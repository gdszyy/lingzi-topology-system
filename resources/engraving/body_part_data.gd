class_name BodyPartData extends Resource

## 肢体部件数据
## 二维体素战斗系统的核心组件，每个肢体是一个可独立损伤的"体素"
## 当肢体被摧毁时，其上篆刻的所有法术将失效

signal health_changed(current: float, maximum: float)
signal destroyed(part: BodyPartData)
signal restored(part: BodyPartData)
signal damage_taken(damage: float, remaining_health: float)

enum PartType {
	HEAD,
	TORSO,
	LEFT_ARM,
	RIGHT_ARM,
	LEFT_HAND,
	RIGHT_HAND,
	LEGS,
	LEFT_FOOT,
	RIGHT_FOOT
}

## 肢体损伤状态
enum DamageState {
	HEALTHY,      # 健康 (100% - 75%)
	DAMAGED,      # 受损 (75% - 50%)
	CRITICAL,     # 重伤 (50% - 25%)
	CRIPPLED,     # 残废 (25% - 1%)
	DESTROYED     # 摧毁 (0%)
}

@export var part_id: String = ""

@export var part_name: String = "肢体部件"

@export var part_type: PartType = PartType.TORSO

@export var description: String = ""

@export var engraving_slots: Array[EngravingSlot] = []

@export var max_health: float = 100.0
@export var current_health: float = 100.0

@export var armor: float = 0.0

@export var is_functional: bool = true

## 肢体被摧毁后对核心造成的伤害比例
@export var core_damage_ratio: float = 0.3

## 肢体是否为关键部位（关键部位被摧毁会导致角色死亡）
@export var is_vital: bool = false

## 当前损伤状态
var damage_state: DamageState = DamageState.HEALTHY

## 肢体效率（受损伤状态影响，影响篆刻法术的效果）
var efficiency: float = 1.0

## 记录总承受伤害
var total_damage_taken: float = 0.0

## 记录被摧毁次数
var destruction_count: int = 0

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

func get_damage_state_name() -> String:
	match damage_state:
		DamageState.HEALTHY:
			return "健康"
		DamageState.DAMAGED:
			return "受损"
		DamageState.CRITICAL:
			return "重伤"
		DamageState.CRIPPLED:
			return "残废"
		DamageState.DESTROYED:
			return "摧毁"
	return "未知"

func initialize(type: PartType, slot_count: int = 1, slot_capacity: float = 100.0) -> void:
	part_type = type
	part_name = get_type_name()
	generate_id()
	
	# 设置关键部位标志
	is_vital = (type == PartType.HEAD or type == PartType.TORSO)
	
	# 根据部位类型设置核心伤害比例
	match type:
		PartType.HEAD:
			core_damage_ratio = 0.5  # 头部受伤传递更多伤害
		PartType.TORSO:
			core_damage_ratio = 0.7  # 躯干是核心，传递大量伤害
		PartType.LEFT_ARM, PartType.RIGHT_ARM:
			core_damage_ratio = 0.2
		PartType.LEFT_HAND, PartType.RIGHT_HAND:
			core_damage_ratio = 0.1
		PartType.LEGS:
			core_damage_ratio = 0.3
		PartType.LEFT_FOOT, PartType.RIGHT_FOOT:
			core_damage_ratio = 0.1

	engraving_slots.clear()
	for i in range(slot_count):
		var slot = EngravingSlot.new()
		slot.initialize(
			"%s_slot_%d" % [part_id, i],
			"%s刻录槽%d" % [part_name, i + 1],
			slot_capacity
		)
		engraving_slots.append(slot)

func generate_id() -> void:
	part_id = "part_%s_%d" % [PartType.keys()[part_type].to_lower(), randi()]

func add_engraving_slot(slot: EngravingSlot) -> void:
	if slot != null and slot not in engraving_slots:
		engraving_slots.append(slot)

func remove_engraving_slot(slot: EngravingSlot) -> bool:
	var index = engraving_slots.find(slot)
	if index >= 0:
		engraving_slots.remove_at(index)
		return true
	return false

func get_engraved_spells() -> Array[SpellCoreData]:
	var spells: Array[SpellCoreData] = []
	# 只有功能完好的肢体才能返回篆刻法术
	if not is_functional:
		return spells
	for slot in engraving_slots:
		if slot.engraved_spell != null:
			spells.append(slot.engraved_spell)
	return spells

