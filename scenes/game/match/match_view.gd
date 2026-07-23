extends Control

## Velocidades de reproducción (segundos reales por minuto de partido)
const SPEED_NORMAL := 0.55
const SPEED_FAST   := 0.12
const ICON_GOAL := preload("res://assets/ui/icons/goal.png")
const ICON_YELLOW := preload("res://assets/ui/icons/yellow-card.png")
const ICON_RED := preload("res://assets/ui/icons/red-card.png")

## Fixture que se está jugando (pasado desde el calendario via GameManager)
var fixture: Dictionary = {}

var _home: Team = null
var _away: Team = null
var _events: Array[Dictionary] = []
var _event_idx: int = 0
var _timer: Timer = null
var _playing: bool = false
var _fast: bool = false
var _finished: bool = false

var _home_goals: int = 0
var _away_goals: int = 0
var _home_shots: int = 0
var _away_shots: int = 0
var _possession: int = 50   # % local


func _ready() -> void:
	fixture = GameManager.active_fixture
	_home = GameManager.get_team(fixture.get("home_id", -1))
	_away = GameManager.get_team(fixture.get("away_id", -1))

	if _home == null or _away == null:
		push_error("MatchView: equipos no encontrados")
		return

	%HomeName.text = _home.name
	%AwayName.text = _away.name
	_add_crests()

	# Banner especial de derbi
	var _derby_name: String = NewsManager.get_derby_name(_home.name, _away.name)
	if _derby_name != "":
		_add_derby_banner(_derby_name)

	# Generar todos los eventos
	_events = MatchEngine.generate_events(_home, _away)

	# Timer que avanza un evento por tick
	_timer = Timer.new()
	_timer.one_shot = true
	add_child(_timer)
	_timer.timeout.connect(_advance_event)

	%BtnPlayPause.pressed.connect(_on_play_pause)
	%BtnFast.pressed.connect(_on_fast)
	%BtnSkip.pressed.connect(_on_skip)

	_refresh_scoreboard()


# ---------------------------------------------------------------------------
# Controles

func _on_play_pause() -> void:
	if _finished:
		_go_back()
		return
	_playing = not _playing
	if _playing:
		%BtnPlayPause.text = "⏸ Pausa"
		_fast = false
		%BtnFast.text = "⏩ Rápido"
		_tick()
	else:
		%BtnPlayPause.text = "▶ Jugar"
		_timer.stop()


func _on_fast() -> void:
	if _finished:
		return
	_fast = not _fast
	%BtnFast.text = "⏩ Rápido" if not _fast else "🐢 Normal"
	if not _playing:
		_playing = true
		%BtnPlayPause.text = "⏸ Pausa"
		_tick()


func _on_skip() -> void:
	# Mostrar todos los eventos restantes instantáneamente
	_timer.stop()
	_playing = false
	while _event_idx < _events.size():
		_process_event(_events[_event_idx])
		_event_idx += 1
	_on_match_finished()


func _add_crests() -> void:
	var teams_row := %HomeName.get_parent() as HBoxContainer
	if teams_row == null:
		return
	var home_crest := _make_crest_rect(_home.crest)
	var away_crest := _make_crest_rect(_away.crest)
	teams_row.add_child(home_crest)
	teams_row.move_child(home_crest, %HomeName.get_index() + 1)
	teams_row.add_child(away_crest)
	teams_row.move_child(away_crest, %AwayName.get_index())


func _make_crest_rect(path: String) -> TextureRect:
	var rect := TextureRect.new()
	rect.custom_minimum_size = Vector2(44, 44)
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if path != "":
		var tex := load(path) as Texture2D
		if tex:
			rect.texture = tex
	return rect


# ---------------------------------------------------------------------------
# Motor de tick

func _tick() -> void:
	if _event_idx >= _events.size():
		_on_match_finished()
		return
	var delay := SPEED_FAST if _fast else SPEED_NORMAL
	_timer.start(delay)


