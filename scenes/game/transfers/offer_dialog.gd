class_name OfferDialog
extends Control

const ICON_CHECK := preload("res://assets/ui/icons/checkmark-white.png")
const ICON_CLOSE := preload("res://assets/ui/icons/close-white.png")
const ICON_SIZE_ACTION := 20

signal offer_submitted(offer_data: Dictionary)

var _player: Player = null
var _my_team: Team = null
var _squad_ids: Array = []  # parallel to option buttons; index 0 = -1 (ninguno)

# UI refs built in _build_ui()
var _title_lbl: Label
var _val_lbl: Label
var _money_spin: SpinBox
var _budget_lbl: Label
var _p1_opt: OptionButton
var _p2_opt: OptionButton
var _clause_spin: SpinBox
var _annual_bonus_spin: SpinBox
var _years_spin: SpinBox
var _join_opt: OptionButton
var _relegation_chk: CheckBox
var _matches_chk: CheckBox
var _matches_spin: SpinBox
var _goal_bonus_chk: CheckBox
var _goal_bonus_spin: SpinBox
var _house_car_chk: CheckBox


func _ready() -> void:
	_build_ui()
	hide()


## Abre el diálogo para el jugador y equipo indicados.
func open(player: Player, my_team: Team) -> void:
	_player = player
	_my_team = my_team
	_fill_data()
	show()


# ---------------------------------------------------------------------------
# Relleno de datos al abrir

func _fill_data() -> void:
	var val: int = TransferManager.calculate_value(_player)
	_title_lbl.text = "OFERTA POR: %s  [%s]  %d años" % [
		_player.full_name, _player.get_position_abbr(), _player.age
	]
	_val_lbl.text = "Valor de mercado estimado: %s €" % _fmt(val)

	_money_spin.max_value = maxf(_my_team.budget, val * 2.0)
	_money_spin.value = val
	_budget_lbl.text = "Disponible: %s € (traspaso) · %s € (caja)" % [_fmt(_my_team.budget), _fmt(_my_team.club_cash)]

	_clause_spin.value = int(val * 1.5)
	_annual_bonus_spin.value = int(_player.salary * 52 * 0.10)
	_years_spin.value = 2
	_join_opt.selected = 0

	_relegation_chk.button_pressed = false

	_matches_chk.button_pressed = false
	_matches_spin.value = 10
	_matches_spin.editable = false
	_matches_spin.modulate = Color(1, 1, 1, 0.45)

	_goal_bonus_chk.button_pressed = false
	_goal_bonus_spin.value = 5000
	_goal_bonus_spin.editable = false
	_goal_bonus_spin.modulate = Color(1, 1, 1, 0.45)

	_house_car_chk.button_pressed = false

	_populate_squad_options()


func _populate_squad_options() -> void:
	_squad_ids = [-1]
	_p1_opt.clear()
	_p2_opt.clear()
	_p1_opt.add_item("— Ninguno —")
	_p2_opt.add_item("— Ninguno —")
	for pid: int in _my_team.player_ids:
		var p: Player = GameManager.get_player(pid)
		if p:
			_squad_ids.append(p.id)
			var entry: String = "%s  (%s %d)" % [p.full_name, p.get_position_abbr(), p.get_overall()]
			_p1_opt.add_item(entry)
			_p2_opt.add_item(entry)
	_p1_opt.selected = 0
	_p2_opt.selected = 0


# ---------------------------------------------------------------------------
# Confirmación

