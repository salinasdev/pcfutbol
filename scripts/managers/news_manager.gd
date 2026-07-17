## Genera noticias semanales basadas en el estado real del juego.
## Autoload: NewsManager
extends Node

enum Category { RESULTADO, FICHAJES, ENTREVISTA, RUMORES, VESTUARIO, CLASIFICACION, TABLOID, ENTRENADORES }

const CAT_LABEL := {
	Category.RESULTADO:     "⚽ RESULTADO",
	Category.FICHAJES:      "💶 FICHAJES",
	Category.ENTREVISTA:    "🎙️ ENTREVISTA",
	Category.RUMORES:       "🗞️ RUMORES",
	Category.VESTUARIO:     "🏟️ VESTUARIO",
	Category.CLASIFICACION: "📊 CLASIFICACIÓN",
	Category.TABLOID:       "🐀 EL PUPAS",
	Category.ENTRENADORES:  "🧥 ENTRENADORES",
}

const CAT_COLOR := {
	Category.RESULTADO:     Color(0.3, 0.8, 0.4, 1),
	Category.FICHAJES:      Color(0.9, 0.75, 0.2, 1),
	Category.ENTREVISTA:    Color(0.4, 0.7, 1.0, 1),
	Category.RUMORES:       Color(0.8, 0.5, 0.9, 1),
	Category.VESTUARIO:     Color(0.7, 0.7, 0.7, 1),
	Category.CLASIFICACION: Color(0.9, 0.6, 0.2, 1),
	Category.TABLOID:       Color(1.0, 0.85, 0.0, 1),
	Category.ENTRENADORES:  Color(0.9, 0.4, 0.2, 1),
}

var news_feed: Array[Dictionary] = []
var _last_reported_player_matchday: int = 0

# ---------------------------------------------------------------------------
# Tabla de derbis — pares de nombres canónicos de equipo y su nombre de derby

## Cada entrada: { "teams": [nameA, nameB], "name": "nombre del derbi" }
const DERBY_MATCHES: Array = [
	{"teams": ["Real Madrid",        "FC Barcelona"],          "name": "El Clásico"},
	{"teams": ["Real Madrid",        "Atlético de Madrid"],    "name": "Derbi Madrileño"},
	{"teams": ["Sevilla FC",         "Real Betis"],            "name": "Derbi Sevillano"},
	{"teams": ["Athletic Club",      "Real Sociedad"],         "name": "Derbi Vasco"},
	{"teams": ["Deportivo Alavés",   "Athletic Club"],         "name": "Derbi Vasco"},
	{"teams": ["Deportivo Alavés",   "Real Sociedad"],         "name": "Derbi Vasco"},
	{"teams": ["RC Celta",           "Deportivo de La Coruña"],"name": "Derbi Gallego"},
	{"teams": ["Valencia CF",        "Villarreal CF"],         "name": "Derbi de la Comunitat"},
	{"teams": ["Valencia CF",        "Levante UD"],            "name": "Derbi Valenciano"},
	{"teams": ["Levante UD",         "Villarreal CF"],         "name": "Derbi de la Comunitat"},
	{"teams": ["Rayo Vallecano",     "Getafe CF"],             "name": "Derbi del Sur de Madrid"},
	{"teams": ["RCD Espanyol",       "FC Barcelona"],          "name": "Derbi Barcelonés"},
]

## Devuelve el nombre del derbi si el partido es uno, o "" si no lo es.
func get_derby_name(home_name: String, away_name: String) -> String:
	for d: Dictionary in DERBY_MATCHES:
		var t: Array = d["teams"]
		if (home_name == t[0] and away_name == t[1]) or \
		   (home_name == t[1] and away_name == t[0]):
			return d["name"]
	return ""

## Conveniencia: recibe IDs de equipo.
func get_derby_name_by_id(home_id: int, away_id: int) -> String:
	var home: Team = GameManager.get_team(home_id)
	var away: Team = GameManager.get_team(away_id)
	if home == null or away == null:
		return ""
	return get_derby_name(home.name, away.name)

# ---------------------------------------------------------------------------
# Plantillas — elegidas según el contexto real, nunca al azar sin filtro

