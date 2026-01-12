extends State
class_name TurnState

## 转身状态
## 当角色需要转向才能攻击或施法时进入此状态
## 实现了角速度上限和各种加成机制

var player: PlayerController

var next_state: String = "Idle"
var next_params: Dictionary = {}
var max_turn_time: float = 1.0
var turn_timer: float = 0.0

## 角速度物理
var current_angular_velocity: float = 0.0
var angular_acceleration: float = 50.0  ## 角加速度

func initialize(_owner: Node) -> void:
	super.initialize(_owner)
	player = _owner as PlayerController

func enter(params: Dictionary = {}) -> void:
	player.can_move = true  ## 允许移动
	player.can_rotate = false  ## 禁用默认旋转，使用自定义角速度物理

	next_state = params.get("next_state", "Idle")
	next_params = params.duplicate()
	next_params.erase("next_state")

	turn_timer = 0.0
	current_angular_velocity = 0.0

func exit() -> void:
	turn_timer = 0.0
	current_angular_velocity = 0.0
	player.can_rotate = true

func physics_update(delta: float) -> void:
	turn_timer += delta

	if turn_timer >= max_turn_time:
		transition_to("Idle")
		return

	## 应用角速度物理
	_apply_angular_physics(delta)

	## 检查是否已经转到位
	var is_attack = next_state == "AttackWindup"
	var angle_valid = false

	if is_attack:
		angle_valid = player.can_attack_at_angle()
	else:
		angle_valid = player.can_cast_at_angle()

	if angle_valid:
		transition_to(next_state, next_params)

func _get_max_angular_velocity() -> float:
	var config = player.movement_config
	
	## 基础角速度
	var base_speed = config.base_turn_speed
	
	## 站定状态加成（站定时转身更快）
	var is_standing = player.velocity.length_squared() < 100
	if is_standing:
		base_speed *= config.standing_turn_bonus
	else:
		base_speed *= config.moving_turn_penalty
	
	## 垂直移动加成（面向与移动方向垂直时，转身更快）
	if player.input_direction.length_squared() > 0.01:
		var dot = abs(player.current_facing_direction.dot(player.input_direction))
		var perpendicular_factor = 1.0 - dot  ## 越垂直，factor越大
		base_speed *= lerpf(1.0, config.perpendicular_turn_bonus, perpendicular_factor)
	
	## 武器重量影响
	if player.current_weapon != null:
		base_speed *= player.current_weapon.get_turn_speed_modifier()
	
	return base_speed

func _apply_angular_physics(delta: float) -> void:
	var current_angle = player.torso_pivot.rotation
	var angle_diff = angle_difference(current_angle, player.target_angle)
	
	var max_angular_velocity = _get_max_angular_velocity()
	
	## 计算目标角速度
	var target_angular_velocity = sign(angle_diff) * max_angular_velocity
	
	## 如果角度差很小，减小目标角速度以避免过冲
	var abs_diff = abs(angle_diff)
	if abs_diff < 0.5:  ## 约30度
		target_angular_velocity *= abs_diff / 0.5
	
	## 应用角加速度
	if abs(target_angular_velocity) > abs(current_angular_velocity):
		## 加速
		current_angular_velocity = move_toward(
			current_angular_velocity, 
			target_angular_velocity, 
			angular_acceleration * delta
		)
	else:
		## 减速（更快的减速以避免过冲）
		current_angular_velocity = move_toward(
			current_angular_velocity, 
			target_angular_velocity, 
			angular_acceleration * 2.0 * delta
		)
	
	## 限制最大角速度
	current_angular_velocity = clamp(current_angular_velocity, -max_angular_velocity, max_angular_velocity)
	
	## 应用旋转
	player.torso_pivot.rotation += current_angular_velocity * delta
	player.current_facing_direction = Vector2.from_angle(player.torso_pivot.rotation)

## 获取当前角速度
func get_angular_velocity() -> float:
	return current_angular_velocity

## 获取剩余转身角度
func get_remaining_angle() -> float:
	return abs(angle_difference(player.torso_pivot.rotation, player.target_angle))