func _advance_event() -> void:
	if _event_idx >= _events.size():
		_on_match_finished()
		return
	_process_event(_events[_event_idx])
	_event_idx += 1
	if _playing and not _finished:
		_tick()


func _process_event(ev: Dictionary) -> void:
	var t := ev["type"] as MatchEngine.EventType
	var min: int = ev["minute"]

	%MinuteLabel.text = "Descanso" if t == MatchEngine.EventType.HALF_TIME else \
						("Final" if t == MatchEngine.EventType.FULL_TIME else "Minuto %d'" % min)

	if t == MatchEngine.EventType.GOAL:
		if ev["team_id"] == _home.id:
			_home_goals += 1
		else:
			_away_goals += 1
		_refresh_scoreboard()

	if t in [MatchEngine.EventType.SHOT_SAVED, MatchEngine.EventType.GOAL]:
		if ev["team_id"] == _home.id:
			_home_shots += 1
		else:
			_away_shots += 1

	_add_commentary(ev["text"], t)
	_update_stats()


func _on_match_finished() -> void:
	_finished = true
	_playing  = false

	if not fixture.get("played", false):
		var ft: Dictionary = _events[_events.size() - 1]
		fixture["home_goals"] = ft.get("home_goals", _home_goals)
		fixture["away_goals"] = ft.get("away_goals", _away_goals)
		fixture["played"]     = true
		LeagueManager._apply_result(fixture)
		# Actualizar métricas de la Junta Directiva
		var _is_home: bool = fixture.get("home_id", -1) == GameManager.player_team_id
		var _pgf: int = fixture["home_goals"] if _is_home else fixture["away_goals"]
		var _pga: int = fixture["away_goals"] if _is_home else fixture["home_goals"]
		GameManager.update_board_metrics(_pgf, _pga)
		# Noticia especial de derbi (después de update_board_metrics que limpia active_derby_name)
		var _d_name := NewsManager.get_derby_name(_home.name, _away.name)
		if _d_name != "":
			NewsManager.add_derby_result_news(fixture, GameManager.get_player_team(), _d_name)
		# Primero liberar a los que cumplieron sanción, luego aplicar las nuevas
		var pt: Team = GameManager.get_player_team()
		if pt != null:
			LeagueManager.consume_suspensions(pt)
		LeagueManager.apply_match_sanctions(ft)
		# Registrar goles de temporada para todos los goleadores del partido
		for ev: Dictionary in _events:
			if ev.get("type") == MatchEngine.EventType.GOAL:
				var scorer_id: int = ev.get("player_id", -1)
				if scorer_id != -1:
					var _sp: Player = GameManager.get_player(scorer_id)
					if _sp:
						_sp.season_goals += 1
		var league: League = _get_fixture_league()
		if league:
			var md: int = fixture.get("matchday", 1)
			if md > league.current_matchday:
				league.current_matchday = md

	%BtnPlayPause.text = "← Volver al Despacho"
	%BtnFast.disabled  = true
	%BtnSkip.disabled  = true

	# Ingresos de taquilla cuando el jugador es local
	var _local: Team = GameManager.get_team(fixture.get("home_id", -1))
	if _local != null and _local.id == GameManager.player_team_id:
		var _md_income := _local.calculate_matchday_income()
		_local.club_cash              += _md_income
		_local.season_matchday_income += _md_income
		# Registrar en la última entrada del historial financiero de esta semana
		if _local.finance_history.size() > 0:
			_local.finance_history[_local.finance_history.size() - 1]["matchday"] = _md_income
			_local.finance_history[_local.finance_history.size() - 1]["balance"]  = _local.club_cash

	GameManager.active_fixture = {}

	# Drenar energía de los titulares del equipo del jugador
	# La pérdida depende del rendimiento físico: más physical = aguanta más
	# Base: 10–26 puntos, reducida hasta ~7–18 si physical >= 80
	var pt2: Team = GameManager.get_player_team()
	if pt2 != null:
		var match_intensity := randf_range(0.8, 1.2)  # partido más o menos exigente
		for pid: int in pt2.starting_eleven:
			var p: Player = GameManager.get_player(pid)
			if p:
				var base_drain := randf_range(10.0, 26.0)
				var phys_factor := 1.0 - (float(p.physical) / 99.0) * 0.35  # 0.65 a 1.0
				var drain := int(round(base_drain * phys_factor * match_intensity))
				p.energy = clampi(p.energy - drain, 5, 100)

	SaveManager.save_game()


