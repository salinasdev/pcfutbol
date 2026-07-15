extends Node

signal date_advanced(new_date: Dictionary)
signal season_started(year: int)
signal new_game_created
signal player_match_ready(fixture: Dictionary)
signal matchday_done(matchday: int)
signal season_ended

var season: int = 2026
var current_week: int = 1
var current_date: Dictionary = {"day": 1, "month": 8, "year": 2026}
var player_team_id: int = -1
var manager_name: String = ""
## Fixture activo que se pasa a MatchView
var active_fixture: Dictionary = {}

## Todos los datos del juego — indexados por ID numérico
var players: Dictionary = {}   ## int -> Player
var teams: Dictionary = {}     ## int -> Team
var leagues: Dictionary = {}   ## int -> League

var _next_player_id: int = 1
var _next_team_id: int = 1
var _next_league_id: int = 1

## Bolsa de entrenadores sin equipo actualmente.
var free_coaches: Array[String] = []

## Métricas de la Junta Directiva (1.0 – 10.0)
var manager_rating:    float = 5.0
var board_confidence:  float = 5.0
var public_confidence: float = 5.0
## Primas activas del jugador
var bonus_win:   int = 0
var bonus_title: int = 0
var bonus_history: Array[Dictionary] = []

## Punto rojo en el botón Tácticas cuando hay lesionados/sancionados
var tactics_badge_active: bool = false

# ---------------------------------------------------------------------------

## Paso 1: Resetea el estado y genera todas las ligas/equipos.
## Llamar al entrar a la pantalla de selección de equipo.
func prepare_new_game() -> void:
	_reset_state()
	DataGenerator.generate_all()


## Paso 2: Fija el equipo y el entrenador del jugador y arranca la partida.
func start_game(p_manager_name: String, team_id: int) -> void:
	manager_name   = p_manager_name
	player_team_id = team_id
	emit_signal("season_started", season)
	emit_signal("new_game_created")


## Avanza el calendario una semana:
## - Simula los partidos rivales de la siguiente jornada.
## - Si el jugador tiene partido, emite player_match_ready.
## - Si no, cierra la jornada y emite matchday_done.
func advance_week() -> void:
	current_week += 1
	_advance_date(7)
	emit_signal("date_advanced", current_date)

	# Tick de construcción del estadio del jugador
	var _build_team: Team = get_player_team()
	if _build_team != null and _build_team.construction_weeks_left > 0:
		_build_team.construction_weeks_left -= 1
		if _build_team.construction_weeks_left == 0:
			_finish_stadium_construction(_build_team)

	# Buscar siguiente jornada pendiente en todas las ligas
	for league: League in leagues.values():
		var next_md: int = league.current_matchday + 1
		if next_md > league.get_total_matchdays():
			continue
		var fixtures: Array[Dictionary] = league.get_fixtures_for_matchday(next_md)
		if fixtures.is_empty():
			continue

		var player_fixture: Dictionary = {}
		for f: Dictionary in fixtures:
			if f["played"]:
				continue
			if f["home_id"] == player_team_id or f["away_id"] == player_team_id:
				player_fixture = f
			else:
				var ht: Team = get_team(f["home_id"])
				var at: Team = get_team(f["away_id"])
				_simulate_ai_match(f, ht, at)

		if not player_fixture.is_empty():
			active_fixture = player_fixture
			emit_signal("player_match_ready", player_fixture)
		else:
			league.current_matchday = next_md
			emit_signal("matchday_done", next_md)

	TransferManager.process_weekly_offers()
	TransferManager.generate_incoming_offers()
	_check_coach_sackings()
	NewsManager.generate_weekly_news()

	# Efectos del personal del club
	var staff_team: Team = get_player_team()
	if staff_team != null:
		_apply_staff_effects(staff_team)
		_deduct_staff_wages(staff_team)

	# Salarios semanales y finanzas del equipo del jugador
	_process_weekly_finances()

	# Recuperación de energía semanal para el equipo del jugador
	# Titulares: +6, suplentes: +10, no convocados: +14 (más descanso = más recarga)
	var energy_team: Team = get_player_team()
	if energy_team != null:
		for pid: int in energy_team.player_ids:
			var p: Player = get_player(pid)
			if p:
				var regen: int
				if energy_team.starting_eleven.has(pid):
					regen = randi_range(4, 8)
				elif energy_team.bench.has(pid):
					regen = randi_range(8, 12)
				else:
					regen = randi_range(12, 18)
				p.energy = clampi(p.energy + regen, 5, 100)

	var all_done: bool = true
	for league: League in leagues.values():
		if league.current_matchday < league.get_total_matchdays():
			all_done = false
			break
	if all_done and not leagues.is_empty():
		emit_signal("season_ended")

	# Activar badge de tácticas si hay lesionados/sancionados en el equipo
	var badge_team: Team = get_player_team()
	if badge_team != null:
		for bid: int in badge_team.player_ids:
			var bp: Player = get_player(bid)
			if bp != null and (bp.injured or bp.suspended):
				tactics_badge_active = true
				break

# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Junta Directiva — métricas y primas

func update_board_metrics(goals_for: int, goals_against: int) -> void:
	if goals_for > goals_against:
		manager_rating    = clampf(manager_rating    + 0.30, 1.0, 10.0)
		board_confidence  = clampf(board_confidence  + 0.20, 1.0, 10.0)
		public_confidence = clampf(public_confidence + 0.25, 1.0, 10.0)
	elif goals_for == goals_against:
		manager_rating    = clampf(manager_rating    - 0.05, 1.0, 10.0)
		board_confidence  = clampf(board_confidence  - 0.08, 1.0, 10.0)
		public_confidence = clampf(public_confidence - 0.10, 1.0, 10.0)
	else:
		manager_rating    = clampf(manager_rating    - 0.40, 1.0, 10.0)
		board_confidence  = clampf(board_confidence  - 0.30, 1.0, 10.0)
		public_confidence = clampf(public_confidence - 0.35, 1.0, 10.0)
	# Moral de los jugadores según resultado
	var pt: Team = get_player_team()
	if pt != null:
		var psych: int = pt.staff_psychologist
		for pid: int in pt.starting_eleven:
			var p: Player = get_player(pid)
			if p == null:
				continue
			if goals_for > goals_against:
				p.morale = clampi(p.morale + 5, 0, 100)
			elif goals_for < goals_against:
				var loss: int = int(8.0 * (1.0 - psych * 0.10))
				p.morale = clampi(p.morale - loss, 0, 100)


func propose_bonuses(win_amt: int, title_amt: int) -> String:
	var team := get_player_team()
	if team == null:
		return "❌ No hay equipo seleccionado."
	var total_wages := 0
	for pid: int in team.player_ids:
		var p := get_player(pid)
		if p:
			total_wages += p.salary
	var max_win   := int(total_wages * 1.5)
	var max_title := int(team.budget * 0.25)
	if win_amt > max_win:
		return "❌ Prima por victoria demasiado alta. Máximo aceptable: %s €" % _fmt_int(max_win)
	if title_amt > max_title:
		return "❌ Prima por título demasiado alta. Máximo aceptable: %s €" % _fmt_int(max_title)
	bonus_win   = win_amt
	bonus_title = title_amt
	if win_amt > 0:
		bonus_history.append({"type": "win",   "amount": win_amt,   "week": current_week})
	if title_amt > 0:
		bonus_history.append({"type": "title", "amount": title_amt, "week": current_week})
	return "✔ La Directiva acepta las primas propuestas."


func get_bonus_strength_factor() -> float:
	if bonus_win == 0:
		return 1.0
	var team := get_player_team()
	if team == null or team.player_ids.is_empty():
		return 1.0
	var total_wages := 0
	for pid: int in team.player_ids:
		var p := get_player(pid)
		if p:
			total_wages += p.salary
	if total_wages == 0:
		return 1.0
	var avg_wage := float(total_wages) / team.player_ids.size()
	var avg_per_player := float(bonus_win) / team.player_ids.size()
	var ratio := avg_per_player / avg_wage
	return 1.0 + clampf(ratio * 0.15, 0.0, 0.10)


