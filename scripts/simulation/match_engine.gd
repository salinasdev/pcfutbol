## Motor de partido minuto a minuto.
## Genera una lista de eventos ordenados por minuto para un partido completo.
## No modifica ningún estado global — solo produce datos.
extends Node

enum EventType {
	KICKOFF, GOAL, SHOT_SAVED, SHOT_OFF_TARGET, YELLOW_CARD,
	RED_CARD, INJURY, FOUL, CORNER, HALF_TIME, EXTRA_TIME_START,
	EXTRA_TIME_HALF, PENALTY_SHOOTOUT, FULL_TIME
}

## Genera todos los eventos de un partido.
## Devuelve Array[Dictionary] con claves:
##   minute(int), type(EventType), team_id(int), player_id(int), text(String)
## El evento FULL_TIME lleva además:
##   home_goals(int), away_goals(int),
##   red_card_ids(Array[int]),     ← expulsados (roja directa o 2ª amarilla)
##   yellow_ids(Array[int])        ← amonestados (su contador +1 al aplicar)
func generate_events(home: Team, away: Team, options: Dictionary = {}) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if home == null or away == null:
		return events

	var home_str := _strength(home) * 1.1
	var away_str := _strength(away)
	var total    := home_str + away_str
	var home_ratio := home_str / total

	# base_xg representa disparos esperados por equipo (no goles).
	# _shot_outcome convierte ~19% en gol para equipos iguales,
	# así que 13.5 disparos × 0.19 ≈ 2.6 goles totales esperados.
	var base_xg := 13.5
	# Amplificar diferencia de nivel: la potencia 1.8 exagera el efecto cuando hay brecha
	var amp_home := pow(home_ratio, 1.8) / (pow(home_ratio, 1.8) + pow(1.0 - home_ratio, 1.8))
	var home_xg := base_xg * amp_home * 1.1
	var away_xg := base_xg * (1.0 - amp_home) * 0.9

	var home_goals := 0
	var away_goals := 0

	# Seguimiento de tarjetas en este partido: player_id -> amarillas recibidas
	var yellow_count: Dictionary = {}   ## int -> int
	var red_card_ids: Array[int]  = []  ## expulsados (roja o 2ª amarilla)
	var yellow_ids:   Array[int]  = []  ## amonestados (solo 1ª y 2ª antes de roja)
	var injured_ids:  Dictionary  = {}  ## player_id -> semanas de baja

	events.append(_make_event(0, EventType.KICKOFF, home.id, -1,
		"⚽ Comienza el partido: %s vs %s" % [home.short_name, away.short_name]))

	for minute in range(1, 91):
		if minute == 45:
			events.append(_make_event(45, EventType.HALF_TIME, -1, -1,
				"🔔 Descanso — %s %d-%d %s" % [home.short_name, home_goals, away_goals, away.short_name]))

		# Chance de gol local
		if randf() < home_xg / 90.0:
			var scorer_id: int = _pick_scorer(home)
			var shot_type := _shot_outcome(home_str, away_str)
			if shot_type == EventType.GOAL:
				home_goals += 1
				events.append(_make_event(minute, EventType.GOAL, home.id, scorer_id,
					"⚽ GOL! %s (%s) %d-%d" % [_player_name(scorer_id), home.short_name, home_goals, away_goals]))
			elif shot_type == EventType.SHOT_SAVED:
				events.append(_make_event(minute, EventType.SHOT_SAVED, home.id, scorer_id,
					"🧤 Parada! Disparo de %s (%s)" % [_player_name(scorer_id), home.short_name]))
			else:
				events.append(_make_event(minute, EventType.SHOT_OFF_TARGET, home.id, scorer_id,
					"💨 Disparo desviado de %s (%s)" % [_player_name(scorer_id), home.short_name]))

		# Chance de gol visitante
		if randf() < away_xg / 90.0:
			var scorer_id: int = _pick_scorer(away)
			var shot_type := _shot_outcome(away_str, home_str)
			if shot_type == EventType.GOAL:
				away_goals += 1
				events.append(_make_event(minute, EventType.GOAL, away.id, scorer_id,
					"⚽ GOL! %s (%s) %d-%d" % [_player_name(scorer_id), away.short_name, home_goals, away_goals]))
			elif shot_type == EventType.SHOT_SAVED:
				events.append(_make_event(minute, EventType.SHOT_SAVED, away.id, scorer_id,
					"🧤 Parada! Disparo de %s (%s)" % [_player_name(scorer_id), away.short_name]))
			else:
				events.append(_make_event(minute, EventType.SHOT_OFF_TARGET, away.id, scorer_id,
					"💨 Disparo desviado de %s (%s)" % [_player_name(scorer_id), away.short_name]))

		# Falta / tarjeta
		if randf() < 0.06:
			var team: Team = home if randf() < 0.5 else away
			var pid: int = _pick_any_player(team)
			if pid == -1:
				continue

			# Roja directa (10% de las infracciones)
			if randf() < 0.1:
				if not red_card_ids.has(pid):
					red_card_ids.append(pid)
				events.append(_make_event(minute, EventType.RED_CARD, team.id, pid,
					"🟥 Tarjeta ROJA para %s (%s)" % [_player_name(pid), team.short_name]))
			else:
				# Amarilla — controlar si ya tiene una
				var prev: int = yellow_count.get(pid, 0)
				yellow_count[pid] = prev + 1
				if yellow_count[pid] >= 2:
					# Segunda amarilla = expulsión
					if not red_card_ids.has(pid):
						red_card_ids.append(pid)
					events.append(_make_event(minute, EventType.YELLOW_CARD, team.id, pid,
						"🟨🟥 Segunda amarilla — EXPULSADO %s (%s)" % [_player_name(pid), team.short_name]))
				else:
					if not yellow_ids.has(pid):
						yellow_ids.append(pid)
					events.append(_make_event(minute, EventType.YELLOW_CARD, team.id, pid,
						"🟨 Tarjeta amarilla para %s (%s)" % [_player_name(pid), team.short_name]))

		# Corner
		if randf() < 0.04:
			var team: Team = home if randf() < home_ratio else away
			events.append(_make_event(minute, EventType.CORNER, team.id, -1,
				"🚩 Córner para %s" % team.short_name))

		# Lesión: probabilidad base + extra si hay jugadores con baja energía
		# El fisio del equipo del jugador reduce la probabilidad
		for side: Team in [home, away]:
			var low_pid := _pick_low_energy_player(side)
			var base_chance := 0.006 if low_pid != -1 else 0.004
			if side.id == GameManager.player_team_id:
				base_chance *= maxf(0.3, 1.0 - side.staff_physio * 0.12)
			if randf() < base_chance:
				var pid := low_pid if low_pid != -1 else _pick_any_player(side)
				if pid != -1 and not injured_ids.has(pid):
					var weeks: int = randi_range(1, 4)
					var injury_data := _make_event(minute, EventType.INJURY, side.id, pid,
						"🩹 Lesión de %s (%s) — baja %d semana%s" % [
							_player_name(pid), side.short_name, weeks,
							"s" if weeks > 1 else ""])
					injury_data["injury_weeks"] = weeks
					injured_ids[pid] = weeks
					events.append(injury_data)

	var needs_tiebreaker := false
	if bool(options.get("knockout_single_leg", false)):
		needs_tiebreaker = home_goals == away_goals
	elif bool(options.get("knockout_on_aggregate_tie", false)):
		var aggregate_home := int(options.get("aggregate_home_start", 0)) + home_goals
		var aggregate_away := int(options.get("aggregate_away_start", 0)) + away_goals
		needs_tiebreaker = aggregate_home == aggregate_away

	var penalties_home := -1
	var penalties_away := -1
	var winner_id := -1
	var decided_by := "normal_time"
	if needs_tiebreaker:
		events.append(_make_event(90, EventType.EXTRA_TIME_START, -1, -1,
			"⏱️ Empate en la eliminatoria. Nos vamos a la prórroga."))
		var extra := _simulate_extra_time_events(home, away, home_str, away_str, home_goals, away_goals)
		home_goals = int(extra.get("home_goals", home_goals))
		away_goals = int(extra.get("away_goals", away_goals))
		for ev: Dictionary in extra.get("events", []):
			events.append(ev)
		if home_goals == away_goals:
			var penalties := _simulate_penalty_shootout(home, away)
			penalties_home = int(penalties.get("penalties_home", 0))
			penalties_away = int(penalties.get("penalties_away", 0))
			winner_id = int(penalties.get("winner_id", -1))
			decided_by = "penalties"
			events.append(_make_event(121, EventType.PENALTY_SHOOTOUT, winner_id, -1,
				"🎯 Penaltis: %s %d-%d %s. Pasa %s." % [home.short_name, penalties_home, penalties_away, away.short_name, _team_short_name(winner_id)]))
		else:
			winner_id = home.id if home_goals > away_goals else away.id
			decided_by = "extra_time"
	else:
		winner_id = home.id if home_goals > away_goals else away.id if away_goals > home_goals else -1

	var ft := _make_event(121 if decided_by == "penalties" else 120 if needs_tiebreaker else 90, EventType.FULL_TIME, -1, -1,
		_final_text(home, away, home_goals, away_goals, winner_id, decided_by, penalties_home, penalties_away))
	ft["home_goals"]    = home_goals
	ft["away_goals"]    = away_goals
	ft["red_card_ids"]  = red_card_ids
	ft["yellow_ids"]    = yellow_ids
	ft["injured_ids"]   = injured_ids
	ft["winner_id"]     = winner_id
	ft["decided_by"]    = decided_by
	if penalties_home >= 0 and penalties_away >= 0:
		ft["penalties_home"] = penalties_home
		ft["penalties_away"] = penalties_away
	if needs_tiebreaker:
		ft["after_extra_time"] = true
	events.append(ft)

	return events


