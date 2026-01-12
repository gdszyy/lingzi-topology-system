extends Control

@onready var ga_button: Button = $VBoxContainer/GAButton
@onready var test_button: Button = $VBoxContainer/TestButton
@onready var combat_button: Button = $VBoxContainer/CombatButton
@onready var arena_button: Button = $VBoxContainer/ArenaButton
@onready var quit_button: Button = $VBoxContainer/QuitButton

func _ready():
	ga_button.pressed.connect(_on_ga_pressed)
	test_button.pressed.connect(_on_test_pressed)
	combat_button.pressed.connect(_on_combat_pressed)
	arena_button.pressed.connect(_on_arena_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _on_ga_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/test/test_main.tscn")

func _on_test_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/battle_test/battle_test_scene.tscn")

func _on_combat_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/player/combat_test_scene.tscn")

func _on_arena_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ai_arena/ai_arena_scene.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
