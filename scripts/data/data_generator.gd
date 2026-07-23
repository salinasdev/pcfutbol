## Genera ligas, equipos y jugadores ficticios.
## Estructura extensible: añade más entradas a LEAGUE_DEFINITIONS para
## nuevas ligas, divisiones o países sin tocar el resto del código.
extends Node

var _last_error: String = ""

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

## Entrenadores iniciales por equipo.
const TEAM_COACHES: Dictionary = {
	"Real Madrid":            "Carlo Ancelotti",
	"FC Barcelona":           "Hansi Flick",
	"Atlético de Madrid":     "Diego Simeone",
	"Sevilla FC":             "García Pimienta",
	"Valencia CF":            "Rubén Baraja",
	"Real Sociedad":          "Imanol Alguacil",
	"Athletic Club":          "Ernesto Valverde",
	"Real Betis":             "Manuel Pellegrini",
	"Villarreal CF":          "Marcelino García Toral",
	"RC Celta":               "Claudio Giráldez",
	"RCD Espanyol":           "Manolo González",
	"CA Osasuna":             "Vicente Moreno",
	"Rayo Vallecano":         "Íñigo Pérez",
	"Getafe CF":              "José Bordalás",
	"Deportivo de La Coruña": "Imanol Idiakez",
	"Deportivo Alavés":       "Luis García Plaza",
	"Málaga CF":              "Sergio Pellicer",
	"Elche CF":               "Eder Sarabia",
	"Levante UD":             "Julián Calero",
	"Racing de Santander":    "José Alberto López",
}

