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
var cup_competitions: Dictionary = {}
var pending_cup_draw_presentations: Array[Dictionary] = []
var week_in_progress: bool = false
var current_week_had_cup_fixture: bool = false

var _next_player_id: int = 1
var _next_team_id: int = 1
var _next_league_id: int = 1
var _next_manager_offer_id: int = 1

## Bolsa de entrenadores sin equipo actualmente.
var free_coaches: Array[String] = []
## Cartera de equipos para cubrir huecos en Segunda por descenso administrativo de filiales.
## Formato de entrada: {name, short_name, city, reputation, stadium_name, stadium_capacity, crest}
var reserve_replacement_pool: Dictionary = {"España": []}
var _last_spanish_transition: Dictionary = {}

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

## Nombre del derbi activo (vacío si el siguiente partido no es un derbi)
var active_derby_name: String = ""

## Carrera del mánager
var manager_matches: int = 0
var manager_wins: int = 0
var manager_draws: int = 0
var manager_losses: int = 0
var manager_clubs_managed: Array[int] = []
var manager_offers_received: int = 0
var manager_offers_accepted: int = 0
var manager_job_offers: Array[Dictionary] = []
var manager_global_reputation: float = 50.0
var manager_honours: Array[Dictionary] = []
var manager_career_history: Array[Dictionary] = []
var manager_preferences: Dictionary = {
	"preferred_level": 0,
	"project_type": 0,
	"min_reputation": 45,
}

const CUP_DEL_REY_KEY := "copa_del_rey"
const CUP_DEL_REY_NAME := "Copa del Rey"
const CUP_DEL_REY_LOGO_PATH := "res://assets/ui/icons/copa1.png"
const CUP_DEL_REY_FINAL_VENUE := "La Cartuja"
const CUP_DEL_REY_TARGET_TEAMS := 64
const CUP_DEL_REY_PAYOUTS := {
	"round_1": {"played": 90_000, "win": 140_000},
	"round_2": {"played": 120_000, "win": 220_000},
	"round_3": {"played": 180_000, "win": 360_000},
	"round_4": {"played": 260_000, "win": 650_000},
	"semifinals": {"played": 450_000, "win": 1_100_000},
	"final": {"played": 1_000_000, "win": 3_200_000},
}

# ---------------------------------------------------------------------------

## Paso 1: Resetea el estado y genera todas las ligas/equipos.
## Llamar al entrar a la pantalla de selección de equipo.
func prepare_new_game() -> void:
	_reset_state()
	DataGenerator.generate_all()
	setup_season_competitions()


## Paso 2: Fija el equipo y el entrenador del jugador y arranca la partida.
func start_game(p_manager_name: String, team_id: int) -> void:
	manager_name   = p_manager_name
	player_team_id = team_id
	if not manager_clubs_managed.has(team_id):
		manager_clubs_managed.append(team_id)
	_open_manager_career_entry(get_team(team_id))
	emit_signal("season_started", season)
	emit_signal("new_game_created")


## Avanza el calendario una semana:
## - Simula los partidos rivales de la siguiente jornada.
## - Si el jugador tiene partido, emite player_match_ready.
## - Si no, cierra la jornada y emite matchday_done.
func advance_week() -> void:
	if week_in_progress and _continue_current_week_if_needed():
		return
	week_in_progress = true
	current_week_had_cup_fixture = false
	current_week += 1
	_advance_date(7)
	emit_signal("date_advanced", current_date)
	_maybe_draw_due_cup_rounds()

	# Tick de construcción del estadio del jugador
	var _build_team: Team = get_player_team()
	if _build_team != null and _build_team.construction_weeks_left > 0:
		_build_team.construction_weeks_left -= 1
		if _build_team.construction_weeks_left == 0:
			_finish_stadium_construction(_build_team)

	var cup_fixture := _process_due_cup_matches()
	if not cup_fixture.is_empty():
		current_week_had_cup_fixture = true
		active_fixture = cup_fixture
		var cup_derby: String = NewsManager.get_derby_name_by_id(
			cup_fixture.get("home_id", -1), cup_fixture.get("away_id", -1))
		active_derby_name = cup_derby
		if cup_derby != "":
			var cup_home: Team = get_team(cup_fixture.get("home_id", -1))
			var cup_away: Team = get_team(cup_fixture.get("away_id", -1))
			if cup_home != null and cup_away != null:
				var derby_team: Team = get_player_team()
				if derby_team != null:
					for derby_player_id: int in derby_team.player_ids:
						var derby_player: Player = get_player(derby_player_id)
						if derby_player != null:
							derby_player.morale = clampi(derby_player.morale + 10, 0, 100)
				NewsManager.add_derby_preview_news(cup_home, cup_away, cup_derby)
		emit_signal("player_match_ready", cup_fixture)
		TransferManager.process_weekly_offers()
		TransferManager.generate_incoming_offers()
		_check_coach_sackings()
		_process_manager_job_market()

		var cup_staff_team: Team = get_player_team()
		if cup_staff_team != null:
			_apply_staff_effects(cup_staff_team)
			_deduct_staff_wages(cup_staff_team)

		_process_weekly_finances()
		_recover_all_teams_condition()

		if _are_domestic_competitions_finished():
			emit_signal("season_ended")

		var cup_badge_team: Team = get_player_team()
		if cup_badge_team != null:
			for cup_badge_id: int in cup_badge_team.player_ids:
				var cup_badge_player: Player = get_player(cup_badge_id)
				if cup_badge_player != null and (cup_badge_player.injured or cup_badge_player.suspended):
					tactics_badge_active = true
					break
		return

	_process_current_week_league_round()

	TransferManager.process_weekly_offers()
	TransferManager.generate_incoming_offers()
	_check_coach_sackings()
	_process_manager_job_market()
	if active_fixture.is_empty() or active_fixture.get("played", false):
		NewsManager.generate_weekly_news()
		NewsManager.ensure_weekly_news()

	# Efectos del personal del club
	var staff_team: Team = get_player_team()
	if staff_team != null:
		_apply_staff_effects(staff_team)
		_deduct_staff_wages(staff_team)

	# Salarios semanales y finanzas del equipo del jugador
	_process_weekly_finances()

	# Recuperación semanal de condición para todos los equipos.
	_recover_all_teams_condition()

	if _are_domestic_competitions_finished():
		emit_signal("season_ended")

	# Activar badge de tácticas si hay lesionados/sancionados en el equipo
	var badge_team: Team = get_player_team()
	if badge_team != null:
		for bid: int in badge_team.player_ids:
			var bp: Player = get_player(bid)
			if bp != null and (bp.injured or bp.suspended):
				tactics_badge_active = true
				break
	if active_fixture.is_empty() or active_fixture.get("played", false):
		week_in_progress = false
		current_week_had_cup_fixture = false

# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Junta Directiva — métricas y primas

