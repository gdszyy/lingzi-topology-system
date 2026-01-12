# attack_data.gd
# 攻击动作数据资源 - 定义单次攻击的详细参数
class_name AttackData extends Resource

## 攻击类型枚举
enum AttackType {
	SLASH,    # 挥砍
	THRUST,   # 刺击
	SPIN,     # 旋转攻击
	SMASH,    # 重击
	SWEEP     # 横扫
}

## 输入类型
enum InputType {
	PRIMARY,    # 左键
	SECONDARY,  # 右键
	COMBO       # 同时按
}

## 基础信息
@export_group("Basic Info")
@export var attack_name: String = "攻击"
@export var attack_type: AttackType = AttackType.SLASH
@export var input_type: InputType = InputType.PRIMARY
@export var animation_name: StringName = &"attack"

## 时间参数
@export_group("Timing")
@export var windup_time: float = 0.2    # 前摇时间
@export var active_time: float = 0.15   # 判定时间
@export var recovery_time: float = 0.3  # 后摇时间
@export var cooldown: float = 0.0       # 额外冷却时间

## 伤害参数
@export_group("Damage")
@export var damage_multiplier: float = 1.0  # 伤害倍率（基于武器基础伤害）
@export var critical_chance: float = 0.0    # 暴击率
@export var critical_multiplier: float = 1.5  # 暴击伤害倍率

## 物理参数
@export_group("Physics")
@export var impulse_multiplier: float = 1.0  # 冲量倍率
@export var knockback_multiplier: float = 1.0  # 击退倍率
@export var movement_lock: bool = false  # 是否锁定移动
@export var rotation_lock: bool = false  # 是否锁定旋转

## 连击配置
@export_group("Combo")
@export var can_combo: bool = true  # 是否可以连击
@export var combo_window: float = 0.3  # 连击窗口时间
@export var next_combo_index: int = -1  # 下一个连击索引（-1表示循环）

## 动画参数
@export_group("Animation")
@export var swing_start_angle: float = -45.0  # 挥动起始角度
@export var swing_end_angle: float = 45.0     # 挥动结束角度
@export var swing_curve: Curve  # 挥动曲线

## 特效
@export_group("Effects")
@export var hit_effect_scene: PackedScene  # 命中特效
@export var swing_effect_scene: PackedScene  # 挥动特效
@export var camera_shake_intensity: float = 0.0  # 屏幕震动强度

## 获取总攻击时长
func get_total_duration() -> float:
	return windup_time + active_time + recovery_time

## 获取判定帧开始时间
func get_active_start_time() -> float:
	return windup_time

## 获取判定帧结束时间
func get_active_end_time() -> float:
	return windup_time + active_time

## 计算实际伤害
func calculate_damage(base_damage: float) -> float:
	var damage = base_damage * damage_multiplier
	
	# 暴击判定
	if randf() < critical_chance:
		damage *= critical_multiplier
	
	return damage

## 获取挥动进度对应的角度
func get_swing_angle_at_progress(progress: float) -> float:
	var curve_value = progress
	if swing_curve != null:
		curve_value = swing_curve.sample(progress)
	
	return lerp(swing_start_angle, swing_end_angle, curve_value)

## 创建默认挥砍攻击
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

## 创建默认刺击攻击
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

## 创建默认重击攻击
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
