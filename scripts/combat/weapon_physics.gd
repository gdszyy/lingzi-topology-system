class_name WeaponPhysics extends Node2D
## 武器惯性物理系统
## 使用弹簧-阻尼模型模拟武器的物理惯性
## 【优化】增强武器挥舞效果，使武器更有"挥出去"的感觉

signal weapon_settled
signal weapon_position_changed(position: Vector2, rotation: float)

## 旋转物理参数
@export_group("Rotation Physics")
@export var rotation_stiffness: float = 150.0  ## 旋转弹簧刚度
@export var rotation_damping: float = 20.0     ## 旋转阻尼系数
@export var max_angular_velocity: float = 35.0  ## 最大角速度（弧度/秒）

## 【新增】武器挥舞增强参数
@export_group("Swing Enhancement")
@export var swing_overshoot_factor: float = 1.2  ## 挥舞超调因子（>1时产生超调效果）
@export var swing_momentum_multiplier: float = 1.5  ## 挥舞动量倍数
@export var active_phase_acceleration: float = 2.0  ## 激活阶段的加速度倍数

@export_group("Settling Thresholds")
@export var rotation_settle_threshold: float = 0.05  ## 旋转稳定阈值 (弧度)
@export var angular_velocity_settle_threshold: float = 0.1  ## 角速度稳定阈值

## 运行时状态
var weapon_angular_velocity: float = 0.0
var weapon_angular_acceleration: float = 0.0

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

## 【新增】攻击状态追踪
var is_attacking: bool = false
var attack_phase: int = 0  ## 0=windup, 1=active, 2=recovery
var last_target_rotation: float = 0.0
var rotation_change_velocity: float = 0.0  ## 目标旋转的变化速度

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
	last_target_rotation = rest_rotation

func _physics_process(delta: float) -> void:
	if not physics_enabled:
		return
	
	_update_weapon_mass()
	_update_attack_state()
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

## 【新增】更新攻击状态
func _update_attack_state() -> void:
	if player == null or not (player is PlayerController):
		is_attacking = false
		return
	
	var player_controller = player as PlayerController
	var visuals = player_controller.visuals as PlayerVisuals
	
	if visuals == null:
		is_attacking = false
		return
	
	var combat_animator = visuals.get_combat_animator()
	if combat_animator == null:
		is_attacking = false
		return
	
	is_attacking = combat_animator.is_playing()
	attack_phase = combat_animator.get_animation_phase()

func _apply_spring_damper_physics(delta: float) -> void:
	## 计算目标旋转的变化速度
	var rotation_delta = angle_difference(target_local_rotation, last_target_rotation)
	rotation_change_velocity = rotation_delta / max(delta, 0.001)
	last_target_rotation = target_local_rotation
	
	var angle_diff = angle_difference(rotation, target_local_rotation)
	
	## 【优化】根据攻击状态调整物理参数
	var effective_stiffness = rotation_stiffness
	var effective_damping = rotation_damping
	var effective_max_velocity = max_angular_velocity
	
	if is_attacking:
		match attack_phase:
			0:  ## windup - 蓄力阶段
				## 快速响应目标旋转
				effective_stiffness = rotation_stiffness * 1.5
				effective_damping = rotation_damping * 0.8
				effective_max_velocity = max_angular_velocity * 1.2
			1:  ## active - 攻击阶段
				## 增加加速度，产生"挥出去"的感觉
				effective_stiffness = rotation_stiffness * swing_momentum_multiplier
				effective_damping = rotation_damping * 0.6
				effective_max_velocity = max_angular_velocity * 1.5
			2:  ## recovery - 恢复阶段
				## 缓慢回正
				effective_stiffness = rotation_stiffness * 0.8
				effective_damping = rotation_damping * 1.2
				effective_max_velocity = max_angular_velocity * 0.9
	
	# 旋转弹簧力矩
	var spring_torque = angle_diff * effective_stiffness
	
	# 旋转阻尼力矩
	var damping_torque = -weapon_angular_velocity * effective_damping
	
	# 【优化】在激活阶段添加额外的加速度
	var extra_acceleration = 0.0
	if is_attacking and attack_phase == 1:
		## 根据目标旋转的变化速度添加额外加速度
		extra_acceleration = rotation_change_velocity * active_phase_acceleration
	
	# 角加速度 (简化的转动惯量模型)
	var moment_of_inertia = current_weapon_mass * 0.5
	weapon_angular_acceleration = (spring_torque + damping_torque + extra_acceleration) / moment_of_inertia
	
	# 角速度积分
	weapon_angular_velocity += weapon_angular_acceleration * delta
	
	# 旋转积分
	rotation += weapon_angular_velocity * delta

func _apply_constraints() -> void:
	## 限制角速度
	if abs(weapon_angular_velocity) > max_angular_velocity:
		weapon_angular_velocity = sign(weapon_angular_velocity) * max_angular_velocity

func _check_settled_state() -> void:
	## 检查旋转是否稳定
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
	
	# 【优化】根据武器类型调整挥舞参数
	match weapon.weapon_type:
		WeaponData.WeaponType.GREATSWORD:
			## 大剑：沉重但挥舞范围大
			swing_momentum_multiplier = 1.3
			swing_overshoot_factor = 1.1
			max_angular_velocity = 30.0
		WeaponData.WeaponType.SWORD:
			## 剑：平衡的挥舞
			swing_momentum_multiplier = 1.5
			swing_overshoot_factor = 1.2
			max_angular_velocity = 35.0
		WeaponData.WeaponType.DAGGER:
			## 匕首：快速灵活
			swing_momentum_multiplier = 1.8
			swing_overshoot_factor = 1.3
			max_angular_velocity = 40.0
		WeaponData.WeaponType.SPEAR:
			## 矛：长杆武器，挥舞需要力量
			swing_momentum_multiplier = 1.2
			swing_overshoot_factor = 1.0
			max_angular_velocity = 28.0
		WeaponData.WeaponType.STAFF:
			## 法杖：灵活但有惯性
			swing_momentum_multiplier = 1.4
			swing_overshoot_factor = 1.25
			max_angular_velocity = 32.0
		_:
			swing_momentum_multiplier = 1.5
			swing_overshoot_factor = 1.2
			max_angular_velocity = 35.0

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

## 【新增】获取当前角速度
func get_angular_velocity() -> float:
	return weapon_angular_velocity

## 【新增】获取当前角加速度
func get_angular_acceleration() -> float:
	return weapon_angular_acceleration

## 【新增】获取目标旋转
func get_target_rotation() -> float:
	return target_local_rotation
