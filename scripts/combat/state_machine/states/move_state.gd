# move_state.gd
# 移动状态 - 角色地面移动时的状态
extends State
class_name MoveState

## 玩家控制器引用
var player: PlayerController

func initialize(_owner: Node) -> void:
	super.initialize(_owner)
	player = _owner as PlayerController

func enter(_params: Dictionary = {}) -> void:
	player.can_move = true
	player.can_rotate = true
	player.is_attacking = false

func physics_update(_delta: float) -> void:
	# 检测是否停止移动
	if player.input_direction.length_squared() < 0.01:
		transition_to("Idle")
		return
	
	# 检测飞行输入
	if player.is_flying:
		transition_to("Fly")
		return
	
	# 检测攻击输入
	_check_attack_input()
	
	# 检测施法输入
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
