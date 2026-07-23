extends Control

const ICON_BACK := preload("res://assets/ui/icons/back-white.png")
const ICON_SIZE_NAV := 28

## Posiciones normalizadas (0–1) en el campo para cada formación.
## Orden: POR, DEF×n, MED×n, DEL×n  (de abajo arriba en portrait)
const FORMATIONS: Dictionary = {
	"4-4-2": [
		Vector2(0.5,  0.88),                                          # POR
		Vector2(0.15, 0.70), Vector2(0.38, 0.70),                    # DEF
		Vector2(0.62, 0.70), Vector2(0.85, 0.70),
		Vector2(0.15, 0.50), Vector2(0.38, 0.50),                    # MED
		Vector2(0.62, 0.50), Vector2(0.85, 0.50),
		Vector2(0.33, 0.26), Vector2(0.67, 0.26),                    # DEL
	],
	"4-3-3": [
		Vector2(0.5,  0.88),
		Vector2(0.15, 0.70), Vector2(0.38, 0.70),
		Vector2(0.62, 0.70), Vector2(0.85, 0.70),
		Vector2(0.25, 0.50), Vector2(0.5, 0.50), Vector2(0.75, 0.50),
		Vector2(0.2,  0.24), Vector2(0.5,  0.20), Vector2(0.8,  0.24),
	],
	"5-3-2": [
		Vector2(0.5,  0.88),
		Vector2(0.1,  0.70), Vector2(0.3,  0.70), Vector2(0.5,  0.68),
		Vector2(0.7,  0.70), Vector2(0.9,  0.70),
		Vector2(0.25, 0.48), Vector2(0.5,  0.46), Vector2(0.75, 0.48),
		Vector2(0.35, 0.24), Vector2(0.65, 0.24),
	],
}

var _team: Team = null
var _formation: String = "4-4-2"
## slot_index -> player_id  (11 slots, -1 = vacío)
var _slots: Array[int] = []
var _selected_slot: int = -1
var _slot_buttons: Array[Button] = []


func _ready() -> void:
	_team = GameManager.get_player_team()
	%BtnBack.icon = ICON_BACK
	%BtnBack.add_theme_constant_override("icon_max_width", ICON_SIZE_NAV)
	%BtnBack.text = ""
	GameManager.tactics_badge_active = false
	if _team:
		_formation = _team.formation
		_slots.assign(_team.starting_eleven.duplicate())
	while _slots.size() < 11:
		_slots.append(-1)

	# Avisar si hay sancionados/lesionados en el once (sin expulsarlos automáticamente)
	var _warned: Array[String] = []
	for i in range(_slots.size()):
		var _wp: Player = GameManager.get_player(_slots[i])
		if _wp != null and (_wp.suspended or _wp.injured):
			_warned.append(_wp.full_name)
	if not _warned.is_empty():
		var dlg := AcceptDialog.new()
		dlg.title = "Jugadores no disponibles en el Once"
		dlg.dialog_text = "Los siguientes jugadores no pueden jugar el próximo partido:\n\n• " + "\n• ".join(_warned) + "\n\nRetíralos manualmente de la alineación."
		add_child(dlg)
		dlg.popup_centered()

	%BtnBack.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/game/office/office.tscn"))
	%BtnSave.pressed.connect(_save_lineup)
	%BtnAutoLineup.pressed.connect(_auto_lineup)
	%BtnFormation442.pressed.connect(func(): _set_formation("4-4-2"))
	%BtnFormation433.pressed.connect(func(): _set_formation("4-3-3"))
	%BtnFormation532.pressed.connect(func(): _set_formation("5-3-2"))
	%BtnTeamTactics.pressed.connect(func(): (%TeamTacticsDialog as TeamTacticsDialog).open(_team))

	_build_field()
	_build_bench()


# ---------------------------------------------------------------------------
# Campo

