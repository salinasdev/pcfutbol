extends Control
class_name DecisionsHub

const ICON_BOARD := preload("res://assets/ui/icons/goal.png")
const ICON_TV := preload("res://assets/ui/icons/tv.png")
const ICON_STORE := preload("res://assets/ui/icons/store.png")
const ICON_HANDSHAKE := preload("res://assets/ui/icons/handshake.png")

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# Fondo oscuro
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.10, 0.14)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	# Cabecera
	var header := ColorRect.new()
	header.color = Color(0.05, 0.07, 0.10)
	header.custom_minimum_size = Vector2(0, 70)
	root.add_child(header)

	var title_lbl := Label.new()
	title_lbl.text = "DECISIONES"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	title_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_lbl.add_theme_font_size_override("font_size", 26)
	title_lbl.add_theme_color_override("font_color", Color.WHITE)
	header.add_child(title_lbl)

	# Contenido
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 16)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   32)
	margin.add_theme_constant_override("margin_right",  32)
	margin.add_theme_constant_override("margin_top",    32)
	margin.add_theme_constant_override("margin_bottom", 32)
	scroll.add_child(margin)
	margin.add_child(vbox)

	var items: Array[Dictionary] = [
		{"label": "Junta Directiva",  "desc": "Objetivos de temporada, confianza de la junta y bonus de rendimiento.",
		 "icon": ICON_BOARD,
		 "scene": "res://scenes/game/decisions/board.tscn",              "color": Color(0.20, 0.35, 0.55)},
		{"label": "Ofertas de TV",    "desc": "Negocia contratos televisivos y asegura ingresos semanales.",
		 "icon": ICON_TV,
		 "scene": "res://scenes/game/decisions/tv_deals.tscn",           "color": Color(0.18, 0.40, 0.30)},
		{"label": "Merchandising",    "desc": "Abre nuevas tiendas del club y aumenta los ingresos de merchandising.",
		 "icon": ICON_STORE,
		 "scene": "res://scenes/game/decisions/merch.tscn",              "color": Color(0.45, 0.28, 0.10)},
		{"label": "Patrocinadores",   "desc": "Firma acuerdos de patrocinio con marcas para obtener ingresos regulares.",
		 "icon": ICON_HANDSHAKE,
		 "scene": "res://scenes/game/decisions/sponsors.tscn",           "color": Color(0.38, 0.18, 0.42)},
	]

	for item in items:
		vbox.add_child(_make_card(item["label"], item["desc"], item["scene"], item["color"], item["icon"]))

	# Botón volver
	var footer := MarginContainer.new()
	footer.add_theme_constant_override("margin_left",  32)
	footer.add_theme_constant_override("margin_right", 32)
	footer.add_theme_constant_override("margin_bottom", 20)
	root.add_child(footer)

	var btn_back := Button.new()
	btn_back.text = "← Volver al Despacho"
	btn_back.custom_minimum_size = Vector2(0, 44)
	btn_back.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/game/office/office.tscn"))
	footer.add_child(btn_back)


func _make_card(label: String, desc: String, scene: String, accent: Color, icon_tex: Texture2D) -> PanelContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color       = Color(0.13, 0.16, 0.22)
	style.border_color   = accent
	style.set_border_width_all(0)
	style.border_width_left = 5
	style.corner_radius_top_left     = 6
	style.corner_radius_top_right    = 6
	style.corner_radius_bottom_left  = 6
	style.corner_radius_bottom_right = 6
	card.add_theme_stylebox_override("panel", style)
	card.custom_minimum_size = Vector2(0, 90)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	card.add_child(hbox)

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left",  20)
	pad.add_theme_constant_override("margin_right", 16)
	pad.add_theme_constant_override("margin_top",   16)
	pad.add_theme_constant_override("margin_bottom",16)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(pad)

	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", 4)
	pad.add_child(texts)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	if icon_tex != null:
		var icon := TextureRect.new()
		icon.texture = icon_tex
		icon.custom_minimum_size = Vector2(20, 20)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		title_row.add_child(icon)
	texts.add_child(title_row)

	var lbl := Label.new()
	lbl.text = label
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	title_row.add_child(lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = desc
	desc_lbl.add_theme_font_size_override("font_size", 13)
	desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.78, 0.82))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(desc_lbl)

	var btn := Button.new()
	btn.text = "Entrar →"
	btn.custom_minimum_size = Vector2(120, 0)
	var mpad := MarginContainer.new()
	mpad.add_theme_constant_override("margin_right", 16)
	mpad.add_theme_constant_override("margin_top",   16)
	mpad.add_theme_constant_override("margin_bottom",16)
	mpad.add_child(btn)
	hbox.add_child(mpad)

	btn.pressed.connect(func():
		get_tree().change_scene_to_file(scene))

	return card
