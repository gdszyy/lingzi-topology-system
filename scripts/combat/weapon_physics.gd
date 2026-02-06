class_name WeaponPhysics extends Node2D
## 武器惯性物理系统
## 使用弹簧-阻尼模型模拟武器的物理惯性
## 【重构】修复脆弱的 get_parent() 链式查找
## 通过显式注入替代隐式节点树遍历

signal weapon_settled
signal weapon_position_changed(position: Vector2, rotation: float)

## 旋转物理参数
@export_group("Rotation Physics")
@export var rotation_stiffness: float = 150.0  ## 旋转弹簧刚度
@export var rotation_damping: float = 20.0     ## 旋转阻尼系数
@export var max_angular_velocity: float = 35.0  ## 最大角速度（弧度/秒）

## 武器挥舞增强参数
@export_group("Swing Enhancement")
@export var swing_overshoot_factor: float = 1.2  ## 挥舞超调因子
@export var swing_momentum_multiplier: float = 1.5  ## 挥舞动量倍数
@export var active_phase_acceleration: float = 2.0  ## 激活阶段的加速度倍数

@export_group("Settling Thresholds")
@export var rotation_settle_threshold: float = 0.05
@export var angular_velocity_settle_threshold: float = 0.1

## 运行时状态
var weapon_angular_velocity: float = 0.0
var weapon_angular_acceleration: float = 0.0

## 目标状态
var target_local_rotation: float = 0.0
var rest_rotation: float = 0.0

## 【重构】通过显式注入获取依赖，不再使用 get_parent() 链
var _combat_animator: CombatAnimator = null
var _weapon_mass_provider: Callable = Callable()  ## 返回 float 的回调

## 状态标记
var is_settled: bool = true
var physics_enabled: bool = true
var current_weapon_mass: float = 1.0

## 攻击状态追踪
var is_attacking: bool = false
var attack_phase: int = 0
var last_target_rotation: float = 0.0
var rotation_change_velocity: float = 0.0

## 【新增】物理参数预计算缓存
var _effective_stiffness: float = 150.0
var _effective_damping: float = 20.0
var _effective_max_velocity: float = 35.0

func _ready() -> void:
	target_local_rotation = rest_rotation
	last_target_rotation = rest_rotation

## 【重构】显式初始化，替代脆弱的 get_parent() 链
func initialize(combat_animator: CombatAnimator, weapon_mass_provider: Callable = Callable()) -> void:
	_combat_animator = combat_animator
	_weapon_mass_provider = weapon_mass_provider

func _physics_process(delta: float) -> void:
	if not physics_enabled:
		return

	_update_weapon_mass()
	_update_attack_state()
	_update_effective_params()  # 【优化】预计算物理参数
	_apply_spring_damper_physics(delta)
	_apply_constraints()
	_check_settled_state()

	weapon_position_changed.emit(Vector2.ZERO, rotation)

func _update_weapon_mass() -> void:
	## 【重构】使用回调获取武器质量，不再直接访问 PlayerController
	if _weapon_mass_provider.is_valid():
		current_weapon_mass = maxf(0.1, _weapon_mass_provider.call())
	else:
		current_weapon_mass = 1.0

func _update_attack_state() -> void:
	## 【重构】直接使用注入的 CombatAnimator 引用
	if _combat_animator == null:
		is_attacking = false
		return
	is_attacking = _combat_animator.is_playing()
	attack_phase = _combat_animator.get_animation_phase()

## 【优化】预计算有效物理参数，避免在 _apply_spring_damper_physics 中重复计算
func _update_effective_params() -> void:
	_effective_stiffness = rotation_stiffness
	_effective_damping = rotation_damping
	_effective_max_velocity = max_angular_velocity

	if is_attacking:
		match attack_phase:
			0:  ## windup
				_effective_stiffness = rotation_stiffness * 1.5
				_effective_damping = rotation_damping * 0.8
				_effective_max_velocity = max_angular_velocity * 1.2
			1:  ## active
				_effective_stiffness = rotation_stiffness * swing_momentum_multiplier
				_effective_damping = rotation_damping * 0.6
				_effective_max_velocity = max_angular_velocity * 1.5
			2:  ## recovery
				_effective_stiffness = rotation_stiffness * 0.8
				_effective_damping = rotation_damping * 1.2
				_effective_max_velocity = max_angular_velocity * 0.9