func _build_field() -> void:
	var field: Control = %FieldSlots
	for child in field.get_children():
		child.queue_free()
	_slot_buttons.clear()

	var positions: Array = FORMATIONS.get(_formation, FORMATIONS["4-4-2"])
	for i in range(11):
		var pos: Vector2 = positions[i]
		var btn := _make_slot_button(i, pos)
		field.add_child(btn)
		_slot_buttons.append(btn)

	_refresh_field()


func _make_slot_button(idx: int, norm_pos: Vector2) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(64, 64)
	btn.size = Vector2(64, 64)
	# Se posiciona en _on_field_resized cuando el campo tenga tamaño
	btn.set_meta("slot_idx", idx)
	btn.set_meta("norm_pos", norm_pos)
	btn.pressed.connect(func(): _on_slot_pressed(idx))

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.45, 0.15, 0.9)
	style.set_corner_radius_all(32)
	style.border_width_left   = 2
	style.border_width_right  = 2
	style.border_width_top    = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.8, 0.3, 1)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_font_size_override("font_size", 11)
	return btn


func _refresh_field() -> void:
	var field: Control = %FieldSlots
	var positions: Array = FORMATIONS.get(_formation, FORMATIONS["4-4-2"])
	var field_size := field.size

	for i in range(_slot_buttons.size()):
		var btn: Button = _slot_buttons[i]
		var norm_pos: Vector2 = positions[i]
		var px := norm_pos.x * field_size.x - 32.0
		var py := norm_pos.y * field_size.y - 32.0
		btn.position = Vector2(px, py)

		var pid: int = _slots[i] if i < _slots.size() else -1
		var p: Player = GameManager.get_player(pid)
		if p:
			btn.text = p.get_position_abbr() + "\n" + p.full_name.split(" ")[0]
			var style := btn.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
			if p.suspended or p.red_carded:
				style.bg_color = Color(0.45, 0.08, 0.08, 0.95)
				style.border_color = Color(0.95, 0.2, 0.2, 1)
			elif i == _selected_slot:
				style.border_color = Color(1.0, 0.9, 0.2, 1)
				style.border_width_left   = 3
				style.border_width_right  = 3
				style.border_width_top    = 3
				style.border_width_bottom = 3
			else:
				style.border_color = Color(0.3, 0.8, 0.3, 1)
			btn.add_theme_stylebox_override("normal", style)
		else:
			btn.text = "?"
			var style := btn.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
			style.bg_color = Color(0.2, 0.2, 0.2, 0.7)
			style.border_color = Color(0.5, 0.5, 0.5, 1)
			btn.add_theme_stylebox_override("normal", style)

	%FormationLabel.text = _formation


func _on_slot_pressed(idx: int) -> void:
	if _selected_slot == -1:
		_selected_slot = idx
	else:
		# Intercambiar los dos slots seleccionados
		var tmp: int = _slots[idx]
		_slots[idx] = _slots[_selected_slot]
		_slots[_selected_slot] = tmp
		_selected_slot = -1
		_build_bench()
	_refresh_field()


# ---------------------------------------------------------------------------
# Banquillo

func _build_bench() -> void:
	var list: VBoxContainer = %BenchList
	for child in list.get_children():
		child.queue_free()

	var nc_list: VBoxContainer = %NoConvocadosList
	for child in nc_list.get_children():
		child.queue_free()

	if _team == null:
		return

	for pid: int in _team.player_ids:
		if _slots.has(pid):
			continue
		var p: Player = GameManager.get_player(pid)
		if p == null:
			continue
		if p.suspended or p.injured:
			nc_list.add_child(_make_no_convocado_row(p))
		else:
			list.add_child(_make_bench_row(p))


func _make_bench_row(p: Player) -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 52)
	btn.text = "[%s] %s  (%d)" % [p.get_position_abbr(), p.full_name.split(" ")[0], p.get_overall()]
	btn.add_theme_font_size_override("font_size", 15)
	btn.pressed.connect(func(): _on_bench_player_pressed(p.id))
	return btn


