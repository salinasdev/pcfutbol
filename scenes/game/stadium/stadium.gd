extends Control

const ICON_BACK := preload("res://assets/ui/icons/back-white.png")

enum Tab { TRIBUNAS, PARKING, EQUIPAMIENTO, SERVICIOS }

const STANDS_UPGRADES := [
	{"name": "Ampliación de Fondo",   "cap_gain": 5000,  "cost": 5_000_000,  "weeks": 8},
	{"name": "Nueva Tribuna Lateral", "cap_gain": 7000,  "cost": 8_500_000,  "weeks": 12},
	{"name": "Gran Anfiteatro",       "cap_gain": 10000, "cost": 16_000_000, "weeks": 20},
]

const PARKING_UPGRADES := [
	{"name": "Parking Pequeño", "spaces": 500,  "bonus_pct": 5,  "cost": 1_000_000, "weeks": 4},
	{"name": "Parking Mediano", "spaces": 1200, "bonus_pct": 10, "cost": 2_500_000, "weeks": 6},
	{"name": "Parking Grande",  "spaces": 2500, "bonus_pct": 18, "cost": 5_000_000, "weeks": 10},
]

const EQUIPMENT_UPGRADES := [
	{"key": "lights_level",         "name": "Focos modernos",         "from": 1, "cost": 500_000,   "desc": "Mejor visibilidad en partidos nocturnos"},
	{"key": "lights_level",         "name": "Focos LED",              "from": 2, "cost": 1_200_000, "desc": "Iluminación de máxima calidad"},
	{"key": "heated_pitch",         "name": "Calefacción del césped", "from": 0, "cost": 800_000,   "desc": "+5% rendimiento en meses de invierno"},
	{"key": "changing_rooms_level", "name": "Vestuarios mejorados",   "from": 1, "cost": 600_000,   "desc": "+3 moral a todos los jugadores"},
	{"key": "changing_rooms_level", "name": "Vestuarios de élite",    "from": 2, "cost": 1_200_000, "desc": "+5 moral a todos los jugadores"},
	{"key": "scoreboard_level",     "name": "Marcador digital",       "from": 1, "cost": 400_000,   "desc": "+2% de asistencia por partido"},
	{"key": "scoreboard_level",     "name": "Videomarcador",          "from": 2, "cost": 900_000,   "desc": "+5% de asistencia por partido"},
	{"key": "access_level",         "name": "Accesos mejorados",      "from": 1, "cost": 300_000,   "desc": "+3% de asistencia por partido"},
	{"key": "access_level",         "name": "Accesos premium",        "from": 2, "cost": 700_000,   "desc": "+5% de asistencia por partido"},
]

const SERVICES_UPGRADES := [
	{"key": "medical_level",   "name": "Enfermería mejorada",  "from": 1, "cost": 400_000,   "desc": "Reduce el tiempo de lesión en 1 semana"},
	{"key": "medical_level",   "name": "Centro médico",        "from": 2, "cost": 900_000,   "desc": "Reduce el tiempo de lesión en 2 semanas"},
	{"key": "shop_level",      "name": "Tienda de souvenirs",  "from": 0, "cost": 200_000,   "desc": "+5.000 € de ingresos por partido"},
	{"key": "shop_level",      "name": "Tienda ampliada",      "from": 1, "cost": 500_000,   "desc": "+12.000 € de ingresos por partido"},
	{"key": "shop_level",      "name": "Megastore",            "from": 2, "cost": 1_000_000, "desc": "+25.000 € de ingresos por partido"},
	{"key": "cafeteria_level", "name": "Cafetería renovada",   "from": 1, "cost": 300_000,   "desc": "+20% de ingresos en bebidas"},
	{"key": "cafeteria_level", "name": "Restaurante VIP",      "from": 2, "cost": 700_000,   "desc": "+40% de ingresos en bebidas"},
	{"key": "bathrooms_level", "name": "Aseos renovados",      "from": 1, "cost": 150_000,   "desc": "+1% de asistencia por partido"},
	{"key": "bathrooms_level", "name": "Aseos premium",        "from": 2, "cost": 400_000,   "desc": "+2% de asistencia por partido"},
]

var _active_tab: Tab = Tab.TRIBUNAS
var _team: Team = null


