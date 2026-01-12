class_name CombatFeedbackSystem extends Node

## 战斗反馈系统
## 提供视觉和音效反馈，增强战斗体验
## 包括伤害数字、状态提示、特效等

signal damage_displayed(amount: float, position: Vector2, is_critical: bool)
signal status_displayed(text: String, position: Vector2, color: Color)

# 配置
@export var damage_number_enabled: bool = true
@export var status_text_enabled: bool = true
@export var screen_shake_enabled: bool = true
@export var hit_pause_enabled: bool = true

@export_group("伤害数字")
@export var damage_font_size: int = 20
@export var critical_font_size: int = 28
@export var damage_float_speed: float = 80.0
@export var damage_fade_time: float = 1.0
@export var damage_spread: float = 30.0

@export_group("屏幕震动")
@export var shake_intensity: float = 5.0
@export var shake_duration: float = 0.1
@export var critical_shake_multiplier: float = 2.0

@export_group("命中暂停")
@export var hit_pause_duration: float = 0.05
@export var critical_hit_pause_duration: float = 0.1

# 内部状态
var _active_damage_numbers: Array[Node2D] = []
var _shake_timer: float = 0.0
var _shake_intensity: float = 0.0
var _original_camera_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	# 更新屏幕震动
	if _shake_timer > 0:
		_shake_timer -= delta
		_apply_screen_shake()
	elif _shake_intensity > 0:
		_shake_intensity = 0
		_reset_camera_offset()

## 显示伤害数字
func show_damage(amount: float, position: Vector2, is_critical: bool = false, is_heal: bool = false) -> void:
	if not damage_number_enabled:
		return
	
	var damage_label = Label.new()
	damage_label.text = ("+" if is_heal else "-") + str(int(amount))
	damage_label.global_position = position + Vector2(randf_range(-damage_spread, damage_spread), -20)
	
	# 设置样式
	var font_size = critical_font_size if is_critical else damage_font_size
	damage_label.add_theme_font_size_override("font_size", font_size)
	
	var color: Color
	if is_heal:
		color = Color.GREEN
	elif is_critical:
		color = Color.YELLOW
	else:
		color = Color.WHITE
	
	damage_label.add_theme_color_override("font_color", color)
	damage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# 添加到场景
	get_tree().current_scene.add_child(damage_label)
	_active_damage_numbers.append(damage_label)
	
	# 动画
	_animate_damage_number(damage_label, is_critical)
	
	damage_displayed.emit(amount, position, is_critical)

## 动画伤害数字
func _animate_damage_number(label: Label, is_critical: bool) -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	
	# 向上飘动
	var target_pos = label.global_position + Vector2(0, -damage_float_speed)
	tween.tween_property(label, "global_position", target_pos, damage_fade_time)
	
	# 淡出
	tween.tween_property(label, "modulate:a", 0.0, damage_fade_time)
	
	# 暴击时放大后缩小
	if is_critical:
		var scale_tween = create_tween()
		scale_tween.tween_property(label, "scale", Vector2(1.5, 1.5), 0.1)
		scale_tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.2)
	
	# 完成后删除
	tween.tween_callback(func():
		_active_damage_numbers.erase(label)
		label.queue_free()
	).set_delay(damage_fade_time)

## 显示状态文本
func show_status(text: String, position: Vector2, color: Color = Color.WHITE) -> void:
	if not status_text_enabled:
		return
	
	var status_label = Label.new()
	status_label.text = text
	status_label.global_position = position + Vector2(0, -40)
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.add_theme_color_override("font_color", color)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	get_tree().current_scene.add_child(status_label)
	
	# 动画
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(status_label, "global_position:y", status_label.global_position.y - 50, 0.8)
	tween.tween_property(status_label, "modulate:a", 0.0, 0.8)
	tween.tween_callback(status_label.queue_free).set_delay(0.8)
	
	status_displayed.emit(text, position, color)

