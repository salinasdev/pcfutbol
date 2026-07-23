extends Control
class_name CashScreen

const ICON_BACK := preload("res://assets/ui/icons/back-white.png")
const ICON_CHECK := preload("res://assets/ui/icons/checkmark-white.png")
const ICON_CLOSE := preload("res://assets/ui/icons/close-white.png")
const ICON_MONEY := preload("res://assets/ui/icons/dollar.png")
const ICON_EXPENSE := preload("res://assets/ui/icons/warning.png")
const ICON_BANK := preload("res://assets/ui/icons/bank.png")
const ICON_CHART := preload("res://assets/ui/icons/chart.png")
const ICON_SEARCH := preload("res://assets/ui/icons/search.png")
const ICON_SIZE_NAV := 28
const ICON_SIZE_ACTION := 20

## Pantalla "Caja del Club": balance de ingresos/gastos, préstamos bancarios.

var _team: Team = null

# UI refs
var _lbl_cash:       Label
var _lbl_budget:     Label
var _lbl_wages:      Label
var _lbl_staff:      Label
var _lbl_loan:       Label
var _lbl_loan_info:  Label
var _history_list:   VBoxContainer
var _loan_overlay:   Control = null
var _detail_overlay: Control = null


func _ready() -> void:
	_team = GameManager.get_player_team()
	_build_ui()


