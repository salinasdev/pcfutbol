extends Control

const ICON_BACK := preload("res://assets/ui/icons/back-white.png")
const ICON_CHECK := preload("res://assets/ui/icons/checkmark-white.png")
const ICON_CLOSE := preload("res://assets/ui/icons/close-white.png")
const ICON_MONEY := preload("res://assets/ui/icons/dollar.png")
const ICON_SIZE_NAV := 28
const ICON_SIZE_ACTION := 20

const POS_COLORS := {
	Player.Position.GK:  Color(0.55, 0.40, 0.02, 1),
	Player.Position.DEF: Color(0.05, 0.40, 0.15, 1),
	Player.Position.MID: Color(0.15, 0.20, 0.72, 1),
	Player.Position.FWD: Color(0.70, 0.15, 0.10, 1),
}

var _team: Team = null
var _overlay: Control = null
var _renewal_round: int = 0
var _renewal_frustration: int = 0  # aumenta cada vez que el jugador rechaza o contraoferta mal pagado

## Touch-scroll manual
const _SCROLL_THRESHOLD := 10.0
var _touch_start_y: float = 0.0
var _touch_start_scroll: int = 0
var _is_touch_scrolling: bool = false


func _input(event: InputEvent) -> void:
	var scroll := $VBoxContainer/ScrollContainer as ScrollContainer
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_start_y = event.position.y
			_touch_start_scroll = scroll.scroll_vertical
			_is_touch_scrolling = false
		elif _is_touch_scrolling:
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var delta: float = event.position.y - _touch_start_y
		if abs(delta) > _SCROLL_THRESHOLD or _is_touch_scrolling:
			_is_touch_scrolling = true
			scroll.scroll_vertical = _touch_start_scroll - int(delta)
			get_viewport().set_input_as_handled()


func _ready() -> void:
	_team = GameManager.get_player_team()
	%BtnBack.icon = ICON_BACK
	%BtnBack.add_theme_constant_override("icon_max_width", ICON_SIZE_NAV)
	%BtnBack.text = ""
	%BtnBack.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/game/office/office.tscn"))
	TransferManager.acknowledge_incoming_offers()
	_build_list()


func _build_list() -> void:
	if _team == null:
		return

	%TitleLabel.text = _team.name + " — Plantilla"
	%CountLabel.text = "%d jugadores" % _team.player_ids.size()

	var list: VBoxContainer = %PlayerList
	for child in list.get_children():
		child.queue_free()

	# —— OFERTAS ENTRANTES PENDIENTES ——
	var pending: Array[Dictionary] = []
	for o: Dictionary in TransferManager.incoming_offers:
		if o["status"] == "pending":
			pending.append(o)

	if not pending.is_empty():
		list.add_child(_make_section_header(
			"📨  OFERTAS ENTRANTES (%d)" % pending.size(),
			Color(0.22, 0.12, 0.05, 1), Color(1.0, 0.75, 0.30, 1)))
		for o: Dictionary in pending:
			list.add_child(_make_incoming_offer_row(o))
		list.add_child(HSeparator.new())

	# —— JUGADORES: cabecera ——
	list.add_child(_make_plantilla_header())

	# Ordenar por posición
	var pids: Array[int] = _team.player_ids.duplicate()
	pids.sort_custom(func(a: int, b: int) -> bool:
		var pa: Player = GameManager.get_player(a)
		var pb: Player = GameManager.get_player(b)
		if pa == null or pb == null: return false
		return int(pa.position) < int(pb.position)
	)

	for pid: int in pids:
		var p: Player = GameManager.get_player(pid)
		if p:
			list.add_child(_make_plantilla_row(p))


func _make_section_header(text: String, bg: Color, fg: Color) -> Control:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", fg)
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_content_margin_all(6)
	lbl.add_theme_stylebox_override("normal", sb)
	return lbl


func _make_plantilla_header() -> Control:
	var root := Control.new()
	root.custom_minimum_size = Vector2(0, 28)
	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.10, 0.18, 1)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 0)
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hbox)
	var cols: Array = [
		["POS", 44, true], ["NOMBRE", -1, false], ["EDAD", 44, true],
		["OVR", 44, true], ["VALOR", 90, true], ["SUELDO/SEM", 90, true],
		["CONT.", 72, true], ["CLÁUSULA", 90, true], ["VENTA", 60, true]
	]
	for i in range(cols.size()):
		if i > 0: hbox.add_child(_vsep(Color(0.35, 0.35, 0.60, 1)))
		var c: Array = cols[i]
		var lbl := Label.new()
		if c[1] > 0: lbl.custom_minimum_size = Vector2(c[1], 0)
		else:        lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.text = c[0]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if c[2] else HORIZONTAL_ALIGNMENT_LEFT
		lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.95, 1))
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(lbl)
	return root


