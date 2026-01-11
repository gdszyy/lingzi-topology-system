# main_menu.gd
# 主菜单 - 系统入口
extends Control

@onready var ga_button: Button = $VBoxContainer/GAButton
@onready var test_button: Button = $VBoxContainer/TestButton
@onready var quit_button: Button = $VBoxContainer/QuitButton

func _ready():
	ga_button.pressed.connect(_on_ga_pressed)
	test_button.pressed.connect(_on_test_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

## 进入遗传算法构筑系统
func _on_ga_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/test/test_main.tscn")

## 进入法术测试场
func _on_test_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/battle_test/battle_test_scene.tscn")

## 退出
func _on_quit_pressed() -> void:
	get_tree().quit()