func update_board_metrics(goals_for: int, goals_against: int) -> void:
	manager_matches += 1
	if goals_for > goals_against:
		manager_wins += 1
		manager_global_reputation = clampf(manager_global_reputation + 0.20, 1.0, 100.0)
	elif goals_for < goals_against:
		manager_losses += 1
		manager_global_reputation = clampf(manager_global_reputation - 0.15, 1.0, 100.0)
	else:
		manager_draws += 1
		manager_global_reputation = clampf(manager_global_reputation + 0.02, 1.0, 100.0)

	# Los derbis amplifican el impacto en las métricas de la junta
	var derby_mult: float = 1.8 if active_derby_name != "" else 1.0
	if goals_for > goals_against:
		manager_rating    = clampf(manager_rating    + 0.30 * derby_mult, 1.0, 10.0)
		board_confidence  = clampf(board_confidence  + 0.20 * derby_mult, 1.0, 10.0)
		public_confidence = clampf(public_confidence + 0.25 * derby_mult, 1.0, 10.0)
	elif goals_for == goals_against:
		manager_rating    = clampf(manager_rating    - 0.05 * derby_mult, 1.0, 10.0)
		board_confidence  = clampf(board_confidence  - 0.08 * derby_mult, 1.0, 10.0)
		public_confidence = clampf(public_confidence - 0.10 * derby_mult, 1.0, 10.0)
	else:
		manager_rating    = clampf(manager_rating    - 0.40 * derby_mult, 1.0, 10.0)
		board_confidence  = clampf(board_confidence  - 0.30 * derby_mult, 1.0, 10.0)
		public_confidence = clampf(public_confidence - 0.35 * derby_mult, 1.0, 10.0)
	active_derby_name = ""  # limpiar tras aplicar el resultado
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
	apply_post_match_wear(home, randf_range(0.90, 1.15))
	apply_post_match_wear(away, randf_range(0.90, 1.15))

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


func apply_post_match_wear(team: Team, intensity: float = 1.0) -> void:
	if team == null:
		return
	for pid: int in team.starting_eleven:
		var p: Player = get_player(pid)
		if p == null:
			continue
		var base_drain := randf_range(7.0, 18.0)
		var phys_factor := 1.0 - (float(p.physical) / 99.0) * 0.30
		var drain := int(round(base_drain * phys_factor * intensity))
		p.energy = clampi(p.energy - drain, 5, 100)

		var fitness_hit := 1
		if p.energy < 35:
			fitness_hit = 3
		elif p.energy < 55:
			fitness_hit = 2
		if intensity > 1.05:
			fitness_hit += 1
		p.fitness = clampi(p.fitness - fitness_hit, 35, 100)


func _recover_all_teams_condition() -> void:
	for team: Team in teams.values():
		_recover_team_condition(team)


func _recover_team_condition(team: Team) -> void:
	if team == null:
		return
	for pid: int in team.player_ids:
		var p: Player = get_player(pid)
		if p == null:
			continue

		var energy_regen: int
		var fitness_regen: int
		if p.injured:
			energy_regen = randi_range(18, 26)
			fitness_regen = randi_range(3, 6)
		elif team.starting_eleven.has(pid):
			energy_regen = randi_range(8, 14)
			fitness_regen = randi_range(0, 2)
		elif team.bench.has(pid):
			energy_regen = randi_range(12, 18)
			fitness_regen = randi_range(1, 3)
		else:
			energy_regen = randi_range(16, 24)
			fitness_regen = randi_range(2, 4)

		p.energy = clampi(p.energy + energy_regen, 5, 100)
		p.fitness = clampi(p.fitness + fitness_regen, 35, 100)


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

	# Ingresos de derechos de liga (reparto TV, abonados y comerciales base)
	# Garantizados cada semana independientemente de si hay partido en casa
	var league_tv: int = int(team.reputation * 3_500)
	team.club_cash += league_tv

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
		"league_tv":      league_tv,
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


func _process_manager_job_market() -> void:
	# Limpiar ofertas caducadas o ya resueltas
	manager_job_offers = manager_job_offers.filter(func(of: Dictionary) -> bool:
		return of.get("status", "pending") == "pending" and int(of.get("deadline_week", 0)) >= current_week
	)

	if manager_job_offers.size() >= 3:
		return
	_generate_manager_job_offer(false)


func _generate_manager_job_offer(force: bool) -> void:
	if manager_job_offers.size() >= 3:
		return

	var form_factor: float = float(manager_wins + 1) / float(manager_losses + 1)
	var strength := clampf((manager_rating + board_confidence + public_confidence) / 30.0, 0.20, 0.95)
	strength = clampf(strength * 0.65 + (manager_global_reputation / 100.0) * 0.35, 0.20, 0.98)
	var chance := clampf(0.08 + strength * 0.18 + form_factor * 0.03, 0.08, 0.45)
	if get_player_team() == null:
		chance = clampf(chance + 0.20, 0.20, 0.70)
	if not force and randf() > chance:
		return

	var current_team: Team = get_player_team()

	var candidates: Array[Team] = []
	for t: Team in teams.values():
		if t == null:
			continue
		if current_team != null and t.id == current_team.id:
			continue
		if not _manager_prefers_club(t, current_team):
			continue
		if current_team == null:
			if t.league_id > 0:
				candidates.append(t)
		elif abs(t.reputation - current_team.reputation) <= 15 or t.reputation > current_team.reputation:
			candidates.append(t)

	if candidates.is_empty():
		return

	var target: Team = candidates[randi() % candidates.size()]
	for of: Dictionary in manager_job_offers:
		if int(of.get("team_id", -1)) == target.id and of.get("status", "") == "pending":
			return

	var offer_salary: int = int(target.reputation * 12_000 + randf_range(60_000, 220_000))
	var offer: Dictionary = {
		"id": _next_manager_offer_id,
		"team_id": target.id,
		"salary": offer_salary,
		"league_id": target.league_id,
		"deadline_week": current_week + randi_range(2, 5),
		"status": "pending",
		"week_created": current_week,
	}
	_next_manager_offer_id += 1
	manager_job_offers.append(offer)
	manager_offers_received += 1
	NewsManager.add_manager_job_offer_news(target, offer_salary)


func _handle_player_manager_relegation(transition: Dictionary) -> void:
	var current_team: Team = get_player_team()
	if current_team == null:
		return
	for relegated: Team in transition.get("second_relegated", []):
		if relegated != null and relegated.id == current_team.id:
			_close_current_manager_career_entry("destituido por descenso")
			player_team_id = -1
			active_fixture = {}
			active_derby_name = ""
			NewsManager.add_manager_sacked_news(current_team)
			_generate_manager_job_offer(true)
			_generate_manager_job_offer(true)
			break


