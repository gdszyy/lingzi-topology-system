class_name AttackData extends Resource

enum AttackType {
	SLASH,
	THRUST,
	SPIN,
	SMASH,
	SWEEP
}

enum InputType {
	PRIMARY,
	SECONDARY,
	COMBO
}

@export_group("Basic Info")
@export var attack_name: String = "攻击"
@export var attack_type: AttackType = AttackType.SLASH
@export var input_type: InputType = InputType.PRIMARY
@export var animation_name: StringName = &"attack"

@export_group("Timing")
@export var windup_time: float = 0.2
@export var active_time: float = 0.15
@export var recovery_time: float = 0.3
@export var cooldown: float = 0.0

@export_group("Damage")
@export var damage_multiplier: float = 1.0
@export var critical_chance: float = 0.0
@export var critical_multiplier: float = 1.5

@export_group("Physics")
@export var impulse_multiplier: float = 1.0
@export var knockback_multiplier: float = 1.0
@export var movement_lock: bool = false
@export var rotation_lock: bool = false

@export_group("Combo")
@export var can_combo: bool = true
@export var combo_window: float = 0.3
@export var next_combo_index: int = -1

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

static func create_default_slash() -> AttackData:
	var attack = AttackData.new()
	attack.attack_name = "挥砍"
	attack.attack_type = AttackType.SLASH
	attack.damage_multiplier = 1.0
	attack.windup_time = 0.15
	attack.active_time = 0.1
	attack.recovery_time = 0.25
	attack.can_combo = true
	attack.swing_start_angle = -60.0
	attack.swing_end_angle = 60.0
	return attack

static func create_default_thrust() -> AttackData:
	var attack = AttackData.new()
	attack.attack_name = "刺击"
	attack.attack_type = AttackType.THRUST
	attack.damage_multiplier = 1.2
	attack.windup_time = 0.2
	attack.active_time = 0.08
	attack.recovery_time = 0.3
	attack.can_combo = true
	attack.swing_start_angle = 0.0
	attack.swing_end_angle = 0.0
	return attack

static func create_default_smash() -> AttackData:
	var attack = AttackData.new()
	attack.attack_name = "重击"
	attack.attack_type = AttackType.SMASH
	attack.damage_multiplier = 2.0
	attack.windup_time = 0.4
	attack.active_time = 0.15
	attack.recovery_time = 0.5
	attack.can_combo = false
	attack.impulse_multiplier = 1.5
	attack.knockback_multiplier = 2.0
	attack.swing_start_angle = -90.0
	attack.swing_end_angle = 0.0
	return attack
