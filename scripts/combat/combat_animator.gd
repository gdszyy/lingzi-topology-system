class_name CombatAnimator extends Node
## 战斗动画控制器
## 根据攻击动作驱动手部轨迹
## 管理武器旋转和手臂 IK
## 【重构】提取通用攻击动画框架，消除 6 种攻击类型的大量重复代码
## 使用数据驱动的 AttackAnimationProfile 替代硬编码的 match 分支

signal animation_started(attack: AttackData)
signal animation_finished(attack: AttackData)
signal hit_frame_reached(attack: AttackData)

## ==================== 攻击动画配置 ====================
## 每种攻击类型的动画参数配置，替代原来的 6 个独立函数
class AttackAnimationProfile:
	## 各阶段的挥舞半径 [windup_start, windup_end, active_base, active_momentum, recovery_start, recovery_end]
	var swing_radius: PackedFloat64Array = PackedFloat64Array([18.0, 24.0, 26.0, 6.0, 26.0, 20.0])
	## 各阶段的武器伸出距离 [windup_start, windup_end, active_base, active_momentum, recovery_start, recovery_end]
	var weapon_extension: PackedFloat64Array = PackedFloat64Array([-3.0, 5.0, 15.0, 10.0, 15.0, 5.0])
	## 身体跟随旋转系数 [windup, active, recovery]
	var body_rotation_factor: PackedFloat64Array = PackedFloat64Array([0.2, 0.4, 0.4])
	## 左手平衡系数（单手武器时）
	var left_hand_balance_factor: float = 0.5
	## 是否使用角度驱动（true=旋转攻击，false=直线攻击如刺击）
	var angle_driven: bool = true
	## 刺击专用参数
	var thrust_distance: PackedFloat64Array = PackedFloat64Array()  # 空=非刺击
	## 重击专用参数
	var overhead_angle: PackedFloat64Array = PackedFloat64Array()  # 空=非重击

## 预构建的攻击动画配置表
var _profiles: Dictionary = {}

## 引用
var left_arm: ArmRig = null
var right_arm: ArmRig = null
var weapon_physics: WeaponPhysics = null

## 当前动画状态
var is_animating: bool = false
var current_attack: AttackData = null
var animation_progress: float = 0.0
var animation_phase: int = 0  ## 0=windup, 1=active, 2=recovery

## 武器配置
var current_weapon: WeaponData = null
var main_hand_grip_offset: Vector2 = Vector2.ZERO
var off_hand_grip_offset: Vector2 = Vector2.ZERO

## 待机位置（相对于肩膀）
var idle_left_hand_offset: Vector2 = Vector2(-5, 18)
var idle_right_hand_offset: Vector2 = Vector2(5, 18)

## 肩膀位置
var left_shoulder: Vector2 = Vector2(-12, 0)
var right_shoulder: Vector2 = Vector2(12, 0)

## 武器基础旋转偏移
const WEAPON_BASE_ROTATION: float = -PI / 2

## 攻击动画参数
var swing_momentum: float = 0.0

## 引用 BodyAnimationController
var body_animation_controller: BodyAnimationController = null

## 【新增】缓存的武器长度因子，避免每帧重复计算
var _cached_weapon_length_factor: float = 1.0

func _ready() -> void:
	_build_animation_profiles()

