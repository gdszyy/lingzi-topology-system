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

## 刻录系统
@export_group("Engraving")
@export var engraving_slots: Array[EngravingSlot] = []  # 武器刻录槽
@export var max_engraving_capacity: float = 100.0       # 最大刻录容量

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

## 初始化刻录槽
func initialize_engraving_slots(slot_count: int = 2) -> void:
	engraving_slots.clear()
	
	# 根据武器类型设置默认槽位数和容量
	var capacity = max_engraving_capacity
	match weapon_type:
		WeaponType.UNARMED:
			slot_count = 0
			capacity = 0
		WeaponType.DAGGER:
			slot_count = 1
			capacity = 50.0
		WeaponType.SWORD, WeaponType.DUAL_BLADE:
			slot_count = 2
			capacity = 80.0
		WeaponType.GREATSWORD, WeaponType.SPEAR:
			slot_count = 3
			capacity = 120.0
		WeaponType.STAFF:
			slot_count = 4
			capacity = 150.0
	
	for i in range(slot_count):
		var slot = EngravingSlot.new()
		slot.initialize(
			"%s_slot_%d" % [weapon_name.to_lower().replace(" ", "_"), i],
			"%s刻录槽%d" % [weapon_name, i + 1],
			capacity / slot_count
		)
		# 武器槽位默认允许攻击相关触发器
		slot.allowed_triggers = [
			TriggerData.TriggerType.ON_WEAPON_HIT,
			TriggerData.TriggerType.ON_ATTACK_START,
			TriggerData.TriggerType.ON_ATTACK_ACTIVE,
			TriggerData.TriggerType.ON_ATTACK_END,
			TriggerData.TriggerType.ON_COMBO_HIT,
			TriggerData.TriggerType.ON_CRITICAL_HIT,
			TriggerData.TriggerType.ON_DEAL_DAMAGE,
			TriggerData.TriggerType.ON_KILL_ENEMY
		]
		engraving_slots.append(slot)

## 获取所有已刻录的法术
func get_engraved_spells() -> Array[SpellCoreData]:
	var spells: Array[SpellCoreData] = []
	for slot in engraving_slots:
		if slot.engraved_spell != null:
			spells.append(slot.engraved_spell)
	return spells

## 获取可触发的规则
func get_triggerable_rules(trigger_type: int) -> Array[TopologyRuleData]:
	var rules: Array[TopologyRuleData] = []
	for slot in engraving_slots:
		var slot_rules = slot.trigger(trigger_type)
		rules.append_array(slot_rules)
	return rules

## 更新所有槽位冷却
func update_engraving_cooldowns(delta: float) -> void:
	for slot in engraving_slots:
		slot.update_cooldown(delta)

## 刻录法术到指定槽位
func engrave_spell_to_slot(slot_index: int, spell: SpellCoreData) -> bool:
	if slot_index < 0 or slot_index >= engraving_slots.size():
		return false
	return engraving_slots[slot_index].engrave_spell(spell)

## 移除指定槽位的法术
func remove_spell_from_slot(slot_index: int) -> SpellCoreData:
	if slot_index < 0 or slot_index >= engraving_slots.size():
		return null
	return engraving_slots[slot_index].remove_spell()

## 获取刻录槽数量
func get_engraving_slot_count() -> int:
	return engraving_slots.size()

## 获取已使用的刻录容量
func get_used_engraving_capacity() -> float:
	var used = 0.0
	for slot in engraving_slots:
		if slot.engraved_spell != null:
			used += slot.engraved_spell.calculate_total_instability()
	return used

## 创建默认徒手武器
static func create_unarmed() -> WeaponData:
	var weapon = WeaponData.new()
	weapon.weapon_name = "徒手"
	weapon.weapon_type = WeaponType.UNARMED
	weapon.grip_type = GripType.ONE_HANDED
	weapon.weight = 0.0
	weapon.base_damage = 5.0
	weapon.attack_range = 30.0
	weapon.max_engraving_capacity = 0.0
	
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
