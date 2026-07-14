extends Control

const POS_ORDER := {
	Player.Position.GK:  0,
	Player.Position.DEF: 1,
	Player.Position.MID: 2,
	Player.Position.FWD: 3,
}


func _ready() -> void:
	%BtnBack.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/game/office/office.tscn"))

	var fixture := _get_next_fixture()
	if fixture.is_empty():
		%RivalName.text = "Sin próximo partido"
		%RivalInfo.text = ""
		%NoRivalLabel.visible = true
		return

	%NoRivalLabel.visible = false
	var rival_id: int = fixture["away_id"] if fixture["home_id"] == GameManager.player_team_id else fixture["home_id"]
	var is_home: bool  = fixture["home_id"] == GameManager.player_team_id
	var rival: Team    = GameManager.get_team(rival_id)
	if rival == null:
		%RivalName.text = "Datos no disponibles"
		return

	_fill_header(rival, fixture, is_home)
	_fill_players(rival)
	_fill_results(rival_id)


# ---------------------------------------------------------------------------
# Fixture del próximo partido del jugador

func _get_next_fixture() -> Dictionary:
	# Si ya hay uno activo pendiente de jugar, devolverlo
	if not GameManager.active_fixture.is_empty() and not GameManager.active_fixture.get("played", true):
		return GameManager.active_fixture
	# Buscar en el calendario el siguiente sin jugar que involucre al jugador
	var pid: int = GameManager.player_team_id
	for league: League in GameManager.leagues.values():
		var best: Dictionary = {}
		for f: Dictionary in league.fixtures:
			if f["played"]:
				continue
			if f["home_id"] != pid and f["away_id"] != pid:
				continue
			if best.is_empty() or f["matchday"] < best["matchday"]:
				best = f
		if not best.is_empty():
			return best
	return {}


# ---------------------------------------------------------------------------
# Cabecera

func _fill_header(rival: Team, fixture: Dictionary, is_home: bool) -> void:
	%RivalName.text = rival.name
	var venue := "Partido en casa" if is_home else "Partido fuera"
	%RivalInfo.text = "%s  •  %s  •  Jornada %d" % [rival.coach_name if rival.coach_name != "" else rival.city, venue, fixture.get("matchday", 0)]

	var standings_text := _get_standings_text(rival)
	%RivalStandings.text = standings_text

	var formation := rival.formation if rival.formation != "" else "4-4-2"
	%RivalFormation.text = "Formación: %s" % formation


# ---------------------------------------------------------------------------
# Jugadores

func _fill_players(rival: Team) -> void:
	var container: VBoxContainer = %PlayerList
	for child in container.get_children():
		child.queue_free()

	# Cabecera de columnas
	var header := _make_player_row("POS", "NOMBRE", "VAL", "EDAD", true)
	container.add_child(header)

	var sep := HSeparator.new()
	container.add_child(sep)

	# Obtener jugadores y ordenar por posición, luego por overall desc
	var players: Array[Player] = []
	for pid: int in rival.player_ids:
		var p: Player = GameManager.get_player(pid)
		if p != null:
			players.append(p)

	players.sort_custom(func(a: Player, b: Player) -> bool:
		var pa: int = POS_ORDER.get(a.position, 9)
		var pb: int = POS_ORDER.get(b.position, 9)
		if pa != pb:
			return pa < pb
		return a.get_overall() > b.get_overall()
	)

	var odd := false
	for p: Player in players:
		var row := _make_player_row(
			p.get_position_abbr(),
			p.full_name,
			str(p.get_overall()),
			str(p.age),
			false,
			odd
		)
		container.add_child(row)
		odd = not odd


