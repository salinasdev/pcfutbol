extends Node

## Genera el calendario completo de una liga (ida y vuelta) usando round-robin.
## Asigna local/visitante de forma greedy para maximizar la alternancia
## casa-fuera en jornadas consecutivas para todos los equipos.
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

	# last_venue[team_id] = 1 (jugó en casa) ó -1 (jugó fuera) en la jornada anterior
	var last_venue: Dictionary = {}

	for round_idx in range(rounds):
		var round_venues: Dictionary = {}

		for i in range(half):
			var t1: int = ids[i]
			var t2: int = ids[n - 1 - i]
			if t1 == -1 or t2 == -1:
				continue

			var v1: int = last_venue.get(t1, 0)
			var v2: int = last_venue.get(t2, 0)

			# Puntuar cada opción: +1 por alternar, -1 por repetir
			var s1: int = 0
			if v1 == -1: s1 += 1
			elif v1 == 1: s1 -= 1
			if v2 == 1: s1 += 1
			elif v2 == -1: s1 -= 1

			var s2: int = 0
			if v2 == -1: s2 += 1
			elif v2 == 1: s2 -= 1
			if v1 == 1: s2 += 1
			elif v1 == -1: s2 -= 1

			var home: int = t1 if s1 >= s2 else t2
			var away: int = t2 if s1 >= s2 else t1

			round_venues[home] = 1
			round_venues[away] = -1

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

		# Actualizar historial de localía
		last_venue.merge(round_venues, true)

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
			p.season_reds += 1

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


func _pick_random_player(team: Team) -> int:
	if team.player_ids.is_empty():
		return -1
	return team.player_ids[randi() % team.player_ids.size()]