# ---------------------------------------------------------------------------

func _make_event(minute: int, type: EventType, team_id: int, player_id: int, text: String) -> Dictionary:
	return {
		"minute":    minute,
		"type":      type,
		"team_id":   team_id,
		"player_id": player_id,
		"text":      text
	}


func _simulate_extra_time_events(home: Team, away: Team, home_str: float, away_str: float, home_goals: int, away_goals: int) -> Dictionary:
	var events: Array[Dictionary] = []
	var current_home_goals := home_goals
	var current_away_goals := away_goals
	var total_strength := maxf(home_str + away_str, 1.0)
	var home_xg := 2.8 * (home_str / total_strength)
	var away_xg := 2.8 * (away_str / total_strength)
	for minute: int in range(91, 121):
		if minute == 105:
			events.append(_make_event(105, EventType.EXTRA_TIME_HALF, -1, -1,
				"🔁 Descanso de la prórroga — %s %d-%d %s" % [home.short_name, current_home_goals, current_away_goals, away.short_name]))
		if randf() < home_xg / 30.0:
			var scorer_id: int = _pick_scorer(home)
			var shot_type := _shot_outcome(home_str, away_str)
			if shot_type == EventType.GOAL:
				current_home_goals += 1
				events.append(_make_event(minute, EventType.GOAL, home.id, scorer_id,
					"⚽ GOL en la prórroga! %s (%s) %d-%d" % [_player_name(scorer_id), home.short_name, current_home_goals, current_away_goals]))
		if randf() < away_xg / 30.0:
			var away_scorer_id: int = _pick_scorer(away)
			var away_shot_type := _shot_outcome(away_str, home_str)
			if away_shot_type == EventType.GOAL:
				current_away_goals += 1
				events.append(_make_event(minute, EventType.GOAL, away.id, away_scorer_id,
					"⚽ GOL en la prórroga! %s (%s) %d-%d" % [_player_name(away_scorer_id), away.short_name, current_home_goals, current_away_goals]))
	return {
		"events": events,
		"home_goals": current_home_goals,
		"away_goals": current_away_goals,
	}