func _fmt_int(n: int) -> String:
	var s := str(n)
	var result := ""
	var count := 0
	for i: int in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "." + result
		result = s[i] + result
		count += 1
	return result


# ---------------------------------------------------------------------------
# Personal del club — entrenamiento, lesiones y salarios

func _apply_staff_effects(team: Team) -> void:
	# Entrenamiento: cada entrenador mejora el atributo correspondiente
	# Probabilidad por jugador = nivel * 4% por semana
	var coach_map: Array = [
		["staff_gk_coach",        "goalkeeping"],
		["staff_passing_coach",   "passing"],
		["staff_dribbling_coach", "dribbling"],
		["staff_shooting_coach",  "shooting"],
		["staff_tackling_coach",  "defending"],
		["staff_physical_coach",  "physical"],
	]
	for entry: Array in coach_map:
		var lvl: int = team.get(entry[0])
		if lvl == 0:
			continue
		var chance: float = lvl * 0.04
		for pid: int in team.player_ids:
			var p: Player = get_player(pid)
			if p and randf() < chance:
				var current: int = p.get(entry[1])
				p.set(entry[1], mini(current + 1, 99))
				p.market_value = TransferManager.calculate_value(p)

	# Fisio: acelera recuperación de lesiones
	var physio: int = team.staff_physio
	if physio >= 3:
		for pid: int in team.player_ids:
			var p: Player = get_player(pid)
			if p and p.injured:
				var extra: int = 2 if physio == 5 else 1
				p.injury_weeks = maxi(0, p.injury_weeks - extra)
				if p.injury_weeks == 0:
					p.injured = false
					p.suspended = false


func _deduct_staff_wages(team: Team) -> void:
	const WEEKLY_COSTS: Array[int] = [0, 500, 1_500, 4_000, 9_000, 20_000]
	var staff_ids: Array[String] = [
		"staff_gk_coach", "staff_passing_coach", "staff_dribbling_coach",
		"staff_shooting_coach", "staff_tackling_coach", "staff_physical_coach",
		"staff_physio", "staff_psychologist", "staff_scout",
		"staff_tech_secretary", "staff_youth_coach", "staff_talent_scout",
		"staff_groundskeeper",
	]
	var total: int = 0
	for sid: String in staff_ids:
		total += WEEKLY_COSTS[team.get(sid)]
	team.club_cash -= total


## Simula un partido de IA usando el motor completo de eventos.
## Actualiza el fixture, aplica resultados, estadísticas y sanciones reales.
func _simulate_ai_match(f: Dictionary, home: Team, away: Team) -> void:
	var events: Array[Dictionary] = MatchEngine.generate_events(home, away)

	# Buscar el evento FULL_TIME para obtener resultado y listas de tarjetas/lesiones
	var ft: Dictionary = {}
	for ev: Dictionary in events:
		if ev.get("type") == MatchEngine.EventType.FULL_TIME:
			ft = ev
			break

	if ft.is_empty():
		# Fallback de seguridad
		var res := MatchSimulator.simulate_match(home, away)
		f["home_goals"] = res["home_goals"]
		f["away_goals"] = res["away_goals"]
	else:
		f["home_goals"] = ft["home_goals"]
		f["away_goals"] = ft["away_goals"]

	f["played"] = true
	LeagueManager._apply_result(f)

	if not ft.is_empty():
		# Aplicar sanciones (amarillas, rojas, lesiones) a ambos equipos
		LeagueManager.apply_match_sanctions(ft)
		# Descontar partido de baja a lesionados IA y liberar sancionados cumplidos
		LeagueManager.consume_suspensions(home)
		LeagueManager.consume_suspensions(away)

	# Aplicar estadísticas de goles a cada jugador goleador
	for ev: Dictionary in events:
		if ev.get("type") == MatchEngine.EventType.GOAL:
			var scorer_id: int = ev.get("player_id", -1)
			if scorer_id != -1:
				var sp: Player = get_player(scorer_id)
				if sp:
					sp.season_goals += 1