## 显示连击数
func show_combo(combo_count: int, position: Vector2) -> void:
	if combo_count < 2:
		return
	
	var combo_label = Label.new()
	combo_label.text = "x%d COMBO!" % combo_count
	combo_label.global_position = position + Vector2(0, -60)
	combo_label.add_theme_font_size_override("font_size", 24)
	
	# 根据连击数变色
	var color: Color
	if combo_count >= 10:
		color = Color.GOLD
	elif combo_count >= 5:
		color = Color.ORANGE
	else:
		color = Color.YELLOW
	
	combo_label.add_theme_color_override("font_color", color)
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	get_tree().current_scene.add_child(combo_label)
	
	# 动画
	var tween = create_tween()
	tween.tween_property(combo_label, "scale", Vector2(1.3, 1.3), 0.1)
	tween.tween_property(combo_label, "scale", Vector2(1.0, 1.0), 0.2)
	tween.tween_property(combo_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(combo_label.queue_free)

## 显示击杀提示
func show_kill(enemy_name: String, score: int, position: Vector2) -> void:
	var kill_label = Label.new()
	kill_label.text = "击杀 %s +%d" % [enemy_name, score]
	kill_label.global_position = position
	kill_label.add_theme_font_size_override("font_size", 18)
	kill_label.add_theme_color_override("font_color", Color.LIME_GREEN)
	kill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	get_tree().current_scene.add_child(kill_label)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(kill_label, "global_position:y", kill_label.global_position.y - 80, 1.2)
	tween.tween_property(kill_label, "modulate:a", 0.0, 1.2)
	tween.tween_callback(kill_label.queue_free).set_delay(1.2)

## 显示波次提示
func show_wave_start(wave_number: int) -> void:
	var wave_label = Label.new()
	wave_label.text = "波次 %d" % wave_number
	wave_label.add_theme_font_size_override("font_size", 48)
	wave_label.add_theme_color_override("font_color", Color.WHITE)
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# 居中显示
	var viewport_size = get_viewport().get_visible_rect().size
	wave_label.global_position = viewport_size / 2 - Vector2(100, 30)
	
	get_tree().current_scene.add_child(wave_label)
	
	# 动画
	wave_label.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(wave_label, "modulate:a", 1.0, 0.3)
	tween.tween_interval(1.0)
	tween.tween_property(wave_label, "modulate:a", 0.0, 0.5)
	tween.tween_property(wave_label, "scale", Vector2(1.5, 1.5), 0.5)
	tween.tween_callback(wave_label.queue_free)

## 显示波次完成
func show_wave_complete(wave_number: int, enemies_killed: int) -> void:
	var complete_label = Label.new()
	complete_label.text = "波次 %d 完成!\n击杀: %d" % [wave_number, enemies_killed]
	complete_label.add_theme_font_size_override("font_size", 36)
	complete_label.add_theme_color_override("font_color", Color.GOLD)
	complete_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	var viewport_size = get_viewport().get_visible_rect().size
	complete_label.global_position = viewport_size / 2 - Vector2(120, 40)
	
	get_tree().current_scene.add_child(complete_label)
	
	complete_label.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(complete_label, "modulate:a", 1.0, 0.3)
	tween.tween_interval(1.5)
	tween.tween_property(complete_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(complete_label.queue_free)

## 触发屏幕震动
func trigger_screen_shake(intensity: float = -1, duration: float = -1) -> void:
	if not screen_shake_enabled:
		return
	
	_shake_intensity = intensity if intensity > 0 else shake_intensity
	_shake_timer = duration if duration > 0 else shake_duration

## 触发暴击屏幕震动
func trigger_critical_shake() -> void:
	trigger_screen_shake(shake_intensity * critical_shake_multiplier, shake_duration * 1.5)

## 应用屏幕震动
func _apply_screen_shake() -> void:
	var camera = get_viewport().get_camera_2d()
	if camera == null:
		return
	
	var offset = Vector2(
		randf_range(-_shake_intensity, _shake_intensity),
		randf_range(-_shake_intensity, _shake_intensity)
	)
	camera.offset = _original_camera_offset + offset

## 重置相机偏移
func _reset_camera_offset() -> void:
	var camera = get_viewport().get_camera_2d()
	if camera != null:
		camera.offset = _original_camera_offset

## 触发命中暂停
func trigger_hit_pause(is_critical: bool = false) -> void:
	if not hit_pause_enabled:
		return
	
	var duration = critical_hit_pause_duration if is_critical else hit_pause_duration
	
	Engine.time_scale = 0.1
	await get_tree().create_timer(duration * 0.1).timeout  # 考虑时间缩放
	Engine.time_scale = 1.0

## 显示肢体损伤提示
func show_body_part_damage(part_name: String, damage_state: String, position: Vector2) -> void:
	var color: Color
	match damage_state:
		"damaged":
			color = Color.YELLOW
		"critical":
			color = Color.ORANGE
		"crippled":
			color = Color.RED
		"destroyed":
			color = Color.DARK_RED
		_:
			color = Color.WHITE
	
	show_status("%s %s" % [part_name, damage_state], position, color)

## 显示闪避提示
func show_dodge(position: Vector2) -> void:
	show_status("闪避!", position, Color.CYAN)

## 显示格挡提示
func show_block(position: Vector2) -> void:
	show_status("格挡!", position, Color.LIGHT_BLUE)

## 显示反击提示
func show_counter(position: Vector2) -> void:
	show_status("反击!", position, Color.ORANGE)

## 清理所有活动的伤害数字
func clear_all() -> void:
	for label in _active_damage_numbers:
		if is_instance_valid(label):
			label.queue_free()
	_active_damage_numbers.clear()
