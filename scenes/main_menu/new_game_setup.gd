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
	%BtnUseGenerated.pressed.connect(func(): _set_source_mode(SOURCE_GENERATED))
	%BtnLoadJson.pressed.connect(_on_load_json_pressed)
	%BtnUseDefaultJson.pressed.connect(_on_use_default_json_pressed)
	%BtnLoadJsonText.pressed.connect(_on_load_json_text_pressed)
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
	%BtnUseJsonSource.visible = false
	%DataSourcePicker.visible = false
	_prefill_json_path()
	_set_source_mode(SOURCE_GENERATED)
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
	_set_source_mode(idx)


func _set_source_mode(mode: int) -> void:
	_source_mode = mode
	%DataSourcePicker.select(mode)
	_selected_team_id = -1
	_selected_btn = null
	_set_json_controls_visible(_source_mode == SOURCE_JSON)
	_set_source_buttons_state()
	if _source_mode == SOURCE_GENERATED:
		_prepare_generated_data()
		return

	_data_ready_for_mode = false
	_clear_team_list()
	_clear_league_picker()
	_show_error("Selecciona un JSON y pulsa 'Cargar JSON'.")


func _set_source_buttons_state() -> void:
	var generated_style := StyleBoxFlat.new()
	generated_style.bg_color = Color(0.14, 0.22, 0.14, 1)
	generated_style.border_color = Color(0.2, 0.45, 0.2, 1)
	generated_style.border_width_left = 2
	generated_style.border_width_right = 2
	generated_style.border_width_top = 2
	generated_style.border_width_bottom = 2

	var json_style := StyleBoxFlat.new()
	json_style.bg_color = Color(0.14, 0.22, 0.14, 1)
	json_style.border_color = Color(0.2, 0.45, 0.2, 1)
	json_style.border_width_left = 2
	json_style.border_width_right = 2
	json_style.border_width_top = 2
	json_style.border_width_bottom = 2

	var active_style := StyleBoxFlat.new()
	active_style.bg_color = Color(0.1, 0.35, 0.1, 1)
	active_style.border_color = Color(0.3, 0.9, 0.3, 1)
	active_style.border_width_left = 2
	active_style.border_width_right = 2
	active_style.border_width_top = 2
	active_style.border_width_bottom = 2

	%BtnUseGenerated.add_theme_stylebox_override("normal", active_style if _source_mode == SOURCE_GENERATED else generated_style)
	%BtnUseJsonSource.add_theme_stylebox_override("normal", active_style if _source_mode == SOURCE_JSON else json_style)


func _set_json_controls_visible(visible: bool) -> void:
	if not visible:
		%InputJsonPath.text = ""
		%InputJsonText.text = ""
	%JsonRow.visible = visible
	%BtnLoadJson.visible = visible
	%BtnUseDefaultJson.visible = visible
	%LblJsonText.visible = visible
	%InputJsonText.visible = visible
	%BtnLoadJsonText.visible = visible


func _on_browse_json_pressed() -> void:
	if OS.get_name() == "Windows":
		var selected_path := _pick_json_with_windows_dialog()
		if selected_path != "":
			_json_path = selected_path
			%InputJsonPath.text = selected_path
			return

	var fd: FileDialog = %JsonFileDialog
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.use_native_dialog = false
	fd.root_subfolder = ""
	fd.filters = PackedStringArray(["*.json ; Archivo JSON", "*.* ; Todos los archivos"])

	var base_dir := OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)
	if _json_path.strip_edges() != "":
		var hinted_dir := _json_path.get_base_dir()
		if DirAccess.dir_exists_absolute(hinted_dir):
			base_dir = hinted_dir
	elif not DirAccess.dir_exists_absolute(base_dir):
		base_dir = "C:/Users"
	fd.current_dir = base_dir

	%JsonFileDialog.popup_centered_ratio(0.8)


func _pick_json_with_windows_dialog() -> String:
	var output: Array = []
	var ps_script := (
		"Add-Type -AssemblyName System.Windows.Forms; "
		+ "$dlg = New-Object System.Windows.Forms.OpenFileDialog; "
		+ "$dlg.Title = 'Selecciona archivo JSON'; "
		+ "$dlg.Filter = 'Archivo JSON (*.json)|*.json|Todos los archivos (*.*)|*.*'; "
		+ "$dlg.InitialDirectory = 'C:\\'; "
		+ "if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { "
		+ "Write-Output $dlg.FileName "
		+ "}"
	)
	var args: PackedStringArray = ["-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", ps_script]
	var exit_code := OS.execute("powershell", args, output, true)
	if exit_code != 0 or output.is_empty():
		return ""
	return str(output[0]).strip_edges()


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


func _on_use_default_json_pressed() -> void:
	var default_path := _get_default_json_path()
	if not FileAccess.file_exists(default_path):
		_show_error("No se encontró el JSON por defecto en Desktop/XE42852.")
		return
	_json_path = default_path
	%InputJsonPath.text = default_path
	_prepare_json_data(default_path)


func _on_load_json_text_pressed() -> void:
	var json_text := %InputJsonText.text
	if json_text.strip_edges().is_empty():
		_show_error("Pega el contenido del JSON antes de cargar.")
		return
	_prepare_json_text_data(json_text)


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


func _prepare_json_text_data(json_text: String) -> void:
	_data_ready_for_mode = false
	var ok := GameManager.prepare_new_game_from_json_text(json_text)
	if not ok:
		_clear_team_list()
		_clear_league_picker()
		_show_error(_non_empty_error("No se pudo cargar el JSON pegado."))
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


func _prefill_json_path() -> void:
	var default_path := _get_default_json_path()
	if FileAccess.file_exists(default_path):
		_json_path = default_path
		%InputJsonPath.text = default_path


func _get_default_json_path() -> String:
	return OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP).path_join("XE42852").path_join("Temporada9798.json")


# ---------------------------------------------------------------------------
# Helpers

func _rep_stars(rep: int) -> String:
	var stars: int = int(round(rep / 20.0))
	stars = clampi(stars, 0, 5)
	return "★".repeat(stars) + "☆".repeat(5 - stars)


func _show_error(msg: String) -> void:
	%ErrorLabel.text = msg
