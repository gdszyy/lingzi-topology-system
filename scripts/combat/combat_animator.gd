class_name CombatAnimator extends Node
## 战斗动画控制器
## 根据攻击动作驱动手部轨迹
## 管理武器旋转和手臂 IK
## 【优化】实现双手协调攻击动作和武器挥舞效果

signal animation_started(attack: AttackData)
signal animation_finished(attack: AttackData)
signal hit_frame_reached(attack: AttackData)

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

## 武器基础旋转偏移（使武器纹理方向正确）
const WEAPON_BASE_ROTATION: float = -PI / 2

## 【新增】攻击动画参数
var attack_start_time: float = 0.0
var swing_momentum: float = 0.0  ## 挥舞动量，用于增强武器挥出感

## 【新增】双手协调参数
var left_hand_base_offset: Vector2 = Vector2.ZERO
var right_hand_base_offset: Vector2 = Vector2.ZERO
var body_lean_angle: float = 0.0  ## 身体倾斜角度

func _ready() -> void:
	pass

func initialize(left: ArmRig, right: ArmRig, physics: WeaponPhysics) -> void:
	left_arm = left
	right_arm = right
	weapon_physics = physics
	
	if left_arm:
		left_shoulder = left_arm.get_shoulder_position()
	if right_arm:
		right_shoulder = right_arm.get_shoulder_position()

## 引用 BodyAnimationController
var body_animation_controller: BodyAnimationController = null

## 设置 BodyAnimationController 引用
func set_body_animation_controller(controller: BodyAnimationController) -> void:
	body_animation_controller = controller

func _process(delta: float) -> void:
	if is_animating and current_attack != null:
		_update_animation(delta)
	else:
		## 如果 BodyAnimationController 正在播放移动/飞行动画，不更新 idle 状态
		if body_animation_controller == null or not body_animation_controller.is_movement_animation_active():
			_update_idle()

func _update_idle() -> void:
	## 待机状态：手放在默认位置
	if current_weapon == null or current_weapon.weapon_type == WeaponData.WeaponType.UNARMED:
		_update_idle_unarmed()
	else:
		_update_idle_armed()

func _update_idle_unarmed() -> void:
	## 徒手待机：双手握拳放在身侧
	if left_arm:
		left_arm.set_hand_target(left_shoulder + idle_left_hand_offset)
	if right_arm:
		right_arm.set_hand_target(right_shoulder + idle_right_hand_offset)

func _update_idle_armed() -> void:
	## 持武器待机：根据武器类型调整手位置
	if current_weapon == null:
		return
	
	match current_weapon.grip_type:
		WeaponData.GripType.ONE_HANDED:
			_update_idle_one_handed()
		WeaponData.GripType.TWO_HANDED:
			_update_idle_two_handed()
		WeaponData.GripType.DUAL_WIELD:
			_update_idle_dual_wield()

func _update_idle_one_handed() -> void:
	## 单手武器：右手持武器，左手放松
	if left_arm:
		left_arm.set_hand_target(left_shoulder + Vector2(-5, 15))
	
	if right_arm:
		## 右手持武器，位置在身前偏右
		var weapon_idle_pos = right_shoulder + Vector2(18, 5)
		right_arm.set_hand_target(weapon_idle_pos, 0)

func _update_idle_two_handed() -> void:
	## 双手武器：两只手都握在武器上
	## 武器在身前，略微倾斜
	var weapon_center = Vector2(15, 0)
	
	if right_arm:
		## 主手握点
		var main_grip = weapon_center + main_hand_grip_offset.rotated(0)
		right_arm.set_hand_target(main_grip, 0)
	
	if left_arm:
		## 副手握点
		var off_grip = weapon_center + off_hand_grip_offset.rotated(0)
		left_arm.set_hand_target(off_grip, 0)

func _update_idle_dual_wield() -> void:
	## 双持：两只手各持一把武器
	if left_arm:
		left_arm.set_hand_target(left_shoulder + Vector2(-15, 5))
	if right_arm:
		right_arm.set_hand_target(right_shoulder + Vector2(15, 5))

