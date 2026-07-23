extends Control

const ICON_BACK := preload("res://assets/ui/icons/back-white.png")
const ICON_SIZE_NAV := 28
const SOURCE_GENERATED := 0
const SOURCE_JSON := 1

var _selected_team_id: int = -1
var _selected_btn: Button = null
var _source_mode: int = SOURCE_GENERATED
var _json_path: String = ""
var _data_ready_for_mode: bool = false


func _ready() -> void:
	%BtnBack.icon = ICON_BACK
	%BtnBack.add_theme_constant_override("icon_max_width", ICON_SIZE_NAV)
	%BtnBack.text = ""

	%BtnBack.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn"))
	%BtnStart.pressed.connect(_on_start)
	%BtnLoadJson.pressed.connect(_on_load_json_pressed)
	%BtnBrowseJson.pressed.connect(_on_browse_json_pressed)
	%DataSourcePicker.item_selected.connect(_on_source_selected)
	%JsonFileDialog.file_selected.connect(_on_json_file_selected)
	%InputManager.text_submitted.connect(func(_t: String): _on_start())
	%InputJsonPath.text_submitted.connect(func(_t: String): _on_load_json_pressed())
	%InputManager.focus_entered.connect(func(): DisplayServer.virtual_keyboard_show(""))
	%InputManager.focus_exited.connect(func(): DisplayServer.virtual_keyboard_hide())

	%LeaguePicker.item_selected.connect(_on_league_selected)
	_build_source_picker()
	_set_json_controls_visible(false)
	_prepare_generated_data()


func _build_source_picker() -> void:
	var picker: OptionButton = %DataSourcePicker
	picker.clear()
	picker.add_item("Jugadores inventados")
	picker.add_item("Cargar equipos y jugadores desde JSON")
	picker.select(SOURCE_GENERATED)

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
	if not _data_ready_for_mode:
		return
	if idx < 0 or idx >= GameManager.leagues.size():
		return
	var league: League = GameManager.leagues.values()[idx] as League
	_load_league(league)


func _load_league(league: League) -> void:
	_selected_team_id = -1
	_selected_btn = null
	_build_team_list(league)
	%ErrorLabel.text = ""


# ---------------------------------------------------------------------------
# Lista de equipos

func _build_team_list(league: League) -> void:
	_clear_team_list()
	var list: VBoxContainer = %TeamList

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


func _clear_team_list() -> void:
	var list: VBoxContainer = %TeamList
	for child in list.get_children():
		child.queue_free()


func _clear_league_picker() -> void:
	var picker: OptionButton = %LeaguePicker
	picker.clear()


func _make_team_button(t: Team) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 72)
	btn.text = "%s\n%s  •  %s  •  %s" % [
		t.name,
		t.city,
		_rep_stars(t.reputation),
		"%d.000 esp." % (t.stadium_capacity / 1000)
	]
	btn.add_theme_font_size_override("font_size", 17)
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
	if not _data_ready_for_mode:
		_show_error("Debes cargar los datos de temporada antes de empezar.")
		return
	if GameManager.leagues.is_empty():
		_show_error("No hay ligas cargadas. Revisa la fuente de datos.")
		return

	GameManager.start_game(manager_name, _selected_team_id)
	get_tree().change_scene_to_file("res://scenes/game/office/office.tscn")


func _on_source_selected(idx: int) -> void:
	_source_mode = idx
	_set_json_controls_visible(_source_mode == SOURCE_JSON)
	_selected_team_id = -1
	_selected_btn = null
	if _source_mode == SOURCE_GENERATED:
		_prepare_generated_data()
		return

	_data_ready_for_mode = false
	_clear_team_list()
	_clear_league_picker()
	_show_error("Selecciona un JSON y pulsa 'Cargar JSON'.")


func _set_json_controls_visible(visible: bool) -> void:
	%JsonRow.visible = visible
	%BtnLoadJson.visible = visible


func _on_browse_json_pressed() -> void:
	%JsonFileDialog.popup_centered_ratio(0.8)


func _on_json_file_selected(path: String) -> void:
	_json_path = path
	%InputJsonPath.text = path
	_on_load_json_pressed()


func _on_load_json_pressed() -> void:
	_json_path = %InputJsonPath.text.strip_edges()
	if _json_path.is_empty():
		_show_error("Indica una ruta de JSON para cargar la temporada.")
		return
	_prepare_json_data(_json_path)


func _prepare_generated_data() -> void:
	_data_ready_for_mode = false
	var ok := GameManager.prepare_new_game()
	if not ok:
		_show_error(_non_empty_error("No se han podido generar los datos de partida."))
		return
	_refresh_leagues_after_load()


func _prepare_json_data(path: String) -> void:
	_data_ready_for_mode = false
	var ok := GameManager.prepare_new_game(path)
	if not ok:
		_clear_team_list()
		_clear_league_picker()
		_show_error(_non_empty_error("No se pudo cargar el JSON."))
		return
	_refresh_leagues_after_load()


func _refresh_leagues_after_load() -> void:
	_build_league_picker()
	if GameManager.leagues.is_empty():
		_data_ready_for_mode = false
		_clear_team_list()
		_show_error("No hay ligas disponibles con la fuente de datos actual.")
		return
	_data_ready_for_mode = true
	_show_error("")
	%LeaguePicker.select(0)
	_load_league(GameManager.leagues.values()[0] as League)


func _non_empty_error(fallback: String) -> String:
	var msg := GameManager.new_game_setup_error.strip_edges()
	if msg.is_empty():
		return fallback
	return msg


# ---------------------------------------------------------------------------
# Helpers

func _rep_stars(rep: int) -> String:
	var stars: int = int(round(rep / 20.0))
	stars = clampi(stars, 0, 5)
	return "★".repeat(stars) + "☆".repeat(5 - stars)


func _show_error(msg: String) -> void:
	%ErrorLabel.text = msg
