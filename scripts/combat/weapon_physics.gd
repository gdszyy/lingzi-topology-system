class_name WeaponPhysics extends Node2D
## 武器惯性物理系统
## 使用弹簧-阻尼模型模拟武器的物理惯性
## 武器作为独立物理对象，角色通过施加力来驱动武器

signal weapon_settled
signal weapon_position_changed(position: Vector2, rotation: float)

## 物理参数
@export_group("Spring-Damper Parameters")
@export var position_stiffness: float = 200.0  ## 位置弹簧刚度 (K)
@export var position_damping: float = 25.0     ## 位置阻尼系数 (C)
@export var rotation_stiffness: float = 150.0  ## 旋转弹簧刚度
@export var rotation_damping: float = 20.0     ## 旋转阻尼系数

@export_group("Settling Thresholds")
@export var position_settle_threshold: float = 2.0   ## 位置稳定阈值
@export var velocity_settle_threshold: float = 5.0   ## 速度稳定阈值
@export var rotation_settle_threshold: float = 0.05  ## 旋转稳定阈值 (弧度)
@export var angular_velocity_settle_threshold: float = 0.1  ## 角速度稳定阈值

@export_group("Constraints")
@export var max_displacement: float = 100.0  ## 最大位移限制
@export var max_velocity: float = 1000.0     ## 最大速度限制

## 运行时状态
var weapon_velocity: Vector2 = Vector2.ZERO
var weapon_angular_velocity: float = 0.0

## 目标状态（由角色控制器设置）
var target_local_position: Vector2 = Vector2.ZERO
var target_local_rotation: float = 0.0

## 默认/休息状态
var rest_position: Vector2 = Vector2(20, 0)  ## 默认武器位置
var rest_rotation: float = 0.0               ## 默认武器旋转

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
	
	# 初始化位置
	position = rest_position
	rotation = rest_rotation
	target_local_position = rest_position
	target_local_rotation = rest_rotation

func _physics_process(delta: float) -> void:
	if not physics_enabled:
		return
	
	_update_weapon_mass()
	_apply_spring_damper_physics(delta)
	_apply_constraints()
	_check_settled_state()
	
	weapon_position_changed.emit(position, rotation)

func _update_weapon_mass() -> void:
	## 安全地获取武器重量
	if player != null and player is CharacterBody2D:
		var player_controller = player as PlayerController
		if player_controller != null and player_controller.current_weapon != null:
			current_weapon_mass = max(0.1, player_controller.current_weapon.weight)
			return
	current_weapon_mass = 1.0

func _apply_spring_damper_physics(delta: float) -> void:
	## 位置物理 - 弹簧阻尼模型
	var displacement = target_local_position - position
	
	# 弹簧力: F = K * x
	var spring_force = displacement * position_stiffness
	
	# 阻尼力: F = -C * v
	var damping_force = -weapon_velocity * position_damping
	
	# 总力和加速度: a = F / m
	var total_force = spring_force + damping_force
	var acceleration = total_force / current_weapon_mass
	
	# 速度积分
	weapon_velocity += acceleration * delta
	
	# 位置积分
	position += weapon_velocity * delta
	
	## 旋转物理 - 类似的弹簧阻尼模型
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
	## 限制最大位移
	var displacement_from_rest = position - rest_position
	if displacement_from_rest.length() > max_displacement:
		position = rest_position + displacement_from_rest.normalized() * max_displacement
	
	## 限制最大速度
	if weapon_velocity.length() > max_velocity:
		weapon_velocity = weapon_velocity.normalized() * max_velocity

func _check_settled_state() -> void:
	var position_diff = (target_local_position - position).length()
	var velocity_magnitude = weapon_velocity.length()
	var rotation_diff = abs(angle_difference(rotation, target_local_rotation))
	var angular_velocity_magnitude = abs(weapon_angular_velocity)
	
	var was_settled = is_settled
	
	is_settled = (
		position_diff < position_settle_threshold and
		velocity_magnitude < velocity_settle_threshold and
		rotation_diff < rotation_settle_threshold and
		angular_velocity_magnitude < angular_velocity_settle_threshold
	)
	
	if is_settled and not was_settled:
		weapon_settled.emit()

## 设置目标位置和旋转
func set_target(target_pos: Vector2, target_rot: float) -> void:
	target_local_position = target_pos
	target_local_rotation = target_rot
	is_settled = false

## 设置为休息位置
func set_to_rest() -> void:
	set_target(rest_position, rest_rotation)

## 立即移动到目标位置（跳过物理模拟）
func snap_to_target() -> void:
	position = target_local_position
	rotation = target_local_rotation
	weapon_velocity = Vector2.ZERO
	weapon_angular_velocity = 0.0
	is_settled = true

## 立即移动到休息位置
func snap_to_rest() -> void:
	position = rest_position
	rotation = rest_rotation
	weapon_velocity = Vector2.ZERO
	weapon_angular_velocity = 0.0
	target_local_position = rest_position
	target_local_rotation = rest_rotation
	is_settled = true

## 施加冲量（用于攻击时的突进效果）
func apply_impulse(impulse: Vector2) -> void:
	weapon_velocity += impulse / current_weapon_mass

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
	
	# 根据武器重量调整物理参数
	# 重武器：更低的刚度，更高的阻尼（更慢但更稳定）
	# 轻武器：更高的刚度，更低的阻尼（更快响应）
	var weight_factor = weapon.weight
	
	# 惯性因子影响响应速度
	var inertia = weapon.inertia_factor
	
	# 调整弹簧参数
	position_stiffness = 200.0 / (1.0 + weight_factor * 0.3)
	position_damping = 25.0 * (1.0 + weight_factor * 0.2)
	rotation_stiffness = 150.0 / (1.0 + weight_factor * 0.3)
	rotation_damping = 20.0 * (1.0 + weight_factor * 0.2)
	
	# 更新休息位置（可以根据武器类型调整）
	rest_position = Vector2(20 + weapon.attack_range * 0.3, 0)

## 启用/禁用物理模拟
func set_physics_enabled(enabled: bool) -> void:
	physics_enabled = enabled
	if not enabled:
		weapon_velocity = Vector2.ZERO
		weapon_angular_velocity = 0.0

## 获取武器在世界坐标中的位置
func get_weapon_global_position() -> Vector2:
	return global_position

## 获取武器在世界坐标中的旋转
func get_weapon_global_rotation() -> float:
	return global_rotation

## 计算从当前位置到目标位置需要的时间估算
func estimate_settle_time() -> float:
	var position_diff = (target_local_position - position).length()
	var rotation_diff = abs(angle_difference(rotation, target_local_rotation))
	
	# 基于临界阻尼的近似估算
	var omega_n = sqrt(position_stiffness / current_weapon_mass)
	var zeta = position_damping / (2.0 * sqrt(position_stiffness * current_weapon_mass))
	
	# 对于欠阻尼系统，稳定时间约为 4 / (zeta * omega_n)
	if zeta < 1.0:
		return 4.0 / (zeta * omega_n)
	else:
		return position_diff / (position_stiffness / position_damping)
