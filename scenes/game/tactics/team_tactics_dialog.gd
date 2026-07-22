extends Control
class_name TeamTacticsDialog

const ICON_CHECK := preload("res://assets/ui/icons/checkmark-white.png")
const ICON_CLOSE := preload("res://assets/ui/icons/close-white.png")

## Diálogo de tácticas de equipo (ataque + defensa).
## Se construye completamente por código para no depender de .tscn.

# ── Referencias a controles internos ────────────────────────────────────────
var _btn_attack: Array[Button] = []   # índices 0=Ofensivo 1=Mixto 2=Especulativo
var _slider_toque: HSlider
var _lbl_toque: Label
var _slider_counter: HSlider
var _lbl_counter: Label

var _btn_tackle: Array[Button] = []   # 0=Suave 1=Media 2=Agresiva
var _btn_marking: Array[Button] = []  # 0=Zonal 1=Al hombre
var _btn_clearance: Array[Button] = [] # 0=Jugado 1=Largo
var _btn_press: Array[Button] = []    # 0=Propio 1=Medio 2=Rival

var _team: Team = null


func _ready() -> void:
	_build_ui()
	hide()


## Abre el diálogo cargando los valores actuales del equipo.
func open(team: Team) -> void:
	_team = team
	_load_values()
	show()


# ---------------------------------------------------------------------------
# Carga / guardado

func _load_values() -> void:
	if _team == null:
		return
	_select_group(_btn_attack, _team.tactic_attack_style)
	_slider_toque.value   = _team.tactic_toque_pct
	_slider_counter.value = _team.tactic_counter_pct
	_select_group(_btn_tackle,    _team.tactic_tackle_style)
	_select_group(_btn_marking,   _team.tactic_marking)
	_select_group(_btn_clearance, _team.tactic_clearance)
	_select_group(_btn_press,     _team.tactic_press_line)
	_update_slider_labels()


func _save_and_close() -> void:
	if _team == null:
		hide()
		return
	_team.tactic_attack_style = _active_index(_btn_attack)
	_team.tactic_toque_pct    = int(_slider_toque.value)
	_team.tactic_counter_pct  = int(_slider_counter.value)
	_team.tactic_tackle_style = _active_index(_btn_tackle)
	_team.tactic_marking      = _active_index(_btn_marking)
	_team.tactic_clearance    = _active_index(_btn_clearance)
	_team.tactic_press_line   = _active_index(_btn_press)
	hide()