func _ready() -> void:
	_team = GameManager.get_player_team()
	%BtnBack.icon = ICON_BACK
	%BtnBack.text = ""
	%BtnBack.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/game/office/office.tscn"))
	%TabTribunas.pressed.connect(func():     _set_tab(Tab.TRIBUNAS))
	%TabParking.pressed.connect(func():      _set_tab(Tab.PARKING))
	%TabEquipamiento.pressed.connect(func(): _set_tab(Tab.EQUIPAMIENTO))
	%TabServicios.pressed.connect(func():    _set_tab(Tab.SERVICIOS))
	_refresh_right_panel()
	_refresh_match_day_panel()
	_set_tab(Tab.TRIBUNAS)


func _set_tab(tab: Tab) -> void:
	_active_tab = tab
	%TabTribunas.button_pressed     = (tab == Tab.TRIBUNAS)
	%TabParking.button_pressed      = (tab == Tab.PARKING)
	%TabEquipamiento.button_pressed = (tab == Tab.EQUIPAMIENTO)
	%TabServicios.button_pressed    = (tab == Tab.SERVICIOS)
	_build_content()


func _build_content() -> void:
	var c: VBoxContainer = %ContentVBox
	for child in c.get_children():
		child.queue_free()
	if _team == null:
		return
	match _active_tab:
		Tab.TRIBUNAS:     _build_tribunas(c)
		Tab.PARKING:      _build_parking(c)
		Tab.EQUIPAMIENTO: _build_equip(c)
		Tab.SERVICIOS:    _build_services(c)


# ──────────────────────────────────────────────────────────────
# TRIBUNAS
# ──────────────────────────────────────────────────────────────
func _build_tribunas(c: VBoxContainer) -> void:
	var building := _team.construction_item.begins_with("stands") and _team.construction_weeks_left > 0
	if building:
		c.add_child(_make_construction_lbl())

	c.add_child(_make_info_lbl("Capacidad actual: %s espectadores" % _fmt(_team.get_effective_capacity())))
	c.add_child(HSeparator.new())

	for i in range(STANDS_UPGRADES.size()):
		var u: Dictionary = STANDS_UPGRADES[i]
		var completed := _team.stands_level > i
		var in_build  := _team.construction_item == ("stands_%d" % (i + 1))
		var available := _team.stands_level == i and not building
		c.add_child(_make_card(
			u["name"],
			["+%s espectadores" % _fmt(u["cap_gain"]),
			 "Coste: %s €" % _fmt(u["cost"]),
			 "Duración: %d semanas" % u["weeks"]],
			u["cost"], completed, in_build, available,
			_buy_stands.bind(i)
		))


func _buy_stands(idx: int) -> void:
	var u: Dictionary = STANDS_UPGRADES[idx]
	if not _check_funds(u["cost"]): return
	_team.club_cash -= u["cost"]
	_team.construction_item = "stands_%d" % (idx + 1)
	_team.construction_weeks_left = u["weeks"]
	_post_buy("✅ Construcción iniciada: %s — %d semanas" % [u["name"], u["weeks"]])


# ──────────────────────────────────────────────────────────────
# PARKING
# ──────────────────────────────────────────────────────────────
func _build_parking(c: VBoxContainer) -> void:
	var building := _team.construction_item.begins_with("parking") and _team.construction_weeks_left > 0
	if building:
		c.add_child(_make_construction_lbl())

	var bonus_arr := [0, 5, 10, 18]
	var bonus: int = bonus_arr[clampi(_team.parking_level, 0, 3)]
	c.add_child(_make_info_lbl(
		"Plazas actuales: %s  (+%d%% de asistencia)" % [_fmt(_team.get_parking_spaces()), bonus]
	))
	c.add_child(HSeparator.new())

	for i in range(PARKING_UPGRADES.size()):
		var u: Dictionary = PARKING_UPGRADES[i]
		var completed := _team.parking_level > i
		var in_build  := _team.construction_item == ("parking_%d" % (i + 1))
		var available := _team.parking_level == i and not building
		c.add_child(_make_card(
			u["name"],
			["%s plazas" % _fmt(u["spaces"]),
			 "+%d%% de asistencia al estadio" % u["bonus_pct"],
			 "Coste: %s €" % _fmt(u["cost"]),
			 "Duración: %d semanas" % u["weeks"]],
			u["cost"], completed, in_build, available,
			_buy_parking.bind(i)
		))


func _buy_parking(idx: int) -> void:
	var u: Dictionary = PARKING_UPGRADES[idx]
	if not _check_funds(u["cost"]): return
	_team.club_cash -= u["cost"]
	_team.construction_item = "parking_%d" % (idx + 1)
	_team.construction_weeks_left = u["weeks"]
	_post_buy("✅ Construcción iniciada: %s — %d semanas" % [u["name"], u["weeks"]])