func _build_animation_profiles() -> void:
	## 挥砍 (SLASH)
	var slash = AttackAnimationProfile.new()
	slash.swing_radius = PackedFloat64Array([18.0, 24.0, 26.0, 6.0, 26.0, 20.0])
	slash.weapon_extension = PackedFloat64Array([-3.0, 5.0, 15.0, 10.0, 15.0, 5.0])
	slash.body_rotation_factor = PackedFloat64Array([0.2, 0.4, 0.4])
	slash.left_hand_balance_factor = 0.5
	_profiles[AttackData.AttackType.SLASH] = slash

	## 反手挥砍 (REVERSE_SLASH) — 与挥砍类似但参数略有不同
	var reverse = AttackAnimationProfile.new()
	reverse.swing_radius = PackedFloat64Array([18.0, 26.0, 26.0, 6.0, 26.0, 20.0])
	reverse.weapon_extension = PackedFloat64Array([-3.0, 5.0, 12.0, 10.0, 12.0, 5.0])
	reverse.body_rotation_factor = PackedFloat64Array([0.15, 0.35, 0.35])
	reverse.left_hand_balance_factor = 0.5
	_profiles[AttackData.AttackType.REVERSE_SLASH] = reverse

	## 刺击 (THRUST) — 直线运动
	var thrust = AttackAnimationProfile.new()
	thrust.angle_driven = false
	thrust.thrust_distance = PackedFloat64Array([20.0, 8.0, 8.0, 40.0, 12.0, 40.0, 15.0])
	# [windup_start, windup_end, active_start, active_end+momentum, active_momentum, recovery_start, recovery_end]
	thrust.weapon_extension = PackedFloat64Array([0.0, -8.0, -8.0, 12.0, 6.0, 12.0, 0.0])
	thrust.body_rotation_factor = PackedFloat64Array([0.1, 0.2, 0.2])
	thrust.left_hand_balance_factor = 0.3
	_profiles[AttackData.AttackType.THRUST] = thrust

	## 重击 (SMASH) — 从上到下
	var smash = AttackAnimationProfile.new()
	smash.swing_radius = PackedFloat64Array([20.0, 15.0, 15.0, 38.0, 10.0, 38.0, 22.0])
	smash.weapon_extension = PackedFloat64Array([5.0, -5.0, -5.0, 25.0, 12.0, 25.0, 6.0])
	smash.body_rotation_factor = PackedFloat64Array([0.2, 0.5, 0.5])
	smash.overhead_angle = PackedFloat64Array([0.0, -110.0, -110.0, 45.0, 45.0, 0.0])
	# [windup_start, windup_end, active_start, active_end, recovery_start, recovery_end]
	smash.left_hand_balance_factor = 0.6
	_profiles[AttackData.AttackType.SMASH] = smash

	## 横扫 (SWEEP) — 更大范围
	var sweep = AttackAnimationProfile.new()
	sweep.swing_radius = PackedFloat64Array([22.0, 32.0, 35.0, 10.0, 35.0, 22.0])
	sweep.weapon_extension = PackedFloat64Array([0.0, 15.0, 22.0, 15.0, 22.0, 8.0])
	sweep.body_rotation_factor = PackedFloat64Array([0.4, 0.6, 0.6])
	sweep.left_hand_balance_factor = 0.7
	_profiles[AttackData.AttackType.SWEEP] = sweep

	## 旋转攻击 (SPIN)
	var spin = AttackAnimationProfile.new()
	spin.swing_radius = PackedFloat64Array([20.0, 28.0, 28.0, 8.0, 28.0, 20.0])
	spin.weapon_extension = PackedFloat64Array([0.0, 10.0, 15.0, 10.0, 15.0, 6.0])
	spin.body_rotation_factor = PackedFloat64Array([0.3, 0.5, 0.5])
	spin.left_hand_balance_factor = 0.6
	_profiles[AttackData.AttackType.SPIN] = spin

func initialize(left: ArmRig, right: ArmRig, physics: WeaponPhysics) -> void:
	left_arm = left
	right_arm = right
	weapon_physics = physics

	if left_arm:
		left_shoulder = left_arm.get_shoulder_position()
	if right_arm:
		right_shoulder = right_arm.get_shoulder_position()

func set_body_animation_controller(controller: BodyAnimationController) -> void:
	body_animation_controller = controller

func _process(delta: float) -> void:
	if is_animating and current_attack != null:
		_update_animation(delta)
	else:
		## 如果 BodyAnimationController 正在播放移动/飞行动画，不更新 idle 状态
		if body_animation_controller == null or not body_animation_controller.is_movement_animation_active():
			_update_idle()

