extends Control

const ICON_BACK := preload("res://assets/ui/icons/back-white.png")
const ICON_TROPHY := preload("res://assets/ui/icons/trophy.png")
const ICON_SIZE_NAV := 28

@onready var title_label: Label = %TitleLabel
@onready var status_label: Label = %StatusLabel
@onready var rounds_box: VBoxContainer = %RoundsBox


func _ready() -> void:
	%BtnBack.icon = ICON_BACK
	%BtnBack.add_theme_constant_override("icon_max_width", ICON_SIZE_NAV)
	%BtnBack.text = ""
	%BtnBack.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/game/office/office.tscn"))
	_refresh()


func _refresh() -> void:
	for child in rounds_box.get_children():
		child.queue_free()

	var cup := GameManager.get_cup_competition()
	if cup.is_empty():
		title_label.text = "Copa no disponible"
		status_label.text = "No hay una edición activa de la Copa del Rey en esta partida."
		return

	title_label.text = str(cup.get("name", "Copa del Rey"))
	status_label.text = _build_status_text(cup)

	for round: Dictionary in cup.get("rounds", []):
		rounds_box.add_child(_build_round_panel(round, int(cup.get("winner_team_id", -1))))


func _build_status_text(cup: Dictionary) -> String:
	var winner_id := int(cup.get("winner_team_id", -1))
	if winner_id != -1:
		var winner := GameManager.get_team(winner_id)
		return "Campeón: %s" % (winner.name if winner != null else "Pendiente")

	var pending_round := ""
	for round: Dictionary in cup.get("rounds", []):
		if round.get("drawn", false) and not round.get("completed", false):
			pending_round = str(round.get("name", "Ronda"))
			break
		if not round.get("drawn", false):
			pending_round = "Sorteo pendiente: %s" % str(round.get("name", "Ronda"))
			break
	return pending_round if pending_round != "" else "Cuadro completo listo."


func _build_round_panel(round: Dictionary, winner_id: int) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 120)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.11, 0.18, 0.96)
	style.border_width_left = 3
	style.border_color = Color(0.83, 0.68, 0.22, 1) if round.get("completed", false) else Color(0.27, 0.55, 0.92, 1)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	panel.add_child(outer)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	outer.add_child(header)

	if ICON_TROPHY != null and str(round.get("key", "")) == "final" and winner_id != -1:
		var trophy := TextureRect.new()
		trophy.texture = ICON_TROPHY
		trophy.custom_minimum_size = Vector2(22, 22)
		trophy.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		trophy.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		header.add_child(trophy)

	var title := Label.new()
	title.text = str(round.get("name", "Ronda"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.93, 0.95, 1.0, 1))
	header.add_child(title)

	var state := Label.new()
	state.text = _round_state_text(round)
	state.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	state.add_theme_font_size_override("font_size", 14)
	state.add_theme_color_override("font_color", Color(0.62, 0.78, 0.96, 1))
	header.add_child(state)

	var meta := Label.new()
	meta.text = _round_meta_text(round)
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meta.add_theme_font_size_override("font_size", 14)
	meta.add_theme_color_override("font_color", Color(0.68, 0.74, 0.84, 1))
	outer.add_child(meta)

	var fixtures_box := VBoxContainer.new()
	fixtures_box.add_theme_constant_override("separation", 6)
	outer.add_child(fixtures_box)

	var fixtures: Array = round.get("fixtures", [])
	if fixtures.is_empty():
		var pending := Label.new()
		pending.text = "Pendiente de sorteo."
		pending.add_theme_font_size_override("font_size", 16)
		pending.add_theme_color_override("font_color", Color(0.84, 0.86, 0.92, 1))
		fixtures_box.add_child(pending)
		return panel

	for pair_id: String in _pair_ids(fixtures):
		fixtures_box.add_child(_build_pair_block(fixtures, pair_id))

	return panel


