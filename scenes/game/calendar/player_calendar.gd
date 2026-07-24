extends Control

const ICON_BACK := preload("res://assets/ui/icons/back-white.png")
const ICON_SIZE_NAV := 28

var _league: League = null


func _ready() -> void:
	%BtnBack.icon = ICON_BACK
	%BtnBack.add_theme_constant_override("icon_max_width", ICON_SIZE_NAV)
	%BtnBack.text = ""
	%BtnBack.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/game/office/office.tscn"))
	_league = _get_first_league()
	_build_list()


func _get_first_league() -> League:
	var player_team: Team = GameManager.get_player_team()
	if player_team != null:
		var player_league: League = GameManager.get_league(player_team.league_id)
		if player_league != null:
			return player_league

	if GameManager.leagues.is_empty():
		return null
	return GameManager.leagues.values()[0] as League


func _build_list() -> void:
	var list: VBoxContainer = %MatchList
	for child in list.get_children():
		child.queue_free()

	if _league == null:
		return

	var pid := GameManager.player_team_id

	# Obtener todos los partidos del equipo del jugador, ordenados por jornada
	var player_fixtures: Array[Dictionary] = []
	for f: Dictionary in _league.fixtures:
		if f["home_id"] == pid or f["away_id"] == pid:
			player_fixtures.append(f)
	player_fixtures.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["matchday"] < b["matchday"]
	)

	var next_panel: Control = null

	for f: Dictionary in player_fixtures:
		var row := _make_fixture_row(f)
		list.add_child(row)
		# Marcar el primer partido no jugado como "próximo"
		if next_panel == null and not f["played"]:
			next_panel = row

	# Scroll automático al próximo partido
	if next_panel != null:
		await get_tree().process_frame
		%ScrollContainer.ensure_control_visible(next_panel)


func _make_fixture_row(f: Dictionary) -> Control:
	var pid := GameManager.player_team_id
	var is_home: bool = (f["home_id"] == pid)
	var opponent_id: int = f["away_id"] if is_home else f["home_id"]
	var opponent: Team = GameManager.get_team(opponent_id)
	var opp_name: String = opponent.name if opponent else "???"

	var is_next: bool = (not f["played"] and f == _get_next_fixture())
	var is_played: bool = f["played"]

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 72)

	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(6)
	if is_next:
		style.bg_color = Color(0.08, 0.25, 0.12, 1)
		style.set_border_width_all(2)
		style.border_color = Color(0.3, 1.0, 0.4, 1)
	elif is_played:
		style.bg_color = Color(0.07, 0.07, 0.10, 0.9)
	else:
		style.bg_color = Color(0.10, 0.13, 0.18, 0.9)
	panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	panel.add_child(hbox)

	# Jornada
	var lbl_md := Label.new()
	lbl_md.custom_minimum_size = Vector2(72, 0)
	lbl_md.text = "J%d" % f["matchday"]
	lbl_md.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_md.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl_md.add_theme_font_size_override("font_size", 15)
	lbl_md.add_theme_color_override("font_color", Color(0.55, 0.65, 0.80, 1))
	hbox.add_child(lbl_md)

	# LOCAL / VISIT
	var lbl_venue := Label.new()
	lbl_venue.custom_minimum_size = Vector2(52, 0)
	lbl_venue.text = "LOCAL" if is_home else "VISIT"
	lbl_venue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_venue.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl_venue.add_theme_font_size_override("font_size", 13)
	lbl_venue.add_theme_color_override("font_color",
		Color(0.35, 0.85, 0.45, 1) if is_home else Color(0.90, 0.65, 0.25, 1))
	hbox.add_child(lbl_venue)

	# Escudo rival
	var crest_rect := TextureRect.new()
	crest_rect.custom_minimum_size = Vector2(36, 36)
	crest_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crest_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if opponent != null and opponent.crest != "":
		var tex := load(opponent.crest) as Texture2D
		if tex:
			crest_rect.texture = tex
	hbox.add_child(crest_rect)

	# Nombre del rival
	var lbl_opp := Label.new()
	lbl_opp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_opp.text = opp_name
	lbl_opp.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl_opp.add_theme_font_size_override("font_size", 18)
	hbox.add_child(lbl_opp)

	# Resultado o guion
	var lbl_result := Label.new()
	lbl_result.custom_minimum_size = Vector2(110, 0)
	lbl_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_result.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl_result.add_theme_font_size_override("font_size", 20)
	if is_played:
		var my_goals: int  = f["home_goals"] if is_home else f["away_goals"]
		var opp_goals: int = f["away_goals"] if is_home else f["home_goals"]
		lbl_result.text = "%d - %d" % [my_goals, opp_goals]
		if my_goals > opp_goals:
			lbl_result.add_theme_color_override("font_color", Color(0.30, 0.90, 0.40, 1))
		elif my_goals < opp_goals:
			lbl_result.add_theme_color_override("font_color", Color(0.90, 0.30, 0.30, 1))
		else:
			lbl_result.add_theme_color_override("font_color", Color(0.90, 0.85, 0.35, 1))
	else:
		lbl_result.text = "- : -"
		lbl_result.add_theme_color_override("font_color", Color(0.40, 0.40, 0.50, 1))
	hbox.add_child(lbl_result)

	return panel


func _get_next_fixture() -> Dictionary:
	if _league == null:
		return {}
	var pid := GameManager.player_team_id
	for f: Dictionary in _league.fixtures:
		if (f["home_id"] == pid or f["away_id"] == pid) and not f["played"]:
			return f
	return {}