func accept_manager_job_offer(offer_id: int) -> String:
	for of: Dictionary in manager_job_offers:
		if int(of.get("id", -1)) != offer_id:
			continue
		if of.get("status", "pending") != "pending":
			return "La oferta ya no está disponible."
		if int(of.get("deadline_week", 0)) < current_week:
			of["status"] = "expired"
			return "La oferta ha caducado."

		var old_team: Team = get_player_team()
		var new_team: Team = get_team(int(of.get("team_id", -1)))
		if new_team == null:
			of["status"] = "invalid"
			return "El club ofertante ya no está disponible."

		if old_team != null and old_team.id != new_team.id:
			if old_team.coach_name == manager_name:
				old_team.coach_name = ""
			_close_current_manager_career_entry("cambio de club")

		player_team_id = new_team.id
		new_team.coach_name = manager_name
		if not manager_clubs_managed.has(new_team.id):
			manager_clubs_managed.append(new_team.id)
		_open_manager_career_entry(new_team)

		manager_offers_accepted += 1
		manager_global_reputation = clampf(manager_global_reputation + 2.5, 1.0, 100.0)
		of["status"] = "accepted"
		active_fixture = {}
		active_derby_name = ""
		NewsManager.add_manager_job_switch_news(old_team, new_team)
		return "Has firmado por %s." % new_team.name

	return "No se encontró la oferta indicada."


func reject_manager_job_offer(offer_id: int) -> String:
	for of: Dictionary in manager_job_offers:
		if int(of.get("id", -1)) == offer_id:
			if of.get("status", "pending") != "pending":
				return "La oferta ya no está activa."
			of["status"] = "rejected"
			return "Oferta rechazada."
	return "No se encontró la oferta indicada."


func get_manager_win_rate() -> float:
	if manager_matches <= 0:
		return 0.0
	return float(manager_wins) * 100.0 / float(manager_matches)


func cycle_manager_preference(key: String, direction: int = 1) -> void:
	match key:
		"preferred_level":
			var current_level := int(manager_preferences.get(key, 0))
			manager_preferences[key] = posmod(current_level + direction, 3)
		"project_type":
			var current_type := int(manager_preferences.get(key, 0))
			manager_preferences[key] = posmod(current_type + direction, 4)
		"min_reputation":
			var rep := int(manager_preferences.get(key, 45)) + direction * 5
			if rep > 80:
				rep = 35
			elif rep < 35:
				rep = 80
			manager_preferences[key] = rep


func get_manager_preference_label(key: String) -> String:
	match key:
		"preferred_level":
			match int(manager_preferences.get(key, 0)):
				1:
					return "Primera"
				2:
					return "Segunda"
				_:
					return "Cualquiera"
		"project_type":
			match int(manager_preferences.get(key, 0)):
				1:
					return "Ambicioso"
				2:
					return "Estable"
				3:
					return "Reconstrucción"
				_:
					return "Cualquiera"
		"min_reputation":
			return "%d+" % int(manager_preferences.get(key, 45))
	return "—"


func _manager_prefers_club(candidate: Team, current_team: Team) -> bool:
	if candidate == null or candidate.league_id <= 0:
		return false
	if candidate.reputation < int(manager_preferences.get("min_reputation", 45)):
		return false

	var preferred_level := int(manager_preferences.get("preferred_level", 0))
	if preferred_level > 0:
		var league := get_league(candidate.league_id)
		if league == null or league.level != preferred_level:
			return false

	var project_type := int(manager_preferences.get("project_type", 0))
	if project_type == 0:
		return true

	var baseline_rep := current_team.reputation if current_team != null else int(round(manager_global_reputation))
	match project_type:
		1:
			return candidate.reputation >= baseline_rep
		2:
			return abs(candidate.reputation - baseline_rep) <= 7
		3:
			return candidate.reputation <= baseline_rep
	return true


func _open_manager_career_entry(team: Team) -> void:
	if team == null:
		return
	if not manager_career_history.is_empty():
		var last: Dictionary = manager_career_history[manager_career_history.size() - 1]
		if int(last.get("team_id", -1)) == team.id and int(last.get("end_season", 0)) == 0:
			return
	manager_career_history.append({
		"team_id": team.id,
		"team_name": team.name,
		"start_season": season,
		"end_season": 0,
		"exit_reason": "",
	})


func _close_current_manager_career_entry(reason: String) -> void:
	for i: int in range(manager_career_history.size() - 1, -1, -1):
		var entry: Dictionary = manager_career_history[i]
		if int(entry.get("end_season", 0)) == 0:
			entry["end_season"] = season
			entry["exit_reason"] = reason
			manager_career_history[i] = entry
			return


func _register_manager_honour(title: String, team: Team) -> void:
	if team == null:
		return
	manager_honours.append({
		"season": season,
		"title": title,
		"team_id": team.id,
		"team_name": team.name,
	})


func setup_season_competitions() -> void:
	_setup_spanish_cup()


func get_cup_competition(key: String = CUP_DEL_REY_KEY) -> Dictionary:
	return cup_competitions.get(key, {})


func has_pending_cup_draw_presentations() -> bool:
	return not pending_cup_draw_presentations.is_empty()


func pop_next_cup_draw_presentation() -> Dictionary:
	if pending_cup_draw_presentations.is_empty():
		return {}
	var next_draw := pending_cup_draw_presentations[0]
	pending_cup_draw_presentations.remove_at(0)
	return next_draw


func get_fixture_competition_name(fixture: Dictionary) -> String:
	var key := str(fixture.get("competition", "league"))
	if key == CUP_DEL_REY_KEY:
		return CUP_DEL_REY_NAME
	return "Liga"


func get_fixture_round_name(fixture: Dictionary) -> String:
	if fixture.is_empty():
		return ""
	if str(fixture.get("competition", "league")) == CUP_DEL_REY_KEY:
		return str(fixture.get("round_name", CUP_DEL_REY_NAME))
	return "Jornada %d" % int(fixture.get("matchday", 0))


func resolve_competition_fixture(fixture: Dictionary) -> void:
	if str(fixture.get("competition", "league")) == CUP_DEL_REY_KEY:
		_resolve_cup_fixture(fixture)
		return
	LeagueManager._apply_result(fixture)
	var league := _find_league_for_fixture(fixture)
	if league != null:
		var md: int = fixture.get("matchday", 1)
		if md > league.current_matchday:
			league.current_matchday = md


func get_cup_team_ids() -> Array[int]:
	var result: Array[int] = []
	for cup: Dictionary in cup_competitions.values():
		for team_id: int in cup.get("participant_team_ids", []):
			if not result.has(team_id):
				result.append(team_id)
	return result


func get_cup_fixtures_for_team(team_id: int) -> Array[Dictionary]:
	var fixtures: Array[Dictionary] = []
	for cup: Dictionary in cup_competitions.values():
		for round: Dictionary in cup.get("rounds", []):
			for fixture: Dictionary in round.get("fixtures", []):
				if fixture.get("home_id", -1) == team_id or fixture.get("away_id", -1) == team_id:
					fixtures.append(fixture)
	fixtures.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _fixture_sort_key(a) < _fixture_sort_key(b)
	)
	return fixtures


func get_fixture_match_options(fixture: Dictionary) -> Dictionary:
	if fixture.is_empty() or str(fixture.get("competition", "league")) != CUP_DEL_REY_KEY:
		return {}
	if not bool(fixture.get("two_legs", false)):
		return {"knockout_single_leg": true}
	if int(fixture.get("leg", 1)) == 2:
		var aggregate := _get_second_leg_starting_aggregate(fixture)
		return {
			"knockout_on_aggregate_tie": true,
			"aggregate_home_start": int(aggregate.get("home", 0)),
			"aggregate_away_start": int(aggregate.get("away", 0)),
		}
	return {}


