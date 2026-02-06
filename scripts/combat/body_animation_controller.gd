class_name BodyAnimationController extends Node
## 全身骨骼动画控制器
## 管理移动和飞行时的全身动画效果
## 包括手臂摆动、躯干倾斜、头部摆动等
## 【重要】不影响攻击动画 - 攻击时由 CombatAnimator 接管
## 【优化】移除冗余调试日志、修复 lerp 权重溢出、优化状态转换

signal animation_state_changed(state: AnimationState)

## 动画状态枚举
enum AnimationState {
	IDLE,
	WALKING,
	RUNNING,
	FLYING,
	FLYING_FAST,
	ATTACKING
}

## 引用
var player: PlayerController = null
var left_arm: ArmRig = null
var right_arm: ArmRig = null
var torso_pivot: Node2D = null
var head_sprite: Sprite2D = null
var legs_pivot: Node2D = null

## 直接引用 CombatAnimator
var combat_animator: CombatAnimator = null

## 当前状态
var current_state: AnimationState = AnimationState.IDLE
var is_combat_animator_active: bool = false

## 动画周期
var animation_cycle: float = 0.0
var animation_speed: float = 10.0

## 配置参数
@export_group("Walk Animation")
@export var walk_arm_swing_amplitude: float = 15.0
@export var walk_torso_bob_amplitude: float = 2.5
@export var walk_torso_sway_amplitude: float = 0.08
@export var walk_head_bob_amplitude: float = 1.5

@export_group("Run Animation")
@export var run_arm_swing_amplitude: float = 22.0
@export var run_torso_bob_amplitude: float = 4.0
@export var run_torso_lean_max: float = 0.2
@export var run_head_bob_amplitude: float = 2.0

@export_group("Flight Animation")
@export var flight_arm_spread_angle: float = 1.0
@export var flight_arm_wave_amplitude: float = 10.0
@export var flight_arm_wave_speed: float = 4.0
@export var flight_torso_lean_factor: float = 0.25
@export var flight_torso_lean_max: float = 0.5
@export var flight_head_tilt_factor: float = 0.15

@export_group("Fast Flight Animation")
@export var fast_flight_arm_back_angle: float = 1.5
@export var fast_flight_torso_lean: float = 0.6
@export var fast_flight_speed_threshold: float = 300.0

@export_group("Transition")
@export var state_transition_speed: float = 10.0
@export var arm_smoothing: float = 15.0

## 肩膀位置
var left_shoulder: Vector2 = Vector2(-12, 0)
var right_shoulder: Vector2 = Vector2(12, 0)

## 待机手臂位置
var idle_left_hand_offset: Vector2 = Vector2(-5, 18)
var idle_right_hand_offset: Vector2 = Vector2(5, 18)

## 当前动画目标值
var target_left_hand_pos: Vector2 = Vector2.ZERO
var target_right_hand_pos: Vector2 = Vector2.ZERO
var target_torso_rotation: float = 0.0
var target_torso_offset: Vector2 = Vector2.ZERO
var target_head_offset: Vector2 = Vector2.ZERO

## 当前插值值
var current_left_hand_pos: Vector2 = Vector2.ZERO
var current_right_hand_pos: Vector2 = Vector2.ZERO
var current_torso_rotation: float = 0.0
var current_torso_offset: Vector2 = Vector2.ZERO
var current_head_offset: Vector2 = Vector2.ZERO

## 速度相关
var speed_factor: float = 0.0

var _initialized: bool = false

func _ready() -> void:
	_initialize_positions()

func initialize(p_player: PlayerController, p_left_arm: ArmRig, p_right_arm: ArmRig,
				p_torso_pivot: Node2D, p_head_sprite: Sprite2D, p_legs_pivot: Node2D) -> void:
	player = p_player
	left_arm = p_left_arm
	right_arm = p_right_arm
	torso_pivot = p_torso_pivot
	head_sprite = p_head_sprite
	legs_pivot = p_legs_pivot

	if left_arm:
		left_shoulder = left_arm.get_shoulder_position()
	if right_arm:
		right_shoulder = right_arm.get_shoulder_position()

	_initialize_positions()
	_initialized = true

func set_combat_animator(animator: CombatAnimator) -> void:
	combat_animator = animator

func _initialize_positions() -> void:
	target_left_hand_pos = left_shoulder + idle_left_hand_offset
	target_right_hand_pos = right_shoulder + idle_right_hand_offset
	current_left_hand_pos = target_left_hand_pos
	current_right_hand_pos = target_right_hand_pos

func _process(delta: float) -> void:
	if not _initialized or player == null:
		return

	_check_combat_animator_state()

	if is_combat_animator_active:
		return

	_update_animation_state()
	_update_animation_cycle(delta)
	_calculate_animation_targets()
	_apply_smooth_transition(delta)
	_apply_animation()

