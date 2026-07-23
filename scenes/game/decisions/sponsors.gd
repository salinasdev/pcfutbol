extends Control
class_name SponsorsScreen

const ICON_HANDSHAKE := preload("res://assets/ui/icons/handshake.png")

# Patrocinadores disponibles — precio semanal escala con la reputación del equipo
const SPONSORS: Array[Dictionary] = [
	{"id": 1, "name": "SportMax",    "sector": "Equipación deportiva",
	 "base_weekly": 1_500,  "weeks": 26, "min_rep": 20,
	 "color": Color(0.25, 0.45, 0.75), "desc": "Marca líder de ropa deportiva."},
	{"id": 2, "name": "TurboEnergy", "sector": "Bebidas energéticas",
	 "base_weekly": 2_000,  "weeks": 26, "min_rep": 30,
	 "color": Color(0.70, 0.60, 0.10), "desc": "La energía que necesitas en el campo."},
	{"id": 3, "name": "BetPlay",     "sector": "Apuestas deportivas",
	 "base_weekly": 4_000,  "weeks": 26, "min_rep": 40,
	 "color": Color(0.50, 0.15, 0.60), "desc": "Plataforma de apuestas deportivas online."},
	{"id": 4, "name": "MegaBank",    "sector": "Banca y finanzas",
	 "base_weekly": 5_500,  "weeks": 52, "min_rep": 50,
	 "color": Color(0.10, 0.35, 0.65), "desc": "Tu banco de confianza para el futuro."},
	{"id": 5, "name": "VitaFresh",   "sector": "Alimentación y nutrición",
	 "base_weekly": 3_000,  "weeks": 26, "min_rep": 35,
	 "color": Color(0.20, 0.65, 0.35), "desc": "Nutrición de alto rendimiento para campeones."},
	{"id": 6, "name": "AutoDrive",   "sector": "Automoción",
	 "base_weekly": 7_000,  "weeks": 52, "min_rep": 60,
	 "color": Color(0.60, 0.25, 0.15), "desc": "Coches premium para quienes van más lejos."},
	{"id": 7, "name": "TechNova",    "sector": "Tecnología",
	 "base_weekly": 9_000,  "weeks": 52, "min_rep": 70,
	 "color": Color(0.15, 0.55, 0.65), "desc": "Innovación tecnológica al servicio del deporte."},
	{"id": 8, "name": "AirComfort",  "sector": "Aerolíneas",
	 "base_weekly": 12_000, "weeks": 52, "min_rep": 80,
	 "color": Color(0.30, 0.30, 0.80), "desc": "Vuela a lo grande con el club de tu vida."},
]

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
	title_icon.texture = ICON_HANDSHAKE
	title_icon.custom_minimum_size = Vector2(24, 24)
	title_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	title_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title_row.add_child(title_icon)
	var title_lbl := Label.new()
	title_lbl.text = "PATROCINADORES"
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 24)
	title_lbl.add_theme_color_override("font_color", Color.WHITE)
	title_row.add_child(title_lbl)

	var team := GameManager.get_player_team()
	root.add_child(_make_info_bar(team))

	# Ofertas
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

	for sp in SPONSORS:
		vbox.add_child(_make_row(sp, team))

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
	if team.sponsor_weeks_left > 0:
		var sp_name := _sponsor_name(team.sponsor_id)
		lbl.text = "Patrocinador actual: %s  |  %s €/semana  |  %d semanas restantes" % [
			sp_name, _fmt(team.sponsor_weekly_income), team.sponsor_weeks_left]
		lbl.add_theme_color_override("font_color", Color(0.60, 1.00, 0.65))
	else:
		lbl.text = "Sin patrocinador activo. Reputación del club: %d / 100" % team.reputation
		lbl.add_theme_color_override("font_color", Color(0.85, 0.75, 0.40))
	lbl.add_theme_font_size_override("font_size", 14)
	m.add_child(lbl)
	return pc


func _sponsor_name(sid: int) -> String:
	for sp in SPONSORS:
		if sp["id"] == sid:
			return sp["name"]
	return "Desconocido"


func _make_row(sp: Dictionary, team: Team) -> PanelContainer:
	var weekly: int = int(sp["base_weekly"] * (0.5 + team.reputation / 100.0))
	var unlocked: bool = team.reputation >= sp["min_rep"]
	var active: bool   = (team.sponsor_id == sp["id"] and team.sponsor_weeks_left > 0)

	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.16, 0.22) if unlocked else Color(0.09, 0.10, 0.14)
	style.border_color = sp["color"] if unlocked else Color(0.25, 0.27, 0.30)
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
	name_lbl.text = sp["name"] + "  •  " + sp["sector"]
	name_lbl.add_theme_font_size_override("font_size", 17)
	name_lbl.add_theme_color_override("font_color", Color.WHITE if unlocked else Color(0.50, 0.52, 0.55))
	vb.add_child(name_lbl)

	var money_lbl := Label.new()
	money_lbl.text = "%s €/semana  ·  %d semanas  →  Total: %s €" % [
		_fmt(weekly), sp["weeks"], _fmt(weekly * sp["weeks"])]
	money_lbl.add_theme_font_size_override("font_size", 13)
	money_lbl.add_theme_color_override("font_color", Color(0.65, 0.95, 0.70) if unlocked else Color(0.45, 0.47, 0.50))
	vb.add_child(money_lbl)

	var desc_lbl := Label.new()
	if unlocked:
		desc_lbl.text = sp["desc"]
	else:
		desc_lbl.text = "Requiere reputación %d (actual: %d)" % [sp["min_rep"], team.reputation]
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.68, 0.72, 0.78) if unlocked else Color(0.50, 0.30, 0.30))
	vb.add_child(desc_lbl)

	# Botón
	var btn_m := MarginContainer.new()
	btn_m.add_theme_constant_override("margin_right", 16)
	btn_m.add_theme_constant_override("margin_top",   20)
	btn_m.add_theme_constant_override("margin_bottom",20)
	hbox.add_child(btn_m)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(120, 0)
	if active:
		btn.text = "✓ Activo"
		btn.disabled = true
	elif not unlocked:
		btn.text = "Bloqueado"
		btn.disabled = true
	else:
		btn.text = "Firmar"
		btn.disabled = false
		btn.pressed.connect(_on_sign.bind(sp, weekly))
	btn_m.add_child(btn)

	return card


func _on_sign(sp: Dictionary, weekly: int) -> void:
	var team := GameManager.get_player_team()
	if team == null:
		return
	team.sponsor_id            = sp["id"]
	team.sponsor_weeks_left    = sp["weeks"]
	team.sponsor_weekly_income = weekly
	get_tree().change_scene_to_file("res://scenes/game/decisions/sponsors.tscn")


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