func _continue_current_week_if_needed() -> bool:
	if not active_fixture.is_empty() and not active_fixture.get("played", false):
		return true
	if not current_week_had_cup_fixture:
		week_in_progress = false
		return false
	var player_fixture := _process_current_week_league_round()
	if not player_fixture.is_empty():
		return true
	week_in_progress = false
	current_week_had_cup_fixture = false
	return false


func _process_current_week_league_round() -> Dictionary:
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
			_prepare_derby_for_fixture(player_fixture)
			emit_signal("player_match_ready", player_fixture)
			return player_fixture
		league.current_matchday = next_md
		emit_signal("matchday_done", next_md)
	return {}


func _prepare_derby_for_fixture(fixture: Dictionary) -> void:
	var derby_name: String = NewsManager.get_derby_name_by_id(
		fixture.get("home_id", -1), fixture.get("away_id", -1))
	active_derby_name = derby_name
	if derby_name == "":
		return
	var home_team: Team = get_team(fixture.get("home_id", -1))
	var away_team: Team = get_team(fixture.get("away_id", -1))
	if home_team == null or away_team == null:
		return
	var derby_team: Team = get_player_team()
	if derby_team != null:
		for derby_player_id: int in derby_team.player_ids:
			var derby_player: Player = get_player(derby_player_id)
			if derby_player != null:
				derby_player.morale = clampi(derby_player.morale + 10, 0, 100)
	NewsManager.add_derby_preview_news(home_team, away_team, derby_name)


func _team_position_in_standings(standings: Array, team_id: int) -> int:
	for i: int in range(standings.size()):
		var t: Team = standings[i] as Team
		if t != null and t.id == team_id:
			return i + 1
	return 0


func _update_manager_end_of_season_records(primera_standings: Array, segunda_standings: Array, transition: Dictionary) -> void:
	var team := get_player_team()
	if team == null:
		return

	var primera_pos := _team_position_in_standings(primera_standings, team.id)
	var segunda_pos := _team_position_in_standings(segunda_standings, team.id)
	if primera_pos == 1:
		_register_manager_honour("Campeón de Primera División", team)
		manager_global_reputation = clampf(manager_global_reputation + 12.0, 1.0, 100.0)
	elif primera_pos > 0 and primera_pos <= 4:
		manager_global_reputation = clampf(manager_global_reputation + 4.0, 1.0, 100.0)
	elif primera_pos > 0 and primera_pos <= 6:
		manager_global_reputation = clampf(manager_global_reputation + 2.0, 1.0, 100.0)
	elif primera_pos > primera_standings.size() - 3 and primera_standings.size() > 0:
		manager_global_reputation = clampf(manager_global_reputation - 5.0, 1.0, 100.0)

	if segunda_pos == 1:
		_register_manager_honour("Campeón de Segunda División", team)
		manager_global_reputation = clampf(manager_global_reputation + 6.0, 1.0, 100.0)
	if team in transition.get("promoted", []):
		var honour := "Ascenso a Primera División"
		if transition.get("playoff_winner", null) == team:
			honour = "Ascenso a Primera División (playoff)"
		_register_manager_honour(honour, team)
		manager_global_reputation = clampf(manager_global_reputation + 8.0, 1.0, 100.0)
	if team in transition.get("second_relegated", []):
		manager_global_reputation = clampf(manager_global_reputation - 8.0, 1.0, 100.0)


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
	var player_cup_fixtures := get_cup_fixtures_for_team(player_team_id)
	for cup_fixture: Dictionary in player_cup_fixtures:
		if cup_fixture.get("played", false):
			continue
		if _date_key(cup_fixture.get("scheduled_date", {})) <= _date_key(current_date):
			return cup_fixture
	for league: League in leagues.values():
		for md: int in range(league.current_matchday + 1, league.get_total_matchdays() + 2):
			for f: Dictionary in league.get_fixtures_for_matchday(md):
				if not f.get("played", false) and (f["home_id"] == player_team_id or f["away_id"] == player_team_id):
					return f
	for future_cup_fixture: Dictionary in player_cup_fixtures:
		if not future_cup_fixture.get("played", false):
			return future_cup_fixture
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
	cup_competitions.clear()
	pending_cup_draw_presentations.clear()
	active_fixture = {}
	active_derby_name = ""
	tactics_badge_active = false
	week_in_progress = false
	current_week_had_cup_fixture = false
	free_coaches.clear()
	manager_rating    = 5.0
	board_confidence  = 5.0
	public_confidence = 5.0
	bonus_win         = 0
	bonus_title       = 0
	bonus_history.clear()
	manager_matches = 0
	manager_wins = 0
	manager_draws = 0
	manager_losses = 0
	manager_clubs_managed.clear()
	manager_offers_received = 0
	manager_offers_accepted = 0
	manager_job_offers.clear()
	manager_global_reputation = 50.0
	manager_honours.clear()
	manager_career_history.clear()
	manager_preferences = {
		"preferred_level": 0,
		"project_type": 0,
		"min_reputation": 45,
	}
	_last_spanish_transition.clear()
	_next_player_id = 1
	_next_team_id = 1
	_next_league_id = 1
	_next_manager_offer_id = 1


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


func configure_reserve_replacement_pool(country: String, pool: Array) -> void:
	reserve_replacement_pool[country] = pool.duplicate(true)


func _are_domestic_competitions_finished() -> bool:
	if leagues.is_empty():
		return false
	for league: League in leagues.values():
		if league.current_matchday < league.get_total_matchdays():
			return false
	for cup: Dictionary in cup_competitions.values():
		if int(cup.get("winner_team_id", -1)) == -1:
			return false
	return true


func _setup_spanish_cup() -> void:
	var participant_ids: Array[int] = []
	for league: League in leagues.values():
		if league.country != "España":
			continue
		for team_id: int in league.team_ids:
			if not participant_ids.has(team_id):
				participant_ids.append(team_id)

	var extra_needed := maxi(0, CUP_DEL_REY_TARGET_TEAMS - participant_ids.size())
	var invited_ids := _ensure_cup_invited_teams(extra_needed)
	for invited_id: int in invited_ids:
		if not participant_ids.has(invited_id):
			participant_ids.append(invited_id)

	var cup := {
		"key": CUP_DEL_REY_KEY,
		"name": CUP_DEL_REY_NAME,
		"logo_path": CUP_DEL_REY_LOGO_PATH,
		"season": season,
		"participant_team_ids": participant_ids,
		"invited_team_ids": invited_ids,
		"winner_team_id": -1,
		"rounds": _build_cup_round_templates(),
	}
	cup_competitions[CUP_DEL_REY_KEY] = cup