func _check_combat_animator_state() -> void:
	if combat_animator == null:
		is_combat_animator_active = false
		return

	is_combat_animator_active = combat_animator.is_playing()

	if is_combat_animator_active and current_state != AnimationState.ATTACKING:
		current_state = AnimationState.ATTACKING
		animation_state_changed.emit(current_state)

func _update_animation_state() -> void:
	var old_state = current_state
	var speed = player.velocity.length()

	## 安全获取 movement_config
	var max_speed: float = 300.0
	if player.movement_config != null:
		max_speed = player.movement_config.max_speed_ground if not player.is_flying else player.movement_config.max_speed_flight

	speed_factor = clampf(speed / max_speed, 0.0, 1.0)

	if player.is_flying:
		if speed > fast_flight_speed_threshold:
			current_state = AnimationState.FLYING_FAST
		else:
			current_state = AnimationState.FLYING
	elif speed > 150:
		current_state = AnimationState.RUNNING
	elif speed > 10:
		current_state = AnimationState.WALKING
	else:
		current_state = AnimationState.IDLE

	if old_state != current_state:
		animation_state_changed.emit(current_state)

func _update_animation_cycle(delta: float) -> void:
	var speed = player.velocity.length()

	match current_state:
		AnimationState.WALKING:
			animation_cycle += delta * animation_speed * maxf(speed / 150.0, 0.5)
		AnimationState.RUNNING:
			animation_cycle += delta * animation_speed * 1.5 * maxf(speed / 250.0, 0.5)
		AnimationState.FLYING, AnimationState.FLYING_FAST:
			animation_cycle += delta * flight_arm_wave_speed
		AnimationState.IDLE:
			animation_cycle += delta * 2.0

	## 保持周期在合理范围内
	if animation_cycle > TAU * 100:
		animation_cycle = fmod(animation_cycle, TAU)

func _calculate_animation_targets() -> void:
	match current_state:
		AnimationState.IDLE:
			_calculate_idle_animation()
		AnimationState.WALKING:
			_calculate_walk_animation()
		AnimationState.RUNNING:
			_calculate_run_animation()
		AnimationState.FLYING:
			_calculate_flight_animation()
		AnimationState.FLYING_FAST:
			_calculate_fast_flight_animation()

func _calculate_idle_animation() -> void:
	var breath_offset = sin(animation_cycle) * 1.0

	target_left_hand_pos = left_shoulder + idle_left_hand_offset + Vector2(0, breath_offset)
	target_right_hand_pos = right_shoulder + idle_right_hand_offset + Vector2(0, breath_offset)

	target_torso_rotation = 0.0
	target_torso_offset = Vector2(0, breath_offset * 0.5)
	target_head_offset = Vector2(0, breath_offset * 0.3)

func _calculate_walk_animation() -> void:
	var swing = sin(animation_cycle)
	var effective_factor = maxf(speed_factor, 0.5)
	var arm_swing = swing * walk_arm_swing_amplitude * effective_factor

	target_left_hand_pos = left_shoulder + idle_left_hand_offset + Vector2(arm_swing * 0.4, -arm_swing)
	target_right_hand_pos = right_shoulder + idle_right_hand_offset + Vector2(-arm_swing * 0.4, arm_swing)

	var torso_bob = abs(sin(animation_cycle * 2)) * walk_torso_bob_amplitude * effective_factor
	var torso_sway = swing * walk_torso_sway_amplitude * effective_factor

	target_torso_rotation = torso_sway
	target_torso_offset = Vector2(0, -torso_bob)
	target_head_offset = Vector2(0, -torso_bob * 0.5 + sin(animation_cycle) * walk_head_bob_amplitude * effective_factor * 0.3)

func _calculate_run_animation() -> void:
	var swing = sin(animation_cycle)
	var effective_factor = maxf(speed_factor, 0.6)
	var arm_swing = swing * run_arm_swing_amplitude * effective_factor

	target_left_hand_pos = left_shoulder + Vector2(-3, 10) + Vector2(arm_swing * 0.5, -arm_swing)
	target_right_hand_pos = right_shoulder + Vector2(3, 10) + Vector2(-arm_swing * 0.5, arm_swing)

	var move_dir = player.velocity.normalized() if player.velocity.length() > 10 else Vector2.ZERO
	var face_dir = player.current_facing_direction
	var forward_factor = face_dir.dot(move_dir) if move_dir.length() > 0 else 0.0

	var torso_lean = run_torso_lean_max * effective_factor * maxf(forward_factor, 0.3)
	var torso_bob = abs(sin(animation_cycle * 2)) * run_torso_bob_amplitude * effective_factor

	target_torso_rotation = torso_lean * 0.3
	target_torso_offset = Vector2(torso_lean * 5, -torso_bob)
	target_head_offset = Vector2(0, -torso_bob * 0.3)

