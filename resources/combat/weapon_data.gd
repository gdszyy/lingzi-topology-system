# weapon_data.gd
# 武器数据资源 - 定义武器的所有属性
class_name WeaponData extends Resource

## 武器类型枚举
enum WeaponType {
	UNARMED,      # 徒手
	SWORD,        # 剑
	GREATSWORD,   # 大剑（双手）
	DUAL_BLADE,   # 双刃剑
	SPEAR,        # 矛
	DAGGER,       # 匕首
	STAFF         # 法杖
}

## 握持类型
enum GripType {
	ONE_HANDED,   # 单手
	TWO_HANDED,   # 双手
	DUAL_WIELD    # 双持
}

## 基础信息
@export_group("Basic Info")
@export var weapon_name: String = "未命名武器"
@export var weapon_type: WeaponType = WeaponType.UNARMED
@export var grip_type: GripType = GripType.ONE_HANDED
@export var description: String = ""

## 视觉配置
@export_group("Visuals")
@export var weapon_texture: Texture2D
@export var weapon_offset: Vector2 = Vector2.ZERO  # 武器相对握持点的偏移
@export var weapon_scale: Vector2 = Vector2.ONE
@export var grip_point_main: Vector2 = Vector2.ZERO  # 主手握持点
@export var grip_point_off: Vector2 = Vector2.ZERO   # 副手握持点（双手武器）

## 物理属性
@export_group("Physics")
@export var weight: float = 1.0  # 重量：影响转身速度和移动惯性
@export_range(0.0, 1.0) var inertia_factor: float = 0.5  # 惯性系数
@export var attack_impulse: float = 100.0  # 攻击时给予角色的冲量
@export var swing_arc: float = 90.0  # 挥砍弧度（度）

## 战斗属性
@export_group("Combat Stats")
@export var base_damage: float = 10.0
@export var attack_range: float = 50.0  # 攻击范围
@export var knockback_force: float = 50.0  # 击退力度

## 攻击动作配置
@export_group("Attack Actions")
@export var primary_attacks: Array[AttackData] = []   # 左键攻击序列
@export var secondary_attacks: Array[AttackData] = [] # 右键攻击序列
@export var combo_attacks: Array[AttackData] = []     # 组合攻击（同时按）

## 获取基于重量的转身速度修正
func get_turn_speed_modifier() -> float:
	# 重量越大，转身越慢
	return 1.0 / (1.0 + weight * 0.1)

## 获取基于重量的移动速度修正
func get_move_speed_modifier() -> float:
	# 重量越大，移动越慢
	return 1.0 / (1.0 + weight * 0.05)

## 获取基于重量的加速度修正
func get_acceleration_modifier() -> float:
	# 重量越大，加速越慢
	return 1.0 / (1.0 + weight * 0.08)

## 获取攻击惯性冲量
func get_attack_impulse() -> float:
	# 重量越大，攻击惯性越大
	return attack_impulse * (1.0 + weight * 0.2)

## 检查是否为双手武器
func is_two_handed() -> bool:
	return grip_type == GripType.TWO_HANDED

## 检查是否为双持武器
func is_dual_wield() -> bool:
	return grip_type == GripType.DUAL_WIELD

## 获取指定输入类型的攻击序列
func get_attacks_for_input(input_type: int) -> Array[AttackData]:
	match input_type:
		0:  # 左键
			return primary_attacks
		1:  # 右键
			return secondary_attacks
		2:  # 组合
			return combo_attacks
		_:
			return primary_attacks

## 创建默认徒手武器
static func create_unarmed() -> WeaponData:
	var weapon = WeaponData.new()
	weapon.weapon_name = "徒手"
	weapon.weapon_type = WeaponType.UNARMED
	weapon.grip_type = GripType.ONE_HANDED
	weapon.weight = 0.0
	weapon.base_damage = 5.0
	weapon.attack_range = 30.0
	
	# 创建基础拳击攻击
	var punch = AttackData.new()
	punch.attack_name = "拳击"
	punch.damage_multiplier = 1.0
	punch.windup_time = 0.1
	punch.active_time = 0.1
	punch.recovery_time = 0.2
	punch.can_combo = true
	weapon.primary_attacks = [punch]
	
	return weapon
