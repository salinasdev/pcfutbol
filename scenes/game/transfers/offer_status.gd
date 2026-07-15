extends Control

const STATUS_COLOR := {
	"pending":  Color(0.95, 0.80, 0.10, 1),
	"accepted": Color(0.25, 0.90, 0.35, 1),
	"rejected": Color(1.00, 0.30, 0.30, 1),
	"countered":Color(1.00, 0.60, 0.10, 1),
}
const STATUS_LABEL := {
	"pending":   "⏳ Pendiente",
	"accepted":  "✅ Aceptada",
	"rejected":  "❌ Rechazada",
	"countered": "🔄 Contraoferta",
}

var _list: VBoxContainer
var _status_lbl: Label


func _ready() -> void:
	_build_ui()
	_refresh()
	TransferManager.acknowledge_active_offers()
	TransferManager.offer_response_received.connect(_on_response)


# ---------------------------------------------------------------------------

func _refresh() -> void:
	for ch in _list.get_children():
		ch.queue_free()

	if TransferManager.active_offers.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No tienes ofertas activas."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_font_size_override("font_size", 17)
		empty_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
		empty_lbl.custom_minimum_size = Vector2(0, 80)
		_list.add_child(empty_lbl)
		return

	# Mostrar en orden: pendientes/contraoferta primero, luego el resto
	var sorted: Array = TransferManager.active_offers.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var priority := {"countered": 0, "pending": 1, "rejected": 2, "accepted": 3}
		return priority.get(a["status"], 9) < priority.get(b["status"], 9)
	)

	for offer: Dictionary in sorted:
		_list.add_child(_make_row(offer))