# Victoria: goleada (dif >= 3)
const H_WIN_GOLEADA := [
	"{team} golea al {opp}: contundente {score}",
	"Exhibición del {team}: {score} ante {opp} en la jornada {md}",
	"{team} arrasa al {opp} con un {score} demoledor",
]
# Victoria: normal (dif 1-2)
const H_WIN_NORMAL := [
	"{team} suma tres puntos ante el {opp} ({score})",
	"Importante victoria del {team} frente a {opp}: {score}",
	"{team} se impone al {opp} con un {score} ajustado",
	"Tres puntos de oro para {team} ante {opp}: {score}",
]
# Derrota: goleada sufrida (dif >= 3)
const H_LOSS_HEAVY := [
	"Duro correctivo para {team}: goleado por {opp} con un {score}",
	"{opp} aplasta al {team}: {score} inapelable en la jornada {md}",
	"Noche negra para {team}: {score} ante {opp}",
]
# Derrota: normal
const H_LOSS_NORMAL := [
	"{team} cae ante {opp} en la jornada {md}: {score}",
	"Derrota del {team} frente a {opp}: {score}",
	"{opp} se lleva los tres puntos ante {team}: {score}",
]
# Empate sin goles
const H_DRAW_ZERO := [
	"Cero a cero: {team} y {opp} se frenan mutuamente",
	"Sin goles entre {team} y {opp} en la jornada {md}",
]
# Empate con goles
const H_DRAW_GOALS := [
	"{team} y {opp} se reparten los puntos: {score}",
	"Empate con goles entre {team} y {opp}: {score}",
	"Partido igualado: {team} {score} {opp}",
]
# Resultado rival (local gana)
const H_RIVAL_HOME_WIN := [
	"{home} vence al {away} en la jornada {md}: {score}",
	"Tres puntos para {home} ante {away}: {score}",
]
# Resultado rival (visitante gana)
const H_RIVAL_AWAY_WIN := [
	"{away} gana fuera de casa ante {home}: {score}",
	"Sorpresa en la jornada {md}: {away} vence al {home} a domicilio ({score})",
]
# Resultado rival empate
const H_RIVAL_DRAW := [
	"Empate entre {home} y {away}: {score}",
	"{home} y {away} no se hacen daño ({score}) en la jornada {md}",
]
# Clasificación: líder
const H_CLASIFICACION_LIDER := [
	"{team} sigue líder con {pts} puntos tras la jornada {md}",
	"{team} se afianza en cabeza: {pts} puntos en {md} jornadas",
	"Sólida marcha del {team}: primer clasificado con {pts} puntos",
]
# Clasificación: pelea por el título (pos 2-4)
const H_CLASIFICACION_ARRIBA := [
	"{team} en puestos de cabeza ({pos}º) con {pts} puntos",
	"El {team} aprieta al líder: {pts} puntos y {pos}ª posición",
]
# Clasificación: zona media
const H_CLASIFICACION_MEDIA := [
	"La clasificación, muy apretada: {team} es {pos}º con {pts} puntos",
	"Jornada {md}: el {team} se mantiene en la posición {pos}",
]
# Clasificación: zona descenso (últimos 3)
const H_CLASIFICACION_DESCENSO := [
	"Alerta en {team}: en puestos de descenso con solo {pts} puntos",
	"{team} en la zona peligrosa: {pos}º con {pts} puntos en {md} jornadas",
]
# Entrevista: buena racha
const H_ENTREVISTA_BIEN := [
	"{player}: «Los resultados hablan por sí solos, seguimos trabajando»",
	"«Llevamos {unbeaten} partidos sin perder y estamos muy confiados» — {player}",
	"{player}: «El equipo está compenetrado, se nota en el campo»",
]
# Entrevista: mala racha
const H_ENTREVISTA_MAL := [
	"{player}: «Llevamos {without_win} partidos sin ganar, hay que reaccionar»",
	"«No estamos rindiendo al nivel que exige el míster» — {player}",
	"{player}: «Esta dinámica hay que cambiarla cuanto antes»",
]
# Entrevista: situación neutral
const H_ENTREVISTA_NEUTRAL := [
	"{player}: «Partido a partido, así llegamos al objetivo»",
	"«Es una temporada larga y hay que mantenerse concentrados» — {player}",
	"{player}: «El vestuario está unido, eso es lo más importante»",
]
const HEADLINES_TRANSFER_RUMOR := [
	"{team} sondea a {player} del {team2} según fuentes del mercado",
	"¿Fichaje bomba? {player} ({pos}, {team2}) en la agenda de {team}",
	"Contactos entre {team} y el entorno de {player} del {team2}",
	"{player} ({team2}) podría cambiar de aires: {team} sigue su situación",
	"{team} busca refuerzos en {pos} y el nombre de {player} aparece en su lista",
]
const HEADLINES_TRANSFER_DONE := [
	"OFICIAL: {player} ficha por {team} procedente de {team2} por {fee} €",
	"{team} anuncia el fichaje de {player}: llega de {team2} por {fee} €",
	"Cerrado el traspaso: {player} deja {team2} y firma por {team} por {fee} €",
]

# ---------------------------------------------------------------------------
# EL PUPAS — diario sensacionalista que critica al equipo del jugador SIEMPRE