func _simulate_penalty_shootout(home: Team, away: Team) -> Dictionary:
	var home_score := 0
	var away_score := 0
	for _shot: int in range(5):
		if randf() < _penalty_conversion(home):
			home_score += 1
		if randf() < _penalty_conversion(away):
			away_score += 1
	while home_score == away_score:
		if randf() < _penalty_conversion(home):
			home_score += 1
		if randf() < _penalty_conversion(away):
			away_score += 1
	return {
		"penalties_home": home_score,
		"penalties_away": away_score,
		"winner_id": home.id if home_score > away_score else away.id,
	}


func _penalty_conversion(team: Team) -> float:
	return clampf(_strength(team) / 100.0 * 0.28 + 0.58, 0.58, 0.88)


func _team_short_name(team_id: int) -> String:
	var team: Team = GameManager.get_team(team_id)
	return team.short_name if team != null else "Equipo"


func _final_text(home: Team, away: Team, home_goals: int, away_goals: int, winner_id: int, decided_by: String, penalties_home: int, penalties_away: int) -> String:
	if decided_by == "penalties":
		return "🏁 Final — %s %d-%d %s. Penaltis %d-%d, pasa %s" % [home.short_name, home_goals, away_goals, away.short_name, penalties_home, penalties_away, _team_short_name(winner_id)]
	if decided_by == "extra_time":
		return "🏁 Final tras prórroga — %s %d-%d %s" % [home.short_name, home_goals, away_goals, away.short_name]
	return "🏁 Final — %s %d-%d %s" % [home.short_name, home_goals, away_goals, away.short_name]


