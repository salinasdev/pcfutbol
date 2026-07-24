extends Control
class_name ManagerScreen

const ICON_BACK := preload("res://assets/ui/icons/back-white.png")
const ICON_MANAGER := preload("res://assets/ui/icons/briefcase.png")
const ICON_CLIPBOARD := preload("res://assets/ui/icons/chart.png")
const ICON_SIZE_NAV := 28

var _stats_box: VBoxContainer
var _prefs_box: VBoxContainer
var _honours_box: VBoxContainer
var _history_box: VBoxContainer
var _offers_box: VBoxContainer


func _ready() -> void:
	_build_ui()
	_refresh()


func _refresh() -> void:
	_refresh_stats()
	_refresh_preferences()
	_refresh_honours()
	_refresh_history()
	_refresh_offers()


func _refresh_stats() -> void:
	for c in _stats_box.get_children():
		c.queue_free()

	var team: Team = GameManager.get_player_team()
	var team_name := team.name if team != null else "Sin equipo"
	var win_rate := GameManager.get_manager_win_rate()

	_stats_box.add_child(_kv_row("Mánager", GameManager.manager_name))
	_stats_box.add_child(_kv_row("Club actual", team_name))
	_stats_box.add_child(_kv_row("Reputación global", "%.1f / 100" % GameManager.manager_global_reputation))
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


func _refresh_preferences() -> void:
	for c in _prefs_box.get_children():
		c.queue_free()

	_prefs_box.add_child(_pref_row("División objetivo", "preferred_level"))
	_prefs_box.add_child(_pref_row("Tipo de proyecto", "project_type"))
	_prefs_box.add_child(_pref_row("Reputación mínima", "min_reputation"))


func _refresh_honours() -> void:
	for c in _honours_box.get_children():
		c.queue_free()

	if GameManager.manager_honours.is_empty():
		var empty := Label.new()
		empty.text = "Aún no has ganado títulos ni ascensos."
		empty.add_theme_font_size_override("font_size", 15)
		empty.add_theme_color_override("font_color", Color(0.60, 0.65, 0.72, 1))
		_honours_box.add_child(empty)
		return

	for i: int in range(GameManager.manager_honours.size() - 1, -1, -1):
		var honour: Dictionary = GameManager.manager_honours[i]
		_honours_box.add_child(_kv_row(
			"%d/%s" % [int(honour.get("season", GameManager.season)), str(int(honour.get("season", GameManager.season)) + 1).right(2)],
			"%s · %s" % [str(honour.get("title", "Logro")), str(honour.get("team_name", "Club"))]
		))


func _refresh_history() -> void:
	for c in _history_box.get_children():
		c.queue_free()

	if GameManager.manager_career_history.is_empty():
		var empty := Label.new()
		empty.text = "Sin historial de clubes todavía."
		empty.add_theme_font_size_override("font_size", 15)
		empty.add_theme_color_override("font_color", Color(0.60, 0.65, 0.72, 1))
		_history_box.add_child(empty)
		return

	for i: int in range(GameManager.manager_career_history.size() - 1, -1, -1):
		var entry: Dictionary = GameManager.manager_career_history[i]
		var start_season := int(entry.get("start_season", GameManager.season))
		var end_season := int(entry.get("end_season", 0))
		var period := "%d-%s" % [start_season, str(start_season + 1).right(2)]
		if end_season > 0 and end_season != start_season:
			period = "%s → %d-%s" % [period, end_season, str(end_season + 1).right(2)]
		elif end_season == 0:
			period += " · actual"
		var reason := str(entry.get("exit_reason", ""))
		var text := "%s · %s" % [str(entry.get("team_name", "Club")), period]
		if not reason.is_empty():
			text += " · %s" % reason
		_history_box.add_child(_simple_line(text))


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

	var prefs_title := Label.new()
	prefs_title.text = "Preferencias de clubs"
	prefs_title.add_theme_font_size_override("font_size", 20)
	prefs_title.add_theme_color_override("font_color", Color(0.85, 0.90, 0.98, 1))
	content.add_child(prefs_title)

	_prefs_box = VBoxContainer.new()
	_prefs_box.add_theme_constant_override("separation", 8)
	content.add_child(_wrap_panel(_prefs_box, Color(0.60, 0.45, 0.18, 1)))

	var honours_title := Label.new()
	honours_title.text = "Palmarés"
	honours_title.add_theme_font_size_override("font_size", 20)
	honours_title.add_theme_color_override("font_color", Color(0.85, 0.90, 0.98, 1))
	content.add_child(honours_title)

	_honours_box = VBoxContainer.new()
	_honours_box.add_theme_constant_override("separation", 6)
	content.add_child(_wrap_panel(_honours_box, Color(0.78, 0.66, 0.22, 1)))

	var history_title := Label.new()
	history_title.text = "Historial de clubes"
	history_title.add_theme_font_size_override("font_size", 20)
	history_title.add_theme_color_override("font_color", Color(0.85, 0.90, 0.98, 1))
	content.add_child(history_title)

	_history_box = VBoxContainer.new()
	_history_box.add_theme_constant_override("separation", 6)
	content.add_child(_wrap_panel(_history_box, Color(0.38, 0.56, 0.28, 1)))

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


func _pref_row(label_text: String, key: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(230, 0)
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color(0.90, 0.93, 0.98, 1))
	row.add_child(lbl)

	var value := Label.new()
	value.text = GameManager.get_manager_preference_label(key)
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.add_theme_font_size_override("font_size", 15)
	value.add_theme_color_override("font_color", Color(0.95, 0.82, 0.35, 1))
	row.add_child(value)

	var btn_prev := Button.new()
	btn_prev.text = "◀"
	btn_prev.custom_minimum_size = Vector2(44, 32)
	btn_prev.pressed.connect(func():
		GameManager.cycle_manager_preference(key, -1)
		_refresh_preferences()
	)
	row.add_child(btn_prev)

	var btn_next := Button.new()
	btn_next.text = "▶"
	btn_next.custom_minimum_size = Vector2(44, 32)
	btn_next.pressed.connect(func():
		GameManager.cycle_manager_preference(key, 1)
		_refresh_preferences()
	)
	row.add_child(btn_next)

	return row


func _simple_line(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color(0.90, 0.93, 0.98, 1))
	return lbl


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