const PUPAS_WIN_GOLEADA := [
	"{team} golea al {opp} ({score}) y aun así fue un espectáculo lamentable",
	"El {opp} les regaló el partido: {score} y el {team} sin enterarse",
	"{score} ante el {opp}: si hubiera rival de verdad, esto no pasa",
]
const PUPAS_WIN_NORMAL := [
	"El {team} se lleva los tres puntos ({score}) por puro accidente",
	"Tres puntos del {team} que no merecen ni el papel en el que están escritos",
	"El {team} gana al {opp} ({score}) pero nadie sabe muy bien cómo",
	"Victoria del {team}: suerte, portero rival y poco más ({score})",
	"¿Eso fue un partido? El {team} sobrevivió al {opp} ({score}) de milagro",
]
const PUPAS_DRAW := [
	"El {team} es incapaz de ganarle al {opp}: punto bochornoso ({score})",
	"Otra vez el {team} dejándose puntos: empate vergonzoso ante {opp} ({score})",
	"No pudieron con el {opp}. El {team} reparte un punto que sobra ({score})",
	"Empate que sabe a derrota para el coleccionista de decepciones: el {team}",
]
const PUPAS_LOSS := [
	"Exactamente lo esperado: el {team} se hunde ante {opp} ({score})",
	"Derrota que no sorprende a nadie: el {team} sigue fiel a sí mismo ({score})",
	"El {team} vuelve a lo suyo: caer ante {opp} con un {score} de manual",
	"Como cada semana, el {team} decepciona. Esta vez el {opp} lo certifica ({score})",
]
const PUPAS_LOSS_HEAVY := [
	"APOCALIPSIS: el {team} encaja un {score} ante {opp} ante la indiferencia general",
	"Papelón histórico del {team}: {score} ante {opp}. El míster debería dimitir",
	"{score}. No hace falta añadir nada más sobre el {team}",
]
const PUPAS_LEADER := [
	"El {team} lidera la clasificación: la competencia debe estar fatal",
	"Primeros con {pts} puntos. Tranquilos, el batacazo llegará",
	"El {team} en lo más alto, pero que nadie se engañe: esto no durará",
	"Líderes el {team}... lo cual dice más del resto que de ellos",
]
const PUPAS_TOP := [
	"El {team} en puestos europeos ({pos}º). Un milagro pasajero con {pts} puntos",
	"{pos}º con {pts} puntos: el {team} disimula bien sus carencias de momento",
	"El {team} arriba ({pos}º) pero el fútbol que exhiben es de tercera división",
]
const PUPAS_MID := [
	"El {team}, mediocre como siempre: {pos}º con {pts} puntos en {md} jornadas",
	"{pos}º. Ni arriba ni abajo. El {team} perpetúa su grisura otra semana más",
	"Jornada {md}: el {team} sigue instalado en la mediocridad ({pos}º, {pts} pts)",
]
const PUPAS_BOTTOM := [
	"Como lo oyen: el {team} está en descenso ({pos}º). Nadie se sorprende",
	"Tercera por abajo. El {team} camina hacia Segunda con paso firme",
	"Lo dijimos al empezar la temporada y lo repetimos: el {team} baja ({pos}º)",
]
const PUPAS_OPENERS := [
	"Nuestro corresponsal en el estadio no da crédito.",
	"Fuentes cercanas al club confirman lo que ya sospechábamos.",
	"Otro domingo, otra vergüenza.",
	"En la redacción de El Pupas llevamos décadas cubriendo el fútbol y pocas veces hemos visto algo así.",
	"No nos gusta regodearnos, pero alguien tiene que decirlo.",
	"El entrenador salió por la puerta de atrás. Comprensible.",
]
const PUPAS_FILLERS := [
	"El vestuario, según nuestras fuentes, huele a derrota incluso cuando gana.",
	"La afición merece algo mejor, aunque ya parece resignada.",
	"El míster compareció en rueda de prensa con cara de no entender qué hace aquí.",
	"El marcador no refleja lo mal que estuvo el equipo. Y eso que el marcador es público.",
	"Dicen que están trabajando en los entrenamientos. Se nota poco, desde luego.",
	"Un experto anónimo nos dijo: 'Con ese nivel, lo raro es que no pierdan más'.",
	"Los jugadores salieron del campo tan rápido que casi no les dio tiempo a aplaudir a la grada.",
	"Nuestro fotógrafo intentó capturar un momento de brillantez. Volvió con la tarjeta vacía.",
]
const PUPAS_CLOSERS := [
	"Desde El Pupas recordamos que seguimos aquí, tomando nota.",
	"Nuestra redacción lleva semanas esperando algo que contar. Seguimos esperando.",
	"El Pupas no tiene favoritismos. Solo tiene la verdad, por incómoda que sea.",
	"Mientras tanto, el presupuesto del club sigue siendo un misterio y los resultados, una broma.",
	"Suscríbase a El Pupas: el único diario que le dice lo que nadie más se atreve.",
	"Firma: Bartolomé Chinchilla, redactor jefe. Que conste en acta.",
]

# ---------------------------------------------------------------------------
# Generador semanal

