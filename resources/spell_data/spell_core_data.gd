class_name SpellCoreData
extends Resource

enum SpellType {
	PROJECTILE,
	ENGRAVING,
	HYBRID
}

@export var spell_id: String = ""
@export var spell_name: String = "未命名法术"
@export var description: String = ""
@export var spell_type: SpellType = SpellType.PROJECTILE
@export var carrier: CarrierConfigData = null
@export var topology_rules: Array[TopologyRuleData] = []

@export_group("Cost & Cooldown")
@export var resource_cost: float = 10.0
@export var cooldown: float = 1.0

@export_group("Windup System")
@export var base_windup_time: float = 0.5
@export var cost_windup_ratio: float = 0.02
@export var min_windup_time: float = 0.1
@export var max_windup_time: float = 5.0

@export_group("Engraving")
@export var engraving_windup_multiplier: float = 0.2
@export var is_engraved: bool = false
@export var engraving_slot_id: String = ""

@export var cast_time: float = 0.0

func calculate_windup_time(proficiency: float = 0.0, is_engraved_cast: bool = false) -> float:
	var base = base_windup_time + resource_cost * cost_windup_ratio

	var proficiency_reduction = proficiency * 0.5
	var after_proficiency = base * (1.0 - proficiency_reduction)

	var final_time = after_proficiency
	if is_engraved_cast or is_engraved:
		final_time *= engraving_windup_multiplier

	return clampf(final_time, min_windup_time, max_windup_time)

## 计算法术总不稳定性（修复版：增加循环引用检测，防止无限递归）
## visited_ids: 已访问的法术 ID 集合，用于检测循环引用
## max_depth: 最大递归深度，防止过深的嵌套导致性能问题
func calculate_total_instability(visited_ids: Dictionary = {}, max_depth: int = 10) -> float:
	# 安全检查：防止无限递归
	if max_depth <= 0:
		push_warning("[SpellCoreData] 计算不稳定性时达到最大递归深度，中断计算: %s" % spell_id)
		return 0.0
	
	# 循环引用检测
	if spell_id != "" and visited_ids.has(spell_id):
		push_warning("[SpellCoreData] 检测到循环引用，中断计算: %s" % spell_id)
		return 0.0
	
	# 将当前法术 ID 加入已访问集合
	var current_visited = visited_ids.duplicate()
	if spell_id != "":
		current_visited[spell_id] = true
	
	var total = 0.0
	if carrier != null:
		total += carrier.instability_cost

	for rule in topology_rules:
		if rule == null:
			continue
		for action in rule.actions:
			if action == null:
				continue
			if action is FissionActionData:
				var fission = action as FissionActionData
				total += fission.spawn_count * 0.5
				if fission.child_spell_data != null and fission.child_spell_data is SpellCoreData:
					var child_spell = fission.child_spell_data as SpellCoreData
					total += child_spell.calculate_total_instability(current_visited, max_depth - 1) * 0.3

	return total

func is_engraving_spell() -> bool:
	return spell_type == SpellType.ENGRAVING or spell_type == SpellType.HYBRID

func is_projectile_spell() -> bool:
	return spell_type == SpellType.PROJECTILE or spell_type == SpellType.HYBRID

func get_type_name() -> String:
	match spell_type:
		SpellType.PROJECTILE:
			return "投射物"
		SpellType.ENGRAVING:
			return "刻录"
		SpellType.HYBRID:
			return "混合"
	return "未知"

func clone_deep() -> SpellCoreData:
	var copy = SpellCoreData.new()
	copy.spell_id = spell_id
	copy.spell_name = spell_name
	copy.description = description
	copy.spell_type = spell_type
	copy.resource_cost = resource_cost
	copy.cooldown = cooldown
	copy.cast_time = cast_time

	copy.base_windup_time = base_windup_time
	copy.cost_windup_ratio = cost_windup_ratio
	copy.min_windup_time = min_windup_time
	copy.max_windup_time = max_windup_time
	copy.engraving_windup_multiplier = engraving_windup_multiplier

	if carrier != null:
		copy.carrier = carrier.clone_deep()

	var rules_copy: Array[TopologyRuleData] = []
	for rule in topology_rules:
		if rule != null:
			rules_copy.append(rule.clone_deep())
	copy.topology_rules = rules_copy

	return copy

