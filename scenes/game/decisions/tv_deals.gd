extends Control
class_name TvDealsScreen

const ICON_TV := preload("res://assets/ui/icons/tv.png")

const DEALS: Array[Dictionary] = [
	{"name": "Canal Local",  "weekly": 500,    "weeks": 26, "tier": 1,
	 "desc": "Cobertura regional básica. Contrato de media temporada.",      "color": Color(0.25, 0.45, 0.65)},
	{"name": "TeleFútbol",   "weekly": 2_000,  "weeks": 26, "tier": 2,
	 "desc": "Cadena nacional de fútbol. Audiencia moderada.",               "color": Color(0.20, 0.55, 0.40)},
	{"name": "SportTV",      "weekly": 5_000,  "weeks": 52, "tier": 3,
	 "desc": "Canal deportivo premium. Retransmisión de partidos en vivo.",  "color": Color(0.70, 0.45, 0.10)},
	{"name": "EuroStream",   "weekly": 12_000, "weeks": 52, "tier": 4,
	 "desc": "Plataforma internacional. Audiencia millonaria en Europa.",    "color": Color(0.60, 0.20, 0.70)},
]

var _rows: Array[Control] = []

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
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

	var title_row := HBoxContainer.new()
	title_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 10)
	header.add_child(title_row)
	var title_icon := TextureRect.new()
	title_icon.texture = ICON_TV
	title_icon.custom_minimum_size = Vector2(24, 24)
	title_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	title_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title_row.add_child(title_icon)
	var title_lbl := Label.new()
	title_lbl.text = "OFERTAS DE TV"
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 24)
	title_lbl.add_theme_color_override("font_color", Color.WHITE)
	title_row.add_child(title_lbl)

	# Info contrato actual
	var team := GameManager.get_player_team()
	var info_panel := _make_info_bar(team)
	root.add_child(info_panel)

	# Lista de ofertas
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   32)
	margin.add_theme_constant_override("margin_right",  32)
	margin.add_theme_constant_override("margin_top",    24)
	margin.add_theme_constant_override("margin_bottom", 24)
	scroll.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	for deal in DEALS:
		var row := _make_deal_row(deal, team)
		vbox.add_child(row)
		_rows.append(row)

	# Botón volver
	var footer := MarginContainer.new()
	footer.add_theme_constant_override("margin_left",   32)
	footer.add_theme_constant_override("margin_right",  32)
	footer.add_theme_constant_override("margin_bottom", 20)
	root.add_child(footer)

	var btn_back := Button.new()
	btn_back.text = "← Volver a Decisiones"
	btn_back.custom_minimum_size = Vector2(0, 44)
	btn_back.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/game/decisions/decisions_hub.tscn"))
	footer.add_child(btn_back)


func _make_info_bar(team: Team) -> PanelContainer:
	var pc := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.14, 0.20)
	pc.add_theme_stylebox_override("panel", style)

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left",  24)
	m.add_theme_constant_override("margin_right", 24)
	m.add_theme_constant_override("margin_top",   12)
	m.add_theme_constant_override("margin_bottom",12)
	pc.add_child(m)

	var lbl := Label.new()
	if team.tv_deal_weeks_left > 0:
		lbl.text = "Contrato actual: %s  |  %s €/semana  |  %d semanas restantes" % [
			_tier_name(team.tv_deal_tier),
			_fmt(team.tv_weekly_income),
			team.tv_deal_weeks_left,
		]
		lbl.add_theme_color_override("font_color", Color(0.60, 1.00, 0.65))
	else:
		lbl.text = "Sin contrato televisivo activo. Firma uno para obtener ingresos semanales."
		lbl.add_theme_color_override("font_color", Color(0.85, 0.75, 0.40))
	lbl.add_theme_font_size_override("font_size", 14)
	m.add_child(lbl)
	return pc


func _tier_name(tier: int) -> String:
	var names := ["—", "Canal Local", "TeleFútbol", "SportTV", "EuroStream"]
	return names[clampi(tier, 0, 4)]


func _make_deal_row(deal: Dictionary, team: Team) -> PanelContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.16, 0.22)
	style.border_color = deal["color"]
	style.set_border_width_all(0)
	style.border_width_left = 5
	style.corner_radius_top_left     = 5
	style.corner_radius_top_right    = 5
	style.corner_radius_bottom_left  = 5
	style.corner_radius_bottom_right = 5
	card.add_theme_stylebox_override("panel", style)
	card.custom_minimum_size = Vector2(0, 96)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	card.add_child(hbox)

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left",  20)
	m.add_theme_constant_override("margin_top",   14)
	m.add_theme_constant_override("margin_bottom",14)
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(m)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	m.add_child(vb)

	var name_lbl := Label.new()
	name_lbl.text = deal["name"]
	name_lbl.add_theme_font_size_override("font_size", 17)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	vb.add_child(name_lbl)

	var money_lbl := Label.new()
	money_lbl.text = "%s €/semana  ·  %d semanas  →  Total: %s €" % [
		_fmt(deal["weekly"]), deal["weeks"], _fmt(deal["weekly"] * deal["weeks"])]
	money_lbl.add_theme_font_size_override("font_size", 13)
	money_lbl.add_theme_color_override("font_color", Color(0.65, 0.95, 0.70))
	vb.add_child(money_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = deal["desc"]
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.68, 0.72, 0.78))
	vb.add_child(desc_lbl)

	# Botón firmar
	var btn_m := MarginContainer.new()
	btn_m.add_theme_constant_override("margin_right", 16)
	btn_m.add_theme_constant_override("margin_top",   20)
	btn_m.add_theme_constant_override("margin_bottom",20)
	hbox.add_child(btn_m)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(120, 0)
	var active: bool = (team.tv_deal_tier == deal["tier"] and team.tv_deal_weeks_left > 0)
	if active:
		btn.text = "✓ Activo"
		btn.disabled = true
	elif team.tv_deal_weeks_left > 0 and team.tv_deal_tier != deal["tier"]:
		btn.text = "Firmar"
		btn.disabled = false
	else:
		btn.text = "Firmar"
		btn.disabled = false
	btn.pressed.connect(_on_sign_deal.bind(deal))
	btn_m.add_child(btn)

	return card


func _on_sign_deal(deal: Dictionary) -> void:
	var team := GameManager.get_player_team()
	if team == null:
		return
	team.tv_deal_tier      = deal["tier"]
	team.tv_deal_weeks_left = deal["weeks"]
	team.tv_weekly_income  = deal["weekly"]
	# Recargar la escena para reflejar cambios
	get_tree().change_scene_to_file("res://scenes/game/decisions/tv_deals.tscn")


func _fmt(n: int) -> String:
	var s := str(n)
	var out := ""
	var cnt := 0
	for i: int in range(s.length() - 1, -1, -1):
		if cnt > 0 and cnt % 3 == 0:
			out = "." + out
		out = s[i] + out
		cnt += 1
	return out