func _make_row(offer: Dictionary) -> Control:
	var player: Player = GameManager.get_player(offer["player_id"])
	var seller: Team   = GameManager.get_team(player.team_id if player else -1)
	var status: String = offer["status"]

	var panel := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.12, 0.14, 0.20, 0.95)
	st.set_corner_radius_all(5)
	st.set_content_margin_all(14)
	# Borde izquierdo coloreado por estado
	st.border_color = STATUS_COLOR.get(status, Color.WHITE)
	st.set_border_width_all(0)
	st.border_width_left = 4
	panel.add_theme_stylebox_override("panel", st)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	# ── Fila superior: jugador + estado ─────────────────────────────────────
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	vbox.add_child(top_row)

	var p_name := Label.new()
	p_name.text = "%s  [%s]  %d años  —  %s" % [
		player.full_name if player else "Jugador desconocido",
		player.get_position_abbr() if player else "?",
		player.age if player else 0,
		seller.short_name if seller else "Sin equipo",
	]
	p_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p_name.add_theme_font_size_override("font_size", 17)
	top_row.add_child(p_name)

	var badge := Label.new()
	badge.text = STATUS_LABEL.get(status, status)
	badge.add_theme_font_size_override("font_size", 14)
	badge.add_theme_color_override("font_color", STATUS_COLOR.get(status, Color.WHITE))
	top_row.add_child(badge)

	# ── Detalles de la oferta ────────────────────────────────────────────────
	var od: Dictionary = offer["offer_data"]
	var details_lbl := Label.new()
	var inc_str: String = "Inmediata" if od.get("join_when", 0) == 0 else "Fin temporada"
	details_lbl.text = "Dinero: %s €   |   Contrato: %d años   |   Prima anual: %s €   |   Incorporación: %s   |   Semana %d" % [
		_fmt(od.get("money", 0)),
		od.get("contract_years", 2),
		_fmt(od.get("annual_bonus", 0)),
		inc_str,
		offer["week_submitted"],
	]
	details_lbl.add_theme_font_size_override("font_size", 13)
	details_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	vbox.add_child(details_lbl)

	# ── Mensaje de respuesta ─────────────────────────────────────────────────
	var resp_lbl := Label.new()
	resp_lbl.text = offer["response_message"]
	resp_lbl.add_theme_font_size_override("font_size", 15)
	resp_lbl.add_theme_color_override("font_color", STATUS_COLOR.get(status, Color.WHITE))
	resp_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(resp_lbl)

	# ── Contraoferta: detalle + botones ─────────────────────────────────────
	if status == "countered":
		var cd: Dictionary = offer["counter_data"]
		var counter_lbl := Label.new()
		counter_lbl.text = "Contraoferta:  %s €  ·  %d años  ·  Prima %s €/año" % [
			_fmt(cd.get("money", 0)),
			cd.get("contract_years", 2),
			_fmt(cd.get("annual_bonus", 0)),
		]
		counter_lbl.add_theme_font_size_override("font_size", 15)
		counter_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4, 1))
		vbox.add_child(counter_lbl)

		var btn_row := HBoxContainer.new()
		btn_row.add_theme_constant_override("separation", 14)
		vbox.add_child(btn_row)

		var btn_accept := Button.new()
		btn_accept.text = "✔ Aceptar contraoferta"
		btn_accept.custom_minimum_size = Vector2(220, 42)
		btn_accept.add_theme_font_size_override("font_size", 15)
		var oid: int = offer["id"]
		btn_accept.pressed.connect(func() -> void:
			TransferManager.accept_counter(oid)
			_set_status("Contraoferta aceptada. ¡Fichaje completado!")
			_refresh()
		)
		btn_row.add_child(btn_accept)

		var btn_reject := Button.new()
		btn_reject.text = "✘ Rechazar"
		btn_reject.custom_minimum_size = Vector2(130, 42)
		btn_reject.add_theme_font_size_override("font_size", 15)
		btn_reject.pressed.connect(func() -> void:
			TransferManager.withdraw_offer(oid)
			_set_status("Contraoferta rechazada. Oferta retirada.")
			_refresh()
		)
		btn_row.add_child(btn_reject)

	# ── Pendiente: botón retirar ─────────────────────────────────────────────
	elif status == "pending":
		var btn_withdraw := Button.new()
		btn_withdraw.text = "Retirar oferta"
		btn_withdraw.custom_minimum_size = Vector2(160, 40)
		btn_withdraw.add_theme_font_size_override("font_size", 14)
		var oid: int = offer["id"]
		btn_withdraw.pressed.connect(func() -> void:
			TransferManager.withdraw_offer(oid)
			_set_status("Oferta retirada.")
			_refresh()
		)
		vbox.add_child(btn_withdraw)

	# ── Aceptada/Rechazada: botón eliminar ───────────────────────────────────
	else:
		var btn_del := Button.new()
		btn_del.text = "Eliminar"
		btn_del.custom_minimum_size = Vector2(110, 38)
		btn_del.add_theme_font_size_override("font_size", 13)
		var oid: int = offer["id"]
		btn_del.pressed.connect(func() -> void:
			TransferManager.withdraw_offer(oid)
			_refresh()
		)
		vbox.add_child(btn_del)

	return panel


# ---------------------------------------------------------------------------
# Eventos

func _on_response(_offer: Dictionary) -> void:
	_refresh()
	_set_status("El club ha respondido a una de tus ofertas.")


# ---------------------------------------------------------------------------
# UI builder

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.07, 0.09, 0.13, 1)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 0)
	add_child(vbox)

	# Top bar
	var top_bar := HBoxContainer.new()
	top_bar.custom_minimum_size = Vector2(0, 72)
	top_bar.add_theme_constant_override("separation", 8)
	vbox.add_child(top_bar)

	var btn_back := Button.new()
	btn_back.text = "◀"
	btn_back.custom_minimum_size = Vector2(72, 72)
	btn_back.add_theme_font_size_override("font_size", 24)
	btn_back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/game/transfers/transfers.tscn")
	)
	top_bar.add_child(btn_back)

	var title := Label.new()
	title.text = "Estado de las Ofertas"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	top_bar.add_child(title)

	vbox.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)

	vbox.add_child(HSeparator.new())

	_status_lbl = Label.new()
	_status_lbl.custom_minimum_size = Vector2(0, 40)
	_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_lbl.add_theme_font_size_override("font_size", 15)
	vbox.add_child(_status_lbl)


func _set_status(msg: String) -> void:
	_status_lbl.text = msg


func _fmt(amount: int) -> String:
	if amount >= 1_000_000:
		return "%.1fM" % (amount / 1_000_000.0)
	elif amount >= 1_000:
		return "%dK" % (amount / 1_000)
	return str(amount)