func _make_plantilla_row(p: Player) -> Control:
	var contract_critical: bool = p.contract_years <= 1
	var contract_warn: bool     = p.contract_years <= 2
	var bg_color: Color
	if p.transfer_listed:
		bg_color = Color(0.22, 0.10, 0.05, 1)
	elif contract_critical:
		bg_color = Color(0.22, 0.05, 0.05, 1)
	elif contract_warn:
		bg_color = Color(0.20, 0.14, 0.04, 1)
	else:
		bg_color = Color(0.09, 0.11, 0.17, 1)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 58)
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(4)
	panel.add_theme_stylebox_override("panel", sb)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 0)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(hbox)

	var sep_c := Color(0.20, 0.20, 0.32, 0.6)

	# POS
	var lbl_pos := Label.new()
	lbl_pos.custom_minimum_size = Vector2(44, 0)
	lbl_pos.text = p.get_position_abbr()
	lbl_pos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_pos.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl_pos.add_theme_font_size_override("font_size", 13)
	lbl_pos.add_theme_color_override("font_color", POS_COLORS.get(p.position, Color.WHITE))
	hbox.add_child(lbl_pos)
	hbox.add_child(_vsep(sep_c))

	# NOMBRE
	var lbl_name := Label.new()
	lbl_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_name.text = p.full_name
	lbl_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_name.add_theme_font_size_override("font_size", 15)
	lbl_name.add_theme_color_override("font_color",
		Color(1.0, 0.35, 0.25, 1) if contract_critical else
		Color(1.0, 0.70, 0.20, 1) if contract_warn else
		Color(0.88, 0.90, 0.95, 1))
	hbox.add_child(lbl_name)
	hbox.add_child(_vsep(sep_c))

	# EDAD
	var lbl_age := Label.new()
	lbl_age.custom_minimum_size = Vector2(44, 0)
	lbl_age.text = str(p.age)
	lbl_age.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_age.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl_age.add_theme_font_size_override("font_size", 14)
	lbl_age.add_theme_color_override("font_color", Color(0.65, 0.70, 0.75, 1))
	hbox.add_child(lbl_age)
	hbox.add_child(_vsep(sep_c))

	# OVR
	hbox.add_child(_stat_lbl(p.get_overall(), 44))
	hbox.add_child(_vsep(sep_c))

	# VALOR
	var lbl_val := Label.new()
	lbl_val.custom_minimum_size = Vector2(90, 0)
	lbl_val.text = _fmt_money(p.market_value)
	lbl_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_val.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl_val.add_theme_font_size_override("font_size", 13)
	lbl_val.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0, 1))
	hbox.add_child(lbl_val)
	hbox.add_child(_vsep(sep_c))

	# SUELDO
	var lbl_sal := Label.new()
	lbl_sal.custom_minimum_size = Vector2(90, 0)
	lbl_sal.text = _fmt_money(p.salary)
	lbl_sal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_sal.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl_sal.add_theme_font_size_override("font_size", 13)
	lbl_sal.add_theme_color_override("font_color", Color(0.95, 0.50, 0.40, 1))
	hbox.add_child(lbl_sal)
	hbox.add_child(_vsep(sep_c))

	# CONTRATO
	var cont_vbox := VBoxContainer.new()
	cont_vbox.custom_minimum_size = Vector2(72, 0)
	cont_vbox.add_theme_constant_override("separation", 2)
	var lbl_cont := Label.new()
	lbl_cont.text = "%d año%s" % [p.contract_years, "s" if p.contract_years != 1 else ""]
	lbl_cont.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_cont.add_theme_font_size_override("font_size", 12)
	var cont_col: Color
	if contract_critical:   cont_col = Color(1.0, 0.30, 0.25, 1)
	elif contract_warn:     cont_col = Color(1.0, 0.65, 0.20, 1)
	else:                   cont_col = Color(0.65, 0.80, 0.65, 1)
	lbl_cont.add_theme_color_override("font_color", cont_col)
	cont_vbox.add_child(lbl_cont)
	if p.contract_years <= 3:
		var btn_ren := Button.new()
		btn_ren.text = "Renovar"
		btn_ren.add_theme_font_size_override("font_size", 11)
		var ren_col: Color
		if contract_critical:   ren_col = Color(1.0, 0.40, 0.30, 1)
		elif contract_warn:     ren_col = Color(1.0, 0.75, 0.25, 1)
		else:                   ren_col = Color(0.50, 0.80, 0.55, 1)
		btn_ren.add_theme_color_override("font_color", ren_col)
		btn_ren.pressed.connect(_open_renewal_dialog.bind(p))
		cont_vbox.add_child(btn_ren)
	hbox.add_child(cont_vbox)
	hbox.add_child(_vsep(sep_c))

	# CLÁUSULA DE RESCISIÓN
	var clause_vbox := VBoxContainer.new()
	clause_vbox.custom_minimum_size = Vector2(90, 0)
	clause_vbox.add_theme_constant_override("separation", 2)
	var lbl_clause := Label.new()
	lbl_clause.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_clause.add_theme_font_size_override("font_size", 12)
	if p.release_clause > 0:
		lbl_clause.text = _fmt_money(p.release_clause)
		lbl_clause.add_theme_color_override("font_color", Color(0.55, 0.70, 1.0, 1))
	else:
		lbl_clause.text = "Sin cláusula"
		lbl_clause.add_theme_color_override("font_color", Color(0.45, 0.48, 0.55, 1))
	clause_vbox.add_child(lbl_clause)
	var btn_clause := Button.new()
	btn_clause.text = "🔒 Fijar"
	btn_clause.add_theme_font_size_override("font_size", 11)
	btn_clause.add_theme_color_override("font_color", Color(0.70, 0.80, 1.0, 1))
	btn_clause.pressed.connect(_open_clause_dialog.bind(p))
	clause_vbox.add_child(btn_clause)
	hbox.add_child(clause_vbox)
	hbox.add_child(_vsep(sep_c))

	# VENTA toggle
	var btn_sell := Button.new()
	btn_sell.custom_minimum_size = Vector2(60, 0)
	btn_sell.text = "En venta" if p.transfer_listed else "Vender"
	btn_sell.add_theme_font_size_override("font_size", 12)
	if p.transfer_listed:
		btn_sell.add_theme_color_override("font_color", Color(1.0, 0.45, 0.20, 1))
	else:
		btn_sell.add_theme_color_override("font_color", Color(0.60, 0.65, 0.70, 1))
	btn_sell.pressed.connect(func():
		if p.transfer_listed:
			TransferManager.delist_player(p)
		else:
			TransferManager.list_player(p)
		_build_list()
	)
	hbox.add_child(btn_sell)

	return panel


func _make_incoming_offer_row(offer: Dictionary) -> Control:
	var p: Player = GameManager.get_player(offer["player_id"])
	var buyer: Team = GameManager.get_team(offer["buyer_id"])
	if p == null or buyer == null:
		return Control.new()

	var is_clause: bool = offer.get("is_clause", false)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 74)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.24, 0.08, 0.04, 1) if is_clause else Color(0.18, 0.12, 0.04, 1)
	sb.set_corner_radius_all(4)
	sb.border_width_left = 4
	sb.border_color = Color(0.95, 0.20, 0.20, 1) if is_clause else Color(1.0, 0.75, 0.30, 1)
	sb.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", sb)

	var outer_hbox := HBoxContainer.new()
	outer_hbox.add_theme_constant_override("separation", 8)
	panel.add_child(outer_hbox)

	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 3)
	outer_hbox.add_child(info_vbox)

	# Línea 1: badge (si cláusula) + nombre
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	info_vbox.add_child(name_row)
	if is_clause:
		var badge := Label.new()
		badge.text = "⚠ CLÁUSULA"
		badge.add_theme_font_size_override("font_size", 11)
		badge.add_theme_color_override("font_color", Color(1.0, 0.30, 0.25, 1))
		name_row.add_child(badge)
	var lbl_player := Label.new()
	lbl_player.text = "%s  [%s]" % [p.full_name, p.get_position_abbr()]
	lbl_player.add_theme_font_size_override("font_size", 15)
	lbl_player.add_theme_color_override("font_color",
		Color(1.0, 0.75, 0.65, 1) if is_clause else Color(0.95, 0.90, 0.70, 1))
	name_row.add_child(lbl_player)

	# Línea 2: descripción de la oferta
	var val: int = TransferManager.calculate_value(p)
	var ratio_pct: int = int(float(offer["offer_money"]) / float(maxi(val, 1)) * 100.0)
	var player_wants_to_go: bool = offer.get("player_wants_to_go", false)
	var lbl_detail := Label.new()
	lbl_detail.add_theme_font_size_override("font_size", 13)
	if is_clause:
		lbl_detail.text = "%s activa la cláusula de rescisión: %s" % [buyer.name, _fmt_money(offer["offer_money"])]
		lbl_detail.add_theme_color_override("font_color", Color(1.0, 0.65, 0.55, 1))
	else:
		lbl_detail.text = "%s ofrece %s (%d%% del valor de mercado)" % [buyer.name, _fmt_money(offer["offer_money"]), ratio_pct]
		lbl_detail.add_theme_color_override("font_color",
			Color(0.35, 0.90, 0.45, 1) if ratio_pct >= 90 else Color(0.90, 0.65, 0.25, 1))
	info_vbox.add_child(lbl_detail)

	# Línea 3: nota (estado del jugador)
	var lbl_note := Label.new()
	lbl_note.add_theme_font_size_override("font_size", 12)
	if is_clause:
		lbl_note.text = "Valor de mercado: %s  —  La cláusula es legalmente vinculante." % _fmt_money(val)
		lbl_note.add_theme_color_override("font_color", Color(0.80, 0.55, 0.50, 1))
	elif player_wants_to_go:
		lbl_note.text = "⚠ El jugador está considerando seriamente la oferta. Puedes intentar convencerle."
		lbl_note.add_theme_color_override("font_color", Color(1.0, 0.70, 0.25, 1))
	else:
		lbl_note.text = "El jugador no quiere marcharse. Puedes rechazar la oferta sin problema."
		lbl_note.add_theme_color_override("font_color", Color(0.40, 0.80, 0.50, 1))
	info_vbox.add_child(lbl_note)

	# Botones
	var btn_vbox := VBoxContainer.new()
	btn_vbox.add_theme_constant_override("separation", 4)
	outer_hbox.add_child(btn_vbox)

	var btn_accept := Button.new()
	btn_accept.text = "⚠ Confirmar venta" if is_clause else "✔ Aceptar"
	if not is_clause:
		btn_accept.icon = ICON_CHECK
		btn_accept.add_theme_constant_override("icon_max_width", ICON_SIZE_ACTION)
	btn_accept.custom_minimum_size = Vector2(130, 0)
	btn_accept.add_theme_font_size_override("font_size", 13)
	btn_accept.add_theme_color_override("font_color",
		Color(1.0, 0.55, 0.25, 1) if is_clause else Color(0.20, 0.90, 0.45, 1))
	btn_accept.pressed.connect(func():
		TransferManager.accept_incoming_offer(offer["id"])
		SaveManager.save_game()
		_team = GameManager.get_player_team()
		_build_list()
	)
	btn_vbox.add_child(btn_accept)

	if is_clause:
		# Opción de intentar retener al jugador negociando su contrato
		var btn_retain := Button.new()
		btn_retain.text = "🤝 Retener"
		btn_retain.custom_minimum_size = Vector2(130, 0)
		btn_retain.add_theme_font_size_override("font_size", 13)
		btn_retain.add_theme_color_override("font_color", Color(0.35, 0.82, 0.98, 1))
		btn_retain.pressed.connect(func(): _open_retention_dialog(p, offer))
		btn_vbox.add_child(btn_retain)
	else:
		var btn_reject := Button.new()
		btn_reject.text = "Rechazar"
		btn_reject.icon = ICON_CLOSE
		btn_reject.add_theme_constant_override("icon_max_width", ICON_SIZE_ACTION)
		btn_reject.custom_minimum_size = Vector2(130, 0)
		btn_reject.add_theme_font_size_override("font_size", 13)
		btn_reject.add_theme_color_override("font_color", Color(0.90, 0.30, 0.25, 1))
		btn_reject.pressed.connect(func():
			TransferManager.reject_incoming_offer(offer["id"])
			_build_list()
		)
		btn_vbox.add_child(btn_reject)

		# Si el jugador quiere irse, ofrece la opción de convencerle
		if player_wants_to_go:
			var btn_convince := Button.new()
			btn_convince.text = "💬 Convencer"
			btn_convince.custom_minimum_size = Vector2(130, 0)
			btn_convince.add_theme_font_size_override("font_size", 13)
			btn_convince.add_theme_color_override("font_color", Color(0.35, 0.82, 0.98, 1))
			btn_convince.pressed.connect(func(): _open_persuasion_dialog(p, offer))
			btn_vbox.add_child(btn_convince)

	return panel