func generate_weekly_news() -> void:
	var new_items: Array[Dictionary] = []
	var week := GameManager.current_week
	var player_team := GameManager.get_player_team()
	var any_league := GameManager.leagues.values()
	var league_started := not any_league.is_empty() and (any_league[0] as League).current_matchday >= 1

	# 1. Resultado del partido propio — busca el último jugado, sin depender de active_fixture
	if player_team != null:
		var last_f := _get_last_fixture(player_team)
		if not last_f.is_empty() and last_f.get("matchday", 0) > _last_reported_player_matchday:
			new_items.append(_news_from_fixture(last_f, player_team))
			_last_reported_player_matchday = last_f.get("matchday", 0)

	# 2. Resultado más destacado de la jornada entre equipos rivales
	var rival := _best_rival_result_news(player_team)
	if not rival.is_empty():
		new_items.append(rival)

	# 3. Clasificación (cada 2 semanas o si el equipo del jugador acaba de cambiar de zona)
	if week % 2 == 0 or _zone_changed_this_week(player_team):
		var cls := _standings_news(player_team)
		if not cls.is_empty():
			new_items.append(cls)

	# 4. Entrevista de un jugador del equipo del jugador (solo si jugaron recientemente)
	if player_team != null and _team_played_recently(player_team):
		new_items.append(_interview_news(player_team))

	# 5. El Pupas — crítica semanal SIEMPRE (solo si la liga ha empezado)
	if league_started:
		new_items.append(_tabloid_news(player_team))

	# 6. Rumor de fichaje (40 % de probabilidad, solo si hay jornadas jugadas)
	if league_started and randf() < 0.40:
		var rumor := _transfer_rumor_news(player_team)
		if not rumor.is_empty():
			new_items.append(rumor)

	for item: Dictionary in new_items:
		if not item.is_empty():
			item["week"] = week
			news_feed.push_front(item)
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
	var md: int = f.get("matchday", 0)
	var score_str: String = "%d-%d" % [hg, ag]

	var is_home: bool = (player_team != null and player_team.id == home.id)
	var my_team: Team  = home if is_home else away
	var opp: Team      = away if is_home else home
	var my_g: int      = hg if is_home else ag
	var opp_g: int     = ag if is_home else hg
	var diff: int      = my_g - opp_g

	var headline: String
	var cat := Category.RESULTADO

	if diff > 0:
		var pool: Array = H_WIN_GOLEADA if diff >= 3 else H_WIN_NORMAL
		headline = pool.pick_random()
	elif diff < 0:
		var pool: Array = H_LOSS_HEAVY if -diff >= 3 else H_LOSS_NORMAL
		headline = pool.pick_random()
	else:
		var pool: Array = H_DRAW_ZERO if (my_g == 0) else H_DRAW_GOALS
		headline = pool.pick_random()
		cat = Category.ENTREVISTA

	headline = headline \
		.replace("{team}", my_team.short_name) \
		.replace("{opp}",  opp.short_name) \
		.replace("{score}", score_str) \
		.replace("{md}",   str(md))

	# Cuerpo con datos reales
	var pid: int = _pick_speaker(my_team)
	var speaker := _last_name(pid)
	var pos_own: int  = _get_team_standing_pos(my_team)
	var pos_opp: int  = _get_team_standing_pos(opp)

	var body := "%s %d-%d %s — Jornada %d\n\n" % [home.short_name, hg, ag, away.short_name, md]
	body += "%s (%dº) %s frente a %s (%dº). " % [
		my_team.name, pos_own,
		"venció" if diff > 0 else ("empató" if diff == 0 else "perdió"),
		opp.name, pos_opp,
	]
	body += "%s comentó tras el partido: «%s»" % [speaker, _quote_for_result(diff)]

	return _make_news(cat, headline, body)


# Elige el partido más interesante de la jornada (más goles o mayor diferencia)
func _best_rival_result_news(player_team: Team) -> Dictionary:
	var best_f: Dictionary = {}
	var best_score: int = -1

	for league: League in GameManager.leagues.values():
		var md := league.current_matchday
		if md < 1:
			continue
		for f: Dictionary in league.get_fixtures_for_matchday(md):
			if not f["played"]:
				continue
			var pid: int = player_team.id if player_team else -1
			if f["home_id"] == pid or f["away_id"] == pid:
				continue
			var interest: int = f["home_goals"] + f["away_goals"] + abs(f["home_goals"] - f["away_goals"])
			if interest > best_score:
				best_score = interest
				best_f = f

	if best_f.is_empty():
		return {}

	var home: Team = GameManager.get_team(best_f["home_id"])
	var away: Team = GameManager.get_team(best_f["away_id"])
	if home == null or away == null:
		return {}

	var hg: int = best_f["home_goals"]
	var ag: int = best_f["away_goals"]
	var md: int = best_f.get("matchday", 0)
	var score_str := "%d-%d" % [hg, ag]

	var headline: String
	if hg > ag:
		headline = H_RIVAL_HOME_WIN.pick_random()
	elif ag > hg:
		headline = H_RIVAL_AWAY_WIN.pick_random()
	else:
		headline = H_RIVAL_DRAW.pick_random()

	headline = headline \
		.replace("{home}", home.short_name) \
		.replace("{away}", away.short_name) \
		.replace("{score}", score_str) \
		.replace("{md}", str(md))

	var body := "%s %d-%d %s (Jornada %d)\n\n" % [home.name, hg, ag, away.name, md]
	body += "%s queda %dº y %s %dº en la clasificación." % [
		home.short_name, _get_team_standing_pos(home),
		away.short_name, _get_team_standing_pos(away),
	]

	return _make_news(Category.RESULTADO, headline, body)


