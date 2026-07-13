extends Control

const POS_COLORS := {
	Player.Position.GK:  Color(0.55, 0.40, 0.02, 1),
	Player.Position.DEF: Color(0.05, 0.40, 0.15, 1),
	Player.Position.MID: Color(0.15, 0.20, 0.72, 1),
	Player.Position.FWD: Color(0.70, 0.15, 0.10, 1),
}

const SECTION_STARTER := "starter"
const SECTION_BENCH   := "bench"
const SECTION_OUT     := "out"

var _team: Team = null
var _selected_id: int = -1

## Touch-scroll manual (para Godot Web en móvil)
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
	%BtnBack.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/game/office/office.tscn"))
	$VBoxContainer/HeaderRow.visible = false
	$VBoxContainer/HSeparator2.visible = false
	_ensure_bench()
	_sanitize_lists()
	_build_list()


func _ensure_bench() -> void:
	if _team == null:
		return
	# Rellenar banco hasta 5 con jugadores que no estén ya en once ni banco
	for pid: int in _team.player_ids:
		if _team.bench.size() >= 5:
			break
		if not _team.starting_eleven.has(pid) and not _team.bench.has(pid):
			_team.bench.append(pid)


func _get_player_section(pid: int) -> String:
	if _team.starting_eleven.has(pid): return SECTION_STARTER
	if _team.bench.has(pid):           return SECTION_BENCH
	return SECTION_OUT


func _swap_players(id_a: int, id_b: int) -> void:
	# Anotar posiciones ANTES de tocar nada
	var a_si := _team.starting_eleven.find(id_a)
	var b_si := _team.starting_eleven.find(id_b)
	var a_bi := _team.bench.find(id_a)
	var b_bi := _team.bench.find(id_b)

	# Paso 1: colocar id_a en el hueco de id_b
	if b_si >= 0:
		_team.starting_eleven[b_si] = id_a
	elif b_bi >= 0:
		_team.bench[b_bi] = id_a
	# si b era "out", id_a pasa a "out" (su hueco se sobreescribe en paso 2)

	# Paso 2: colocar id_b en el hueco de id_a
	if a_si >= 0:
		_team.starting_eleven[a_si] = id_b
	elif a_bi >= 0:
		_team.bench[a_bi] = id_b
	# si a era "out", id_b pasa a "out" (su hueco ya se sobreescribió en paso 1)

	# Sanear duplicates por si hubiera datos corruptos previos
	_sanitize_lists()


## Elimina IDs duplicados o inválidos de starting_eleven y bench
func _sanitize_lists() -> void:
	var seen: Dictionary = {}
	var clean_si: Array[int] = []
	for pid: int in _team.starting_eleven:
		if pid > 0 and not seen.has(pid):
			seen[pid] = true
			clean_si.append(pid)
	_team.starting_eleven.assign(clean_si)

	var clean_bench: Array[int] = []
	for pid: int in _team.bench:
		if pid > 0 and not seen.has(pid):
			seen[pid] = true
			clean_bench.append(pid)
	_team.bench.assign(clean_bench)


func _on_player_clicked(pid: int) -> void:
	var section := _get_player_section(pid)

	if _selected_id == -1:
		# Añadir directamente al banco si hay hueco y viene de no convocados
		if section == SECTION_OUT and _team.bench.size() < 5:
			_team.bench.append(pid)
			_build_list()
			return
		_selected_id = pid
	elif _selected_id == pid:
		_selected_id = -1
	else:
		_swap_players(_selected_id, pid)
		_selected_id = -1
	_build_list()


func _build_list() -> void:
	if _team == null:
		return

	%TitleLabel.text = _team.name + " — Alineación"
	%CountLabel.text = "%d jugadores" % _team.player_ids.size()

	var list: VBoxContainer = %PlayerList
	for child in list.get_children():
		child.queue_free()

	# —— MEDIA DEL EQUIPO ——
	list.add_child(_make_team_average_bar())

	# —— 11 INICIAL ——
	list.add_child(_make_section_header("⚽  11 INICIAL", Color(0.10, 0.22, 0.10, 1), Color(0.4, 0.95, 0.5, 1)))
	list.add_child(_make_col_header(true))
	for i in range(_team.starting_eleven.size()):
		var p: Player = GameManager.get_player(_team.starting_eleven[i])
		if p:
			list.add_child(_make_row(p, SECTION_STARTER, i))

	# —— SUPLENTES ——
	# Mostrar hint de selección en curso en la sección Suplentes
	var bench_hint := "" if _selected_id == -1 else " — toca aquí para intercambiar"
	list.add_child(_make_section_header("🔄  SUPLENTES" + bench_hint, Color(0.08, 0.12, 0.24, 1), Color(0.5, 0.72, 1.0, 1)))
	list.add_child(_make_col_header(false))
	for i in range(_team.bench.size()):
		var p: Player = GameManager.get_player(_team.bench[i])
		if p:
			list.add_child(_make_row(p, SECTION_BENCH, i))

	# —— NO CONVOCADOS ——
	var out_ids: Array[int] = []
	for pid: int in _team.player_ids:
		if not _team.starting_eleven.has(pid) and not _team.bench.has(pid):
			out_ids.append(pid)
	out_ids.sort_custom(func(a: int, b: int) -> bool:
		var pa: Player = GameManager.get_player(a)
		var pb: Player = GameManager.get_player(b)
		if pa == null or pb == null: return false
		return int(pa.position) < int(pb.position)
	)
	var bench_full := _team.bench.size() >= 5
	var out_hint := " — toca para convocar" if not bench_full else " — toca otro para intercambiar"
	list.add_child(_make_section_header("❌  NO CONVOCADOS" + out_hint, Color(0.18, 0.10, 0.10, 1), Color(0.85, 0.45, 0.45, 1)))
	list.add_child(_make_col_header(false))
	for pid: int in out_ids:
		var p: Player = GameManager.get_player(pid)
		if p:
			list.add_child(_make_row(p, SECTION_OUT, -1))