# Diálogo para fijar/modificar la cláusula de rescisión
func _open_clause_dialog(p: Player) -> void:
	if _overlay != null:
		_overlay.queue_free()
	_overlay = _make_dim_overlay()
	add_child(_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 0)
	var pst := StyleBoxFlat.new()
	pst.bg_color = Color(0.08, 0.10, 0.18, 0.98)
	pst.set_corner_radius_all(8)
	pst.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", pst)
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)

	var ttl := Label.new()
	ttl.text = "🔒  Cláusula de rescisión — " + p.full_name
	ttl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ttl.add_theme_font_size_override("font_size", 17)
	ttl.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0, 1))
	vb.add_child(ttl)

	var val: int = TransferManager.calculate_value(p)
	var info := Label.new()
	info.text = "Valor de mercado: " + _fmt_money(val) + "  ·  Cláusula actual: " + \
		(_fmt_money(p.release_clause) if p.release_clause > 0 else "Sin cláusula")
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 13)
	info.add_theme_color_override("font_color", Color(0.60, 0.65, 0.72, 1))
	vb.add_child(info)

	var note := Label.new()
	note.text = "Una cláusula alta disuade a los equipos: por encima de 2× el valor de mercado raro que hagan oferta."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 12)
	note.add_theme_color_override("font_color", Color(0.60, 0.65, 0.70, 1))
	vb.add_child(note)

	vb.add_child(HSeparator.new())

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	vb.add_child(row)
	var lbl_r := Label.new(); lbl_r.text = "Nueva cláusula:"
	lbl_r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_r.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_r.add_theme_font_size_override("font_size", 15)
	row.add_child(lbl_r)

	var spin := SpinBox.new()
	spin.min_value = 0
	spin.max_value = val * 10
	spin.step = 100_000
	spin.suffix = "€"
	spin.value = p.release_clause if p.release_clause > 0 else val * 2
	spin.custom_minimum_size = Vector2(180, 40)
	row.add_child(spin)

	# Atajos de valor predefinido
	var shortcuts_row := HBoxContainer.new()
	shortcuts_row.add_theme_constant_override("separation", 8)
	shortcuts_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(shortcuts_row)
	var _mult_labels := ["1.5x", "2x", "3x", "5x"]
	var _mult_values := [1.5, 2.0, 3.0, 5.0]
	for i in _mult_labels.size():
		var btn_s := Button.new()
		btn_s.text = _mult_labels[i]
		btn_s.custom_minimum_size = Vector2(60, 36)
		btn_s.add_theme_font_size_override("font_size", 13)
		var target_val: int = int(val * _mult_values[i] / 100_000.0) * 100_000
		btn_s.pressed.connect(func(): spin.value = target_val)
		shortcuts_row.add_child(btn_s)

	var btn_clear := Button.new()
	btn_clear.text = "Sin cláusula"
	btn_clear.custom_minimum_size = Vector2(110, 36)
	btn_clear.add_theme_font_size_override("font_size", 12)
	btn_clear.add_theme_color_override("font_color", Color(0.70, 0.45, 0.40, 1))
	btn_clear.pressed.connect(func(): spin.value = 0)
	shortcuts_row.add_child(btn_clear)

	vb.add_child(HSeparator.new())

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	vb.add_child(btn_row)

	var btn_cancel := Button.new()
	btn_cancel.text = "Cancelar"
	btn_cancel.icon = ICON_CLOSE
	btn_cancel.add_theme_constant_override("icon_max_width", ICON_SIZE_ACTION)
	btn_cancel.custom_minimum_size = Vector2(110, 44)
	btn_cancel.pressed.connect(func(): _overlay.queue_free(); _overlay = null)
	btn_row.add_child(btn_cancel)

	var btn_confirm := Button.new()
	btn_confirm.text = "Guardar"
	btn_confirm.icon = ICON_CHECK
	btn_confirm.add_theme_constant_override("icon_max_width", ICON_SIZE_ACTION)
	btn_confirm.custom_minimum_size = Vector2(130, 44)
	btn_confirm.add_theme_font_size_override("font_size", 15)
	btn_confirm.add_theme_color_override("font_color", Color(0.35, 0.85, 0.98, 1))
	btn_confirm.pressed.connect(func():
		p.release_clause = int(spin.value)
		SaveManager.save_game()
		_overlay.queue_free()
		_overlay = null
		_build_list()
	)
	btn_row.add_child(btn_confirm)