func _standings_news(player_team: Team) -> Dictionary:
	for league: League in GameManager.leagues.values():
		var md := league.current_matchday
		if md < 1:
			continue
		var standings := LeagueManager.get_standings(league)
		if standings.size() < 3:
			continue

		var leader: Team = standings[0]
		var total: int   = standings.size()

		# Elegir qué equipo "protagoniza" la noticia: el del jugador
		var focus: Team  = player_team if player_team != null else leader
		var pos: int     = _get_team_standing_pos(focus)
		var pts: int     = focus.get_points()
		var leader_pts: int = leader.get_points()

		var headline: String
		if pos == 1:
			headline = H_CLASIFICACION_LIDER.pick_random()
		elif pos <= 4:
			headline = H_CLASIFICACION_ARRIBA.pick_random()
		elif pos >= total - 2:
			headline = H_CLASIFICACION_DESCENSO.pick_random()
		else:
			headline = H_CLASIFICACION_MEDIA.pick_random()

		headline = headline \
			.replace("{team}", focus.short_name) \
			.replace("{pos}",  str(pos)) \
			.replace("{pts}",  str(pts)) \
			.replace("{md}",   str(md))

		# Cuerpo: top 5 real + posición del equipo del jugador
		var body := "Clasificación tras la jornada %d:\n" % md
		var top_n: int = mini(5, standings.size())
		for i in range(top_n):
			var t: Team = standings[i]
			body += "%d. %s — %d pts (%d-%d-%d) DG %+d\n" % [
				i + 1, t.short_name, t.get_points(),
				t.wins, t.draws, t.losses,
				t.get_goal_difference(),
			]
		if pos > top_n:
			body += "...\n%d. %s — %d pts (%d-%d-%d) DG %+d\n" % [
				pos, focus.short_name, pts,
				focus.wins, focus.draws, focus.losses,
				focus.get_goal_difference(),
			]
		if pos > 1:
			var diff: int = leader_pts - pts
			body += "\n%s está a %d punto(s) del líder (%s)." % [
				focus.short_name, diff, leader.short_name
			]

		return _make_news(Category.CLASIFICACION, headline, body)

	return {}


func _interview_news(player_team: Team) -> Dictionary:
	if player_team == null:
		return _placeholder_news()

	var pid: int    = _pick_speaker(player_team)
	var speaker     := _last_name(pid)
	var form        := _get_team_form(player_team, 5)  # últimos 5 partidos
	var unbeaten    := _count_unbeaten(form)
	var without_win := _count_without_win(form)
	var pos         := _get_team_standing_pos(player_team)
	var total       := _get_league_size(player_team)

	var headline: String
	var body_detail: String

	if without_win >= 3:
		headline = H_ENTREVISTA_MAL.pick_random()
		headline = headline.replace("{without_win}", str(without_win))
		body_detail = "El equipo acumula %d partidos sin ganar. " % without_win
		body_detail += "La situación actual es la posición %d con %d puntos." % [pos, player_team.get_points()]
	elif unbeaten >= 3:
		headline = H_ENTREVISTA_BIEN.pick_random()
		headline = headline.replace("{unbeaten}", str(unbeaten))
		body_detail = "El equipo lleva %d partidos sin perder. " % unbeaten
		body_detail += "Ocupan la posición %d con %d puntos." % [pos, player_team.get_points()]
	else:
		headline = H_ENTREVISTA_NEUTRAL.pick_random()
		body_detail = "%s es %dº con %d puntos (%d-%d-%d)." % [
			player_team.short_name, pos, player_team.get_points(),
			player_team.wins, player_team.draws, player_team.losses,
		]

	headline = headline.replace("{player}", speaker).replace("{team}", player_team.short_name)

	var body := "%s atendió a los medios tras el entrenamiento.\n\n" % speaker
	body += body_detail
	if total > 0 and pos >= total - 2:
		body += "\n\nEl equipo se encuentra en puestos de descenso y necesita sumar puntos cuanto antes."
	elif pos == 1:
		body += "\n\nEl equipo lidera la tabla y afronta las próximas jornadas con confianza."

	return _make_news(Category.ENTREVISTA, headline, body)


func _transfer_rumor_news(player_team: Team) -> Dictionary:
	var candidates: Array = []
	for p: Player in GameManager.players.values():
		if player_team != null and p.team_id == player_team.id:
			continue
		if p.transfer_listed:
			candidates.push_front(p)
		elif candidates.size() < 20:
			candidates.append(p)

	if candidates.is_empty():
		return {}

	var target: Player = candidates.pick_random()
	var seller: Team   = GameManager.get_team(target.team_id)

	# Equipo interesado: 60% el del jugador, 40% uno aleatorio de la liga
	var interested: Team = player_team
	if interested == null or randf() < 0.40:
		var tv: Array = GameManager.teams.values()
		if not tv.is_empty():
			interested = tv.pick_random() as Team

	var val     := TransferManager.calculate_value(target)
	var pos_str := target.get_position_abbr()

	var headline: String = HEADLINES_TRANSFER_RUMOR.pick_random()
	headline = headline \
		.replace("{player}", target.full_name) \
		.replace("{team}",   interested.short_name if interested else "un club") \
		.replace("{team2}",  seller.short_name if seller else "su club") \
		.replace("{pos}",    pos_str)

	var body := "%s (%s, %d años) del %s podría estar en el mercado este verano.\n\n" % [
		target.full_name, pos_str, target.age,
		seller.name if seller else "su club"
	]
	body += "Valorado en %s €, le queda contrato por %d temporada(s)." % [
		_fmt(val), target.contract_years
	]
	if target.transfer_listed:
		body += "\n\nEl club ha confirmado que el jugador puede salir si llega una oferta adecuada."
	else:
		body += "\n\n%s no ha hecho declaraciones al respecto." % target.full_name

	return _make_news(Category.RUMORES, headline, body)


# ---------------------------------------------------------------------------
# Helpers de forma