func get_triggerable_rules(trigger_type: int) -> Array[TopologyRuleData]:
	var rules: Array[TopologyRuleData] = []
	# 只有功能完好的肢体才能触发法术
	if not is_functional:
		return rules
	for slot in engraving_slots:
		var slot_rules = slot.trigger(trigger_type)
		rules.append_array(slot_rules)
	return rules

func update_cooldowns(delta: float) -> void:
	for slot in engraving_slots:
		slot.update_cooldown(delta)

## 承受伤害（二维体素战斗系统核心方法）
## 返回实际造成的伤害值
func take_damage(damage: float) -> float:
	if not is_functional:
		# 已摧毁的肢体不再承受伤害
		return 0.0
	
	var actual_damage = max(0, damage - armor)
	var old_health = current_health
	current_health = max(0, current_health - actual_damage)
	total_damage_taken += actual_damage
	
	# 更新损伤状态
	_update_damage_state()
	
	# 发送伤害信号
	damage_taken.emit(actual_damage, current_health)
	health_changed.emit(current_health, max_health)
	
	# 检查是否被摧毁
	if current_health <= 0 and old_health > 0:
		_on_destroyed()
	
	return actual_damage

## 治疗肢体
func heal(amount: float) -> float:
	var old_health = current_health
	var was_destroyed = not is_functional
	
	current_health = min(max_health, current_health + amount)
	
	# 更新损伤状态
	_update_damage_state()
	
	# 如果从摧毁状态恢复
	if was_destroyed and current_health > 0:
		_on_restored()
	
	health_changed.emit(current_health, max_health)
	
	return current_health - old_health

## 完全修复肢体
func fully_restore() -> void:
	var was_destroyed = not is_functional
	current_health = max_health
	is_functional = true
	damage_state = DamageState.HEALTHY
	efficiency = 1.0
	
	if was_destroyed:
		restored.emit(self)
	
	health_changed.emit(current_health, max_health)

## 更新损伤状态
func _update_damage_state() -> void:
	var health_ratio = current_health / max_health if max_health > 0 else 0
	
	if health_ratio <= 0:
		damage_state = DamageState.DESTROYED
		efficiency = 0.0
		is_functional = false
	elif health_ratio <= 0.25:
		damage_state = DamageState.CRIPPLED
		efficiency = 0.25
	elif health_ratio <= 0.5:
		damage_state = DamageState.CRITICAL
		efficiency = 0.5
	elif health_ratio <= 0.75:
		damage_state = DamageState.DAMAGED
		efficiency = 0.75
	else:
		damage_state = DamageState.HEALTHY
		efficiency = 1.0
		is_functional = true

## 肢体被摧毁时的处理
func _on_destroyed() -> void:
	is_functional = false
	damage_state = DamageState.DESTROYED
	efficiency = 0.0
	destruction_count += 1
	
	# 禁用所有篆刻槽
	for slot in engraving_slots:
		slot.is_enabled = false
	
	destroyed.emit(self)
	print("[肢体摧毁] %s 已被摧毁！其上的 %d 个法术已失效。" % [part_name, engraving_slots.size()])

## 肢体恢复时的处理
func _on_restored() -> void:
	is_functional = true
	
	# 重新启用所有篆刻槽
	for slot in engraving_slots:
		slot.is_enabled = true
	
	restored.emit(self)
	print("[肢体恢复] %s 已恢复功能！其上的法术重新生效。" % [part_name])

## 获取健康百分比
func get_health_percent() -> float:
	return current_health / max_health if max_health > 0 else 0.0

## 检查肢体是否可以使用篆刻法术
func can_use_engravings() -> bool:
	return is_functional and efficiency > 0

## 获取肢体效率修正后的效果倍率
func get_effect_multiplier() -> float:
	return efficiency

## 获取肢体详细信息
func get_info() -> String:
	var slots_info = []
	for slot in engraving_slots:
		slots_info.append(slot.get_info())
	
	var status = "功能正常" if is_functional else "已摧毁"
	
	return "[%s] %s (HP: %.0f/%.0f) [%s - %s]\n  效率: %.0f%%\n  槽位:\n    %s" % [
		part_id,
		part_name,
		current_health,
		max_health,
		get_damage_state_name(),
		status,
		efficiency * 100,
		"\n    ".join(slots_info)
	]