func _make_no_convocado_row(p: Player) -> Control:
	var lbl := Label.new()
	var reason: String
	if p.injured:
		reason = "Lesionado (%d sem.)" % p.injury_weeks
	elif p.red_carded:
		reason = "Roja directa"
	else:
		reason = "Sancionado"
	lbl.text = "[%s] %s  %s" % [p.get_position_abbr(), p.full_name.split(" ")[0], reason]
	lbl.custom_minimum_size = Vector2(0, 44)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.3, 0.3, 1))
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return lbl


func _on_bench_player_pressed(pid: int) -> void:
	if _selected_slot == -1:
		return
	var p: Player = GameManager.get_player(pid)
	if p != null and (p.suspended or p.injured):
		return  # No disponible
	# Poner jugador del banquillo en el slot seleccionado, sacar el anterior
	_slots[_selected_slot] = pid
	_selected_slot = -1
	_refresh_field()
	_build_bench()


# ---------------------------------------------------------------------------
# Formación

func _set_formation(f: String) -> void:
	_formation = f
	# Actualizar estado visual de los botones de formación
	%BtnFormation442.button_pressed = (f == "4-4-2")
	%BtnFormation433.button_pressed = (f == "4-3-3")
	%BtnFormation532.button_pressed = (f == "5-3-2")
	_build_field()
	_build_bench()


# ---------------------------------------------------------------------------
# Alineación automática

## Rellena los 11 slots con los mejores jugadores disponibles (no sancionados/lesionados)
## respetando el esquema de posiciones de la formación activa.
func _auto_lineup() -> void:
	if _team == null:
		return

	# Jugadores disponibles ordenados por OVR descendente
	var available: Array[Player] = []
	for pid: int in _team.player_ids:
		var p: Player = GameManager.get_player(pid)
		if p != null and not p.suspended and not p.injured:
			available.append(p)
	available.sort_custom(func(a: Player, b: Player) -> bool:
		return a.get_overall() > b.get_overall())

	# Determinar cuántos slots hay por posición según la formación
	var parts := _formation.split("-")
	var n_def: int = int(parts[0]) if parts.size() > 0 else 4
	var n_mid: int = int(parts[1]) if parts.size() > 1 else 4
	var n_fwd: int = int(parts[2]) if parts.size() > 2 else 2

	# Slots requeridos: 1 POR, n_def DEF, n_mid MID, n_fwd FWD
	var required: Array[Player.Position] = [Player.Position.GK]
	for _i in range(n_def): required.append(Player.Position.DEF)
	for _i in range(n_mid): required.append(Player.Position.MID)
	for _i in range(n_fwd): required.append(Player.Position.FWD)

	_slots.fill(-1)
	var used: Array[int] = []

	# Primera pasada: asignar por posición exacta (mejor OVR de cada posición)
	for i in range(required.size()):
		var pos: Player.Position = required[i]
		for p: Player in available:
			if used.has(p.id):
				continue
			if p.position == pos:
				_slots[i] = p.id
				used.append(p.id)
				break

	# Segunda pasada: rellenar huecos con el mejor disponible sin importar posición
	for i in range(_slots.size()):
		if _slots[i] != -1:
			continue
		for p: Player in available:
			if used.has(p.id):
				continue
			_slots[i] = p.id
			used.append(p.id)
			break

	_selected_slot = -1
	_refresh_field()
	_build_bench()


# ---------------------------------------------------------------------------
# Guardar

func _save_lineup() -> void:
	if _team == null:
		return
	for pid: int in _slots:
		var p: Player = GameManager.get_player(pid)
		if p != null and (p.suspended or p.injured):
			var dlg := AcceptDialog.new()
			dlg.title = "Alineación inválida"
			dlg.dialog_text = "%s no está disponible y no puede jugar.\nRetíralo de la alineación." % p.full_name
			add_child(dlg)
			dlg.popup_centered()
			return
	_team.formation = _formation
	_team.starting_eleven.clear()
	for pid: int in _slots:
		_team.starting_eleven.append(pid)
	get_tree().change_scene_to_file("res://scenes/game/office/office.tscn")


# ---------------------------------------------------------------------------
# Reposicionar botones cuando el campo cambia de tamaño

func _process(_delta: float) -> void:
	if not _slot_buttons.is_empty():
		_refresh_field()