func _on_confirm() -> void:
	if _player == null:
		return

	var offered_ids: Array = []
	var p1_idx: int = _p1_opt.selected
	var p2_idx: int = _p2_opt.selected
	if p1_idx > 0 and p1_idx < _squad_ids.size():
		offered_ids.append(_squad_ids[p1_idx])
	if p2_idx > 0 and p2_idx < _squad_ids.size():
		var pid2: int = _squad_ids[p2_idx]
		if pid2 not in offered_ids:
			offered_ids.append(pid2)

	var data: Dictionary = {
		"player":                _player,
		"money":                 int(_money_spin.value),
		"player_offer_ids":      offered_ids,
		"release_clause":        int(_clause_spin.value),
		"annual_bonus":          int(_annual_bonus_spin.value),
		"contract_years":        int(_years_spin.value),
		"join_when":             _join_opt.selected,
		"relegation_freedom":    _relegation_chk.button_pressed,
		"matches_renewal":       _matches_chk.button_pressed,
		"matches_renewal_count": int(_matches_spin.value) if _matches_chk.button_pressed else 0,
		"goal_bonus_active":     _goal_bonus_chk.button_pressed,
		"goal_bonus_amount":     int(_goal_bonus_spin.value) if _goal_bonus_chk.button_pressed else 0,
		"house_car":             _house_car_chk.button_pressed,
	}
	offer_submitted.emit(data)
	hide()