## ==================== 待机动画 ====================

func _update_idle() -> void:
	if current_weapon == null or current_weapon.weapon_type == WeaponData.WeaponType.UNARMED:
		_update_idle_unarmed()
	else:
		_update_idle_armed()

func _update_idle_unarmed() -> void:
	if left_arm:
		left_arm.set_hand_target(left_shoulder + idle_left_hand_offset)
	if right_arm:
		right_arm.set_hand_target(right_shoulder + idle_right_hand_offset)

func _update_idle_armed() -> void:
	if current_weapon == null:
		return
	match current_weapon.grip_type:
		WeaponData.GripType.ONE_HANDED:
			if left_arm:
				left_arm.set_hand_target(left_shoulder + Vector2(-5, 15))
			if right_arm:
				right_arm.set_hand_target(right_shoulder + Vector2(18, 5), 0)
		WeaponData.GripType.TWO_HANDED:
			var weapon_center = Vector2(15, 0)
			if right_arm:
				right_arm.set_hand_target(weapon_center + main_hand_grip_offset.rotated(0), 0)
			if left_arm:
				left_arm.set_hand_target(weapon_center + off_hand_grip_offset.rotated(0), 0)
		WeaponData.GripType.DUAL_WIELD:
			if left_arm:
				left_arm.set_hand_target(left_shoulder + Vector2(-15, 5))
			if right_arm:
				right_arm.set_hand_target(right_shoulder + Vector2(15, 5))

## ==================== 统一攻击动画框架 ====================

func _update_animation(delta: float) -> void:
	if current_attack == null:
		return

	var total_duration = current_attack.get_total_duration()
	animation_progress += delta / total_duration

	## 更新挥舞动量
	swing_momentum = maxf(0.0, swing_momentum - delta * 3.0)

	## 确定当前阶段
	var windup_ratio = current_attack.windup_time / total_duration
	var active_ratio = (current_attack.windup_time + current_attack.active_time) / total_duration

	var old_phase = animation_phase
	if animation_progress < windup_ratio:
		animation_phase = 0  ## windup
	elif animation_progress < active_ratio:
		animation_phase = 1  ## active
	else:
		animation_phase = 2  ## recovery

	## 检测进入 active 阶段
	if old_phase == 0 and animation_phase == 1:
		hit_frame_reached.emit(current_attack)
		swing_momentum = 1.5

	## 【重构核心】使用统一框架更新攻击视觉
	_update_attack_visuals_unified()

	## 检查动画结束
	if animation_progress >= 1.0:
		_finish_animation()

## 【重构核心】统一的攻击视觉更新 — 替代原来 6 个独立的 _update_xxx_visuals 函数
func _update_attack_visuals_unified() -> void:
	if current_attack == null:
		return

	var attack_type = current_attack.attack_type
	var profile = _profiles.get(attack_type, _profiles[AttackData.AttackType.SLASH]) as AttackAnimationProfile

	var swing_progress = _get_swing_progress()
	var recovery_progress = _get_recovery_progress()
	var wlf = _cached_weapon_length_factor  # 武器长度因子

	## 计算主手位置和旋转
	var main_hand_pos: Vector2
	var main_hand_rot: float
	var swing_angle_rad: float = 0.0

	if profile.overhead_angle.size() > 0:
		## 重击类型：使用 overhead_angle 驱动
		main_hand_pos = _calc_overhead_attack(profile, swing_progress, recovery_progress, wlf)
		var angle_deg = _get_overhead_angle(profile, swing_progress, recovery_progress)
		swing_angle_rad = deg_to_rad(angle_deg)
		main_hand_rot = swing_angle_rad
	elif not profile.angle_driven:
		## 刺击类型：直线运动
		main_hand_pos = _calc_thrust_attack(profile, swing_progress, recovery_progress, wlf)
		var body_lean = _get_thrust_body_lean(profile, swing_progress, recovery_progress)
		swing_angle_rad = body_lean * 0.5
		main_hand_rot = body_lean * 0.5
	else:
		## 标准旋转攻击（挥砍、横扫、旋转等）
		var swing_angle_deg = current_attack.get_swing_angle_at_progress(swing_progress)
		swing_angle_rad = deg_to_rad(swing_angle_deg)
		main_hand_pos = _calc_swing_attack(profile, swing_progress, recovery_progress, swing_angle_rad, wlf)
		var body_rot = _get_body_rotation(profile, swing_angle_rad, recovery_progress)
		main_hand_rot = swing_angle_rad + body_rot

	## 应用到右手
	if right_arm:
		right_arm.set_hand_target(main_hand_pos, main_hand_rot)
		right_arm.set_weapon_rotation(WEAPON_BASE_ROTATION)

	## 更新左手（双手/单手协调）
	_update_left_hand_unified(profile, swing_progress, recovery_progress, swing_angle_rad, main_hand_pos, main_hand_rot)

	## 更新 WeaponPhysics
	if weapon_physics:
		weapon_physics.set_target(Vector2.ZERO, swing_angle_rad)