func _go_back() -> void:
	get_tree().change_scene_to_file("res://scenes/game/office/office.tscn")


func _add_derby_banner(derby_name: String) -> void:
	# Insertar una barra de derbi llamativa encima del marcador
	var root_vbox := get_node_or_null("VBoxContainer") as VBoxContainer
	if root_vbox == null:
		root_vbox = get_child(0) as VBoxContainer
	if root_vbox == null:
		return
	var banner := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.55, 0.08, 0.05, 1)
	sb.set_content_margin_all(6)
	banner.add_theme_stylebox_override("panel", sb)
	var lbl := Label.new()
	lbl.text = "🔥  %s  🔥" % derby_name.to_upper()
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.20, 1))
	banner.add_child(lbl)
	root_vbox.add_child(banner)
	root_vbox.move_child(banner, 0)


# ---------------------------------------------------------------------------
# UI helpers

func _refresh_scoreboard() -> void:
	%ScoreLabel.text = "%d - %d" % [_home_goals, _away_goals]


func _update_stats() -> void:
	%HomeShots.text  = "Tiros: %d" % _home_shots
	%AwayShots.text  = "Tiros: %d" % _away_shots
	# Posesión estimada: se va ajustando con los eventos de cada equipo
	var home_events := 0
	var away_events := 0
	for i in range(_event_idx):
		var ev: Dictionary = _events[i]
		if ev["team_id"] == _home.id:
			home_events += 1
		elif ev["team_id"] == _away.id:
			away_events += 1
	var total := home_events + away_events
	_possession = 50 if total == 0 else int(round(float(home_events) / float(total) * 100.0))
	%PossLabel.text = "Pos. %d%%-%d%%" % [_possession, 100 - _possession]


func _add_commentary(text: String, type: MatchEngine.EventType) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override("separation", 8)

	var icon_tex := _event_icon_texture(type)
	if icon_tex != null:
		var icon := TextureRect.new()
		icon.texture = icon_tex
		icon.custom_minimum_size = Vector2(24, 24)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)

	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	match type:
		MatchEngine.EventType.GOAL:
			lbl.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4, 1))
		MatchEngine.EventType.RED_CARD:
			lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3, 1))
		MatchEngine.EventType.YELLOW_CARD:
			lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2, 1))
		MatchEngine.EventType.HALF_TIME, MatchEngine.EventType.FULL_TIME:
			lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.5, 1))
		_:
			lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1))
	row.add_child(lbl)

	var list: VBoxContainer = %CommentaryList
	# Insertar al inicio para que el más reciente quede arriba
	list.add_child(row)
	list.move_child(row, 0)


func _event_icon_texture(type: MatchEngine.EventType) -> Texture2D:
	match type:
		MatchEngine.EventType.GOAL:
			return ICON_GOAL
		MatchEngine.EventType.YELLOW_CARD:
			return ICON_YELLOW
		MatchEngine.EventType.RED_CARD:
			return ICON_RED
		_:
			return null


func _get_fixture_league() -> League:
	for league: League in GameManager.leagues.values():
		for f: Dictionary in league.fixtures:
			if f.get("home_id") == fixture.get("home_id") and \
			   f.get("away_id") == fixture.get("away_id") and \
			   f.get("matchday") == fixture.get("matchday"):
				return league
	return null
