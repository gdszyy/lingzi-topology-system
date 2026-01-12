class_name EngravingSlot extends Resource

signal spell_engraved(spell: SpellCoreData)
signal spell_removed(spell: SpellCoreData)
signal spell_triggered(spell: SpellCoreData, trigger_type: int)
signal windup_started(spell: SpellCoreData, windup_time: float)
signal windup_completed(spell: SpellCoreData)

@export var slot_id: String = ""

@export var slot_name: String = "刻录槽"

@export var description: String = ""

@export var engraved_spell: SpellCoreData = null

@export var is_locked: bool = false

@export var is_enabled: bool = true

@export var allowed_triggers: Array[int] = []

@export var slot_level: int = 1

@export var slot_capacity: float = 100.0

@export var cooldown: float = 0.0

@export var engraving_windup_multiplier: float = 0.2

var cooldown_timer: float = 0.0

var windup_timer: float = 0.0

var is_winding_up: bool = false

var pending_trigger_type: int = -1

var pending_context: Dictionary = {}

var trigger_count: int = 0

## 武器特质修正器（由外部设置）
var weapon_modifier: WeaponTraitModifier = null

## 连续触发计数
var consecutive_trigger_count: int = 0

## 上次触发时间
var last_trigger_time: float = 0.0

## 连续触发窗口时间（秒）
const CHAIN_TRIGGER_WINDOW: float = 2.0

func initialize(id: String, name: String, capacity: float = 100.0) -> void:
	slot_id = id
	slot_name = name
	slot_capacity = capacity
	generate_id()

## 设置武器特质修正器
func set_weapon_modifier(modifier: WeaponTraitModifier) -> void:
	weapon_modifier = modifier

func generate_id() -> void:
	if slot_id.is_empty():
		slot_id = "slot_%d_%d" % [Time.get_unix_time_from_system(), randi()]

func engrave_spell(spell: SpellCoreData) -> bool:
	if is_locked:
		push_warning("槽位已锁定，无法刻录")
		return false

	if spell == null:
		push_warning("法术为空")
		return false

	var complexity = spell.calculate_total_instability()
	if complexity > slot_capacity:
		push_warning("法术复杂度 %.1f 超过槽位容量 %.1f" % [complexity, slot_capacity])
		return false

	if not _check_triggers_allowed(spell):
		push_warning("法术包含不允许的触发器类型")
		return false

	var old_spell = engraved_spell
	if old_spell != null:
		spell_removed.emit(old_spell)

	engraved_spell = spell.clone_deep()
	engraved_spell.is_engraved = true
	engraved_spell.engraving_slot_id = slot_id

	spell_engraved.emit(engraved_spell)

	return true

func remove_spell() -> SpellCoreData:
	if is_locked:
		push_warning("槽位已锁定，无法移除")
		return null

	var removed = engraved_spell
	if removed != null:
		removed.is_engraved = false
		removed.engraving_slot_id = ""
		engraved_spell = null
		spell_removed.emit(removed)

	return removed

func can_trigger() -> bool:
	if not is_enabled:
		return false

	if engraved_spell == null:
		return false

	if cooldown_timer > 0:
		return false

	if is_winding_up:
		return false

	return true

func calculate_engraved_windup(proficiency: float = 0.0) -> float:
	if engraved_spell == null:
		return 0.0

	return engraved_spell.calculate_windup_time(proficiency, true)

## 计算调整后的前摇时间（应用武器特质修正）
func calculate_modified_windup(proficiency: float = 0.0, trigger_type: int = -1) -> float:
	if engraved_spell == null:
		return 0.0
	
	var base_windup = engraved_spell.calculate_windup_time(proficiency, true)
	
	if weapon_modifier != null:
		var modifier = weapon_modifier.get_windup_for_trigger(trigger_type)
		base_windup *= modifier
	
	return base_windup

## 计算调整后的能量消耗
func calculate_modified_cost(trigger_type: int = -1) -> float:
	if engraved_spell == null:
		return 0.0
	
	var base_cost = engraved_spell.resource_cost
	
	if weapon_modifier != null:
		var modifier = weapon_modifier.get_cost_for_trigger(trigger_type)
		base_cost *= modifier
	
	return base_cost

## 计算调整后的效果强度
func calculate_modified_effect(action_type: int = -1) -> float:
	var base_effect = 1.0
	
	if weapon_modifier != null:
		base_effect = weapon_modifier.get_effect_for_action(action_type)
	
	return base_effect

## 计算调整后的冷却时间
func calculate_modified_cooldown(trigger_type: int = -1) -> float:
	var base_cooldown = cooldown
	
	if weapon_modifier != null:
		base_cooldown *= weapon_modifier.get_cooldown_for_trigger(trigger_type)
	
	return base_cooldown

## 获取连续触发加成
func get_chain_bonus() -> float:
	if weapon_modifier == null:
		return 0.0
	return weapon_modifier.get_chain_bonus(consecutive_trigger_count)

## 更新连续触发计数
func update_consecutive_count() -> void:
	var current_time = Time.get_unix_time_from_system()
	if current_time - last_trigger_time > CHAIN_TRIGGER_WINDOW:
		consecutive_trigger_count = 0
	else:
		consecutive_trigger_count += 1
	last_trigger_time = current_time

