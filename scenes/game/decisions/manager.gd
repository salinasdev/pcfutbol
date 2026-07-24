extends Control
class_name ManagerScreen

const ICON_BACK := preload("res://assets/ui/icons/back-white.png")
const ICON_MANAGER := preload("res://assets/ui/icons/briefcase.png")
const ICON_CLIPBOARD := preload("res://assets/ui/icons/chart.png")
const ICON_SIZE_NAV := 28

var _stats_box: VBoxContainer
var _offers_box: VBoxContainer


func _ready() -> void:
	_build_ui()
	_refresh()


func _refresh() -> void:
	_refresh_stats()
	_refresh_offers()


func _refresh_stats() -> void:
	for c in _stats_box.get_children():
		c.queue_free()

	var team: Team = GameManager.get_player_team()
	var team_name := team.name if team != null else "Sin equipo"
	var win_rate := GameManager.get_manager_win_rate()

	_stats_box.add_child(_kv_row("Mánager", GameManager.manager_name))
	_stats_box.add_child(_kv_row("Club actual", team_name))
	_stats_box.add_child(_kv_row("Partidos dirigidos", str(GameManager.manager_matches)))
	_stats_box.add_child(_kv_row("Balance", "%dV · %dE · %dD" % [
		GameManager.manager_wins,
		GameManager.manager_draws,
		GameManager.manager_losses,
	]))
	_stats_box.add_child(_kv_row("Porcentaje de victorias", "%.1f %%" % win_rate))
	_stats_box.add_child(_kv_row("Valoración", "%.1f / 10" % GameManager.manager_rating))
	_stats_box.add_child(_kv_row("Confianza directiva", "%.1f / 10" % GameManager.board_confidence))
	_stats_box.add_child(_kv_row("Confianza pública", "%.1f / 10" % GameManager.public_confidence))
	_stats_box.add_child(_kv_row("Ofertas recibidas", str(GameManager.manager_offers_received)))
	_stats_box.add_child(_kv_row("Ofertas aceptadas", str(GameManager.manager_offers_accepted)))


func _refresh_offers() -> void:
	for c in _offers_box.get_children():
		c.queue_free()

	var pending: Array[Dictionary] = []
	for of: Dictionary in GameManager.manager_job_offers:
		if of.get("status", "pending") == "pending":
			pending.append(of)

	pending.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("deadline_week", 0)) < int(b.get("deadline_week", 0))
	)

	if pending.is_empty():
		var lbl := Label.new()
		lbl.text = "No tienes ofertas activas ahora mismo."
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override("font_color", Color(0.60, 0.65, 0.72, 1))
		_offers_box.add_child(lbl)
		return

	for of: Dictionary in pending:
		_offers_box.add_child(_offer_card(of))


