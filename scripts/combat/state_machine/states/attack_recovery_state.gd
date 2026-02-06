extends State
class_name AttackRecoveryState

## 攻击恢复状态
## 在此阶段：
## - 武器从攻击结束位置恢复到休息位置
## - 检测连击输入
## - 允许有限的旋转
## 【优化】消除重复类型转换、缓存 visuals 引用

var player: PlayerController

var current_attack: AttackData = null
var input_type: int = 0
var combo_index: int = 0
var recovery_timer: float = 0.0
var from_fly: bool = false

var combo_input_detected: bool = false
var next_input: InputBuffer.BufferedInput = null

## 武器恢复状态
var weapon_recovery_started: bool = false

## 【优化】缓存 PlayerVisuals 引用
var _cached_visuals: PlayerVisuals = null

func initialize(_owner: Node) -> void:
	super.initialize(_owner)
	player = _owner as PlayerController

func enter(params: Dictionary = {}) -> void:
	player.can_move = true
	player.can_rotate = true  ## 恢复阶段允许旋转
	player.is_attacking = true
	player.current_attack_phase = "recovery"

	## 【优化】一次性缓存 visuals 引用
	_cached_visuals = player.visuals as PlayerVisuals if player.visuals != null else null

	current_attack = params.get("attack", null)
	player.current_attack = current_attack
	input_type = params.get("input_type", 0)
	combo_index = params.get("combo_index", 0)
	from_fly = params.get("from_fly", false)

	recovery_timer = 0.0
	combo_input_detected = false
	next_input = null
	weapon_recovery_started = false

	if current_attack == null:
		transition_to("Idle")
		return

	## 切换攻击方向（用于双手武器交替攻击）
	if player.current_weapon != null:
		player.current_weapon.toggle_attack_direction()

	## 开始武器恢复动画
	_start_weapon_recovery()

func exit() -> void:
	recovery_timer = 0.0
	combo_input_detected = false
	next_input = null
	weapon_recovery_started = false
	player.is_attacking = false
	player.current_attack = null
	player.current_attack_phase = ""
	_cached_visuals = null

func physics_update(delta: float) -> void:
	recovery_timer += delta

	## 检测连击输入
	if current_attack != null and current_attack.can_combo:
		_check_combo_input()

	if current_attack != null and recovery_timer >= current_attack.recovery_time:
		_on_recovery_complete()

func _start_weapon_recovery() -> void:
	if weapon_recovery_started:
		return

	## 【优化】使用缓存的 visuals 引用
	if _cached_visuals != null and _cached_visuals.weapon_physics != null:
		_cached_visuals.weapon_physics.set_to_rest()

	weapon_recovery_started = true

func _check_combo_input() -> void:
	if combo_input_detected:
		return

	if player.input_buffer == null:
		return

	## 计算连击窗口开始时间
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

		## 检查角度是否合适
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
		## 确保武器回到休息位置
		_ensure_weapon_at_rest()

		if from_fly and player.is_flying:
			transition_to("Fly")
		elif player.input_direction.length_squared() > 0.01:
			transition_to("Move")
		else:
			transition_to("Idle")

func _ensure_weapon_at_rest() -> void:
	## 【优化】使用缓存的 visuals 引用
	if _cached_visuals != null and _cached_visuals.weapon_physics != null:
		if not _cached_visuals.weapon_physics.get_is_settled():
			## 如果还没稳定，强制设置到休息位置
			_cached_visuals.weapon_physics.set_to_rest()
