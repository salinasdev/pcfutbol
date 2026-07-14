class_name Team
extends Resource

@export var id: int = 0
@export var name: String = ""
@export var short_name: String = ""
@export var city: String = ""
@export var league_id: int = 0

# Finanzas
@export var budget: int = 1_000_000          ## Presupuesto de traspasos en €
@export var weekly_wage_budget: int = 100_000 ## Masa salarial semanal máxima en €

# Identidad
@export var reputation: int = 50             ## 1–100
@export var crest: String = ""               ## Ruta al escudo: "res://assets/teams/xxx.png"
@export var stadium_image: String = ""       ## Ruta a la foto del estadio: "res://assets/stadiums/xxx.jpg"
@export var stadium_name: String = ""
@export var stadium_capacity: int = 20_000

# Cuerpo técnico
@export var coach_name: String = ""

# Plantilla
@export var player_ids: Array[int] = []
@export var starting_eleven: Array[int] = [] ## IDs ordenados de titular (POR→DEL)
@export var bench: Array[int] = []           ## 5 suplentes convocados
@export var formation: String = "4-4-2"

# Tácticas de equipo
## Ataque: 0=Ofensivo  1=Mixto  2=Especulativo
@export var tactic_attack_style: int = 1
## Porcentaje de juego al toque (0–100); el resto es balón largo
@export var tactic_toque_pct: int = 50
## Porcentaje de contragolpe (0–100)
@export var tactic_counter_pct: int = 20
## Defensa — tipo de entradas: 0=Suave  1=Media  2=Agresiva
@export var tactic_tackle_style: int = 1
## Defensa — marcaje: 0=Zonal  1=Al hombre
@export var tactic_marking: int = 0
## Defensa — despejes: 0=Balón jugado  1=Balón largo
@export var tactic_clearance: int = 0
## Defensa — línea de presión: 0=Campo propio  1=Campo medio  2=Campo rival
@export var tactic_press_line: int = 1

# Estadísticas de temporada (se resetean cada temporada)
@export var wins: int = 0
@export var draws: int = 0
@export var losses: int = 0
@export var goals_for: int = 0
@export var goals_against: int = 0

# Estadio — mejoras estructurales
@export var stands_level: int = 0           ## 0-3: ampliaciones de tribuna (requieren construcción)
@export var parking_level: int = 0          ## 0-3: parking (requiere construcción)
@export var construction_weeks_left: int = 0
@export var construction_item: String = ""  ## "stands_N" | "parking_N"

# Equipamiento (1=básico 2=bueno 3=top)
@export var lights_level: int = 1
@export var heated_pitch: bool = false
@export var changing_rooms_level: int = 1
@export var scoreboard_level: int = 1
@export var access_level: int = 1

# Servicios (0=sin servicio, 1=básico, 2=bueno, 3=top)
@export var medical_level: int = 1
@export var shop_level: int = 0
@export var cafeteria_level: int = 1
@export var bathrooms_level: int = 1

# Precios día de partido
@export var ticket_price: int = 20
@export var drink_price: int = 3
@export var merch_price: int = 15

# Finanzas del club
@export var club_cash: int = 5_000_000
@export var season_matchday_income: int = 0
## Préstamo bancario activo
@export var loan_amount: int = 0        ## Capital pendiente de devolver
@export var loan_weekly_payment: int = 0 ## Cuota semanal (capital + intereses)
@export var loan_weeks_left: int = 0    ## Semanas restantes
## Histórico financiero semanal (últimas 20 entradas)
@export var finance_history: Array[Dictionary] = []

# Ingresos comerciales
## Oferta TV activa: 0=sin contrato, id del contrato activo
@export var tv_deal_tier: int = 0         ## 0=sin contrato 1-4=tier
@export var tv_deal_weeks_left: int = 0   ## Semanas restantes del contrato TV
@export var tv_weekly_income: int = 0     ## Ingreso semanal del contrato TV
## Patrocinio de camiseta
@export var sponsor_id: int = 0           ## 0=sin patrocinador, 1-8=patrocinador
@export var sponsor_weeks_left: int = 0
@export var sponsor_weekly_income: int = 0
## Tiendas de merchandising (además de la del estadio)
@export var merch_stores: int = 0         ## Tiendas adicionales (0-3)

# Personal del club (0 = sin contratar, 1-5 = nivel)
@export var staff_gk_coach: int = 0        ## Entrenador de porteros
@export var staff_passing_coach: int = 0   ## Entrenador de pase
@export var staff_dribbling_coach: int = 0 ## Entrenador de regate
@export var staff_shooting_coach: int = 0  ## Entrenador de remate
@export var staff_tackling_coach: int = 0  ## Entrenador de entradas
@export var staff_physical_coach: int = 0  ## Entrenador físico
@export var staff_physio: int = 0          ## Fisioterapeuta
@export var staff_psychologist: int = 0    ## Psícolog
@export var staff_scout: int = 0           ## Observador
@export var staff_tech_secretary: int = 0  ## Secretario técnico
@export var staff_youth_coach: int = 0     ## Entrenador de juveniles
@export var staff_talent_scout: int = 0    ## Ojeador
@export var staff_groundskeeper: int = 0   ## Encargado del campo


func get_points() -> int:
	return wins * 3 + draws


func get_goal_difference() -> int:
	return goals_for - goals_against


func get_matches_played() -> int:
	return wins + draws + losses


func reset_season_stats() -> void:
	wins = 0
	draws = 0
	losses = 0
	goals_for = 0
	goals_against = 0
	season_matchday_income = 0


func get_effective_capacity() -> int:
	var additions := [0, 5000, 12000, 22000]
	return stadium_capacity + additions[clampi(stands_level, 0, 3)]


func get_parking_spaces() -> int:
	var spaces := [0, 500, 1200, 2500]
	return spaces[clampi(parking_level, 0, 3)]


func calculate_attendance() -> int:
	var cap       := get_effective_capacity()
	var fill      := clampf(float(reputation) / 100.0 * 0.55 + 0.30, 0.30, 0.90)
	var price_mod := clampf(1.0 - maxf(0.0, float(ticket_price - 20)) * 0.012, 0.35, 1.10)
	var park_pct: int = [0, 5, 10, 18][clampi(parking_level, 0, 3)]
	var park_mod  := 1.0 + float(park_pct) / 100.0
	var equip_mod := float(scoreboard_level - 1) * 0.02 \
				  + float(access_level     - 1) * 0.025 \
				  + float(bathrooms_level  - 1) * 0.01
	return clampi(int(float(cap) * fill * price_mod * park_mod * (1.0 + equip_mod)), 0, cap)


func calculate_matchday_income() -> int:
	var att         := calculate_attendance()
	var drink_mult  := 1.0 + float(cafeteria_level - 1) * 0.20
	var tickets     := att * ticket_price
	var drinks      := int(float(att) * float(drink_price) * 0.35 * drink_mult)
	var merch       := int(float(att) * float(merch_price) * 0.08)
	var shop_income: int = [0, 5000, 12000, 25000][clampi(shop_level, 0, 3)]
	return tickets + drinks + merch + shop_income
