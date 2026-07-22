extends Control
class_name BoardScreen

const ICON_BACK := preload("res://assets/ui/icons/back-white.png")
const ICON_SIZE_NAV := 28

## Pantalla "Junta Directiva": métricas del mánager y propuesta de primas.

# ── Refs a controles actualizables ──────────────────────────────────────────
var _lbl_name:        Label
var _lbl_rating:      Label
var _lbl_board:       Label
var _lbl_public:      Label
var _spin_win:        SpinBox
var _spin_title:      SpinBox
var _lbl_result:      Label
var _bonus_table:     VBoxContainer


func _ready() -> void:
	_build_ui()
	_refresh()


# ---------------------------------------------------------------------------
# Refresco de datos

func _refresh() -> void:
	_lbl_name.text = GameManager.manager_name if GameManager.manager_name != "" else "Mánager"
	_update_metric(_lbl_rating, GameManager.manager_rating)
	_update_metric(_lbl_board,  GameManager.board_confidence)
	_update_metric(_lbl_public, GameManager.public_confidence)
	_spin_win.value   = GameManager.bonus_win
	_spin_title.value = GameManager.bonus_title
	_rebuild_bonus_table()


func _update_metric(lbl: Label, val: float) -> void:
	var filled := int(round(val))
	var bar := "█".repeat(filled) + "░".repeat(10 - filled)
	lbl.text = "%s  %.1f / 10" % [bar, val]
	if val >= 7.0:
		lbl.add_theme_color_override("font_color", Color(0.25, 0.90, 0.40, 1))
	elif val >= 4.0:
		lbl.add_theme_color_override("font_color", Color(0.95, 0.75, 0.15, 1))
	else:
		lbl.add_theme_color_override("font_color", Color(0.90, 0.25, 0.20, 1))


func _rebuild_bonus_table() -> void:
	for child in _bonus_table.get_children():
		child.queue_free()

	if GameManager.bonus_win == 0 and GameManager.bonus_title == 0:
		var lbl := Label.new()
		lbl.text = "Sin primas activas."
		lbl.add_theme_font_size_override("font_size", 15)
		lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
		_bonus_table.add_child(lbl)
	else:
		if GameManager.bonus_win > 0:
			_bonus_table.add_child(_bonus_row("⚽  Por victoria", GameManager.bonus_win))
		if GameManager.bonus_title > 0:
			_bonus_table.add_child(_bonus_row("🏆  Por título", GameManager.bonus_title))

	# Historial (últimas 6 entradas)
	if not GameManager.bonus_history.is_empty():
		var sep := HSeparator.new()
		_bonus_table.add_child(sep)
		var hist_lbl := Label.new()
		hist_lbl.text = "Historial"
		hist_lbl.add_theme_font_size_override("font_size", 13)
		hist_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55, 1))
		_bonus_table.add_child(hist_lbl)
		var history: Array = GameManager.bonus_history
		var start: int = maxi(0, history.size() - 6)
		for i in range(history.size() - 1, start - 1, -1):
			var entry: Dictionary = history[i]
			var type_str := "Victoria" if entry["type"] == "win" else "Título"
			var row_lbl := Label.new()
			row_lbl.text = "  Sem.%d  %s → %s €" % [entry["week"], type_str, _fmt(entry["amount"])]
			row_lbl.add_theme_font_size_override("font_size", 13)
			row_lbl.add_theme_color_override("font_color", Color(0.50, 0.50, 0.50, 1))
			_bonus_table.add_child(row_lbl)


func _bonus_row(label_txt: String, amount: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var lbl := Label.new()
	lbl.text = label_txt
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 16)
	row.add_child(lbl)
	var val_lbl := Label.new()
	val_lbl.text = "%s €" % _fmt(amount)
	val_lbl.add_theme_font_size_override("font_size", 16)
	val_lbl.add_theme_color_override("font_color", Color(0.90, 0.85, 0.20, 1))
	row.add_child(val_lbl)
	return row


# ---------------------------------------------------------------------------
# Propuesta de primas

func _on_propose() -> void:
	var msg := GameManager.propose_bonuses(int(_spin_win.value), int(_spin_title.value))
	_lbl_result.text = msg
	if msg.begins_with("✔"):
		_lbl_result.add_theme_color_override("font_color", Color(0.25, 0.90, 0.40, 1))
		_rebuild_bonus_table()
	else:
		_lbl_result.add_theme_color_override("font_color", Color(0.90, 0.25, 0.20, 1))