func _calculate_flight_animation() -> void:
	var wave = sin(animation_cycle)
	var wave_offset = cos(animation_cycle * 0.7)

	var velocity_dir = player.velocity.normalized() if player.velocity.length() > 10 else Vector2.ZERO
	var face_dir = player.current_facing_direction

	var effective_factor = maxf(speed_factor, 0.4)
	var arm_spread = flight_arm_spread_angle * effective_factor
	var arm_wave = wave * flight_arm_wave_amplitude * effective_factor

	var left_arm_angle = -arm_spread - 0.4
	var left_arm_length = 22.0 + arm_wave
	target_left_hand_pos = left_shoulder + Vector2(left_arm_length, 0).rotated(left_arm_angle)

	var right_arm_angle = arm_spread + 0.4
	var right_arm_length = 22.0 - arm_wave
	target_right_hand_pos = right_shoulder + Vector2(right_arm_length, 0).rotated(right_arm_angle)

	var lateral_velocity = velocity_dir.rotated(-face_dir.angle()) if velocity_dir.length() > 0 else Vector2.ZERO
	var torso_lean = lateral_velocity.x * flight_torso_lean_factor * flight_torso_lean_max

	target_torso_rotation = clampf(torso_lean, -flight_torso_lean_max, flight_torso_lean_max)
	target_torso_offset = Vector2(0, wave_offset * 2.0 * effective_factor)
	target_head_offset = Vector2(0, wave_offset * 1.0 * effective_factor)

func _calculate_fast_flight_animation() -> void:
	var wave = sin(animation_cycle * 1.5)

	var velocity_dir = player.velocity.normalized() if player.velocity.length() > 10 else player.current_facing_direction
	var face_dir = player.current_facing_direction

	var arm_wave = wave * flight_arm_wave_amplitude * 0.5

	target_left_hand_pos = left_shoulder + Vector2(-10, 18 + arm_wave).rotated(-0.3)
	target_right_hand_pos = right_shoulder + Vector2(10, 18 - arm_wave).rotated(0.3)

	var forward_factor = face_dir.dot(velocity_dir) if velocity_dir.length() > 0 else 0.5
	var torso_lean = fast_flight_torso_lean * maxf(forward_factor, 0.5)

	var lateral_velocity = velocity_dir.rotated(-face_dir.angle()) if velocity_dir.length() > 0 else Vector2.ZERO
	var lateral_lean = lateral_velocity.x * 0.4

	target_torso_rotation = clampf(lateral_lean, -0.5, 0.5)
	target_torso_offset = Vector2(torso_lean * 10, wave * 1.5)
	target_head_offset = Vector2(torso_lean * 3, 0)

## 【修复】防止 lerp 权重超过 1.0 导致抖动
func _apply_smooth_transition(delta: float) -> void:
	var lerp_factor = minf(state_transition_speed * delta, 1.0)
	var arm_lerp_factor = minf(arm_smoothing * delta, 1.0)

	current_left_hand_pos = current_left_hand_pos.lerp(target_left_hand_pos, arm_lerp_factor)
	current_right_hand_pos = current_right_hand_pos.lerp(target_right_hand_pos, arm_lerp_factor)
	current_torso_rotation = lerpf(current_torso_rotation, target_torso_rotation, lerp_factor)
	current_torso_offset = current_torso_offset.lerp(target_torso_offset, lerp_factor)
	current_head_offset = current_head_offset.lerp(target_head_offset, lerp_factor)

func _apply_animation() -> void:
	if left_arm and not is_combat_animator_active:
		left_arm.set_hand_target(current_left_hand_pos)

	if right_arm and not is_combat_animator_active:
		right_arm.set_hand_target(current_right_hand_pos)

	## 【修复】只在 torso_pivot 存在时应用躯干动画
	if torso_pivot:
		torso_pivot.position = current_torso_offset
		## 【新增】应用躯干旋转（原代码只设置了 position 没有设置 rotation）
		torso_pivot.rotation = current_torso_rotation

	if head_sprite:
		head_sprite.position = Vector2(0, -8) + current_head_offset

func on_combat_animation_started() -> void:
	is_combat_animator_active = true
	current_state = AnimationState.ATTACKING

func on_combat_animation_finished() -> void:
	is_combat_animator_active = false

func get_current_state() -> AnimationState:
	return current_state

func get_speed_factor() -> float:
	return speed_factor

func is_movement_animation_active() -> bool:
	return not is_combat_animator_active and current_state != AnimationState.IDLE
