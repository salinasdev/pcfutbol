## Genera noticias semanales basadas en el estado real del juego.
## Autoload: NewsManager
extends Node

enum Category { RESULTADO, FICHAJES, ENTREVISTA, RUMORES, VESTUARIO, CLASIFICACION }

const CAT_LABEL := {
	Category.RESULTADO:     "⚽ RESULTADO",
	Category.FICHAJES:      "💶 FICHAJES",
	Category.ENTREVISTA:    "🎙️ ENTREVISTA",
	Category.RUMORES:       "🗞️ RUMORES",
	Category.VESTUARIO:     "🏟️ VESTUARIO",
	Category.CLASIFICACION: "📊 CLASIFICACIÓN",
}

const CAT_COLOR := {
	Category.RESULTADO:     Color(0.3, 0.8, 0.4, 1),
	Category.FICHAJES:      Color(0.9, 0.75, 0.2, 1),
	Category.ENTREVISTA:    Color(0.4, 0.7, 1.0, 1),
	Category.RUMORES:       Color(0.8, 0.5, 0.9, 1),
	Category.VESTUARIO:     Color(0.7, 0.7, 0.7, 1),
	Category.CLASIFICACION: Color(0.9, 0.6, 0.2, 1),
}

## Lista de noticias de las últimas semanas
var news_feed: Array[Dictionary] = []

# ---------------------------------------------------------------------------
# Plantillas de titulares y cuerpos

const HEADLINES_WIN := [
	"«Sabíamos que podíamos ganar, el trabajo es de todos» — {player}",
	"{player}: «Este triunfo es para la afición, que lo merecía»",
	"Tres puntos de oro para {team}: «Seguimos creyendo» — {player}",
	"«El vestuario está enchufado, esto es solo el principio» — {player}",
	"{team} golea y el capitán {player} advierte: «A por más»",
]
const HEADLINES_LOSS := [
	"«Hay que levantar la cabeza y seguir trabajando» — {player}",
	"{player} después de la derrota: «No fue nuestro mejor día»",
	"«Duele perder así, pero el equipo tiene carácter» — {player}",
	"Dura derrota de {team}. {player}: «Esto no se repetirá»",
	"«Hemos regalado el partido, punto» — {player}, autocrítico",
]
const HEADLINES_DRAW := [
	"«Un punto que sabe a poco, merecíamos más» — {player}",
	"{player}: «El empate no nos vale, tenemos que mejorar»",
	"«Hay cosas buenas, pero también hay que mejorar» — {player}",
	"«Seguimos invictos, eso es importante» — {player} tras el empate",
]

const HEADLINES_TRANSFER_RUMOR := [
	"El {team} sigue de cerca a {player} del {team2}, según fuentes cercanas",
	"¿Fichaje bomba? {player} podría cambiar de aires este mercado",
	"Agentes de {player} confirman contactos con varios clubes",
	"{team} prepara una oferta millonaria por {player}",
	"{player} estaría «abierto» a escuchar propuestas según su entorno",
	"El técnico de {team} pide un '9' de nivel: {player} en la agenda",
]
const HEADLINES_TRANSFER_DONE := [
	"OFICIAL: {player} firma por {team} tras superar el reconocimiento médico",
	"{team} anuncia el fichaje de {player}: «Estoy muy ilusionado»",
	"El {team2} vende a {player} al {team} por {fee} millones",
]

const HEADLINES_STANDINGS := [
	"{team} lidera con autoridad: «El objetivo es mantenernos arriba» — {player}",
	"El {team} cae a puestos de descenso y el vestuario pide calma",
	"«Estamos en zona Champions y no lo vamos a tirar» — {player} de {team}",
	"Solo tres puntos separan a {team} del liderato",
	"«Liga abiertísima», dice {player}: «Cualquiera puede ganar»",
]

const BODIES_INTERVIEW := [
	"En rueda de prensa, {player} fue claro: «{quote}»",
	"Ante los medios, {player} respondió sin rodeos: «{quote}»",
	"Visiblemente emocionado, {player} comentó: «{quote}»",
	"{player} atendió a la prensa con una sonrisa: «{quote}»",
]

const QUOTES_POSITIVE := [
	"El equipo está muy unido, se nota en el campo.",
	"Trabajamos todos los días para esto. El esfuerzo tiene su recompensa.",
	"El míster nos pide presión alta y lo estamos logrando.",
	"Hay calidad en esta plantilla, solo hay que creer.",
	"La afición nos empuja. Sin ellos no seríamos nada.",
	"Cada partido es una final para nosotros y así lo afrontamos.",
]
const QUOTES_NEGATIVE := [
	"No hicimos lo que habíamos entrenado. Hay que reflexionar.",
	"Hay que mirar hacia adelante. Los errores se corrigen en el campo.",
	"Ha sido un partido para olvidar, pero el vestuario está fuerte.",
	"Duele perder así, sobre todo por los aficionados que vinieron.",
	"El míster ya nos ha dicho lo que hay que mejorar. A trabajar.",
	"No estuvimos acertados. Mañana a entrenar con más intensidad.",
]