func _open_persuasion_dialog(p: Player, offer: Dictionary) -> void:
	_renewal_round = 0
	_renewal_frustration = 0
	if _overlay != null:
		_overlay.queue_free()
	_overlay = _make_dim_overlay()
	add_child(_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(540, 0)
	var pst := StyleBoxFlat.new()
	pst.bg_color = Color(0.08, 0.12, 0.16, 0.98)
	pst.set_corner_radius_all(8)
	pst.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", pst)
	center.add_child(panel)

	var outer_vb := VBoxContainer.new()
	outer_vb.add_theme_constant_override("separation", 12)
	panel.add_child(outer_vb)

	_build_renewal_header(outer_vb, p,
		"El jugador está tentado por la oferta. Intenta convencerle de que se quede.")

	var content_vb := VBoxContainer.new()
	content_vb.add_theme_constant_override("separation", 12)
	outer_vb.add_child(content_vb)
	_persuasion_phase(content_vb, p, offer)


func _persuasion_phase(box: VBoxContainer, p: Player, offer: Dictionary) -> void:
	for c in box.get_children(): c.queue_free()

	# Mostrar estado actual del jugador
	var reason_text: String
	if p.morale < 40:
		reason_text = "La moral de %s está muy baja. Busca una salida para recuperar la motivación." % p.full_name
	elif p.morale < 60:
		reason_text = "%s no está del todo a gusto en el club y valora el cambio de aires." % p.full_name
	elif p.contract_years <= 1:
		reason_text = "El contrato de %s expira pronto y la oferta le parece una buena oportunidad." % p.full_name
	else:
		reason_text = "%s está considerando la oferta del %s." % [p.full_name,
			(GameManager.get_team(offer["buyer_id"]).name if GameManager.get_team(offer["buyer_id"]) else "club rival")]

	var lbl_reason := Label.new()
	lbl_reason.text = reason_text
	lbl_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_reason.add_theme_font_size_override("font_size", 14)
	lbl_reason.add_theme_color_override("font_color", Color(0.90, 0.78, 0.50, 1))
	box.add_child(lbl_reason)

	# Probabilidad de éxito de una charla motivacional
	var talk_success_pct: int = clampi(int(float(p.morale) * 0.70 + 15.0), 15, 80)
	var lbl_talk_info := Label.new()
	lbl_talk_info.text = "Charla del entrenador — probabilidad de éxito: %d%%" % talk_success_pct
	lbl_talk_info.add_theme_font_size_override("font_size", 13)
	lbl_talk_info.add_theme_color_override("font_color", Color(0.60, 0.70, 0.80, 1))
	box.add_child(lbl_talk_info)

	box.add_child(HSeparator.new())

	# Sección: mejora salarial
	var lbl_sal_title := Label.new()
	lbl_sal_title.text = "Alternativamente, propón una mejora salarial:"
	lbl_sal_title.add_theme_font_size_override("font_size", 14)
	lbl_sal_title.add_theme_color_override("font_color", Color(0.75, 0.80, 0.90, 1))
	box.add_child(lbl_sal_title)

	var row_sal := HBoxContainer.new()
	row_sal.add_theme_constant_override("separation", 12)
	box.add_child(row_sal)
	var lbl_s := Label.new(); lbl_s.text = "Nuevo sueldo semanal:"
	lbl_s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_s.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_s.add_theme_font_size_override("font_size", 15)
	row_sal.add_child(lbl_s)
	var spin_sal := SpinBox.new()
	spin_sal.min_value = p.salary
	spin_sal.max_value = p.salary * 6
	spin_sal.step = 500
	spin_sal.suffix = "€"
	spin_sal.value = int(p.salary * 1.15 / 500) * 500
	spin_sal.custom_minimum_size = Vector2(160, 40)
	row_sal.add_child(spin_sal)

	box.add_child(HSeparator.new())

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	box.add_child(btn_row)

	var btn_close := Button.new()
	btn_close.text = "Cancelar"
	btn_close.icon = ICON_CLOSE
	btn_close.add_theme_constant_override("icon_max_width", ICON_SIZE_ACTION)
	btn_close.custom_minimum_size = Vector2(100, 44)
	btn_close.pressed.connect(func(): _overlay.queue_free(); _overlay = null)
	btn_row.add_child(btn_close)

	var btn_talk := Button.new()
	btn_talk.text = "🗣 Charla motivacional"
	btn_talk.custom_minimum_size = Vector2(190, 44)
	btn_talk.add_theme_font_size_override("font_size", 14)
	btn_talk.add_theme_color_override("font_color", Color(0.80, 0.90, 0.50, 1))
	btn_talk.pressed.connect(func():
		var success: bool = randf() < (float(talk_success_pct) / 100.0)
		_persuasion_result(box, p, offer, success, false, 0)
	)
	btn_row.add_child(btn_talk)

	var btn_raise := Button.new()
	btn_raise.text = "Mejorar contrato"
	btn_raise.icon = ICON_MONEY
	btn_raise.add_theme_constant_override("icon_max_width", ICON_SIZE_ACTION)
	btn_raise.custom_minimum_size = Vector2(175, 44)
	btn_raise.add_theme_font_size_override("font_size", 14)
	btn_raise.add_theme_color_override("font_color", Color(0.35, 0.82, 0.98, 1))
	btn_raise.pressed.connect(func():
		var new_sal := int(spin_sal.value)
		_persuasion_result(box, p, offer, true, true, new_sal)
	)
	btn_row.add_child(btn_raise)


func _persuasion_result(box: VBoxContainer, p: Player, offer: Dictionary,
		success: bool, is_raise: bool, new_salary: int) -> void:
	for c in box.get_children(): c.queue_free()

	var banner := PanelContainer.new()
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0.05, 0.22, 0.08, 1) if success else Color(0.24, 0.05, 0.05, 1)
	bsb.set_corner_radius_all(6)
	bsb.set_content_margin_all(14)
	banner.add_theme_stylebox_override("panel", bsb)
	box.add_child(banner)

	var bvb := VBoxContainer.new()
	bvb.add_theme_constant_override("separation", 6)
	banner.add_child(bvb)

	var lbl_main := Label.new()
	lbl_main.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_main.add_theme_font_size_override("font_size", 15)
	lbl_main.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bvb.add_child(lbl_main)

	var lbl_sub := Label.new()
	lbl_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_sub.add_theme_font_size_override("font_size", 13)
	lbl_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bvb.add_child(lbl_sub)

	if success:
		lbl_main.text = "✔  %s ha decidido quedarse en el club." % p.full_name
		lbl_main.add_theme_color_override("font_color", Color(0.30, 0.95, 0.50, 1))
		if is_raise:
			lbl_sub.text = "Firma el nuevo contrato a %s/sem. La oferta del club rival queda rechazada." % _fmt_money(new_salary)
		else:
			lbl_sub.text = "La charla ha surtido efecto. La moral del jugador mejora y rechaza la oferta."
		lbl_sub.add_theme_color_override("font_color", Color(0.65, 0.88, 0.65, 1))
	else:
		lbl_main.text = "✗  La charla no ha convencido a %s." % p.full_name
		lbl_main.add_theme_color_override("font_color", Color(1.0, 0.35, 0.30, 1))
		lbl_sub.text = "El jugador sigue considerando la oferta. Intenta mejorar su sueldo o acepta su salida."
		lbl_sub.add_theme_color_override("font_color", Color(0.80, 0.55, 0.55, 1))

	box.add_child(HSeparator.new())

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 14)
	box.add_child(btn_row)

	var btn_close := Button.new()
	btn_close.text = "Cerrar"
	btn_close.icon = ICON_CLOSE
	btn_close.add_theme_constant_override("icon_max_width", ICON_SIZE_ACTION)
	btn_close.custom_minimum_size = Vector2(100, 44)
	btn_close.pressed.connect(func(): _overlay.queue_free(); _overlay = null; _build_list())
	btn_row.add_child(btn_close)

	if success:
		var btn_confirm := Button.new()
		btn_confirm.text = "Confirmar y retener"
		btn_confirm.icon = ICON_CHECK
		btn_confirm.add_theme_constant_override("icon_max_width", ICON_SIZE_ACTION)
		btn_confirm.custom_minimum_size = Vector2(185, 44)
		btn_confirm.add_theme_font_size_override("font_size", 15)
		btn_confirm.add_theme_color_override("font_color", Color(0.20, 0.90, 0.50, 1))
		btn_confirm.pressed.connect(func():
			TransferManager.reject_incoming_offer(offer["id"])
			p.morale = clampi(p.morale + 15, 0, 100)
			if is_raise:
				var signing_fee: int = maxi(0, (new_salary - p.salary) * 26)
				if _team.club_cash >= signing_fee:
					_team.club_cash -= signing_fee
					p.salary = new_salary
					p.market_value = TransferManager.calculate_value(p)
				else:
					var dlg := AcceptDialog.new()
					dlg.dialog_text = "Sin fondos para la prima de firma (%s).\nReduce el sueldo ofrecido." % _fmt_money(signing_fee)
					add_child(dlg)
					dlg.popup_centered()
					return
			SaveManager.save_game()
			_overlay.queue_free()
			_overlay = null
			_build_list()
		)
		btn_row.add_child(btn_confirm)
	else:
		# Permitir reintentar con mejora salarial
		var btn_retry := Button.new()
		btn_retry.text = "Ofrecer subida de sueldo"
		btn_retry.custom_minimum_size = Vector2(185, 44)
		btn_retry.add_theme_font_size_override("font_size", 14)
		btn_retry.add_theme_color_override("font_color", Color(0.35, 0.82, 0.98, 1))
		btn_retry.pressed.connect(func():
			p.morale = clampi(p.morale - 5, 0, 100)
			_persuasion_phase(box, p, offer)
		)
		btn_row.add_child(btn_retry)