func _build_cup_round_templates() -> Array[Dictionary]:
	return [
		{
			"order": 1,
			"key": "round_1",
			"name": "Primera ronda",
			"draw_date": _make_date(31, 10, season),
			"play_date": _make_date(31, 10, season),
			"two_legs": false,
			"neutral": false,
			"drawn": false,
			"completed": false,
			"fixtures": [],
			"winners": [],
		},
		{
			"order": 2,
			"key": "round_2",
			"name": "Segunda ronda",
			"draw_date": _make_date(5, 12, season),
			"play_date": _make_date(5, 12, season),
			"two_legs": false,
			"neutral": false,
			"drawn": false,
			"completed": false,
			"fixtures": [],
			"winners": [],
		},
		{
			"order": 3,
			"key": "round_3",
			"name": "Tercera ronda",
			"draw_date": _make_date(16, 1, season + 1),
			"play_date": _make_date(16, 1, season + 1),
			"two_legs": false,
			"neutral": false,
			"drawn": false,
			"completed": false,
			"fixtures": [],
			"winners": [],
		},
		{
			"order": 4,
			"key": "round_4",
			"name": "Cuarta ronda",
			"draw_date": _make_date(6, 2, season + 1),
			"play_date": _make_date(6, 2, season + 1),
			"two_legs": false,
			"neutral": false,
			"drawn": false,
			"completed": false,
			"fixtures": [],
			"winners": [],
		},
		{
			"order": 5,
			"key": "semifinals",
			"name": "Semifinales",
			"draw_date": _make_date(6, 2, season + 1),
			"play_date": _make_date(27, 2, season + 1),
			"second_leg_date": _make_date(6, 3, season + 1),
			"two_legs": true,
			"neutral": false,
			"drawn": false,
			"completed": false,
			"fixtures": [],
			"winners": [],
		},
		{
			"order": 6,
			"key": "final",
			"name": "Final",
			"draw_date": _make_date(6, 3, season + 1),
			"play_date": _make_date(17, 4, season + 1),
			"two_legs": false,
			"neutral": true,
			"drawn": false,
			"completed": false,
			"fixtures": [],
			"winners": [],
		},
	]


func _ensure_cup_invited_teams(required_count: int) -> Array[int]:
	var invited: Array[int] = []
	for entry: Dictionary in DataGenerator.SECOND_DIVISION_REPLACEMENT_POOL:
		if invited.size() >= required_count:
			break
		var existing := _find_team_by_name(str(entry.get("name", "")))
		if existing != null:
			invited.append(existing.id)
			continue
		var t := Team.new()
		t.name = str(entry.get("name", "Equipo Copa"))
		t.short_name = str(entry.get("short_name", "COP"))
		t.city = str(entry.get("city", t.name))
		t.reputation = int(entry.get("reputation", 52))
		t.stadium_name = str(entry.get("stadium_name", "Estadio Municipal"))
		t.stadium_capacity = int(entry.get("stadium_capacity", 14_000))
		t.crest = str(entry.get("crest", DataGenerator.TEAM_CRESTS.get(t.name, "")))
		t.stadium_image = DataGenerator.TEAM_STADIUMS.get(t.name, "")
		t.coach_name = DataGenerator.TEAM_COACHES.get(t.name, "")
		t.budget = t.reputation * 80_000
		t.weekly_wage_budget = t.reputation * 5_000
		t.club_cash = t.reputation * 280_000
		t.league_id = 0
		register_team(t)
		DataGenerator._fill_squad(t)
		invited.append(t.id)
	return invited


func _find_team_by_name(team_name: String) -> Team:
	for team: Team in teams.values():
		if team.name == team_name:
			return team
	return null


func _maybe_draw_due_cup_rounds() -> void:
	var cup := get_cup_competition()
	if cup.is_empty():
		return
	var rounds: Array = cup.get("rounds", [])
	for round_index: int in range(rounds.size()):
		var round: Dictionary = rounds[round_index]
		if round.get("drawn", false):
			continue
		if round_index > 0:
			var previous_round: Dictionary = rounds[round_index - 1]
			if not previous_round.get("completed", false):
				break
		if _date_key(current_date) < _date_key(round.get("draw_date", {})):
			break
		var entrants: Array[int] = []
		if round_index == 0:
			entrants.assign(cup.get("participant_team_ids", []))
		else:
			entrants.assign(rounds[round_index - 1].get("winners", []))
		round["fixtures"] = _draw_cup_round(round, entrants)
		round["drawn"] = true
		NewsManager.add_cup_draw_news(str(round.get("name", "Ronda")), round.get("fixtures", []))
		pending_cup_draw_presentations.append({
			"competition_name": cup.get("name", CUP_DEL_REY_NAME),
			"round_name": round.get("name", "Ronda"),
			"draw_date": round.get("draw_date", {}).duplicate(true),
			"fixtures": round.get("fixtures", []).duplicate(true),
		})
		rounds[round_index] = round
		cup["rounds"] = rounds
		cup_competitions[CUP_DEL_REY_KEY] = cup


func _draw_cup_round(round: Dictionary, entrants: Array[int]) -> Array[Dictionary]:
	var shuffled := entrants.duplicate()
	shuffled.shuffle()
	var fixtures: Array[Dictionary] = []
	for i: int in range(0, shuffled.size(), 2):
		if i + 1 >= shuffled.size():
			break
		var first_team_id: int = shuffled[i]
		var second_team_id: int = shuffled[i + 1]
		var pairing := _resolve_cup_pairing(first_team_id, second_team_id, round)
		var pair_number := int(i / 2) + 1
		fixtures.append(_build_cup_fixture(round, pair_number, 1, pairing.get("home_id", first_team_id), pairing.get("away_id", second_team_id), round.get("play_date", {}), bool(round.get("neutral", false))))
		if round.get("two_legs", false):
			fixtures.append(_build_cup_fixture(round, pair_number, 2, pairing.get("away_id", second_team_id), pairing.get("home_id", first_team_id), round.get("second_leg_date", {}), false))
	return fixtures


func _resolve_cup_pairing(first_team_id: int, second_team_id: int, round: Dictionary) -> Dictionary:
	if round.get("neutral", false):
		return {"home_id": first_team_id, "away_id": second_team_id}
	var first_category := _get_team_competition_category(first_team_id)
	var second_category := _get_team_competition_category(second_team_id)
	if first_category > second_category:
		return {"home_id": first_team_id, "away_id": second_team_id}
	if second_category > first_category:
		return {"home_id": second_team_id, "away_id": first_team_id}
	return {"home_id": first_team_id, "away_id": second_team_id}


func _get_team_competition_category(team_id: int) -> int:
	var team := get_team(team_id)
	if team == null:
		return 99
	var league := get_league(team.league_id)
	if league != null and league.country == "España":
		return maxi(1, league.level)
	return 3