## ==================== 通用计算方法 ====================

## 标准旋转攻击的主手位置计算
func _calc_swing_attack(profile: AttackAnimationProfile, swing_progress: float, recovery_progress: float, angle_rad: float, wlf: float) -> Vector2:
	var sr = profile.swing_radius
	var we = profile.weapon_extension
	var radius: float
	var extension: float

	match animation_phase:
		0:  ## windup
			radius = lerpf(sr[0], sr[1], swing_progress) * wlf
			extension = lerpf(we[0], we[1], swing_progress) * wlf
		1:  ## active
			radius = (sr[2] + swing_momentum * sr[3]) * wlf
			extension = (we[2] + swing_momentum * we[3]) * wlf
		2:  ## recovery
			radius = lerpf(sr[4], sr[5], recovery_progress) * wlf
			extension = lerpf(we[4], we[5], recovery_progress) * wlf
		_:
			radius = sr[2] * wlf
			extension = we[2] * wlf

	return right_shoulder + Vector2(radius + extension, 0).rotated(angle_rad)

## 刺击攻击的主手位置计算
func _calc_thrust_attack(profile: AttackAnimationProfile, swing_progress: float, recovery_progress: float, wlf: float) -> Vector2:
	var td = profile.thrust_distance
	var we = profile.weapon_extension
	var thrust_dist: float
	var arm_ext: float
	var body_lean: float = 0.0

	match animation_phase:
		0:  ## windup
			thrust_dist = lerpf(td[0], td[1], swing_progress) * wlf
			arm_ext = lerpf(we[0], we[1], swing_progress)
			body_lean = lerpf(0.0, -0.1, swing_progress)
		1:  ## active
			var active_t = _ease_out_cubic(swing_progress)
			thrust_dist = lerpf(td[2], (td[3] + swing_momentum * td[4]) * wlf, active_t)
			arm_ext = lerpf(we[2], (we[3] + swing_momentum * we[4]) * wlf, active_t)
			body_lean = lerpf(-0.1, 0.2, active_t)
		2:  ## recovery
			thrust_dist = lerpf(td[5] * wlf, td[6] * wlf, _ease_in_out_cubic(recovery_progress))
			arm_ext = lerpf(we[5] * wlf, we[6], recovery_progress)
			body_lean = lerpf(0.2, 0.0, recovery_progress)
		_:
			thrust_dist = td[0] * wlf
			arm_ext = 0.0

	return right_shoulder + Vector2(thrust_dist + arm_ext, body_lean * 20)

