extends Control

const ICON_BACK := preload("res://assets/ui/icons/back-white.png")
const ICON_GOAL := preload("res://assets/ui/icons/goal.png")
const ICON_YELLOW := preload("res://assets/ui/icons/yellow-card.png")
const ICON_RED := preload("res://assets/ui/icons/red-card.png")
const ICON_SIZE_NAV := 28

# Colores estilo PC Fútbol 6.0
const C_POS_BG   := Color(0.706, 0.784, 0.863, 1)  # #b4c8dc
const C_POS_FG   := Color(0.0,   0.0,   0.502, 1)  # #000080
const C_TEAM_BG  := Color(0.0,   0.0,   0.502, 1)  # #000080
const C_TEAM_FG  := Color(0.875, 0.875, 0.937, 1)  # #dfdfef
const C_PTS_BG   := Color(0.282, 0.118, 0.008, 1)  # #481e02
const C_PTS_FG   := Color(1.0,   0.875, 0.0,   1)  # #ffdf00
const C_PJ_BG    := Color(0.863, 0.863, 0.863, 1)  # #dcdcdc
const C_PJ_FG    := Color(0.537, 0.537, 0.537, 1)  # #898989
const C_PG_BG    := Color(0.706, 0.784, 0.863, 1)  # #b4c8dc
const C_PG_FG    := Color(0.357, 0.396, 0.435, 1)  # #5b656f
const C_PE_BG    := Color(0.831, 0.875, 0.667, 1)  # #d4dfaa
const C_PE_FG    := Color(0.537, 0.655, 0.373, 1)  # #89a75f
const C_PP_BG    := Color(0.831, 0.749, 0.667, 1)  # #d4bfaa
const C_PP_FG    := Color(0.671, 0.502, 0.337, 1)  # #ab8056
const C_GF_BG    := Color(0.706, 0.784, 0.863, 1)  # #b4c8dc
const C_GF_FG    := Color(0.475, 0.553, 0.631, 1)  # #798da1
const C_GC_BG    := Color(0.831, 0.749, 0.667, 1)  # #d4bfaa
const C_GC_FG    := Color(0.682, 0.522, 0.365, 1)  # #ae855d


func _ready() -> void:
	%BtnBack.icon = ICON_BACK
	%BtnBack.add_theme_constant_override("icon_max_width", ICON_SIZE_NAV)
	%BtnBack.text = ""
	%BtnBack.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/game/office/office.tscn"))
	_build_league_picker()
	%LeaguePicker.item_selected.connect(func(idx: int): _load_league(idx))
	if not GameManager.leagues.is_empty():
		_load_league(0)


func _build_league_picker() -> void:
	var picker: OptionButton = %LeaguePicker
	picker.clear()
	for league: League in GameManager.leagues.values():
		picker.add_item(league.name)


func _load_league(idx: int) -> void:
	var league: League = GameManager.leagues.values()[idx] as League
	if league == null:
		return
	%TitleLabel.text = league.name
	_build_table(league)


func _build_table(league: League) -> void:
	var list: VBoxContainer = %StandingsList
	for child in list.get_children():
		child.queue_free()

	list.add_child(_make_header())

	var standings := LeagueManager.get_standings(league)
	var player_tid := GameManager.player_team_id
	var n := standings.size()

	for i in range(n):
		var t: Team = standings[i]
		list.add_child(_make_row(i + 1, t, n, player_tid))

	# ── Rankings de jugadores ──────────────────────────────────────────────────
	list.add_child(_make_spacer(12))
	list.add_child(_make_stats_block(league))


