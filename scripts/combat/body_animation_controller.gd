class_name BodyAnimationController extends Node
## 全身骨骼动画控制器
## 管理移动和飞行时的全身动画效果
## 包括手臂摆动、躯干倾斜、头部摆动等
## 【重要】不影响攻击动画 - 攻击时由 CombatAnimator 接管

signal animation_state_changed(state: AnimationState)

## 动画状态枚举
enum AnimationState {
	IDLE,           ## 待机
	WALKING,        ## 行走
	RUNNING,        ## 奔跑
	FLYING,         ## 飞行
	FLYING_FAST,    ## 高速飞行
	ATTACKING       ## 攻击中（由 CombatAnimator 控制）
}

## 引用
var player: PlayerController = null
var left_arm: ArmRig = null
var right_arm: ArmRig = null
var torso_pivot: Node2D = null
var head_sprite: Sprite2D = null
var legs_pivot: Node2D = null

## 当前状态
var current_state: AnimationState = AnimationState.IDLE
var is_combat_animator_active: bool = false  ## CombatAnimator 是否正在播放攻击动画

## 动画周期
var animation_cycle: float = 0.0
var animation_speed: float = 10.0

## 配置参数
@export_group("Walk Animation")
@export var walk_arm_swing_amplitude: float = 12.0      ## 行走手臂摆动幅度
@export var walk_torso_bob_amplitude: float = 2.0       ## 行走躯干上下摆动幅度
@export var walk_torso_sway_amplitude: float = 0.05     ## 行走躯干左右摇摆幅度（弧度）
@export var walk_head_bob_amplitude: float = 1.0        ## 行走头部摆动幅度

@export_group("Run Animation")
@export var run_arm_swing_amplitude: float = 18.0       ## 奔跑手臂摆动幅度
@export var run_torso_bob_amplitude: float = 3.0        ## 奔跑躯干上下摆动幅度
@export var run_torso_lean_max: float = 0.15            ## 奔跑躯干前倾最大角度（弧度）
@export var run_head_bob_amplitude: float = 1.5         ## 奔跑头部摆动幅度

@export_group("Flight Animation")
@export var flight_arm_spread_angle: float = 0.8        ## 飞行手臂展开角度（弧度）
@export var flight_arm_wave_amplitude: float = 8.0      ## 飞行手臂波动幅度
@export var flight_arm_wave_speed: float = 3.0          ## 飞行手臂波动速度
@export var flight_torso_lean_factor: float = 0.2       ## 飞行躯干倾斜因子
@export var flight_torso_lean_max: float = 0.4          ## 飞行躯干最大倾斜角度（弧度）
@export var flight_head_tilt_factor: float = 0.1        ## 飞行头部倾斜因子

@export_group("Fast Flight Animation")
@export var fast_flight_arm_back_angle: float = 1.2     ## 高速飞行手臂后掠角度
@export var fast_flight_torso_lean: float = 0.5         ## 高速飞行躯干前倾角度
@export var fast_flight_speed_threshold: float = 350.0  ## 高速飞行速度阈值

@export_group("Transition")
@export var state_transition_speed: float = 8.0         ## 状态过渡速度
@export var arm_smoothing: float = 12.0                 ## 手臂平滑度

## 肩膀位置
var left_shoulder: Vector2 = Vector2(-12, 0)
var right_shoulder: Vector2 = Vector2(12, 0)

## 待机手臂位置
var idle_left_hand_offset: Vector2 = Vector2(-5, 18)
var idle_right_hand_offset: Vector2 = Vector2(5, 18)

## 当前动画目标值（用于平滑过渡）
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
var speed_factor: float = 0.0  ## 0-1，表示当前速度占最大速度的比例

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

func _initialize_positions() -> void:
	target_left_hand_pos = left_shoulder + idle_left_hand_offset
	target_right_hand_pos = right_shoulder + idle_right_hand_offset
	current_left_hand_pos = target_left_hand_pos
	current_right_hand_pos = target_right_hand_pos

func _process(delta: float) -> void:
	if player == null:
		return
	
	## 检查是否在攻击状态
	_check_combat_animator_state()
	
	## 如果 CombatAnimator 正在控制，不更新移动/飞行动画
	if is_combat_animator_active:
		return
	
	## 更新动画状态
	_update_animation_state()
	
	## 更新动画周期
	_update_animation_cycle(delta)
	
	## 根据状态计算目标动画值
	_calculate_animation_targets()
	
	## 平滑过渡到目标值
	_apply_smooth_transition(delta)
	
	## 应用动画到骨骼
	_apply_animation()