## 重击攻击的主手位置计算
func _calc_overhead_attack(profile: AttackAnimationProfile, swing_progress: float, recovery_progress: float, wlf: float) -> Vector2:
	var sr = profile.swing_radius
	var we = profile.weapon_extension
	var angle_deg = _get_overhead_angle(profile, swing_progress, recovery_progress)
	var angle_rad = deg_to_rad(angle_deg)
	var radius: float
	var extension: float

	match animation_phase:
		0:  ## windup
			radius = lerpf(sr[0], sr[1], _ease_out_cubic(swing_progress)) * wlf
			extension = lerpf(we[0], we[1], swing_progress) * wlf
		1:  ## active
			radius = lerpf(sr[2], (sr[3] + swing_momentum * sr[4]) * wlf, swing_progress)
			extension = lerpf(we[2], (we[3] + swing_momentum * we[4]) * wlf, _ease_in_cubic(swing_progress))
		2:  ## recovery
			radius = lerpf(sr[5], sr[6], recovery_progress) * wlf
			extension = lerpf(we[5], we[6], recovery_progress) * wlf
		_:
			radius = sr[0] * wlf
			extension = we[0] * wlf

	return right_shoulder + Vector2(radius + extension, 0).rotated(angle_rad)

## 获取重击的角度
func _get_overhead_angle(profile: AttackAnimationProfile, swing_progress: float, recovery_progress: float) -> float:
	var oa = profile.overhead_angle
	match animation_phase:
		0:
			return lerpf(oa[0], oa[1], _ease_out_cubic(swing_progress))
		1:
			return lerpf(oa[2], oa[3], _ease_in_cubic(swing_progress))
		2:
			return lerpf(oa[4], oa[5], recovery_progress)
		_:
			return oa[0]

## 获取身体跟随旋转
func _get_body_rotation(profile: AttackAnimationProfile, swing_angle_rad: float, recovery_progress: float) -> float:
	var brf = profile.body_rotation_factor
	match animation_phase:
		0:
			return -swing_angle_rad * brf[0]
		1:
			return swing_angle_rad * brf[1]
		2:
			return lerpf(swing_angle_rad * brf[2], 0.0, recovery_progress)
		_:
			return 0.0

## 获取刺击的身体倾斜
func _get_thrust_body_lean(profile: AttackAnimationProfile, swing_progress: float, recovery_progress: float) -> float:
	match animation_phase:
		0:
			return lerpf(0.0, -0.1, swing_progress)
		1:
			return lerpf(-0.1, 0.2, _ease_out_cubic(swing_progress))
		2:
			return lerpf(0.2, 0.0, recovery_progress)
		_:
			return 0.0

## ==================== 统一的左手协调 ====================

func _update_left_hand_unified(profile: AttackAnimationProfile, swing_progress: float, recovery_progress: float, swing_angle_rad: float, main_hand_pos: Vector2, main_hand_rot: float) -> void:
	if left_arm == null:
		return

	var is_two_handed = current_weapon != null and current_weapon.is_two_handed()

	if is_two_handed:
		## 双手武器：左手握在武器上，跟随主手
		var actual_main_pos = right_arm.get_hand_position() if right_arm else main_hand_pos
		var grip_offset = off_hand_grip_offset.rotated(swing_angle_rad)
		var off_hand_pos = actual_main_pos + grip_offset
		left_arm.set_hand_target(off_hand_pos, main_hand_rot)
	else:
		## 单手武器：左手做平衡动作
		var balance_factor = profile.left_hand_balance_factor
		var balance_angle = -swing_angle_rad * balance_factor
		var balance_radius = 15.0 + swing_progress * 5.0

		match animation_phase:
			0:  ## windup
				var left_pos = left_shoulder + Vector2(-balance_radius, -5).rotated(balance_angle * 0.3)
				left_arm.set_hand_target(left_pos, balance_angle * 0.5)
			1:  ## active
				var left_pos = left_shoulder + Vector2(-balance_radius - 5, 8).rotated(balance_angle)
				left_arm.set_hand_target(left_pos, balance_angle)
			2:  ## recovery
				var target_pos = left_shoulder + idle_left_hand_offset
				var current_pos = left_shoulder + Vector2(-balance_radius, 5)
				var left_pos = current_pos.lerp(target_pos, recovery_progress)
				left_arm.set_hand_target(left_pos, balance_angle * (1.0 - recovery_progress))

		## 旋转攻击特殊处理：左手反向旋转
		if current_attack and current_attack.attack_type == AttackData.AttackType.SPIN:
			var left_angle = swing_angle_rad + PI
			var left_radius = balance_radius * 0.6
			var left_pos = Vector2(left_radius, 0).rotated(left_angle)
			left_arm.set_hand_target(left_pos, left_angle)

