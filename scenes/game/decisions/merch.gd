extends Control
class_name MerchScreen

# Coste por tienda extra y su ingreso semanal adicional
const STORE_COST:   int = 500_000
const STORE_INCOME: int = 25_000
const MAX_STORES:   int = 3

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

	var title_lbl := Label.new()
	title_lbl.text = "🏪  MERCHANDISING"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	title_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_lbl.add_theme_font_size_override("font_size", 24)
	title_lbl.add_theme_color_override("font_color", Color.WHITE)
	header.add_child(title_lbl)

	# Contenido con scroll
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   48)
	margin.add_theme_constant_override("margin_right",  48)
	margin.add_theme_constant_override("margin_top",    32)
	margin.add_theme_constant_override("margin_bottom", 32)
	scroll.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 20)
	margin.add_child(vbox)

	var team := GameManager.get_player_team()
	_build_content(vbox, team)

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


func _build_content(vbox: VBoxContainer, team: Team) -> void:
	# Panel resumen actual
	var summary := _make_summary(team)
	vbox.add_child(summary)

	# Título sección
	var sec_lbl := Label.new()
	sec_lbl.text = "Tiendas adicionales del club"
	sec_lbl.add_theme_font_size_override("font_size", 16)
	sec_lbl.add_theme_color_override("font_color", Color(0.80, 0.85, 0.90))
	vbox.add_child(sec_lbl)

	# Tres slots de tiendas
	for i in range(MAX_STORES):
		vbox.add_child(_make_store_slot(i + 1, team))

	# Nota informativa
	var note := Label.new()
	note.text = "Cada tienda adicional genera %s € por semana en concepto de ventas de camisetas, bufandas y accesorios del club. La tienda del estadio ya está incluida en los ingresos base." % _fmt(STORE_INCOME)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 13)
	note.add_theme_color_override("font_color", Color(0.60, 0.63, 0.68))
	vbox.add_child(note)


func _make_summary(team: Team) -> PanelContainer:
	var pc := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.14, 0.20)
	style.corner_radius_top_left     = 6
	style.corner_radius_top_right    = 6
	style.corner_radius_bottom_left  = 6
	style.corner_radius_bottom_right = 6
	pc.add_theme_stylebox_override("panel", style)

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left",  24)
	m.add_theme_constant_override("margin_right", 24)
	m.add_theme_constant_override("margin_top",   18)
	m.add_theme_constant_override("margin_bottom",18)
	pc.add_child(m)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	m.add_child(vb)

	var title := Label.new()
	title.text = "Resumen actual"
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(0.75, 0.80, 0.88))
	vb.add_child(title)

	var base_weekly: int = [0, 3_000, 8_000, 18_000, 40_000][clampi(team.shop_level, 0, 4)]
	var extra_weekly: int = team.merch_stores * STORE_INCOME
	var total_weekly: int = base_weekly + extra_weekly

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 6)
	vb.add_child(grid)

	_add_stat(grid, "Tiendas adicionales:", "%d / %d" % [team.merch_stores, MAX_STORES])
	_add_stat(grid, "Tienda del estadio (nivel %d):" % team.shop_level, "%s €/sem" % _fmt(base_weekly))
	_add_stat(grid, "Tiendas adicionales:", "%s €/sem" % _fmt(extra_weekly))
	_add_stat(grid, "Total merchandising:", "%s €/sem" % _fmt(total_weekly))

	return pc


func _add_stat(grid: GridContainer, key: String, value: String) -> void:
	var k := Label.new()
	k.text = key
	k.add_theme_font_size_override("font_size", 13)
	k.add_theme_color_override("font_color", Color(0.72, 0.75, 0.80))
	grid.add_child(k)

	var v := Label.new()
	v.text = value
	v.add_theme_font_size_override("font_size", 13)
	v.add_theme_color_override("font_color", Color.WHITE)
	grid.add_child(v)


func _make_store_slot(slot: int, team: Team) -> PanelContainer:
	var owned: bool = team.merch_stores >= slot
	var is_next: bool = (team.merch_stores == slot - 1)

	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	if owned:
		style.bg_color     = Color(0.13, 0.22, 0.16)
		style.border_color = Color(0.25, 0.65, 0.35)
	elif is_next:
		style.bg_color     = Color(0.13, 0.16, 0.22)
		style.border_color = Color(0.55, 0.45, 0.10)
	else:
		style.bg_color     = Color(0.09, 0.10, 0.13)
		style.border_color = Color(0.22, 0.24, 0.28)
	style.set_border_width_all(2)
	style.corner_radius_top_left     = 6
	style.corner_radius_top_right    = 6
	style.corner_radius_bottom_left  = 6
	style.corner_radius_bottom_right = 6
	card.add_theme_stylebox_override("panel", style)
	card.custom_minimum_size = Vector2(0, 80)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 0)
	card.add_child(hbox)

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left",  24)
	m.add_theme_constant_override("margin_top",   16)
	m.add_theme_constant_override("margin_bottom",16)
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(m)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	m.add_child(vb)

	var name_lbl := Label.new()
	if owned:
		name_lbl.text = "🏪 Tienda adicional #%d  (ABIERTA)" % slot
		name_lbl.add_theme_color_override("font_color", Color(0.50, 1.00, 0.60))
	elif is_next:
		name_lbl.text = "🏪 Tienda adicional #%d" % slot
		name_lbl.add_theme_color_override("font_color", Color.WHITE)
	else:
		name_lbl.text = "🔒 Tienda adicional #%d  (abre con tienda %d primero)" % [slot, slot - 1]
		name_lbl.add_theme_color_override("font_color", Color(0.45, 0.47, 0.50))
	name_lbl.add_theme_font_size_override("font_size", 16)
	vb.add_child(name_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "+%s €/semana" % _fmt(STORE_INCOME)
	sub_lbl.add_theme_font_size_override("font_size", 13)
	sub_lbl.add_theme_color_override("font_color", Color(0.65, 0.90, 0.70) if (owned or is_next) else Color(0.40, 0.42, 0.45))
	vb.add_child(sub_lbl)

	# Botón
	var btn_m := MarginContainer.new()
	btn_m.add_theme_constant_override("margin_right", 20)
	btn_m.add_theme_constant_override("margin_top",   18)
	btn_m.add_theme_constant_override("margin_bottom",18)
	hbox.add_child(btn_m)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(140, 0)
	if owned:
		btn.text = "✓ Adquirida"
		btn.disabled = true
	elif not is_next:
		btn.text = "Bloqueada"
		btn.disabled = true
	elif team.club_cash < STORE_COST:
		btn.text = "Fondos insuf."
		btn.disabled = true
	else:
		btn.text = "Abrir (%s €)" % _fmt(STORE_COST)
		btn.disabled = false
		btn.pressed.connect(_on_buy.bind(team))
	btn_m.add_child(btn)

	return card


func _on_buy(team: Team) -> void:
	if team.club_cash < STORE_COST:
		return
	team.club_cash   -= STORE_COST
	team.merch_stores += 1
	get_tree().change_scene_to_file("res://scenes/game/decisions/merch.tscn")


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