## 获取简短状态信息
func get_status_summary() -> String:
	var spell_count = 0
	for slot in engraving_slots:
		if slot.engraved_spell != null:
			spell_count += 1
	
	return "%s: %.0f%% [%s] (%d法术)" % [
		part_name,
		get_health_percent() * 100,
		get_damage_state_name(),
		spell_count
	]

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
	copy.core_damage_ratio = core_damage_ratio
	copy.is_vital = is_vital
	copy.damage_state = damage_state
	copy.efficiency = efficiency
	copy.total_damage_taken = total_damage_taken
	copy.destruction_count = destruction_count

	var slots_copy: Array[EngravingSlot] = []
	for slot in engraving_slots:
		slots_copy.append(slot.clone_deep())
	copy.engraving_slots = slots_copy

	return copy

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
		"core_damage_ratio": core_damage_ratio,
		"is_vital": is_vital,
		"damage_state": damage_state,
		"efficiency": efficiency,
		"total_damage_taken": total_damage_taken,
		"destruction_count": destruction_count,
		"engraving_slots": slots_array
	}

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
	part.core_damage_ratio = data.get("core_damage_ratio", 0.3)
	part.is_vital = data.get("is_vital", false)
	part.damage_state = data.get("damage_state", DamageState.HEALTHY)
	part.efficiency = data.get("efficiency", 1.0)
	part.total_damage_taken = data.get("total_damage_taken", 0.0)
	part.destruction_count = data.get("destruction_count", 0)

	var slots_data = data.get("engraving_slots", [])
	var loaded_slots: Array[EngravingSlot] = []
	for slot_data in slots_data:
		loaded_slots.append(EngravingSlot.from_dict(slot_data))
	part.engraving_slots = loaded_slots

	return part

static func create_default_body_parts() -> Array[BodyPartData]:
	var parts: Array[BodyPartData] = []

	var head = BodyPartData.new()
	head.initialize(PartType.HEAD, 1, 80.0)
	head.max_health = 80.0
	head.current_health = 80.0
	head.description = "头部，可刻录感知类法术。关键部位，被摧毁将导致死亡。"
	parts.append(head)

	var torso = BodyPartData.new()
	torso.initialize(PartType.TORSO, 2, 150.0)
	torso.max_health = 200.0
	torso.current_health = 200.0
	torso.armor = 5.0
	torso.description = "躯干，核心部位，可刻录防御类法术。关键部位，被摧毁将导致死亡。"
	parts.append(torso)

	var left_arm = BodyPartData.new()
	left_arm.initialize(PartType.LEFT_ARM, 1, 100.0)
	left_arm.max_health = 100.0
	left_arm.current_health = 100.0
	left_arm.description = "左臂，可刻录辅助类法术。被摧毁后无法使用副手武器。"
	parts.append(left_arm)

	var right_arm = BodyPartData.new()
	right_arm.initialize(PartType.RIGHT_ARM, 1, 100.0)
	right_arm.max_health = 100.0
	right_arm.current_health = 100.0
	right_arm.description = "右臂，可刻录攻击类法术。被摧毁后无法使用主手武器。"
	parts.append(right_arm)

	var left_hand = BodyPartData.new()
	left_hand.initialize(PartType.LEFT_HAND, 1, 60.0)
	left_hand.max_health = 50.0
	left_hand.current_health = 50.0
	left_hand.description = "左手，可刻录施法增强类法术。被摧毁后施法速度降低。"
	parts.append(left_hand)

	var right_hand = BodyPartData.new()
	right_hand.initialize(PartType.RIGHT_HAND, 1, 60.0)
	right_hand.max_health = 50.0
	right_hand.current_health = 50.0
	right_hand.description = "右手，可刻录武器增强类法术。被摧毁后攻击伤害降低。"
	parts.append(right_hand)

	var legs = BodyPartData.new()
	legs.initialize(PartType.LEGS, 1, 120.0)
	legs.max_health = 150.0
	legs.current_health = 150.0
	legs.description = "腿部，可刻录移动类法术。被摧毁后移动速度大幅降低，无法飞行。"
	parts.append(legs)

	return parts
