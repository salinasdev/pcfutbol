extends Control

func _ready() -> void:
	%BtnNewGame.pressed.connect(_on_new_game)
	%BtnLoadGame.pressed.connect(_on_load_game)
	%BtnQuit.pressed.connect(_on_quit)
	# En móvil el SO gestiona la salida; ocultamos el botón
	%BtnQuit.visible = not OS.has_feature("mobile")
	# Habilitar "Cargar" solo si existe partida guardada
	%BtnLoadGame.disabled = not SaveManager.has_save()


func _on_new_game() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu/new_game_setup.tscn")


func _on_load_game() -> void:
	if SaveManager.load_game():
		get_tree().change_scene_to_file("res://scenes/game/office/office.tscn")


func _on_quit() -> void:
	get_tree().quit()
