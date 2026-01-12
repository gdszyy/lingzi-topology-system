# movement_config.gd
# 角色移动配置资源 - 定义移动相关的所有参数
class_name MovementConfig extends Resource

## 地面移动参数
@export_group("Ground Movement")
@export var max_speed_ground: float = 300.0  # 地面最大速度
@export var acceleration_ground: float = 2000.0  # 地面加速度
@export var friction_ground: float = 3000.0  # 地面摩擦力（减速度）

## 飞行移动参数
@export_group("Flight Movement")
@export var max_speed_flight: float = 500.0  # 飞行最大速度
@export var acceleration_flight: float = 800.0  # 飞行加速度（较低，模拟推进器启动延迟）
@export var friction_flight: float = 200.0  # 飞行摩擦力（极低，模拟惯性滑行）

## 方向速度修正
@export_group("Directional Speed Modifiers")
@export var forward_speed_multiplier: float = 1.0  # 前进速度倍率
@export var strafe_speed_multiplier: float = 0.75  # 侧移速度倍率
@export var backward_speed_multiplier: float = 0.5  # 后退速度倍率

## 旋转参数
@export_group("Rotation")
@export var base_turn_speed: float = 10.0  # 基础角速度（弧度/秒）
@export var standing_turn_bonus: float = 1.5  # 站定时的角速度加成
@export var perpendicular_turn_bonus: float = 1.2  # 垂直移动时的角速度加成

## 回正参数
@export_group("Turn Gating")
@export var attack_angle_threshold: float = 30.0  # 攻击允许的最大角度偏差（度）
@export var spell_angle_threshold: float = 15.0   # 施法允许的最大角度偏差（度）

## 获取基于移动方向的速度修正
## face_direction: 角色朝向单位向量
## move_direction: 移动方向单位向量
func get_directional_speed_modifier(face_direction: Vector2, move_direction: Vector2) -> float:
	if move_direction.length_squared() < 0.01:
		return 1.0
	
	# 计算点积
	var dot = face_direction.dot(move_direction)
	
	# 将点积 [-1, 1] 映射到速度修正
	# dot = 1 -> forward (1.0)
	# dot = 0 -> strafe (0.75)
	# dot = -1 -> backward (0.5)
	if dot >= 0:
		# 前进或侧移
		return lerpf(strafe_speed_multiplier, forward_speed_multiplier, dot)
	else:
		# 后退
		return lerpf(strafe_speed_multiplier, backward_speed_multiplier, -dot)

## 获取基于状态的角速度
## is_standing: 是否站定
## face_direction: 角色朝向单位向量
## move_direction: 移动方向单位向量
func get_turn_speed(is_standing: bool, face_direction: Vector2, move_direction: Vector2) -> float:
	var turn_speed = base_turn_speed
	
	# 站定加成
	if is_standing:
		turn_speed *= standing_turn_bonus
	
	# 垂直移动加成
	if move_direction.length_squared() > 0.01:
		var dot = abs(face_direction.dot(move_direction))
		# 当移动方向与朝向垂直时（dot接近0），给予加成
		var perpendicular_factor = 1.0 - dot
		turn_speed *= lerpf(1.0, perpendicular_turn_bonus, perpendicular_factor)
	
	return turn_speed

## 检查角度是否在攻击允许范围内
func is_angle_valid_for_attack(current_angle: float, target_angle: float) -> bool:
	var angle_diff = abs(angle_difference(current_angle, target_angle))
	return rad_to_deg(angle_diff) <= attack_angle_threshold

## 检查角度是否在施法允许范围内
func is_angle_valid_for_spell(current_angle: float, target_angle: float) -> bool:
	var angle_diff = abs(angle_difference(current_angle, target_angle))
	return rad_to_deg(angle_diff) <= spell_angle_threshold

## 创建默认配置
static func create_default() -> MovementConfig:
	var config = MovementConfig.new()
	return config