func _make_spacer(height: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c


## Recoge todos los jugadores de la liga y devuelve los tres rankings
func _make_stats_block(league: League) -> Control:
	# Recopilar jugadores de la liga
	var players: Array[Player] = []
	for tid: int in league.team_ids:
		var t: Team = GameManager.get_team(tid)
		if t == null:
			continue
		for pid: int in t.player_ids:
			var p: Player = GameManager.get_player(pid)
			if p:
				players.append(p)

	# Top goleadores
	var scorers := players.duplicate()
	scorers.sort_custom(func(a: Player, b: Player) -> bool: return a.season_goals > b.season_goals)
	scorers = scorers.slice(0, 10)

	# Top amarillas
	var yellows := players.duplicate()
	yellows.sort_custom(func(a: Player, b: Player) -> bool: return a.yellow_cards > b.yellow_cards)
	yellows = yellows.slice(0, 10)

	# Top rojas
	var reds := players.duplicate()
	reds.sort_custom(func(a: Player, b: Player) -> bool: return a.season_reds > b.season_reds)
	reds = reds.slice(0, 10)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	hbox.add_child(_make_ranking_panel("Goleadores", scorers,
		func(p: Player) -> String: return str(p.season_goals),
		Color(0.30, 0.80, 0.35, 1), ICON_GOAL))

	hbox.add_child(_make_ranking_panel("Tarjetas amarillas", yellows,
		func(p: Player) -> String: return str(p.yellow_cards),
		Color(0.92, 0.80, 0.10, 1), ICON_YELLOW))

	hbox.add_child(_make_ranking_panel("Tarjetas rojas", reds,
		func(p: Player) -> String: return str(p.season_reds),
		Color(0.88, 0.20, 0.20, 1), ICON_RED))

	return hbox


func _make_ranking_panel(title: String, players: Array, value_fn: Callable, accent: Color, icon_tex: Texture2D = null) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.10, 0.15, 1)
	sb.set_corner_radius_all(4)
	sb.border_width_left = 3
	sb.border_color = accent
	sb.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	panel.add_child(vbox)

	# Título con icono
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 6)
	if icon_tex != null:
		var icon := TextureRect.new()
		icon.texture = icon_tex
		icon.custom_minimum_size = Vector2(16, 16)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		title_row.add_child(icon)
	var lbl_title := Label.new()
	lbl_title.text = title
	lbl_title.add_theme_font_size_override("font_size", 13)
	lbl_title.add_theme_color_override("font_color", accent)
	title_row.add_child(lbl_title)
	vbox.add_child(title_row)

	vbox.add_child(HSeparator.new())

	var pid_player := GameManager.player_team_id
	var rank := 1
	for p: Player in players:
		var val: String = value_fn.call(p)
		if int(val) == 0 or rank > 7:
			break
		var t: Team = GameManager.get_team(p.team_id)
		var is_mine: bool = (p.team_id == pid_player)

		# Usar solo el apellido para ahorrar espacio
		var parts := p.full_name.split(" ")
		var display_name: String = parts[parts.size() - 1]

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 3)

		var lbl_rank := Label.new()
		lbl_rank.text = str(rank)
		lbl_rank.custom_minimum_size = Vector2(18, 0)
		lbl_rank.add_theme_font_size_override("font_size", 11)
		lbl_rank.add_theme_color_override("font_color", Color(0.55, 0.60, 0.65, 1))
		row.add_child(lbl_rank)

		var lbl_name := Label.new()
		lbl_name.text = display_name
		lbl_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl_name.clip_contents = true
		lbl_name.add_theme_font_size_override("font_size", 12)
		lbl_name.add_theme_color_override("font_color",
			Color(1.0, 0.92, 0.30, 1) if is_mine else Color(0.85, 0.88, 0.92, 1))
		row.add_child(lbl_name)

		var lbl_team := Label.new()
		lbl_team.text = (t.short_name if t else "?")
		lbl_team.custom_minimum_size = Vector2(44, 0)
		lbl_team.add_theme_font_size_override("font_size", 11)
		lbl_team.add_theme_color_override("font_color", Color(0.55, 0.70, 0.85, 1))
		row.add_child(lbl_team)

		var lbl_val := Label.new()
		lbl_val.text = val
		lbl_val.custom_minimum_size = Vector2(26, 0)
		lbl_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lbl_val.add_theme_font_size_override("font_size", 13)
		lbl_val.add_theme_color_override("font_color", accent)
		row.add_child(lbl_val)

		vbox.add_child(row)
		rank += 1

	if rank == 1:
		var empty := Label.new()
		empty.text = "Sin datos aún"
		empty.add_theme_font_size_override("font_size", 12)
		empty.add_theme_color_override("font_color", Color(0.45, 0.48, 0.52, 1))
		vbox.add_child(empty)

	return panel


func _make_header() -> Control:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 1)
	# Columna indicador (sin título)
	hbox.add_child(_make_indicator_cell(-1, 1))
	var cols: Array = [
		["POS",    36,  C_POS_BG,  C_POS_FG],
		["EQUIPO", -1,  C_TEAM_BG, C_TEAM_FG],
		["PTS",    36,  C_PTS_BG,  C_PTS_FG],
		["PJ",     34,  C_PJ_BG,   C_PJ_FG],
		["PG",     34,  C_PG_BG,   C_PG_FG],
		["PE",     34,  C_PE_BG,   C_PE_FG],
		["PP",     34,  C_PP_BG,   C_PP_FG],
		["GF",     34,  C_GF_BG,   C_GF_FG],
		["GC",     34,  C_GC_BG,   C_GC_FG],
	]
	for col: Array in cols:
		hbox.add_child(_make_cell(col[0], col[1], col[2], col[3], true, true))
	return hbox