func _check_combat_animator_state() -> void:
	## 检查 CombatAnimator 是否正在播放攻击动画
	var visuals = player.visuals as PlayerVisuals
	if visuals == null:
		is_combat_animator_active = false
		return
	
	var combat_animator = visuals.get_combat_animator()
	if combat_animator == null:
		is_combat_animator_active = false
		return
	
	## 检查是否正在播放攻击动画
	is_combat_animator_active = combat_animator.is_playing()
	
	if is_combat_animator_active and current_state != AnimationState.ATTACKING:
		current_state = AnimationState.ATTACKING
		animation_state_changed.emit(current_state)

func _update_animation_state() -> void:
	var old_state = current_state
	var speed = player.velocity.length()
	var max_speed = player.movement_config.max_speed_ground if not player.is_flying else player.movement_config.max_speed_flight
	
	## 计算速度因子
	speed_factor = clamp(speed / max_speed, 0.0, 1.0)
	
	if player.is_flying:
		if speed > fast_flight_speed_threshold:
			current_state = AnimationState.FLYING_FAST
		else:
			current_state = AnimationState.FLYING
	elif speed > 200:
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
			animation_cycle += delta * animation_speed * (speed / 200.0)
		AnimationState.RUNNING:
			animation_cycle += delta * animation_speed * 1.5 * (speed / 300.0)
		AnimationState.FLYING, AnimationState.FLYING_FAST:
			animation_cycle += delta * flight_arm_wave_speed
		AnimationState.IDLE:
			## 待机时有轻微的呼吸动画
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
	## 待机状态：轻微的呼吸动画
	var breath_offset = sin(animation_cycle) * 0.5
	
	target_left_hand_pos = left_shoulder + idle_left_hand_offset + Vector2(0, breath_offset)
	target_right_hand_pos = right_shoulder + idle_right_hand_offset + Vector2(0, breath_offset)
	
	target_torso_rotation = 0.0
	target_torso_offset = Vector2(0, breath_offset * 0.5)
	target_head_offset = Vector2(0, breath_offset * 0.3)

func _calculate_walk_animation() -> void:
	## 行走动画：手臂交替摆动
	var swing = sin(animation_cycle)
	var swing_offset = cos(animation_cycle)
	
	## 手臂摆动（左右手相位相反）
	var arm_swing = swing * walk_arm_swing_amplitude * speed_factor
	
	## 左手向前时右手向后
	target_left_hand_pos = left_shoulder + idle_left_hand_offset + Vector2(arm_swing * 0.3, -arm_swing)
	target_right_hand_pos = right_shoulder + idle_right_hand_offset + Vector2(-arm_swing * 0.3, arm_swing)
	
	## 躯干上下摆动和轻微左右摇摆
	var torso_bob = abs(sin(animation_cycle * 2)) * walk_torso_bob_amplitude * speed_factor
	var torso_sway = swing * walk_torso_sway_amplitude * speed_factor
	
	target_torso_rotation = torso_sway
	target_torso_offset = Vector2(0, -torso_bob)
	
	## 头部轻微摆动
	target_head_offset = Vector2(0, -torso_bob * 0.5 + sin(animation_cycle) * walk_head_bob_amplitude * speed_factor * 0.3)

func _calculate_run_animation() -> void:
	## 奔跑动画：更大幅度的手臂摆动和躯干前倾
	var swing = sin(animation_cycle)
	
	## 手臂大幅摆动
	var arm_swing = swing * run_arm_swing_amplitude * speed_factor
	
	## 奔跑时手臂弯曲更多，位置更靠近身体
	target_left_hand_pos = left_shoulder + Vector2(-3, 12) + Vector2(arm_swing * 0.4, -arm_swing)
	target_right_hand_pos = right_shoulder + Vector2(3, 12) + Vector2(-arm_swing * 0.4, arm_swing)
	
	## 躯干前倾（根据移动方向）
	var move_dir = player.velocity.normalized()
	var face_dir = player.current_facing_direction
	var forward_factor = face_dir.dot(move_dir)
	
	var torso_lean = run_torso_lean_max * speed_factor * max(forward_factor, 0.3)
	var torso_bob = abs(sin(animation_cycle * 2)) * run_torso_bob_amplitude * speed_factor
	
	target_torso_rotation = torso_lean * 0.3  ## 轻微的侧向倾斜
	target_torso_offset = Vector2(torso_lean * 5, -torso_bob)
	
	## 头部保持稳定但有轻微摆动
	target_head_offset = Vector2(0, -torso_bob * 0.3)