# ---------------------------------------------------------------------------
# Construcción de UI

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
	btn_back.text = ""
	btn_back.icon = ICON_BACK
	btn_back.add_theme_constant_override("icon_max_width", ICON_SIZE_NAV)
	btn_back.custom_minimum_size = Vector2(64, 64)
	btn_back.add_theme_font_size_override("font_size", 22)
	btn_back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/game/office/office.tscn"))
	topbar.add_child(btn_back)

	var title_wrap := CenterContainer.new()
	title_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topbar.add_child(title_wrap)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	title_wrap.add_child(title_row)
	var title_icon := TextureRect.new()
	title_icon.texture = ICON_MONEY
	title_icon.custom_minimum_size = Vector2(26, 26)
	title_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	title_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title_row.add_child(title_icon)
	var title := Label.new()
	title.text = "Caja del Club"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.90, 0.85, 0.50, 1))
	title_row.add_child(title)

	var top_spacer := Control.new()
	top_spacer.custom_minimum_size = Vector2(64, 0)
	topbar.add_child(top_spacer)

	root.add_child(HSeparator.new())

	# ── Resumen: fila horizontal con saldo + gastos + préstamo ────────────────
	var summary_scroll := ScrollContainer.new()
	summary_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	summary_scroll.custom_minimum_size = Vector2(0, 280)
	summary_scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	root.add_child(summary_scroll)

	var sm := MarginContainer.new()
	sm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sm.add_theme_constant_override("margin_left",   24)
	sm.add_theme_constant_override("margin_right",  24)
	sm.add_theme_constant_override("margin_top",    16)
	sm.add_theme_constant_override("margin_bottom", 16)
	summary_scroll.add_child(sm)

	var summary_hbox := HBoxContainer.new()
	summary_hbox.add_theme_constant_override("separation", 0)
	sm.add_child(summary_hbox)

	# ── Bloque saldo + presupuesto ────────────────────────────────────────────
	var col_cash := VBoxContainer.new()
	col_cash.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_cash.add_theme_constant_override("separation", 10)
	summary_hbox.add_child(col_cash)

	col_cash.add_child(_sub("Saldo operativo del club"))
	_lbl_cash = Label.new()
	_lbl_cash.add_theme_font_size_override("font_size", 30)
	col_cash.add_child(_lbl_cash)

	col_cash.add_child(_sub("Presupuesto de fichajes"))
	_lbl_budget = Label.new()
	_lbl_budget.add_theme_font_size_override("font_size", 22)
	_lbl_budget.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0, 1))
	col_cash.add_child(_lbl_budget)

	summary_hbox.add_child(VSeparator.new())

	# ── Bloque gastos semanales ───────────────────────────────────────────────
	var col_exp := VBoxContainer.new()
	col_exp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_exp.add_theme_constant_override("separation", 8)
	var col_exp_m := MarginContainer.new()
	col_exp_m.add_theme_constant_override("margin_left", 16)
	col_exp_m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_exp_m.add_child(col_exp)
	summary_hbox.add_child(col_exp_m)

	col_exp.add_child(_section_title_with_icon("Gastos semanales estimados", ICON_EXPENSE))
	col_exp.add_child(_sub("Masa salarial de la plantilla"))
	_lbl_wages = Label.new()
	_lbl_wages.add_theme_font_size_override("font_size", 17)
	_lbl_wages.add_theme_color_override("font_color", Color(0.95, 0.45, 0.35, 1))
	col_exp.add_child(_lbl_wages)

	col_exp.add_child(_sub("Personal del club"))
	_lbl_staff = Label.new()
	_lbl_staff.add_theme_font_size_override("font_size", 17)
	_lbl_staff.add_theme_color_override("font_color", Color(0.95, 0.45, 0.35, 1))
	col_exp.add_child(_lbl_staff)

	col_exp.add_child(_sub("Cuota préstamo bancario"))
	_lbl_loan = Label.new()
	_lbl_loan.add_theme_font_size_override("font_size", 17)
	_lbl_loan.add_theme_color_override("font_color", Color(0.95, 0.45, 0.35, 1))
	col_exp.add_child(_lbl_loan)

	summary_hbox.add_child(VSeparator.new())

	# ── Bloque préstamo bancario ──────────────────────────────────────────────
	var col_loan := VBoxContainer.new()
	col_loan.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_loan.add_theme_constant_override("separation", 8)
	var col_loan_m := MarginContainer.new()
	col_loan_m.add_theme_constant_override("margin_left", 16)
	col_loan_m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_loan_m.add_child(col_loan)
	summary_hbox.add_child(col_loan_m)

	col_loan.add_child(_section_title_with_icon("Préstamo bancario", ICON_BANK))
	_lbl_loan_info = Label.new()
	_lbl_loan_info.add_theme_font_size_override("font_size", 15)
	_lbl_loan_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col_loan.add_child(_lbl_loan_info)

	var btn_loan := Button.new()
	btn_loan.text = "Solicitar préstamo"
	btn_loan.custom_minimum_size = Vector2(0, 48)
	btn_loan.add_theme_font_size_override("font_size", 16)
	btn_loan.add_theme_color_override("font_color", Color(0.90, 0.80, 0.25, 1))
	btn_loan.pressed.connect(_open_loan_dialog)
	col_loan.add_child(btn_loan)

	# ── Historial financiero (abajo, ancho completo) ──────────────────────────
	root.add_child(HSeparator.new())

	var hist_m := MarginContainer.new()
	hist_m.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hist_m.add_theme_constant_override("margin_left",   24)
	hist_m.add_theme_constant_override("margin_right",  24)
	hist_m.add_theme_constant_override("margin_top",    12)
	hist_m.add_theme_constant_override("margin_bottom", 12)
	root.add_child(hist_m)

	var hist_vbox := VBoxContainer.new()
	hist_vbox.add_theme_constant_override("separation", 6)
	hist_m.add_child(hist_vbox)

	hist_vbox.add_child(_section_title_with_icon("Historial financiero", ICON_CHART))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hist_vbox.add_child(scroll)

	_history_list = VBoxContainer.new()
	_history_list.add_theme_constant_override("separation", 4)
	_history_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_history_list)

	_refresh()


# ---------------------------------------------------------------------------
# Refresco