func _update_animation(delta: float) -> void:
	if current_attack == null:
		return
	
	var total_duration = current_attack.get_total_duration()
	animation_progress += delta / total_duration
	
	## 更新挥舞动量
	_update_swing_momentum(delta)
	
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
		## 在击中帧增加额外动量
		swing_momentum = 1.5
	
	## 统一更新手部位置和武器旋转
	_update_attack_visuals()
	
	## 检查动画结束
	if animation_progress >= 1.0:
		_finish_animation()

## 【新增】更新挥舞动量
func _update_swing_momentum(delta: float) -> void:
	## 动量衰减
	swing_momentum = max(0, swing_momentum - delta * 3.0)

## 统一的攻击视觉更新方法
func _update_attack_visuals() -> void:
	if current_attack == null:
		return
	
	var attack_type = current_attack.attack_type
	
	match attack_type:
		AttackData.AttackType.SLASH:
			_update_slash_visuals_enhanced()
		AttackData.AttackType.REVERSE_SLASH:
			_update_reverse_slash_visuals()
		AttackData.AttackType.THRUST:
			_update_thrust_visuals_enhanced()
		AttackData.AttackType.SMASH:
			_update_smash_visuals_enhanced()
		AttackData.AttackType.SWEEP:
			_update_sweep_visuals_enhanced()
		AttackData.AttackType.SPIN:
			_update_spin_visuals_enhanced()
		_:
			_update_slash_visuals_enhanced()

## 【优化】增强版挥砍攻击 - 双手协调动作
func _update_slash_visuals_enhanced() -> void:
	var swing_progress = _get_swing_progress()
	var swing_angle_deg = current_attack.get_swing_angle_at_progress(swing_progress)
	var swing_angle_rad = deg_to_rad(swing_angle_deg)
	
	## 【修复】根据武器长度计算伸缩系数（收紧上限）
	var weapon_length_factor = 1.0
	if current_weapon:
		## 武器越长，挥舞半径和伸出距离应该越大，但不能超过手臂最大位移
		weapon_length_factor = clamp(current_weapon.weapon_length / 40.0, 0.8, 1.3)
	
	## 根据动画阶段调整挥舞参数
	var swing_radius: float
	var weapon_extension: float  ## 武器伸出距离
	var body_rotation: float  ## 身体跟随旋转
	
	match animation_phase:
		0:  ## windup - 蓄力阶段
			## 手臂向后拉，准备挥舞
			swing_radius = (18.0 + swing_progress * 6.0) * weapon_length_factor
			weapon_extension = (-3.0 + swing_progress * 8.0) * weapon_length_factor  ## 武器略微后收
			body_rotation = -swing_angle_rad * 0.2  ## 身体轻微反向
		1:  ## active - 【修复】武器快速挥出 - 收紧伸出距离
			swing_radius = (26.0 + swing_momentum * 6.0) * weapon_length_factor  ## 动量增加挥舞半径
			weapon_extension = (15.0 + swing_momentum * 10.0) * weapon_length_factor  ## 武器伸出
			body_rotation = swing_angle_rad * 0.4  ## 身体跟随旋转增强
		2:  ## recovery - 恢复阶段
			## 收回动作
			var recovery_progress = (animation_progress - (current_attack.windup_time + current_attack.active_time) / current_attack.get_total_duration())
			recovery_progress = recovery_progress / (current_attack.recovery_time / current_attack.get_total_duration())
			swing_radius = lerp(26.0, 20.0, recovery_progress) * weapon_length_factor
			weapon_extension = lerp(15.0, 5.0, recovery_progress) * weapon_length_factor
			body_rotation = lerp(swing_angle_rad * 0.4, 0.0, recovery_progress)
		_:
			swing_radius = 25.0 * weapon_length_factor
			weapon_extension = 10.0 * weapon_length_factor
			body_rotation = 0.0
	
	## 计算主手位置 - 武器挥舞轨迹
	var main_hand_offset = Vector2(swing_radius + weapon_extension, 0).rotated(swing_angle_rad)
	var main_hand_pos = right_shoulder + main_hand_offset
	
	## 主手旋转跟随挥舞角度
	var main_hand_rotation = swing_angle_rad + body_rotation
	
	if right_arm:
		right_arm.set_hand_target(main_hand_pos, main_hand_rotation)
		## 武器精灵旋转
		right_arm.set_weapon_rotation(WEAPON_BASE_ROTATION)
	
	## 【关键优化】左手协调动作
	_update_left_hand_for_slash(swing_progress, swing_angle_rad, body_rotation)
	
	## 更新 WeaponPhysics
	if weapon_physics:
		weapon_physics.set_target(Vector2.ZERO, swing_angle_rad)

