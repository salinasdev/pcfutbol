extends Control

var _active_filter: int = -1   # -1 = todo


func _ready() -> void:
	%BtnBack.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/game/office/office.tscn"))
	%WeekLabel.text = "Semana %d" % GameManager.current_week

	%FilterAll.pressed.connect(func(): _set_filter(-1))
	%FilterResults.pressed.connect(func(): _set_filter(NewsManager.Category.RESULTADO))
	%FilterTransfers.pressed.connect(func(): _set_filter(NewsManager.Category.FICHAJES))
	%FilterInterview.pressed.connect(func(): _set_filter(NewsManager.Category.ENTREVISTA))
	%FilterTabloid.pressed.connect(func(): _set_filter(NewsManager.Category.TABLOID))

	_build_feed()


func _set_filter(cat: int) -> void:
	_active_filter = cat
	# Mantener solo un botón activo
	%FilterAll.button_pressed       = (cat == -1)
	%FilterResults.button_pressed   = (cat == NewsManager.Category.RESULTADO)
	%FilterTransfers.button_pressed = (cat == NewsManager.Category.FICHAJES)
	%FilterInterview.button_pressed = (cat == NewsManager.Category.ENTREVISTA)
	%FilterTabloid.button_pressed   = (cat == NewsManager.Category.TABLOID)
	_build_feed()


func _build_feed() -> void:
	var feed: VBoxContainer = %NewsFeed
	for child in feed.get_children():
		child.queue_free()

	if NewsManager.news_feed.is_empty():
		var lbl := Label.new()
		lbl.text = "Aún no hay noticias. Avanza la semana para generar contenido."
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 17)
		lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
		feed.add_child(lbl)
		return

	var shown := 0
	for item: Dictionary in NewsManager.news_feed:
		if _active_filter != -1 and item["category"] != _active_filter:
			continue
		feed.add_child(_make_card(item))
		shown += 1

	if shown == 0:
		var lbl := Label.new()
		lbl.text = "No hay noticias en esta categoría."
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 17)
		lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
		feed.add_child(lbl)


func _make_card(item: Dictionary) -> Control:
	var panel := PanelContainer.new()

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.10, 0.11, 0.15, 1)
	bg.set_corner_radius_all(6)
	bg.border_width_left   = 4
	bg.border_width_right  = 0
	bg.border_width_top    = 0
	bg.border_width_bottom = 0
	bg.border_color = item.get("cat_color", Color.WHITE)
	panel.add_theme_stylebox_override("panel", bg)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	# Fila superior: badge de categoría + semana
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	vbox.add_child(top_row)

	var lbl_cat := Label.new()
	lbl_cat.text = item.get("cat_label", "")
	lbl_cat.add_theme_font_size_override("font_size", 13)
	lbl_cat.add_theme_color_override("font_color", item.get("cat_color", Color.WHITE))
	top_row.add_child(lbl_cat)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(spacer)

	var lbl_week := Label.new()
	lbl_week.text = "Semana %d" % item.get("week", 0)
	lbl_week.add_theme_font_size_override("font_size", 12)
	lbl_week.add_theme_color_override("font_color", Color(0.45, 0.45, 0.55, 1))
	top_row.add_child(lbl_week)

	# Titular
	var lbl_headline := Label.new()
	lbl_headline.text = item.get("headline", "")
	lbl_headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_headline.add_theme_font_size_override("font_size", 17)
	lbl_headline.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95, 1))
	vbox.add_child(lbl_headline)

	# Cuerpo (desplegable al pulsar)
	var lbl_body := Label.new()
	lbl_body.text = item.get("body", "")
	lbl_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_body.add_theme_font_size_override("font_size", 15)
	lbl_body.add_theme_color_override("font_color", Color(0.7, 0.72, 0.78, 1))
	lbl_body.visible = false
	vbox.add_child(lbl_body)

	# Botón expandir
	var btn_expand := Button.new()
	btn_expand.text = "▼ Leer más"
	btn_expand.flat = true
	btn_expand.add_theme_font_size_override("font_size", 13)
	btn_expand.add_theme_color_override("font_color", item.get("cat_color", Color.WHITE))
	btn_expand.pressed.connect(func():
		lbl_body.visible = not lbl_body.visible
		btn_expand.text = "▲ Cerrar" if lbl_body.visible else "▼ Leer más"
	)
	vbox.add_child(btn_expand)

	return panel
