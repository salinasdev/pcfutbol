extends Node

signal transfer_completed(player: Player, from_team: Team, to_team: Team, fee: int)
signal transfer_rejected(player: Player, reason: String)
## Emitida cuando la IA responde a una oferta (accepted/rejected/countered)
signal offer_response_received(offer: Dictionary)
## Emitida cuando llega una nueva oferta de la IA por un jugador nuestro
signal incoming_offer_received(offer: Dictionary)

## Ofertas activas del equipo del jugador (hacia equipos IA)
var active_offers: Array[Dictionary] = []
var _next_offer_id: int = 1

## Ofertas que equipos IA han hecho por jugadores del equipo del jugador
var incoming_offers: Array[Dictionary] = []
var _next_incoming_id: int = 1

const _REJECT_MSGS: Array = [
	"El club ha rechazado la oferta. Consideran que no refleja el valor del jugador.",
	"Propuesta denegada. La directiva no tiene intención de vender.",
	"El técnico rival ha bloqueado la salida del jugador.",
	"La directiva rechaza la oferta. Piden una cantidad muy superior.",
	"No hay acuerdo. El club vendedor quiere bastante más dinero.",
	"El jugador no quiere abandonar el club en estos momentos.",
]
const _ACCEPT_MSGS: Array = [
	"¡Oferta aceptada! El club ha dado luz verde al traspaso.",
	"¡Acuerdo alcanzado! El jugador se somete al reconocimiento médico.",
	"La directiva rival acepta los términos. ¡El fichaje está hecho!",
	"¡Trato cerrado! El jugador ya es tuyo.",
	"Tras breves negociaciones, ambos clubes han llegado a un acuerdo.",
]
const _COUNTER_MSGS: Array = [
	"El club hace una contraoferta: quieren %s € por el jugador.",
	"El equipo no acepta los términos pero propone un acuerdo alternativo: %s €.",
	"Nueva propuesta del vendedor: valoran al jugador en %s €.",
	"El jugador está interesado pero su club exige %s € para dejarlo marchar.",
]


# ---------------------------------------------------------------------------
# API pública

## Calcula el valor estimado de mercado de un jugador
func calculate_value(player: Player) -> int:
	var base := float(player.get_overall())
	var age_factor := 1.0
	if player.age < 24:
		age_factor = 1.2 + (24 - player.age) * 0.04
	elif player.age > 30:
		age_factor = maxf(0.2, 1.0 - (player.age - 30) * 0.08)
	return int(base * base * age_factor * 200.0)


## Coloca una oferta de fichaje (asíncrona). Devuelve el ID de oferta o -1 si la validación falla.
func place_offer(buyer: Team, data: Dictionary) -> int:
	var player: Player = data.get("player")
	if player == null:
		return -1
	var money: int = data.get("money", 0)

	var seller: Team = GameManager.get_team(player.team_id)
	if seller == null:
		emit_signal("transfer_rejected", player, "El jugador no tiene equipo asignado")
		return -1
	if buyer.id == seller.id:
		emit_signal("transfer_rejected", player, "El jugador ya pertenece a tu equipo")
		return -1
	if buyer.budget < money:
		emit_signal("transfer_rejected", player,
			"Presupuesto insuficiente (disponible: %s €)" % _format_money(buyer.budget))
		return -1

	# Construir oferta (sin guardar la referencia al objeto Player)
	var clean_data := data.duplicate(true)
	clean_data.erase("player")  # no serializable; usamos player_id

	var offer: Dictionary = {
		"id":               _next_offer_id,
		"player_id":        player.id,
		"buyer_id":         buyer.id,
		"week_submitted":   GameManager.current_week,
		"status":           "pending",
		"offer_data":       clean_data,
		"response_message": "Esperando respuesta del club...",
		"counter_data":     {},
	}
	_next_offer_id += 1
	active_offers.append(offer)

	# Posible filtración a la prensa (30 % de probabilidad)
	if randf() < 0.30:
		NewsManager.add_offer_leak_news(player, buyer)

	return offer["id"]