## 【新增】挥砍时的左手协调动作
func _update_left_hand_for_slash(swing_progress: float, swing_angle_rad: float, body_rotation: float) -> void:
	if left_arm == null:
		return
	
	var is_two_handed = current_weapon != null and current_weapon.is_two_handed()
	
	if is_two_handed:
		## 【修复】双手武器：左手握在武器上，跟随主手
		var main_hand_pos = right_arm.get_hand_position() if right_arm else right_shoulder
		var grip_offset = off_hand_grip_offset.rotated(swing_angle_rad)
		var off_hand_pos = main_hand_pos + grip_offset
		left_arm.set_hand_target(off_hand_pos, swing_angle_rad + body_rotation)
		left_arm.set_weapon_rotation(WEAPON_BASE_ROTATION)
	else:
		## 单手武器：左手做平衡动作
		var balance_angle = -swing_angle_rad * 0.5  ## 反向平衡
		var balance_radius = 15.0 + swing_progress * 5.0
		
		match animation_phase:
			0:  ## windup - 左手向前伸出保持平衡
				var left_hand_pos = left_shoulder + Vector2(-balance_radius, -5).rotated(balance_angle * 0.3)
				left_arm.set_hand_target(left_hand_pos, balance_angle * 0.5)
			1:  ## active - 左手向后摆动
				var left_hand_pos = left_shoulder + Vector2(-balance_radius - 5, 8).rotated(balance_angle)
				left_arm.set_hand_target(left_hand_pos, balance_angle)
			2:  ## recovery - 左手恢复
				var recovery_progress = _get_recovery_progress()
				var left_hand_pos = left_shoulder + idle_left_hand_offset.lerp(Vector2(-balance_radius, 5), 1.0 - recovery_progress)
				left_arm.set_hand_target(left_hand_pos, balance_angle * (1.0 - recovery_progress))

## 【新增】反手挥砍攻击
func _update_reverse_slash_visuals() -> void:
	var swing_progress = _get_swing_progress()
	var swing_angle_deg = current_attack.get_swing_angle_at_progress(swing_progress)
	var swing_angle_rad = deg_to_rad(swing_angle_deg)
	
	## 反手挥砍参数
	var swing_radius: float
	var weapon_extension: float
	
	match animation_phase:
		0:  ## windup
			swing_radius = 18.0 + swing_progress * 8.0
			weapon_extension = -3.0 + swing_progress * 8.0
		1:  ## active
			swing_radius = 26.0 + swing_momentum * 6.0
			weapon_extension = 12.0 + swing_momentum * 10.0
		2:  ## recovery
			var recovery_progress = _get_recovery_progress()
			swing_radius = lerp(26.0, 20.0, recovery_progress)
			weapon_extension = lerp(12.0, 5.0, recovery_progress)
		_:
			swing_radius = 22.0
			weapon_extension = 8.0
	
	## 主手位置
	var main_hand_offset = Vector2(swing_radius + weapon_extension, 0).rotated(swing_angle_rad)
	var main_hand_pos = right_shoulder + main_hand_offset
	
	if right_arm:
		right_arm.set_hand_target(main_hand_pos, swing_angle_rad)
		right_arm.set_weapon_rotation(WEAPON_BASE_ROTATION)
	
	## 左手协调
	_update_left_hand_for_slash(swing_progress, swing_angle_rad, 0.0)
	
	if weapon_physics:
		weapon_physics.set_target(Vector2.ZERO, swing_angle_rad)