func _refresh() -> void:
	if _team == null:
		return

	# Saldo
	var cash_color := Color(0.25, 0.90, 0.40, 1) if _team.club_cash >= 0 else Color(0.90, 0.25, 0.20, 1)
	_lbl_cash.text = "%s €" % _fmt(_team.club_cash)
	_lbl_cash.add_theme_color_override("font_color", cash_color)
	_lbl_budget.text = "%s €" % _fmt(_team.budget)

	# Gastos semanales estimados
	var wages: int = 0
	for pid: int in _team.player_ids:
		var p := GameManager.get_player(pid)
		if p:
			wages += p.salary
	_lbl_wages.text = "−%s €/semana" % _fmt(wages)

	const WEEKLY_COSTS: Array[int] = [0, 500, 1_500, 4_000, 9_000, 20_000]
	var staff_ids: Array[String] = [
		"staff_gk_coach", "staff_passing_coach", "staff_dribbling_coach",
		"staff_shooting_coach", "staff_tackling_coach", "staff_physical_coach",
		"staff_physio", "staff_psychologist", "staff_scout",
		"staff_tech_secretary", "staff_youth_coach", "staff_talent_scout",
		"staff_groundskeeper",
	]
	var staff_cost: int = 0
	for sid: String in staff_ids:
		staff_cost += WEEKLY_COSTS[_team.get(sid)]
	_lbl_staff.text = "−%s €/semana" % _fmt(staff_cost)

	if _team.loan_weeks_left > 0:
		_lbl_loan.text = "−%s €/semana" % _fmt(_team.loan_weekly_payment)
		_lbl_loan_info.text = "Préstamo activo: %s € pendientes · %d semanas restantes" % [
			_fmt(_team.loan_amount), _team.loan_weeks_left
		]
		_lbl_loan_info.add_theme_color_override("font_color", Color(0.95, 0.65, 0.20, 1))
	else:
		_lbl_loan.text = "0 €"
		_lbl_loan_info.text = "Sin préstamos activos."
		_lbl_loan_info.add_theme_color_override("font_color", Color(0.55, 0.60, 0.65, 1))

	# Historial
	for child in _history_list.get_children():
		child.queue_free()
	var history: Array = _team.finance_history.duplicate()
	history.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.get("week", 0) > b.get("week", 0)
	)
	_history_list.add_child(_hist_header())
	for entry: Dictionary in history:
		_history_list.add_child(_hist_row(entry))


# ---------------------------------------------------------------------------
# Diálogo préstamo

