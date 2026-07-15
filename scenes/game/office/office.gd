extends Control

@onready var team_name_label: Label = %TeamNameLabel
@onready var date_label: Label      = %DateLabel
@onready var status_bar: Label      = %StatusBar
@onready var btn_play_match: Button = %BtnPlayMatch
@onready var away_team_label: Label  = %AwayTeamLabel
@onready var away_manager_label: Label = %AwayManagerLabel
@onready var home_manager_label: Label = %HomeManagerLabel
@onready var match_week_label: Label = %MatchWeekLabel
@onready var notice_label: Label    = %NoticeLabel
@onready var home_crest: TextureRect = %HomeCrest
@onready var away_crest: TextureRect = %AwayCrest

const _TICKER_SPEED: float = 110.0  # px/s
var _notices: Array[String] = []
var _ticker_x: float = 0.0
var _squad_badge: Label     = null  # punto rojo sobre Plantilla
var _transfers_badge: Label = null  # punto rojo sobre Fichajes
var _tactics_badge: Label   = null  # punto rojo sobre Tácticas


func _ready() -> void:
	_refresh_header()
	GameManager.date_advanced.connect(_on_date_advanced)
	GameManager.player_match_ready.connect(_on_player_match_ready)
	GameManager.matchday_done.connect(_on_matchday_done)
	GameManager.season_ended.connect(_on_season_ended)

	%BtnSquad.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/game/squad/plantilla.tscn"))
	%BtnAlignment.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/game/squad/squad.tscn"))
	%BtnTactics.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/game/tactics/tactics.tscn"))
	%BtnTransfers.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/game/transfers/transfers.tscn"))
	%BtnCalendar.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/game/calendar/player_calendar.tscn"))
	%BtnResults.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/game/calendar/calendar.tscn"))
	%BtnStandings.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/game/standings/standings.tscn"))
	%BtnPress.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/game/press/press.tscn"))
	%BtnSalir.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn"))
	%BtnSave.pressed.connect(func(): SaveManager.save_game(); _set_status("Partida guardada."))
	%BtnViewRival.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/game/rival/rival.tscn"))
	%BtnEmployees.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/game/employees/employees.tscn"))
	%BtnCash.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/game/cash/cash.tscn"))
	%BtnDecisions.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/game/decisions/decisions_hub.tscn"))
	%BtnStadium.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/game/stadium/stadium.tscn"))
	%BtnNextWeek.pressed.connect(_on_next_week)
	btn_play_match.pressed.connect(_on_play_match)
	TransferManager.incoming_offer_received.connect(_on_incoming_offer)
	TransferManager.offer_response_received.connect(_on_offer_response)
	_setup_squad_badge()
	_setup_transfers_badge()
	_setup_tactics_badge()

	set_process(false)

	# Restaurar estado del partido si volvemos desde otra pantalla
	if not GameManager.active_fixture.is_empty() and not GameManager.active_fixture.get("played", false):
		_on_player_match_ready(GameManager.active_fixture)


func _process(delta: float) -> void:
	if _notices.is_empty():
		return
	var clip: Control = notice_label.get_parent()
	_ticker_x -= _TICKER_SPEED * delta
	notice_label.position.x = _ticker_x
	if _ticker_x + notice_label.size.x < 0.0:
		_ticker_x = clip.size.x


func _refresh_header() -> void:
	var team := GameManager.get_player_team()
	date_label.text = GameManager.get_date_string()
	match_week_label.text = "Semana %d" % GameManager.current_week

	var next_f: Dictionary = GameManager.get_next_player_fixture()
	if not next_f.is_empty():
		var home: Team = GameManager.get_team(next_f.get("home_id", -1))
		var away: Team = GameManager.get_team(next_f.get("away_id", -1))
		var player_is_home := (home != null and home.id == GameManager.player_team_id)
		team_name_label.text = home.name if home else (team.name if team else "Mi Equipo")
		away_team_label.text = away.name if away else "—"
		if player_is_home:
			home_manager_label.text = GameManager.manager_name
			away_manager_label.text = (away.coach_name if away.coach_name != "" else away.city) if away else ""
		else:
			home_manager_label.text = (home.coach_name if home.coach_name != "" else home.city) if home else ""
			away_manager_label.text = GameManager.manager_name
		_set_crest(home_crest, home)
		_set_crest(away_crest, away)
	else:
		team_name_label.text = team.name if team else "Sin equipo"
		away_team_label.text = "—"
		home_manager_label.text = GameManager.manager_name
		away_manager_label.text = ""
		_set_crest(home_crest, team)
		_set_crest(away_crest, null)