func _open_renewal_dialog(p: Player) -> void:
	_renewal_round = 0
	_renewal_frustration = 0
	if _overlay != null:
		_overlay.queue_free()
	_overlay = _make_dim_overlay()
	add_child(_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	var pst := StyleBoxFlat.new()
	pst.bg_color = Color(0.08, 0.10, 0.16, 0.98)
	pst.set_corner_radius_all(8)
	pst.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", pst)
	center.add_child(panel)

	var outer_vb := VBoxContainer.new()
	outer_vb.add_theme_constant_override("separation", 12)
	panel.add_child(outer_vb)

	_build_renewal_header(outer_vb, p, "")

	var content_vb := VBoxContainer.new()
	content_vb.add_theme_constant_override("separation", 12)
	outer_vb.add_child(content_vb)
	_renewal_proposal_phase(content_vb, p)


# Retención ante cláusula: el jugador debe querer quedarse
func _open_retention_dialog(p: Player, offer: Dictionary) -> void:
	_renewal_round = 0
	_renewal_frustration = 0
	if _overlay != null:
		_overlay.queue_free()
	_overlay = _make_dim_overlay()
	add_child(_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(540, 0)
	var pst := StyleBoxFlat.new()
	pst.bg_color = Color(0.09, 0.08, 0.18, 0.98)
	pst.set_corner_radius_all(8)
	pst.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", pst)
	center.add_child(panel)

	var outer_vb := VBoxContainer.new()
	outer_vb.add_theme_constant_override("separation", 12)
	panel.add_child(outer_vb)

	_build_renewal_header(outer_vb, p,
		"⚠  %s quiere irse. Ofrécele mejores condiciones para que se quede." % p.full_name)

	var content_vb := VBoxContainer.new()
	content_vb.add_theme_constant_override("separation", 12)
	outer_vb.add_child(content_vb)
	_retention_proposal_phase(content_vb, p, offer)


func _build_renewal_header(vb: VBoxContainer, p: Player, subtitle: String) -> void:
	var ttl := Label.new()
	ttl.text = "🤝  Negociación — %s" % p.full_name
	ttl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ttl.add_theme_font_size_override("font_size", 18)
	ttl.add_theme_color_override("font_color", Color(0.90, 0.85, 0.50, 1))
	vb.add_child(ttl)
	if subtitle != "":
		var sub := Label.new()
		sub.text = subtitle
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub.add_theme_font_size_override("font_size", 13)
		sub.add_theme_color_override("font_color", Color(1.0, 0.65, 0.40, 1))
		vb.add_child(sub)
	var info := Label.new()
	info.text = "Contrato: %d año%s  ·  Sueldo: %s/sem  ·  Valor: %s" % [
		p.contract_years, "s" if p.contract_years != 1 else "",
		_fmt_money(p.salary), _fmt_money(p.market_value)
	]
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 13)
	info.add_theme_color_override("font_color", Color(0.65, 0.70, 0.75, 1))
	vb.add_child(info)
	vb.add_child(HSeparator.new())


# Fase de propuesta para RETENCIÓN (cláusula activada)
# El jugador exige más que en una renovación normal porque ya tiene oferta en firme
func _retention_proposal_phase(box: VBoxContainer, p: Player, offer: Dictionary) -> void:
	for c in box.get_children(): c.queue_free()

	# Estimación de lo que pide el jugador para quedarse (más exigente que renovación normal)
	var ovr: int = p.get_overall()
	var min_raise: float = 0.20 + clampf((ovr - 50) * 0.010, 0.0, 0.50)
	var hint_salary: int = int(p.salary * (1.0 + min_raise) / 500.0) * 500

	var lbl_hint := Label.new()
	lbl_hint.text = "El jugador esperará como mínimo ~%s/sem para rechazar la oferta de %s." % [
		_fmt_money(hint_salary), _fmt_money(offer["offer_money"])]
	lbl_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_hint.add_theme_font_size_override("font_size", 13)
	lbl_hint.add_theme_color_override("font_color", Color(0.90, 0.78, 0.45, 1))
	box.add_child(lbl_hint)

	var row_years := HBoxContainer.new()
	row_years.add_theme_constant_override("separation", 12)
	box.add_child(row_years)
	var lbl_y := Label.new(); lbl_y.text = "Años de contrato:"
	lbl_y.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_y.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_y.add_theme_font_size_override("font_size", 15)
	row_years.add_child(lbl_y)
	var spin_years := SpinBox.new()
	spin_years.min_value = 1; spin_years.max_value = 5; spin_years.step = 1
	spin_years.value = clampi(p.contract_years + 2, 3, 5)
	spin_years.custom_minimum_size = Vector2(120, 40)
	row_years.add_child(spin_years)

	var row_sal := HBoxContainer.new()
	row_sal.add_theme_constant_override("separation", 12)
	box.add_child(row_sal)
	var lbl_s := Label.new(); lbl_s.text = "Nuevo sueldo semanal:"
	lbl_s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_s.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_s.add_theme_font_size_override("font_size", 15)
	row_sal.add_child(lbl_s)
	var spin_sal := SpinBox.new()
	spin_sal.min_value = p.salary
	spin_sal.max_value = p.salary * 8
	spin_sal.step = 500
	spin_sal.suffix = "€"
	spin_sal.value = hint_salary
	spin_sal.custom_minimum_size = Vector2(160, 40)
	row_sal.add_child(spin_sal)

	box.add_child(HSeparator.new())

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	box.add_child(btn_row)

	var btn_close := Button.new()
	btn_close.text = "Cancelar"
	btn_close.icon = ICON_CLOSE
	btn_close.add_theme_constant_override("icon_max_width", ICON_SIZE_ACTION)
	btn_close.custom_minimum_size = Vector2(110, 44)
	btn_close.pressed.connect(func(): _overlay.queue_free(); _overlay = null)
	btn_row.add_child(btn_close)

	var btn_propose := Button.new()
	btn_propose.text = "💬  Proponer condiciones"
	btn_propose.custom_minimum_size = Vector2(210, 44)
	btn_propose.add_theme_font_size_override("font_size", 15)
	btn_propose.add_theme_color_override("font_color", Color(0.35, 0.82, 0.98, 1))
	btn_propose.pressed.connect(func():
		var yrs := int(spin_years.value)
		var sal := int(spin_sal.value)
		_renewal_round += 1
		# La retención requiere condiciones mejores que la renovación normal
		var resp := _eval_retention_response(p, yrs, sal, _renewal_round, offer)
		if resp["verdict"] in ["reject", "counter"]:
			var ratio: float = float(sal) / float(maxi(resp["desired_salary"], 1))
			if ratio < 0.72:
				_renewal_frustration += 1
		_retention_response_phase(box, p, resp, yrs, sal, offer)
	)
	btn_row.add_child(btn_propose)


func _retention_response_phase(box: VBoxContainer, p: Player, resp: Dictionary,
		offered_years: int, offered_salary: int, offer: Dictionary) -> void:
	for c in box.get_children(): c.queue_free()

	var verdict: String     = resp["verdict"]
	var desired_salary: int = resp["desired_salary"]
	var desired_years: int  = resp["desired_years"]

	var banner := PanelContainer.new()
	var bsb := StyleBoxFlat.new()
	match verdict:
		"accept":  bsb.bg_color = Color(0.05, 0.22, 0.08, 1)
		"counter": bsb.bg_color = Color(0.22, 0.16, 0.04, 1)
		"reject", "walkout": bsb.bg_color = Color(0.24, 0.05, 0.05, 1)
	bsb.set_corner_radius_all(6)
	bsb.set_content_margin_all(14)
	banner.add_theme_stylebox_override("panel", bsb)
	box.add_child(banner)

	var bvb := VBoxContainer.new()
	bvb.add_theme_constant_override("separation", 6)
	banner.add_child(bvb)

	var lbl_main := Label.new()
	lbl_main.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_main.add_theme_font_size_override("font_size", 15)
	lbl_main.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bvb.add_child(lbl_main)

	var lbl_sub := Label.new()
	lbl_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_sub.add_theme_font_size_override("font_size", 13)
	lbl_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bvb.add_child(lbl_sub)

	match verdict:
		"accept":
			lbl_main.text = "✔  %s decide quedarse en el club." % p.full_name
			lbl_main.add_theme_color_override("font_color", Color(0.30, 0.95, 0.50, 1))
			lbl_sub.text = "La oferta de cláusula será rechazada. Nuevo contrato: %d año%s · %s/sem" % [
				offered_years, "s" if offered_years != 1 else "", _fmt_money(offered_salary)]
			lbl_sub.add_theme_color_override("font_color", Color(0.65, 0.88, 0.65, 1))
		"counter":
			lbl_main.text = "🤔  %s considera la oferta, pero quiere más." % p.full_name
			lbl_main.add_theme_color_override("font_color", Color(1.0, 0.80, 0.30, 1))
			lbl_sub.text = "Para quedarse exige: %d año%s · %s/sem" % [
				desired_years, "s" if desired_years != 1 else "", _fmt_money(desired_salary)]
			lbl_sub.add_theme_color_override("font_color", Color(0.90, 0.75, 0.50, 1))
		"reject", "walkout":
			lbl_main.text = "🔴  %s prefiere marcharse al %s." % [p.full_name,
				(GameManager.get_team(offer["buyer_id"]).name if GameManager.get_team(offer["buyer_id"]) else "club comprador")]
			lbl_main.add_theme_color_override("font_color", Color(1.0, 0.35, 0.30, 1))
			lbl_sub.text = "No es posible retenerle. Puedes confirmar la venta o dejar caducar la oferta."
			lbl_sub.add_theme_color_override("font_color", Color(0.80, 0.55, 0.55, 1))

	box.add_child(HSeparator.new())

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 14)
	box.add_child(btn_row)

	var btn_close := Button.new()
	btn_close.text = "Cerrar"
	btn_close.icon = ICON_CLOSE
	btn_close.add_theme_constant_override("icon_max_width", ICON_SIZE_ACTION)
	btn_close.custom_minimum_size = Vector2(100, 44)
	btn_close.pressed.connect(func(): _overlay.queue_free(); _overlay = null)
	btn_row.add_child(btn_close)

	if verdict == "accept":
		var btn_confirm := Button.new()
		btn_confirm.text = "Firmar y retener"
		btn_confirm.icon = ICON_CHECK
		btn_confirm.add_theme_constant_override("icon_max_width", ICON_SIZE_ACTION)
		btn_confirm.custom_minimum_size = Vector2(180, 44)
		btn_confirm.add_theme_font_size_override("font_size", 15)
		btn_confirm.add_theme_color_override("font_color", Color(0.20, 0.90, 0.50, 1))
		btn_confirm.pressed.connect(func():
			# Rechazar la oferta de cláusula y renovar contrato
			TransferManager.reject_incoming_offer(offer["id"])
			_confirm_renewal(p, offered_years, offered_salary)
		)
		btn_row.add_child(btn_confirm)

	elif verdict == "counter":
		var btn_accept_ctr := Button.new()
		btn_accept_ctr.text = "Aceptar sus condiciones"
		btn_accept_ctr.custom_minimum_size = Vector2(195, 44)
		btn_accept_ctr.add_theme_font_size_override("font_size", 14)
		btn_accept_ctr.add_theme_color_override("font_color", Color(0.20, 0.90, 0.50, 1))
		btn_accept_ctr.pressed.connect(func():
			TransferManager.reject_incoming_offer(offer["id"])
			_confirm_renewal(p, desired_years, desired_salary)
		)
		btn_row.add_child(btn_accept_ctr)

		var btn_retry := Button.new()
		btn_retry.text = "Re-negociar"
		btn_retry.custom_minimum_size = Vector2(130, 44)
		btn_retry.add_theme_font_size_override("font_size", 14)
		btn_retry.add_theme_color_override("font_color", Color(0.60, 0.80, 1.0, 1))
		btn_retry.pressed.connect(func(): _retention_proposal_phase(box, p, offer))
		btn_row.add_child(btn_retry)


