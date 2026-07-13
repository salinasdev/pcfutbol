class_name Player
extends Resource

enum Position { GK, DEF, MID, FWD }

@export var id: int = 0
@export var full_name: String = ""
@export var age: int = 20
@export var nationality: String = "España"
@export var position: Position = Position.MID
@export var number: int = 0

# Atributos técnicos (1–99)
@export var pace: int = 50
@export var shooting: int = 50
@export var passing: int = 50
@export var dribbling: int = 50
@export var defending: int = 50
@export var physical: int = 50
@export var goalkeeping: int = 20

# Contrato
@export var salary: int = 5000          ## Salario semanal en €
@export var contract_years: int = 2
@export var market_value: int = 100000  ## Valor de mercado en €
@export var transfer_listed: bool = false

# Estado
@export var morale: int = 70            ## 0–100
@export var fitness: int = 100          ## 0–100
@export var energy: int = 100           ## 0–100: baja al jugar, sube al descansar
@export var injured: bool = false
@export var injury_weeks: int = 0
@export var team_id: int = -1

# Disciplina
@export var yellow_cards: int = 0       ## Acumuladas en la temporada
@export var suspended: bool = false     ## Sancionado para el próximo partido
@export var red_carded: bool = false    ## Expulsado este partido (interno)


## Control/Técnica: media de pase y regate (1–99)
func get_ca() -> int:
	return int(round((passing + dribbling) / 2.0))


## Media de los 5 stats normalizados a 1–99
func get_me() -> int:
	var en_norm: int = clamp(energy, 1, 99)
	return int(round((en_norm + pace + physical + defending + get_ca()) / 5.0))


## Valoración global por posición, penalizada por baja energía
func get_overall() -> int:
	match position:
		Position.GK:
			return goalkeeping
		Position.DEF:
			return int(round((defending * 3 + pace + physical + passing) / 6.0))
		Position.MID:
			return int(round((passing * 2 + dribbling * 2 + defending + shooting) / 6.0))
		Position.FWD:
			return int(round((shooting * 3 + pace * 2 + dribbling) / 6.0))
	return 50


## Overall efectivo penalizado por energía (usado en simulación de partidos)
func get_effective_overall() -> int:
	var base := get_overall()
	var factor := clampf(energy / 100.0 * 0.40 + 0.60, 0.60, 1.0)
	return maxi(1, int(round(base * factor)))


func get_position_abbr() -> String:
	match position:
		Position.GK:  return "POR"
		Position.DEF: return "DEF"
		Position.MID: return "MED"
		Position.FWD: return "DEL"
	return "?"
