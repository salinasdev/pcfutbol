extends Node

## Genera el calendario completo de una liga (ida y vuelta) usando round-robin
func generate_fixtures(league: League) -> void:
	league.fixtures.clear()
	league.current_matchday = 0

	var ids := league.team_ids.duplicate()
	var n := ids.size()
	if n < 2:
		return
	if n % 2 != 0:
		ids.append(-1)  # placeholder para jornada libre
		n += 1

	var half := n / 2
	var rounds := n - 1

	for round_idx in range(rounds):
		for i in range(half):
			var home: int = ids[i]
			var away: int = ids[n - 1 - i]
			if home != -1 and away != -1:
				league.fixtures.append({
					"matchday":   round_idx + 1,
					"home_id":    home,
					"away_id":    away,
					"home_goals": -1,
					"away_goals": -1,
					"played":     false
				})
		# Rotar manteniendo ids[0] fijo
		var last: int = ids[n - 1]
		for i in range(n - 1, 1, -1):
			ids[i] = ids[i - 1]
		ids[1] = last

	# Generar vuelta (intercambiar local/visitante, desplazar jornada)
	var first_leg := league.fixtures.duplicate()
	for f: Dictionary in first_leg:
		league.fixtures.append({
			"matchday":   f["matchday"] + rounds,
			"home_id":    f["away_id"],
			"away_id":    f["home_id"],
			"home_goals": -1,
			"away_goals": -1,
			"played":     false
		})


## Simula todos los partidos no jugados de una jornada concreta
func simulate_matchday(league: League, matchday: int) -> void:
	for fixture: Dictionary in league.fixtures:
		if fixture["matchday"] == matchday and not fixture["played"]:
			var home_team: Team = GameManager.get_team(fixture["home_id"])
			var away_team: Team = GameManager.get_team(fixture["away_id"])
			var result: Dictionary = MatchSimulator.simulate_match(home_team, away_team)
			fixture["home_goals"] = result["home_goals"]
			fixture["away_goals"] = result["away_goals"]
			fixture["played"]     = true
			_apply_result(fixture)
	league.current_matchday = matchday


## Devuelve los equipos ordenados: puntos → diferencia de goles → goles a favor
func get_standings(league: League) -> Array:
	var standing: Array = []
	for tid: int in league.team_ids:
		var t: Team = GameManager.get_team(tid)
		if t:
			standing.append(t)

	standing.sort_custom(func(a: Team, b: Team) -> bool:
		if a.get_points() != b.get_points():
			return a.get_points() > b.get_points()
		if a.get_goal_difference() != b.get_goal_difference():
			return a.get_goal_difference() > b.get_goal_difference()
		return a.goals_for > b.goals_for
	)
	return standing


func _apply_result(fixture: Dictionary) -> void:
	var home: Team = GameManager.get_team(fixture["home_id"])
	var away: Team = GameManager.get_team(fixture["away_id"])
	if home == null or away == null:
		return

	home.goals_for     += fixture["home_goals"]
	home.goals_against += fixture["away_goals"]
	away.goals_for     += fixture["away_goals"]
	away.goals_against += fixture["home_goals"]

	if fixture["home_goals"] > fixture["away_goals"]:
		home.wins   += 1
		away.losses += 1
	elif fixture["home_goals"] < fixture["away_goals"]:
		away.wins   += 1
		home.losses += 1
	else:
		home.draws += 1
		away.draws += 1


## Aplica sanciones disciplinarias tras un partido.
## ft_event: el evento FULL_TIME que contiene red_card_ids y yellow_ids.
## También simula tarjetas para partidos de IA si no tiene eventos detallados.
func apply_match_sanctions(ft_event: Dictionary) -> void:
	# Expulsados: sancionados para el siguiente partido
	for pid: int in ft_event.get("red_card_ids", []):
		var p: Player = GameManager.get_player(pid)
		if p:
			p.suspended = true

	# Amonestados: sumar tarjeta amarilla; sanción al llegar a 5
	for pid: int in ft_event.get("yellow_ids", []):
		var p: Player = GameManager.get_player(pid)
		if p:
			p.yellow_cards += 1
			if p.yellow_cards > 0 and p.yellow_cards % 5 == 0:
				p.suspended = true

	# Lesionados: baja N partidos
	var injured: Dictionary = ft_event.get("injured_ids", {})
	for raw_key in injured.keys():
		var pid: int = int(raw_key)
		var p: Player = GameManager.get_player(pid)
		if p and not p.injured:
			p.injured      = true
			p.injury_weeks = int(injured[raw_key])
			p.suspended    = true


## Limpia la sanción de jugadores que acaban de cumplirla (un partido fuera).
## Llama al final del partido del equipo del jugador.
## También descuenta un partido de baja a los lesionados.
func consume_suspensions(team: Team) -> void:
	for pid: int in team.player_ids:
		var p: Player = GameManager.get_player(pid)
		if p == null:
			continue
		if p.injured:
			p.injury_weeks -= 1
			if p.injury_weeks <= 0:
				p.injured      = false
				p.injury_weeks = 0
				p.suspended    = false
			## Si sigue lesionado, suspended permanece true
		elif p.suspended:
			p.suspended = false  ## Cumplió sanción de tarjetas/roja


## Genera sanciones ficticias para partidos de IA (sin eventos reales)
func simulate_sanctions_for_ia(home: Team, away: Team) -> void:
	for team: Team in [home, away]:
		if team == null:
			continue
		# Descontar partido de baja a lesionados de IA
		for pid: int in team.player_ids:
			var p: Player = GameManager.get_player(pid)
			if p and p.injured:
				p.injury_weeks -= 1
				if p.injury_weeks <= 0:
					p.injured      = false
					p.injury_weeks = 0
					p.suspended    = false
		# ~40% de probabilidad de que algún jugador reciba amarilla
		if randf() < 0.4:
			var pid: int = _pick_random_player(team)
			if pid != -1:
				var p: Player = GameManager.get_player(pid)
				if p:
					p.yellow_cards += 1
					if p.yellow_cards > 0 and p.yellow_cards % 5 == 0:
						p.suspended = true
		# ~8% de probabilidad de roja
		if randf() < 0.08:
			var pid: int = _pick_random_player(team)
			if pid != -1:
				var p: Player = GameManager.get_player(pid)
				if p:
					p.suspended = true


func _pick_random_player(team: Team) -> int:
	if team.player_ids.is_empty():
		return -1
	return team.player_ids[randi() % team.player_ids.size()]