## 【优化】增强版刷击攻击 - 双手协调动作
func _update_thrust_visuals_enhanced() -> void:
	var thrust_progress = _get_swing_progress()
	
	## 【新增】根据武器长度计算伸缩系数
	var weapon_length_factor = 1.0
	if current_weapon:
		## 武器越长，刷击轨迹参数也应该越大（收紧上限）
		weapon_length_factor = clamp(current_weapon.weapon_length / 40.0, 0.9, 1.3)
	
	## 刷击轨迹参数
	var thrust_distance: float
	var arm_extension: float
	var body_lean: float
	
	match animation_phase:
		0:  ## windup - 后拉蓄力
			## 手臂后收，身体后仑
			thrust_distance = lerp(20.0, 8.0, thrust_progress) * weapon_length_factor
			arm_extension = lerp(0.0, -8.0, thrust_progress)
			body_lean = lerp(0.0, -0.1, thrust_progress)
		1:  ## active - 快速刷出
			## 【修复】手臂快速伸出 - 收紧刷击距离
			var active_progress = (thrust_progress - 0.0) / 1.0
			thrust_distance = lerp(8.0, (40.0 + swing_momentum * 12.0) * weapon_length_factor, _ease_out_cubic(active_progress))
			arm_extension = lerp(-8.0, (12.0 + swing_momentum * 6.0) * weapon_length_factor, _ease_out_cubic(active_progress))
			body_lean = lerp(-0.1, 0.2, _ease_out_cubic(active_progress))
		2:  ## recovery - 收回
			var recovery_progress = _get_recovery_progress()
			thrust_distance = lerp((40.0 * weapon_length_factor), (15.0 * weapon_length_factor), _ease_in_out_cubic(recovery_progress))
			arm_extension = lerp((12.0 * weapon_length_factor), 0.0, recovery_progress)
			body_lean = lerp(0.2, 0.0, recovery_progress)
		_:
			thrust_distance = 20.0 * weapon_length_factor
			arm_extension = 0.0
			body_lean = 0.0
	
	## 主手位置 - 向前刺出
	var main_hand_pos = right_shoulder + Vector2(thrust_distance + arm_extension, body_lean * 20)
	var main_hand_rotation = body_lean * 0.5  ## 轻微旋转
	
	if right_arm:
		right_arm.set_hand_target(main_hand_pos, main_hand_rotation)
		right_arm.set_weapon_rotation(WEAPON_BASE_ROTATION)
	
	## 【关键优化】左手协调动作
	_update_left_hand_for_thrust(thrust_progress, thrust_distance, body_lean)
	
	if weapon_physics:
		weapon_physics.set_target(Vector2.ZERO, 0)

## 【新增】刺击时的左手协调动作
func _update_left_hand_for_thrust(thrust_progress: float, thrust_distance: float, body_lean: float) -> void:
	if left_arm == null:
		return
	
	var is_two_handed = current_weapon != null and current_weapon.is_two_handed()
	
	if is_two_handed:
		## 【关键优化】双手武器：左手握在武器杆上
		var main_hand_pos = right_arm.get_hand_position() if right_arm else right_shoulder
		## 【修复】使用 off_hand_grip_offset 而不是硬编码偏移
		var grip_offset = off_hand_grip_offset.rotated(body_lean * 0.3)
		var off_hand_pos = main_hand_pos + grip_offset
		left_arm.set_hand_target(off_hand_pos, body_lean * 0.3)
	else:
		## 单手武器：左手做平衡/防御姿势
		match animation_phase:
			0:  ## windup - 左手向前准备
				var left_hand_pos = left_shoulder + Vector2(-12, -5 + thrust_progress * 8)
				left_arm.set_hand_target(left_hand_pos, 0.2)
			1:  ## active - 左手向后平衡
				var left_hand_pos = left_shoulder + Vector2(-8 - thrust_distance * 0.3, 10 + body_lean * 30)
				left_arm.set_hand_target(left_hand_pos, -body_lean)
			2:  ## recovery - 左手恢复
				var recovery_progress = _get_recovery_progress()
				var target_pos = left_shoulder + idle_left_hand_offset
				var current_pos = left_shoulder + Vector2(-8, 10)
				var left_hand_pos = current_pos.lerp(target_pos, recovery_progress)
				left_arm.set_hand_target(left_hand_pos, -body_lean * (1.0 - recovery_progress))

