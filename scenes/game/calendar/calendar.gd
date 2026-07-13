extends Control

var _league: League = null
var _current_matchday: int = 1
var _total_matchdays: int = 0


func _ready() -> void:
	%BtnBack.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/game/office/office.tscn"))
	%BtnPrev.pressed.connect(_prev_matchday)
	%BtnNext.pressed.connect(_next_matchday)
	%BtnSimulate.pressed.connect(_simulate_current)

	_league = _get_first_league()
	if _league:
		_total_matchdays = _league.get_total_matchdays()
		_current_matchday = max(1, _league.current_matchday)
		_refresh()


func _get_first_league() -> League:
	if GameManager.leagues.is_empty():
		return null
	return GameManager.leagues.values()[0] as League


func _prev_matchday() -> void:
	if _current_matchday > 1:
		_current_matchday -= 1
		_refresh()


func _next_matchday() -> void:
	if _current_matchday < _total_matchdays:
		_current_matchday += 1
		_refresh()


func _simulate_current() -> void:
	if _league == null:
		return
	var fixtures := _league.get_fixtures_for_matchday(_current_matchday)
	var all_played := fixtures.all(func(f: Dictionary) -> bool: return f["played"])
	if all_played:
		_set_status("Jornada %d ya jugada." % _current_matchday)
		return

	# Simular sólo los partidos que NO son del equipo del jugador
	var pid := GameManager.player_team_id
	var has_player_match := false
	for f: Dictionary in fixtures:
		if not f["played"]:
			if f["home_id"] == pid or f["away_id"] == pid:
				has_player_match = true
			else:
				var ht: Team = GameManager.get_team(f["home_id"])
				var at: Team = GameManager.get_team(f["away_id"])
				var res: Dictionary = MatchSimulator.simulate_match(ht, at)
				f["home_goals"] = res["home_goals"]
				f["away_goals"] = res["away_goals"]
				f["played"]     = true
				LeagueManager._apply_result(f)

	if has_player_match:
		_set_status("Pulsa tu partido para jugarlo en directo.")
	else:
		_league.current_matchday = _current_matchday

	_refresh()


func _refresh() -> void:
	if _league == null:
		%JornadaLabel.text = "Sin liga"
		%BtnSimulate.disabled = true
		return

	%JornadaLabel.text = "Jornada %d / %d" % [_current_matchday, _total_matchdays]
	%BtnPrev.disabled = (_current_matchday <= 1)
	%BtnNext.disabled = (_current_matchday >= _total_matchdays)

	var fixtures := _league.get_fixtures_for_matchday(_current_matchday)
	var all_played := fixtures.all(func(f: Dictionary) -> bool: return f["played"])
	%BtnSimulate.disabled = all_played
	%BtnSimulate.text = "Jornada ya jugada" if all_played else "Simular Jornada"

	var list: VBoxContainer = %MatchList
	for child in list.get_children():
		child.queue_free()

	for f: Dictionary in fixtures:
		list.add_child(_make_fixture_row(f))


func _make_fixture_row(f: Dictionary) -> Control:
	var home: Team = GameManager.get_team(f["home_id"])
	var away: Team = GameManager.get_team(f["away_id"])
	var home_name: String = home.short_name if home else "???"
	var away_name: String = away.short_name if away else "???"

	var pid := GameManager.player_team_id
	var is_player_match: bool = (f["home_id"] == pid or f["away_id"] == pid)
	var playable: bool = is_player_match and not f["played"]

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 64)

	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(4)
	if is_player_match:
		style.bg_color = Color(0.1, 0.22, 0.1, 1)
		style.border_width_left   = 2
		style.border_width_right  = 2
		style.border_width_top    = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.3, 0.8, 0.3, 0.6) if not playable else Color(0.3, 1.0, 0.3, 1)
	else:
		style.bg_color = Color(0.1, 0.1, 0.1, 0.3)
	panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	panel.add_child(hbox)

	var lbl_home := Label.new()
	lbl_home.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_home.text = home_name
	lbl_home.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_home.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl_home.add_theme_font_size_override("font_size", 18)
	if home != null and home.id == pid:
		lbl_home.add_theme_color_override("font_color", Color(0.9, 1.0, 0.4, 1))
	hbox.add_child(lbl_home)

	var lbl_score := Label.new()
	lbl_score.custom_minimum_size = Vector2(110, 0)
	lbl_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_score.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl_score.add_theme_font_size_override("font_size", 20)
	if f["played"]:
		lbl_score.text = "%d  -  %d" % [f["home_goals"], f["away_goals"]]
		lbl_score.add_theme_color_override("font_color", Color(0.9, 0.9, 0.4, 1))
	elif playable:
		lbl_score.text = "▶ JUGAR"
		lbl_score.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5, 1))
	else:
		lbl_score.text = "vs"
		lbl_score.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
	hbox.add_child(lbl_score)

	var lbl_away := Label.new()
	lbl_away.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_away.text = away_name
	lbl_away.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lbl_away.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl_away.add_theme_font_size_override("font_size", 18)
	if away != null and away.id == pid:
		lbl_away.add_theme_color_override("font_color", Color(0.9, 1.0, 0.4, 1))
	hbox.add_child(lbl_away)

	# El panel entero es clickable si el partido es jugable
	if playable:
		var btn := Button.new()
		btn.flat = true
		btn.layout_mode = 1
		btn.anchors_preset = 15
		btn.anchor_right  = 1.0
		btn.anchor_bottom = 1.0
		btn.modulate = Color(1, 1, 1, 0)  # invisible pero recibe clicks
		btn.pressed.connect(func(): _launch_match(f))
		panel.add_child(btn)

	return panel


func _launch_match(f: Dictionary) -> void:
	GameManager.active_fixture = f
	get_tree().change_scene_to_file("res://scenes/game/match/match_view.tscn")


func _set_status(msg: String) -> void:
	%JornadaLabel.text = msg
