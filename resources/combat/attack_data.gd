class_name AttackData extends Resource

enum AttackType {
	SLASH,       ## 挥砍
	THRUST,      ## 刺击
	SPIN,        ## 旋转攻击
	SMASH,       ## 重击
	SWEEP,       ## 横扫
	REVERSE_SLASH ## 反手挥砍
}

enum InputType {
	PRIMARY,
	SECONDARY,
	COMBO
}

enum AttackDirection {
	FORWARD,     ## 正向攻击（从右向左挥）
	REVERSE,     ## 反向攻击（从左向右挥）
	THRUST_FORWARD,  ## 向前刺击
	OVERHEAD,    ## 从上向下
	UNDERHAND    ## 从下向上
}

@export_group("Basic Info")
@export var attack_name: String = "攻击"
@export var attack_type: AttackType = AttackType.SLASH
@export var input_type: InputType = InputType.PRIMARY
@export var attack_direction: AttackDirection = AttackDirection.FORWARD
@export var animation_name: StringName = &"attack"

@export_group("Timing")
@export var windup_time: float = 0.2
@export var active_time: float = 0.15
@export var recovery_time: float = 0.3
@export var cooldown: float = 0.0
@export var reposition_time_multiplier: float = 1.0  ## 武器回正时间倍率

@export_group("Damage")
@export var damage_multiplier: float = 1.0
@export var critical_chance: float = 0.0
@export var critical_multiplier: float = 1.5

@export_group("Physics")
@export var impulse_multiplier: float = 1.0
@export var knockback_multiplier: float = 1.0
@export var movement_lock: bool = false
@export var rotation_lock: bool = false

@export_group("Weapon Positioning")
@export var windup_start_position: Vector2 = Vector2(20, 0)  ## 前摇开始时武器的位置
@export var windup_start_rotation: float = -45.0            ## 前摇开始时武器的旋转角度（度）
@export var requires_repositioning: bool = true              ## 是否需要武器回正

@export_group("Combo")
@export var can_combo: bool = true
@export var combo_window: float = 0.3
@export var next_combo_index: int = -1
@export var preferred_next_direction: AttackDirection = AttackDirection.REVERSE  ## 连击时优选的下一个攻击方向

@export_group("Animation")
@export var swing_start_angle: float = -45.0
@export var swing_end_angle: float = 45.0
@export var swing_curve: Curve

@export_group("Effects")
@export var hit_effect_scene: PackedScene
@export var swing_effect_scene: PackedScene
@export var camera_shake_intensity: float = 0.0

func get_total_duration() -> float:
	return windup_time + active_time + recovery_time

func get_active_start_time() -> float:
	return windup_time

func get_active_end_time() -> float:
	return windup_time + active_time

func calculate_damage(base_damage: float) -> float:
	var damage = base_damage * damage_multiplier

	if randf() < critical_chance:
		damage *= critical_multiplier

	return damage

func get_swing_angle_at_progress(progress: float) -> float:
	var curve_value = progress
	if swing_curve != null:
		curve_value = swing_curve.sample(progress)

	return lerp(swing_start_angle, swing_end_angle, curve_value)

## 获取武器回正的目标位置
func get_reposition_target_position() -> Vector2:
	return windup_start_position

## 获取武器回正的目标旋转（弧度）
func get_reposition_target_rotation() -> float:
	return deg_to_rad(windup_start_rotation)

## 检查当前武器位置是否适合执行此攻击
func is_weapon_position_suitable(current_rotation: float, threshold_degrees: float = 30.0) -> bool:
	var target_rad = deg_to_rad(windup_start_rotation)
	var diff = abs(angle_difference(current_rotation, target_rad))
	return rad_to_deg(diff) <= threshold_degrees

## 获取此攻击的反向版本的起始角度
func get_reverse_start_angle() -> float:
	return -swing_start_angle

## 获取此攻击的反向版本的结束角度
func get_reverse_end_angle() -> float:
	return -swing_end_angle

