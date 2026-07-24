class_name League
extends Resource

@export var id: int = 0
@export var name: String = ""
@export var short_name: String = ""
@export var country: String = "España"
@export var level: int = 1
@export var season: int = 2026

@export var team_ids: Array[int] = []
@export var current_matchday: int = 0

## Cada fixture: {matchday, home_id, away_id, home_goals, away_goals, played}
@export var fixtures: Array[Dictionary] = []


func get_total_matchdays() -> int:
	var n := team_ids.size()
	if n < 2:
		return 0
	return (n - 1) * 2


func get_fixtures_for_matchday(matchday: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for f: Dictionary in fixtures:
		if f["matchday"] == matchday:
			result.append(f)
	return result


func reset_season() -> void:
	current_matchday = 0
	fixtures.clear()