## El jugador acepta la contraoferta recibida — el traspaso se completa de inmediato.
func accept_counter(offer_id: int) -> void:
	for offer: Dictionary in active_offers:
		if offer["id"] != offer_id or offer["status"] != "countered":
			continue
		var cd: Dictionary = offer["counter_data"]
		# Sobrescribir términos con la contraoferta
		offer["offer_data"]["money"]          = cd.get("money",          offer["offer_data"].get("money", 0))
		offer["offer_data"]["contract_years"] = cd.get("contract_years", offer["offer_data"].get("contract_years", 2))
		offer["offer_data"]["annual_bonus"]   = cd.get("annual_bonus",   offer["offer_data"].get("annual_bonus", 0))

		var player: Player = GameManager.get_player(offer["player_id"])
		var buyer: Team    = GameManager.get_team(offer["buyer_id"])
		if player == null or buyer == null:
			offer["status"] = "rejected"
			offer["response_message"] = "El jugador ya no está disponible."
			return
		if buyer.budget < offer["offer_data"]["money"]:
			offer["status"] = "rejected"
			offer["response_message"] = "Presupuesto insuficiente para la contraoferta."
			return

		offer["status"]           = "accepted"
		offer["response_message"] = "Contraoferta aceptada. ¡Fichaje completado!"
		_complete_offer(offer, player, buyer)
		return


## Retira (elimina) una oferta, sea cual sea su estado.
func withdraw_offer(offer_id: int) -> void:
	for i in range(active_offers.size()):
		if active_offers[i]["id"] == offer_id:
			active_offers.remove_at(i)
			return


## Marca como vistas todas las respuestas de ofertas activas (quita badge Fichajes).
func acknowledge_active_offers() -> void:
	for offer: Dictionary in active_offers:
		offer["acknowledged"] = true


## Marca como vistas todas las ofertas entrantes pendientes (quita badge Plantilla).
func acknowledge_incoming_offers() -> void:
	for offer: Dictionary in incoming_offers:
		if offer["status"] == "pending":
			offer["acknowledged"] = true


## Procesa la respuesta de la IA a todas las ofertas pendientes.
## Llamar desde GameManager.advance_week().
func process_weekly_offers() -> void:
	for offer: Dictionary in active_offers:
		if offer["status"] != "pending":
			continue
		var player: Player = GameManager.get_player(offer["player_id"])
		if player == null:
			offer["status"]           = "rejected"
			offer["response_message"] = "El jugador ya no está disponible."
			offer["acknowledged"]     = false
			emit_signal("offer_response_received", offer)
			continue
		_evaluate_offer(offer, player)
		offer["acknowledged"] = false
		emit_signal("offer_response_received", offer)


## Pone a un jugador en el mercado de traspasos
func list_player(player: Player) -> void:
	player.transfer_listed = true


## Retira a un jugador del mercado de traspasos
func delist_player(player: Player) -> void:
	player.transfer_listed = false


## Devuelve todos los jugadores actualmente en el mercado
func get_listed_players() -> Array:
	var listed: Array = []
	for p: Player in GameManager.players.values():
		if p.transfer_listed:
			listed.append(p)
	return listed


# ---------------------------------------------------------------------------
# Ofertas entrantes (IA → equipo del jugador)