func _open_loan_dialog() -> void:
	if _team.loan_weeks_left > 0:
		return  # ya hay un préstamo activo
	if _loan_overlay != null:
		_loan_overlay.queue_free()
	_loan_overlay = _make_overlay()
	add_child(_loan_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loan_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	var pst := StyleBoxFlat.new()
	pst.bg_color = Color(0.09, 0.11, 0.17, 0.98)
	pst.set_corner_radius_all(8)
	pst.set_content_margin_all(26)
	panel.add_theme_stylebox_override("panel", pst)
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)

	var ttl := Label.new()
	ttl.text = "🏦  Solicitar Préstamo Bancario"
	ttl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ttl.add_theme_font_size_override("font_size", 20)
	ttl.add_theme_color_override("font_color", Color(0.90, 0.85, 0.50, 1))
	vb.add_child(ttl)

	var note := Label.new()
	note.text = "El banco aplica un interés del 8% anual.\nEl importe máximo es 3× la masa salarial semanal."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 14)
	note.add_theme_color_override("font_color", Color(0.60, 0.65, 0.70, 1))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(note)

	vb.add_child(HSeparator.new())

	# Importe
	var amt_row := HBoxContainer.new()
	amt_row.add_theme_constant_override("separation", 12)
	vb.add_child(amt_row)
	var amt_lbl := Label.new()
	amt_lbl.text = "Importe:"
	amt_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	amt_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	amt_lbl.add_theme_font_size_override("font_size", 16)
	amt_row.add_child(amt_lbl)
	var spin_amt := SpinBox.new()
	spin_amt.min_value = 100_000
	spin_amt.step = 50_000
	spin_amt.suffix = "€"
	spin_amt.custom_minimum_size = Vector2(200, 40)
	# Max = 3 × masa salarial semanal
	var wages: int = 0
	for pid: int in _team.player_ids:
		var p := GameManager.get_player(pid)
		if p: wages += p.salary
	spin_amt.max_value = wages * 3
	spin_amt.value = mini(1_000_000, wages * 3)
	amt_row.add_child(spin_amt)

	# Plazo
	var plz_row := HBoxContainer.new()
	plz_row.add_theme_constant_override("separation", 12)
	vb.add_child(plz_row)
	var plz_lbl := Label.new()
	plz_lbl.text = "Plazo:"
	plz_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plz_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plz_lbl.add_theme_font_size_override("font_size", 16)
	plz_row.add_child(plz_lbl)
	var opt_plz := OptionButton.new()
	opt_plz.add_item("26 semanas (6 meses)",  26)
	opt_plz.add_item("52 semanas (1 año)",    52)
	opt_plz.add_item("104 semanas (2 años)", 104)
	opt_plz.custom_minimum_size = Vector2(200, 40)
	plz_row.add_child(opt_plz)

	# Resumen calculado
	var summary_lbl := Label.new()
	summary_lbl.add_theme_font_size_override("font_size", 15)
	summary_lbl.add_theme_color_override("font_color", Color(0.90, 0.80, 0.30, 1))
	summary_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(summary_lbl)

	var _update_summary := func():
		var amount: float = spin_amt.value
		var weeks: int = opt_plz.get_selected_id()
		var annual_rate := 0.08
		var weekly_rate := annual_rate / 52.0
		var weekly_pay: float
		if weekly_rate == 0.0:
			weekly_pay = amount / weeks
		else:
			weekly_pay = amount * weekly_rate / (1.0 - pow(1.0 + weekly_rate, -weeks))
		var total_pay := weekly_pay * weeks
		var total_interest := total_pay - amount
		summary_lbl.text = "Cuota semanal: %s €  ·  Total intereses: %s €  ·  Total a devolver: %s €" % [
			_fmt(int(weekly_pay)), _fmt(int(total_interest)), _fmt(int(total_pay))
		]

	spin_amt.value_changed.connect(func(_v): _update_summary.call())
	opt_plz.item_selected.connect(func(_i): _update_summary.call())
	_update_summary.call()

	var result_lbl := Label.new()
	result_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_lbl.add_theme_font_size_override("font_size", 15)
	vb.add_child(result_lbl)

	vb.add_child(HSeparator.new())

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 20)
	vb.add_child(btn_row)

	var btn_cancel := Button.new()
	btn_cancel.text = "Cancelar"
	btn_cancel.icon = ICON_CLOSE
	btn_cancel.add_theme_constant_override("icon_max_width", ICON_SIZE_ACTION)
	btn_cancel.custom_minimum_size = Vector2(130, 44)
	btn_cancel.pressed.connect(func(): _loan_overlay.queue_free(); _loan_overlay = null)
	btn_row.add_child(btn_cancel)

	var btn_confirm := Button.new()
	btn_confirm.text = "Confirmar"
	btn_confirm.icon = ICON_CHECK
	btn_confirm.add_theme_constant_override("icon_max_width", ICON_SIZE_ACTION)
	btn_confirm.custom_minimum_size = Vector2(160, 44)
	btn_confirm.add_theme_font_size_override("font_size", 16)
	btn_confirm.add_theme_color_override("font_color", Color(0.20, 0.90, 0.50, 1))
	btn_confirm.pressed.connect(func():
		var amount: int = int(spin_amt.value)
		var weeks: int = opt_plz.get_selected_id()
		var weekly_rate := 0.08 / 52.0
		var weekly_pay: int
		if weekly_rate == 0.0:
			weekly_pay = int(amount / weeks)
		else:
			weekly_pay = int(amount * weekly_rate / (1.0 - pow(1.0 + weekly_rate, -weeks)))
		_team.club_cash          += amount
		_team.loan_amount         = amount
		_team.loan_weekly_payment = weekly_pay
		_team.loan_weeks_left     = weeks
		result_lbl.text = "✔ Préstamo de %s € concedido. Cuota semanal: %s €" % [_fmt(amount), _fmt(weekly_pay)]
		result_lbl.add_theme_color_override("font_color", Color(0.25, 0.90, 0.40, 1))
		btn_confirm.disabled = true
		_refresh()
	)
	btn_row.add_child(btn_confirm)


# ---------------------------------------------------------------------------
# Helpers de UI

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


func _section_title_with_icon(text: String, icon_tex: Texture2D) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	if icon_tex != null:
		var icon := TextureRect.new()
		icon.texture = icon_tex
		icon.custom_minimum_size = Vector2(20, 20)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 17)
	l.add_theme_color_override("font_color", Color(0.85, 0.80, 0.45, 1))
	row.add_child(l)
	return row