func to_dict() -> Dictionary:
	var rules_array = []
	for rule in topology_rules:
		if rule != null:
			rules_array.append(rule.to_dict())

	return {
		"spell_id": spell_id,
		"spell_name": spell_name,
		"description": description,
		"spell_type": spell_type,
		"resource_cost": resource_cost,
		"cooldown": cooldown,
		"cast_time": cast_time,
		"base_windup_time": base_windup_time,
		"cost_windup_ratio": cost_windup_ratio,
		"min_windup_time": min_windup_time,
		"max_windup_time": max_windup_time,
		"engraving_windup_multiplier": engraving_windup_multiplier,
		"carrier": carrier.to_dict() if carrier != null else {},
		"topology_rules": rules_array
	}

static func from_dict(data: Dictionary) -> SpellCoreData:
	var spell = SpellCoreData.new()
	spell.spell_id = data.get("spell_id", "")
	spell.spell_name = data.get("spell_name", "未命名法术")
	spell.description = data.get("description", "")
	spell.spell_type = data.get("spell_type", SpellType.PROJECTILE)
	spell.resource_cost = data.get("resource_cost", 10.0)
	spell.cooldown = data.get("cooldown", 1.0)
	spell.cast_time = data.get("cast_time", 0.0)

	spell.base_windup_time = data.get("base_windup_time", 0.5)
	spell.cost_windup_ratio = data.get("cost_windup_ratio", 0.02)
	spell.min_windup_time = data.get("min_windup_time", 0.1)
	spell.max_windup_time = data.get("max_windup_time", 5.0)
	spell.engraving_windup_multiplier = data.get("engraving_windup_multiplier", 0.2)

	var carrier_data = data.get("carrier", null)
	if carrier_data != null:
		spell.carrier = CarrierConfigData.from_dict(carrier_data)

	var rules_data = data.get("topology_rules", [])
	var loaded_rules: Array[TopologyRuleData] = []
	for rule_data in rules_data:
		loaded_rules.append(TopologyRuleData.from_dict(rule_data))
	spell.topology_rules = loaded_rules

	return spell

func generate_id() -> void:
	spell_id = "spell_%d_%d" % [Time.get_unix_time_from_system(), randi()]

func get_summary() -> String:
	var phase_name = "未知"
	if carrier != null:
		match carrier.phase:
			CarrierConfigData.Phase.SOLID:
				phase_name = "固态"
			CarrierConfigData.Phase.LIQUID:
				phase_name = "液态"
			CarrierConfigData.Phase.PLASMA:
				phase_name = "等离子态"

	return "[%s] %s - 类型: %s, 相态: %s, 规则数: %d, 不稳定性: %.1f" % [
		spell_id,
		spell_name,
		get_type_name(),
		phase_name,
		topology_rules.size(),
		calculate_total_instability()
	]

func get_windup_summary(proficiency: float = 0.0) -> String:
	var normal_time = calculate_windup_time(proficiency, false)
	var engraved_time = calculate_windup_time(proficiency, true)

	return "前摇: %.2fs (刻录: %.2fs) | 熟练度: %.0f%%" % [
		normal_time,
		engraved_time,
		proficiency * 100
	]

func validate() -> Dictionary:
	var result = {
		"valid": true,
		"errors": []
	}

	if is_projectile_spell() and carrier == null:
		result.valid = false
		result.errors.append("投射物法术缺少载体配置")

	if topology_rules.is_empty():
		result.valid = false
		result.errors.append("至少需要一条拓扑规则")

	for i in range(topology_rules.size()):
		var rule = topology_rules[i]
		if rule == null:
			result.valid = false
			result.errors.append("规则 %d 为 null" % i)
			continue
		if rule.trigger == null:
			result.valid = false
			result.errors.append("规则 %d 缺少触发器" % i)
		if rule.actions.is_empty():
			result.valid = false
			result.errors.append("规则 %d 没有任何效果" % i)

	return result
