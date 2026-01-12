extends Window
class_name SpellNestingViewer
## 法术嵌套结构查看器窗口
## 提供独立窗口查看法术的多层嵌套结构

signal viewer_closed

@onready var tree_view: SpellNestingTreeView = $SpellNestingTreeView
@onready var close_button: Button = $SpellNestingTreeView/VBox/TitleBar/CloseButton

func _ready() -> void:
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	close_requested.connect(_on_close_requested)
	
	# 设置窗口属性
	title = "法术嵌套结构查看器"
	size = Vector2i(800, 600)
	min_size = Vector2i(600, 400)

func show_spell(spell: SpellCoreData) -> void:
	if tree_view:
		tree_view.load_spell(spell)
	show()

func _on_close_pressed() -> void:
	hide()
	viewer_closed.emit()

func _on_close_requested() -> void:
	hide()
	viewer_closed.emit()