# ---------------------------------------------------------------------------
# Constructor de UI (ejecutado en _ready)

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Fondo oscuro semitransparente
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.68)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	# Contenedor centrador (ocupa toda la pantalla, centra su hijo)
	var center_cont := CenterContainer.new()
	center_cont.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_cont.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center_cont)

	# Panel central
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(740, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.11, 0.17, 0.98)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	center_cont.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	# ── Cabecera ────────────────────────────────────────────────────────────
	_title_lbl = Label.new()
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_lbl.add_theme_font_size_override("font_size", 21)
	vbox.add_child(_title_lbl)

	_val_lbl = Label.new()
	_val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_val_lbl.add_theme_font_size_override("font_size", 14)
	_val_lbl.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6, 1))
	vbox.add_child(_val_lbl)

	vbox.add_child(HSeparator.new())

	# ── OFERTA AL EQUIPO (#336cb0) ───────────────────────────────────────────
	var team_box := _colored_section(vbox, Color.html("336cb0"))

	team_box.add_child(_section_lbl("OFERTA AL EQUIPO"))

	var money_row := HBoxContainer.new()
	money_row.add_theme_constant_override("separation", 12)
	team_box.add_child(money_row)

	money_row.add_child(_lbl("Dinero ofrecido:"))
	_money_spin = _spinbox(0, 999_000_000, 50_000, 185)
	money_row.add_child(_money_spin)
	_budget_lbl = Label.new()
	_budget_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_budget_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_budget_lbl.add_theme_font_size_override("font_size", 14)
	_budget_lbl.add_theme_color_override("font_color", Color(0.85, 1.0, 0.85, 1))
	money_row.add_child(_budget_lbl)

	var pl_row := HBoxContainer.new()
	pl_row.add_theme_constant_override("separation", 12)
	team_box.add_child(pl_row)

	pl_row.add_child(_lbl("Jugadores a incluir:"))
	_p1_opt = OptionButton.new()
	_p1_opt.custom_minimum_size = Vector2(225, 42)
	_p1_opt.add_theme_font_size_override("font_size", 14)
	pl_row.add_child(_p1_opt)
	_p2_opt = OptionButton.new()
	_p2_opt.custom_minimum_size = Vector2(225, 42)
	_p2_opt.add_theme_font_size_override("font_size", 14)
	pl_row.add_child(_p2_opt)

	# ── OFERTA AL JUGADOR (#6693bd) ──────────────────────────────────────────
	var player_box := _colored_section(vbox, Color.html("6693bd"))

	player_box.add_child(_section_lbl("OFERTA AL JUGADOR"))

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 8)
	player_box.add_child(grid)

	grid.add_child(_lbl("Cláusula de rescisión:"))
	_clause_spin = _spinbox(0, 999_000_000, 50_000, 165)
	grid.add_child(_clause_spin)

	grid.add_child(_lbl("Prima anual:"))
	_annual_bonus_spin = _spinbox(0, 10_000_000, 1_000, 145)
	grid.add_child(_annual_bonus_spin)

	grid.add_child(_lbl("Años de contrato:"))
	_years_spin = _spinbox(1, 5, 1, 85)
	grid.add_child(_years_spin)

	grid.add_child(_lbl("Incorporación:"))
	_join_opt = OptionButton.new()
	_join_opt.add_item("Inmediata")
	_join_opt.add_item("Final de temporada")
	_join_opt.custom_minimum_size = Vector2(200, 42)
	_join_opt.add_theme_font_size_override("font_size", 15)
	grid.add_child(_join_opt)

	_relegation_chk = _checkbox("Libertad por descenso")
	player_box.add_child(_relegation_chk)

	var mr := HBoxContainer.new()
	mr.add_theme_constant_override("separation", 12)
	player_box.add_child(mr)
	_matches_chk = _checkbox("Partidos para renovación automática:")
	mr.add_child(_matches_chk)
	_matches_spin = _spinbox(1, 20, 1, 82)
	_matches_spin.editable = false
	_matches_spin.modulate = Color(1, 1, 1, 0.45)
	mr.add_child(_matches_spin)
	_matches_chk.toggled.connect(func(on: bool) -> void:
		_matches_spin.editable = on
		_matches_spin.modulate = Color(1, 1, 1, 1.0 if on else 0.45)
	)

	var gr := HBoxContainer.new()
	gr.add_theme_constant_override("separation", 12)
	player_box.add_child(gr)
	_goal_bonus_chk = _checkbox("Prima por gol (€/gol):")
	gr.add_child(_goal_bonus_chk)
	_goal_bonus_spin = _spinbox(500, 500_000, 500, 125)
	_goal_bonus_spin.editable = false
	_goal_bonus_spin.modulate = Color(1, 1, 1, 0.45)
	gr.add_child(_goal_bonus_spin)
	_goal_bonus_chk.toggled.connect(func(on: bool) -> void:
		_goal_bonus_spin.editable = on
		_goal_bonus_spin.modulate = Color(1, 1, 1, 1.0 if on else 0.45)
	)

	_house_car_chk = _checkbox("Casa y coche")
	player_box.add_child(_house_car_chk)

	vbox.add_child(HSeparator.new())

	# ── Botones ─────────────────────────────────────────────────────────────
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 24)
	vbox.add_child(btn_row)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancelar"
	cancel_btn.icon = ICON_CLOSE
	cancel_btn.add_theme_constant_override("icon_max_width", ICON_SIZE_ACTION)
	cancel_btn.custom_minimum_size = Vector2(140, 52)
	cancel_btn.add_theme_font_size_override("font_size", 17)
	cancel_btn.pressed.connect(hide)
	btn_row.add_child(cancel_btn)

	var confirm_btn := Button.new()
	confirm_btn.text = "Hacer Oferta"
	confirm_btn.icon = ICON_CHECK
	confirm_btn.add_theme_constant_override("icon_max_width", ICON_SIZE_ACTION)
	confirm_btn.custom_minimum_size = Vector2(200, 52)
	confirm_btn.add_theme_font_size_override("font_size", 17)
	confirm_btn.pressed.connect(_on_confirm)
	btn_row.add_child(confirm_btn)


# ---------------------------------------------------------------------------
# Helpers

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


func _section_lbl(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 17)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	return l


func _lbl(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 15)
	return l


func _spinbox(mn: float, mx: float, step: float, min_w: int) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = mn
	s.max_value = mx
	s.step = step
	s.custom_minimum_size = Vector2(min_w, 40)
	s.add_theme_font_size_override("font_size", 15)
	return s


func _checkbox(text: String) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.add_theme_font_size_override("font_size", 15)
	return c


func _fmt(amount: int) -> String:
	if amount >= 1_000_000:
		return "%.1fM" % (amount / 1_000_000.0)
	elif amount >= 1_000:
		return "%dK" % (amount / 1_000)
	return str(amount)