# ---------------------------------------------------------------------------

## Genera las noticias de la semana. Llamar desde advance_week().
func generate_weekly_news() -> void:
	var new_items: Array[Dictionary] = []
	var week := GameManager.current_week
	var player_team := GameManager.get_player_team()

	# 1. Noticias de resultado del partido del jugador (si hubo)
	if not GameManager.active_fixture.is_empty():
		var f: Dictionary = GameManager.active_fixture
		if f.get("played", false):
			new_items.append(_news_from_fixture(f, player_team))

	# 2. Noticia de resultado de un partido rival aleatorio
	var rival_news := _random_rival_result_news(player_team)
	if rival_news != null:
		new_items.append(rival_news)

	# 3. Rumor de fichaje (basado en jugadores en venta o aleatorio)
	if randf() < 0.7:
		new_items.append(_transfer_rumor_news(player_team))

	# 4. Entrevista de jugador del equipo del jugador
	if player_team != null and not player_team.player_ids.is_empty():
		new_items.append(_interview_news(player_team))

	# 5. Noticia de clasificación (cada 3 semanas)
	if week % 3 == 0:
		new_items.append(_standings_news(player_team))

	for item: Dictionary in new_items:
		if item != null:
			item["week"] = week
			news_feed.push_front(item)

	# Mantener máximo 40 noticias
	while news_feed.size() > 40:
		news_feed.pop_back()


# ---------------------------------------------------------------------------
# Constructores de noticias

func _news_from_fixture(f: Dictionary, player_team: Team) -> Dictionary:
	var home: Team = GameManager.get_team(f["home_id"])
	var away: Team = GameManager.get_team(f["away_id"])
	if home == null or away == null:
		return _placeholder_news()

	var hg: int = f["home_goals"]
	var ag: int = f["away_goals"]

	var is_home: bool = (player_team != null and player_team.id == home.id)
	var my_goals: int = hg if is_home else ag
	var opp_goals: int = ag if is_home else hg
	var opp: Team = away if is_home else home

	var won := my_goals > opp_goals
	var drew := my_goals == opp_goals

	var templates: Array = HEADLINES_WIN if won else (HEADLINES_DRAW if drew else HEADLINES_LOSS)
	var quotes: Array = QUOTES_POSITIVE if won or drew else QUOTES_NEGATIVE

	var pid: int = _pick_speaker(player_team) if player_team != null else -1
	var speaker := _last_name(pid)
	var team_name := player_team.short_name if player_team != null else "???"

	var headline: String = templates.pick_random()
	headline = headline.replace("{player}", speaker).replace("{team}", team_name)

	var body_template: String = BODIES_INTERVIEW.pick_random()
	var body: String = body_template.replace("{player}", speaker).replace("{quote}", quotes.pick_random())
	body += "\n\n%s %d-%d %s (Jornada %d)" % [home.short_name, hg, ag, away.short_name, f.get("matchday", 0)]

	return _make_news(Category.RESULTADO if not drew else Category.ENTREVISTA, headline, body)


func _random_rival_result_news(player_team: Team) -> Dictionary:
	# Buscar un fixture reciente de otro equipo
	for league: League in GameManager.leagues.values():
		var md := league.current_matchday
		if md < 1:
			continue
		var fixtures := league.get_fixtures_for_matchday(md)
		var rivals: Array = []
		for f: Dictionary in fixtures:
			if not f["played"]:
				continue
			var pid: int = player_team.id if player_team else -1
			if f["home_id"] != pid and f["away_id"] != pid:
				rivals.append(f)
		if rivals.is_empty():
			continue
		var f: Dictionary = rivals.pick_random()
		var home: Team = GameManager.get_team(f["home_id"])
		var away: Team = GameManager.get_team(f["away_id"])
		if home == null or away == null:
			continue
		var speaker_team: Team = home if randf() < 0.5 else away
		var pid: int = _pick_speaker(speaker_team)
		var won: bool = (speaker_team.id == home.id and f["home_goals"] > f["away_goals"]) or \
				   (speaker_team.id == away.id and f["away_goals"] > f["home_goals"])
		var templates: Array = HEADLINES_WIN if won else HEADLINES_LOSS
		var headline: String = templates.pick_random()
		headline = headline.replace("{player}", _last_name(pid)).replace("{team}", speaker_team.short_name)
		var body := "%s %d-%d %s\n\n%s tras el partido: «%s»" % [
			home.short_name, f["home_goals"], f["away_goals"], away.short_name,
			_last_name(pid),
			(QUOTES_POSITIVE if won else QUOTES_NEGATIVE).pick_random()
		]
		return _make_news(Category.RESULTADO, headline, body)
	return _placeholder_news()