# ---------------------------------------------------------------------------
# Construcción de UI

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Overlay oscuro
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.70)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	# Panel central con scroll
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(700, 0)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.09, 0.11, 0.17, 0.98)
	st.set_corner_radius_all(8)
	st.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", st)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# Título
	var title_lbl := Label.new()
	title_lbl.text = "Tácticas de Equipo"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 23)
	vbox.add_child(title_lbl)

	vbox.add_child(HSeparator.new())

	# ── ATAQUE ───────────────────────────────────────────────────────────────
	var atk_panel := _colored_section(vbox, Color.html("1c4f8c"))

	atk_panel.add_child(_section_title("⚔  ATAQUE"))

	# Estilo de juego
	atk_panel.add_child(_lbl("Estilo de juego:"))
	var atk_style_row := HBoxContainer.new()
	atk_style_row.add_theme_constant_override("separation", 10)
	atk_panel.add_child(atk_style_row)
	_btn_attack = _toggle_group(atk_style_row, ["Ofensivo", "Mixto", "Especulativo"])

	# Juego al toque vs. balón largo
	atk_panel.add_child(_lbl("Juego al toque / Balón largo:"))
	var toque_row := HBoxContainer.new()
	toque_row.add_theme_constant_override("separation", 10)
	atk_panel.add_child(toque_row)
	toque_row.add_child(_mini_lbl("Balón largo"))
	_slider_toque = _slider(0, 100, 5, 320)
	toque_row.add_child(_slider_toque)
	toque_row.add_child(_mini_lbl("Al toque"))
	_lbl_toque = _value_lbl()
	toque_row.add_child(_lbl_toque)
	_slider_toque.value_changed.connect(func(_v): _update_slider_labels())

	# Contragolpe
	atk_panel.add_child(_lbl("Tendencia al contragolpe:"))
	var counter_row := HBoxContainer.new()
	counter_row.add_theme_constant_override("separation", 10)
	atk_panel.add_child(counter_row)
	counter_row.add_child(_mini_lbl("Sin contra"))
	_slider_counter = _slider(0, 100, 5, 320)
	counter_row.add_child(_slider_counter)
	counter_row.add_child(_mini_lbl("Máxima"))
	_lbl_counter = _value_lbl()
	counter_row.add_child(_lbl_counter)
	_slider_counter.value_changed.connect(func(_v): _update_slider_labels())

	vbox.add_child(HSeparator.new())

	# ── DEFENSA ──────────────────────────────────────────────────────────────
	var def_panel := _colored_section(vbox, Color.html("4a1c1c"))

	def_panel.add_child(_section_title("🛡  DEFENSA"))

	def_panel.add_child(_lbl("Tipo de entradas:"))
	var tackle_row := HBoxContainer.new()
	tackle_row.add_theme_constant_override("separation", 10)
	def_panel.add_child(tackle_row)
	_btn_tackle = _toggle_group(tackle_row, ["Suave", "Media", "Agresiva"])

	def_panel.add_child(_lbl("Marcaje:"))
	var marking_row := HBoxContainer.new()
	marking_row.add_theme_constant_override("separation", 10)
	def_panel.add_child(marking_row)
	_btn_marking = _toggle_group(marking_row, ["Zonal", "Al hombre"])

	def_panel.add_child(_lbl("Despejes:"))
	var clear_row := HBoxContainer.new()
	clear_row.add_theme_constant_override("separation", 10)
	def_panel.add_child(clear_row)
	_btn_clearance = _toggle_group(clear_row, ["Balón jugado", "Balón largo"])

	def_panel.add_child(_lbl("Presionar desde campo:"))
	var press_row := HBoxContainer.new()
	press_row.add_theme_constant_override("separation", 10)
	def_panel.add_child(press_row)
	_btn_press = _toggle_group(press_row, ["Propio", "Medio", "Rival"])

	vbox.add_child(HSeparator.new())

	# ── Botones ───────────────────────────────────────────────────────────────
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 24)
	vbox.add_child(btn_row)

	var btn_cancel := Button.new()
	btn_cancel.text = "Cancelar"
	btn_cancel.icon = ICON_CLOSE
	btn_cancel.custom_minimum_size = Vector2(140, 52)
	btn_cancel.add_theme_font_size_override("font_size", 17)
	btn_cancel.pressed.connect(hide)
	btn_row.add_child(btn_cancel)

	var btn_save := Button.new()
	btn_save.text = "Guardar Tácticas"
	btn_save.icon = ICON_CHECK
	btn_save.custom_minimum_size = Vector2(210, 52)
	btn_save.add_theme_font_size_override("font_size", 17)
	btn_save.pressed.connect(_save_and_close)
	btn_row.add_child(btn_save)


# ---------------------------------------------------------------------------
# Helpers de UI

func _colored_section(parent: Control, color: Color) -> VBoxContainer:
	var pc := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = color
	st.set_corner_radius_all(6)
	st.set_content_margin_all(14)
	pc.add_theme_stylebox_override("panel", st)
	parent.add_child(pc)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	pc.add_child(inner)
	return inner


func _section_title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	return l


func _lbl(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	return l


func _mini_lbl(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	return l


func _value_lbl() -> Label:
	var l := Label.new()
	l.custom_minimum_size = Vector2(48, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 15)
	return l


func _slider(mn: float, mx: float, step: float, min_w: int) -> HSlider:
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = step
	s.custom_minimum_size = Vector2(min_w, 32)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return s


func _toggle_group(parent: HBoxContainer, labels: Array) -> Array[Button]:
	var btns: Array[Button] = []
	for i in range(labels.size()):
		var b := Button.new()
		b.text = labels[i]
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(110, 44)
		b.add_theme_font_size_override("font_size", 15)
		var idx := i
		b.pressed.connect(func(): _select_group(btns, idx))
		parent.add_child(b)
		btns.append(b)
	return btns


func _select_group(btns: Array[Button], idx: int) -> void:
	for i in range(btns.size()):
		btns[i].button_pressed = (i == idx)


func _active_index(btns: Array[Button]) -> int:
	for i in range(btns.size()):
		if btns[i].button_pressed:
			return i
	return 0


func _update_slider_labels() -> void:
	_lbl_toque.text   = "%d%%" % int(_slider_toque.value)
	_lbl_counter.text = "%d%%" % int(_slider_counter.value)
