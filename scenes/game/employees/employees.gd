extends Control
class_name EmployeesScreen

## Pantalla "Personal del Club": entrenadores secundarios y personal de apoyo.

# ────────────────────────────────────────────────────────────────────────────
# Datos estáticos

const WEEKLY_COSTS: Array[int]  = [0, 500, 1_500, 4_000, 9_000, 20_000]
const LEVEL_NAMES: Array[String] = ["Sin contratar", "Básico", "Bueno", "Experto", "Maestro", "Élite"]
const LEVEL_COLORS: Array[Color] = [
	Color(0.45, 0.45, 0.45, 1),  # Sin contratar
	Color(0.55, 0.80, 0.55, 1),  # Básico
	Color(0.40, 0.75, 1.00, 1),  # Bueno
	Color(0.90, 0.75, 0.20, 1),  # Experto
	Color(1.00, 0.50, 0.15, 1),  # Maestro
	Color(0.90, 0.30, 0.90, 1),  # Élite
]

## id, nombre, icono, efecto corto
const COACH_DEFS: Array = [
	["staff_gk_coach",        "Entr. Porteros",    "🧤", "Mejora la portería de los porteros semanalmente."],
	["staff_passing_coach",   "Entr. de Pase",     "🎯", "Incrementa el pase de todos los jugadores."],
	["staff_dribbling_coach", "Entr. de Regate",   "⚡", "Incrementa el regate de los jugadores de campo."],
	["staff_shooting_coach",  "Entr. de Remate",   "🥅", "Incrementa el remate de delanteros y mediapuntas."],
	["staff_tackling_coach",  "Entr. de Entradas", "🛡", "Mejora la defensa de defensas y centrocampistas."],
	["staff_physical_coach",  "Preparador Físico", "💪", "Mejora el físico y velocidad de toda la plantilla."],
]
const STAFF_DEFS: Array = [
	["staff_physio",          "Fisioterapeuta",    "💉", "Reduce tiempo de lesión y probabilidad de lesionarse."],
	["staff_psychologist",    "Psicólogo",         "🧠", "Amortigua la pérdida de moral tras las derrotas."],
	["staff_scout",           "Observador",        "🔭", "Analiza el equipo rival con mayor profundidad."],
	["staff_tech_secretary",  "Secretario Técnico","📋", "Mejora las condiciones en negociaciones de fichajes."],
	["staff_youth_coach",     "Entr. Juveniles",   "🌱", "Los jugadores jóvenes progresan más rápido."],
	["staff_talent_scout",    "Ojeador",           "👁", "Recomienda jugadores de calidad en el mercado."],
	["staff_groundskeeper",   "Enc. del Campo",    "🌿", "Mantiene el campo en perfectas condiciones."],
]

# ────────────────────────────────────────────────────────────────────────────
# Estado

var _team: Team = null
var _cash_lbl: Label = null
var _cards: Dictionary = {}   # staff_id -> Label (level label on card)
var _hire_overlay: Control = null
var _fire_overlay: Control = null


func _ready() -> void:
	_team = GameManager.get_player_team()
	_build_ui()


