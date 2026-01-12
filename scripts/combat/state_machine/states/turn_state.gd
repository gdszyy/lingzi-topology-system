extends State
class_name TurnState

var player: PlayerController

var next_state: String = "Idle"

var next_params: Dictionary = {}

var max_turn_time: float = 1.0
var turn_timer: float = 0.0

func initialize(_owner: Node) -> void:
	super.initialize(_owner)
	player = _owner as PlayerController

func enter(params: Dictionary = {}) -> void:
	player.can_move = false
	player.can_rotate = true

	next_state = params.get("next_state", "Idle")
	next_params = params.duplicate()
	next_params.erase("next_state")

	turn_timer = 0.0

func exit() -> void:
	turn_timer = 0.0

func physics_update(delta: float) -> void:
	turn_timer += delta

	if turn_timer >= max_turn_time:
		transition_to("Idle")
		return

	var is_attack = next_state == "AttackWindup"
	var angle_valid = false

	if is_attack:
		angle_valid = player.can_attack_at_angle()
	else:
		angle_valid = player.can_cast_at_angle()

	if angle_valid:
		transition_to(next_state, next_params)
