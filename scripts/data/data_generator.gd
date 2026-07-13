## Genera ligas, equipos y jugadores ficticios.
## Estructura extensible: añade más entradas a LEAGUE_DEFINITIONS para
## nuevas ligas, divisiones o países sin tocar el resto del código.
extends Node

const FIRST_NAMES: Array[String] = [
	"Alejandro", "Carlos", "David", "Sergio", "Javier", "Marcos",
	"Roberto", "Pablo", "Adrián", "Raúl", "Iván", "Diego",
	"Fernando", "Miguel", "Álvaro", "Rubén", "Víctor", "Hugo",
	"Manuel", "Óscar", "Luis", "Jorge", "Andrés", "Rafael"
]

const LAST_NAMES: Array[String] = [
	"García", "Martínez", "López", "Sánchez", "González", "Rodríguez",
	"Fernández", "Pérez", "Álvarez", "Torres", "Navarro", "Domínguez",
	"Ramos", "Gil", "Serrano", "Moreno", "Jiménez", "Ruiz",
	"Ortega", "Molina", "Delgado", "Herrera", "Suárez", "Vega"
]

## Mapa nombre de equipo → ruta de escudo.
## Usado como fallback al cargar partidas antiguas sin el campo crest.
const TEAM_CRESTS: Dictionary = {
	"Real Madrid":            "res://assets/teams/esp18_madrid.png",
	"FC Barcelona":           "res://assets/teams/esp12_barcelona.png",
	"Atlético de Madrid":     "res://assets/teams/esp2_atleti.png",
	"Sevilla FC":             "res://assets/teams/esp19_sevilla.png",
	"Valencia CF":            "res://assets/teams/esp10_valencia.png",
	"Real Sociedad":          "res://assets/teams/esp9_realsociedad.png",
	"Athletic Club":          "res://assets/teams/esp11_bilbao.png",
	"Real Betis":             "res://assets/teams/esp8_betis.png",
	"Villarreal CF":          "res://assets/teams/esp20_villareal.png",
	"RC Celta":               "res://assets/teams/esp3_vigo.png",
	"RCD Espanyol":           "res://assets/teams/esp14_espanyol.png",
	"CA Osasuna":             "res://assets/teams/esp16_osasuna.png",
	"Rayo Vallecano":         "res://assets/teams/esp17_rayo.png",
	"Getafe CF":              "res://assets/teams/esp5_getafe.png",
	"Deportivo de La Coruña": "res://assets/teams/esp13_depor.png",
	"Deportivo Alavés":       "res://assets/teams/esp1_alaves.png",
	"Málaga CF":              "res://assets/teams/esp6_malaga.png",
	"Elche CF":               "res://assets/teams/esp4_elche.png",
	"Levante UD":             "res://assets/teams/esp15_levante.png",
	"Racing de Santander":    "res://assets/teams/esp7_santander.png",
}

const TEAM_STADIUMS: Dictionary = {
	"Real Madrid":            "res://assets/stadiums/esp18_estadio.jpg",
	"FC Barcelona":           "res://assets/stadiums/esp12_estadio.jpg",
	"Atlético de Madrid":     "res://assets/stadiums/esp2_estadio.jpg",
	"Sevilla FC":             "res://assets/stadiums/esp19_estadio.jpg",
	"Valencia CF":            "res://assets/stadiums/esp10_estadio.jpg",
	"Real Sociedad":          "res://assets/stadiums/esp9_estadio.jpg",
	"Athletic Club":          "res://assets/stadiums/esp11_estadio.jpg",
	"Real Betis":             "res://assets/stadiums/esp8_estadio.jpg",
	"Villarreal CF":          "res://assets/stadiums/esp20_estadio.jpg",
	"RC Celta":               "res://assets/stadiums/esp3_estadio.jpg",
	"RCD Espanyol":           "res://assets/stadiums/esp14_estadio.jpg",
	"CA Osasuna":             "res://assets/stadiums/esp16_estadio.jpg",
	"Rayo Vallecano":         "res://assets/stadiums/esp17_estadio.jpg",
	"Getafe CF":              "res://assets/stadiums/esp5_estadio.jpg",
	"Deportivo de La Coruña": "res://assets/stadiums/esp13_estadio.jpg",
	"Deportivo Alavés":       "res://assets/stadiums/esp1_estadio.jpg",
	"Málaga CF":              "res://assets/stadiums/esp6_estadio.jpg",
	"Elche CF":               "res://assets/stadiums/esp4_estadio.jpg",
	"Levante UD":             "res://assets/stadiums/esp15_estadio.jpg",
	"Racing de Santander":    "res://assets/stadiums/esp7_estadio.jpg",
}