func _calculate_flight_animation() -> void:
	## 飞行动画：手臂展开，随风波动
	var wave = sin(animation_cycle)
	var wave_offset = cos(animation_cycle * 0.7)
	
	## 计算飞行方向相关的倾斜
	var velocity_dir = player.velocity.normalized() if player.velocity.length() > 10 else Vector2.ZERO
	var face_dir = player.current_facing_direction
	
	## 手臂向两侧展开，带有波动效果
	var arm_spread = flight_arm_spread_angle * speed_factor
	var arm_wave = wave * flight_arm_wave_amplitude * speed_factor
	
	## 左臂向左后方展开
	var left_arm_angle = -arm_spread - 0.3
	var left_arm_length = 20.0 + arm_wave
	target_left_hand_pos = left_shoulder + Vector2(left_arm_length, 0).rotated(left_arm_angle)
	
	## 右臂向右后方展开
	var right_arm_angle = arm_spread + 0.3
	var right_arm_length = 20.0 - arm_wave  ## 相位相反
	target_right_hand_pos = right_shoulder + Vector2(right_arm_length, 0).rotated(right_arm_angle)
	
	## 躯干根据飞行方向倾斜
	var lateral_velocity = velocity_dir.rotated(-face_dir.angle())
	var torso_lean = lateral_velocity.x * flight_torso_lean_factor * flight_torso_lean_max
	
	target_torso_rotation = clamp(torso_lean, -flight_torso_lean_max, flight_torso_lean_max)
	target_torso_offset = Vector2(0, wave_offset * 1.5 * speed_factor)
	
	## 头部轻微倾斜
	target_head_offset = Vector2(0, wave_offset * 0.5)

func _calculate_fast_flight_animation() -> void:
	## 高速飞行动画：手臂向后掠，身体大幅前倾
	var wave = sin(animation_cycle * 1.5)
	
	## 计算飞行方向
	var velocity_dir = player.velocity.normalized() if player.velocity.length() > 10 else player.current_facing_direction
	var face_dir = player.current_facing_direction
	
	## 手臂向后掠，贴近身体
	var arm_back_angle = fast_flight_arm_back_angle
	var arm_wave = wave * flight_arm_wave_amplitude * 0.5  ## 高速时波动减小
	
	## 左臂向后
	target_left_hand_pos = left_shoulder + Vector2(-8, 15 + arm_wave).rotated(-0.2)
	
	## 右臂向后
	target_right_hand_pos = right_shoulder + Vector2(8, 15 - arm_wave).rotated(0.2)
	
	## 躯干大幅前倾
	var forward_factor = face_dir.dot(velocity_dir)
	var torso_lean = fast_flight_torso_lean * max(forward_factor, 0.5)
	
	## 侧向速度导致的倾斜
	var lateral_velocity = velocity_dir.rotated(-face_dir.angle())
	var lateral_lean = lateral_velocity.x * 0.3
	
	target_torso_rotation = clamp(lateral_lean, -0.4, 0.4)
	target_torso_offset = Vector2(torso_lean * 8, wave * 1.0)
	
	## 头部保持向前
	target_head_offset = Vector2(torso_lean * 2, 0)

func _apply_smooth_transition(delta: float) -> void:
	var lerp_factor = state_transition_speed * delta
	var arm_lerp_factor = arm_smoothing * delta
	
	current_left_hand_pos = current_left_hand_pos.lerp(target_left_hand_pos, arm_lerp_factor)
	current_right_hand_pos = current_right_hand_pos.lerp(target_right_hand_pos, arm_lerp_factor)
	current_torso_rotation = lerp(current_torso_rotation, target_torso_rotation, lerp_factor)
	current_torso_offset = current_torso_offset.lerp(target_torso_offset, lerp_factor)
	current_head_offset = current_head_offset.lerp(target_head_offset, lerp_factor)

func _apply_animation() -> void:
	## 应用手臂动画
	if left_arm and not is_combat_animator_active:
		left_arm.set_hand_target(current_left_hand_pos)
	
	if right_arm and not is_combat_animator_active:
		right_arm.set_hand_target(current_right_hand_pos)
	
	## 应用躯干动画（注意：这里只应用额外的偏移，不覆盖玩家控制的旋转）
	## 躯干的主旋转由 PlayerController 控制，这里只添加动画效果
	
	## 应用头部动画
	if head_sprite:
		head_sprite.position = Vector2(0, -8) + current_head_offset

## 当 CombatAnimator 开始播放时调用
func on_combat_animation_started() -> void:
	is_combat_animator_active = true
	current_state = AnimationState.ATTACKING

## 当 CombatAnimator 结束播放时调用
func on_combat_animation_finished() -> void:
	is_combat_animator_active = false
	## 状态会在下一帧自动更新

## 获取当前动画状态
func get_current_state() -> AnimationState:
	return current_state

## 获取当前速度因子
func get_speed_factor() -> float:
	return speed_factor

## 检查是否正在播放移动/飞行动画
func is_movement_animation_active() -> bool:
	return not is_combat_animator_active and current_state != AnimationState.IDLE