func _build_cup_fixture(round: Dictionary, pair_number: int, leg: int, home_id: int, away_id: int, scheduled_date: Dictionary, neutral_venue: bool) -> Dictionary:
	return {
		"competition": CUP_DEL_REY_KEY,
		"competition_name": CUP_DEL_REY_NAME,
		"round_key": str(round.get("key", "round")),
		"round_name": str(round.get("name", CUP_DEL_REY_NAME)),
		"matchday": int(round.get("order", 0)),
		"pair_id": "%s_%d" % [str(round.get("key", "round")), pair_number],
		"leg": leg,
		"week_slot": "midweek" if str(round.get("key", "")) != "final" else "weekend",
		"two_legs": bool(round.get("two_legs", false)),
		"home_id": home_id,
		"away_id": away_id,
		"home_goals": -1,
		"away_goals": -1,
		"played": false,
		"winner_id": -1,
		"scheduled_date": scheduled_date.duplicate(true),
		"neutral_venue": neutral_venue,
		"venue_name": CUP_DEL_REY_FINAL_VENUE if neutral_venue else "",
	}


func _process_due_cup_matches() -> Dictionary:
	var cup := get_cup_competition()
	if cup.is_empty():
		return {}
	var rounds: Array = cup.get("rounds", [])
	for round_index: int in range(rounds.size()):
		var round: Dictionary = rounds[round_index]
		if not round.get("drawn", false) or round.get("completed", false):
			continue
		var fixtures: Array = round.get("fixtures", [])
		var player_fixture: Dictionary = {}
		for fixture: Dictionary in fixtures:
			if fixture.get("played", false):
				continue
			if _date_key(fixture.get("scheduled_date", {})) != _date_key(current_date):
				continue
			if fixture.get("home_id", -1) == player_team_id or fixture.get("away_id", -1) == player_team_id:
				player_fixture = fixture
			else:
				_simulate_ai_cup_match(fixture)
		round["fixtures"] = fixtures
		rounds[round_index] = round
		cup["rounds"] = rounds
		cup_competitions[CUP_DEL_REY_KEY] = cup
		_finalize_cup_round_if_ready(round_index)
		if not player_fixture.is_empty():
			return player_fixture
	return {}


func _simulate_ai_cup_match(fixture: Dictionary) -> void:
	var home_team: Team = get_team(fixture.get("home_id", -1))
	var away_team: Team = get_team(fixture.get("away_id", -1))
	if home_team == null or away_team == null:
		return
	var result: Dictionary = MatchSimulator.simulate_match(home_team, away_team, get_fixture_match_options(fixture))
	fixture["home_goals"] = result.get("home_goals", 0)
	fixture["away_goals"] = result.get("away_goals", 0)
	fixture["winner_id"] = result.get("winner_id", -1)
	fixture["decided_by"] = result.get("decided_by", "normal_time")
	if result.has("after_extra_time"):
		fixture["after_extra_time"] = result.get("after_extra_time", false)
	if result.has("penalties_home"):
		fixture["penalties_home"] = result.get("penalties_home", 0)
		fixture["penalties_away"] = result.get("penalties_away", 0)
	fixture["played"] = true
	_resolve_cup_fixture(fixture)


func _resolve_cup_fixture(fixture: Dictionary) -> void:
	var cup := get_cup_competition()
	if cup.is_empty():
		return
	var rounds: Array = cup.get("rounds", [])
	var round_index := _get_cup_round_index(str(fixture.get("round_key", "")))
	if round_index == -1:
		return
	var round: Dictionary = rounds[round_index]
	var fixtures: Array = round.get("fixtures", [])
	if not round.get("two_legs", false):
		fixture["winner_id"] = _resolve_single_leg_winner(fixture)
	elif int(fixture.get("leg", 1)) == 2:
		var winner_id := _resolve_two_leg_winner(fixtures, str(fixture.get("pair_id", "")))
		fixture["winner_id"] = winner_id
		for leg_fixture: Dictionary in fixtures:
			if leg_fixture.get("pair_id", "") == fixture.get("pair_id", ""):
				leg_fixture["winner_id"] = winner_id
	round["fixtures"] = fixtures
	rounds[round_index] = round
	cup["rounds"] = rounds
	cup_competitions[CUP_DEL_REY_KEY] = cup
	NewsManager.add_cup_result_news(fixture)
	_finalize_cup_round_if_ready(round_index)


func _resolve_single_leg_winner(fixture: Dictionary) -> int:
	if int(fixture.get("winner_id", -1)) != -1:
		return int(fixture.get("winner_id", -1))
	var home_goals := int(fixture.get("home_goals", 0))
	var away_goals := int(fixture.get("away_goals", 0))
	if home_goals > away_goals:
		return int(fixture.get("home_id", -1))
	if away_goals > home_goals:
		return int(fixture.get("away_id", -1))
	return int(fixture.get("home_id", -1)) if randf() < 0.5 else int(fixture.get("away_id", -1))


func _resolve_two_leg_winner(fixtures: Array, pair_id: String) -> int:
	var first_leg: Dictionary = {}
	var second_leg: Dictionary = {}
	for fixture: Dictionary in fixtures:
		if fixture.get("pair_id", "") != pair_id:
			continue
		if int(fixture.get("leg", 1)) == 1:
			first_leg = fixture
		else:
			second_leg = fixture
	if first_leg.is_empty() or second_leg.is_empty():
		return -1
	var team_a: int = first_leg.get("home_id", -1)
	var team_b: int = first_leg.get("away_id", -1)
	var agg_a := int(first_leg.get("home_goals", 0)) + int(second_leg.get("away_goals", 0))
	var agg_b := int(first_leg.get("away_goals", 0)) + int(second_leg.get("home_goals", 0))
	if agg_a > agg_b:
		return team_a
	if agg_b > agg_a:
		return team_b
	if int(second_leg.get("winner_id", -1)) != -1:
		return int(second_leg.get("winner_id", -1))
	return team_a if randf() < 0.5 else team_b


func _get_second_leg_starting_aggregate(fixture: Dictionary) -> Dictionary:
	var cup := get_cup_competition()
	if cup.is_empty():
		return {"home": 0, "away": 0}
	var round_index := _get_cup_round_index(str(fixture.get("round_key", "")))
	if round_index == -1:
		return {"home": 0, "away": 0}
	var rounds: Array = cup.get("rounds", [])
	var round: Dictionary = rounds[round_index]
	for candidate: Dictionary in round.get("fixtures", []):
		if candidate.get("pair_id", "") != fixture.get("pair_id", ""):
			continue
		if int(candidate.get("leg", 1)) != 1:
			continue
		return {
			"home": int(candidate.get("away_goals", 0)),
			"away": int(candidate.get("home_goals", 0)),
		}
	return {"home": 0, "away": 0}


