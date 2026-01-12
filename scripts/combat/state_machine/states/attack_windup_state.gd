extends State
class_name AttackWindupState

var player: PlayerController

var current_attack: AttackData = null

var input_type: int = 0

var combo_index: int = 0

var windup_timer: float = 0.0

var from_fly: bool = false

func initialize(_owner: Node) -> void:
	super.initialize(_owner)
	player = _owner as PlayerController

func enter(params: Dictionary = {}) -> void:
	player.can_move = false
	player.can_rotate = false
	player.is_attacking = true

	var input = params.get("input", null)
	if input != null:
		match input.type:
			InputBuffer.InputType.ATTACK_PRIMARY:
				input_type = 0
			InputBuffer.InputType.ATTACK_SECONDARY:
				input_type = 1
			InputBuffer.InputType.ATTACK_COMBO:
				input_type = 2

	combo_index = params.get("combo_index", 0)
	from_fly = params.get("from_fly", false)

	current_attack = _get_attack_data()

	if current_attack == null:
		transition_to("Idle")
		return

	windup_timer = 0.0

	_play_windup_animation()

	player.attack_started.emit(current_attack)

func exit() -> void:
	windup_timer = 0.0
	current_attack = null

func physics_update(delta: float) -> void:
	windup_timer += delta

	if current_attack != null and windup_timer >= current_attack.windup_time:
		transition_to("AttackActive", {
			"attack": current_attack,
			"input_type": input_type,
			"combo_index": combo_index,
			"from_fly": from_fly
		})

func _get_attack_data() -> AttackData:
	if player.current_weapon == null:
		return null

	var attacks = player.current_weapon.get_attacks_for_input(input_type)
	if attacks.size() == 0:
		return null

	var index = combo_index % attacks.size()
	return attacks[index]

func _play_windup_animation() -> void:
	if current_attack == null:
		return