## Devuelve array de resultados ('W','D','L') de los últimos n partidos del equipo
func _get_team_form(team: Team, n: int) -> Array:
	var results: Array = []
	for league: League in GameManager.leagues.values():
		for md in range(league.current_matchday, 0, -1):
			for f: Dictionary in league.get_fixtures_for_matchday(md):
				if not f["played"]:
					continue
				if f["home_id"] != team.id and f["away_id"] != team.id:
					continue
				var is_home: bool = f["home_id"] == team.id
				var my_g: int = f["home_goals"] if is_home else f["away_goals"]
				var op_g: int = f["away_goals"] if is_home else f["home_goals"]
				if my_g > op_g:
					results.append("W")
				elif my_g < op_g:
					results.append("L")
				else:
					results.append("D")
				if results.size() >= n:
					return results
	return results


func _count_unbeaten(form: Array) -> int:
	var c := 0
	for r in form:
		if r == "W" or r == "D":
			c += 1
		else:
			break
	return c


func _count_without_win(form: Array) -> int:
	var c := 0
	for r in form:
		if r == "D" or r == "L":
			c += 1
		else:
			break
	return c


func _team_played_recently(team: Team) -> bool:
	for league: League in GameManager.leagues.values():
		var md := league.current_matchday
		if md < 1:
			continue
		for f: Dictionary in league.get_fixtures_for_matchday(md):
			if f["played"] and (f["home_id"] == team.id or f["away_id"] == team.id):
				return true
		# Buscar también en md-1 por si la jornada del jugador va desfasada
		if md >= 2:
			for f: Dictionary in league.get_fixtures_for_matchday(md - 1):
				if f["played"] and (f["home_id"] == team.id or f["away_id"] == team.id):
					return true
	return false


func _zone_changed_this_week(team: Team) -> bool:
	if team == null:
		return false
	var pos: int  = _get_team_standing_pos(team)
	var total: int = _get_league_size(team)
	# Notificar si está en las 3 primeras o en las 3 últimas posiciones
	return pos <= 3 or (total > 0 and pos >= total - 2)


func _get_league_size(team: Team) -> int:
	if team == null:
		return 0
	for league: League in GameManager.leagues.values():
		if team.id in league.team_ids:
			return league.team_ids.size()
	return 0


func _tabloid_news(player_team: Team) -> Dictionary:
	if player_team == null:
		return _make_news(Category.TABLOID,
			"Sin equipo que criticar... por ahora",
			"[ El Pupas — el diario que no tiene filtro ]\n\nEl Pupas siempre encuentra un culpable. Esta semana buscamos.")

	var last_f: Dictionary = _get_last_fixture(player_team)
	var headline: String
	var context_body: String

	if not last_f.is_empty():
		var is_home: bool = last_f["home_id"] == player_team.id
		var my_g: int     = last_f["home_goals"] if is_home else last_f["away_goals"]
		var op_g: int     = last_f["away_goals"] if is_home else last_f["home_goals"]
		var diff: int     = my_g - op_g
		var opp: Team     = GameManager.get_team(last_f["away_id"] if is_home else last_f["home_id"])
		var score_str: String
		if is_home:
			score_str = "%d-%d" % [my_g, op_g]
		else:
			score_str = "%d-%d" % [last_f["home_goals"], last_f["away_goals"]]
		var opp_name := opp.short_name if opp else "el rival"

		if diff >= 3:
			headline = PUPAS_WIN_GOLEADA.pick_random()
		elif diff > 0:
			headline = PUPAS_WIN_NORMAL.pick_random()
		elif diff == 0:
			headline = PUPAS_DRAW.pick_random()
		elif diff > -3:
			headline = PUPAS_LOSS.pick_random()
		else:
			headline = PUPAS_LOSS_HEAVY.pick_random()

		headline = headline \
			.replace("{team}",  player_team.short_name) \
			.replace("{opp}",   opp_name) \
			.replace("{score}", score_str)
		context_body = "%s %s al %s (%s) en la jornada %d. " % [
			player_team.short_name,
			"venció" if diff > 0 else ("empató con" if diff == 0 else "cayó ante"),
			opp_name, score_str,
			last_f.get("matchday", 0),
		]
	else:
		# Sin partido reciente → criticar posición en tabla
		var pos: int   = _get_team_standing_pos(player_team)
		var pts: int   = player_team.get_points()
		var total: int = _get_league_size(player_team)
		var md: int    = 0
		for lg: League in GameManager.leagues.values():
			md = lg.current_matchday
			break
		if pos == 1:
			headline = PUPAS_LEADER.pick_random()
		elif pos <= 5:
			headline = PUPAS_TOP.pick_random()
		elif total > 0 and pos >= total - 2:
			headline = PUPAS_BOTTOM.pick_random()
		else:
			headline = PUPAS_MID.pick_random()
		headline = headline \
			.replace("{team}", player_team.short_name) \
			.replace("{pos}",  str(pos)) \
			.replace("{pts}",  str(pts)) \
			.replace("{md}",   str(md))
		context_body = "%s ocupa la posición %d con %d puntos. " % [player_team.short_name, pos, pts]

	var body := "[ El Pupas — el diario que no tiene filtro ]\n\n"
	body += PUPAS_OPENERS.pick_random() + " "
	body += context_body
	body += PUPAS_FILLERS.pick_random() + "\n\n"
	body += PUPAS_CLOSERS.pick_random()

	return _make_news(Category.TABLOID, headline, body)