static func create_default_slash() -> AttackData:
	var attack = AttackData.new()
	attack.attack_name = "挥砍"
	attack.attack_type = AttackType.SLASH
	attack.attack_direction = AttackDirection.FORWARD
	attack.damage_multiplier = 1.0
	attack.windup_time = 0.15
	attack.active_time = 0.1
	attack.recovery_time = 0.25
	attack.can_combo = true
	attack.swing_start_angle = -60.0
	attack.swing_end_angle = 60.0
	attack.windup_start_position = Vector2(25, -10)
	attack.windup_start_rotation = -60.0
	attack.preferred_next_direction = AttackDirection.REVERSE
	return attack

static func create_default_reverse_slash() -> AttackData:
	var attack = AttackData.new()
	attack.attack_name = "反手挥砍"
	attack.attack_type = AttackType.REVERSE_SLASH
	attack.attack_direction = AttackDirection.REVERSE
	attack.damage_multiplier = 0.9
	attack.windup_time = 0.12
	attack.active_time = 0.1
	attack.recovery_time = 0.2
	attack.can_combo = true
	attack.swing_start_angle = 60.0
	attack.swing_end_angle = -60.0
	attack.windup_start_position = Vector2(25, 10)
	attack.windup_start_rotation = 60.0
	attack.preferred_next_direction = AttackDirection.FORWARD
	return attack

static func create_default_thrust() -> AttackData:
	var attack = AttackData.new()
	attack.attack_name = "刺击"
	attack.attack_type = AttackType.THRUST
	attack.attack_direction = AttackDirection.THRUST_FORWARD
	attack.damage_multiplier = 1.2
	attack.windup_time = 0.2
	attack.active_time = 0.08
	attack.recovery_time = 0.3
	attack.can_combo = true
	attack.swing_start_angle = 0.0
	attack.swing_end_angle = 0.0
	attack.windup_start_position = Vector2(15, 0)
	attack.windup_start_rotation = 0.0
	return attack

static func create_default_smash() -> AttackData:
	var attack = AttackData.new()
	attack.attack_name = "重击"
	attack.attack_type = AttackType.SMASH
	attack.attack_direction = AttackDirection.OVERHEAD
	attack.damage_multiplier = 2.0
	attack.windup_time = 0.4
	attack.active_time = 0.15
	attack.recovery_time = 0.5
	attack.can_combo = false
	attack.impulse_multiplier = 1.5
	attack.knockback_multiplier = 2.0
	attack.swing_start_angle = -90.0
	attack.swing_end_angle = 0.0
	attack.windup_start_position = Vector2(10, -20)
	attack.windup_start_rotation = -90.0
	return attack

static func create_spear_thrust() -> AttackData:
	var attack = AttackData.new()
	attack.attack_name = "枪刺"
	attack.attack_type = AttackType.THRUST
	attack.attack_direction = AttackDirection.THRUST_FORWARD
	attack.damage_multiplier = 1.3
	attack.windup_time = 0.25
	attack.active_time = 0.1
	attack.recovery_time = 0.35
	attack.can_combo = true
	attack.swing_start_angle = 0.0
	attack.swing_end_angle = 0.0
	attack.windup_start_position = Vector2(10, 0)
	attack.windup_start_rotation = 0.0
	return attack

static func create_spear_sweep() -> AttackData:
	var attack = AttackData.new()
	attack.attack_name = "舞枪"
	attack.attack_type = AttackType.SWEEP
	attack.attack_direction = AttackDirection.FORWARD
	attack.damage_multiplier = 0.8
	attack.windup_time = 0.3
	attack.active_time = 0.25
	attack.recovery_time = 0.4
	attack.can_combo = false
	attack.swing_start_angle = -120.0
	attack.swing_end_angle = 120.0
	attack.windup_start_position = Vector2(15, -15)
	attack.windup_start_rotation = -120.0
	return attack
