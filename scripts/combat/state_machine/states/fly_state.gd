extends State
class_name FlyState

## 飞行状态
## 飞行时方向键控制加速度而非直接速度
## 具有惯性滑行效果和最大速度限制

var player: PlayerController

var fly_duration: float = 0.0

## 飞行物理状态
var flight_velocity: Vector2 = Vector2.ZERO

func initialize(_owner: Node) -> void:
	super.initialize(_owner)
	player = _owner as PlayerController

func enter(_params: Dictionary = {}) -> void:
	player.can_move = false  ## 禁用默认移动，使用自定义飞行物理
	player.can_rotate = true
	player.is_attacking = false
	fly_duration = 0.0
	
	## 继承进入飞行时的速度
	flight_velocity = player.velocity

func exit() -> void:
	fly_duration = 0.0
	## 将飞行速度传递回玩家
	player.velocity = flight_velocity

func physics_update(delta: float) -> void:
	fly_duration += delta

	if not player.is_flying:
		if player.input_direction.length_squared() > 0.01:
			transition_to("Move")
		else:
			transition_to("Idle")
		return

	## 应用飞行物理
	_apply_flight_physics(delta)
	
	## 应用飞行时的旋转（有惩罚）
	_apply_flight_rotation(delta)

	_check_attack_input()

func _apply_flight_physics(delta: float) -> void:
	var config = player.movement_config
	
	## 获取当前速度
	var current_speed = flight_velocity.length()
	
	## 计算加速度（速度越快，加速度越低）
	var acceleration = config.get_flight_acceleration(current_speed)
	
	## 计算摩擦力（空气阻力）
	var friction = config.get_flight_friction(current_speed)
	
	## 武器重量影响
	if player.current_weapon != null:
		acceleration *= player.current_weapon.get_acceleration_modifier()
	
	## 应用输入加速度
	if player.input_direction.length_squared() > 0.01:
		## 方向键控制加速度方向
		var thrust = player.input_direction.normalized() * acceleration
		flight_velocity += thrust * delta
		
		## 朝向移动方向时有速度加成
		var directional_modifier = config.get_directional_speed_modifier(
			player.current_facing_direction, player.input_direction
		)
		var effective_max_speed = config.max_speed_flight * directional_modifier * config.flight_boost_multiplier
		
		## 限制最大速度
		if flight_velocity.length() > effective_max_speed:
			flight_velocity = flight_velocity.normalized() * effective_max_speed
	else:
		## 无输入时应用空气阻力减速
		flight_velocity = flight_velocity.move_toward(Vector2.ZERO, friction * delta)
	
	## 惯性保持
	flight_velocity *= pow(config.flight_inertia_factor, delta)
	
	## 更新玩家速度
	player.velocity = flight_velocity
	player.move_and_slide()
	
	## 同步碰撞后的速度
	flight_velocity = player.velocity

func _apply_flight_rotation(delta: float) -> void:
	if not player.can_rotate:
		return
	
	var config = player.movement_config
	
	## 获取飞行时的转身速度（有惩罚）
	var is_standing = flight_velocity.length_squared() < 100
	var turn_speed = config.get_flight_turn_speed(
		is_standing, player.current_facing_direction, player.input_direction
	)
	
	## 武器重量影响
	if player.current_weapon != null:
		turn_speed *= player.current_weapon.get_turn_speed_modifier()
	
	## 应用旋转
	var current_angle = player.torso_pivot.rotation
	player.torso_pivot.rotation = rotate_toward(current_angle, player.target_angle, turn_speed * delta)
	player.current_facing_direction = Vector2.from_angle(player.torso_pivot.rotation)

func _check_attack_input() -> void:
	if player.input_buffer == null:
		return

	var attack_input = player.input_buffer.consume_any_attack()
	if attack_input != null:
		if player.can_attack_at_angle():
			transition_to("AttackWindup", {"input": attack_input, "from_fly": true})
		else:
			transition_to("Turn", {"next_state": "AttackWindup", "input": attack_input, "from_fly": true})

## 获取当前飞行速度
func get_flight_speed() -> float:
	return flight_velocity.length()

## 获取飞行方向
func get_flight_direction() -> Vector2:
	if flight_velocity.length_squared() > 0.01:
		return flight_velocity.normalized()
	return Vector2.ZERO