func _process_weekly_finances() -> void:
	var team: Team = get_player_team()
	if team == null:
		return

	# Salarios semanales de la plantilla
	var wage_bill: int = 0
	for pid: int in team.player_ids:
		var p: Player = get_player(pid)
		if p:
			wage_bill += p.salary
	team.club_cash -= wage_bill

	# Cuota del préstamo
	var loan_payment: int = 0
	if team.loan_weeks_left > 0:
		loan_payment = team.loan_weekly_payment
		team.club_cash    -= loan_payment
		team.loan_amount  -= loan_payment
		team.loan_weeks_left -= 1
		if team.loan_weeks_left <= 0 or team.loan_amount <= 0:
			team.loan_amount        = 0
			team.loan_weekly_payment = 0
			team.loan_weeks_left    = 0

	# Ingresos TV
	var tv_income: int = 0
	if team.tv_deal_weeks_left > 0:
		tv_income = team.tv_weekly_income
		team.club_cash += tv_income
		team.tv_deal_weeks_left -= 1
		if team.tv_deal_weeks_left <= 0:
			team.tv_deal_tier    = 0
			team.tv_weekly_income = 0

	# Ingresos patrocinio
	var sponsor_income: int = 0
	if team.sponsor_weeks_left > 0:
		sponsor_income = team.sponsor_weekly_income
		team.club_cash += sponsor_income
		team.sponsor_weeks_left -= 1
		if team.sponsor_weeks_left <= 0:
			team.sponsor_id             = 0
			team.sponsor_weekly_income  = 0

	# Ingresos merchandising semanal (tienda del estadio + tiendas adicionales)
	var merch_income: int = 0
	var base_merch: int = [0, 3_000, 8_000, 18_000, 40_000][clampi(team.shop_level, 0, 4)]
	merch_income = base_merch + team.merch_stores * 25_000
	team.club_cash += merch_income

	# Calcular coste de personal (ya descontado antes, solo para registrarlo)
	const _STAFF_WEEKLY: Array[int] = [0, 500, 1_500, 4_000, 9_000, 20_000]
	const _STAFF_IDS: Array[String] = [
		"staff_gk_coach", "staff_passing_coach", "staff_dribbling_coach",
		"staff_shooting_coach", "staff_tackling_coach", "staff_physical_coach",
		"staff_physio", "staff_psychologist", "staff_scout",
		"staff_tech_secretary", "staff_youth_coach", "staff_talent_scout",
		"staff_groundskeeper",
	]
	var staff_cost: int = 0
	for _sid: String in _STAFF_IDS:
		staff_cost += _STAFF_WEEKLY[team.get(_sid)]

	# Registrar en historial financiero (máx 20 entradas)
	var entry: Dictionary = {
		"week":           current_week,
		"wages":          wage_bill,
		"staff_cost":     staff_cost,
		"loan_payment":   loan_payment,
		"tv_income":      tv_income,
		"sponsor_income": sponsor_income,
		"merch_income":   merch_income,
		"matchday":       0,  # se rellena desde match_view si hay partido ese semana
		"balance":        team.club_cash,
	}
	team.finance_history.append(entry)
	while team.finance_history.size() > 20:
		team.finance_history.pop_front()


# ---------------------------------------------------------------------------
# Sistema de entrenadores — destituciones por malos resultados

func _check_coach_sackings() -> void:
	for league: League in leagues.values():
		if league.current_matchday < 6:
			continue
		for team_id: int in league.team_ids:
			if team_id == player_team_id:
				continue
			var team: Team = get_team(team_id)
			if team == null or team.coach_name.is_empty():
				continue
			var form: Array[String] = _get_last_results(league, team_id, 5)
			if form.size() < 5:
				continue
			var wins:   int = form.count("W")
			var losses: int = form.count("L")
			var sack_chance: float = 0.0
			if wins == 0 and losses >= 4:
				sack_chance = 0.65
			elif wins == 0:
				sack_chance = 0.35
			elif wins <= 1 and losses >= 4:
				sack_chance = 0.20
			if sack_chance > 0.0 and randf() < sack_chance:
				_sack_coach(team)


