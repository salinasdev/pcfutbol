## Autoload: SaveManager
## Guarda y carga el estado completo del juego en JSON.
extends Node

const SAVE_PATH := "user://savegame.json"


# ---------------------------------------------------------------------------
# Guardar

func save_game() -> void:
	var data := {
		"version": 1,
		"season":         GameManager.season,
		"current_week":   GameManager.current_week,
		"current_date":   GameManager.current_date,
		"player_team_id": GameManager.player_team_id,
		"manager_name":   GameManager.manager_name,
		"_next_player_id": GameManager._next_player_id,
		"_next_team_id":   GameManager._next_team_id,
		"_next_league_id": GameManager._next_league_id,
		"players": _serialize_players(),
		"teams":   _serialize_teams(),
		"leagues": _serialize_leagues(),
		"news_feed": NewsManager.news_feed,
		"active_offers":    TransferManager.active_offers,
		"_next_offer_id":   TransferManager._next_offer_id,
		"incoming_offers":  TransferManager.incoming_offers,
		"_next_incoming_id": TransferManager._next_incoming_id,
		"_last_reported_player_matchday": NewsManager._last_reported_player_matchday,
		"free_coaches":     GameManager.free_coaches,
		"manager_rating":    GameManager.manager_rating,
		"board_confidence":  GameManager.board_confidence,
		"public_confidence": GameManager.public_confidence,
		"bonus_win":          GameManager.bonus_win,
		"bonus_title":        GameManager.bonus_title,
		"bonus_history":      GameManager.bonus_history,
		"reserve_replacement_pool": GameManager.reserve_replacement_pool,
		"manager_matches": GameManager.manager_matches,
		"manager_wins": GameManager.manager_wins,
		"manager_draws": GameManager.manager_draws,
		"manager_losses": GameManager.manager_losses,
		"manager_clubs_managed": GameManager.manager_clubs_managed,
		"manager_offers_received": GameManager.manager_offers_received,
		"manager_offers_accepted": GameManager.manager_offers_accepted,
		"manager_job_offers": GameManager.manager_job_offers,
		"_next_manager_offer_id": GameManager._next_manager_offer_id,
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: no se pudo abrir el archivo para escritura")
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


# ---------------------------------------------------------------------------
# Cargar

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not parsed is Dictionary:
		push_error("SaveManager: JSON corrupto")
		return false

	var data: Dictionary = parsed as Dictionary
	GameManager._reset_state()

	GameManager.season         = data.get("season", 2026)
	GameManager.current_week   = data.get("current_week", 1)
	GameManager.current_date   = data.get("current_date", {"day": 1, "month": 8, "year": 2026})
	GameManager.player_team_id = data.get("player_team_id", -1)
	GameManager.manager_name   = data.get("manager_name", "")
	GameManager._next_player_id = data.get("_next_player_id", 1)
	GameManager._next_team_id   = data.get("_next_team_id", 1)
	GameManager._next_league_id = data.get("_next_league_id", 1)

	_deserialize_players(data.get("players", {}))
	_deserialize_teams(data.get("teams", {}))
	_deserialize_leagues(data.get("leagues", {}))
	NewsManager.news_feed.assign(data.get("news_feed", []))
	TransferManager.active_offers.assign(data.get("active_offers", []))
	TransferManager._next_offer_id = data.get("_next_offer_id", 1)
	TransferManager.incoming_offers.assign(data.get("incoming_offers", []))
	TransferManager._next_incoming_id = data.get("_next_incoming_id", 1)
	NewsManager._last_reported_player_matchday = data.get("_last_reported_player_matchday", 0)
	GameManager.free_coaches.assign(data.get("free_coaches", []))
	GameManager.manager_rating    = data.get("manager_rating",    5.0)
	GameManager.board_confidence  = data.get("board_confidence",  5.0)
	GameManager.public_confidence = data.get("public_confidence", 5.0)
	GameManager.bonus_win         = data.get("bonus_win",         0)
	GameManager.bonus_title       = data.get("bonus_title",       0)
	GameManager.bonus_history.assign(data.get("bonus_history", []))
	GameManager.reserve_replacement_pool = data.get("reserve_replacement_pool", {"España": []})
	GameManager.manager_matches = data.get("manager_matches", 0)
	GameManager.manager_wins = data.get("manager_wins", 0)
	GameManager.manager_draws = data.get("manager_draws", 0)
	GameManager.manager_losses = data.get("manager_losses", 0)
	GameManager.manager_clubs_managed.assign(data.get("manager_clubs_managed", []))
	GameManager.manager_offers_received = data.get("manager_offers_received", 0)
	GameManager.manager_offers_accepted = data.get("manager_offers_accepted", 0)
	GameManager.manager_job_offers.assign(data.get("manager_job_offers", []))
	GameManager._next_manager_offer_id = data.get("_next_manager_offer_id", 1)

	return true


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


# ---------------------------------------------------------------------------
# Serialización jugadores

func _serialize_players() -> Dictionary:
	var out: Dictionary = {}
	for id: int in GameManager.players:
		var p: Player = GameManager.players[id]
		out[str(id)] = {
			"id": p.id, "full_name": p.full_name, "age": p.age,
			"nationality": p.nationality, "position": int(p.position),
			"number": p.number,
			"pace": p.pace, "shooting": p.shooting, "passing": p.passing,
			"dribbling": p.dribbling, "defending": p.defending,
			"physical": p.physical, "goalkeeping": p.goalkeeping,
			"salary": p.salary, "contract_years": p.contract_years,
			"market_value": p.market_value, "transfer_listed": p.transfer_listed,
			"release_clause": p.release_clause, "annual_bonus": p.annual_bonus,
			"join_when": p.join_when,
			"relegation_freedom": p.relegation_freedom,
			"matches_renewal": p.matches_renewal, "matches_renewal_count": p.matches_renewal_count,
			"goal_bonus_active": p.goal_bonus_active, "goal_bonus_amount": p.goal_bonus_amount,
			"house_car": p.house_car,
			"morale": p.morale, "fitness": p.fitness, "energy": p.energy,
			"injured": p.injured, "injury_weeks": p.injury_weeks,
			"team_id": p.team_id,
			"yellow_cards": p.yellow_cards, "suspended": p.suspended,
			"red_carded": p.red_carded,
			"season_goals": p.season_goals, "season_reds": p.season_reds,
		}
	return out


func _deserialize_players(raw: Dictionary) -> void:
	for key: String in raw:
		var d: Dictionary = raw[key]
		var p := Player.new()
		p.id             = d.get("id", 0)
		p.full_name      = d.get("full_name", "")
		p.age            = d.get("age", 20)
		p.nationality    = d.get("nationality", "España")
		p.position       = d.get("position", 0) as Player.Position
		p.number         = d.get("number", 0)
		p.pace           = d.get("pace", 10)
		p.shooting       = d.get("shooting", 10)
		p.passing        = d.get("passing", 10)
		p.dribbling      = d.get("dribbling", 10)
		p.defending      = d.get("defending", 10)
		p.physical       = d.get("physical", 10)
		p.goalkeeping    = d.get("goalkeeping", 1)
		p.salary         = d.get("salary", 5000)
		p.contract_years = d.get("contract_years", 2)
		p.market_value   = d.get("market_value", 100000)
		p.transfer_listed = d.get("transfer_listed", false)
		p.release_clause        = d.get("release_clause", 0)
		p.annual_bonus          = d.get("annual_bonus", 0)
		p.join_when             = d.get("join_when", 0)
		p.relegation_freedom    = d.get("relegation_freedom", false)
		p.matches_renewal       = d.get("matches_renewal", false)
		p.matches_renewal_count = d.get("matches_renewal_count", 0)
		p.goal_bonus_active     = d.get("goal_bonus_active", false)
		p.goal_bonus_amount     = d.get("goal_bonus_amount", 0)
		p.house_car             = d.get("house_car", false)
		p.morale         = d.get("morale", 70)
		p.fitness        = d.get("fitness", 100)
		p.energy         = d.get("energy", 100)
		p.injured        = d.get("injured", false)
		p.injury_weeks   = d.get("injury_weeks", 0)
		p.team_id        = d.get("team_id", -1)
		p.yellow_cards   = d.get("yellow_cards", 0)
		p.suspended      = d.get("suspended", false)
		p.red_carded     = d.get("red_carded", false)
		p.season_goals   = d.get("season_goals", 0)
		p.season_reds    = d.get("season_reds", 0)
		GameManager.players[p.id] = p


# ---------------------------------------------------------------------------
# Serialización equipos

func _serialize_teams() -> Dictionary:
	var out: Dictionary = {}
	for id: int in GameManager.teams:
		var t: Team = GameManager.teams[id]
		out[str(id)] = {
			"id": t.id, "name": t.name, "short_name": t.short_name,
			"city": t.city, "league_id": t.league_id,
			"is_reserve_team": t.is_reserve_team,
			"parent_club_name": t.parent_club_name,
			"budget": t.budget, "weekly_wage_budget": t.weekly_wage_budget,
			"reputation": t.reputation,
			"crest": t.crest,
			"stadium_image": t.stadium_image,
			"stadium_name": t.stadium_name, "stadium_capacity": t.stadium_capacity,
			"player_ids": t.player_ids, "starting_eleven": t.starting_eleven,
			"bench": t.bench,
			"formation": t.formation,
			# Tácticas
			"tactic_attack_style": t.tactic_attack_style,
			"tactic_toque_pct": t.tactic_toque_pct,
			"tactic_counter_pct": t.tactic_counter_pct,
			"tactic_tackle_style": t.tactic_tackle_style,
			"tactic_marking": t.tactic_marking,
			"tactic_clearance": t.tactic_clearance,
			"tactic_press_line": t.tactic_press_line,			"coach_name": t.coach_name,			"wins": t.wins, "draws": t.draws, "losses": t.losses,
			"goals_for": t.goals_for, "goals_against": t.goals_against,
			# Mejoras del estadio
			"stands_level": t.stands_level, "parking_level": t.parking_level,
			"construction_weeks_left": t.construction_weeks_left,
			"construction_item": t.construction_item,
			# Equipamiento
			"lights_level": t.lights_level, "heated_pitch": t.heated_pitch,
			"changing_rooms_level": t.changing_rooms_level,
			"scoreboard_level": t.scoreboard_level, "access_level": t.access_level,
			# Servicios
			"medical_level": t.medical_level, "shop_level": t.shop_level,
			"cafeteria_level": t.cafeteria_level, "bathrooms_level": t.bathrooms_level,
			# Precios
			"ticket_price": t.ticket_price, "drink_price": t.drink_price,
			"merch_price": t.merch_price,
			# Finanzas
			"club_cash": t.club_cash, "season_matchday_income": t.season_matchday_income,
			"loan_amount": t.loan_amount, "loan_weekly_payment": t.loan_weekly_payment,
			"loan_weeks_left": t.loan_weeks_left,
			"finance_history": t.finance_history,
			# Ingresos comerciales
			"tv_deal_tier": t.tv_deal_tier, "tv_deal_weeks_left": t.tv_deal_weeks_left,
			"tv_weekly_income": t.tv_weekly_income,
			"sponsor_id": t.sponsor_id, "sponsor_weeks_left": t.sponsor_weeks_left,
			"sponsor_weekly_income": t.sponsor_weekly_income,
			"merch_stores": t.merch_stores,
			# Personal
			"staff_gk_coach": t.staff_gk_coach, "staff_passing_coach": t.staff_passing_coach,
			"staff_dribbling_coach": t.staff_dribbling_coach, "staff_shooting_coach": t.staff_shooting_coach,
			"staff_tackling_coach": t.staff_tackling_coach, "staff_physical_coach": t.staff_physical_coach,
			"staff_physio": t.staff_physio, "staff_psychologist": t.staff_psychologist,
			"staff_scout": t.staff_scout, "staff_tech_secretary": t.staff_tech_secretary,
			"staff_youth_coach": t.staff_youth_coach, "staff_talent_scout": t.staff_talent_scout,
			"staff_groundskeeper": t.staff_groundskeeper,
		}
	return out


func _deserialize_teams(raw: Dictionary) -> void:
	for key: String in raw:
		var d: Dictionary = raw[key]
		var t := Team.new()
		t.id               = d.get("id", 0)
		t.name             = d.get("name", "")
		t.short_name       = d.get("short_name", "")
		t.city             = d.get("city", "")
		t.league_id        = d.get("league_id", 0)
		t.is_reserve_team  = d.get("is_reserve_team", false)
		t.parent_club_name = d.get("parent_club_name", "")
		t.budget           = d.get("budget", 1000000)
		t.weekly_wage_budget = d.get("weekly_wage_budget", 100000)
		t.reputation       = d.get("reputation", 50)
		var saved_crest: String = d.get("crest", "")
		t.crest = saved_crest if saved_crest != "" else DataGenerator.TEAM_CRESTS.get(t.name, "")
		t.stadium_name     = d.get("stadium_name", "")
		t.stadium_capacity = d.get("stadium_capacity", 20000)
		t.player_ids.assign(d.get("player_ids", []))
		t.starting_eleven.assign(d.get("starting_eleven", []))
		t.bench.assign(d.get("bench", []))
		t.formation        = d.get("formation", "4-4-2")
		# Tácticas
		t.tactic_attack_style = d.get("tactic_attack_style", 1)
		t.tactic_toque_pct    = d.get("tactic_toque_pct", 50)
		t.tactic_counter_pct  = d.get("tactic_counter_pct", 20)
		t.tactic_tackle_style = d.get("tactic_tackle_style", 1)
		t.tactic_marking      = d.get("tactic_marking", 0)
		t.tactic_clearance    = d.get("tactic_clearance", 0)
		t.tactic_press_line   = d.get("tactic_press_line", 1)
		t.coach_name          = d.get("coach_name", "")
		t.wins             = d.get("wins", 0)
		t.draws            = d.get("draws", 0)
		t.losses           = d.get("losses", 0)
		t.goals_for        = d.get("goals_for", 0)
		t.goals_against    = d.get("goals_against", 0)
		# Mejoras del estadio
		t.stands_level             = d.get("stands_level", 0)
		t.parking_level            = d.get("parking_level", 0)
		t.construction_weeks_left  = d.get("construction_weeks_left", 0)
		t.construction_item        = d.get("construction_item", "")
		# Equipamiento
		t.lights_level         = d.get("lights_level", 1)
		t.heated_pitch         = d.get("heated_pitch", false)
		t.changing_rooms_level = d.get("changing_rooms_level", 1)
		t.scoreboard_level     = d.get("scoreboard_level", 1)
		t.access_level         = d.get("access_level", 1)
		# Servicios
		t.medical_level    = d.get("medical_level", 1)
		t.shop_level       = d.get("shop_level", 0)
		t.cafeteria_level  = d.get("cafeteria_level", 1)
		t.bathrooms_level  = d.get("bathrooms_level", 1)
		# Precios
		t.ticket_price = d.get("ticket_price", 20)
		t.drink_price  = d.get("drink_price", 3)
		t.merch_price  = d.get("merch_price", 15)
		# Finanzas
		t.club_cash              = d.get("club_cash", 5000000)
		t.season_matchday_income = d.get("season_matchday_income", 0)
		t.loan_amount            = d.get("loan_amount", 0)
		t.loan_weekly_payment    = d.get("loan_weekly_payment", 0)
		t.loan_weeks_left        = d.get("loan_weeks_left", 0)
		t.finance_history.assign(d.get("finance_history", []))
		# Ingresos comerciales
		t.tv_deal_tier          = d.get("tv_deal_tier", 0)
		t.tv_deal_weeks_left    = d.get("tv_deal_weeks_left", 0)
		t.tv_weekly_income      = d.get("tv_weekly_income", 0)
		t.sponsor_id            = d.get("sponsor_id", 0)
		t.sponsor_weeks_left    = d.get("sponsor_weeks_left", 0)
		t.sponsor_weekly_income = d.get("sponsor_weekly_income", 0)
		t.merch_stores          = d.get("merch_stores", 0)
		# Personal
		t.staff_gk_coach        = d.get("staff_gk_coach", 0)
		t.staff_passing_coach   = d.get("staff_passing_coach", 0)
		t.staff_dribbling_coach = d.get("staff_dribbling_coach", 0)
		t.staff_shooting_coach  = d.get("staff_shooting_coach", 0)
		t.staff_tackling_coach  = d.get("staff_tackling_coach", 0)
		t.staff_physical_coach  = d.get("staff_physical_coach", 0)
		t.staff_physio          = d.get("staff_physio", 0)
		t.staff_psychologist    = d.get("staff_psychologist", 0)
		t.staff_scout           = d.get("staff_scout", 0)
		t.staff_tech_secretary  = d.get("staff_tech_secretary", 0)
		t.staff_youth_coach     = d.get("staff_youth_coach", 0)
		t.staff_talent_scout    = d.get("staff_talent_scout", 0)
		t.staff_groundskeeper   = d.get("staff_groundskeeper", 0)
		GameManager.teams[t.id] = t


# ---------------------------------------------------------------------------
# Serialización ligas

func _serialize_leagues() -> Dictionary:
	var out: Dictionary = {}
	for id: int in GameManager.leagues:
		var l: League = GameManager.leagues[id]
		out[str(id)] = {
			"id": l.id, "name": l.name, "short_name": l.short_name,
			"country": l.country, "level": l.level,
			"season": l.season, "team_ids": l.team_ids,
			"current_matchday": l.current_matchday,
			"fixtures": l.fixtures,
		}
	return out


func _deserialize_leagues(raw: Dictionary) -> void:
	for key: String in raw:
		var d: Dictionary = raw[key]
		var l := League.new()
		l.id               = d.get("id", 0)
		l.name             = d.get("name", "")
		l.short_name       = d.get("short_name", l.name)
		l.country          = d.get("country", "")
		l.level            = d.get("level", 1)
		l.season           = d.get("season", 2026)
		l.team_ids.assign(d.get("team_ids", []))
		l.current_matchday = d.get("current_matchday", 0)
		l.fixtures.assign(d.get("fixtures", []))
		GameManager.leagues[l.id] = l