# ────────────────────────────────────────────────────────────────────────────
# Construcción principal

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.07, 0.09, 0.13, 1)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	# ── Top bar ──────────────────────────────────────────────────────────────
	var topbar := HBoxContainer.new()
	topbar.custom_minimum_size = Vector2(0, 64)
	root.add_child(topbar)

	var btn_back := Button.new()
	btn_back.text = "◀"
	btn_back.custom_minimum_size = Vector2(64, 64)
	btn_back.add_theme_font_size_override("font_size", 22)
	btn_back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/game/office/office.tscn"))
	topbar.add_child(btn_back)

	var title := Label.new()
	title.text = "Personal del Club"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.90, 0.85, 0.50, 1))
	topbar.add_child(title)

	_cash_lbl = Label.new()
	_cash_lbl.custom_minimum_size = Vector2(200, 0)
	_cash_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_cash_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cash_lbl.add_theme_font_size_override("font_size", 16)
	_cash_lbl.add_theme_color_override("font_color", Color(0.55, 0.90, 0.40, 1))
	topbar.add_child(_cash_lbl)

	var cash_spacer := Control.new()
	cash_spacer.custom_minimum_size = Vector2(12, 0)
	topbar.add_child(cash_spacer)

	root.add_child(HSeparator.new())

	# ── Scroll principal ──────────────────────────────────────────────────────
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 18)
	var mg := MarginContainer.new()
	mg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mg.add_theme_constant_override("margin_left",   20)
	mg.add_theme_constant_override("margin_right",  20)
	mg.add_theme_constant_override("margin_top",    18)
	mg.add_theme_constant_override("margin_bottom", 18)
	mg.add_child(content)
	scroll.add_child(mg)

	# Sección: Segundos Entrenadores
	content.add_child(_section_title("🎓  Segundos Entrenadores"))
	var coach_grid := _make_grid(COACH_DEFS, content)
	content.add_child(coach_grid)

	content.add_child(HSeparator.new())

	# Sección: Personal de Apoyo
	content.add_child(_section_title("👥  Personal de Apoyo"))
	var staff_grid := _make_grid(STAFF_DEFS, content)
	content.add_child(staff_grid)

	# ── Botones de acción ─────────────────────────────────────────────────────
	root.add_child(HSeparator.new())

	var btn_row := HBoxContainer.new()
	btn_row.custom_minimum_size = Vector2(0, 68)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 32)
	root.add_child(btn_row)

	var btn_hire := Button.new()
	btn_hire.text = "💼  Contratar / Mejorar"
	btn_hire.custom_minimum_size = Vector2(240, 56)
	btn_hire.add_theme_font_size_override("font_size", 18)
	btn_hire.add_theme_color_override("font_color", Color(0.20, 0.90, 0.50, 1))
	btn_hire.pressed.connect(_open_hire_dialog)
	btn_row.add_child(btn_hire)

	var btn_fire := Button.new()
	btn_fire.text = "❌  Despedir Personal"
	btn_fire.custom_minimum_size = Vector2(220, 56)
	btn_fire.add_theme_font_size_override("font_size", 18)
	btn_fire.add_theme_color_override("font_color", Color(0.95, 0.35, 0.25, 1))
	btn_fire.pressed.connect(_open_fire_dialog)
	btn_row.add_child(btn_fire)

	_refresh_cash()


func _make_grid(defs: Array, _parent: VBoxContainer) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	for entry: Array in defs:
		grid.add_child(_staff_card(entry[0], entry[1], entry[2], entry[3]))
	return grid


# ────────────────────────────────────────────────────────────────────────────
# Card de empleado

func _staff_card(staff_id: String, label_txt: String, icon: String, effect: String) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.custom_minimum_size = Vector2(220, 0)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.11, 0.14, 0.20, 1)
	st.set_corner_radius_all(6)
	st.set_content_margin_all(12)
	pc.add_theme_stylebox_override("panel", st)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	pc.add_child(vb)

	# Nombre + icono
	var name_lbl := Label.new()
	name_lbl.text = "%s  %s" % [icon, label_txt]
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0, 1))
	vb.add_child(name_lbl)

	# Nivel
	var level_row := HBoxContainer.new()
	level_row.add_theme_constant_override("separation", 6)
	vb.add_child(level_row)
	var level_key_lbl := Label.new()
	level_key_lbl.text = "Nivel:"
	level_key_lbl.add_theme_font_size_override("font_size", 13)
	level_key_lbl.add_theme_color_override("font_color", Color(0.55, 0.60, 0.65, 1))
	level_row.add_child(level_key_lbl)
	var level_val_lbl := Label.new()
	level_val_lbl.add_theme_font_size_override("font_size", 13)
	level_row.add_child(level_val_lbl)
	_cards[staff_id] = level_val_lbl

	# Efecto
	var eff_lbl := Label.new()
	eff_lbl.text = effect
	eff_lbl.add_theme_font_size_override("font_size", 11)
	eff_lbl.add_theme_color_override("font_color", Color(0.55, 0.60, 0.65, 1))
	eff_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(eff_lbl)

	# Coste semanal
	var cost_lbl := Label.new()
	cost_lbl.add_theme_font_size_override("font_size", 12)
	cost_lbl.add_theme_color_override("font_color", Color(0.90, 0.75, 0.20, 1))
	vb.add_child(cost_lbl)
	# Hook para refrescar coste
	level_val_lbl.set_meta("cost_lbl", cost_lbl)
	level_val_lbl.set_meta("staff_id", staff_id)

	_refresh_card(staff_id)
	return pc


func _refresh_card(staff_id: String) -> void:
	if not _cards.has(staff_id):
		return
	var lbl: Label = _cards[staff_id]
	var level: int = _team.get(staff_id) if _team != null else 0
	lbl.text = LEVEL_NAMES[level]
	lbl.add_theme_color_override("font_color", LEVEL_COLORS[level])
	var cost_lbl: Label = lbl.get_meta("cost_lbl") as Label
	if level == 0:
		cost_lbl.text = "Sin coste"
	else:
		cost_lbl.text = "%s €/semana" % _fmt(WEEKLY_COSTS[level])