func _get_last_fixture(team: Team) -> Dictionary:
	var best: Dictionary = {}
	var best_md: int = -1
	for league: League in GameManager.leagues.values():
		for f: Dictionary in league.fixtures:
			if not f["played"]:
				continue
			if f["home_id"] != team.id and f["away_id"] != team.id:
				continue
			if f["matchday"] > best_md:
				best_md = f["matchday"]
				best = f
	return best


func _quote_for_result(diff: int) -> String:
	if diff >= 3:
		return ["Hoy hemos mostrado nuestra mejor versión.",
			"Ha sido un partido casi perfecto.",
			"El equipo estuvo brillante de principio a fin.",
		].pick_random()
	elif diff > 0:
		return ["Tres puntos muy trabajados.",
			"Lo importante era ganar y lo hemos conseguido.",
			"No fue fácil, pero el equipo supo sufrir.",
		].pick_random()
	elif diff == 0:
		return ["Un punto que puede valer mucho al final.",
			"El empate es justo, ambos equipos tuvieron sus opciones.",
			"Hay cosas que mejorar, pero también positivos.",
		].pick_random()
	elif diff > -3:
		return ["Toca analizar lo que ha fallado y seguir adelante.",
			"Una derrota dura. Hay que levantarse para el siguiente.",
			"No hicimos el partido que habíamos preparado.",
		].pick_random()
	else:
		return ["Ha sido un día para olvidar. Hay que reflexionar.",
			"El equipo rival fue superior. No hay excusas.",
			"Esta derrota duele, pero tenemos que reaccionar.",
		].pick_random()


# ---------------------------------------------------------------------------
# Helpers comunes

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
		"Semana de trabajo en los entrenamientos",
		"El cuerpo técnico ha intensificado la preparación de cara a los próximos compromisos.")



# ---------------------------------------------------------------------------
# Noticias de derbis — llamadas desde GameManager

const DERBY_PREVIEW_HEADLINES := [
	"¡{derby}! {home} y {away} se miden en el partido del año",
	"El {derby} está aquí: {home} contra {away}, duelo sin cuartel",
	"Semana grande: llega el {derby} entre {home} y {away}",
	"El {derby} domina todos los titulares: ¿quién ganará esta edición?",
	"{home} vs {away}: el {derby} sacude a toda la afición",
]
const DERBY_WIN_HEADLINES := [
	"¡Histórico! {my_team} se lleva el {derby} ante {opp}: {score}",
	"¡Victoria en el {derby}! {my_team} supera a {opp} con un {score} memorable",
	"El {derby} es nuestro: {my_team} {score} {opp} en un partido épico",
	"¡Gana el {derby}! {my_team} aplasta la ilusión del {opp}: {score}",
]
const DERBY_DRAW_HEADLINES := [
	"Empate dramático en el {derby}: {my_team} y {opp} se neutralizan ({score})",
	"El {derby} termina sin ganador: {my_team} {score} {opp}",
	"Reparto de puntos en un {derby} intenso: {score}",
]
const DERBY_LOSS_HEADLINES := [
	"Derrota dolorosa en el {derby}: {opp} supera a {my_team} ({score})",
	"El {derby} se va con el {opp}: {score} ante {my_team}",
	"El {derby} deja una herida: {my_team} cae ante {opp} ({score})",
]

func add_derby_preview_news(home: Team, away: Team, derby_name: String) -> void:
	var headline: String = DERBY_PREVIEW_HEADLINES.pick_random()
	headline = headline \
		.replace("{derby}", derby_name) \
		.replace("{home}", home.short_name) \
		.replace("{away}", away.short_name)

	var body := "🔥 %s 🔥\n\n" % derby_name
	body += "%s vs %s\n\n" % [home.name, away.name]
	body += "La directiva espera una victoria y los jugadores llegan con la moral por las nubes. El %s siempre es especial: más allá de la clasificación, estos partidos tienen su propia historia y quedan grabados en la memoria de la afición para siempre." % derby_name
	body += "\n\n¡Es el partido más importante de la temporada!"
	_push_news(_make_news(Category.VESTUARIO, headline, body))


func add_derby_result_news(f: Dictionary, player_team: Team, derby_name: String) -> void:
	var home: Team = GameManager.get_team(f["home_id"])
	var away: Team = GameManager.get_team(f["away_id"])
	if home == null or away == null or player_team == null:
		return
	var is_home: bool = f["home_id"] == player_team.id
	var my_team: Team = home if is_home else away
	var opp: Team     = away if is_home else home
	var my_g: int     = f["home_goals"] if is_home else f["away_goals"]
	var opp_g: int    = f["away_goals"] if is_home else f["home_goals"]
	var diff: int     = my_g - opp_g
	var score_str: String = "%d-%d" % [f["home_goals"], f["away_goals"]]

	var headline: String
	if diff > 0:
		headline = DERBY_WIN_HEADLINES.pick_random()
	elif diff == 0:
		headline = DERBY_DRAW_HEADLINES.pick_random()
	else:
		headline = DERBY_LOSS_HEADLINES.pick_random()

	headline = headline \
		.replace("{derby}",   derby_name) \
		.replace("{my_team}", my_team.short_name) \
		.replace("{opp}",     opp.short_name) \
		.replace("{score}",   score_str)

	var body := "🔥 %s — %s %d-%d %s 🔥\n\n" % [derby_name, home.short_name, f["home_goals"], f["away_goals"], away.short_name]
	if diff > 0:
		body += "¡Victoria en el %s! El %s supera al %s y la afición explota de alegría." % [derby_name, my_team.name, opp.name]
	elif diff == 0:
		body += "El %s termina en empate. Ambos equipos comparten los puntos en un partido disputadísimo." % derby_name
	else:
		body += "Derrota en el %s. El %s no pudo con el %s y la hinchada lo sufrirá durante semanas." % [derby_name, my_team.name, opp.name]

	var speaker := _last_name(_pick_speaker(player_team))
	body += "\n\n%s comentó: «%s»" % [speaker, _derby_quote(diff)]
	_push_news(_make_news(Category.RESULTADO, headline, body))