# ──────────────────────────────────────────────────────────────
# EQUIPAMIENTO
# ──────────────────────────────────────────────────────────────
func _build_equip(c: VBoxContainer) -> void:
	for i in range(EQUIPMENT_UPGRADES.size()):
		var u: Dictionary = EQUIPMENT_UPGRADES[i]
		var cur: int       = _get_field(u["key"])
		var completed: bool = cur > u["from"]
		var available: bool = cur == u["from"]
		c.add_child(_make_card(
			u["name"],
			[u["desc"], "Coste: %s €" % _fmt(u["cost"])],
			u["cost"], completed, false, available,
			_buy_upgrade.bind(i, false)
		))


# ──────────────────────────────────────────────────────────────
# SERVICIOS
# ──────────────────────────────────────────────────────────────
func _build_services(c: VBoxContainer) -> void:
	for i in range(SERVICES_UPGRADES.size()):
		var u: Dictionary = SERVICES_UPGRADES[i]
		var cur: int       = _get_field(u["key"])
		var completed: bool = cur > u["from"]
		var available: bool = cur == u["from"]
		c.add_child(_make_card(
			u["name"],
			[u["desc"], "Coste: %s €" % _fmt(u["cost"])],
			u["cost"], completed, false, available,
			_buy_upgrade.bind(i, true)
		))


func _buy_upgrade(idx: int, is_service: bool) -> void:
	var u: Dictionary = SERVICES_UPGRADES[idx] if is_service else EQUIPMENT_UPGRADES[idx]
	var cur := _get_field(u["key"])
	if cur != u["from"]: return
	if not _check_funds(u["cost"]): return
	_team.club_cash -= u["cost"]
	_set_field(u["key"], cur + 1)
	_post_buy("✅ Instalado: %s" % u["name"])


# ──────────────────────────────────────────────────────────────
# Panel derecho — info
# ──────────────────────────────────────────────────────────────
func _refresh_right_panel() -> void:
	if _team == null: return
	%StadiumName.text     = _team.stadium_name if _team.stadium_name != "" else "Estadio Municipal"
	%StadiumCapacity.text = "Capacidad: %s espectadores" % _fmt(_team.get_effective_capacity())
	%StadiumParking.text  = "Parking: %s plazas" % _fmt(_team.get_parking_spaces())
	%ClubCash.text        = "💰 Caja del club: %s €" % _fmt(_team.club_cash)

	# Resolver la ruta del estadio: campo guardado, o fallback por nombre
	var img_path: String = _team.stadium_image
	if img_path == "":
		img_path = DataGenerator.TEAM_STADIUMS.get(_team.name, "")
	push_warning("StadiumPhoto path: '%s'  team: '%s'" % [img_path, _team.name])
	if img_path != "":
		var tex := load(img_path) as Texture2D
		if tex:
			%StadiumPhoto.texture = tex
		else:
			push_error("StadiumPhoto: no se pudo cargar la textura '%s'" % img_path)
	else:
		%StadiumPhoto.texture = null
	if _team.construction_weeks_left > 0:
		%ConstructionStatus.visible = true
		%ConstructionStatus.text    = "🔨 En construcción — %d sem. restantes" % _team.construction_weeks_left
	else:
		%ConstructionStatus.visible = false


# ──────────────────────────────────────────────────────────────
# Panel día de partido — precios
# ──────────────────────────────────────────────────────────────
func _refresh_match_day_panel() -> void:
	var has_pending: bool = not GameManager.active_fixture.is_empty() \
					   and not GameManager.active_fixture.get("played", true)
	%MatchDayPanel.visible = has_pending
	if not has_pending or _team == null: return

	%SpinTicket.set_value_no_signal(_team.ticket_price)
	%SpinDrink.set_value_no_signal(_team.drink_price)
	%SpinMerch.set_value_no_signal(_team.merch_price)
	_update_preview()

	%SpinTicket.value_changed.connect(_on_ticket_changed)
	%SpinDrink.value_changed.connect(_on_drink_changed)
	%SpinMerch.value_changed.connect(_on_merch_changed)


func _on_ticket_changed(v: float) -> void:
	if _team == null: return
	_team.ticket_price = int(v)
	_update_preview()


func _on_drink_changed(v: float) -> void:
	if _team == null: return
	_team.drink_price = int(v)
	_update_preview()


func _on_merch_changed(v: float) -> void:
	if _team == null: return
	_team.merch_price = int(v)
	_update_preview()


func _update_preview() -> void:
	if _team == null: return
	var att    := _team.calculate_attendance()
	var income := _team.calculate_matchday_income()
	%IncomePreview.text = "Asistencia estimada: %s  •  Ingresos: %s €" % [_fmt(att), _fmt(income)]