## Genera ofertas entrantes aleatorias de la IA. Llamar desde advance_week().
func generate_incoming_offers() -> void:
	var player_team: Team = GameManager.get_player_team()
	if player_team == null:
		return

	# Limpiar ofertas caducadas (más de 4 semanas sin respuesta)
	var current_week: int = GameManager.current_week
	incoming_offers = incoming_offers.filter(func(o: Dictionary) -> bool:
		return o["status"] != "pending" or (current_week - o.get("week_submitted", current_week)) < 4
	)

	# ~15 % de probabilidad semanal (reducido para no saturar al jugador)
	if randf() > 0.15:
		return

	# Candidatos: jugadores en venta (oferta normal) y jugadores con cláusula activable
	var listed_cands: Array[Player] = []
	var clause_cands: Array[Player] = []

	for pid: int in player_team.player_ids:
		var p: Player = GameManager.get_player(pid)
		if p == null:
			continue
		var already: bool = false
		for o: Dictionary in incoming_offers:
			if o["player_id"] == p.id and o["status"] == "pending":
				already = true
				break
		if already:
			continue
		if p.transfer_listed:
			listed_cands.append(p)
		elif p.release_clause > 0 and p.get_overall() >= 70:
			# Solo incluir si hay equipos que puedan pagar la cláusula
			clause_cands.append(p)

	# Priorizar jugadores en venta; 35 % de chance de oferta de cláusula si no hay en venta
	var target: Player = null
	var is_clause: bool = false
	if not listed_cands.is_empty() and (clause_cands.is_empty() or randf() < 0.65):
		target = listed_cands[randi() % listed_cands.size()]
		is_clause = false
	elif not clause_cands.is_empty():
		# Filtrar cláusula: si es muy alta respecto al valor, reducir probabilidad
		var affordable: Array[Player] = []
		for cp: Player in clause_cands:
			var ratio: float = float(cp.release_clause) / float(maxi(calculate_value(cp), 1))
			# <1.5× : siempre candidato; 1.5-2×: 50%; 2-3×: 20%; >3×: 5%
			var prob: float
			if   ratio < 1.5: prob = 1.00
			elif ratio < 2.0: prob = 0.50
			elif ratio < 3.0: prob = 0.20
			else:             prob = 0.05
			if randf() < prob:
				affordable.append(cp)
		if affordable.is_empty():
			return
		target = affordable[randi() % affordable.size()]
		is_clause = true
	else:
		return

	# Elegir comprador que pueda permitirse la cláusula
	var buyer_candidates: Array = GameManager.teams.values().filter(func(t: Team) -> bool:
		if t.id == player_team.id or t.budget <= 0:
			return false
		if is_clause and target != null:
			return t.budget >= target.release_clause
		return true
	)
	if buyer_candidates.is_empty():
		return
	var buyer: Team = buyer_candidates[randi() % buyer_candidates.size()]

	var value: int = calculate_value(target)
	var offer_money: int
	if is_clause:
		offer_money = target.release_clause
	else:
		offer_money = int(value * randf_range(0.70, 1.20))
	offer_money = int(offer_money / 50_000.0) * 50_000

	# Calcular si el jugador quiere marcharse (influye en la UI de plantilla)
	var want_prob: float = 0.0
	if not target.transfer_listed:
		if target.morale < 40:
			want_prob = 0.70
		elif target.morale < 60:
			want_prob = 0.35
		if target.contract_years <= 1:
			want_prob = minf(want_prob + 0.25, 0.90)
	var player_wants_to_go: bool = is_clause or (randf() < want_prob)

	var offer: Dictionary = {
		"id":                  _next_incoming_id,
		"player_id":           target.id,
		"buyer_id":            buyer.id,
		"offer_money":         offer_money,
		"week_submitted":      current_week,
		"status":              "pending",
		"is_clause":           is_clause,
		"player_wants_to_go":  player_wants_to_go,
		"acknowledged":        false,
	}
	_next_incoming_id += 1
	incoming_offers.append(offer)
	emit_signal("incoming_offer_received", offer)


## Acepta una oferta entrante: transfiere el jugador y cobra el dinero.
func accept_incoming_offer(offer_id: int) -> void:
	for offer: Dictionary in incoming_offers:
		if offer["id"] != offer_id or offer["status"] != "pending":
			continue
		var player: Player = GameManager.get_player(offer["player_id"])
		var buyer: Team    = GameManager.get_team(offer["buyer_id"])
		var seller: Team   = GameManager.get_player_team()
		if player == null or buyer == null or seller == null:
			offer["status"] = "rejected"
			return
		offer["status"] = "accepted"
		_complete_transfer(buyer, seller, player, offer["offer_money"])
		NewsManager.add_transfer_done_news(player, seller, buyer, offer["offer_money"])
		return


## Rechaza una oferta entrante.
func reject_incoming_offer(offer_id: int) -> void:
	for offer: Dictionary in incoming_offers:
		if offer["id"] == offer_id:
			offer["status"] = "rejected"
			return


# ---------------------------------------------------------------------------
# Lógica de negociación IA

