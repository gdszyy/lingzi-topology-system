# spell_core_data.gd
# 法术核心数据 - 灵子拓扑核的完整定义
class_name SpellCoreData
extends Resource

@export var spell_id: String = ""                          # 唯一标识符
@export var spell_name: String = "未命名法术"               # 法术名称
@export var description: String = ""                        # 法术描述
@export var carrier: CarrierConfigData = null              # 载体配置
@export var topology_rules: Array[TopologyRuleData] = []   # 拓扑规则列表
@export var resource_cost: float = 10.0                    # 施法消耗
@export var cooldown: float = 1.0                          # 冷却时间
@export var cast_time: float = 0.0                         # 施法时间

## 计算总不稳定性
func calculate_total_instability() -> float:
	var total = 0.0
	if carrier != null:
		total += carrier.instability_cost
	
	# 递归计算裂变子法术的不稳定性
	for rule in topology_rules:
		for action in rule.actions:
			if action is FissionActionData:
				var fission = action as FissionActionData
				total += fission.spawn_count * 0.5  # 每个子弹增加不稳定性
				if fission.child_spell_data != null and fission.child_spell_data is SpellCoreData:
					total += fission.child_spell_data.calculate_total_instability() * 0.3
	
	return total

## 深拷贝
func duplicate_deep() -> SpellCoreData:
	var copy = SpellCoreData.new()
	copy.spell_id = spell_id
	copy.spell_name = spell_name
	copy.description = description
	copy.resource_cost = resource_cost
	copy.cooldown = cooldown
	copy.cast_time = cast_time
	
	# 深拷贝载体
	if carrier != null:
		copy.carrier = carrier.duplicate_deep()
	
	# 深拷贝拓扑规则
	copy.topology_rules = []
	for rule in topology_rules:
		if rule != null:
			copy.topology_rules.append(rule.duplicate_deep())
	
	return copy

## 转换为字典
func to_dict() -> Dictionary:
	var rules_array = []
	for rule in topology_rules:
		if rule != null:
			rules_array.append(rule.to_dict())
	
	return {
		"spell_id": spell_id,
		"spell_name": spell_name,
		"description": description,
		"resource_cost": resource_cost,
		"cooldown": cooldown,
		"cast_time": cast_time,
		"carrier": carrier.to_dict() if carrier != null else null,
		"topology_rules": rules_array
	}

## 从字典加载
static func from_dict(data: Dictionary) -> SpellCoreData:
	var spell = SpellCoreData.new()
	spell.spell_id = data.get("spell_id", "")
	spell.spell_name = data.get("spell_name", "未命名法术")
	spell.description = data.get("description", "")
	spell.resource_cost = data.get("resource_cost", 10.0)
	spell.cooldown = data.get("cooldown", 1.0)
	spell.cast_time = data.get("cast_time", 0.0)
	
	# 加载载体
	var carrier_data = data.get("carrier", null)
	if carrier_data != null:
		spell.carrier = CarrierConfigData.from_dict(carrier_data)
	
	# 加载拓扑规则
	var rules_data = data.get("topology_rules", [])
	spell.topology_rules = []
	for rule_data in rules_data:
		spell.topology_rules.append(TopologyRuleData.from_dict(rule_data))
	
	return spell

## 生成唯一ID
func generate_id() -> void:
	spell_id = "spell_%d_%d" % [Time.get_unix_time_from_system(), randi()]

## 获取法术摘要
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
	
	return "[%s] %s - 相态: %s, 规则数: %d, 不稳定性: %.1f" % [
		spell_id,
		spell_name,
		phase_name,
		topology_rules.size(),
		calculate_total_instability()
	]

## 验证法术结构是否合法
func validate() -> Dictionary:
	var result = {
		"valid": true,
		"errors": []
	}
	
	if carrier == null:
		result.valid = false
		result.errors.append("缺少载体配置")
	
	if topology_rules.is_empty():
		result.valid = false
		result.errors.append("至少需要一条拓扑规则")
	
	for i in range(topology_rules.size()):
		var rule = topology_rules[i]
		if rule.trigger == null:
			result.valid = false
			result.errors.append("规则 %d 缺少触发器" % i)
		if rule.actions.is_empty():
			result.valid = false
			result.errors.append("规则 %d 没有任何效果" % i)
	
	return result