## Definición de todas las ligas disponibles.
## Formato de cada entrada:
##   { name, short, country, flag, level, teams: [[name, short, city, rep, stadium, capacity], ...] }
## Para añadir una nueva liga/país basta con añadir otro Dictionary aquí.
const LEAGUE_DEFINITIONS: Array = [
	{
		"name":    "Primera División",
		"short":   "LaLiga",
		"country": "España",
		"flag":    "ES",
		"level":   1,
		"teams": [
			["Real Madrid",             "RMA", "Madrid",        90, "Santiago Bernabéu",       80_000, "res://assets/teams/esp18_madrid.png"],
			["FC Barcelona",            "FCB", "Barcelona",     88, "Camp Nou",                90_000, "res://assets/teams/esp12_barcelona.png"],
			["Atlético de Madrid",      "ATM", "Madrid",        82, "Civitas Metropolitano",   67_000, "res://assets/teams/esp2_atleti.png"],
			["Sevilla FC",              "SEV", "Sevilla",       76, "Ramón Sánchez-Pizjuán",  43_000, "res://assets/teams/esp19_sevilla.png"],
			["Valencia CF",             "VLC", "Valencia",      74, "Mestalla",                50_000, "res://assets/teams/esp10_valencia.png"],
			["Real Sociedad",           "RSO", "San Sebastián", 70, "Reale Arena",             39_000, "res://assets/teams/esp9_realsociedad.png"],
			["Athletic Club",           "ATH", "Bilbao",        68, "San Mamés",               53_000, "res://assets/teams/esp11_bilbao.png"],
			["Real Betis",              "BET", "Sevilla",       67, "Benito Villamarín",       60_000, "res://assets/teams/esp8_betis.png"],
			["Villarreal CF",           "VIL", "Villarreal",    65, "Estadio de la Cerámica",  24_000, "res://assets/teams/esp20_villareal.png"],
			["RC Celta",                "CEL", "Vigo",          60, "Abanca Balaídos",         30_000, "res://assets/teams/esp3_vigo.png"],
			["RCD Espanyol",            "ESP", "Barcelona",     58, "RCDE Stadium",            40_000, "res://assets/teams/esp14_espanyol.png"],
			["CA Osasuna",              "OSA", "Pamplona",      57, "El Sadar",                20_000, "res://assets/teams/esp16_osasuna.png"],
			["Rayo Vallecano",          "RAY", "Madrid",        55, "Campo de Vallecas",       15_000, "res://assets/teams/esp17_rayo.png"],
			["Getafe CF",               "GET", "Getafe",        54, "Coliseum Alfonso Pérez",  17_000, "res://assets/teams/esp5_getafe.png"],
			["Deportivo de La Coruña",  "DEP", "La Coruña",     53, "Riazor",                  33_000, "res://assets/teams/esp13_depor.png"],
			["Deportivo Alavés",        "ALA", "Vitoria",       52, "Mendizorroza",            20_000, "res://assets/teams/esp1_alaves.png"],
			["Málaga CF",               "MAL", "Málaga",        51, "La Rosaleda",             30_000, "res://assets/teams/esp6_malaga.png"],
			["Elche CF",                "ELC", "Elche",         50, "Martínez Valero",         33_000, "res://assets/teams/esp4_elche.png"],
			["Levante UD",              "LEV", "Valencia",      48, "Ciutat de València",      25_000, "res://assets/teams/esp15_levante.png"],
			["Racing de Santander",     "RAC", "Santander",     47, "El Sardinero",            22_000, "res://assets/teams/esp7_santander.png"],
		]
	},
	## ── Futuras ligas (descomentar y completar según necesidad) ──────────────
	# {
	# 	"name":    "Segunda División",
	# 	"short":   "LaLiga2",
	# 	"country": "España",
	# 	"flag":    "ES",
	# 	"level":   2,
	# 	"teams": [ ... ]
	# },
	# {
	# 	"name":    "Premier League",
	# 	"short":   "PL",
	# 	"country": "Inglaterra",
	# 	"flag":    "EN",
	# 	"level":   1,
	# 	"teams": [ ... ]
	# },
]


