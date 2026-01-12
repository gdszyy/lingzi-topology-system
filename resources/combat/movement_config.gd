class_name MovementConfig extends Resource
## 移动配置资源
## 定义角色的移动、飞行和旋转物理参数

@export_group("Ground Movement")
@export var max_speed_ground: float = 300.0
@export var acceleration_ground: float = 2000.0
@export var friction_ground: float = 3000.0

@export_group("Flight Movement")
## 飞行模式：方向键控制加速度而非直接速度
@export var max_speed_flight: float = 500.0
@export var acceleration_flight: float = 800.0  ## 飞行时的推进力（较低，体现惯性）
@export var friction_flight: float = 200.0      ## 飞行时的空气阻力（很低，体现滑行）
@export var flight_boost_multiplier: float = 1.5  ## 飞行时的速度提升倍率

@export_group("Directional Speed Modifiers")
## 朝向移动速度修正
@export var forward_speed_multiplier: float = 1.0   ## 前进速度倍率
@export var strafe_speed_multiplier: float = 0.75   ## 侧移速度倍率
@export var backward_speed_multiplier: float = 0.5  ## 后退速度倍率

@export_group("Rotation")
## 角速度控制
@export var base_turn_speed: float = 10.0           ## 基础转身速度（弧度/秒）
@export var standing_turn_bonus: float = 1.5        ## 站定时的转身加成
@export var perpendicular_turn_bonus: float = 1.2   ## 垂直移动时的转身加成
@export var moving_turn_penalty: float = 0.8        ## 移动时的转身惩罚

@export_group("Attack Movement")
## 攻击时移动速度默认修正（0.0-1.0，1.0表示无惩罚）
@export_range(0.0, 1.0) var default_attack_move_speed_modifier: float = 0.6
## 攻击时加速度默认修正（0.0-1.0，1.0表示无惩罚）
@export_range(0.0, 1.0) var default_attack_acceleration_modifier: float = 0.7

@export_group("Turn Gating")
## 攻击/施法角度阈值
@export var attack_angle_threshold: float = 30.0    ## 攻击允许的最大角度偏差（度）
@export var spell_angle_threshold: float = 15.0     ## 施法允许的最大角度偏差（度）

@export_group("Flight Physics")
## 飞行物理细节
@export var flight_inertia_factor: float = 0.9      ## 飞行惯性保持因子
@export var flight_turn_penalty: float = 0.6        ## 飞行时的转身惩罚
@export var flight_acceleration_curve: Curve        ## 飞行加速曲线（可选）

## 获取方向速度修正
func get_directional_speed_modifier(face_direction: Vector2, move_direction: Vector2) -> float:
	if move_direction.length_squared() < 0.01:
		return 1.0

	var dot = face_direction.dot(move_direction)

	## 使用平滑插值计算速度修正
	if dot >= 0:
		## 前进或侧移
		return lerpf(strafe_speed_multiplier, forward_speed_multiplier, dot)
	else:
		## 后退或侧移
		return lerpf(strafe_speed_multiplier, backward_speed_multiplier, -dot)

## 获取转身速度
func get_turn_speed(is_standing: bool, face_direction: Vector2, move_direction: Vector2) -> float:
	var turn_speed = base_turn_speed

	## 站定状态加成
	if is_standing:
		turn_speed *= standing_turn_bonus
	else:
		turn_speed *= moving_turn_penalty

	## 垂直移动加成
	if move_direction.length_squared() > 0.01:
		var dot = abs(face_direction.dot(move_direction))
		var perpendicular_factor = 1.0 - dot  ## 越垂直，factor越大
		turn_speed *= lerpf(1.0, perpendicular_turn_bonus, perpendicular_factor)

	return turn_speed

## 获取飞行时的转身速度
func get_flight_turn_speed(is_standing: bool, face_direction: Vector2, move_direction: Vector2) -> float:
	var base_speed = get_turn_speed(is_standing, face_direction, move_direction)
	return base_speed * flight_turn_penalty

## 检查角度是否适合攻击
func is_angle_valid_for_attack(current_angle: float, target_angle: float) -> bool:
	var angle_diff = abs(angle_difference(current_angle, target_angle))
	return rad_to_deg(angle_diff) <= attack_angle_threshold

## 检查角度是否适合施法
func is_angle_valid_for_spell(current_angle: float, target_angle: float) -> bool:
	var angle_diff = abs(angle_difference(current_angle, target_angle))
	return rad_to_deg(angle_diff) <= spell_angle_threshold

## 计算飞行加速度
func get_flight_acceleration(current_speed: float) -> float:
	## 如果有加速曲线，使用曲线采样
	if flight_acceleration_curve != null:
		var speed_ratio = clamp(current_speed / max_speed_flight, 0.0, 1.0)
		return acceleration_flight * flight_acceleration_curve.sample(speed_ratio)
	
	## 默认：速度越快，加速度越低（模拟空气阻力）
	var speed_ratio = clamp(current_speed / max_speed_flight, 0.0, 1.0)
	return acceleration_flight * (1.0 - speed_ratio * 0.5)

## 计算飞行摩擦力
func get_flight_friction(current_speed: float) -> float:
	## 速度越快，摩擦力越大（模拟空气阻力）
	var speed_ratio = clamp(current_speed / max_speed_flight, 0.0, 1.0)
	return friction_flight * (1.0 + speed_ratio * 0.5)

## 创建默认配置
static func create_default() -> MovementConfig:
	var config = MovementConfig.new()
	return config

## 创建轻装配置（更快的移动和转身）
static func create_light() -> MovementConfig:
	var config = MovementConfig.new()
	config.max_speed_ground = 350.0
	config.acceleration_ground = 2500.0
	config.friction_ground = 3500.0
	config.base_turn_speed = 12.0
	config.standing_turn_bonus = 1.8
	return config

## 创建重装配置（更慢但更稳定）
static func create_heavy() -> MovementConfig:
	var config = MovementConfig.new()
	config.max_speed_ground = 220.0
	config.acceleration_ground = 1500.0
	config.friction_ground = 2500.0
	config.base_turn_speed = 7.0
	config.standing_turn_bonus = 1.3
	config.forward_speed_multiplier = 0.9
	config.backward_speed_multiplier = 0.4
	return config

## 创建飞行专精配置
static func create_flight_focused() -> MovementConfig:
	var config = MovementConfig.new()
	config.max_speed_flight = 600.0
	config.acceleration_flight = 1000.0
	config.friction_flight = 150.0
	config.flight_boost_multiplier = 2.0
	config.flight_turn_penalty = 0.7
	return config
