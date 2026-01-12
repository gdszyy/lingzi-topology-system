class_name CombatAnimator extends Node
## 战斗动画控制器
## 根据攻击动作驱动手部轨迹
## 管理武器旋转和手臂 IK

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

func _process(delta: float) -> void:
	if is_animating and current_attack != null:
		_update_animation(delta)
	else:
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
	
	## 更新手部位置
	_update_hand_positions_for_attack()
	
	## 更新武器旋转
	_update_weapon_rotation()
	
	## 检查动画结束
	if animation_progress >= 1.0:
		_finish_animation()

func _update_hand_positions_for_attack() -> void:
	if current_attack == null:
		return
	
	## 根据攻击类型和进度计算手的位置
	var attack_type = current_attack.attack_type
	
	match attack_type:
		AttackData.AttackType.SLASH, AttackData.AttackType.REVERSE_SLASH:
			_update_slash_hand_positions()
		AttackData.AttackType.THRUST:
			_update_thrust_hand_positions()
		AttackData.AttackType.SMASH:
			_update_smash_hand_positions()
		AttackData.AttackType.SWEEP:
			_update_sweep_hand_positions()
		_:
			_update_slash_hand_positions()

func _update_slash_hand_positions() -> void:
	## 挥砍攻击的手部轨迹
	var swing_angle = current_attack.get_swing_angle_at_progress(_get_swing_progress())
	var swing_rad = deg_to_rad(swing_angle)
	
	## 手的位置跟随武器挥舞
	var swing_radius = 25.0
	var hand_pos = right_shoulder + Vector2(swing_radius, 0).rotated(swing_rad)
	
	if right_arm:
		right_arm.set_hand_target(hand_pos, swing_rad)
	
	## 双手武器时，左手也跟随
	if current_weapon and current_weapon.is_two_handed() and left_arm:
		var off_hand_pos = hand_pos + off_hand_grip_offset.rotated(swing_rad)
		left_arm.set_hand_target(off_hand_pos, swing_rad)

func _update_thrust_hand_positions() -> void:
	## 刺击攻击的手部轨迹
	var thrust_progress = _get_swing_progress()
	
	## 刺击轨迹：后拉 -> 前刺 -> 收回
	var thrust_distance: float
	if thrust_progress < 0.3:
		## 后拉
		thrust_distance = lerp(20.0, 10.0, thrust_progress / 0.3)
	elif thrust_progress < 0.6:
		## 前刺
		thrust_distance = lerp(10.0, 35.0, (thrust_progress - 0.3) / 0.3)
	else:
		## 收回
		thrust_distance = lerp(35.0, 20.0, (thrust_progress - 0.6) / 0.4)
	
	var hand_pos = right_shoulder + Vector2(thrust_distance, 0)
	
	if right_arm:
		right_arm.set_hand_target(hand_pos, 0)
	
	if current_weapon and current_weapon.is_two_handed() and left_arm:
		var off_hand_pos = hand_pos + Vector2(-15, 0)
		left_arm.set_hand_target(off_hand_pos, 0)

func _update_smash_hand_positions() -> void:
	## 重击攻击的手部轨迹
	var smash_progress = _get_swing_progress()
	
	## 重击轨迹：举起 -> 砸下
	var angle: float
	if smash_progress < 0.5:
		## 举起
		angle = lerp(0.0, -90.0, smash_progress / 0.5)
	else:
		## 砸下
		angle = lerp(-90.0, 30.0, (smash_progress - 0.5) / 0.5)
	
	var angle_rad = deg_to_rad(angle)
	var hand_pos = right_shoulder + Vector2(20, 0).rotated(angle_rad)
	
	if right_arm:
		right_arm.set_hand_target(hand_pos, angle_rad)
	
	if current_weapon and current_weapon.is_two_handed() and left_arm:
		var off_hand_pos = hand_pos + off_hand_grip_offset.rotated(angle_rad)
		left_arm.set_hand_target(off_hand_pos, angle_rad)

func _update_sweep_hand_positions() -> void:
	## 横扫攻击的手部轨迹（类似挥砍但范围更大）
	_update_slash_hand_positions()

func _get_swing_progress() -> float:
	## 获取挥舞进度（只在 windup 和 active 阶段）
	if current_attack == null:
		return 0.0
	
	var total_duration = current_attack.get_total_duration()
	var swing_end_time = current_attack.windup_time + current_attack.active_time
	var swing_ratio = swing_end_time / total_duration
	
	if animation_progress >= swing_ratio:
		return 1.0
	
	return animation_progress / swing_ratio

func _update_weapon_rotation() -> void:
	if weapon_physics == null or current_attack == null:
		return
	
	var swing_angle = current_attack.get_swing_angle_at_progress(_get_swing_progress())
	weapon_physics.set_target(Vector2.ZERO, deg_to_rad(swing_angle))

func _finish_animation() -> void:
	var finished_attack = current_attack
	is_animating = false
	current_attack = null
	animation_progress = 0.0
	animation_phase = 0
	animation_finished.emit(finished_attack)

## 开始播放攻击动画
func play_attack(attack: AttackData) -> void:
	if attack == null:
		return
	
	current_attack = attack
	is_animating = true
	animation_progress = 0.0
	animation_phase = 0
	animation_started.emit(attack)

## 停止当前动画
func stop_animation() -> void:
	is_animating = false
	current_attack = null
	animation_progress = 0.0
	animation_phase = 0

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