## Barra de media del equipo titular
func _make_team_average_bar() -> Control:
	var starters: Array[Player] = []
	for pid: int in _team.starting_eleven:
		var p: Player = GameManager.get_player(pid)
		if p:
			starters.append(p)

	var avg_en := 0; var avg_ve := 0; var avg_re := 0
	var avg_ag := 0; var avg_ca := 0; var avg_me := 0
	if not starters.is_empty():
		for p: Player in starters:
			avg_en += clamp(p.energy, 1, 99)
			avg_ve += p.pace
			avg_re += p.physical
			avg_ag += p.defending
			avg_ca += p.get_ca()
			avg_me += p.get_me()
		var n := starters.size()
		avg_en = avg_en / n; avg_ve = avg_ve / n; avg_re = avg_re / n
		avg_ag = avg_ag / n; avg_ca = avg_ca / n; avg_me = avg_me / n

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 48)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.10, 0.18, 1)
	style.border_color = Color(0.3, 0.3, 0.5, 1)
	style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 0)
	panel.add_child(hbox)
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var lbl_title := Label.new()
	lbl_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_title.text = "  MEDIA 11 INICIAL"
	lbl_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_title.add_theme_font_size_override("font_size", 14)
	lbl_title.add_theme_color_override("font_color", Color(0.75, 0.75, 0.95, 1))
	hbox.add_child(lbl_title)

	var sep_col := Color(0.30, 0.30, 0.55, 1)
	for sv: Array in [[avg_en, 38], [avg_ve, 38], [avg_re, 38], [avg_ag, 38], [avg_ca, 38], [avg_me, 42]]:
		hbox.add_child(_vsep(sep_col))
		hbox.add_child(_stat_lbl(sv[0], sv[1]))

	return panel


## Cabecera de sección coloreada
func _make_section_header(title: String, bg: Color, fg: Color) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 40)
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(0)
	panel.add_theme_stylebox_override("panel", style)
	var lbl := Label.new()
	lbl.text = title
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", fg)
	lbl.add_theme_constant_override("margin_left", 14)
	panel.add_child(lbl)
	return panel


## Fila de cabecera de columnas
func _make_col_header(with_slot: bool) -> Control:
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

	var cols: Array
	if with_slot:
		cols = [["PUESTO", 80, true], ["POS", 40, true], ["NOMBRE", -1, false], ["EN", 38, true], ["VE", 38, true], ["RE", 38, true], ["AG", 38, true], ["CA", 38, true], ["ME", 42, true]]
	else:
		cols = [["#", 40, true], ["POS", 40, true], ["NOMBRE", -1, false], ["EN", 38, true], ["VE", 38, true], ["RE", 38, true], ["AG", 38, true], ["CA", 38, true], ["ME", 42, true]]
	for i in range(cols.size()):
		var c: Array = cols[i]
		if i > 0:
			hbox.add_child(_vsep(Color(0.35, 0.35, 0.60, 1)))
		var lbl := Label.new()
		if c[1] > 0:
			lbl.custom_minimum_size = Vector2(c[1], 0)
		else:
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.text = c[0]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if c[2] else HORIZONTAL_ALIGNMENT_LEFT
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.95, 1))
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(lbl)
	return root


## Etiqueta del puesto en el once según formación
func _get_slot_label(slot_idx: int) -> String:
	var parts := _team.formation.split("-")
	var defs := int(parts[0]) if parts.size() > 0 else 4
	var mids := int(parts[1]) if parts.size() > 1 else 4
	if slot_idx == 0: return "POR"
	if slot_idx <= defs: return "DEF %d" % slot_idx
	if slot_idx <= defs + mids: return "MED %d" % (slot_idx - defs)
	return "DEL %d" % (slot_idx - defs - mids)