func _strength(team: Team) -> float:
	if team.starting_eleven.is_empty():
		return float(team.reputation)
	var total := 0.0
	var count := 0
	for pid: int in team.starting_eleven:
		var p: Player = GameManager.get_player(pid)
		if p:
			total += float(p.get_effective_overall())
			count += 1
	return (total / float(count)) if count > 0 else float(team.reputation)


func _shot_outcome(att_str: float, def_str: float) -> EventType:
	var goal_chance := clampf(att_str / (att_str + def_str) * 0.38, 0.05, 0.45)
	var saved_chance := goal_chance * 1.4
	var r := randf()
	if r < goal_chance:
		return EventType.GOAL
	elif r < goal_chance + saved_chance:
		return EventType.SHOT_SAVED
	return EventType.SHOT_OFF_TARGET


func _pick_scorer(team: Team) -> int:
	# Delanteros y mediocampistas tienen más peso para marcar; los sancionados no juegan
	var candidates: Array[int] = []
	for pid: int in team.starting_eleven:
		var p: Player = GameManager.get_player(pid)
		if p == null or p.suspended:
			continue
		if p.position == Player.Position.FWD:
			candidates.append(pid)
			candidates.append(pid)   # doble peso
		elif p.position == Player.Position.MID:
			candidates.append(pid)
	if candidates.is_empty():
		return _pick_any_player(team)
	return candidates[randi() % candidates.size()]


func _pick_any_player(team: Team) -> int:
	var available: Array[int] = []
	for pid: int in team.starting_eleven:
		var p: Player = GameManager.get_player(pid)
		if p and not p.suspended:
			available.append(pid)
	if available.is_empty():
		# Fallback: cualquier jugador aunque esté sancionado (equipo muy mermado)
		if team.starting_eleven.is_empty():
			return -1
		return team.starting_eleven[randi() % team.starting_eleven.size()]
	return available[randi() % available.size()]


## Devuelve el jugador titular con menos energía si alguno está por debajo de 35, si no -1
func _pick_low_energy_player(team: Team) -> int:
	var lowest_pid := -1
	var lowest_energy := 35
	for pid: int in team.starting_eleven:
		var p: Player = GameManager.get_player(pid)
		if p != null and p.energy < lowest_energy:
			lowest_energy = p.energy
			lowest_pid = pid
	return lowest_pid


func _player_name(pid: int) -> String:
	if pid == -1:
		return "Desconocido"
	var p: Player = GameManager.get_player(pid)
	if p == null:
		return "Jugador"
	var parts := p.full_name.split(" ")
	return parts[parts.size() - 1]   # apellido