func _sack_coach(team: Team) -> void:
	var old_coach: String = team.coach_name
	# Liberar el entrenador saliente al mercado libre
	if not old_coach.is_empty() and old_coach not in free_coaches:
		free_coaches.append(old_coach)
	# Buscar reemplazo
	var new_coach: String = ""
	if not free_coaches.is_empty():
		var idx: int = randi() % free_coaches.size()
		new_coach = free_coaches[idx]
		free_coaches.remove_at(idx)
	team.coach_name = new_coach
	# Noticia de destitución
	NewsManager.add_coach_sacked_news(team, old_coach, new_coach)


func _get_last_results(league: League, team_id: int, n: int) -> Array[String]:
	var results: Array[String] = []
	# Recorrer fixtures de atrás hacia adelante
	for i: int in range(league.fixtures.size() - 1, -1, -1):
		var f: Dictionary = league.fixtures[i]
		if not f.get("played", false):
			continue
		var is_home: bool = f["home_id"] == team_id
		var is_away: bool = f["away_id"] == team_id
		if not is_home and not is_away:
			continue
		var gf: int = f["home_goals"] if is_home else f["away_goals"]
		var ga: int = f["away_goals"] if is_home else f["home_goals"]
		if gf > ga:
			results.append("W")
		elif gf < ga:
			results.append("L")
		else:
			results.append("D")
		if results.size() >= n:
			break
	return results


func _finish_stadium_construction(t: Team) -> void:
	var item: String = t.construction_item
	if item.begins_with("stands_"):
		t.stands_level = int(item.split("_")[1])
	elif item.begins_with("parking_"):
		t.parking_level = int(item.split("_")[1])
	t.construction_item = ""


func register_player(player: Player) -> int:
	player.id = _next_player_id
	players[_next_player_id] = player
	_next_player_id += 1
	return player.id


func register_team(team: Team) -> int:
	team.id = _next_team_id
	teams[_next_team_id] = team
	_next_team_id += 1
	return team.id


func register_league(league: League) -> int:
	league.id = _next_league_id
	leagues[_next_league_id] = league
	_next_league_id += 1
	return league.id


func get_player(id: int) -> Player:
	return players.get(id, null)


func get_team(id: int) -> Team:
	return teams.get(id, null)


func get_league(id: int) -> League:
	return leagues.get(id, null)


func get_player_team() -> Team:
	return get_team(player_team_id)


func get_date_string() -> String:
	return "%02d/%02d/%d" % [current_date["day"], current_date["month"], current_date["year"]]


## Devuelve el próximo fixture sin jugar del equipo del jugador (mirando hacia adelante).
func get_next_player_fixture() -> Dictionary:
	if not active_fixture.is_empty() and not active_fixture.get("played", false):
		return active_fixture
	for league: League in leagues.values():
		for md: int in range(league.current_matchday + 1, league.get_total_matchdays() + 2):
			for f: Dictionary in league.get_fixtures_for_matchday(md):
				if not f.get("played", false) and (f["home_id"] == player_team_id or f["away_id"] == player_team_id):
					return f
	return {}

# ---------------------------------------------------------------------------

func _reset_state() -> void:
	season = 2026
	current_week = 1
	current_date = {"day": 1, "month": 8, "year": 2026}
	player_team_id = -1
	manager_name = ""
	players.clear()
	teams.clear()
	leagues.clear()
	free_coaches.clear()
	manager_rating    = 5.0
	board_confidence  = 5.0
	public_confidence = 5.0
	bonus_win         = 0
	bonus_title       = 0
	bonus_history.clear()
	_next_player_id = 1
	_next_team_id = 1
	_next_league_id = 1


func _advance_date(days: int) -> void:
	var days_per_month := [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	current_date["day"] += days
	while current_date["day"] > days_per_month[current_date["month"]]:
		current_date["day"] -= days_per_month[current_date["month"]]
		current_date["month"] += 1
		if current_date["month"] > 12:
			current_date["month"] = 1
			current_date["year"] += 1
			season = current_date["year"]