func _set_crest(rect: TextureRect, team: Team) -> void:
	if rect == null:
		return
	if team != null and team.crest != "":
		var tex := load(team.crest) as Texture2D
		rect.texture = tex
	else:
		rect.texture = null


func _on_next_week() -> void:
	# Si hay partido pendiente, jugar en lugar de avanzar
	if not GameManager.active_fixture.is_empty() and not GameManager.active_fixture.get("played", false):
		_on_play_match()
		return
	%BtnNextWeek.disabled = true
	GameManager.advance_week()
	SaveManager.save_game()
	%BtnNextWeek.disabled = false


func _on_player_match_ready(fixture: Dictionary) -> void:
	var home: Team = GameManager.get_team(fixture.get("home_id", -1))
	var away: Team = GameManager.get_team(fixture.get("away_id", -1))
	team_name_label.text = home.name if home else "Mi Equipo"
	away_team_label.text = away.name if away else "Rival"
	away_manager_label.text = (away.coach_name if away.coach_name != "" else away.city) if away else ""
	_set_crest(home_crest, home)
	_set_crest(away_crest, away)
	%BtnNextWeek.text = "⚽ Jugar Partido"
	%BtnNextWeek.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4, 1))

	var msgs: Array[String] = []
	msgs.append("⚽ Jornada %d — Los rivales ya han jugado. ¡Te toca!" % fixture.get("matchday", 0))
	var suspended_names := _get_suspended_in_lineup()
	if not suspended_names.is_empty():
		msgs.append("⚠️ Sancionados en el once: %s — Ve a Tácticas y cámbialos antes de jugar." % ", ".join(suspended_names))
	_set_notices(msgs)


func _on_matchday_done(matchday: int) -> void:
	%BtnNextWeek.text = "Seguir  ▶"
	%BtnNextWeek.remove_theme_color_override("font_color")
	_set_notices([])
	_set_status("Semana %d — Jornada %d completada." % [GameManager.current_week, matchday])


func _on_play_match() -> void:
	var suspended_names := _get_suspended_in_lineup()
	if not suspended_names.is_empty():
		var dlg := AcceptDialog.new()
		dlg.title = "Jugadores sancionados en el once"
		dlg.dialog_text = "Los siguientes jugadores no pueden disputar el partido:\n\n• %s\n\nVe a Tácticas y cámbialos antes de jugar." % "\n• ".join(suspended_names)
		dlg.confirmed.connect(func(): get_tree().change_scene_to_file("res://scenes/game/tactics/tactics.tscn"))
		add_child(dlg)
		dlg.popup_centered()
		return
	get_tree().change_scene_to_file("res://scenes/game/match/match_view.tscn")


func _on_date_advanced(_date: Dictionary) -> void:
	_refresh_header()
	_refresh_squad_badge()
	_refresh_tactics_badge()


func _setup_squad_badge() -> void:
	# Inyectar un punto rojo sobre el botón Plantilla
	var btn: Button = %BtnSquad
	var badge := Label.new()
	badge.text = "\u25cf"
	badge.add_theme_font_size_override("font_size", 22)
	badge.add_theme_color_override("font_color", Color(1.0, 0.20, 0.15, 1))
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Posicionar en esquina superior derecha del botón
	btn.add_child(badge)
	badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	badge.position = Vector2(-22, 2)
	_squad_badge = badge
	_refresh_squad_badge()


