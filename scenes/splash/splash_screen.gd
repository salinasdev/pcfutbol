extends Control

const MENU_SCENE := "res://scenes/main_menu/main_menu.tscn"
const LOGO_PATH := "res://logo_blanco.png"

@onready var logo_texture_rect: TextureRect = %LogoTextureRect
@onready var logo_label: Label = %LogoLabel
@onready var logo_box: VBoxContainer = %VBoxContainer
@onready var background: Panel = %Background


func _ready() -> void:
	logo_box.scale = Vector2(0.94, 0.94)
	background.modulate = Color(1.0, 1.0, 1.0, 0.0)
	logo_texture_rect.modulate.a = 0.0
	logo_label.modulate.a = 0.0
	var logo := _load_logo_texture()
	if logo != null:
		logo_texture_rect.texture = logo
		logo_texture_rect.visible = true
		logo_label.visible = false
	else:
		logo_texture_rect.visible = false
		logo_label.visible = true

	var logo_node := logo_texture_rect if logo != null else logo_label
	var intro_tween := create_tween()
	intro_tween.set_parallel(true)
	intro_tween.tween_property(background, "modulate:a", 1.0, 0.22)
	intro_tween.tween_property(logo_box, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	intro_tween.tween_property(logo_node, "modulate:a", 1.0, 0.55)
	intro_tween.finished.connect(_play_outro.bind(logo_node))


func _load_logo_texture() -> Texture2D:
	if ResourceLoader.exists(LOGO_PATH):
		return load(LOGO_PATH)
	return null


func _play_outro(logo_node: CanvasItem) -> void:
	await get_tree().create_timer(1.15).timeout
	var outro_tween := create_tween()
	outro_tween.set_parallel(true)
	outro_tween.tween_property(logo_box, "scale", Vector2(1.03, 1.03), 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	outro_tween.tween_property(logo_node, "modulate:a", 0.0, 0.32)
	outro_tween.tween_property(background, "modulate:a", 0.0, 0.32)
	outro_tween.finished.connect(_go_to_menu)


func _go_to_menu() -> void:
	if get_tree() == null:
		return
	if get_tree().current_scene == self:
		get_tree().change_scene_to_file(MENU_SCENE)