# Evaluación de respuesta para retención (más exigente que renovación normal)
func _eval_retention_response(p: Player, offered_years: int, offered_salary: int,
		neg_round: int, _offer: Dictionary) -> Dictionary:
	var ovr: int = p.get_overall()

	# Umbral de frustración mucho más bajo porque tiene oferta real en la mano
	var walkout_threshold: int = 2 if ovr >= 70 else 3
	if _renewal_frustration >= walkout_threshold:
		return {"verdict": "walkout", "desired_salary": 0, "desired_years": 0}
	if neg_round >= 4 and randf() < 0.40:
		return {"verdict": "walkout", "desired_salary": 0, "desired_years": 0}

	# El jugador exige más que en renovación normal
	var base_raise: float = 0.20 + clampf((ovr - 50) * 0.010, 0.0, 0.50)
	var jitter: float = randf_range(-0.06, 0.06)
	var patience_discount: float = clampf((neg_round - 1) * 0.04, 0.0, 0.20)
	var morale_factor: float = 0.80 if p.morale < 50 else 1.0
	var raise_pct: float = maxf(0.10, (base_raise + jitter - patience_discount) * morale_factor)
	var desired_salary: int = int(p.salary * (1.0 + raise_pct) / 500.0) * 500

	var base_years: int = 3 if p.age < 28 else 2
	var desired_years: int = maxi(2, base_years - (1 if neg_round >= 2 and randf() < 0.35 else 0))

	var salary_ratio: float = float(offered_salary) / float(maxi(desired_salary, 1))
	var years_ok: bool = offered_years >= desired_years

	# El jugador es más duro en retención: umbrales más altos
	var accept_threshold: float  = maxf(0.80, 0.92 - (neg_round - 1) * 0.04)
	var counter_threshold: float = maxf(0.60, 0.72 - (neg_round - 1) * 0.03)

	if salary_ratio >= accept_threshold and years_ok:
		return {"verdict": "accept",  "desired_salary": desired_salary, "desired_years": desired_years}
	elif salary_ratio >= counter_threshold:
		return {"verdict": "counter", "desired_salary": desired_salary, "desired_years": desired_years}
	else:
		return {"verdict": "reject",  "desired_salary": desired_salary, "desired_years": desired_years}


