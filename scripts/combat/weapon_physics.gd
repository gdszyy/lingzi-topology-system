class_name WeaponPhysics extends Node2D
## 武器惯性物理系统
## 使用弹簧-阻尼模型模拟武器的物理惯性
## 武器作为独立物理对象，角色通过施加力来驱动武器

signal weapon_settled
signal weapon_position_changed(position: Vector2, rotation: float)

## 旋转物理参数
@export_group("Rotation Physics")
@export var rotation_stiffness: float = 150.0  ## 旋转弹簧刚度
@export var rotation_damping: float = 20.0     ## 旋转阻尼系数

@export_group("Settling Thresholds")
@export var rotation_settle_threshold: float = 0.05  ## 旋转稳定阈值 (弧度)
@export var angular_velocity_settle_threshold: float = 0.1  ## 角速度稳定阈值

## 运行时状态
var weapon_angular_velocity: float = 0.0

## 目标状态（由角色控制器设置）
var target_local_rotation: float = 0.0

## 默认/休息状态
var rest_rotation: float = 0.0  ## 默认武器旋转

## 引用
var player: Node = null
var current_weapon_mass: float = 1.0

## 状态标记
var is_settled: bool = true
var physics_enabled: bool = true

func _ready() -> void:
	## 节点层级: Player/Visuals/TorsoPivot/WeaponRig/WeaponPhysics
	## 需要向上查找4层才能到达Player
	var parent = get_parent()  # WeaponRig
	if parent:
		parent = parent.get_parent()  # TorsoPivot
	if parent:
		parent = parent.get_parent()  # Visuals
	if parent:
		parent = parent.get_parent()  # Player
	player = parent
	
	## WeaponPhysics节点本身不移动，保持在原点
	## 武器精灵是子节点，已经有自己的位置
	target_local_rotation = rest_rotation

func _physics_process(delta: float) -> void:
	if not physics_enabled:
		return
	
	_update_weapon_mass()
	_apply_spring_damper_physics(delta)
	_apply_constraints()
	_check_settled_state()
	
	weapon_position_changed.emit(Vector2.ZERO, rotation)

func _update_weapon_mass() -> void:
	## 安全地获取武器重量
	if player != null and player is CharacterBody2D:
		var player_controller = player as PlayerController
		if player_controller != null and player_controller.current_weapon != null:
			current_weapon_mass = max(0.1, player_controller.current_weapon.weight)
			return
	current_weapon_mass = 1.0

func _apply_spring_damper_physics(delta: float) -> void:
	## 旋转物理 - 弹簧阻尼模型
	## 注意：WeaponPhysics节点只控制旋转，不控制位置
	## 武器精灵的位置由其自身的position属性控制
	
	var angle_diff = angle_difference(rotation, target_local_rotation)
	
	# 旋转弹簧力矩
	var spring_torque = angle_diff * rotation_stiffness
	
	# 旋转阻尼力矩
	var damping_torque = -weapon_angular_velocity * rotation_damping
	
	# 角加速度 (简化的转动惯量模型)
	var moment_of_inertia = current_weapon_mass * 0.5  # 简化的转动惯量
	var angular_acceleration = (spring_torque + damping_torque) / moment_of_inertia
	
	# 角速度积分
	weapon_angular_velocity += angular_acceleration * delta
	
	# 旋转积分
	rotation += weapon_angular_velocity * delta

func _apply_constraints() -> void:
	## 只限制角速度
	var max_angular_velocity = 30.0  # 最大角速度（弧度/秒）
	if abs(weapon_angular_velocity) > max_angular_velocity:
		weapon_angular_velocity = sign(weapon_angular_velocity) * max_angular_velocity

func _check_settled_state() -> void:
	## 只检查旋转是否稳定
	var rotation_diff = abs(angle_difference(rotation, target_local_rotation))
	var angular_velocity_magnitude = abs(weapon_angular_velocity)
	
	var was_settled = is_settled
	
	is_settled = (
		rotation_diff < rotation_settle_threshold and
		angular_velocity_magnitude < angular_velocity_settle_threshold
	)
	
	if is_settled and not was_settled:
		weapon_settled.emit()

## 设置目标旋转
func set_target(_target_pos: Vector2, target_rot: float) -> void:
	## 只使用旋转参数，位置参数忽略
	target_local_rotation = target_rot
	is_settled = false

## 设置为休息旋转
func set_to_rest() -> void:
	target_local_rotation = rest_rotation
	is_settled = false

## 立即跳转到目标旋转（跳过物理模拟）
func snap_to_target() -> void:
	rotation = target_local_rotation
	weapon_angular_velocity = 0.0
	is_settled = true

## 立即跳转到休息旋转
func snap_to_rest() -> void:
	rotation = rest_rotation
	weapon_angular_velocity = 0.0
	target_local_rotation = rest_rotation
	is_settled = true

## 施加角冲量
func apply_angular_impulse(angular_impulse: float) -> void:
	var moment_of_inertia = current_weapon_mass * 0.5
	weapon_angular_velocity += angular_impulse / moment_of_inertia

## 获取当前是否稳定
func get_is_settled() -> bool:
	return is_settled

## 根据武器数据更新物理参数
func update_physics_from_weapon(weapon: WeaponData) -> void:
	if weapon == null:
		return
	
	# 根据武器重量调整旋转物理参数
	# 重武器：更低的刚度，更高的阻尼（更慢但更稳定）
	# 轻武器：更高的刚度，更低的阻尼（更快响应）
	var weight_factor = weapon.weight
	
	# 调整旋转弹簧参数
	rotation_stiffness = 150.0 / (1.0 + weight_factor * 0.3)
	rotation_damping = 20.0 * (1.0 + weight_factor * 0.2)

## 启用/禁用物理模拟
func set_physics_enabled(enabled: bool) -> void:
	physics_enabled = enabled
	if not enabled:
		weapon_angular_velocity = 0.0

## 获取武器在世界坐标中的位置
func get_weapon_global_position() -> Vector2:
	return global_position

## 获取武器在世界坐标中的旋转
func get_weapon_global_rotation() -> float:
	return global_rotation

## 计算从当前旋转到目标旋转需要的时间估算
func estimate_settle_time() -> float:
	var rotation_diff = abs(angle_difference(rotation, target_local_rotation))
	
	# 基于临界阻尼的近似估算
	var omega_n = sqrt(rotation_stiffness / current_weapon_mass)
	var zeta = rotation_damping / (2.0 * sqrt(rotation_stiffness * current_weapon_mass))
	
	# 对于欠阻尼系统，稳定时间约为 4 / (zeta * omega_n)
	if zeta < 1.0 and omega_n > 0:
		return 4.0 / max(0.01, zeta * omega_n)
	else:
		return rotation_diff / max(0.01, rotation_stiffness / rotation_damping)
