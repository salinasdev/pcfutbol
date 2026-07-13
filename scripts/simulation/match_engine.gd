## Motor de partido minuto a minuto.
## Genera una lista de eventos ordenados por minuto para un partido completo.
## No modifica ningún estado global — solo produce datos.
extends Node

enum EventType {
	KICKOFF, GOAL, SHOT_SAVED, SHOT_OFF_TARGET, YELLOW_CARD,
	RED_CARD, INJURY, FOUL, CORNER, HALF_TIME, FULL_TIME
}

## Genera todos los eventos de un partido.
## Devuelve Array[Dictionary] con claves:
##   minute(int), type(EventType), team_id(int), player_id(int), text(String)
## El evento FULL_TIME lleva además:
##   home_goals(int), away_goals(int),
##   red_card_ids(Array[int]),     ← expulsados (roja directa o 2ª amarilla)
##   yellow_ids(Array[int])        ← amonestados (su contador +1 al aplicar)
func generate_events(home: Team, away: Team) -> Array[Dictionary]:
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
		for side: Team in [home, away]:
			var low_pid := _pick_low_energy_player(side)
			var inj_chance := 0.006 if low_pid != -1 else 0.004
			if randf() < inj_chance:
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

	var ft := _make_event(90, EventType.FULL_TIME, -1, -1,
		"🏁 Final — %s %d-%d %s" % [home.short_name, home_goals, away_goals, away.short_name])
	ft["home_goals"]    = home_goals
	ft["away_goals"]    = away_goals
	ft["red_card_ids"]  = red_card_ids
	ft["yellow_ids"]    = yellow_ids
	ft["injured_ids"]   = injured_ids
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
	# Delanteros y mediocampistas tienen más peso para marcar
	var candidates: Array[int] = []
	for pid: int in team.starting_eleven:
		var p: Player = GameManager.get_player(pid)
		if p == null:
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
	if team.starting_eleven.is_empty():
		return -1
	return team.starting_eleven[randi() % team.starting_eleven.size()]


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