func _renewal_proposal_phase(box: VBoxContainer, p: Player) -> void:
	for c in box.get_children(): c.queue_free()

	var row_years := HBoxContainer.new()
	row_years.add_theme_constant_override("separation", 12)
	box.add_child(row_years)
	var lbl_y := Label.new(); lbl_y.text = "Años de contrato:"
	lbl_y.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_y.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_y.add_theme_font_size_override("font_size", 15)
	row_years.add_child(lbl_y)
	var spin_years := SpinBox.new()
	spin_years.min_value = 1; spin_years.max_value = 5; spin_years.step = 1
	spin_years.value = clampi(p.contract_years + 1, 2, 5)
	spin_years.custom_minimum_size = Vector2(120, 40)
	row_years.add_child(spin_years)

	var row_sal := HBoxContainer.new()
	row_sal.add_theme_constant_override("separation", 12)
	box.add_child(row_sal)
	var lbl_s := Label.new(); lbl_s.text = "Sueldo semanal:"
	lbl_s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_s.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_s.add_theme_font_size_override("font_size", 15)
	row_sal.add_child(lbl_s)
	var spin_sal := SpinBox.new()
	spin_sal.min_value = int(p.salary * 0.5)
	spin_sal.max_value = p.salary * 6
	spin_sal.step = 500
	spin_sal.suffix = "€"
	spin_sal.value = int(p.salary * 1.10 / 500) * 500
	spin_sal.custom_minimum_size = Vector2(160, 40)
	row_sal.add_child(spin_sal)

	box.add_child(HSeparator.new())

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	box.add_child(btn_row)

	var btn_close := Button.new()
	btn_close.text = "Cerrar"
	btn_close.icon = ICON_CLOSE
	btn_close.add_theme_constant_override("icon_max_width", ICON_SIZE_ACTION)
	btn_close.custom_minimum_size = Vector2(110, 44)
	btn_close.pressed.connect(func(): _overlay.queue_free(); _overlay = null)
	btn_row.add_child(btn_close)

	var btn_propose := Button.new()
	btn_propose.text = "💬  Proponer condiciones"
	btn_propose.custom_minimum_size = Vector2(210, 44)
	btn_propose.add_theme_font_size_override("font_size", 15)
	btn_propose.add_theme_color_override("font_color", Color(0.35, 0.82, 0.98, 1))
	btn_propose.pressed.connect(func():
		var yrs := int(spin_years.value)
		var sal := int(spin_sal.value)
		_renewal_round += 1
		var resp := _eval_renewal_response(p, yrs, sal, _renewal_round, _renewal_frustration)
		if resp["verdict"] in ["reject", "counter"]:
			var salary_ratio: float = float(sal) / float(maxi(resp["desired_salary"], 1))
			if salary_ratio < 0.70:
				_renewal_frustration += 1
		_renewal_response_phase(box, p, resp, yrs, sal)
	)
	btn_row.add_child(btn_propose)