func _finalize_cup_round_if_ready(round_index: int) -> void:
	var cup := get_cup_competition()
	if cup.is_empty():
		return
	var rounds: Array = cup.get("rounds", [])
	if round_index < 0 or round_index >= rounds.size():
		return
	var round: Dictionary = rounds[round_index]
	if round.get("completed", false) or not round.get("drawn", false):
		return
	var fixtures: Array = round.get("fixtures", [])
	for fixture: Dictionary in fixtures:
		if not fixture.get("played", false):
			return
	var winners: Array[int] = []
	if round.get("two_legs", false):
		var seen_pairs: Dictionary = {}
		for fixture: Dictionary in fixtures:
			var pair_id := str(fixture.get("pair_id", ""))
			if seen_pairs.has(pair_id):
				continue
			seen_pairs[pair_id] = true
			var winner_id := _resolve_two_leg_winner(fixtures, pair_id)
			if winner_id != -1:
				winners.append(winner_id)
	else:
		for fixture: Dictionary in fixtures:
			var winner_id := int(fixture.get("winner_id", -1))
			if winner_id == -1:
				winner_id = _resolve_single_leg_winner(fixture)
				fixture["winner_id"] = winner_id
			winners.append(winner_id)
	round["winners"] = winners
	round["completed"] = true
	round["fixtures"] = fixtures
	rounds[round_index] = round
	cup["rounds"] = rounds
	_apply_cup_round_payouts(round, winners)
	if str(round.get("key", "")) == "final" and not winners.is_empty():
		cup["winner_team_id"] = winners[0]
		var champion := get_team(winners[0])
		if champion != null and champion.id == player_team_id:
			_register_manager_honour("Campeón de la Copa del Rey", champion)
			manager_global_reputation = clampf(manager_global_reputation + 10.0, 1.0, 100.0)
	cup_competitions[CUP_DEL_REY_KEY] = cup


func _apply_cup_round_payouts(round: Dictionary, winners: Array[int]) -> void:
	var payout: Dictionary = CUP_DEL_REY_PAYOUTS.get(str(round.get("key", "")), {})
	var played_bonus := int(payout.get("played", 0))
	var win_bonus := int(payout.get("win", 0))
	var paid_teams: Dictionary = {}
	for fixture: Dictionary in round.get("fixtures", []):
		for team_id: int in [int(fixture.get("home_id", -1)), int(fixture.get("away_id", -1))]:
			if team_id == -1 or paid_teams.has(team_id):
				continue
			var team := get_team(team_id)
			if team != null:
				team.club_cash += played_bonus
			paid_teams[team_id] = true
	for winner_id: int in winners:
		var winner := get_team(winner_id)
		if winner != null:
			winner.club_cash += win_bonus


func _get_cup_round_index(round_key: String) -> int:
	var cup := get_cup_competition()
	if cup.is_empty():
		return -1
	var rounds: Array = cup.get("rounds", [])
	for i: int in range(rounds.size()):
		if str((rounds[i] as Dictionary).get("key", "")) == round_key:
			return i
	return -1


func _find_league_for_fixture(fixture: Dictionary) -> League:
	for league: League in leagues.values():
		for league_fixture: Dictionary in league.fixtures:
			if league_fixture.get("home_id") == fixture.get("home_id") and \
				league_fixture.get("away_id") == fixture.get("away_id") and \
				league_fixture.get("matchday") == fixture.get("matchday"):
				return league
	return null


func _fixture_sort_key(fixture: Dictionary) -> int:
	var scheduled := fixture.get("scheduled_date", {})
	if not (scheduled as Dictionary).is_empty():
		return _date_key(scheduled)
	return 10_000_000 + int(fixture.get("matchday", 0))


func _date_key(date: Dictionary) -> int:
	if date.is_empty():
		return 0
	return int(date.get("year", season)) * 10_000 + int(date.get("month", 1)) * 100 + int(date.get("day", 1))


func _make_date(day: int, month: int, year: int) -> Dictionary:
	return {"day": day, "month": month, "year": year}


func process_end_of_season_spanish_leagues() -> Dictionary:
	var primera := get_league_by_country_level("España", 1)
	var segunda := get_league_by_country_level("España", 2)
	if primera == null or segunda == null:
		_last_spanish_transition = {}
		return _last_spanish_transition

	var primera_standings: Array = LeagueManager.get_standings(primera)
	var segunda_standings: Array = LeagueManager.get_standings(segunda)
	if primera_standings.size() < 3 or segunda_standings.size() < 6:
		_last_spanish_transition = {}
		return _last_spanish_transition
	var player_team_before: Team = get_player_team()

	var relegated: Array[Team] = []
	for i: int in range(primera_standings.size() - 3, primera_standings.size()):
		relegated.append(primera_standings[i] as Team)
	var relegated_names: Array[String] = []
	for t: Team in relegated:
		relegated_names.append(t.name)

	var promoted: Array[Team] = []
	var blocked_reserves: Array[String] = []
	for i: int in range(0, mini(2, segunda_standings.size())):
		var t: Team = segunda_standings[i] as Team
		if _is_eligible_for_promotion(t, primera, relegated_names):
			promoted.append(t)
		elif t.is_reserve_team:
			blocked_reserves.append(t.name)

	var playoff_candidates: Array[Team] = []
	for i: int in range(2, mini(6, segunda_standings.size())):
		var t: Team = segunda_standings[i] as Team
		if _is_eligible_for_promotion(t, primera, relegated_names):
			playoff_candidates.append(t)
		elif t.is_reserve_team:
			blocked_reserves.append(t.name)

	var playoff_winner: Team = _simulate_playoff_winner(playoff_candidates)
	if playoff_winner != null and not promoted.has(playoff_winner):
		promoted.append(playoff_winner)

	# Si alguna plaza queda vacante por filiales bloqueados, pasa al siguiente clasificado elegible.
	if promoted.size() < 3:
		for i: int in range(2, segunda_standings.size()):
			var t: Team = segunda_standings[i] as Team
			if _is_eligible_for_promotion(t, primera, relegated_names) and not promoted.has(t):
				promoted.append(t)
				if promoted.size() >= 3:
					break

	var reserve_dropped: Array[Team] = _collect_admin_reserve_relegations(relegated_names, segunda_standings)
	var second_relegated: Array[Team] = _build_second_division_relegations(segunda_standings, reserve_dropped)

	var swaps: int = mini(relegated.size(), promoted.size())
	for i: int in range(swaps):
		_move_team_to_league(promoted[i], segunda, primera)
		_move_team_to_league(relegated[i], primera, segunda)

	for t: Team in second_relegated:
		segunda.team_ids.erase(t.id)
		t.league_id = 0

	var second_promoted_from_pool: Array[Team] = []
	for _slot: int in range(second_relegated.size()):
		var replacement: Team = _promote_replacement_to_second_division(segunda)
		if replacement != null:
			replacement.league_id = segunda.id
			segunda.team_ids.append(replacement.id)
			second_promoted_from_pool.append(replacement)

	_last_spanish_transition = {
		"promoted": promoted,
		"relegated": relegated,
		"second_relegated": second_relegated,
		"second_promoted_from_pool": second_promoted_from_pool,
		"playoff_winner": playoff_winner,
		"blocked_reserves": blocked_reserves,
		"reserve_dropped": reserve_dropped,
	}
	if player_team_before != null:
		_update_manager_end_of_season_records(primera_standings, segunda_standings, _last_spanish_transition)
	_handle_player_manager_relegation(_last_spanish_transition)
	return _last_spanish_transition