## 【优化】增强版重击攻击 - 双手大幅度动作
func _update_smash_visuals_enhanced() -> void:
	var smash_progress = _get_swing_progress()
	
	## 【新增】根据武器长度计算伸缩系数
	var weapon_length_factor = 1.0
	if current_weapon:
		weapon_length_factor = clamp(current_weapon.weapon_length / 40.0, 0.8, 1.3)
	
	## 重击轨迹：举起 -> 砂下
	var angle_deg: float
	var swing_radius: float
	var weapon_extension: float
	
	match animation_phase:
		0:  ## windup - 举起武器
			## 武器高举过头
			angle_deg = lerp(0.0, -110.0, _ease_out_cubic(smash_progress))
			swing_radius = lerp(20.0, 15.0, smash_progress) * weapon_length_factor  ## 收紧准备
			weapon_extension = lerp(5.0, -5.0, smash_progress) * weapon_length_factor
		1:  ## active - 【关键优化】砂下
			var active_progress = smash_progress
			angle_deg = lerp(-110.0, 45.0, _ease_in_cubic(active_progress))
			swing_radius = lerp(15.0, (38.0 + swing_momentum * 10.0) * weapon_length_factor, active_progress)  ## 大幅伸出
			weapon_extension = lerp(-5.0, (25.0 + swing_momentum * 12.0) * weapon_length_factor, _ease_in_cubic(active_progress))
		2:  ## recovery - 恢复
			var recovery_progress = _get_recovery_progress()
			angle_deg = lerp(45.0, 0.0, recovery_progress)
			swing_radius = lerp(38.0, 22.0, recovery_progress) * weapon_length_factor
			weapon_extension = lerp(25.0, 6.0, recovery_progress) * weapon_length_factor
		_:
			angle_deg = 0.0
			swing_radius = 20.0 * weapon_length_factor
			weapon_extension = 5.0 * weapon_length_factor
	
	var angle_rad = deg_to_rad(angle_deg)
	var main_hand_pos = right_shoulder + Vector2(swing_radius + weapon_extension, 0).rotated(angle_rad)
	var main_hand_rotation = angle_rad
	
	if right_arm:
		right_arm.set_hand_target(main_hand_pos, main_hand_rotation)
		right_arm.set_weapon_rotation(WEAPON_BASE_ROTATION)
	
	## 【关键优化】左手协调 - 重击时双手都要用力
	_update_left_hand_for_smash(smash_progress, angle_rad, swing_radius, weapon_extension)
	
	if weapon_physics:
		weapon_physics.set_target(Vector2.ZERO, angle_rad)

## 【新增】重击时的左手协调动作
func _update_left_hand_for_smash(smash_progress: float, angle_rad: float, swing_radius: float, weapon_extension: float) -> void:
	if left_arm == null:
		return
	
	var is_two_handed = current_weapon != null and current_weapon.is_two_handed()
	
	if is_two_handed:
		## 双手武器重击：左手紧握武器
		var main_hand_pos = right_arm.get_hand_position() if right_arm else right_shoulder
		var grip_offset = off_hand_grip_offset.rotated(angle_rad)
		var off_hand_pos = main_hand_pos + grip_offset
		left_arm.set_hand_target(off_hand_pos, angle_rad)
	else:
		## 单手武器重击：左手辅助发力
		match animation_phase:
			0:  ## windup - 左手也举起
				var left_angle = angle_rad * 0.6
				var left_hand_pos = left_shoulder + Vector2(-swing_radius * 0.7, 0).rotated(left_angle)
				left_arm.set_hand_target(left_hand_pos, left_angle)
			1:  ## active - 左手向下挥
				var left_angle = angle_rad * 0.5
				var left_hand_pos = left_shoulder + Vector2(-swing_radius * 0.6 - weapon_extension * 0.3, 0).rotated(left_angle)
				left_arm.set_hand_target(left_hand_pos, left_angle)
			2:  ## recovery - 左手恢复
				var recovery_progress = _get_recovery_progress()
				var target_pos = left_shoulder + idle_left_hand_offset
				var current_angle = angle_rad * 0.5
				var left_hand_pos = (left_shoulder + Vector2(-15, 0).rotated(current_angle)).lerp(target_pos, recovery_progress)
				left_arm.set_hand_target(left_hand_pos, current_angle * (1.0 - recovery_progress))