func _renewal_response_phase(box: VBoxContainer, p: Player, resp: Dictionary,
		offered_years: int, offered_salary: int) -> void:
	for c in box.get_children(): c.queue_free()

	var verdict: String     = resp["verdict"]
	var desired_salary: int = resp["desired_salary"]
	var desired_years: int  = resp["desired_years"]

	var banner := PanelContainer.new()
	var bsb := StyleBoxFlat.new()
	match verdict:
		"accept":  bsb.bg_color = Color(0.05, 0.22, 0.08, 1)
		"counter": bsb.bg_color = Color(0.22, 0.16, 0.04, 1)
		"reject":  bsb.bg_color = Color(0.24, 0.05, 0.05, 1)
		"walkout": bsb.bg_color = Color(0.28, 0.04, 0.10, 1)
	bsb.set_corner_radius_all(6)
	bsb.set_content_margin_all(14)
	banner.add_theme_stylebox_override("panel", bsb)
	box.add_child(banner)

	var bvb := VBoxContainer.new()
	bvb.add_theme_constant_override("separation", 6)
	banner.add_child(bvb)

	var lbl_main := Label.new()
	lbl_main.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_main.add_theme_font_size_override("font_size", 15)
	lbl_main.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bvb.add_child(lbl_main)

	var lbl_sub := Label.new()
	lbl_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_sub.add_theme_font_size_override("font_size", 13)
	lbl_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bvb.add_child(lbl_sub)

	match verdict:
		"accept":
			lbl_main.text = "✔  %s acepta las condiciones." % p.full_name
			lbl_main.add_theme_color_override("font_color", Color(0.30, 0.95, 0.50, 1))
			lbl_sub.text = "Nuevo contrato: %d año%s · %s/semana" % [
				offered_years, "s" if offered_years != 1 else "", _fmt_money(offered_salary)]
			lbl_sub.add_theme_color_override("font_color", Color(0.65, 0.88, 0.65, 1))
		"counter":
			lbl_main.text = "🤔  %s quiere negociar otros términos." % p.full_name
			lbl_main.add_theme_color_override("font_color", Color(1.0, 0.80, 0.30, 1))
			lbl_sub.text = "Contraoferta: %d año%s · %s/semana" % [
				desired_years, "s" if desired_years != 1 else "", _fmt_money(desired_salary)]
			lbl_sub.add_theme_color_override("font_color", Color(0.90, 0.75, 0.50, 1))
		"reject":
			lbl_main.text = "✗  %s rechaza la propuesta." % p.full_name
			lbl_main.add_theme_color_override("font_color", Color(1.0, 0.35, 0.30, 1))
			lbl_sub.text = "El jugador esperaba al menos %s/semana." % _fmt_money(desired_salary)
			lbl_sub.add_theme_color_override("font_color", Color(0.80, 0.55, 0.55, 1))
		"walkout":
			lbl_main.text = "🔴  %s ha roto las negociaciones." % p.full_name
			lbl_main.add_theme_font_size_override("font_size", 16)
			lbl_main.add_theme_color_override("font_color", Color(1.0, 0.22, 0.18, 1))
			lbl_sub.text = "El jugador ha pedido expresamente ser traspasado. Se ha puesto en venta de forma automática."
			lbl_sub.add_theme_color_override("font_color", Color(0.90, 0.60, 0.55, 1))
			p.transfer_listed = true
			p.morale = maxi(20, p.morale - 15)
			SaveManager.save_game()

	box.add_child(HSeparator.new())

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 14)
	box.add_child(btn_row)

	var btn_close := Button.new()
	btn_close.text = "Cerrar"
	btn_close.icon = ICON_CLOSE
	btn_close.add_theme_constant_override("icon_max_width", ICON_SIZE_ACTION)
	btn_close.custom_minimum_size = Vector2(100, 44)
	btn_close.pressed.connect(func(): _overlay.queue_free(); _overlay = null)
	btn_row.add_child(btn_close)

	if verdict == "accept":
		var btn_confirm := Button.new()
		btn_confirm.text = "Firmar contrato"
		btn_confirm.icon = ICON_CHECK
		btn_confirm.add_theme_constant_override("icon_max_width", ICON_SIZE_ACTION)
		btn_confirm.custom_minimum_size = Vector2(170, 44)
		btn_confirm.add_theme_font_size_override("font_size", 15)
		btn_confirm.add_theme_color_override("font_color", Color(0.20, 0.90, 0.50, 1))
		btn_confirm.pressed.connect(func(): _confirm_renewal(p, offered_years, offered_salary))
		btn_row.add_child(btn_confirm)

	elif verdict == "counter":
		var btn_accept_ctr := Button.new()
		btn_accept_ctr.text = "Aceptar contraoferta"
		btn_accept_ctr.custom_minimum_size = Vector2(180, 44)
		btn_accept_ctr.add_theme_font_size_override("font_size", 14)
		btn_accept_ctr.add_theme_color_override("font_color", Color(0.20, 0.90, 0.50, 1))
		btn_accept_ctr.pressed.connect(func(): _confirm_renewal(p, desired_years, desired_salary))
		btn_row.add_child(btn_accept_ctr)

		var btn_retry := Button.new()
		btn_retry.text = "Re-negociar"
		btn_retry.custom_minimum_size = Vector2(130, 44)
		btn_retry.add_theme_font_size_override("font_size", 14)
		btn_retry.add_theme_color_override("font_color", Color(0.60, 0.80, 1.0, 1))
		btn_retry.pressed.connect(func(): _renewal_proposal_phase(box, p))
		btn_row.add_child(btn_retry)

	# En walkout y reject el único botón disponible es Cerrar


func _confirm_renewal(p: Player, new_years: int, new_salary: int) -> void:
	var signing_fee: int = maxi(0, (new_salary - p.salary) * 26)
	if _team.club_cash < signing_fee:
		var dlg := AcceptDialog.new()
		dlg.dialog_text = "Sin fondos para la prima de firma (%s).\nReduce el sueldo ofrecido." % _fmt_money(signing_fee)
		add_child(dlg)
		dlg.popup_centered()
		return
	p.contract_years = new_years
	p.salary         = new_salary
	_team.club_cash -= signing_fee
	p.market_value   = TransferManager.calculate_value(p)
	SaveManager.save_game()
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null
	_build_list()


func _eval_renewal_response(p: Player, offered_years: int, offered_salary: int, neg_round: int, frustration: int) -> Dictionary:
	var ovr: int = p.get_overall()

	# Si el jugador lleva 3+ rondas de malas ofertas, walkout
	# (también se activa antes si tiene buena moral y el club no tiene intención de pagar)
	var walkout_threshold: int = 2 if (p.morale >= 70 and ovr >= 75) else 3
	if frustration >= walkout_threshold:
		return {"verdict": "walkout", "desired_salary": 0, "desired_years": 0}

	# También: ronda muy alta sin acuerdo = el jugador se cansa y se va
	if neg_round >= 5 and randf() < 0.35:
		return {"verdict": "walkout", "desired_salary": 0, "desired_years": 0}

	# Base: +5 % en OVR 50, hasta +36 % en OVR 95
	var base_raise: float = 0.05 + clampf((ovr - 50) * 0.0080, 0.0, 0.36)

	# Variación aleatoria ±8 % en cada ronda
	var jitter: float = randf_range(-0.08, 0.08)

	# Cada ronda de negociación el jugador cede un poco (hasta ‑18 % tras 6 rondas)
	var patience_discount: float = clampf((neg_round - 1) * 0.03, 0.0, 0.18)

	# Moral baja → el jugador ya quiere salir, acepta menos
	var morale_factor: float = 1.0
	if p.morale < 50:
		morale_factor = 0.65
	elif p.morale < 65:
		morale_factor = 0.85

	var raise_pct: float = maxf(0.01, (base_raise + jitter - patience_discount) * morale_factor)
	var desired_salary: int = (int(p.salary * (1.0 + raise_pct) / 500.0) * 500)

	# Años deseados según edad, con algo de aleatoriedad
	var base_years: int
	if   p.age < 24: base_years = 4
	elif p.age < 28: base_years = 3
	elif p.age < 32: base_years = 2
	else:            base_years = 1
	# En rondas avanzadas, el jugador puede volverse más flexible en duración
	var year_flex: int = 1 if (neg_round >= 2 and randf() < 0.40) else 0
	var desired_years: int = maxi(1, base_years - year_flex)

	var salary_ratio: float = float(offered_salary) / float(maxi(desired_salary, 1))
	var years_ok: bool = abs(offered_years - desired_years) <= 1

	# Los umbrales de aceptación también se suavizan con las rondas
	var accept_threshold: float  = maxf(0.72, 0.88 - (neg_round - 1) * 0.04)
	var counter_threshold: float = maxf(0.50, 0.68 - (neg_round - 1) * 0.03)

	if salary_ratio >= accept_threshold and years_ok:
		return {"verdict": "accept",  "desired_salary": desired_salary, "desired_years": desired_years}
	elif salary_ratio >= counter_threshold or (salary_ratio >= accept_threshold - 0.10 and years_ok):
		return {"verdict": "counter", "desired_salary": desired_salary, "desired_years": desired_years}
	else:
		return {"verdict": "reject",  "desired_salary": desired_salary, "desired_years": desired_years}


func _make_dim_overlay() -> Control:
	var ov := Control.new()
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.70)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.add_child(dim)
	return ov


func _stat_lbl(val: int, width: int) -> Label:
	var lbl := Label.new()
	lbl.custom_minimum_size = Vector2(width, 0)
	lbl.text = str(val)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color",
		Color(0.15, 0.85, 0.35, 1) if val >= 70 else
		Color(0.85, 0.75, 0.20, 1) if val >= 55 else
		Color(0.80, 0.35, 0.25, 1))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


func _vsep(col: Color) -> Control:
	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(2, 0)
	sep.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sep.color = col
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return sep


func _fmt_money(amount: int) -> String:
	if amount >= 1_000_000:
		return "%.1fM €" % (amount / 1_000_000.0)
	elif amount >= 1_000:
		return "%.0fK €" % (amount / 1_000.0)
	return "%d €" % amount
