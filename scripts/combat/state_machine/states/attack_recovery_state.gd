extends State
class_name AttackRecoveryState

var player: PlayerController

var current_attack: AttackData = null

var input_type: int = 0

var combo_index: int = 0

var recovery_timer: float = 0.0

var from_fly: bool = false

var combo_input_detected: bool = false
var next_input: InputBuffer.BufferedInput = null

func initialize(_owner: Node) -> void:
	super.initialize(_owner)
	player = _owner as PlayerController

func enter(params: Dictionary = {}) -> void:
	player.can_move = false
	player.can_rotate = true
	player.is_attacking = true

	current_attack = params.get("attack", null)
	input_type = params.get("input_type", 0)
	combo_index = params.get("combo_index", 0)
	from_fly = params.get("from_fly", false)

	recovery_timer = 0.0
	combo_input_detected = false
	next_input = null

	if current_attack == null:
		transition_to("Idle")
		return

	_play_recovery_animation()

func exit() -> void:
	recovery_timer = 0.0
	combo_input_detected = false
	next_input = null
	player.is_attacking = false

func physics_update(delta: float) -> void:
	recovery_timer += delta

	if current_attack != null and current_attack.can_combo:
		_check_combo_input()

	if current_attack != null and recovery_timer >= current_attack.recovery_time:
		_on_recovery_complete()

func _check_combo_input() -> void:
	if combo_input_detected:
		return

	if player.input_buffer == null:
		return

	var combo_window_start = current_attack.recovery_time - current_attack.combo_window
	if recovery_timer < combo_window_start:
		return

	var buffered_attack = player.input_buffer.consume_any_attack()
	if buffered_attack != null:
		combo_input_detected = true
		next_input = buffered_attack

func _on_recovery_complete() -> void:
	if combo_input_detected and next_input != null:
		var next_combo_index = combo_index + 1

		if current_attack.next_combo_index >= 0:
			next_combo_index = current_attack.next_combo_index

		if player.can_attack_at_angle():
			transition_to("AttackWindup", {
				"input": next_input,
				"combo_index": next_combo_index,
				"from_fly": from_fly
			})
		else:
			transition_to("Turn", {
				"next_state": "AttackWindup",
				"input": next_input,
				"combo_index": next_combo_index,
				"from_fly": from_fly
			})
	else:
		if from_fly and player.is_flying:
			transition_to("Fly")
		elif player.input_direction.length_squared() > 0.01:
			transition_to("Move")
		else:
			transition_to("Idle")

func _play_recovery_animation() -> void:
	if current_attack == null:
		return