# ---------------------------------------------------------------------------
# Construcción de UI (completamente programática)

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Fondo
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.07, 0.09, 0.13, 1)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	# ── Top bar ──────────────────────────────────────────────────────────────
	var topbar := HBoxContainer.new()
	topbar.custom_minimum_size = Vector2(0, 64)
	root.add_child(topbar)

	var btn_back := Button.new()
	btn_back.text = ""
	btn_back.icon = ICON_BACK
	btn_back.add_theme_constant_override("icon_max_width", ICON_SIZE_NAV)
	btn_back.custom_minimum_size = Vector2(64, 64)
	btn_back.add_theme_font_size_override("font_size", 22)
	btn_back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/game/office/office.tscn"))
	topbar.add_child(btn_back)

	var title_lbl := Label.new()
	title_lbl.text = "Junta Directiva"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 26)
	title_lbl.add_theme_color_override("font_color", Color(0.90, 0.85, 0.50, 1))
	topbar.add_child(title_lbl)

	var top_spacer := Control.new()
	top_spacer.custom_minimum_size = Vector2(64, 0)
	topbar.add_child(top_spacer)

	root.add_child(HSeparator.new())

	# ── Contenido principal (dos columnas) ────────────────────────────────────
	var hbox := HBoxContainer.new()
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 0)
	root.add_child(hbox)

	# ── COLUMNA IZQUIERDA ────────────────────────────────────────────────────
	var left_margin := MarginContainer.new()
	left_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_margin.size_flags_stretch_ratio = 3.0
	left_margin.add_theme_constant_override("margin_left",   28)
	left_margin.add_theme_constant_override("margin_right",  28)
	left_margin.add_theme_constant_override("margin_top",    24)
	left_margin.add_theme_constant_override("margin_bottom", 24)
	hbox.add_child(left_margin)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 14)
	left_margin.add_child(left)

	# Nombre del mánager
	var name_header := Label.new()
	name_header.text = "👤  Mánager"
	name_header.add_theme_font_size_override("font_size", 13)
	name_header.add_theme_color_override("font_color", Color(0.55, 0.60, 0.65, 1))
	left.add_child(name_header)

	_lbl_name = Label.new()
	_lbl_name.add_theme_font_size_override("font_size", 22)
	_lbl_name.add_theme_color_override("font_color", Color(0.95, 0.95, 1.00, 1))
	left.add_child(_lbl_name)

	left.add_child(HSeparator.new())

	# Métricas
	left.add_child(_sublabel("Evaluación como mánager"))
	_lbl_rating = Label.new()
	_lbl_rating.add_theme_font_size_override("font_size", 17)
	left.add_child(_lbl_rating)

	left.add_child(_sublabel("Confianza de la Directiva"))
	_lbl_board = Label.new()
	_lbl_board.add_theme_font_size_override("font_size", 17)
	left.add_child(_lbl_board)

	left.add_child(_sublabel("Confianza del Público"))
	_lbl_public = Label.new()
	_lbl_public.add_theme_font_size_override("font_size", 17)
	left.add_child(_lbl_public)

	left.add_child(HSeparator.new())

	# Sección Primas
	var primas_title := Label.new()
	primas_title.text = "💰  Proponer Primas"
	primas_title.add_theme_font_size_override("font_size", 19)
	primas_title.add_theme_color_override("font_color", Color(0.90, 0.80, 0.30, 1))
	left.add_child(primas_title)

	# Prima por victoria
	var win_row := HBoxContainer.new()
	win_row.add_theme_constant_override("separation", 14)
	left.add_child(win_row)
	var win_lbl := Label.new()
	win_lbl.text = "Prima por victoria:"
	win_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	win_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	win_lbl.add_theme_font_size_override("font_size", 16)
	win_row.add_child(win_lbl)
	_spin_win = SpinBox.new()
	_spin_win.min_value = 0
	_spin_win.max_value = 10_000_000
	_spin_win.step = 1_000
	_spin_win.custom_minimum_size = Vector2(180, 40)
	_spin_win.suffix = "€"
	win_row.add_child(_spin_win)

	# Prima por título
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 14)
	left.add_child(title_row)
	var title_lbl2 := Label.new()
	title_lbl2.text = "Prima por título:"
	title_lbl2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl2.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_lbl2.add_theme_font_size_override("font_size", 16)
	title_row.add_child(title_lbl2)
	_spin_title = SpinBox.new()
	_spin_title.min_value = 0
	_spin_title.max_value = 100_000_000
	_spin_title.step = 10_000
	_spin_title.custom_minimum_size = Vector2(180, 40)
	_spin_title.suffix = "€"
	title_row.add_child(_spin_title)

	# Botón proponer
	var btn_propose := Button.new()
	btn_propose.text = "Presentar a la Directiva"
	btn_propose.custom_minimum_size = Vector2(0, 52)
	btn_propose.add_theme_font_size_override("font_size", 17)
	btn_propose.add_theme_color_override("font_color", Color(0.20, 0.90, 0.50, 1))
	btn_propose.pressed.connect(_on_propose)
	left.add_child(btn_propose)

	# Mensaje resultado
	_lbl_result = Label.new()
	_lbl_result.add_theme_font_size_override("font_size", 15)
	_lbl_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_lbl_result)

	# ── Separador vertical ────────────────────────────────────────────────────
	hbox.add_child(VSeparator.new())

	# ── COLUMNA DERECHA ───────────────────────────────────────────────────────
	var right_margin := MarginContainer.new()
	right_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_margin.size_flags_stretch_ratio = 2.0
	right_margin.add_theme_constant_override("margin_left",   24)
	right_margin.add_theme_constant_override("margin_right",  24)
	right_margin.add_theme_constant_override("margin_top",    24)
	right_margin.add_theme_constant_override("margin_bottom", 24)
	hbox.add_child(right_margin)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 12)
	right_margin.add_child(right)

	var right_title := Label.new()
	right_title.text = "📋  Primas Vigentes"
	right_title.add_theme_font_size_override("font_size", 19)
	right_title.add_theme_color_override("font_color", Color(0.90, 0.80, 0.30, 1))
	right.add_child(right_title)

	right.add_child(HSeparator.new())

	_bonus_table = VBoxContainer.new()
	_bonus_table.add_theme_constant_override("separation", 10)
	right.add_child(_bonus_table)


# ---------------------------------------------------------------------------
# Helpers

func _sublabel(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", Color(0.55, 0.60, 0.65, 1))
	return l


func _fmt(n: int) -> String:
	var s := str(n)
	var result := ""
	var count := 0
	for i: int in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "." + result
		result = s[i] + result
		count += 1
	return result
