# body_part_data.gd
# 肢体部件数据 - 定义角色身体的一个部分
class_name BodyPartData extends Resource

## 肢体类型枚举
enum PartType {
	HEAD,       # 头部
	TORSO,      # 躯干
	LEFT_ARM,   # 左臂
	RIGHT_ARM,  # 右臂
	LEFT_HAND,  # 左手
	RIGHT_HAND, # 右手
	LEGS,       # 腿部
	LEFT_FOOT,  # 左脚
	RIGHT_FOOT  # 右脚
}

## 部件ID
@export var part_id: String = ""

## 部件名称
@export var part_name: String = "肢体部件"

## 部件类型
@export var part_type: PartType = PartType.TORSO

## 部件描述
@export var description: String = ""

## 刻录槽列表
@export var engraving_slots: Array[EngravingSlot] = []

## 部件生命值（可选，用于肢体伤害系统）
@export var max_health: float = 100.0
@export var current_health: float = 100.0

## 部件护甲值
@export var armor: float = 0.0

## 部件是否可用
@export var is_functional: bool = true

## 获取部件类型名称
func get_type_name() -> String:
	match part_type:
		PartType.HEAD:
			return "头部"
		PartType.TORSO:
			return "躯干"
		PartType.LEFT_ARM:
			return "左臂"
		PartType.RIGHT_ARM:
			return "右臂"
		PartType.LEFT_HAND:
			return "左手"
		PartType.RIGHT_HAND:
			return "右手"
		PartType.LEGS:
			return "腿部"
		PartType.LEFT_FOOT:
			return "左脚"
		PartType.RIGHT_FOOT:
			return "右脚"
	return "未知部件"

## 初始化部件
func initialize(type: PartType, slot_count: int = 1, slot_capacity: float = 100.0) -> void:
	part_type = type
	part_name = get_type_name()
	generate_id()
	
	# 创建刻录槽
	engraving_slots.clear()
	for i in range(slot_count):
		var slot = EngravingSlot.new()
		slot.initialize(
			"%s_slot_%d" % [part_id, i],
			"%s刻录槽%d" % [part_name, i + 1],
			slot_capacity
		)
		engraving_slots.append(slot)

## 生成唯一ID
func generate_id() -> void:
	part_id = "part_%s_%d" % [PartType.keys()[part_type].to_lower(), randi()]

## 添加刻录槽
func add_engraving_slot(slot: EngravingSlot) -> void:
	if slot != null and slot not in engraving_slots:
		engraving_slots.append(slot)

## 移除刻录槽
func remove_engraving_slot(slot: EngravingSlot) -> bool:
	var index = engraving_slots.find(slot)
	if index >= 0:
		engraving_slots.remove_at(index)
		return true
	return false

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
func update_cooldowns(delta: float) -> void:
	for slot in engraving_slots:
		slot.update_cooldown(delta)

## 受到伤害
func take_damage(damage: float) -> float:
	var actual_damage = max(0, damage - armor)
	current_health = max(0, current_health - actual_damage)
	
	if current_health <= 0:
		is_functional = false
	
	return actual_damage

## 治疗
func heal(amount: float) -> float:
	var old_health = current_health
	current_health = min(max_health, current_health + amount)
	
	if current_health > 0:
		is_functional = true
	
	return current_health - old_health

## 获取部件信息
func get_info() -> String:
	var slots_info = []
	for slot in engraving_slots:
		slots_info.append(slot.get_info())
	
	return "[%s] %s (HP: %.0f/%.0f)\n  槽位:\n    %s" % [
		part_id,
		part_name,
		current_health,
		max_health,
		"\n    ".join(slots_info)
	]

## 深拷贝
func clone_deep() -> BodyPartData:
	var copy = BodyPartData.new()
	copy.part_id = part_id
	copy.part_name = part_name
	copy.part_type = part_type
	copy.description = description
	copy.max_health = max_health
	copy.current_health = current_health
	copy.armor = armor
	copy.is_functional = is_functional
	
	var slots_copy: Array[EngravingSlot] = []
	for slot in engraving_slots:
		slots_copy.append(slot.clone_deep())
	copy.engraving_slots = slots_copy
	
	return copy

## 转换为字典
func to_dict() -> Dictionary:
	var slots_array = []
	for slot in engraving_slots:
		slots_array.append(slot.to_dict())
	
	return {
		"part_id": part_id,
		"part_name": part_name,
		"part_type": part_type,
		"description": description,
		"max_health": max_health,
		"current_health": current_health,
		"armor": armor,
		"is_functional": is_functional,
		"engraving_slots": slots_array
	}

## 从字典加载
static func from_dict(data: Dictionary) -> BodyPartData:
	var part = BodyPartData.new()
	part.part_id = data.get("part_id", "")
	part.part_name = data.get("part_name", "肢体部件")
	part.part_type = data.get("part_type", PartType.TORSO)
	part.description = data.get("description", "")
	part.max_health = data.get("max_health", 100.0)
	part.current_health = data.get("current_health", 100.0)
	part.armor = data.get("armor", 0.0)
	part.is_functional = data.get("is_functional", true)
	
	var slots_data = data.get("engraving_slots", [])
	var loaded_slots: Array[EngravingSlot] = []
	for slot_data in slots_data:
		loaded_slots.append(EngravingSlot.from_dict(slot_data))
	part.engraving_slots = loaded_slots
	
	return part

## 创建默认人体部件集
static func create_default_body_parts() -> Array[BodyPartData]:
	var parts: Array[BodyPartData] = []
	
	# 头部 - 1个槽位
	var head = BodyPartData.new()
	head.initialize(PartType.HEAD, 1, 80.0)
	head.description = "头部，可刻录感知类法术"
	parts.append(head)
	
	# 躯干 - 2个槽位
	var torso = BodyPartData.new()
	torso.initialize(PartType.TORSO, 2, 150.0)
	torso.max_health = 200.0
	torso.current_health = 200.0
	torso.description = "躯干，核心部位，可刻录防御类法术"
	parts.append(torso)
	
	# 左臂 - 1个槽位
	var left_arm = BodyPartData.new()
	left_arm.initialize(PartType.LEFT_ARM, 1, 100.0)
	left_arm.description = "左臂，可刻录辅助类法术"
	parts.append(left_arm)
	
	# 右臂 - 1个槽位
	var right_arm = BodyPartData.new()
	right_arm.initialize(PartType.RIGHT_ARM, 1, 100.0)
	right_arm.description = "右臂，可刻录攻击类法术"
	parts.append(right_arm)
	
	# 左手 - 1个槽位
	var left_hand = BodyPartData.new()
	left_hand.initialize(PartType.LEFT_HAND, 1, 60.0)
	left_hand.max_health = 50.0
	left_hand.current_health = 50.0
	left_hand.description = "左手，可刻录施法增强类法术"
	parts.append(left_hand)
	
	# 右手 - 1个槽位
	var right_hand = BodyPartData.new()
	right_hand.initialize(PartType.RIGHT_HAND, 1, 60.0)
	right_hand.max_health = 50.0
	right_hand.current_health = 50.0
	right_hand.description = "右手，可刻录武器增强类法术"
	parts.append(right_hand)
	
	# 腿部 - 1个槽位
	var legs = BodyPartData.new()
	legs.initialize(PartType.LEGS, 1, 120.0)
	legs.max_health = 150.0
	legs.current_health = 150.0
	legs.description = "腿部，可刻录移动类法术"
	parts.append(legs)
	
	return parts