func _refresh_cash() -> void:
	if _cash_lbl != null and _team != null:
		_cash_lbl.text = "💰 %s €" % _fmt(_team.club_cash)


# ────────────────────────────────────────────────────────────────────────────
# Diálogo CONTRATAR

func _open_hire_dialog() -> void:
	if _hire_overlay != null:
		_hire_overlay.queue_free()

	_hire_overlay = _make_overlay()
	add_child(_hire_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hire_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(720, 0)
	var pst := StyleBoxFlat.new()
	pst.bg_color = Color(0.09, 0.11, 0.17, 0.98)
	pst.set_corner_radius_all(8)
	pst.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", pst)
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)

	var dlg_title := Label.new()
	dlg_title.text = "💼  Contratar / Mejorar Personal"
	dlg_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dlg_title.add_theme_font_size_override("font_size", 20)
	dlg_title.add_theme_color_override("font_color", Color(0.90, 0.85, 0.50, 1))
	vb.add_child(dlg_title)
	vb.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 420)
	vb.add_child(scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	var all_defs: Array = []
	all_defs.append_array(COACH_DEFS)
	all_defs.append_array(STAFF_DEFS)

	for entry: Array in all_defs:
		var sid: String = entry[0]
		var sname: String = entry[1]
		var sicon: String = entry[2]
		var current_lvl: int = _team.get(sid) if _team != null else 0
		list.add_child(_hire_row(sid, sicon + " " + sname, current_lvl))

	vb.add_child(HSeparator.new())

	var close_btn := Button.new()
	close_btn.text = "Cerrar"
	close_btn.custom_minimum_size = Vector2(0, 46)
	close_btn.add_theme_font_size_override("font_size", 16)
	close_btn.pressed.connect(func(): _hire_overlay.queue_free(); _hire_overlay = null)
	vb.add_child(close_btn)


func _hire_row(staff_id: String, label_txt: String, current_lvl: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var name_lbl := Label.new()
	name_lbl.text = label_txt
	name_lbl.custom_minimum_size = Vector2(220, 0)
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 15)
	row.add_child(name_lbl)

	var cur_lbl := Label.new()
	cur_lbl.text = "Actual: %s" % LEVEL_NAMES[current_lvl]
	cur_lbl.custom_minimum_size = Vector2(140, 0)
	cur_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cur_lbl.add_theme_font_size_override("font_size", 13)
	cur_lbl.add_theme_color_override("font_color", LEVEL_COLORS[current_lvl])
	row.add_child(cur_lbl)

	# OptionButton para el nivel destino
	var opt := OptionButton.new()
	opt.custom_minimum_size = Vector2(140, 38)
	for i: int in range(1, 6):
		opt.add_item("Nivel %d — %s €/sem" % [i, _fmt(WEEKLY_COSTS[i])], i)
	opt.selected = maxi(0, current_lvl - 1)
	row.add_child(opt)

	# Coste de contratación (8 semanas)
	var cost_info := Label.new()
	cost_info.custom_minimum_size = Vector2(160, 0)
	cost_info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_info.add_theme_font_size_override("font_size", 12)
	cost_info.add_theme_color_override("font_color", Color(0.90, 0.75, 0.20, 1))
	row.add_child(cost_info)

	# Actualizar etiqueta de coste al cambiar nivel
	var _update_cost_label := func():
		var new_lvl: int = opt.get_selected_id()
		var upfront: int = WEEKLY_COSTS[new_lvl] * 8
		cost_info.text = "Pago inicial: %s €" % _fmt(upfront)
	opt.item_selected.connect(func(_i): _update_cost_label.call())
	_update_cost_label.call()

	# Botón contratar
	var btn := Button.new()
	btn.text = "Contratar"
	btn.custom_minimum_size = Vector2(100, 38)
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", Color(0.20, 0.90, 0.50, 1))
	btn.pressed.connect(func():
		var new_lvl: int = opt.get_selected_id()
		var upfront: int = WEEKLY_COSTS[new_lvl] * 8
		if _team.club_cash < upfront:
			cost_info.text = "❌ Sin fondos suficientes"
			cost_info.add_theme_color_override("font_color", Color(0.90, 0.25, 0.20, 1))
			return
		_team.club_cash -= upfront
		_team.set(staff_id, new_lvl)
		cur_lbl.text = "Actual: %s" % LEVEL_NAMES[new_lvl]
		cur_lbl.add_theme_color_override("font_color", LEVEL_COLORS[new_lvl])
		cost_info.text = "✔ Contratado"
		cost_info.add_theme_color_override("font_color", Color(0.25, 0.90, 0.40, 1))
		_refresh_card(staff_id)
		_refresh_cash()
	)
	row.add_child(btn)

	return row


# ────────────────────────────────────────────────────────────────────────────
# Diálogo DESPEDIR

func _open_fire_dialog() -> void:
	if _fire_overlay != null:
		_fire_overlay.queue_free()

	# Comprobar que hay personal contratado
	var all_defs: Array = []
	all_defs.append_array(COACH_DEFS)
	all_defs.append_array(STAFF_DEFS)
	var any_hired := false
	for entry: Array in all_defs:
		if _team.get(entry[0]) > 0:
			any_hired = true
			break
	if not any_hired:
		return

	_fire_overlay = _make_overlay()
	add_child(_fire_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fire_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(580, 0)
	var pst := StyleBoxFlat.new()
	pst.bg_color = Color(0.13, 0.08, 0.08, 0.98)
	pst.set_corner_radius_all(8)
	pst.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", pst)
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)

	var dlg_title := Label.new()
	dlg_title.text = "❌  Despedir Personal"
	dlg_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dlg_title.add_theme_font_size_override("font_size", 20)
	dlg_title.add_theme_color_override("font_color", Color(0.95, 0.40, 0.30, 1))
	vb.add_child(dlg_title)

	var note := Label.new()
	note.text = "El finiquito equivale a 4 semanas de salario."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 13)
	note.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65, 1))
	vb.add_child(note)
	vb.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 300)
	vb.add_child(scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	for entry: Array in all_defs:
		var sid: String = entry[0]
		var lvl: int = _team.get(sid)
		if lvl == 0:
			continue
		var sname: String = entry[2] + "  " + entry[1]
		list.add_child(_fire_row(list, sid, sname, lvl))

	vb.add_child(HSeparator.new())

	var close_btn := Button.new()
	close_btn.text = "Cerrar"
	close_btn.custom_minimum_size = Vector2(0, 46)
	close_btn.add_theme_font_size_override("font_size", 16)
	close_btn.pressed.connect(func(): _fire_overlay.queue_free(); _fire_overlay = null)
	vb.add_child(close_btn)


func _fire_row(parent_list: VBoxContainer, staff_id: String, label_txt: String, level: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var name_lbl := Label.new()
	name_lbl.text = label_txt
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 15)
	row.add_child(name_lbl)

	var lvl_lbl := Label.new()
	lvl_lbl.text = LEVEL_NAMES[level]
	lvl_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lvl_lbl.add_theme_font_size_override("font_size", 13)
	lvl_lbl.add_theme_color_override("font_color", LEVEL_COLORS[level])
	lvl_lbl.custom_minimum_size = Vector2(90, 0)
	row.add_child(lvl_lbl)

	var severance: int = WEEKLY_COSTS[level] * 4
	var cost_lbl := Label.new()
	cost_lbl.text = "Finiquito: %s €" % _fmt(severance)
	cost_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_lbl.add_theme_font_size_override("font_size", 13)
	cost_lbl.add_theme_color_override("font_color", Color(0.90, 0.55, 0.20, 1))
	cost_lbl.custom_minimum_size = Vector2(180, 0)
	row.add_child(cost_lbl)

	var btn := Button.new()
	btn.text = "Despedir"
	btn.custom_minimum_size = Vector2(100, 36)
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", Color(0.95, 0.30, 0.20, 1))
	btn.pressed.connect(func():
		_team.club_cash -= severance
		_team.set(staff_id, 0)
		cost_lbl.text = "✔ Despedido"
		cost_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55, 1))
		btn.disabled = true
		row.modulate = Color(0.5, 0.5, 0.5, 0.6)
		_refresh_card(staff_id)
		_refresh_cash()
	)
	row.add_child(btn)

	return row


# ────────────────────────────────────────────────────────────────────────────
# Helpers

func _make_overlay() -> Control:
	var ov := Control.new()
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.70)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.add_child(dim)
	return ov


func _section_title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", Color(0.85, 0.80, 0.45, 1))
	return l


func _fmt(n: int) -> String:
	var s := str(n)
	var result := ""
	var count := 0
	for i: int in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "." + result
		result = s[i] + result
		count += 1
	return result