func _make_player_row(pos: String, name: String, val: String, age: String, is_header: bool, odd: bool = false) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 36)

	if not is_header and odd:
		var bg := ColorRect.new()
		bg.color = Color(1, 1, 1, 0.04)
		bg.anchor_right = 1.0
		bg.anchor_bottom = 1.0
		row.add_child(bg)

	var font_size := 15 if is_header else 16
	var color     := Color(0.45, 0.65, 0.95, 1) if is_header else Color(0.88, 0.94, 1.0, 1)

	var lbl_pos  := _make_label(pos,  60,  font_size, color, HORIZONTAL_ALIGNMENT_CENTER)
	var lbl_name := _make_label(name, 0,   font_size, color, HORIZONTAL_ALIGNMENT_LEFT)
	lbl_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lbl_val  := _make_label(val,  50,  font_size, color, HORIZONTAL_ALIGNMENT_CENTER)
	var lbl_age  := _make_label(age,  50,  font_size, color, HORIZONTAL_ALIGNMENT_CENTER)

	row.add_child(lbl_pos)
	row.add_child(lbl_name)
	row.add_child(lbl_val)
	row.add_child(lbl_age)
	return row


func _make_label(txt: String, min_w: int, font_size: int, color: Color, align: HorizontalAlignment) -> Label:
	var lbl := Label.new()
	lbl.text = txt
	lbl.horizontal_alignment = align
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	if min_w > 0:
		lbl.custom_minimum_size = Vector2(min_w, 0)
	return lbl


# ---------------------------------------------------------------------------
# Últimos resultados

func _fill_results(rival_id: int) -> void:
	var container: VBoxContainer = %ResultList
	for child in container.get_children():
		child.queue_free()

	var results: Array[Dictionary] = _get_last_results(rival_id, 5)
	if results.is_empty():
		var lbl := Label.new()
		lbl.text = "Sin resultados anteriores"
		lbl.add_theme_color_override("font_color", Color(0.55, 0.65, 0.75, 1))
		lbl.add_theme_font_size_override("font_size", 15)
		container.add_child(lbl)
		return

	for f: Dictionary in results:
		var home: Team = GameManager.get_team(f["home_id"])
		var away: Team = GameManager.get_team(f["away_id"])
		var home_name := home.short_name if home else "???"
		var away_name := away.short_name if away else "???"

		var result_str := "%s  %d - %d  %s" % [home_name, f["home_goals"], f["away_goals"], away_name]

		# Determinar si el rival ganó, empató o perdió
		var won: bool
		var drew: bool
		if f["home_id"] == rival_id:
			won  = f["home_goals"] > f["away_goals"]
			drew = f["home_goals"] == f["away_goals"]
		else:
			won  = f["away_goals"] > f["home_goals"]
			drew = f["away_goals"] == f["home_goals"]

		var badge := "V" if won else ("E" if drew else "D")
		var badge_color := Color(0.15, 0.9, 0.3, 1) if won else (Color(0.9, 0.85, 0.1, 1) if drew else Color(0.9, 0.2, 0.2, 1))

		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 34)
		row.add_theme_constant_override("separation", 10)

		var lbl_badge := _make_label(badge, 28, 15, badge_color, HORIZONTAL_ALIGNMENT_CENTER)
		var lbl_result := _make_label(result_str, 0, 15, Color(0.82, 0.88, 0.96, 1), HORIZONTAL_ALIGNMENT_LEFT)

		row.add_child(lbl_badge)
		row.add_child(lbl_result)
		container.add_child(row)


func _get_last_results(rival_id: int, count: int) -> Array[Dictionary]:
	var played: Array[Dictionary] = []
	for league: League in GameManager.leagues.values():
		for f: Dictionary in league.fixtures:
			if not f["played"]:
				continue
			if f["home_id"] == rival_id or f["away_id"] == rival_id:
				played.append(f)

	# Ordenar por jornada desc
	played.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["matchday"] > b["matchday"]
	)

	var result: Array[Dictionary] = []
	for i in range(mini(count, played.size())):
		result.append(played[i])
	return result


# ---------------------------------------------------------------------------
# Clasificación del rival en su liga

func _get_standings_text(rival: Team) -> String:
	for league: League in GameManager.leagues.values():
		if not (rival.id in league.team_ids):
			continue
		var standings := LeagueManager.get_standings(league)
		for i in range(standings.size()):
			if (standings[i] as Team).id == rival.id:
				var t: Team = standings[i] as Team
				return "Posición: %dº  •  PJ %d  •  %d pts  •  %d-%d-%d" % [
					i + 1, t.get_matches_played(), t.get_points(), t.wins, t.draws, t.losses
				]
	return ""
