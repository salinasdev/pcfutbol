extends Control

## Cuántos equipos ascienden / descienden por liga
const PROMOTION_SPOTS  := 2   ## Top N → liga superior (futuro)
const PLAYOFF_SPOTS    := 6
const RELEGATION_SPOTS := 3   ## Bottom N → segunda (futuro)

## Colores de zonas
const COLOR_CHAMPION   := Color(0.1, 0.6, 1.0, 1)
const COLOR_PROMOTION  := Color(0.1, 0.8, 0.3, 1)
const COLOR_RELEGATION := Color(0.9, 0.2, 0.2, 1)
const COLOR_NORMAL     := Color(0.85, 0.85, 0.85, 1)


func _ready() -> void:
	%SeasonLabel.text = "%d/%s" % [
		GameManager.season,
		str(GameManager.season + 1).right(2)
	]
	%BtnNextSeason.pressed.connect(_on_next_season)
	_build_content()


func _build_content() -> void:
	var content: VBoxContainer = %ContentVBox
	for child in content.get_children():
		child.queue_free()

	var player_team: Team = GameManager.get_player_team()

	for league: League in GameManager.leagues.values():
		# --- Título de liga ---
		var lbl_league := Label.new()
		lbl_league.text = "%s — Temporada %d" % [league.name, GameManager.season]
		lbl_league.add_theme_font_size_override("font_size", 20)
		lbl_league.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1, 1))
		content.add_child(lbl_league)

		var standings: Array = LeagueManager.get_standings(league)
		var total: int = standings.size()

		for i in range(total):
			var team: Team = standings[i]
			var is_player: bool = (team.id == GameManager.player_team_id)
			content.add_child(_make_standing_row(team, i + 1, total, league, is_player, player_team))

		# Resultado del equipo del jugador si está en esta liga
		if player_team != null and league.team_ids.has(player_team.id):
			content.add_child(_make_player_result(player_team, standings, league))

		var sep := HSeparator.new()
		content.add_child(sep)


func _make_standing_row(team: Team, pos: int, total: int, league: League, is_player: bool, _pt: Team) -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(4)

	# Color de zona
	var zone_color := _zone_color_for_position(league, pos, total)

	if is_player:
		style.bg_color = Color(zone_color.r, zone_color.g, zone_color.b, 0.35)
		style.border_width_left = 4
		style.border_color = Color(1.0, 0.85, 0.1, 1)
	else:
		style.bg_color = Color(zone_color.r * 0.15, zone_color.g * 0.15, zone_color.b * 0.15, 0.7)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(0, 48)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 0)
	panel.add_child(hbox)

	# Posición
	var lbl_pos := Label.new()
	lbl_pos.custom_minimum_size = Vector2(40, 0)
	lbl_pos.text = str(pos)
	lbl_pos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_pos.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl_pos.add_theme_font_size_override("font_size", 16)
	lbl_pos.add_theme_color_override("font_color", zone_color if pos != 1 else COLOR_CHAMPION)
	hbox.add_child(lbl_pos)

	# Nombre
	var lbl_name := Label.new()
	lbl_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_name.text = ("[Tu equipo] " if is_player else "") + team.name
	lbl_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_name.add_theme_font_size_override("font_size", 17)
	lbl_name.add_theme_color_override("font_color",
		Color(1.0, 0.9, 0.3, 1) if is_player else COLOR_NORMAL)
	hbox.add_child(lbl_name)

	# Stats compactas
	var stats := "%d PJ  %d G  %d E  %d P  %s GD  %d PTS" % [
		team.get_matches_played(), team.wins, team.draws, team.losses,
		("+" if team.get_goal_difference() >= 0 else "") + str(team.get_goal_difference()),
		team.get_points()
	]
	var lbl_stats := Label.new()
	lbl_stats.text = stats
	lbl_stats.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_stats.add_theme_font_size_override("font_size", 13)
	lbl_stats.add_theme_color_override("font_color", Color(0.65, 0.65, 0.72, 1))
	hbox.add_child(lbl_stats)

	return panel


