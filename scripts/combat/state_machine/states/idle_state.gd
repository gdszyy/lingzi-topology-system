extends State
class_name IdleState

var player: PlayerController

func initialize(_owner: Node) -> void:
	super.initialize(_owner)
	player = _owner as PlayerController

func enter(_params: Dictionary = {}) -> void:
	player.can_move = true
	player.can_rotate = true
	player.is_attacking = false

func physics_update(_delta: float) -> void:
	if player.input_direction.length_squared() > 0.01:
		if player.is_flying:
			transition_to("Fly")
		else:
			transition_to("Move")

	_check_attack_input()

	_check_spell_input()

func _check_attack_input() -> void:
	if player.input_buffer == null:
		return

	var attack_input = player.input_buffer.consume_any_attack()
	if attack_input != null:
		if player.can_attack_at_angle():
			transition_to("AttackWindup", {"input": attack_input})
		else:
			transition_to("Turn", {"next_state": "AttackWindup", "input": attack_input})

func _check_spell_input() -> void:
	if player.input_buffer == null:
		return

	var spell_input = player.input_buffer.consume_input(InputBuffer.InputType.SPELL)
	if spell_input != null and player.current_spell != null:
		if player.can_cast_at_angle():
			transition_to("SpellCast", {"input": spell_input})
		else:
			transition_to("Turn", {"next_state": "SpellCast", "input": spell_input})

func handle_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.pressed:
			if mouse_event.button_index == MOUSE_BUTTON_LEFT or mouse_event.button_index == MOUSE_BUTTON_RIGHT:
				pass