func _sub(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", Color(0.55, 0.60, 0.65, 1))
	return l


func _hist_header() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	for txt: String in ["Sem.", "Ingresos", "Gastos", "Saldo", ""]:
		var l := Label.new()
		l.text = txt
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color", Color(0.55, 0.60, 0.65, 1))
		row.add_child(l)
	return row


func _hist_row(entry: Dictionary) -> Control:
	var container := PanelContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.12, 0.17, 0.6)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(3)
	container.add_theme_stylebox_override("panel", sb)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	container.add_child(row)

	var lbl_week := Label.new()
	lbl_week.text = "Sem. %d" % entry.get("week", 0)
	lbl_week.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_week.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_week.add_theme_font_size_override("font_size", 13)
	row.add_child(lbl_week)

	var total_income: int = entry.get("tv_income", 0) + entry.get("league_tv", 0) + entry.get("sponsor_income", 0) \
		+ entry.get("merch_income", 0) + entry.get("matchday", 0) + entry.get("transfer_income", 0)
	var lbl_income := Label.new()
	lbl_income.text = "+%s" % _fmt(total_income) if total_income > 0 else "—"
	lbl_income.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_income.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_income.add_theme_font_size_override("font_size", 13)
	lbl_income.add_theme_color_override("font_color", Color(0.35, 0.85, 0.50, 1))
	row.add_child(lbl_income)

	var total_expenses: int = entry.get("wages", 0) + entry.get("staff_cost", 0) + entry.get("loan_payment", 0)
	var lbl_exp := Label.new()
	lbl_exp.text = "−%s" % _fmt(total_expenses)
	lbl_exp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_exp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_exp.add_theme_font_size_override("font_size", 13)
	lbl_exp.add_theme_color_override("font_color", Color(0.90, 0.40, 0.30, 1))
	row.add_child(lbl_exp)

	var bal: int = entry.get("balance", 0)
	var lbl_bal := Label.new()
	lbl_bal.text = _fmt(bal)
	lbl_bal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_bal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_bal.add_theme_font_size_override("font_size", 13)
	lbl_bal.add_theme_color_override("font_color", Color(0.25, 0.90, 0.40, 1) if bal >= 0 else Color(0.90, 0.25, 0.20, 1))
	row.add_child(lbl_bal)

	# Botón detalle
	var btn_detail := Button.new()
	btn_detail.text = ""
	btn_detail.icon = ICON_SEARCH
	btn_detail.add_theme_constant_override("icon_max_width", 18)
	btn_detail.flat = true
	btn_detail.custom_minimum_size = Vector2(32, 0)
	btn_detail.pressed.connect(func(): _show_entry_detail(entry))
	row.add_child(btn_detail)

	return container


# ---------------------------------------------------------------------------
# Popup de desglose detallado