func _derby_quote(diff: int) -> String:
	if diff > 0:
		return [
			"Ganar el derbi es diferente. No hay palabras para describirlo.",
			"Un partido así lo recuerdas toda la vida. Somos los mejores de la ciudad.",
			"Esto es lo que lleva meses esperando la afición. Felicidad total.",
		].pick_random()
	elif diff == 0:
		return [
			"En un derbi, el empate es un resultado digno. Nos lo pusieron muy difícil.",
			"El derbi siempre aprieta. Un punto que sabe a poco, pero el rival tampoco pudo con nosotros.",
		].pick_random()
	else:
		return [
			"La derrota en el derbi duele doble. Lo asumimos y aprendemos.",
			"Es el resultado que más duele en todo el año. Hay que levantarse.",
		].pick_random()



# ---------------------------------------------------------------------------
# Noticias de fichajes — llamadas desde TransferManager

func add_offer_leak_news(player: Player, buyer: Team) -> void:
	var seller: Team = GameManager.get_team(player.team_id)
	var headline: String = HEADLINES_TRANSFER_RUMOR.pick_random()
	headline = headline \
		.replace("{player}", player.full_name) \
		.replace("{team}",   buyer.short_name if buyer else "un club") \
		.replace("{team2}",  seller.short_name if seller else "su club") \
		.replace("{pos}",    player.get_position_abbr())
	var val := TransferManager.calculate_value(player)
	var body := "Fuentes del mercado apuntan a que %s (%s, %d años) del %s ha recibido una oferta formal.\n\n" % [
		player.full_name, player.get_position_abbr(), player.age,
		seller.name if seller else "su club",
	]
	body += "El jugador está valorado en %s €." % _fmt(val)
	_push_news(_make_news(Category.RUMORES, headline, body))


func add_coach_sacked_news(team: Team, old_coach: String, new_coach: String) -> void:
	var headlines_fired := [
		"{team} prescinde de {coach} tras los malos resultados",
		"{coach} destituido: el {team} busca reacción",
		"Fin de la etapa de {coach} en el {team}",
		"El {team} da un golpe de timón y cesa a {coach}",
	]
	var headlines_hired := [
		"{team} presenta a {new_coach} como nuevo técnico",
		"{new_coach} llega al {team} para enderezar el rumbo",
		"{team} apuesta por {new_coach} para salir del bache",
	]
	var headline: String
	if new_coach.is_empty():
		headline = headlines_fired.pick_random()
		headline = headline.replace("{coach}", old_coach).replace("{team}", team.short_name)
		var body := "El %s ha tomado la difícil decisión de cesar a %s tras una racha de malos resultados.\n\nEl club buscará un nuevo técnico en los próximos días." % [team.name, old_coach]
		_push_news(_make_news(Category.ENTRENADORES, headline, body))
	else:
		headline = headlines_hired.pick_random()
		headline = headline.replace("{new_coach}", new_coach).replace("{team}", team.short_name)
		var body := "El %s ha nombrado a %s como su nuevo entrenador.\n\nEl técnico, que sustituye a %s, llega con el objetivo de dar la vuelta a la situación." % [team.name, new_coach, old_coach]
		_push_news(_make_news(Category.ENTRENADORES, headline, body))


func add_transfer_done_news(player: Player, from_team: Team, to_team: Team, fee: int) -> void:
	var headline: String = HEADLINES_TRANSFER_DONE.pick_random()
	headline = headline \
		.replace("{player}", player.full_name) \
		.replace("{team}",   to_team.short_name if to_team else "nuevo club") \
		.replace("{team2}",  from_team.short_name if from_team else "su club") \
		.replace("{fee}",    _fmt(fee))
	var body := "OFICIAL: %s ficha por %s procedente de %s.\n\n" % [
		player.full_name,
		to_team.name if to_team else "nuevo club",
		from_team.name if from_team else "su anterior equipo",
	]
	body += "El traspaso se ha cerrado por %s €. El jugador (%s, %d años) firma por %d temporada(s)." % [
		_fmt(fee), player.get_position_abbr(), player.age, player.contract_years,
	]
	_push_news(_make_news(Category.FICHAJES, headline, body))


func _push_news(item: Dictionary) -> void:
	item["week"] = GameManager.current_week
	news_feed.push_front(item)
	while news_feed.size() > 40:
		news_feed.pop_back()


func _pick_speaker(team: Team) -> int:
	if team == null or team.player_ids.is_empty():
		return -1
	if not team.starting_eleven.is_empty():
		return team.starting_eleven[randi() % team.starting_eleven.size()]
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
	if team == null:
		return 0
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
