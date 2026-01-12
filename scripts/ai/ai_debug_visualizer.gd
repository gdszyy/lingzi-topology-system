@tool
class_name AIDebugVisualizer extends Node2D

## AI调试可视化器
## 在编辑器和运行时显示AI的感知范围、目标、状态等信息
## 用于调试和优化AI行为

@export var enabled: bool = true
@export var show_perception_range: bool = true
@export var show_attack_range: bool = true
@export var show_target_line: bool = true
@export var show_state_label: bool = true
@export var show_health_info: bool = true
@export var show_body_parts: bool = true

@export_group("颜色配置")
@export var perception_color: Color = Color(0.2, 0.6, 1.0, 0.2)
@export var attack_range_color: Color = Color(1.0, 0.3, 0.3, 0.3)
@export var target_line_color: Color = Color(1.0, 0.0, 0.0, 0.8)
@export var state_label_color: Color = Color(1.0, 1.0, 1.0, 1.0)

var ai: EnemyAIController = null
var font: Font = null

func _ready() -> void:
	ai = get_parent() as EnemyAIController
	
	# 获取默认字体
	font = ThemeDB.fallback_font

func _process(_delta: float) -> void:
	if enabled:
		queue_redraw()

func _draw() -> void:
	if not enabled or ai == null:
		return
	
	if show_perception_range:
		_draw_perception_range()
	
	if show_attack_range:
		_draw_attack_range()
	
	if show_target_line:
		_draw_target_line()
	
	if show_state_label:
		_draw_state_label()
	
	if show_health_info:
		_draw_health_info()
	
	if show_body_parts:
		_draw_body_parts()

## 绘制感知范围
func _draw_perception_range() -> void:
	if ai.perception == null:
		return
	
	var radius = ai.perception.perception_radius
	draw_circle(Vector2.ZERO, radius, perception_color)
	draw_arc(Vector2.ZERO, radius, 0, TAU, 64, perception_color.lightened(0.3), 2.0)

## 绘制攻击范围
func _draw_attack_range() -> void:
	if ai.behavior_profile == null:
		return
	
	var radius = ai.behavior_profile.attack_range
	draw_circle(Vector2.ZERO, radius, attack_range_color)
	draw_arc(Vector2.ZERO, radius, 0, TAU, 32, attack_range_color.lightened(0.3), 2.0)
	
	# 绘制最佳攻击距离
	var optimal_distance = ai.behavior_profile.get_optimal_attack_distance()
	draw_arc(Vector2.ZERO, optimal_distance, 0, TAU, 32, Color(0.0, 1.0, 0.0, 0.5), 1.5)

## 绘制目标连线
func _draw_target_line() -> void:
	if ai.current_target == null:
		return
	
	var target_pos = ai.current_target.global_position - ai.global_position
	draw_line(Vector2.ZERO, target_pos, target_line_color, 2.0)
	
	# 绘制目标标记
	draw_circle(target_pos, 10, target_line_color)
	
	# 如果有目标肢体，显示肢体名称
	if ai.target_selector != null and ai.target_selector.current_target_part >= 0:
		var part_name = ai.target_selector.get_target_part_name()
		if font != null:
			draw_string(font, target_pos + Vector2(15, 5), part_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.YELLOW)

## 绘制状态标签
func _draw_state_label() -> void:
	if ai.state_machine == null:
		return
	
	var state_name = "Unknown"
	if ai.state_machine.current_state != null:
		state_name = ai.state_machine.current_state.name
	
	var label_pos = Vector2(-30, -50)
	
	# 绘制背景
	var label_size = Vector2(80, 20)
	draw_rect(Rect2(label_pos - Vector2(5, 15), label_size), Color(0, 0, 0, 0.7))
	
	# 绘制状态文本
	if font != null:
		draw_string(font, label_pos, state_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, state_label_color)

## 绘制生命值信息
func _draw_health_info() -> void:
	if ai.energy_system == null:
		return
	
	var health_percent = ai.get_health_percent()
	var info_pos = Vector2(-30, 40)
	
	# 绘制能量条背景
	var bar_width = 60.0
	var bar_height = 8.0
	draw_rect(Rect2(info_pos, Vector2(bar_width, bar_height)), Color(0.2, 0.2, 0.2, 0.8))
	
	# 绘制能量条
	var fill_width = bar_width * health_percent
	var fill_color = Color.GREEN
	if health_percent < 0.5:
		fill_color = Color.YELLOW
	if health_percent < 0.25:
		fill_color = Color.RED
	draw_rect(Rect2(info_pos, Vector2(fill_width, bar_height)), fill_color)
	
	# 绘制边框
	draw_rect(Rect2(info_pos, Vector2(bar_width, bar_height)), Color.WHITE, false, 1.0)

## 绘制肢体状态
func _draw_body_parts() -> void:
	if not ai.use_voxel_system or ai.body_parts.is_empty():
		return
	
	var start_pos = Vector2(40, -30)
	var line_height = 12
	
	for i in range(ai.body_parts.size()):
		var part = ai.body_parts[i]
		var pos = start_pos + Vector2(0, i * line_height)
		
		# 确定颜色
		var color = Color.GREEN
		match part.damage_state:
			BodyPartData.DamageState.DAMAGED:
				color = Color.YELLOW
			BodyPartData.DamageState.CRITICAL:
				color = Color.ORANGE
			BodyPartData.DamageState.CRIPPLED:
				color = Color.RED
			BodyPartData.DamageState.DESTROYED:
				color = Color.DARK_RED
		
		# 绘制肢体名称和状态
		var text = "%s: %.0f%%" % [part.get_type_name().substr(0, 2), part.get_health_percent() * 100]
		if font != null:
			draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, color)

## 切换调试显示
func toggle_debug() -> void:
	enabled = not enabled

## 设置显示选项
func set_display_options(options: Dictionary) -> void:
	show_perception_range = options.get("perception", show_perception_range)
	show_attack_range = options.get("attack", show_attack_range)
	show_target_line = options.get("target", show_target_line)
	show_state_label = options.get("state", show_state_label)
	show_health_info = options.get("health", show_health_info)
	show_body_parts = options.get("body_parts", show_body_parts)