func _apply_spring_damper_physics(delta: float) -> void:
	## 计算目标旋转的变化速度
	var rotation_delta = angle_difference(target_local_rotation, last_target_rotation)
	rotation_change_velocity = rotation_delta / maxf(delta, 0.001)
	last_target_rotation = target_local_rotation

	var angle_diff = angle_difference(rotation, target_local_rotation)

	# 旋转弹簧力矩
	var spring_torque = angle_diff * _effective_stiffness

	# 旋转阻尼力矩
	var damping_torque = -weapon_angular_velocity * _effective_damping

	# 在激活阶段添加额外的加速度
	var extra_acceleration = 0.0
	if is_attacking and attack_phase == 1:
		extra_acceleration = rotation_change_velocity * active_phase_acceleration

	# 角加速度 (简化的转动惯量模型)
	var moment_of_inertia = current_weapon_mass * 0.5
	weapon_angular_acceleration = (spring_torque + damping_torque + extra_acceleration) / moment_of_inertia

	# 角速度积分
	weapon_angular_velocity += weapon_angular_acceleration * delta

	# 旋转积分
	rotation += weapon_angular_velocity * delta

func _apply_constraints() -> void:
	if absf(weapon_angular_velocity) > _effective_max_velocity:
		weapon_angular_velocity = signf(weapon_angular_velocity) * _effective_max_velocity

func _check_settled_state() -> void:
	var rotation_diff = absf(angle_difference(rotation, target_local_rotation))
	var angular_velocity_magnitude = absf(weapon_angular_velocity)

	var was_settled = is_settled

	is_settled = (
		rotation_diff < rotation_settle_threshold and
		angular_velocity_magnitude < angular_velocity_settle_threshold
	)

	if is_settled and not was_settled:
		weapon_settled.emit()

## 设置目标旋转
func set_target(_target_pos: Vector2, target_rot: float) -> void:
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

	var weight_factor = weapon.weight

	# 调整旋转弹簧参数
	rotation_stiffness = 150.0 / (1.0 + weight_factor * 0.3)
	rotation_damping = 20.0 * (1.0 + weight_factor * 0.2)

	# 【优化】使用查找表替代 match 链
	var weapon_params = _get_weapon_type_params(weapon.weapon_type)
	swing_momentum_multiplier = weapon_params.x
	swing_overshoot_factor = weapon_params.y
	max_angular_velocity = weapon_params.z

## 【优化】武器类型参数查找表，替代 match 链
static var _weapon_type_params_table: Dictionary = {
	WeaponData.WeaponType.GREATSWORD: Vector3(1.3, 1.1, 30.0),
	WeaponData.WeaponType.SWORD: Vector3(1.5, 1.2, 35.0),
	WeaponData.WeaponType.DAGGER: Vector3(1.8, 1.3, 40.0),
	WeaponData.WeaponType.SPEAR: Vector3(1.2, 1.0, 28.0),
	WeaponData.WeaponType.STAFF: Vector3(1.4, 1.25, 32.0),
}
static var _default_weapon_params: Vector3 = Vector3(1.5, 1.2, 35.0)

func _get_weapon_type_params(weapon_type: WeaponData.WeaponType) -> Vector3:
	return _weapon_type_params_table.get(weapon_type, _default_weapon_params)

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
	var rotation_diff = absf(angle_difference(rotation, target_local_rotation))
	var omega_n = sqrt(rotation_stiffness / current_weapon_mass)
	var zeta = rotation_damping / (2.0 * sqrt(rotation_stiffness * current_weapon_mass))

	if zeta < 1.0 and omega_n > 0:
		return 4.0 / maxf(0.01, zeta * omega_n)
	else:
		return rotation_diff / maxf(0.01, rotation_stiffness / rotation_damping)

## 获取当前角速度
func get_angular_velocity() -> float:
	return weapon_angular_velocity

## 获取当前角加速度
func get_angular_acceleration() -> float:
	return weapon_angular_acceleration

## 获取目标旋转
func get_target_rotation() -> float:
	return target_local_rotation