func _refresh_squad_badge() -> void:
	if _squad_badge == null:
		return
	var has_pending: bool = false
	for o: Dictionary in TransferManager.incoming_offers:
		if o["status"] == "pending" and not o.get("acknowledged", false):
			has_pending = true
			break
	_squad_badge.visible = has_pending


func _setup_transfers_badge() -> void:
	var btn: Button = %BtnTransfers
	var badge := Label.new()
	badge.text = "\u25cf"
	badge.add_theme_font_size_override("font_size", 22)
	badge.add_theme_color_override("font_color", Color(1.0, 0.20, 0.15, 1))
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(badge)
	badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	badge.position = Vector2(-22, 2)
	_transfers_badge = badge
	_refresh_transfers_badge()


func _refresh_transfers_badge() -> void:
	if _transfers_badge == null:
		return
	var has_response: bool = false
	for o: Dictionary in TransferManager.active_offers:
		var st: String = o.get("status", "")
		if (st == "countered" or st == "rejected") and not o.get("acknowledged", false):
			has_response = true
			break
	_transfers_badge.visible = has_response


func _on_offer_response(_offer: Dictionary) -> void:
	_refresh_transfers_badge()


func _setup_tactics_badge() -> void:
	var btn: Button = %BtnTactics
	var badge := Label.new()
	badge.text = "\u25cf"
	badge.add_theme_font_size_override("font_size", 22)
	badge.add_theme_color_override("font_color", Color(1.0, 0.20, 0.15, 1))
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(badge)
	badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	badge.position = Vector2(-22, 2)
	_tactics_badge = badge
	_refresh_tactics_badge()


func _refresh_tactics_badge() -> void:
	if _tactics_badge == null:
		return
	_tactics_badge.visible = GameManager.tactics_badge_active


func _on_season_ended() -> void:
	get_tree().change_scene_to_file("res://scenes/game/season_end/season_end.tscn")


func _set_status(msg: String) -> void:
	status_bar.text = msg


func _set_notice(msg: String) -> void:
	var arr: Array[String] = []
	if msg != "":
		arr.append(msg)
	_set_notices(arr)


func _set_notices(msgs: Array[String]) -> void:
	_notices = msgs.filter(func(s: String) -> bool: return s != "")
	var bar: Control = notice_label.get_parent().get_parent()
	if _notices.is_empty():
		bar.visible = false
		set_process(false)
		return
	notice_label.text = "          ".join(_notices) + "          "
	notice_label.reset_size()
	var clip: Control = notice_label.get_parent()
	_ticker_x = clip.size.x if clip.size.x > 0.0 else 1280.0
	notice_label.position.x = _ticker_x
	bar.visible = true
	set_process(true)


## Devuelve los nombres de jugadores sancionados o lesionados que están en el once titular.
func _get_suspended_in_lineup() -> Array[String]:
	var team: Team = GameManager.get_player_team()
	if team == null:
		return []
	var names: Array[String] = []
	for pid: int in team.starting_eleven:
		var p: Player = GameManager.get_player(pid)
		if p != null and (p.suspended or p.injured):
			names.append(p.full_name)
	return names


func _on_incoming_offer(offer: Dictionary) -> void:
	var p: Player   = GameManager.get_player(offer["player_id"])
	var buyer: Team = GameManager.get_team(offer["buyer_id"])
	if p == null or buyer == null:
		return
	var msg: String
	if offer.get("is_clause", false):
		msg = "🔔 %s ha activado la cláusula de rescisión de %s (%s). ¡Revisa Plantilla!" % [
			buyer.name, p.full_name, _fmt_short(offer["offer_money"])]
	else:
		msg = "🔔 %s ha hecho una oferta por %s. ¡Revisa la sección Plantilla!" % [buyer.name, p.full_name]
	_set_notice(msg)
	_refresh_squad_badge()


func _fmt_short(amount: int) -> String:
	if amount >= 1_000_000:
		return "%.1fM€" % (amount / 1_000_000.0)
	elif amount >= 1_000:
		return "%.0fK€" % (amount / 1_000.0)
	return "%d€" % amount