func _show_entry_detail(entry: Dictionary) -> void:
	if _detail_overlay != null:
		_detail_overlay.queue_free()
	_detail_overlay = _make_overlay()
	add_child(_detail_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 0)
	var pst := StyleBoxFlat.new()
	pst.bg_color = Color(0.08, 0.10, 0.16, 0.98)
	pst.set_corner_radius_all(8)
	pst.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", pst)
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)

	# Título
	vb.add_child(_section_title_with_icon("Semana %d — Desglose financiero" % entry.get("week", 0), ICON_CHART))
	vb.add_child(HSeparator.new())

	# ── INGRESOS ──
	vb.add_child(_section_title_with_icon("INGRESOS", ICON_MONEY))

	var tv: int = entry.get("tv_income", 0)
	var ltv: int = entry.get("league_tv", 0)
	var sp: int = entry.get("sponsor_income", 0)
	var me: int = entry.get("merch_income", 0)
	var md: int = entry.get("matchday", 0)
	var tr: int = entry.get("transfer_income", 0)
	var total_income: int = tv + ltv + sp + me + md + tr

	var income_lines: Array = [
		["Derechos de TV (acuerdo)",   tv],
		["Derechos de liga",            ltv],
		["Patrocinador",                sp],
		["Merchandising",               me],
		["Taquilla (partido)",           md],
		["Traspaso de jugador",          tr],
	]
	for line: Array in income_lines:
		var val: int = line[1] as int
		vb.add_child(_detail_line(line[0] as String, val, true))

	vb.add_child(_detail_separator())
	vb.add_child(_detail_total("Total ingresos", total_income, true))
	vb.add_child(HSeparator.new())

	# ── GASTOS ──
	vb.add_child(_section_title_with_icon("GASTOS", ICON_EXPENSE))

	var wa: int = entry.get("wages", 0)
	var sc: int = entry.get("staff_cost", 0)
	var lp: int = entry.get("loan_payment", 0)
	var total_expenses: int = wa + sc + lp

	var expense_lines: Array = [
		["Salarios de la plantilla", wa],
		["Personal del club",         sc],
		["Cuota préstamo bancario",   lp],
	]
	for line: Array in expense_lines:
		var val: int = line[1] as int
		if val > 0:
			vb.add_child(_detail_line(line[0] as String, val, false))

	vb.add_child(_detail_separator())
	vb.add_child(_detail_total("Total gastos", total_expenses, false))
	vb.add_child(HSeparator.new())

	# ── SALDO ──
	var bal: int = entry.get("balance", 0)
	var net: int = total_income - total_expenses
	var saldo_row := HBoxContainer.new()
	var saldo_icon := TextureRect.new()
	saldo_icon.texture = ICON_MONEY
	saldo_icon.custom_minimum_size = Vector2(18, 18)
	saldo_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	saldo_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	saldo_row.add_child(saldo_icon)
	var saldo_lbl := Label.new()
	saldo_lbl.text = "Saldo al final de la semana"
	saldo_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	saldo_lbl.add_theme_font_size_override("font_size", 15)
	saldo_row.add_child(saldo_lbl)
	var saldo_val := Label.new()
	saldo_val.text = "%s €" % _fmt(bal)
	saldo_val.add_theme_font_size_override("font_size", 16)
	saldo_val.add_theme_color_override("font_color", Color(0.25, 0.90, 0.40, 1) if bal >= 0 else Color(0.90, 0.25, 0.20, 1))
	saldo_row.add_child(saldo_val)
	vb.add_child(saldo_row)

	var net_row := HBoxContainer.new()
	var net_lbl := Label.new()
	net_lbl.text = "Balance neto de la semana"
	net_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	net_lbl.add_theme_font_size_override("font_size", 13)
	net_lbl.add_theme_color_override("font_color", Color(0.55, 0.60, 0.65, 1))
	net_row.add_child(net_lbl)
	var net_val := Label.new()
	net_val.text = ("+%s" if net >= 0 else "%s") % _fmt(net) + " €"
	net_val.add_theme_font_size_override("font_size", 13)
	net_val.add_theme_color_override("font_color", Color(0.35, 0.85, 0.50, 1) if net >= 0 else Color(0.90, 0.40, 0.30, 1))
	net_row.add_child(net_val)
	vb.add_child(net_row)

	vb.add_child(HSeparator.new())

	var btn_close := Button.new()
	btn_close.text = "Cerrar"
	btn_close.custom_minimum_size = Vector2(120, 44)
	btn_close.pressed.connect(func(): _detail_overlay.queue_free(); _detail_overlay = null)
	var btn_wrap := CenterContainer.new()
	btn_wrap.add_child(btn_close)
	vb.add_child(btn_wrap)


# Detail helpers

func _detail_line(label: String, amount: int, is_income: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = "    " + label
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 14)
	row.add_child(lbl)
	var val := Label.new()
	val.text = ("+%s" if is_income else "−%s") % _fmt(amount) + " €"
	val.add_theme_font_size_override("font_size", 14)
	val.add_theme_color_override("font_color",
		Color(0.35, 0.85, 0.50, 1) if is_income else Color(0.90, 0.40, 0.30, 1))
	row.add_child(val)
	return row


func _detail_total(label: String, amount: int, is_income: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = label
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color",
		Color(0.35, 0.85, 0.50, 1) if is_income else Color(0.90, 0.40, 0.30, 1))
	row.add_child(lbl)
	var val := Label.new()
	val.text = ("+%s" if is_income else "−%s") % _fmt(amount) + " €"
	val.add_theme_font_size_override("font_size", 15)
	val.add_theme_color_override("font_color",
		Color(0.35, 0.85, 0.50, 1) if is_income else Color(0.90, 0.40, 0.30, 1))
	row.add_child(val)
	return row


func _detail_separator() -> HSeparator:
	var sep := HSeparator.new()
	return sep


func _fmt(n: int) -> String:
	var neg := n < 0
	var s := str(absi(n))
	var result := ""
	var count := 0
	for i: int in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "." + result
		result = s[i] + result
		count += 1
	return ("-" if neg else "") + result
