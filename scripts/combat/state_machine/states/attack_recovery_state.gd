# attack_recovery_state.gd
# 攻击后摇状态 - 攻击动作的恢复阶段，检测连击输入
extends State
class_name AttackRecoveryState

## 玩家控制器引用
var player: PlayerController

## 当前攻击数据
var current_attack: AttackData = null

## 输入类型
var input_type: int = 0

## 连击索引
var combo_index: int = 0

## 后摇计时器
var recovery_timer: float = 0.0

## 是否从飞行状态进入
var from_fly: bool = false

## 是否检测到连击输入
var combo_input_detected: bool = false
var next_input: InputBuffer.BufferedInput = null

func initialize(_owner: Node) -> void:
	super.initialize(_owner)
	player = _owner as PlayerController

func enter(params: Dictionary = {}) -> void:
	player.can_move = false  # 后摇时不能移动
	player.can_rotate = true  # 但可以旋转（准备下一次攻击）
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
	
	# 播放后摇动画
	_play_recovery_animation()

func exit() -> void:
	recovery_timer = 0.0
	combo_input_detected = false
	next_input = null
	player.is_attacking = false

func physics_update(delta: float) -> void:
	recovery_timer += delta
	
	# 在连击窗口内检测输入
	if current_attack != null and current_attack.can_combo:
		_check_combo_input()
	
	# 检查后摇是否结束
	if current_attack != null and recovery_timer >= current_attack.recovery_time:
		_on_recovery_complete()

func _check_combo_input() -> void:
	if combo_input_detected:
		return
	
	if player.input_buffer == null:
		return
	
	# 检查是否在连击窗口内
	var combo_window_start = current_attack.recovery_time - current_attack.combo_window
	if recovery_timer < combo_window_start:
		return
	
	# 检测缓存的攻击输入
	var buffered_attack = player.input_buffer.consume_any_attack()
	if buffered_attack != null:
		combo_input_detected = true
		next_input = buffered_attack

func _on_recovery_complete() -> void:
	if combo_input_detected and next_input != null:
		# 执行连击
		var next_combo_index = combo_index + 1
		
		# 检查是否需要重置连击
		if current_attack.next_combo_index >= 0:
			next_combo_index = current_attack.next_combo_index
		
		# 检查角度
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
		# 返回正常状态
		if from_fly and player.is_flying:
			transition_to("Fly")
		elif player.input_direction.length_squared() > 0.01:
			transition_to("Move")
		else:
			transition_to("Idle")

func _play_recovery_animation() -> void:
	if current_attack == null:
		return
	
	# TODO: 播放实际动画
	# player.animation_player.play(current_attack.animation_name + "_recovery")