# ──────────────────────────────────────────────────────────────
# Helpers de UI — tarjeta de mejora
# ──────────────────────────────────────────────────────────────
func _make_card(title: String, details: Array, cost: int,
				done: bool, in_build: bool, available: bool,
				on_buy: Callable) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 76)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.11, 0.20, 1)
	style.set_border_width_all(0)
	style.border_width_left = 4
	if done:
		style.border_color = Color(0.25, 0.75, 0.25, 1)
	elif in_build:
		style.border_color = Color(0.90, 0.75, 0.10, 1)
	elif available:
		style.border_color = Color(0.25, 0.55, 0.95, 1)
	else:
		style.border_color = Color(0.22, 0.25, 0.32, 1)
	style.content_margin_left   = 12.0
	style.content_margin_right  = 12.0
	style.content_margin_top    = 8.0
	style.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	panel.add_child(hbox)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(vbox)

	var lbl_t := Label.new()
	lbl_t.text = title
	lbl_t.add_theme_font_size_override("font_size", 17)
	if done:
		lbl_t.add_theme_color_override("font_color", Color(0.40, 0.88, 0.40, 1))
	elif in_build:
		lbl_t.add_theme_color_override("font_color", Color(0.92, 0.82, 0.20, 1))
	else:
		lbl_t.add_theme_color_override("font_color", Color(0.88, 0.94, 1.0, 1))
	vbox.add_child(lbl_t)

	for d: String in details:
		var lbl_d := Label.new()
		lbl_d.text = d
		lbl_d.add_theme_font_size_override("font_size", 13)
		lbl_d.add_theme_color_override("font_color", Color(0.58, 0.70, 0.84, 1))
		vbox.add_child(lbl_d)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(140, 0)
	btn.add_theme_font_size_override("font_size", 14)
	if done:
		btn.text     = "✅ Completado"
		btn.disabled = true
	elif in_build:
		btn.text     = "🔨 En obras"
		btn.disabled = true
	elif available:
		if _team != null and _team.club_cash < cost:
			btn.text     = "Sin fondos"
			btn.disabled = true
		else:
			btn.text = "Construir / Instalar"
			btn.pressed.connect(on_buy)
	else:
		btn.text     = "No disponible"
		btn.disabled = true
	hbox.add_child(btn)

	return panel


func _make_info_lbl(txt: String) -> Label:
	var lbl := Label.new()
	lbl.text = txt
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color(0.62, 0.84, 0.62, 1))
	return lbl


func _make_construction_lbl() -> Label:
	var lbl := Label.new()
	lbl.text = "🔨 Obra en curso — %d semana(s) restantes" % _team.construction_weeks_left
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.78, 0.20, 1))
	return lbl


func _post_buy(msg: String) -> void:
	SaveManager.save_game()
	_refresh_right_panel()
	_build_content()
	%StatusBar.text = msg


func _check_funds(cost: int) -> bool:
	if _team == null or _team.club_cash < cost:
		%StatusBar.text = "❌ Fondos insuficientes — necesitas %s €" % _fmt(cost)
		return false
	return true


func _fmt(n: int) -> String:
	var s      := str(n)
	var result := ""
	var count  := 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "." + result
		result = s[i] + result
		count += 1
	return result


# ──────────────────────────────────────────────────────────────
# Acceso a campos de Team por clave de texto
# ──────────────────────────────────────────────────────────────
func _get_field(key: String) -> int:
	match key:
		"lights_level":         return _team.lights_level
		"heated_pitch":         return 1 if _team.heated_pitch else 0
		"changing_rooms_level": return _team.changing_rooms_level
		"scoreboard_level":     return _team.scoreboard_level
		"access_level":         return _team.access_level
		"medical_level":        return _team.medical_level
		"shop_level":           return _team.shop_level
		"cafeteria_level":      return _team.cafeteria_level
		"bathrooms_level":      return _team.bathrooms_level
	return 0


func _set_field(key: String, val: int) -> void:
	match key:
		"lights_level":         _team.lights_level         = val
		"heated_pitch":         _team.heated_pitch         = val > 0
		"changing_rooms_level": _team.changing_rooms_level = val
		"scoreboard_level":     _team.scoreboard_level     = val
		"access_level":         _team.access_level         = val
		"medical_level":        _team.medical_level        = val
		"shop_level":           _team.shop_level           = val
		"cafeteria_level":      _team.cafeteria_level      = val
		"bathrooms_level":      _team.bathrooms_level      = val
