extends Node

## Simula un partido entre dos equipos y devuelve el resultado
func simulate_match(home: Team, away: Team, options: Dictionary = {}) -> Dictionary:
	if home == null or away == null:
		return {"home_goals": 0, "away_goals": 0}

	var home_str := _get_team_strength(home) * 1.1  # ventaja de campo
	var away_str := _get_team_strength(away)
	var total    := home_str + away_str
	var home_ratio := home_str / total

	# Goles esperados según diferencia de nivel
	var base_goals := 2.6
	var amp_home := pow(home_ratio, 1.8) / (pow(home_ratio, 1.8) + pow(1.0 - home_ratio, 1.8))
	var home_xg := base_goals * amp_home * 1.1
	var away_xg := base_goals * (1.0 - amp_home) * 0.9

	# ── Modificadores tácticos ──────────────────────────────────────────────
	var hm := _tactics_modifier(home, away)   # [xg_factor, concede_factor]
	var am := _tactics_modifier(away, home)

	home_xg *= hm[0]
	away_xg *= am[0]
	home_xg *= am[1]  # la defensa rival mitiga mi ataque
	away_xg *= hm[1]

	var result := {
		"home_goals": _poisson_sample(home_xg),
		"away_goals": _poisson_sample(away_xg),
		"winner_id": -1,
		"decided_by": "normal_time",
	}

	var needs_tiebreaker := false
	if bool(options.get("knockout_single_leg", false)):
		needs_tiebreaker = result["home_goals"] == result["away_goals"]
	elif bool(options.get("knockout_on_aggregate_tie", false)):
		var aggregate_home := int(options.get("aggregate_home_start", 0)) + int(result["home_goals"])
		var aggregate_away := int(options.get("aggregate_away_start", 0)) + int(result["away_goals"])
		needs_tiebreaker = aggregate_home == aggregate_away

	if needs_tiebreaker:
		var extra_time := _simulate_extra_time(home_xg, away_xg)
		result["home_goals"] = int(result["home_goals"]) + int(extra_time.get("home_goals", 0))
		result["away_goals"] = int(result["away_goals"]) + int(extra_time.get("away_goals", 0))
		result["after_extra_time"] = true
		if int(result["home_goals"]) == int(result["away_goals"]):
			var penalties := _simulate_penalties(home, away)
			result["penalties_home"] = penalties.get("penalties_home", 0)
			result["penalties_away"] = penalties.get("penalties_away", 0)
			result["winner_id"] = penalties.get("winner_id", -1)
			result["decided_by"] = "penalties"
		else:
			result["winner_id"] = home.id if int(result["home_goals"]) > int(result["away_goals"]) else away.id
			result["decided_by"] = "extra_time"
	else:
		result["winner_id"] = home.id if int(result["home_goals"]) > int(result["away_goals"]) else away.id if int(result["away_goals"]) > int(result["home_goals"]) else -1

	return result


## Devuelve [xg_attack_factor, xg_concede_factor] para un equipo frente a su rival.
## Valores > 1.0 benefician; < 1.0 penalizan.
func _tactics_modifier(team: Team, rival: Team) -> Array:
	var atk: float = 1.0   # multiplicador sobre mis xG
	var def: float = 1.0   # multiplicador sobre los xG que concedo

	# ── ATAQUE ────────────────────────────────────────────────────────────
	# Estilo de juego
	match team.tactic_attack_style:
		0:  atk *= 1.10   # Ofensivo: más goles pero también más exposición
		1:  atk *= 1.00   # Mixto: base
		2:  atk *= 0.85   # Especulativo: menos goles propios, pero también menos concedidos
	if team.tactic_attack_style == 2:
		def *= 0.88

	# Juego al toque (50 = neutro; cada 10 pts de toque = +1 % atk si rival presiona poco)
	var toque_bias := (team.tactic_toque_pct - 50) / 100.0   # -0.5 … +0.5
	# El toque da ventaja si el rival NO presiona en campo rival
	if rival.tactic_press_line < 2:
		atk *= 1.0 + toque_bias * 0.12
	else:
		# El rival presiona alto → el toque es arriesgado, balón largo puede ser mejor
		atk *= 1.0 - toque_bias * 0.08

	# Contragolpe
	var counter := team.tactic_counter_pct / 100.0   # 0 … 1
	# El contra es más efectivo contra equipos que atacan mucho (ofensivos)
	var rival_offensive := float(rival.tactic_attack_style == 0)
	atk *= 1.0 + counter * 0.10 * (1.0 + rival_offensive * 0.5)

	# ── DEFENSA ───────────────────────────────────────────────────────────
	# Entradas
	match team.tactic_tackle_style:
		0:  def *= 1.06   # Suave: menos tarjetas pero peor defensa
		1:  def *= 1.00
		2:  def *= 0.90   # Agresiva: mejor defensa pero cansancio

	# Marcaje al hombre vs rival con muchos delanteros de calidad
	if team.tactic_marking == 1:   # Al hombre
		def *= 0.94
	else:                           # Zonal
		def *= 1.00

	# Despejes
	if team.tactic_clearance == 1:   # Balón largo
		# Útil si el rival presiona mucho
		if rival.tactic_press_line == 2:
			def *= 0.94
		else:
			def *= 1.02
	# Balón jugado: más riesgo si rival presiona alto
	else:
		if rival.tactic_press_line == 2:
			def *= 1.04
		else:
			def *= 0.97

	# Línea de presión
	match team.tactic_press_line:
		0:  # Campo propio: más defensivo, menos riesgo
			def *= 0.93
		1:  # Campo medio: equilibrado
			def *= 1.00
		2:  # Campo rival: presión alta, más xG generados, pero más espacio concedido
			atk *= 1.08
			def *= 1.08   # también más exposición

	return [atk, def]


## Versión detallada con estadísticas adicionales (tiros, posesión…)
func simulate_match_detailed(home: Team, away: Team) -> Dictionary:
	var result := simulate_match(home, away)
	return {
		"home_goals":      result["home_goals"],
		"away_goals":      result["away_goals"],
		"home_shots":      randi_range(4, 20),
		"away_shots":      randi_range(4, 20),
		"home_possession": randi_range(35, 65)
	}


func _simulate_extra_time(home_xg: float, away_xg: float) -> Dictionary:
	var extra_factor := 0.28
	return {
		"home_goals": _poisson_sample(home_xg * extra_factor),
		"away_goals": _poisson_sample(away_xg * extra_factor)
	}


func _simulate_penalties(home: Team, away: Team) -> Dictionary:
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

# ---------------------------------------------------------------------------

func _get_team_strength(team: Team) -> float:
	if team.starting_eleven.is_empty():
		return float(team.reputation)

	var total := 0.0
	var count := 0
	for pid: int in team.starting_eleven:
		var p: Player = GameManager.get_player(pid)
		if p:
			total += float(p.get_effective_overall())
			count += 1

	var base := (total / count) if count > 0 else float(team.reputation)
	# Prima por victoria — motiva más al equipo del jugador
	if team.id == GameManager.player_team_id:
		base *= GameManager.get_bonus_strength_factor()
	return base


func _penalty_conversion(team: Team) -> float:
	return clampf(_get_team_strength(team) / 100.0 * 0.28 + 0.58, 0.58, 0.88)


## Algoritmo de Knuth para muestrear distribución de Poisson
func _poisson_sample(lambda_val: float) -> int:
	var l := exp(-lambda_val)
	var k := 0
	var p := 1.0
	while p > l:
		k += 1
		p *= randf()
	return maxi(0, k - 1)