## ==================== 工具方法 ====================

func _get_swing_progress() -> float:
	if current_attack == null:
		return 0.0
	var total_duration = current_attack.get_total_duration()
	var swing_end_time = current_attack.windup_time + current_attack.active_time
	var swing_ratio = swing_end_time / total_duration
	if animation_progress >= swing_ratio:
		return 1.0
	return animation_progress / swing_ratio

func _get_recovery_progress() -> float:
	if current_attack == null:
		return 0.0
	var total_duration = current_attack.get_total_duration()
	var active_end_ratio = (current_attack.windup_time + current_attack.active_time) / total_duration
	var recovery_ratio = current_attack.recovery_time / total_duration
	if animation_progress < active_end_ratio:
		return 0.0
	return minf(1.0, (animation_progress - active_end_ratio) / recovery_ratio)

func _ease_out_cubic(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3)

func _ease_in_cubic(t: float) -> float:
	return t * t * t

func _ease_in_out_cubic(t: float) -> float:
	if t < 0.5:
		return 4 * t * t * t
	else:
		return 1 - pow(-2 * t + 2, 3) / 2

func _finish_animation() -> void:
	var finished_attack = current_attack
	is_animating = false
	current_attack = null
	animation_progress = 0.0
	animation_phase = 0
	swing_momentum = 0.0
	animation_finished.emit(finished_attack)

## ==================== 公开接口 ====================

func play_attack(attack: AttackData) -> void:
	if attack == null:
		return
	current_attack = attack
	is_animating = true
	animation_progress = 0.0
	animation_phase = 0
	swing_momentum = 0.0
	animation_started.emit(attack)

func stop_animation() -> void:
	is_animating = false
	current_attack = null
	animation_progress = 0.0
	animation_phase = 0
	swing_momentum = 0.0

func set_weapon(weapon: WeaponData) -> void:
	current_weapon = weapon

	if weapon == null:
		main_hand_grip_offset = Vector2.ZERO
		off_hand_grip_offset = Vector2.ZERO
		_cached_weapon_length_factor = 1.0
		return

	## 设置握点偏移
	main_hand_grip_offset = weapon.grip_point_main
	off_hand_grip_offset = weapon.grip_point_off

	## 如果握点未设置，使用默认值
	if main_hand_grip_offset == Vector2.ZERO:
		main_hand_grip_offset = Vector2(0, weapon.weapon_length * 0.3)
	if off_hand_grip_offset == Vector2.ZERO:
		off_hand_grip_offset = Vector2(0, weapon.weapon_length * 0.6)

	## 【优化】缓存武器长度因子
	_cached_weapon_length_factor = clampf(weapon.weapon_length / 40.0, 0.8, 1.3)

func play_unarmed_attack(is_left_punch: bool) -> void:
	var punch = AttackData.new()
	punch.attack_name = "左拳" if is_left_punch else "右拳"
	punch.attack_type = AttackData.AttackType.THRUST
	punch.windup_time = 0.08
	punch.active_time = 0.05
	punch.recovery_time = 0.15
	punch.swing_start_angle = 0.0
	punch.swing_end_angle = 0.0
	play_attack(punch)

func get_animation_progress() -> float:
	return animation_progress

func is_playing() -> bool:
	return is_animating

func get_animation_phase() -> int:
	return animation_phase
