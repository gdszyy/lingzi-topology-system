extends State
class_name FlyState

var player: PlayerController

var fly_duration: float = 0.0

func initialize(_owner: Node) -> void:
	super.initialize(_owner)
	player = _owner as PlayerController

func enter(_params: Dictionary = {}) -> void:
	player.can_move = true
	player.can_rotate = true
	player.is_attacking = false
	fly_duration = 0.0

func exit() -> void:
	fly_duration = 0.0

func physics_update(delta: float) -> void:
	fly_duration += delta

	if not player.is_flying:
		if player.input_direction.length_squared() > 0.01:
			transition_to("Move")
		else:
			transition_to("Idle")
		return

	_check_attack_input()

func _check_attack_input() -> void:
	if player.input_buffer == null:
		return

	var attack_input = player.input_buffer.consume_any_attack()
	if attack_input != null:
		if player.can_attack_at_angle():
			transition_to("AttackWindup", {"input": attack_input, "from_fly": true})
		else:
			transition_to("Turn", {"next_state": "AttackWindup", "input": attack_input, "from_fly": true})
