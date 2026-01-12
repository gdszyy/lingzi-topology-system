# input_buffer.gd
# 输入缓存系统 - 缓存玩家输入以实现流畅的连击
class_name InputBuffer extends Node

## 输入类型枚举
enum InputType {
	ATTACK_PRIMARY,    # 左键攻击
	ATTACK_SECONDARY,  # 右键攻击
	ATTACK_COMBO,      # 组合攻击
	DODGE,             # 闪避
	SPELL,             # 施法
	INTERACT           # 交互
}

## 缓存的输入数据
class BufferedInput:
	var type: InputType
	var timestamp: float
	var position: Vector2  # 鼠标位置（用于攻击方向）
	var direction: Vector2  # 移动方向
	
	func _init(_type: InputType, _timestamp: float, _position: Vector2 = Vector2.ZERO, _direction: Vector2 = Vector2.ZERO):
		type = _type
		timestamp = _timestamp
		position = _position
		direction = _direction

## 配置
@export var buffer_duration: float = 0.2  # 输入缓存持续时间
@export var max_buffer_size: int = 3  # 最大缓存数量

## 输入缓存队列
var input_queue: Array[BufferedInput] = []

## 当前时间戳
var current_time: float = 0.0

## 上一帧的输入状态（用于检测同时按键）
var last_primary_pressed: bool = false
var last_secondary_pressed: bool = false

func _process(delta: float) -> void:
	current_time += delta
	_clean_expired_inputs()

## 清理过期的输入
func _clean_expired_inputs() -> void:
	var valid_inputs: Array[BufferedInput] = []
	for input in input_queue:
		if current_time - input.timestamp <= buffer_duration:
			valid_inputs.append(input)
	input_queue = valid_inputs

## 缓存输入
func buffer_input(type: InputType, position: Vector2 = Vector2.ZERO, direction: Vector2 = Vector2.ZERO) -> void:
	var buffered = BufferedInput.new(type, current_time, position, direction)
	input_queue.append(buffered)
	
	# 限制缓存大小
	while input_queue.size() > max_buffer_size:
		input_queue.pop_front()

## 消费指定类型的缓存输入
func consume_input(type: InputType) -> BufferedInput:
	for i in range(input_queue.size()):
		if input_queue[i].type == type:
			var input = input_queue[i]
			input_queue.remove_at(i)
			return input
	return null

## 消费任意攻击输入
func consume_any_attack() -> BufferedInput:
	for i in range(input_queue.size()):
		var input_type = input_queue[i].type
		if input_type in [InputType.ATTACK_PRIMARY, InputType.ATTACK_SECONDARY, InputType.ATTACK_COMBO]:
			var input = input_queue[i]
			input_queue.remove_at(i)
			return input
	return null

## 检查是否有指定类型的缓存输入
func has_buffered_input(type: InputType) -> bool:
	for input in input_queue:
		if input.type == type:
			return true
	return false

## 检查是否有任意攻击输入
func has_any_attack_input() -> bool:
	for input in input_queue:
		if input.type in [InputType.ATTACK_PRIMARY, InputType.ATTACK_SECONDARY, InputType.ATTACK_COMBO]:
			return true
	return false

## 获取最新的缓存输入
func get_latest_input() -> BufferedInput:
	if input_queue.size() > 0:
		return input_queue[input_queue.size() - 1]
	return null

## 清空所有缓存
func clear() -> void:
	input_queue.clear()

## 处理输入事件（由Player调用）
func process_input_event(event: InputEvent, mouse_position: Vector2, move_direction: Vector2) -> void:
	# 检测鼠标按键
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.pressed:
			# 检测同时按键
			var primary_pressed = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
			var secondary_pressed = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
			
			if primary_pressed and secondary_pressed:
				buffer_input(InputType.ATTACK_COMBO, mouse_position, move_direction)
			elif mouse_event.button_index == MOUSE_BUTTON_LEFT:
				buffer_input(InputType.ATTACK_PRIMARY, mouse_position, move_direction)
			elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
				buffer_input(InputType.ATTACK_SECONDARY, mouse_position, move_direction)
	
	# 检测键盘输入
	if event is InputEventKey:
		var key_event = event as InputEventKey
		if key_event.pressed and not key_event.echo:
			if key_event.keycode == KEY_E:
				buffer_input(InputType.INTERACT, mouse_position, move_direction)
			elif key_event.keycode == KEY_Q:
				buffer_input(InputType.SPELL, mouse_position, move_direction)
			elif key_event.keycode == KEY_SHIFT:
				buffer_input(InputType.DODGE, mouse_position, move_direction)
