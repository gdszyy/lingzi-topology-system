class_name BodyPartData extends Resource

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

@export var part_id: String = ""

@export var part_name: String = "肢体部件"

@export var part_type: PartType = PartType.TORSO

@export var description: String = ""

@export var engraving_slots: Array[EngravingSlot] = []

@export var max_health: float = 100.0
@export var current_health: float = 100.0

@export var armor: float = 0.0

@export var is_functional: bool = true

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

func initialize(type: PartType, slot_count: int = 1, slot_capacity: float = 100.0) -> void:
	part_type = type
	part_name = get_type_name()
	generate_id()

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
	for slot in engraving_slots:
		if slot.engraved_spell != null:
			spells.append(slot.engraved_spell)
	return spells

func get_triggerable_rules(trigger_type: int) -> Array[TopologyRuleData]:
	var rules: Array[TopologyRuleData] = []
	for slot in engraving_slots:
		var slot_rules = slot.trigger(trigger_type)
		rules.append_array(slot_rules)
	return rules

func update_cooldowns(delta: float) -> void:
	for slot in engraving_slots:
		slot.update_cooldown(delta)

func take_damage(damage: float) -> float:
	var actual_damage = max(0, damage - armor)
	current_health = max(0, current_health - actual_damage)

	if current_health <= 0:
		is_functional = false

	return actual_damage

func heal(amount: float) -> float:
	var old_health = current_health
	current_health = min(max_health, current_health + amount)

	if current_health > 0:
		is_functional = true

	return current_health - old_health

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

static func create_default_body_parts() -> Array[BodyPartData]:
	var parts: Array[BodyPartData] = []

	var head = BodyPartData.new()
	head.initialize(PartType.HEAD, 1, 80.0)
	head.description = "头部，可刻录感知类法术"
	parts.append(head)

	var torso = BodyPartData.new()
	torso.initialize(PartType.TORSO, 2, 150.0)
	torso.max_health = 200.0
	torso.current_health = 200.0
	torso.description = "躯干，核心部位，可刻录防御类法术"
	parts.append(torso)

	var left_arm = BodyPartData.new()
	left_arm.initialize(PartType.LEFT_ARM, 1, 100.0)
	left_arm.description = "左臂，可刻录辅助类法术"
	parts.append(left_arm)

	var right_arm = BodyPartData.new()
	right_arm.initialize(PartType.RIGHT_ARM, 1, 100.0)
	right_arm.description = "右臂，可刻录攻击类法术"
	parts.append(right_arm)

	var left_hand = BodyPartData.new()
	left_hand.initialize(PartType.LEFT_HAND, 1, 60.0)
	left_hand.max_health = 50.0
	left_hand.current_health = 50.0
	left_hand.description = "左手，可刻录施法增强类法术"
	parts.append(left_hand)

	var right_hand = BodyPartData.new()
	right_hand.initialize(PartType.RIGHT_HAND, 1, 60.0)
	right_hand.max_health = 50.0
	right_hand.current_health = 50.0
	right_hand.description = "右手，可刻录武器增强类法术"
	parts.append(right_hand)

	var legs = BodyPartData.new()
	legs.initialize(PartType.LEGS, 1, 120.0)
	legs.max_health = 150.0
	legs.current_health = 150.0
	legs.description = "腿部，可刻录移动类法术"
	parts.append(legs)

	return parts