## Bolsa de entrenadores libres disponibles para contratar.
const FREE_COACHES: Array[String] = [
	"Rafael Benítez", "Quique Setién", "Michel", "Víctor Fernández",
	"Javi Gracia", "Eduardo Coudet", "Natxo González", "Paco Jémez",
	"Quique Flores", "Diego Martínez", "José Luis Mendilibar",
	"Antonio Mohamed", "Míchel Sánchez", "Juan Carlos Unzué",
	"Pablo Machín", "Pepe Mel", "Álvaro Cervera", "José Rojo Martín",
	"Fernando Vázquez", "Robert Moreno",
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
	_last_error = ""
	for def: Dictionary in LEAGUE_DEFINITIONS:
		_generate_league(def)
	# Poblar la cartera de entrenadores libres
	GameManager.free_coaches.assign(FREE_COACHES.duplicate())


func get_last_error() -> String:
	return _last_error


func generate_from_external_json(file_path: String) -> bool:
	_last_error = ""
	var trimmed_path := file_path.strip_edges()
	if trimmed_path.is_empty():
		_last_error = "Debes indicar la ruta de un JSON."
		return false
	if not FileAccess.file_exists(trimmed_path):
		_last_error = "No existe el archivo JSON indicado."
		return false

	var f := FileAccess.open(trimmed_path, FileAccess.READ)
	if f == null:
		_last_error = "No se pudo abrir el archivo JSON."
		return false

	var raw_text := f.get_as_text()
	var parsed: Variant = JSON.parse_string(raw_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		_last_error = "El JSON no tiene un objeto raíz válido."
		return false

	var root: Dictionary = parsed
	var countries: Array = root.get("f1_countries", [])
	if countries.is_empty():
		_last_error = "El JSON no contiene países (f1_countries)."
		return false

	var created_leagues := 0
	var created_teams := 0

	for c: Dictionary in countries:
		var country_name: String = str(c.get("f1_name", "España"))
		var leagues_in_country: Array = c.get("f3_leagues", [])
		for ldef: Dictionary in leagues_in_country:
			var participants: Array = ldef.get("f3_participants", [])
			if participants.is_empty():
				continue

			var league := League.new()
			league.name = str(ldef.get("f1_name", "Liga"))
			league.country = country_name
			league.season = GameManager.season
			GameManager.register_league(league)
			created_leagues += 1

			for tdef: Dictionary in participants:
				var team := Team.new()
				team.name = str(tdef.get("f01_name", "Equipo"))
				team.short_name = _short_code_from_name(team.name)
				team.city = _city_from_team_name(team.name)
				team.league_id = league.id
				team.formation = str(tdef.get("f03_tactic", "4-4-2"))
				team.stadium_name = ""
				team.stadium_capacity = int(tdef.get("f04_stadiumCapacity", 20_000))
				team.parking_level = _map_stadium_level(int(tdef.get("f05_stadiumParking", 0)), [0, 800, 1800, 3000])
				team.shop_level = _map_stadium_level(int(tdef.get("f06_stadiumShops", 0)), [0, 4, 8, 12])
				team.bathrooms_level = _map_stadium_level(int(tdef.get("f07_stadiumWCs", 0)), [0, 10, 20, 30])
				team.crest = TEAM_CRESTS.get(team.name, "")
				team.stadium_image = TEAM_STADIUMS.get(team.name, "")
				team.coach_name = TEAM_COACHES.get(team.name, "")

				GameManager.register_team(team)
				league.team_ids.append(team.id)
				created_teams += 1

				var lineup: Array = tdef.get("f08_lineupPlayers", [])
				var reserves: Array = tdef.get("f09_reservePlayers", [])
				var all_base_levels: Array[int] = []

				for pdata: Dictionary in lineup:
					var p := _create_player_from_external(pdata, country_name)
					p.team_id = team.id
					GameManager.register_player(p)
					team.player_ids.append(p.id)
					team.starting_eleven.append(p.id)
					all_base_levels.append(int(pdata.get("f04_baseLevel", p.get_overall())))

				for pdata: Dictionary in reserves:
					var p := _create_player_from_external(pdata, country_name)
					p.team_id = team.id
					GameManager.register_player(p)
					team.player_ids.append(p.id)
					team.bench.append(p.id)
					all_base_levels.append(int(pdata.get("f04_baseLevel", p.get_overall())))

				if team.player_ids.is_empty():
					_fill_squad(team)
				else:
					if team.starting_eleven.size() < 11:
						for pid: int in team.player_ids:
							if not team.starting_eleven.has(pid):
								team.starting_eleven.append(pid)
							if team.starting_eleven.size() >= 11:
								break
					if team.bench.size() > 7:
						team.bench = team.bench.slice(0, 7)

				team.reputation = _team_reputation_from_levels(all_base_levels)
				var cash_millions := float(tdef.get("f02_cash", 0.0))
				team.club_cash = maxi(200_000, int(cash_millions * 1_000_000.0))
				team.budget = int(float(team.reputation) * 80_000.0)
				team.weekly_wage_budget = int(float(team.reputation) * 5_000.0)

				for pid: int in team.player_ids:
					var tp: Player = GameManager.get_player(pid)
					if tp:
						tp.market_value = TransferManager.calculate_value(tp)

			LeagueManager.generate_fixtures(league)

	if created_leagues == 0 or created_teams == 0:
		_last_error = "El JSON no contiene ligas o equipos válidos para importar."
		return false

	GameManager.free_coaches.assign(FREE_COACHES.duplicate())
	return true


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
		t.coach_name       = DataGenerator.TEAM_COACHES.get(t.name, "")
		t.budget           = td[3] * 80_000
		t.weekly_wage_budget = td[3] * 5_000
		t.club_cash        = td[3] * 300_000
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

	p.salary        = p.get_overall() * randi_range(200, 400)
	p.market_value  = TransferManager.calculate_value(p)
	p.contract_years = randi_range(1, 5)
	# Cláusula de rescisión para jugadores con cierta calidad
	if p.get_overall() >= 62:
		p.release_clause = int(p.market_value * randf_range(1.5, 2.5) / 100_000.0) * 100_000
	p.morale     = randi_range(55, 95)
	p.fitness    = randi_range(70, 100)
	return p


func _create_player_from_external(def: Dictionary, nationality: String) -> Player:
	var p := Player.new()
	var stat_gk: int = int(def.get("f09_statGoalkeeper", 20))
	var stat_def: int = int(def.get("f10_statDefense", 50))
	var stat_pass: int = int(def.get("f11_statPass", 50))
	var stat_fin: int = int(def.get("f12_statFinishing", 50))
	var stat_shot: int = int(def.get("f13_statShot", 50))
	var stat_drib: int = int(def.get("f14_statDribble", 50))

	p.number = int(def.get("f01_number", 0))
	p.full_name = str(def.get("f02_name", "Jugador"))
	p.age = int(def.get("f03_age", 24))
	p.nationality = nationality
	p.position = _position_from_external(int(def.get("f08_position", 2)))

	p.goalkeeping = clampi(stat_gk, 1, 99)
	p.defending = clampi(stat_def, 1, 99)
	p.passing = clampi(stat_pass, 1, 99)
	p.shooting = clampi(stat_fin, 1, 99)
	p.dribbling = clampi(stat_drib, 1, 99)
	p.pace = clampi(int(round((stat_shot + stat_drib) / 2.0)), 1, 99)
	p.physical = clampi(int(round((stat_def + stat_shot) / 2.0)), 1, 99)

	var salary_source := float(def.get("f05_salary", 1.0))
	p.salary = maxi(1_000, int(salary_source * 6_000.0))

	var value_source := float(def.get("f06_value", 1.0))
	p.market_value = maxi(50_000, int(value_source * 1_000_000.0))
	p.contract_years = maxi(1, int(def.get("f07_contractYears", 2)))
	if p.get_overall() >= 62:
		p.release_clause = int(p.market_value * 2.0 / 100_000.0) * 100_000

	p.morale = randi_range(60, 95)
	p.fitness = randi_range(70, 100)
	p.energy = 100
	return p


func _position_from_external(pos: int) -> Player.Position:
	match pos:
		0:
			return Player.Position.GK
		1:
			return Player.Position.DEF
		2:
			return Player.Position.MID
		3:
			return Player.Position.FWD
	return Player.Position.MID


func _team_reputation_from_levels(levels: Array[int]) -> int:
	if levels.is_empty():
		return 50
	var total := 0
	for lv: int in levels:
		total += lv
	return clampi(int(round(float(total) / float(levels.size()))), 35, 95)


func _map_stadium_level(value: int, thresholds: Array[int]) -> int:
	for i: int in range(thresholds.size() - 1, -1, -1):
		if value >= thresholds[i]:
			return i
	return 0


func _short_code_from_name(name: String) -> String:
	var parts := name.split(" ", false)
	var short_name := ""
	for part: String in parts:
		if part.length() >= 1:
			short_name += part.substr(0, 1).to_upper()
		if short_name.length() >= 3:
			break
	if short_name.length() < 2 and name.length() >= 2:
		short_name = name.substr(0, 3).to_upper()
	return short_name.substr(0, mini(3, short_name.length()))


func _city_from_team_name(name: String) -> String:
	if TEAM_STADIUMS.has(name):
		var known: Dictionary = {
			"Real Madrid": "Madrid",
			"FC Barcelona": "Barcelona",
			"Atlético de Madrid": "Madrid",
			"Sevilla FC": "Sevilla",
			"Valencia CF": "Valencia",
			"Real Sociedad": "San Sebastián",
			"Athletic Club": "Bilbao",
			"Real Betis": "Sevilla",
			"Villarreal CF": "Villarreal",
			"RC Celta": "Vigo",
			"RCD Espanyol": "Barcelona",
			"CA Osasuna": "Pamplona",
			"Rayo Vallecano": "Madrid",
			"Getafe CF": "Getafe",
			"Deportivo de La Coruña": "La Coruña",
			"Deportivo Alavés": "Vitoria",
			"Málaga CF": "Málaga",
			"Elche CF": "Elche",
			"Levante UD": "Valencia",
			"Racing de Santander": "Santander",
		}
		return known.get(name, name)
	return name