## 【优化】增强版横扫攻击 - 大范围双手动作
func _update_sweep_visuals_enhanced() -> void:
	var swing_progress = _get_swing_progress()
	var swing_angle_deg = current_attack.get_swing_angle_at_progress(swing_progress)
	var swing_angle_rad = deg_to_rad(swing_angle_deg)
	
	## 【新增】根据武器长度计算伸缩系数
	var weapon_length_factor = 1.0
	if current_weapon:
		weapon_length_factor = clamp(current_weapon.weapon_length / 40.0, 0.8, 1.3)
	
	## 横扫参数 - 更大的挥舞范围
	var swing_radius: float
	var weapon_extension: float
	var body_rotation: float
	
	match animation_phase:
		0:  ## windup
			swing_radius = (22.0 + swing_progress * 10.0) * weapon_length_factor
			weapon_extension = (swing_progress * 15.0) * weapon_length_factor
			body_rotation = swing_angle_rad * 0.4
		1:  ## active - 【关键优化】大范围横扫
			swing_radius = (35.0 + swing_momentum * 10.0) * weapon_length_factor
			weapon_extension = (22.0 + swing_momentum * 15.0) * weapon_length_factor
			body_rotation = swing_angle_rad * 0.6
		2:  ## recovery
			var recovery_progress = _get_recovery_progress()
			swing_radius = lerp(35.0, 22.0, recovery_progress) * weapon_length_factor
			weapon_extension = lerp(22.0, 8.0, recovery_progress) * weapon_length_factor
			body_rotation = lerp(swing_angle_rad * 0.6, 0.0, recovery_progress)
		_:
			swing_radius = 25.0 * weapon_length_factor
			weapon_extension = 10.0 * weapon_length_factor
			body_rotation = 0.0
	
	var main_hand_offset = Vector2(swing_radius + weapon_extension, 0).rotated(swing_angle_rad)
	var main_hand_pos = right_shoulder + main_hand_offset
	
	if right_arm:
		right_arm.set_hand_target(main_hand_pos, swing_angle_rad + body_rotation * 0.3)
		right_arm.set_weapon_rotation(WEAPON_BASE_ROTATION)
	
	## 左手协调 - 横扫时身体大幅转动
	_update_left_hand_for_sweep(swing_progress, swing_angle_rad, body_rotation)
	
	if weapon_physics:
		weapon_physics.set_target(Vector2.ZERO, swing_angle_rad)

## 【新增】横扫时的左手协调动作
func _update_left_hand_for_sweep(swing_progress: float, swing_angle_rad: float, body_rotation: float) -> void:
	if left_arm == null:
		return
	
	var is_two_handed = current_weapon != null and current_weapon.is_two_handed()
	
	if is_two_handed:
		## 双手武器横扫
		var main_hand_pos = right_arm.get_hand_position() if right_arm else right_shoulder
		var grip_offset = off_hand_grip_offset.rotated(swing_angle_rad)
		var off_hand_pos = main_hand_pos + grip_offset
		left_arm.set_hand_target(off_hand_pos, swing_angle_rad)
	else:
		## 单手武器横扫：左手大幅平衡动作
		var balance_angle = -swing_angle_rad * 0.7
		var balance_radius = 18.0 + abs(sin(swing_angle_rad)) * 8.0
		var left_hand_pos = left_shoulder + Vector2(-balance_radius, 0).rotated(balance_angle)
		left_arm.set_hand_target(left_hand_pos, balance_angle)

## 【优化】增强版旋转攻击 - 全身旋转
func _update_spin_visuals_enhanced() -> void:
	var spin_progress = _get_swing_progress()
	var swing_angle_deg = current_attack.get_swing_angle_at_progress(spin_progress)
	var swing_angle_rad = deg_to_rad(swing_angle_deg)
	
	## 【新增】根据武器长度计算伸缩系数
	var weapon_length_factor = 1.0
	if current_weapon:
		weapon_length_factor = clamp(current_weapon.weapon_length / 40.0, 0.8, 1.3)
	
	## 旋转攻击参数
	var spin_radius: float
	var weapon_extension: float
	
	match animation_phase:
		0:  ## windup - 准备旋转
			spin_radius = (20.0 + spin_progress * 8.0) * weapon_length_factor
			weapon_extension = (spin_progress * 10.0) * weapon_length_factor
		1:  ## active - 【关键优化】快速旋转
			spin_radius = (28.0 + swing_momentum * 8.0) * weapon_length_factor
			weapon_extension = (15.0 + swing_momentum * 10.0) * weapon_length_factor
		2:  ## recovery
			var recovery_progress = _get_recovery_progress()
			spin_radius = lerp(28.0, 20.0, recovery_progress) * weapon_length_factor
			weapon_extension = lerp(15.0, 6.0, recovery_progress) * weapon_length_factor
		_:
			spin_radius = 20.0 * weapon_length_factor
			weapon_extension = 8.0 * weapon_length_factor
	
	## 主手绕身体旋转
	var main_hand_pos = Vector2(spin_radius + weapon_extension, 0).rotated(swing_angle_rad)
	
	if right_arm:
		right_arm.set_hand_target(main_hand_pos, swing_angle_rad)
		right_arm.set_weapon_rotation(WEAPON_BASE_ROTATION)
	
	## 左手也绕身体旋转（相位差180度）
	if left_arm:
		var is_two_handed = current_weapon != null and current_weapon.is_two_handed()
		if is_two_handed:
			var main_pos = right_arm.get_hand_position() if right_arm else Vector2.ZERO
			var grip_offset = off_hand_grip_offset.rotated(swing_angle_rad)
			var off_hand_pos = main_pos + grip_offset
			left_arm.set_hand_target(off_hand_pos, swing_angle_rad)
		else:
			## 单手武器：左手反向旋转保持平衡
			var left_angle = swing_angle_rad + PI
			var left_radius = spin_radius * 0.6
			var left_hand_pos = Vector2(left_radius, 0).rotated(left_angle)
			left_arm.set_hand_target(left_hand_pos, left_angle)
	
	if weapon_physics:
		weapon_physics.set_target(Vector2.ZERO, swing_angle_rad)