## Genera TODAS las ligas definidas. Llamar antes de que el jugador elija equipo.
func generate_all() -> void:
	for def: Dictionary in LEAGUE_DEFINITIONS:
		_generate_league(def)


func _generate_league(def: Dictionary) -> void:
	var league := League.new()
	league.name    = def["name"]
	league.country = def["country"]
	league.season  = GameManager.season
	GameManager.register_league(league)

	for td: Array in def["teams"]:
		var t := Team.new()
		t.name             = td[0]
		t.short_name       = td[1]
		t.city             = td[2]
		t.reputation       = td[3]
		t.stadium_name     = td[4]
		t.stadium_capacity = td[5]
		t.crest            = td[6] if td.size() > 6 else ""
		t.stadium_image    = DataGenerator.TEAM_STADIUMS.get(t.name, "")
		t.budget           = td[3] * 80_000
		t.weekly_wage_budget = td[3] * 5_000
		t.league_id        = league.id
		GameManager.register_team(t)
		league.team_ids.append(t.id)
		_fill_squad(t)

	LeagueManager.generate_fixtures(league)


## Crea 22 jugadores (1 GK, 5 DEF, 7 MID, 5 FWD + 4 reservas) para un equipo
func _fill_squad(team: Team) -> void:
	var lineup_slots: Array[Player.Position] = [
		Player.Position.GK,
		Player.Position.DEF, Player.Position.DEF, Player.Position.DEF, Player.Position.DEF,
		Player.Position.MID, Player.Position.MID, Player.Position.MID,
		Player.Position.FWD, Player.Position.FWD, Player.Position.FWD,
	]
	var bench_positions: Array[Player.Position] = [
		Player.Position.GK,
		Player.Position.DEF, Player.Position.DEF,
		Player.Position.MID, Player.Position.MID,
		Player.Position.FWD, Player.Position.FWD,
		Player.Position.DEF, Player.Position.MID, Player.Position.FWD,
		Player.Position.MID,
	]

	var all_positions: Array[Player.Position] = []
	all_positions.append_array(lineup_slots)
	all_positions.append_array(bench_positions)

	var number := 1
	for pos: Player.Position in all_positions:
		var p := _create_player(pos, team.reputation)
		p.number    = number
		p.team_id   = team.id
		GameManager.register_player(p)
		team.player_ids.append(p.id)
		if number <= 11:
			team.starting_eleven.append(p.id)
		number += 1

	# Primeros 5 no titulares como suplentes convocados
	for pid: int in team.player_ids:
		if not team.starting_eleven.has(pid):
			team.bench.append(pid)
			if team.bench.size() >= 5:
				break


func _create_player(pos: Player.Position, team_rep: int) -> Player:
	var p     := Player.new()
	p.full_name  = FIRST_NAMES.pick_random() + " " + LAST_NAMES.pick_random()
	p.age        = randi_range(17, 35)
	p.position   = pos

	# Rango de habilidad según reputación del equipo (escala 1–99)
	var base: int = clamp(team_rep, 30, 88)
	var lo: int = max(1, base - 18)
	var hi: int = min(99, base + 12)

	p.pace       = randi_range(lo, hi)
	p.shooting   = randi_range(lo, hi)
	p.passing    = randi_range(lo, hi)
	p.dribbling  = randi_range(lo, hi)
	p.defending  = randi_range(lo, hi)
	p.physical   = randi_range(lo, hi)
	p.goalkeeping = randi_range(lo, hi) if pos == Player.Position.GK else randi_range(1, 25)

	p.salary        = p.get_overall() * randi_range(800, 1_400)
	p.market_value  = TransferManager.calculate_value(p)
	p.contract_years = randi_range(1, 5)
	p.morale     = randi_range(55, 95)
	p.fitness    = randi_range(70, 100)
	return p
