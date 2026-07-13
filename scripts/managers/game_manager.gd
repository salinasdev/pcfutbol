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
				var res: Dictionary = MatchSimulator.simulate_match(ht, at)
				f["home_goals"] = res["home_goals"]
				f["away_goals"] = res["away_goals"]
				f["played"]     = true
				LeagueManager._apply_result(f)
				LeagueManager.simulate_sanctions_for_ia(ht, at)

		if not player_fixture.is_empty():
			active_fixture = player_fixture
			emit_signal("player_match_ready", player_fixture)
		else:
			league.current_matchday = next_md
			emit_signal("matchday_done", next_md)

	NewsManager.generate_weekly_news()

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

# ---------------------------------------------------------------------------

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
