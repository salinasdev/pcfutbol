extends Control

const POS_LABELS := ["Todas", "POR", "DEF", "MED", "DEL"]
const MODE_ALL    := 0
const MODE_LISTED := 1

var _offer_player: Player = null
var _filter_pos: int  = 0   # 0 = todas
var _filter_mode: int = 0   # 0 = todos, 1 = en venta


func _ready() -> void:
	%BtnBack.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/game/office/office.tscn"))

	for lbl: String in POS_LABELS:
		%FilterPos.add_item(lbl)
	%FilterMode.add_item("Todos los jugadores")
	%FilterMode.add_item("En venta")

	%FilterPos.item_selected.connect(func(i: int): _filter_pos = i; _refresh_list())
	%FilterMode.item_selected.connect(func(i: int): _filter_mode = i; _refresh_list())

	(%OfferDialog as OfferDialog).offer_submitted.connect(_on_offer_submitted)
	%BtnOfferStatus.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/game/transfers/offer_status.tscn"))

	TransferManager.transfer_completed.connect(_on_transfer_done)
	TransferManager.transfer_rejected.connect(_on_transfer_rejected)

	_refresh_budget()
	_refresh_list()


# ---------------------------------------------------------------------------
# Lista de jugadores

func _refresh_list() -> void:
	var list: VBoxContainer = %PlayerList
	for child in list.get_children():
		child.queue_free()

	var my_team := GameManager.get_player_team()
	var players := _get_filtered_players(my_team)

	for p: Player in players:
		list.add_child(_make_player_row(p, my_team))


func _get_filtered_players(my_team: Team) -> Array:
	var all_players: Array = []
	for p: Player in GameManager.players.values():
		if my_team != null and p.team_id == my_team.id:
			continue   # no mostramos nuestros propios jugadores
		if _filter_mode == MODE_LISTED and not p.transfer_listed:
			continue
		if _filter_pos > 0:
			var pos_map := [Player.Position.GK, Player.Position.DEF,
							Player.Position.MID, Player.Position.FWD]
			if p.position != pos_map[_filter_pos - 1]:
				continue
		all_players.append(p)

	# Ordenar por overall descendente
	all_players.sort_custom(func(a: Player, b: Player) -> bool:
		return a.get_overall() > b.get_overall()
	)
	return all_players


func _make_player_row(p: Player, my_team: Team) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 60)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 0.5) if p.transfer_listed else Color(0.1, 0.1, 0.1, 0.4)
	style.set_corner_radius_all(3)
	panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 0)
	panel.add_child(hbox)

	# POS
	var lbl_pos := Label.new()
	lbl_pos.custom_minimum_size = Vector2(46, 0)
	lbl_pos.text = p.get_position_abbr()
	lbl_pos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_pos.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl_pos.add_theme_font_size_override("font_size", 14)
	hbox.add_child(lbl_pos)

	# NOMBRE + equipo actual
	var seller: Team = GameManager.get_team(p.team_id)
	var seller_short := seller.short_name if seller else "---"
	var name_vbox := VBoxContainer.new()
	name_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_vbox.add_theme_constant_override("separation", 0)
	var lbl_name := Label.new()
	lbl_name.text = p.full_name
	lbl_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_name.add_theme_font_size_override("font_size", 16)
	var lbl_club := Label.new()
	lbl_club.text = seller_short + ("  📋" if p.transfer_listed else "")
	lbl_club.add_theme_font_size_override("font_size", 12)
	lbl_club.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6, 1))
	name_vbox.add_child(lbl_name)
	name_vbox.add_child(lbl_club)
	hbox.add_child(name_vbox)

	# EDAD
	var lbl_age := Label.new()
	lbl_age.custom_minimum_size = Vector2(40, 0)
	lbl_age.text = str(p.age)
	lbl_age.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_age.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl_age.add_theme_font_size_override("font_size", 15)
	lbl_age.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75, 1))
	hbox.add_child(lbl_age)

	# OVERALL
	var ovr := p.get_overall()
	var lbl_ovr := Label.new()
	lbl_ovr.custom_minimum_size = Vector2(40, 0)
	lbl_ovr.text = str(ovr)
	lbl_ovr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_ovr.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl_ovr.add_theme_font_size_override("font_size", 17)
	var ovr_col := Color(0.2, 1.0, 0.4, 1) if ovr >= 15 else (Color(0.9, 0.9, 0.2, 1) if ovr >= 11 else Color(1.0, 0.5, 0.3, 1))
	lbl_ovr.add_theme_color_override("font_color", ovr_col)
	hbox.add_child(lbl_ovr)

	# VALOR
	var lbl_val := Label.new()
	lbl_val.custom_minimum_size = Vector2(72, 0)
	lbl_val.text = _fmt(TransferManager.calculate_value(p))
	lbl_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_val.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl_val.add_theme_font_size_override("font_size", 14)
	lbl_val.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7, 1))
	hbox.add_child(lbl_val)

	# Botón oferta
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(72, 0)
	btn.text = "Fichar"
	btn.add_theme_font_size_override("font_size", 14)
	if my_team == null or my_team.budget <= 0:
		btn.disabled = true
	btn.pressed.connect(func(): _open_offer_dialog(p))
	hbox.add_child(btn)

	return panel


# ---------------------------------------------------------------------------
# Diálogo de oferta

func _open_offer_dialog(p: Player) -> void:
	_offer_player = p
	var my_team := GameManager.get_player_team()
	if my_team == null:
		return
	(%OfferDialog as OfferDialog).open(p, my_team)


func _on_offer_submitted(data: Dictionary) -> void:
	var my_team := GameManager.get_player_team()
	if my_team == null:
		return
	var oid: int = TransferManager.place_offer(my_team, data)
	if oid >= 0:
		_set_status("✔ Oferta enviada. El club responderá en breve.", true)
	else:
		_set_status("✘ No se pudo enviar la oferta.", false)
	_offer_player = null


# ---------------------------------------------------------------------------
# Señales de TransferManager

func _on_transfer_done(player: Player, _from: Team, _to: Team, fee: int) -> void:
	_refresh_budget()
	_refresh_list()
	_set_status("✔ %s fichado por %s €" % [player.full_name, _fmt(fee)], true)


func _on_transfer_rejected(_player: Player, reason: String) -> void:
	_set_status("✘ " + reason, false)


# ---------------------------------------------------------------------------
# Helpers

func _refresh_budget() -> void:
	var t := GameManager.get_player_team()
	%BudgetLabel.text = "Presupuesto: %s €" % (_fmt(t.budget) if t else "--")


func _set_status(msg: String, ok: bool) -> void:
	%StatusLabel.text = msg
	%StatusLabel.add_theme_color_override("font_color",
		Color(0.3, 1.0, 0.4, 1) if ok else Color(1.0, 0.4, 0.4, 1))


func _fmt(amount: int) -> String:
	if amount >= 1_000_000:
		return "%.1fM" % (amount / 1_000_000.0)
	elif amount >= 1_000:
		return "%dK" % (amount / 1_000)
	return str(amount)