func _offer_card(of: Dictionary) -> Control:
	var team: Team = GameManager.get_team(int(of.get("team_id", -1)))
	var league: League = GameManager.get_league(int(of.get("league_id", 0)))
	var team_name := team.name if team != null else "Club desconocido"
	var league_name := league.name if league != null else "Liga"
	var salary := int(of.get("salary", 0))
	var deadline := int(of.get("deadline_week", GameManager.current_week))
	var weeks_left := maxi(0, deadline - GameManager.current_week)
	var offer_id := int(of.get("id", -1))

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.16, 0.22, 1)
	sb.border_width_left = 4
	sb.border_color = Color(0.28, 0.62, 0.92, 1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(0, 110)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)

	var title := Label.new()
	title.text = "%s (%s)" % [team_name, league_name]
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.93, 0.96, 1.0, 1))
	v.add_child(title)

	var detail := Label.new()
	detail.text = "Salario: %s €/temporada · Caduca en %d semana(s)" % [_fmt(salary), weeks_left]
	detail.add_theme_font_size_override("font_size", 14)
	detail.add_theme_color_override("font_color", Color(0.75, 0.80, 0.86, 1))
	v.add_child(detail)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)

	var btn_accept := Button.new()
	btn_accept.text = "Aceptar"
	btn_accept.custom_minimum_size = Vector2(120, 36)
	btn_accept.add_theme_color_override("font_color", Color(0.30, 0.95, 0.40, 1))
	btn_accept.pressed.connect(func():
		var msg := GameManager.accept_manager_job_offer(offer_id)
		_show_message(msg)
		_refresh()
	)
	row.add_child(btn_accept)

	var btn_reject := Button.new()
	btn_reject.text = "Rechazar"
	btn_reject.custom_minimum_size = Vector2(120, 36)
	btn_reject.add_theme_color_override("font_color", Color(0.95, 0.40, 0.35, 1))
	btn_reject.pressed.connect(func():
		var msg := GameManager.reject_manager_job_offer(offer_id)
		_show_message(msg)
		_refresh()
	)
	row.add_child(btn_reject)

	return panel


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.09, 0.13, 1)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	var top := HBoxContainer.new()
	top.custom_minimum_size = Vector2(0, 64)
	root.add_child(top)

	var btn_back := Button.new()
	btn_back.text = ""
	btn_back.icon = ICON_BACK
	btn_back.add_theme_constant_override("icon_max_width", ICON_SIZE_NAV)
	btn_back.custom_minimum_size = Vector2(64, 64)
	btn_back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/game/decisions/decisions_hub.tscn"))
	top.add_child(btn_back)

	var title_row := HBoxContainer.new()
	title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_theme_constant_override("separation", 8)
	top.add_child(title_row)

	var icon := TextureRect.new()
	icon.texture = ICON_MANAGER
	icon.custom_minimum_size = Vector2(24, 24)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title_row.add_child(icon)

	var title := Label.new()
	title.text = "Manager"
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.90, 0.85, 0.50, 1))
	title_row.add_child(title)

	root.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	scroll.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	margin.add_child(content)

	var stats_title_row := HBoxContainer.new()
	stats_title_row.add_theme_constant_override("separation", 8)
	content.add_child(stats_title_row)

	var stats_icon := TextureRect.new()
	stats_icon.texture = ICON_CLIPBOARD
	stats_icon.custom_minimum_size = Vector2(18, 18)
	stats_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	stats_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	stats_title_row.add_child(stats_icon)

	var stats_title := Label.new()
	stats_title.text = "Estadísticas"
	stats_title.add_theme_font_size_override("font_size", 20)
	stats_title.add_theme_color_override("font_color", Color(0.85, 0.90, 0.98, 1))
	stats_title_row.add_child(stats_title)

	_stats_box = VBoxContainer.new()
	_stats_box.add_theme_constant_override("separation", 6)
	content.add_child(_wrap_panel(_stats_box, Color(0.20, 0.35, 0.55, 1)))

	var offers_title := Label.new()
	offers_title.text = "Ofertas de otros clubes"
	offers_title.add_theme_font_size_override("font_size", 20)
	offers_title.add_theme_color_override("font_color", Color(0.85, 0.90, 0.98, 1))
	content.add_child(offers_title)

	_offers_box = VBoxContainer.new()
	_offers_box.add_theme_constant_override("separation", 8)
	content.add_child(_wrap_panel(_offers_box, Color(0.28, 0.62, 0.92, 1)))


func _wrap_panel(inner: Control, accent: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.14, 0.20, 1)
	sb.border_width_left = 4
	sb.border_color = accent
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", sb)
	panel.add_child(inner)
	return panel


func _kv_row(k: String, v: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var lk := Label.new()
	lk.text = k
	lk.custom_minimum_size = Vector2(230, 0)
	lk.add_theme_font_size_override("font_size", 15)
	lk.add_theme_color_override("font_color", Color(0.60, 0.66, 0.75, 1))
	row.add_child(lk)
	var lv := Label.new()
	lv.text = v
	lv.add_theme_font_size_override("font_size", 16)
	lv.add_theme_color_override("font_color", Color(0.90, 0.93, 0.98, 1))
	row.add_child(lv)
	return row


func _show_message(msg: String) -> void:
	var d := AcceptDialog.new()
	d.title = "Manager"
	d.dialog_text = msg
	add_child(d)
	d.popup_centered()


func _fmt(amount: int) -> String:
	var s := str(amount)
	var out := ""
	var count := 0
	for i: int in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			out = "." + out
		out = s[i] + out
		count += 1
	return out