func _evaluate_offer(offer: Dictionary, player: Player) -> void:
	var money: int  = offer["offer_data"].get("money", 0)
	var value: int  = calculate_value(player)
	var ratio: float = float(money) / float(maxi(value, 1))
	var bias: float  = 0.15 if player.transfer_listed else 0.0

	var r := randf()
	var at: float  # umbral de aceptación
	var ct: float  # umbral de contraoferta (arriba → rechazo)

	if ratio >= 1.15:
		at = 0.90; ct = 0.97
	elif ratio >= 0.95:
		at = 0.70; ct = 0.90
	elif ratio >= 0.80:
		at = 0.35; ct = 0.72
	elif ratio >= 0.65:
		at = 0.10; ct = 0.42
	else:
		at = 0.03; ct = 0.18

	at = clampf(at + bias, 0.0, 0.98)
	ct = clampf(ct + bias, 0.0, 0.99)

	if r < at:
		_do_accept(offer, player)
	elif r < ct:
		_do_counter(offer, player, value)
	else:
		_do_reject(offer)


func _do_accept(offer: Dictionary, player: Player) -> void:
	offer["status"]           = "accepted"
	offer["response_message"] = _ACCEPT_MSGS.pick_random()
	var buyer: Team = GameManager.get_team(offer["buyer_id"])
	if buyer != null:
		_complete_offer(offer, player, buyer)


func _do_counter(offer: Dictionary, _player: Player, value: int) -> void:
	var counter_money: int = int(value * randf_range(1.05, 1.28))
	counter_money = int(counter_money / 50_000.0) * 50_000  # redondeo a 50 K
	var orig_years:  int = offer["offer_data"].get("contract_years", 2)
	var orig_bonus:  int = offer["offer_data"].get("annual_bonus", 0)

	offer["status"]       = "countered"
	offer["counter_data"] = {
		"money":          counter_money,
		"contract_years": clampi(orig_years + (randi() % 2), orig_years, 5),
		"annual_bonus":   int(orig_bonus * randf_range(1.0, 1.30)),
	}
	offer["response_message"] = (_COUNTER_MSGS.pick_random()) % _format_money(counter_money)


func _do_reject(offer: Dictionary) -> void:
	offer["status"]           = "rejected"
	offer["response_message"] = _REJECT_MSGS.pick_random()


func _complete_offer(offer: Dictionary, player: Player, buyer: Team) -> void:
	var seller: Team = GameManager.get_team(player.team_id)
	if seller == null:
		return
	var data: Dictionary = offer["offer_data"]
	var money: int = data.get("money", 0)

	# Condiciones del contrato
	player.contract_years        = data.get("contract_years", 2)
	player.release_clause        = data.get("release_clause", 0)
	player.annual_bonus          = data.get("annual_bonus", 0)
	player.join_when             = data.get("join_when", 0)
	player.relegation_freedom    = data.get("relegation_freedom", false)
	player.matches_renewal       = data.get("matches_renewal", false)
	player.matches_renewal_count = data.get("matches_renewal_count", 0)
	player.goal_bonus_active     = data.get("goal_bonus_active", false)
	player.goal_bonus_amount     = data.get("goal_bonus_amount", 0)
	player.house_car             = data.get("house_car", false)

	# Jugadores incluidos en el traspaso
	for pid: int in data.get("player_offer_ids", []):
		var offered: Player = GameManager.get_player(pid)
		if offered and offered.team_id == buyer.id:
			buyer.player_ids.erase(offered.id)
			seller.player_ids.append(offered.id)
			offered.team_id = seller.id

	_complete_transfer(buyer, seller, player, money)
	NewsManager.add_transfer_done_news(player, seller, buyer, money)


func _complete_transfer(buyer: Team, seller: Team, player: Player, fee: int) -> void:
	seller.player_ids.erase(player.id)
	buyer.player_ids.append(player.id)
	player.team_id = buyer.id
	buyer.budget  -= fee
	seller.budget += fee

	# El dinero del traspaso va a la caja del vendedor
	var player_team: Team = GameManager.get_player_team()
	if player_team != null and seller.id == player_team.id:
		seller.club_cash += fee
		# Anotar en el historial financiero de la semana actual
		if not seller.finance_history.is_empty():
			var entry: Dictionary = seller.finance_history[seller.finance_history.size() - 1]
			entry["transfer_income"] = entry.get("transfer_income", 0) + fee
			entry["balance"] = seller.club_cash

	emit_signal("transfer_completed", player, seller, buyer, fee)


func _format_money(amount: int) -> String:
	if amount >= 1_000_000:
		return "%.1fM" % (amount / 1_000_000.0)
	elif amount >= 1_000:
		return "%.0fK" % (amount / 1_000.0)
	return str(amount)