func _pair_ids(fixtures: Array) -> Array[String]:
	var ids: Array[String] = []
	for fixture: Dictionary in fixtures:
		var pair_id := str(fixture.get("pair_id", ""))
		if not ids.has(pair_id):
			ids.append(pair_id)
	return ids


func _build_pair_block(fixtures: Array, pair_id: String) -> Control:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 4)
	for fixture: Dictionary in fixtures:
		if str(fixture.get("pair_id", "")) != pair_id:
			continue
		block.add_child(_build_fixture_row(fixture))
	return block


func _build_fixture_row(fixture: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.04)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)

	var leg_label := Label.new()
	leg_label.custom_minimum_size = Vector2(76, 0)
	leg_label.text = "Vuelta" if int(fixture.get("leg", 1)) == 2 else ("Ida" if fixture.get("two_legs", false) else "Partido")
	leg_label.add_theme_font_size_override("font_size", 14)
	leg_label.add_theme_color_override("font_color", Color(0.48, 0.72, 0.95, 1))
	row.add_child(leg_label)

	var home := GameManager.get_team(int(fixture.get("home_id", -1)))
	var away := GameManager.get_team(int(fixture.get("away_id", -1)))
	var match_label := Label.new()
	match_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	match_label.text = "%s vs %s" % [home.name if home != null else "???", away.name if away != null else "???"]
	match_label.add_theme_font_size_override("font_size", 17)
	match_label.add_theme_color_override("font_color", _fixture_color(fixture))
	row.add_child(match_label)

	var result_label := Label.new()
	result_label.custom_minimum_size = Vector2(170, 0)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	result_label.text = _fixture_result_text(fixture)
	result_label.add_theme_font_size_override("font_size", 15)
	result_label.add_theme_color_override("font_color", Color(0.9, 0.92, 0.97, 1))
	row.add_child(result_label)

	return panel


func _fixture_color(fixture: Dictionary) -> Color:
	var player_id := GameManager.player_team_id
	if int(fixture.get("home_id", -1)) == player_id or int(fixture.get("away_id", -1)) == player_id:
		return Color(0.98, 0.91, 0.46, 1)
	return Color(0.88, 0.92, 1.0, 1)


func _fixture_result_text(fixture: Dictionary) -> String:
	var date_text := _fmt_date(fixture.get("scheduled_date", {}))
	if not fixture.get("played", false):
		var venue_note := " · Neutral" if fixture.get("neutral_venue", false) else ""
		return "%s%s" % [date_text, venue_note]
	var score_text := "%d-%d" % [int(fixture.get("home_goals", 0)), int(fixture.get("away_goals", 0))]
	if fixture.has("penalties_home"):
		score_text += " (%d-%d pen.)" % [int(fixture.get("penalties_home", 0)), int(fixture.get("penalties_away", 0))]
	elif fixture.get("decided_by", "") == "extra_time":
		score_text += " (prórroga)"
	var winner_id := int(fixture.get("winner_id", -1))
	if winner_id == -1:
		return score_text
	var winner := GameManager.get_team(winner_id)
	return "%s · pasa %s" % [score_text, winner.short_name if winner != null else "???"]


func _round_state_text(round: Dictionary) -> String:
	if round.get("completed", false):
		return "Completada"
	if round.get("drawn", false):
		return "Sorteada"
	return "Pendiente"


func _round_meta_text(round: Dictionary) -> String:
	var draw_text := "Sorteo: %s" % _fmt_date(round.get("draw_date", {}))
	var play_text := "Juega: %s" % _fmt_date(round.get("play_date", {}))
	if round.get("two_legs", false):
		play_text = "%s · Vuelta: %s" % [play_text, _fmt_date(round.get("second_leg_date", {}))]
	if round.get("neutral", false):
		play_text += " · Sede neutral"
	return "%s  |  %s" % [draw_text, play_text]


func _fmt_date(date: Dictionary) -> String:
	if date.is_empty():
		return "--/--/----"
	return "%02d/%02d/%d" % [int(date.get("day", 1)), int(date.get("month", 1)), int(date.get("year", GameManager.season))]