func _make_player_result(team: Team, standings: Array, league: League) -> Control:
	var pos: int = 1
	for i in range(standings.size()):
		if standings[i].id == team.id:
			pos = i + 1
			break
	var total: int = standings.size()

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(6)

	var result_text: String
	var result_color: Color

	if league.level == 1:
		if pos == 1:
			result_text = "¡CAMPEÓN DE LIGA! Temporada histórica, %s." % GameManager.manager_name
			result_color = COLOR_CHAMPION
		elif pos <= 6:
			result_text = "Clasificado para puestos europeos. ¡Gran temporada!"
			result_color = COLOR_PROMOTION
		elif pos > total - RELEGATION_SPOTS:
			result_text = "DESCENSO. El equipo baja a Segunda División."
			result_color = COLOR_RELEGATION
		else:
			result_text = "Temporada finalizada en %dª posición." % pos
			result_color = COLOR_NORMAL
	elif league.level == 2:
		if pos <= PROMOTION_SPOTS:
			result_text = "Ascenso directo logrado. ¡A Primera División!"
			result_color = COLOR_CHAMPION
		elif pos <= PLAYOFF_SPOTS:
			result_text = "Clasificado para playoff de ascenso."
			result_color = COLOR_PROMOTION
		else:
			result_text = "Temporada finalizada en %dª posición en Segunda." % pos
			result_color = COLOR_NORMAL
	else:
		result_text = "Temporada finalizada en %dª posición." % pos
		result_color = COLOR_NORMAL

	style.bg_color = Color(result_color.r * 0.2, result_color.g * 0.2, result_color.b * 0.2, 1)
	style.border_width_left = 5
	style.border_color = result_color
	panel.add_theme_stylebox_override("panel", style)

	var lbl := Label.new()
	lbl.text = result_text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", result_color)
	panel.add_child(lbl)

	return panel


# ---------------------------------------------------------------------------
# Nueva temporada

func _on_next_season() -> void:
	_start_new_season()
	get_tree().change_scene_to_file("res://scenes/game/office/office.tscn")


func _start_new_season() -> void:
	var transition := GameManager.process_end_of_season_spanish_leagues()
	GameManager.apply_end_of_season_prizes(transition)

	GameManager.season += 1
	GameManager.current_week = 1
	GameManager.current_date = {"day": 1, "month": 8, "year": GameManager.season}

	# Resetear stats de equipos y jugadores
	for team: Team in GameManager.teams.values():
		team.reset_season_stats()

	for p: Player in GameManager.players.values():
		p.yellow_cards = 0
		p.suspended    = false
		p.red_carded   = false
		p.season_goals = 0
		p.season_reds  = 0
		p.age         += 1   # Cumplir años

	# Regenerar calendario de todas las ligas
	for league: League in GameManager.leagues.values():
		league.season = GameManager.season
		league.reset_season()
		LeagueManager.generate_fixtures(league)

	NewsManager.news_feed.clear()
	NewsManager.add_season_transition_news(transition)
	SaveManager.save_game()


func _zone_color_for_position(league: League, pos: int, total: int) -> Color:
	if league.level == 1:
		if pos == 1:
			return COLOR_CHAMPION
		if pos <= 6:
			return COLOR_PROMOTION
		if pos > total - RELEGATION_SPOTS:
			return COLOR_RELEGATION
		return Color(0.1, 0.12, 0.18, 1)

	if league.level == 2:
		if pos <= PROMOTION_SPOTS:
			return COLOR_CHAMPION
		if pos <= PLAYOFF_SPOTS:
			return COLOR_PROMOTION
		return Color(0.1, 0.12, 0.18, 1)

	return Color(0.1, 0.12, 0.18, 1)
