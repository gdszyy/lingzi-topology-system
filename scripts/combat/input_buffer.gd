class_name InputBuffer extends Node

enum InputType {
	ATTACK_PRIMARY,
	ATTACK_SECONDARY,
	ATTACK_COMBO,
	DODGE,
	SPELL,
	INTERACT
}

class BufferedInput:
	var type: InputType
	var timestamp: float
	var position: Vector2
	var direction: Vector2

	func _init(_type: InputType, _timestamp: float, _position: Vector2 = Vector2.ZERO, _direction: Vector2 = Vector2.ZERO):
		type = _type
		timestamp = _timestamp
		position = _position
		direction = _direction

@export var buffer_duration: float = 0.2
@export var max_buffer_size: int = 3

var input_queue: Array[BufferedInput] = []

var current_time: float = 0.0

var last_primary_pressed: bool = false
var last_secondary_pressed: bool = false

func _process(delta: float) -> void:
	current_time += delta
	_clean_expired_inputs()

func _clean_expired_inputs() -> void:
	var valid_inputs: Array[BufferedInput] = []
	for input in input_queue:
		if current_time - input.timestamp <= buffer_duration:
			valid_inputs.append(input)
	input_queue = valid_inputs

func buffer_input(type: InputType, position: Vector2 = Vector2.ZERO, direction: Vector2 = Vector2.ZERO) -> void:
	var buffered = BufferedInput.new(type, current_time, position, direction)
	input_queue.append(buffered)

	while input_queue.size() > max_buffer_size:
		input_queue.pop_front()

func consume_input(type: InputType) -> BufferedInput:
	for i in range(input_queue.size()):
		if input_queue[i].type == type:
			var input = input_queue[i]
			input_queue.remove_at(i)
			return input
	return null

func consume_any_attack() -> BufferedInput:
	for i in range(input_queue.size()):
		var input_type = input_queue[i].type
		if input_type in [InputType.ATTACK_PRIMARY, InputType.ATTACK_SECONDARY, InputType.ATTACK_COMBO]:
			var input = input_queue[i]
			input_queue.remove_at(i)
			return input
	return null

func has_buffered_input(type: InputType) -> bool:
	for input in input_queue:
		if input.type == type:
			return true
	return false

func has_any_attack_input() -> bool:
	for input in input_queue:
		if input.type in [InputType.ATTACK_PRIMARY, InputType.ATTACK_SECONDARY, InputType.ATTACK_COMBO]:
			return true
	return false

func get_latest_input() -> BufferedInput:
	if input_queue.size() > 0:
		return input_queue[input_queue.size() - 1]
	return null

func clear() -> void:
	input_queue.clear()

func process_input_event(event: InputEvent, mouse_position: Vector2, move_direction: Vector2) -> void:
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.pressed:
			var primary_pressed = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
			var secondary_pressed = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)

			if primary_pressed and secondary_pressed:
				buffer_input(InputType.ATTACK_COMBO, mouse_position, move_direction)
			elif mouse_event.button_index == MOUSE_BUTTON_LEFT:
				buffer_input(InputType.ATTACK_PRIMARY, mouse_position, move_direction)
			elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
				buffer_input(InputType.ATTACK_SECONDARY, mouse_position, move_direction)

	if event is InputEventKey:
		var key_event = event as InputEventKey
		if key_event.pressed and not key_event.echo:
			if key_event.keycode == KEY_E:
				buffer_input(InputType.INTERACT, mouse_position, move_direction)
			elif key_event.keycode == KEY_Q:
				buffer_input(InputType.SPELL, mouse_position, move_direction)
			elif key_event.keycode == KEY_SHIFT:
				buffer_input(InputType.DODGE, mouse_position, move_direction)