func apply_end_of_season_prizes(transition: Dictionary = {}) -> void:
	for league: League in leagues.values():
		var standings: Array = LeagueManager.get_standings(league)
		var positional: Array[int] = _position_prize_table(league.level, standings.size())
		for i: int in range(mini(standings.size(), positional.size())):
			var t: Team = standings[i] as Team
			t.club_cash += positional[i]

		if league.country == "España" and league.level == 1:
			for i: int in range(mini(6, standings.size())):
				var t: Team = standings[i] as Team
				if i == 0:
					t.club_cash += 12_000_000  # campeón de liga
				elif i <= 3:
					t.club_cash += 8_000_000   # plazas Champions
				else:
					t.club_cash += 4_000_000   # plazas europeas adicionales

	if transition.is_empty():
		transition = _last_spanish_transition

	for t: Team in transition.get("promoted", []):
		if t:
			t.club_cash += 10_000_000  # prima de ascenso


func get_league_by_country_level(country: String, level: int) -> League:
	for league: League in leagues.values():
		if league.country == country and league.level == level:
			return league
	return null


func _is_eligible_for_promotion(candidate: Team, target_league: League, relegated_parent_names: Array[String] = []) -> bool:
	if candidate == null:
		return false
	if not candidate.is_reserve_team:
		return true
	if candidate.parent_club_name.is_empty():
		return true
	if relegated_parent_names.has(candidate.parent_club_name):
		return true
	for tid: int in target_league.team_ids:
		var t: Team = get_team(tid)
		if t != null and t.name == candidate.parent_club_name:
			return false
	return true


func _simulate_playoff_winner(candidates: Array[Team]) -> Team:
	if candidates.is_empty():
		return null
	if candidates.size() == 1:
		return candidates[0]
	if candidates.size() == 2:
		return _simulate_knockout_match(candidates[0], candidates[1])
	if candidates.size() == 3:
		var final_a: Team = _simulate_knockout_match(candidates[1], candidates[2])
		return _simulate_knockout_match(candidates[0], final_a)

	var semi_a: Team = _simulate_knockout_match(candidates[0], candidates[3])
	var semi_b: Team = _simulate_knockout_match(candidates[1], candidates[2])
	return _simulate_knockout_match(semi_a, semi_b)


func _simulate_knockout_match(home: Team, away: Team) -> Team:
	var home_score := float(home.reputation) * randf_range(0.85, 1.15) + 2.5
	var away_score := float(away.reputation) * randf_range(0.85, 1.15)
	if home_score >= away_score:
		return home
	return away


func _move_team_to_league(team: Team, from_league: League, to_league: League) -> void:
	if team == null or from_league == null or to_league == null:
		return
	from_league.team_ids.erase(team.id)
	if not to_league.team_ids.has(team.id):
		to_league.team_ids.append(team.id)
	team.league_id = to_league.id


func _collect_admin_reserve_relegations(relegated_parent_names: Array[String], segunda_standings: Array) -> Array[Team]:
	var dropped: Array[Team] = []
	for t: Team in segunda_standings:
		if t != null and t.is_reserve_team and relegated_parent_names.has(t.parent_club_name):
			dropped.append(t)
	return dropped


func _build_second_division_relegations(segunda_standings: Array, admin_relegated: Array[Team]) -> Array[Team]:
	var down: Array[Team] = []
	for t: Team in admin_relegated:
		if t != null and not down.has(t):
			down.append(t)

	if admin_relegated.is_empty():
		for i: int in range(maxi(0, segunda_standings.size() - 4), segunda_standings.size()):
			var t: Team = segunda_standings[i] as Team
			if t != null and not down.has(t):
				down.append(t)
		return down

	# Con descenso administrativo: descienden los 3 últimos + el/los afectados.
	for i: int in range(maxi(0, segunda_standings.size() - 3), segunda_standings.size()):
		var t: Team = segunda_standings[i] as Team
		if t != null and not down.has(t):
			down.append(t)

	return down


func _promote_replacement_to_second_division(segunda: League) -> Team:
	var pool: Array = reserve_replacement_pool.get("España", [])
	if not pool.is_empty():
		var entry: Dictionary = pool[0]
		pool.remove_at(0)
		reserve_replacement_pool["España"] = pool
		return _create_team_from_pool_entry(entry, segunda)

	# Fallback: mantener tamaño de liga estable hasta que exista cartera real.
	var fallback := Team.new()
	fallback.name = "Ascenso pendiente %d" % _next_team_id
	fallback.short_name = "TBD"
	fallback.city = "España"
	fallback.reputation = 50
	fallback.stadium_name = "Estadio Municipal"
	fallback.stadium_capacity = 12_000
	fallback.crest = ""
	fallback.budget = 4_000_000
	fallback.weekly_wage_budget = 250_000
	fallback.club_cash = 8_000_000
	fallback.league_id = segunda.id
	register_team(fallback)
	DataGenerator._fill_squad(fallback)
	return fallback


func _create_team_from_pool_entry(entry: Dictionary, segunda: League) -> Team:
	var existing := _find_team_by_name(str(entry.get("name", "")))
	if existing != null:
		existing.league_id = segunda.id
		return existing
	var t := Team.new()
	t.name = str(entry.get("name", "Equipo Ascendido"))
	t.short_name = str(entry.get("short_name", "ASC"))
	t.city = str(entry.get("city", t.name))
	t.reputation = int(entry.get("reputation", 52))
	t.stadium_name = str(entry.get("stadium_name", "Estadio Municipal"))
	t.stadium_capacity = int(entry.get("stadium_capacity", 14_000))
	t.crest = str(entry.get("crest", DataGenerator.TEAM_CRESTS.get(t.name, "")))
	t.stadium_image = DataGenerator.TEAM_STADIUMS.get(t.name, "")
	t.budget = t.reputation * 80_000
	t.weekly_wage_budget = t.reputation * 5_000
	t.club_cash = t.reputation * 300_000
	t.league_id = segunda.id
	register_team(t)
	DataGenerator._fill_squad(t)
	return t


func _position_prize_table(level: int, size: int) -> Array[int]:
	if level == 1:
		var la_liga: Array[int] = [
			20_000_000, 16_000_000, 14_000_000, 12_000_000, 10_000_000,
			9_000_000, 8_000_000, 7_000_000, 6_000_000, 5_000_000,
			4_500_000, 4_000_000, 3_500_000, 3_000_000, 2_600_000,
			2_300_000, 2_000_000, 1_700_000, 1_500_000, 1_300_000,
		]
		return la_liga.slice(0, mini(size, la_liga.size()))

	if level == 2:
		var segunda: Array[int] = [
			8_000_000, 7_200_000, 6_700_000, 6_200_000, 5_800_000, 5_400_000,
			5_000_000, 4_600_000, 4_200_000, 3_900_000, 3_600_000,
			3_300_000, 3_000_000, 2_700_000, 2_400_000, 2_200_000,
			2_000_000, 1_800_000, 1_600_000, 1_450_000, 1_300_000, 1_200_000,
		]
		return segunda.slice(0, mini(size, segunda.size()))

	var generic: Array[int] = []
	for i: int in range(size):
		generic.append(maxi(400_000, 2_000_000 - i * 80_000))
	return generic
