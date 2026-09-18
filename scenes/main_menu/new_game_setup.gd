extends Control

const ICON_BACK := preload("res://assets/ui/icons/back-white.png")
const ICON_STAR := preload("res://assets/ui/icons/star.png")
const ICON_SIZE_NAV := 28

var _selected_team_id: int = -1
var _selected_btn: Button = null


func _ready() -> void:
	# Generar todas las ligas y equipos antes de mostrar la pantalla
	GameManager.prepare_new_game()
	NewsManager.rebuild_news_feed()
	%BtnBack.icon = ICON_BACK
	%BtnBack.add_theme_constant_override("icon_max_width", ICON_SIZE_NAV)
	%BtnBack.text = ""

	%BtnBack.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn"))
	%BtnStart.pressed.connect(_on_start)
	%InputManager.text_submitted.connect(func(_t: String): _on_start())
	%InputManager.focus_entered.connect(func(): DisplayServer.virtual_keyboard_show(""))
	%InputManager.focus_exited.connect(func(): DisplayServer.virtual_keyboard_hide())

	_build_league_picker()
	%LeaguePicker.item_selected.connect(_on_league_selected)

	# Cargar la primera liga por defecto
	if not GameManager.leagues.is_empty():
		_load_league(GameManager.leagues.values()[0] as League)


# ---------------------------------------------------------------------------
# Liga

func _build_league_picker() -> void:
	var picker: OptionButton = %LeaguePicker
	picker.clear()
	for league: League in GameManager.leagues.values():
		picker.add_item("%s  (%s)" % [league.name, league.country])


func _on_league_selected(idx: int) -> void:
	var league: League = GameManager.leagues.values()[idx] as League
	_load_league(league)


func _load_league(league: League) -> void:
	_selected_team_id = -1
	_selected_btn = null
	_build_team_list(league)


# ---------------------------------------------------------------------------
# Lista de equipos

func _build_team_list(league: League) -> void:
	var list: VBoxContainer = %TeamList
	for child in list.get_children():
		child.queue_free()

	# Ordenar por reputación descendente
	var sorted_teams: Array = []
	for tid: int in league.team_ids:
		var t: Team = GameManager.get_team(tid)
		if t:
			sorted_teams.append(t)
	sorted_teams.sort_custom(func(a: Team, b: Team) -> bool: return a.reputation > b.reputation)

	for t: Team in sorted_teams:
		var btn := _make_team_button(t)
		list.add_child(btn)


func _make_team_button(t: Team) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 72)
	btn.text = ""
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	btn.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = t.name
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	var info_row := HBoxContainer.new()
	info_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_row.add_theme_constant_override("separation", 8)
	vbox.add_child(info_row)

	var city_lbl := Label.new()
	city_lbl.text = t.city
	city_lbl.add_theme_font_size_override("font_size", 15)
	info_row.add_child(city_lbl)

	var dot1 := Label.new()
	dot1.text = "•"
	dot1.add_theme_font_size_override("font_size", 15)
	info_row.add_child(dot1)

	info_row.add_child(_make_rep_stars_control(t.reputation))

	var dot2 := Label.new()
	dot2.text = "•"
	dot2.add_theme_font_size_override("font_size", 15)
	info_row.add_child(dot2)

	var cap_lbl := Label.new()
	cap_lbl.text = "%d.000 esp." % (t.stadium_capacity / 1000)
	cap_lbl.add_theme_font_size_override("font_size", 15)
	info_row.add_child(cap_lbl)

	btn.pressed.connect(func(): _select_team(t.id, btn))
	return btn


func _select_team(team_id: int, btn: Button) -> void:
	# Quitar resaltado anterior
	if _selected_btn != null:
		_selected_btn.remove_theme_stylebox_override("normal")

	_selected_team_id = team_id
	_selected_btn     = btn
	%ErrorLabel.text  = ""

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.35, 0.1, 1)
	style.set_corner_radius_all(4)
	style.border_width_left   = 2
	style.border_width_right  = 2
	style.border_width_top    = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.9, 0.3, 1)
	btn.add_theme_stylebox_override("normal", style)


# ---------------------------------------------------------------------------
# Confirmar

func _on_start() -> void:
	var manager_name: String = %InputManager.text.strip_edges()

	if manager_name.is_empty():
		_show_error("Escribe el nombre del entrenador.")
		%InputManager.grab_focus()
		return
	if _selected_team_id == -1:
		_show_error("Selecciona un equipo de la lista.")
		return

	GameManager.start_game(manager_name, _selected_team_id)
	get_tree().change_scene_to_file("res://scenes/game/office/office.tscn")


# ---------------------------------------------------------------------------
# Helpers

func _rep_stars(rep: int) -> String:
	var stars: int = int(round(rep / 20.0))
	stars = clampi(stars, 0, 5)
	return "★".repeat(stars) + "☆".repeat(5 - stars)


func _make_rep_stars_control(rep: int) -> Control:
	var stars: int = int(round(rep / 20.0))
	stars = clampi(stars, 0, 5)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 2)

	for i: int in range(5):
		var icon := TextureRect.new()
		icon.texture = ICON_STAR
		icon.custom_minimum_size = Vector2(14, 14)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.modulate = Color(1.0, 0.84, 0.2, 1.0) if i < stars else Color(0.45, 0.48, 0.52, 0.65)
		row.add_child(icon)

	return row


func _show_error(msg: String) -> void:
	%ErrorLabel.text = msg
