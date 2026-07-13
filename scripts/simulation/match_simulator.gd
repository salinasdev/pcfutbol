extends Node

## Simula un partido entre dos equipos y devuelve el resultado
func simulate_match(home: Team, away: Team) -> Dictionary:
	if home == null or away == null:
		return {"home_goals": 0, "away_goals": 0}

	var home_str := _get_team_strength(home) * 1.1  # ventaja de campo
	var away_str := _get_team_strength(away)
	var total    := home_str + away_str
	var home_ratio := home_str / total

	# Goles esperados según diferencia de nivel
	var base_goals := 2.6
	# Amplificar diferencia de nivel: la potencia 1.8 exagera el efecto cuando hay brecha
	var amp_home := pow(home_ratio, 1.8) / (pow(home_ratio, 1.8) + pow(1.0 - home_ratio, 1.8))
	var home_xg := base_goals * amp_home * 1.1
	var away_xg := base_goals * (1.0 - amp_home) * 0.9

	return {
		"home_goals": _poisson_sample(home_xg),
		"away_goals": _poisson_sample(away_xg)
	}


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

	return (total / count) if count > 0 else float(team.reputation)


## Algoritmo de Knuth para muestrear distribución de Poisson
func _poisson_sample(lambda_val: float) -> int:
	var l := exp(-lambda_val)
	var k := 0
	var p := 1.0
	while p > l:
		k += 1
		p *= randf()
	return maxi(0, k - 1)