func _make_row(pos: int, t: Team, total: int, player_tid: int) -> Control:
	var is_player_team := (t.id == player_tid)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 1)

	# Indicador Europa / Descenso
	hbox.add_child(_make_indicator_cell(pos, total))

	# POS
	hbox.add_child(_make_cell(str(pos), 36, C_POS_BG, C_POS_FG, true, false))

	# EQUIPO (escudo + nombre)
	hbox.add_child(_make_team_cell(t, is_player_team))

	# Stats: PTS, PJ, PG, PE, PP, GF, GC
	var stats: Array = [
		[str(t.get_points()),         36, C_PTS_BG, C_PTS_FG],
		[str(t.get_matches_played()), 34, C_PJ_BG,  C_PJ_FG],
		[str(t.wins),                 34, C_PG_BG,  C_PG_FG],
		[str(t.draws),                34, C_PE_BG,  C_PE_FG],
		[str(t.losses),               34, C_PP_BG,  C_PP_FG],
		[str(t.goals_for),            34, C_GF_BG,  C_GF_FG],
		[str(t.goals_against),        34, C_GC_BG,  C_GC_FG],
	]
	for s: Array in stats:
		hbox.add_child(_make_cell(s[0], s[1], s[2], s[3], true, false))

	return hbox


func _make_team_cell(t: Team, is_player_team: bool) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_TEAM_BG
	sb.set_content_margin_all(4)
	if is_player_team:
		sb.border_color = Color(1.0, 0.88, 0.2, 1)
		sb.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", sb)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 5)
	panel.add_child(hbox)

	var crest_rect := TextureRect.new()
	crest_rect.custom_minimum_size = Vector2(20, 20)
	crest_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crest_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if t.crest != "":
		var tex := load(t.crest) as Texture2D
		if tex:
			crest_rect.texture = tex
	hbox.add_child(crest_rect)

	var lbl := Label.new()
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.text = t.name
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_font_override("font", _bold_font())
	lbl.add_theme_color_override("font_color",
		Color(1.0, 0.95, 0.35, 1) if is_player_team else C_TEAM_FG)
	hbox.add_child(lbl)

	return panel


func _make_cell(text: String, width: int, bg: Color, fg: Color, centered: bool, is_header: bool) -> Control:
	var panel := PanelContainer.new()
	if width > 0:
		panel.custom_minimum_size = Vector2(width, 0)
	else:
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_content_margin_all(4)
	panel.add_theme_stylebox_override("panel", sb)

	var lbl := Label.new()
	lbl.text = text
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	lbl.add_theme_font_size_override("font_size", 12 if is_header else 14)
	lbl.add_theme_font_override("font", _bold_font())
	lbl.add_theme_color_override("font_color", fg)
	panel.add_child(lbl)

	return panel


## Celda indicador: franja de color a la izquierda sobre fondo blanco.
## pos == -1 → cabecera (celda blanca vacía).
func _make_indicator_cell(pos: int, total: int) -> Control:
	var outer := PanelContainer.new()
	outer.custom_minimum_size = Vector2(10, 0)
	var sb_outer := StyleBoxFlat.new()
	sb_outer.bg_color = Color.WHITE
	sb_outer.set_content_margin_all(0)
	outer.add_theme_stylebox_override("panel", sb_outer)

	if pos <= 0:
		return outer  # cabecera: solo blanco

	var strip_color: Color
	if pos <= 4:
		strip_color = Color(0.098, 0.318, 0.843, 1)   # azul Champions
	elif pos <= 6:
		strip_color = Color(0.98, 0.5, 0.0, 1)         # naranja Europa League
	elif pos > total - 3:
		strip_color = Color(0.82, 0.09, 0.09, 1)        # rojo descenso
	else:
		return outer  # sin indicador

	var strip := ColorRect.new()
	strip.color = strip_color
	strip.layout_mode = 1
	strip.anchors_preset = -1
	strip.anchor_left   = 0.0
	strip.anchor_right  = 0.0
	strip.anchor_top    = 0.0
	strip.anchor_bottom = 1.0
	strip.offset_left   = 0
	strip.offset_right  = 6
	strip.offset_top    = 0
	strip.offset_bottom = 0
	outer.add_child(strip)
	return outer


func _bold_font() -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Arial", "Roboto", "DejaVu Sans", "Noto Sans"])
	f.font_weight = 700
	return f