func _transfer_rumor_news(player_team: Team) -> Dictionary:
	# Buscar un jugador en venta o elegir uno aleatorio de otro equipo
	var candidates: Array = []
	for p: Player in GameManager.players.values():
		if player_team != null and p.team_id == player_team.id:
			continue
		if p.transfer_listed:
			candidates.push_front(p)   # Prioritarios
		elif candidates.size() < 30:
			candidates.append(p)

	if candidates.is_empty():
		return _placeholder_news()

	var target: Player = candidates.pick_random()
	var seller: Team = GameManager.get_team(target.team_id)

	# Equipo interesado: 50% el del jugador, 50% uno aleatorio
	var interested: Team = player_team
	if interested == null or randf() < 0.5:
		var team_vals: Array = GameManager.teams.values()
		interested = team_vals.pick_random() as Team

	var headline: String = HEADLINES_TRANSFER_RUMOR.pick_random()
	headline = headline.replace("{player}", _last_name(target.id)) \
		.replace("{team}", interested.short_name if interested else "un grande") \
		.replace("{team2}", seller.short_name if seller else "su club")

	var val := TransferManager.calculate_value(target)
	var body := "Según fuentes del mercado, %s (%s) podría cambiar de equipo este mercado.\n\n" % [
		target.full_name, target.get_position_abbr()
	]
	body += "Valorado en %s €, el jugador de %d años tiene contrato por %d temporada(s) más." % [
		_fmt(val), target.age, target.contract_years
	]
	if target.transfer_listed:
		body += "\n\nFuentes del club confirman que el jugador está disponible para su venta."

	return _make_news(Category.RUMORES if not target.transfer_listed else Category.FICHAJES, headline, body)


func _interview_news(player_team: Team) -> Dictionary:
	var pid: int = _pick_speaker(player_team)
	var speaker := _last_name(pid)

	var standing_pos := _get_team_standing_pos(player_team)
	var is_top: bool = standing_pos <= 4
	var is_bottom: bool = standing_pos > 15
	var quotes: Array = QUOTES_POSITIVE if is_top else (QUOTES_NEGATIVE if is_bottom else QUOTES_POSITIVE)

	var headline: String = "«%s» — %s, en exclusiva" % [quotes.pick_random(), speaker]
	var body_tpl: String = BODIES_INTERVIEW.pick_random()
	var body: String = body_tpl.replace("{player}", speaker).replace("{quote}", quotes.pick_random())
	body += "\n\n%s ocupa la posición %d en la clasificación." % [player_team.short_name, standing_pos]

	return _make_news(Category.ENTREVISTA, headline, body)


func _standings_news(player_team: Team) -> Dictionary:
	# Coger el líder de la primera liga
	var headline := ""
	var body := ""
	for league: League in GameManager.leagues.values():
		var standings := LeagueManager.get_standings(league)
		if standings.is_empty():
			continue
		var leader: Team = standings[0]
		var pid: int = _pick_speaker(leader)
		headline = HEADLINES_STANDINGS.pick_random()
		headline = headline.replace("{team}", leader.short_name).replace("{player}", _last_name(pid))
		body = "Tras la jornada %d, %s encabeza la tabla con %d puntos.\n\n" % [
			league.current_matchday, leader.name, leader.get_points()
		]
		if player_team != null:
			var my_pos := _get_team_standing_pos(player_team)
			body += "%s se encuentra en la posición %d con %d puntos." % [
				player_team.name, my_pos, player_team.get_points()
			]
		break
	if headline.is_empty():
		return _placeholder_news()
	return _make_news(Category.CLASIFICACION, headline, body)


# ---------------------------------------------------------------------------
# Helpers

func _make_news(cat: Category, headline: String, body: String) -> Dictionary:
	return {
		"category": cat,
		"cat_label": CAT_LABEL[cat],
		"cat_color": CAT_COLOR[cat],
		"headline":  headline,
		"body":      body,
		"week":      GameManager.current_week,
	}


func _placeholder_news() -> Dictionary:
	return _make_news(Category.VESTUARIO,
		"Semana de trabajo intenso en los entrenamientos",
		"El cuerpo técnico ha preparado una sesión doble buscando afinar la puesta a punto del equipo de cara a los próximos compromisos.")


func _pick_speaker(team: Team) -> int:
	if team == null or team.player_ids.is_empty():
		return -1
	# Preferir titulares
	if not team.starting_eleven.is_empty():
		var idx := randi() % team.starting_eleven.size()
		return team.starting_eleven[idx]
	return team.player_ids[randi() % team.player_ids.size()]


func _last_name(pid: int) -> String:
	if pid == -1:
		return "el capitán"
	var p: Player = GameManager.get_player(pid)
	if p == null:
		return "el jugador"
	var parts := p.full_name.split(" ")
	return parts[parts.size() - 1]


func _get_team_standing_pos(team: Team) -> int:
	for league: League in GameManager.leagues.values():
		var standings := LeagueManager.get_standings(league)
		for i in range(standings.size()):
			if (standings[i] as Team).id == team.id:
				return i + 1
	return 0


func _fmt(amount: int) -> String:
	if amount >= 1_000_000:
		return "%.1fM" % (amount / 1_000_000.0)
	elif amount >= 1_000:
		return "%dK" % (amount / 1_000)
	return str(amount)
