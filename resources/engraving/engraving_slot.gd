# engraving_slot.gd
# 刻录槽资源 - 定义一个可以刻录法术的槽位
class_name EngravingSlot extends Resource

## 信号
signal spell_engraved(spell: SpellCoreData)
signal spell_removed(spell: SpellCoreData)
signal spell_triggered(spell: SpellCoreData, trigger_type: int)
signal windup_started(spell: SpellCoreData, windup_time: float)
signal windup_completed(spell: SpellCoreData)

## 槽位ID
@export var slot_id: String = ""

## 槽位名称
@export var slot_name: String = "刻录槽"

## 槽位描述
@export var description: String = ""

## 刻录的法术
@export var engraved_spell: SpellCoreData = null

## 槽位是否锁定（不可修改）
@export var is_locked: bool = false

## 槽位是否启用
@export var is_enabled: bool = true

## 允许的触发器类型（空数组表示允许所有类型）
@export var allowed_triggers: Array[int] = []

## 槽位等级（影响法术效果强度）
@export var slot_level: int = 1

## 槽位容量（可刻录法术的最大复杂度）
@export var slot_capacity: float = 100.0

## 冷却时间（触发后的冷却）
@export var cooldown: float = 0.0

## 刻录前摇减少倍率（刻录法术的前摇会乘以这个值）
@export var engraving_windup_multiplier: float = 0.2

## 当前冷却计时器
var cooldown_timer: float = 0.0

## 当前前摇计时器
var windup_timer: float = 0.0

## 是否正在前摇
var is_winding_up: bool = false

## 待执行的触发类型（前摇完成后执行）
var pending_trigger_type: int = -1

## 待执行的上下文
var pending_context: Dictionary = {}

## 触发次数统计
var trigger_count: int = 0

## 初始化槽位
func initialize(id: String, name: String, capacity: float = 100.0) -> void:
	slot_id = id
	slot_name = name
	slot_capacity = capacity
	generate_id()

## 生成唯一ID
func generate_id() -> void:
	if slot_id.is_empty():
		slot_id = "slot_%d_%d" % [Time.get_unix_time_from_system(), randi()]

## 刻录法术
func engrave_spell(spell: SpellCoreData) -> bool:
	if is_locked:
		push_warning("槽位已锁定，无法刻录")
		return false
	
	if spell == null:
		push_warning("法术为空")
		return false
	
	# 检查法术复杂度是否超过槽位容量
	var complexity = spell.calculate_total_instability()
	if complexity > slot_capacity:
		push_warning("法术复杂度 %.1f 超过槽位容量 %.1f" % [complexity, slot_capacity])
		return false
	
	# 检查触发器类型是否允许
	if not _check_triggers_allowed(spell):
		push_warning("法术包含不允许的触发器类型")
		return false
	
	# 移除旧法术
	var old_spell = engraved_spell
	if old_spell != null:
		spell_removed.emit(old_spell)
	
	# 刻录新法术（深拷贝并标记为已刻录）
	engraved_spell = spell.clone_deep()
	engraved_spell.is_engraved = true
	engraved_spell.engraving_slot_id = slot_id
	
	spell_engraved.emit(engraved_spell)
	
	return true

## 移除刻录的法术
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

## 检查是否可以触发
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

## 计算刻录法术的前摇时间
func calculate_engraved_windup(proficiency: float = 0.0) -> float:
	if engraved_spell == null:
		return 0.0
	
	# 刻录法术使用极大减少的前摇
	return engraved_spell.calculate_windup_time(proficiency, true)

## 开始触发（带前摇）
func start_trigger(trigger_type: int, context: Dictionary = {}, proficiency: float = 0.0) -> bool:
	if not can_trigger():
		return false
	
	# 检查触发器类型是否匹配
	var has_matching_rule = false
	for rule in engraved_spell.topology_rules:
		if rule.trigger != null and rule.trigger.trigger_type == trigger_type:
			if rule.enabled:
				has_matching_rule = true
				break
	
	if not has_matching_rule:
		return false
	
	# 计算前摇时间
	var windup_time = calculate_engraved_windup(proficiency)
	
	# 如果前摇时间极短，直接触发
	if windup_time < 0.05:
		return _execute_trigger(trigger_type, context)
	
	# 开始前摇
	is_winding_up = true
	windup_timer = windup_time
	pending_trigger_type = trigger_type
	pending_context = context.duplicate()
	
	windup_started.emit(engraved_spell, windup_time)
	
	return true

## 立即触发（跳过前摇，用于特殊情况）
func trigger(trigger_type: int, context: Dictionary = {}) -> Array[TopologyRuleData]:
	if not can_trigger():
		return []
	
	return _execute_trigger_internal(trigger_type, context)

## 执行触发
func _execute_trigger(trigger_type: int, context: Dictionary) -> bool:
	var rules = _execute_trigger_internal(trigger_type, context)
	return rules.size() > 0

## 内部触发执行
func _execute_trigger_internal(trigger_type: int, context: Dictionary) -> Array[TopologyRuleData]:
	var triggered_rules: Array[TopologyRuleData] = []
	
	for rule in engraved_spell.topology_rules:
		if rule.trigger != null and rule.trigger.trigger_type == trigger_type:
			if rule.enabled:
				triggered_rules.append(rule)
	
	if triggered_rules.size() > 0:
		trigger_count += 1
		cooldown_timer = cooldown
		spell_triggered.emit(engraved_spell, trigger_type)
	
	return triggered_rules

## 更新（处理冷却和前摇）
func update(delta: float) -> void:
	# 更新冷却
	if cooldown_timer > 0:
		cooldown_timer = max(0, cooldown_timer - delta)
	
	# 更新前摇
	if is_winding_up:
		windup_timer -= delta
		if windup_timer <= 0:
			# 前摇完成，执行触发
			is_winding_up = false
			windup_completed.emit(engraved_spell)
			_execute_trigger(pending_trigger_type, pending_context)
			pending_trigger_type = -1
			pending_context.clear()

## 更新冷却（兼容旧接口）
func update_cooldown(delta: float) -> void:
	update(delta)

## 取消前摇
func cancel_windup() -> void:
	if is_winding_up:
		is_winding_up = false
		windup_timer = 0.0
		pending_trigger_type = -1
		pending_context.clear()

## 获取前摇进度 (0.0 - 1.0)
func get_windup_progress() -> float:
	if not is_winding_up or engraved_spell == null:
		return 1.0
	
	var total_windup = calculate_engraved_windup()
	if total_windup <= 0:
		return 1.0
	
	return 1.0 - (windup_timer / total_windup)

## 检查触发器是否允许
func _check_triggers_allowed(spell: SpellCoreData) -> bool:
	if allowed_triggers.is_empty():
		return true  # 空数组表示允许所有
	
	for rule in spell.topology_rules:
		if rule.trigger != null:
			if rule.trigger.trigger_type not in allowed_triggers:
				return false
	
	return true

## 获取槽位信息
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

## 深拷贝
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

## 转换为字典
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
		"engraved_spell": engraved_spell.to_dict() if engraved_spell != null else null
	}

## 从字典加载
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