## 重置连续触发计数
func reset_consecutive_count() -> void:
	consecutive_trigger_count = 0
	last_trigger_time = 0.0

func start_trigger(trigger_type: int, context: Dictionary = {}, proficiency: float = 0.0) -> bool:
	if not can_trigger():
		return false

	var has_matching_rule = false
	for rule in engraved_spell.topology_rules:
		if rule.trigger != null and rule.trigger.trigger_type == trigger_type:
			if rule.enabled:
				has_matching_rule = true
				break

	if not has_matching_rule:
		return false

	var windup_time = calculate_modified_windup(proficiency, trigger_type)

	if windup_time < 0.05:
		return _execute_trigger(trigger_type, context)

	is_winding_up = true
	windup_timer = windup_time
	pending_trigger_type = trigger_type
	pending_context = context.duplicate()

	windup_started.emit(engraved_spell, windup_time)

	return true

func trigger(trigger_type: int, context: Dictionary = {}) -> Array[TopologyRuleData]:
	if not can_trigger():
		return []

	return _execute_trigger_internal(trigger_type, context)

func _execute_trigger(trigger_type: int, context: Dictionary) -> bool:
	var rules = _execute_trigger_internal(trigger_type, context)
	return rules.size() > 0

func _execute_trigger_internal(trigger_type: int, _context: Dictionary) -> Array[TopologyRuleData]:
	var triggered_rules: Array[TopologyRuleData] = []

	for rule in engraved_spell.topology_rules:
		if rule.trigger != null and rule.trigger.trigger_type == trigger_type:
			if rule.enabled:
				triggered_rules.append(rule)

	if triggered_rules.size() > 0:
		trigger_count += 1
		cooldown_timer = calculate_modified_cooldown(trigger_type)
		spell_triggered.emit(engraved_spell, trigger_type)

	return triggered_rules

func update(delta: float) -> void:
	if cooldown_timer > 0:
		cooldown_timer = max(0, cooldown_timer - delta)

	if is_winding_up:
		windup_timer -= delta
		if windup_timer <= 0:
			is_winding_up = false
			windup_completed.emit(engraved_spell)
			_execute_trigger(pending_trigger_type, pending_context)
			pending_trigger_type = -1
			pending_context.clear()

func update_cooldown(delta: float) -> void:
	update(delta)

func cancel_windup() -> void:
	if is_winding_up:
		is_winding_up = false
		windup_timer = 0.0
		pending_trigger_type = -1
		pending_context.clear()

func get_windup_progress() -> float:
	if not is_winding_up or engraved_spell == null:
		return 1.0

	var total_windup = calculate_modified_windup()
	if total_windup <= 0:
		return 1.0

	return 1.0 - (windup_timer / total_windup)

func _check_triggers_allowed(spell: SpellCoreData) -> bool:
	if allowed_triggers.is_empty():
		return true

	for rule in spell.topology_rules:
		if rule.trigger != null:
			if rule.trigger.trigger_type not in allowed_triggers:
				return false

	return true

func get_info() -> String:
	var spell_info = "空"
	if engraved_spell != null:
		spell_info = engraved_spell.spell_name

	var status = "启用" if is_enabled else "禁用"
	if is_locked:
		status = "锁定"
	if is_winding_up:
		status = "蓄能中"

	return "[%s] %s - 法术: %s (%s)" % [slot_id, slot_name, spell_info, status]

func clone_deep() -> EngravingSlot:
	var copy = EngravingSlot.new()
	copy.slot_id = slot_id
	copy.slot_name = slot_name
	copy.description = description
	copy.is_locked = is_locked
	copy.is_enabled = is_enabled
	copy.allowed_triggers = allowed_triggers.duplicate()
	copy.slot_level = slot_level
	copy.slot_capacity = slot_capacity
	copy.cooldown = cooldown
	copy.engraving_windup_multiplier = engraving_windup_multiplier

	if engraved_spell != null:
		copy.engraved_spell = engraved_spell.clone_deep()

	return copy

func to_dict() -> Dictionary:
	return {
		"slot_id": slot_id,
		"slot_name": slot_name,
		"description": description,
		"is_locked": is_locked,
		"is_enabled": is_enabled,
		"allowed_triggers": allowed_triggers,
		"slot_level": slot_level,
		"slot_capacity": slot_capacity,
		"cooldown": cooldown,
		"engraving_windup_multiplier": engraving_windup_multiplier,
		"engraved_spell": engraved_spell.to_dict() if engraved_spell != null else {}
	}

static func from_dict(data: Dictionary) -> EngravingSlot:
	var slot = EngravingSlot.new()
	slot.slot_id = data.get("slot_id", "")
	slot.slot_name = data.get("slot_name", "刻录槽")
	slot.description = data.get("description", "")
	slot.is_locked = data.get("is_locked", false)
	slot.is_enabled = data.get("is_enabled", true)
	slot.allowed_triggers = data.get("allowed_triggers", [])
	slot.slot_level = data.get("slot_level", 1)
	slot.slot_capacity = data.get("slot_capacity", 100.0)
	slot.cooldown = data.get("cooldown", 0.0)
	slot.engraving_windup_multiplier = data.get("engraving_windup_multiplier", 0.2)

	var spell_data = data.get("engraved_spell", null)
	if spell_data != null:
		slot.engraved_spell = SpellCoreData.from_dict(spell_data)

	return slot