## 获取挥舞进度
func _get_swing_progress() -> float:
	if current_attack == null:
		return 0.0
	
	var total_duration = current_attack.get_total_duration()
	var swing_end_time = current_attack.windup_time + current_attack.active_time
	var swing_ratio = swing_end_time / total_duration
	
	if animation_progress >= swing_ratio:
		return 1.0
	
	return animation_progress / swing_ratio

## 【新增】获取恢复阶段进度
func _get_recovery_progress() -> float:
	if current_attack == null:
		return 0.0
	
	var total_duration = current_attack.get_total_duration()
	var active_end_ratio = (current_attack.windup_time + current_attack.active_time) / total_duration
	var recovery_ratio = current_attack.recovery_time / total_duration
	
	if animation_progress < active_end_ratio:
		return 0.0
	
	return min(1.0, (animation_progress - active_end_ratio) / recovery_ratio)

## 【新增】缓动函数
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

## 开始播放攻击动画
func play_attack(attack: AttackData) -> void:
	if attack == null:
		return
	
	current_attack = attack
	is_animating = true
	animation_progress = 0.0
	animation_phase = 0
	swing_momentum = 0.0
	attack_start_time = Time.get_ticks_msec() / 1000.0
	animation_started.emit(attack)

## 停止当前动画
func stop_animation() -> void:
	is_animating = false
	current_attack = null
	animation_progress = 0.0
	animation_phase = 0
	swing_momentum = 0.0

## 设置当前武器
func set_weapon(weapon: WeaponData) -> void:
	current_weapon = weapon
	
	if weapon == null:
		main_hand_grip_offset = Vector2.ZERO
		off_hand_grip_offset = Vector2.ZERO
		return
	
	## 设置握点偏移
	main_hand_grip_offset = weapon.grip_point_main
	off_hand_grip_offset = weapon.grip_point_off
	
	## 如果握点未设置，使用默认值
	if main_hand_grip_offset == Vector2.ZERO:
		main_hand_grip_offset = Vector2(0, weapon.weapon_length * 0.3)
	if off_hand_grip_offset == Vector2.ZERO:
		off_hand_grip_offset = Vector2(0, weapon.weapon_length * 0.6)

## 播放徒手攻击
func play_unarmed_attack(is_left_punch: bool) -> void:
	## 创建临时的拳击攻击数据
	var punch = AttackData.new()
	punch.attack_name = "左拳" if is_left_punch else "右拳"
	punch.attack_type = AttackData.AttackType.THRUST
	punch.windup_time = 0.08
	punch.active_time = 0.05
	punch.recovery_time = 0.15
	
	## 设置挥舞角度（拳击是直线，角度不变）
	punch.swing_start_angle = 0.0
	punch.swing_end_angle = 0.0
	
	play_attack(punch)

## 获取当前动画进度
func get_animation_progress() -> float:
	return animation_progress

## 检查是否正在播放动画
func is_playing() -> bool:
	return is_animating

## 获取当前动画阶段
func get_animation_phase() -> int:
	return animation_phase
