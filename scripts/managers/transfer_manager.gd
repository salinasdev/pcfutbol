extends Node

signal transfer_completed(player: Player, from_team: Team, to_team: Team, fee: int)
signal transfer_rejected(player: Player, reason: String)


## Calcula el valor estimado de mercado de un jugador
func calculate_value(player: Player) -> int:
	var base := float(player.get_overall())
	var age_factor := 1.0
	if player.age < 24:
		age_factor = 1.2 + (24 - player.age) * 0.04
	elif player.age > 30:
		age_factor = maxf(0.2, 1.0 - (player.age - 30) * 0.08)
	return int(base * base * age_factor * 200.0)


## Intenta realizar un fichaje. Devuelve true si se completa.
func make_offer(buyer: Team, player: Player, offer: int) -> bool:
	var seller: Team = GameManager.get_team(player.team_id)

	if seller == null:
		emit_signal("transfer_rejected", player, "El jugador no tiene equipo asignado")
		return false
	if buyer.id == seller.id:
		emit_signal("transfer_rejected", player, "El jugador ya pertenece a tu equipo")
		return false

	var min_acceptable := int(calculate_value(player) * 0.85)
	if offer < min_acceptable:
		emit_signal("transfer_rejected", player,
			"Oferta rechazada. Valor mínimo aceptable: %s €" % _format_money(min_acceptable))
		return false
	if buyer.budget < offer:
		emit_signal("transfer_rejected", player,
			"Presupuesto insuficiente (disponible: %s €)" % _format_money(buyer.budget))
		return false

	_complete_transfer(buyer, seller, player, offer)
	return true


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


func _complete_transfer(buyer: Team, seller: Team, player: Player, fee: int) -> void:
	seller.player_ids.erase(player.id)
	buyer.player_ids.append(player.id)
	player.team_id = buyer.id
	buyer.budget  -= fee
	seller.budget += fee
	emit_signal("transfer_completed", player, seller, buyer, fee)


func _format_money(amount: int) -> String:
	if amount >= 1_000_000:
		return "%.1fM" % (amount / 1_000_000.0)
	elif amount >= 1_000:
		return "%.0fK" % (amount / 1_000.0)
	return str(amount)