## Color base de fila según sección y posición del jugador
func _row_base_color(p: Player, section: String) -> Color:
	if p.injured:   return Color(0.95, 0.70, 0.35, 1)
	if p.suspended: return Color(0.95, 0.55, 0.55, 1)
	match section:
		SECTION_STARTER:
			match p.position:
				Player.Position.GK:  return Color.html("fcfda4")
				Player.Position.DEF: return Color.html("d4f2d4")
				Player.Position.MID: return Color.html("c8cdfe")
				_:                   return Color.html("f6c2ae")   # FWD
		SECTION_BENCH:
			return Color.html("d2e0f9")
	return Color.html("a8bccc")  # OUT


## Fila de jugador (clickable para seleccionar/intercambiar)
func _make_row(p: Player, section: String, slot_idx: int) -> Control:
	var is_selected := (p.id == _selected_id)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 54)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.pressed.connect(_on_player_clicked.bind(p.id))

	var base := _row_base_color(p, section)
	var hover := base.lightened(0.08)

	var sn := StyleBoxFlat.new()
	var sh := StyleBoxFlat.new()
	sn.set_corner_radius_all(3)
	sh.set_corner_radius_all(3)
	sn.bg_color = base
	sh.bg_color = hover

	if is_selected:
		sn.border_color = Color(0, 0, 0, 1)
		sn.set_border_width_all(3)
		sh.border_color = Color(0, 0, 0, 1)
		sh.set_border_width_all(3)

	btn.add_theme_stylebox_override("normal",  sn)
	btn.add_theme_stylebox_override("hover",   sh)
	btn.add_theme_stylebox_override("pressed", sh)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 0)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(hbox)
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Primera columna: puesto en formación (titulares) o número de camiseta
	var sep_c := Color(0.0, 0.0, 0.0, 0.28)
	if section == SECTION_STARTER:
		var lbl := Label.new()
		lbl.custom_minimum_size = Vector2(80, 0)
		lbl.text = _get_slot_label(slot_idx)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15, 1))
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(lbl)
	else:
		var lbl := Label.new()
		lbl.custom_minimum_size = Vector2(40, 0)
		lbl.text = str(p.number)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 15)
		lbl.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2, 1))
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(lbl)

	hbox.add_child(_vsep(sep_c))

	# Posición natural
	var lbl_pos := Label.new()
	lbl_pos.custom_minimum_size = Vector2(40, 0)
	lbl_pos.text = p.get_position_abbr()
	lbl_pos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_pos.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl_pos.add_theme_font_size_override("font_size", 14)
	lbl_pos.add_theme_color_override("font_color", POS_COLORS.get(p.position, Color.WHITE))
	lbl_pos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(lbl_pos)
	hbox.add_child(_vsep(sep_c))

	# Nombre + badges
	var name_hbox := HBoxContainer.new()
	name_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_hbox.add_theme_constant_override("separation", 4)
	name_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var lbl_name := Label.new()
	lbl_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_name.text = p.full_name
	lbl_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_name.add_theme_font_size_override("font_size", 16)
	lbl_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if p.injured:
		lbl_name.add_theme_color_override("font_color", Color(0.55, 0.22, 0.0, 1))
	elif p.suspended:
		lbl_name.add_theme_color_override("font_color", Color(0.55, 0.05, 0.05, 1))
	else:
		lbl_name.add_theme_color_override("font_color", Color(0.08, 0.08, 0.08, 1))
	name_hbox.add_child(lbl_name)

	if p.injured:
		var b := Label.new()
		b.text = "🩹×%d" % p.injury_weeks
		b.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		b.add_theme_font_size_override("font_size", 12)
		b.add_theme_color_override("font_color", Color(0.55, 0.22, 0.0, 1))
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_hbox.add_child(b)
	elif p.suspended:
		var b := Label.new()
		b.text = "🚫"
		b.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		b.add_theme_font_size_override("font_size", 15)
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_hbox.add_child(b)
	elif p.yellow_cards > 0:
		var b := Label.new()
		b.text = "🟨×%d" % p.yellow_cards
		b.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		b.add_theme_font_size_override("font_size", 12)
		b.add_theme_color_override("font_color",
			Color(0.60, 0.30, 0.0, 1) if p.yellow_cards >= 4 else Color(0.45, 0.38, 0.0, 1))
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_hbox.add_child(b)
	hbox.add_child(name_hbox)

	# Stats: EN VE RE AG CA ME
	var en_val: int = clamp(p.energy, 1, 99)
	for stat_pair: Array in [
		[en_val,        38],
		[p.pace,        38],
		[p.physical,    38],
		[p.defending,   38],
		[p.get_ca(),    38],
		[p.get_me(),    42],
	]:
		hbox.add_child(_vsep(sep_c))
		hbox.add_child(_stat_lbl(stat_pair[0], stat_pair[1]))

	return btn


func _stat_lbl(val: int, width: int) -> Label:
	var lbl := Label.new()
	lbl.custom_minimum_size = Vector2(width, 0)
	lbl.text = str(val)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color",
		Color(0.05, 0.40, 0.10, 1) if val >= 70 else
		Color(0.45, 0.35, 0.00, 1) if val >= 40 else
		Color(0.60, 0.10, 0.05, 1))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


func _vsep(col: Color) -> Control:
	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(2, 0)
	sep.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sep.color = col
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return sep
