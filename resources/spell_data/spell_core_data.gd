# spell_core_data.gd
# 法术核心数据 - 灵子拓扑核的完整定义
class_name SpellCoreData
extends Resource

## 法术类型枚举
enum SpellType {
	PROJECTILE,    # 投射物法术（需要手动施放）
	ENGRAVING,     # 刻录法术（被动触发）
	HYBRID         # 混合型（两种方式都可以）
}

@export var spell_id: String = ""                          # 唯一标识符
@export var spell_name: String = "未命名法术"               # 法术名称
@export var description: String = ""                        # 法术描述
@export var spell_type: SpellType = SpellType.PROJECTILE   # 法术类型
@export var carrier: CarrierConfigData = null              # 载体配置
@export var topology_rules: Array[TopologyRuleData] = []   # 拓扑规则列表

## 消耗与冷却
@export_group("Cost & Cooldown")
@export var resource_cost: float = 10.0                    # 施法消耗（灵力/法力）
@export var cooldown: float = 1.0                          # 冷却时间（秒）

## 前摇（蓄能）系统
@export_group("Windup System")
@export var base_windup_time: float = 0.5                  # 基础前摇时间（秒）
@export var cost_windup_ratio: float = 0.02                # cost对前摇的影响系数（每点cost增加的前摇时间）
@export var min_windup_time: float = 0.1                   # 最小前摇时间（秒）
@export var max_windup_time: float = 5.0                   # 最大前摇时间（秒）

## 刻录相关
@export_group("Engraving")
@export var engraving_windup_multiplier: float = 0.2       # 刻录时的前摇倍率（0.2 = 80%减少）
@export var is_engraved: bool = false                      # 是否已被刻录（运行时状态）
@export var engraving_slot_id: String = ""                 # 刻录槽ID（运行时状态）

## 旧属性（兼容性）
@export var cast_time: float = 0.0                         # 施法时间（已废弃，使用windup系统）

## 计算实际前摇时间
## proficiency: 熟练度 (0.0 - 1.0)
## is_engraved_cast: 是否为刻录触发
func calculate_windup_time(proficiency: float = 0.0, is_engraved_cast: bool = false) -> float:
	# 基础前摇 = 基础时间 + cost * 系数
	var base = base_windup_time + resource_cost * cost_windup_ratio
	
	# 熟练度减少前摇（最多减少50%）
	var proficiency_reduction = proficiency * 0.5
	var after_proficiency = base * (1.0 - proficiency_reduction)
	
	# 刻录大幅减少前摇
	var final_time = after_proficiency
	if is_engraved_cast or is_engraved:
		final_time *= engraving_windup_multiplier
	
	# 限制在最小和最大值之间
	return clampf(final_time, min_windup_time, max_windup_time)

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

## 检查是否为刻录法术
func is_engraving_spell() -> bool:
	return spell_type == SpellType.ENGRAVING or spell_type == SpellType.HYBRID

## 检查是否为投射物法术
func is_projectile_spell() -> bool:
	return spell_type == SpellType.PROJECTILE or spell_type == SpellType.HYBRID

## 获取法术类型名称
func get_type_name() -> String:
	match spell_type:
		SpellType.PROJECTILE:
			return "投射物"
		SpellType.ENGRAVING:
			return "刻录"
		SpellType.HYBRID:
			return "混合"
	return "未知"

## 深拷贝
func clone_deep() -> SpellCoreData:
	var copy = SpellCoreData.new()
	copy.spell_id = spell_id
	copy.spell_name = spell_name
	copy.description = description
	copy.spell_type = spell_type
	copy.resource_cost = resource_cost
	copy.cooldown = cooldown
	copy.cast_time = cast_time
	
	# 前摇系统
	copy.base_windup_time = base_windup_time
	copy.cost_windup_ratio = cost_windup_ratio
	copy.min_windup_time = min_windup_time
	copy.max_windup_time = max_windup_time
	copy.engraving_windup_multiplier = engraving_windup_multiplier
	
	# 深拷贝载体
	if carrier != null:
		copy.carrier = carrier.clone_deep()
	
	# 深拷贝拓扑规则
	var rules_copy: Array[TopologyRuleData] = []
	for rule in topology_rules:
		if rule != null:
			rules_copy.append(rule.clone_deep())
	copy.topology_rules = rules_copy
	
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
		"spell_type": spell_type,
		"resource_cost": resource_cost,
		"cooldown": cooldown,
		"cast_time": cast_time,
		"base_windup_time": base_windup_time,
		"cost_windup_ratio": cost_windup_ratio,
		"min_windup_time": min_windup_time,
		"max_windup_time": max_windup_time,
		"engraving_windup_multiplier": engraving_windup_multiplier,
		"carrier": carrier.to_dict() if carrier != null else null,
		"topology_rules": rules_array
	}

## 从字典加载
static func from_dict(data: Dictionary) -> SpellCoreData:
	var spell = SpellCoreData.new()
	spell.spell_id = data.get("spell_id", "")
	spell.spell_name = data.get("spell_name", "未命名法术")
	spell.description = data.get("description", "")
	spell.spell_type = data.get("spell_type", SpellType.PROJECTILE)
	spell.resource_cost = data.get("resource_cost", 10.0)
	spell.cooldown = data.get("cooldown", 1.0)
	spell.cast_time = data.get("cast_time", 0.0)
	
	# 前摇系统
	spell.base_windup_time = data.get("base_windup_time", 0.5)
	spell.cost_windup_ratio = data.get("cost_windup_ratio", 0.02)
	spell.min_windup_time = data.get("min_windup_time", 0.1)
	spell.max_windup_time = data.get("max_windup_time", 5.0)
	spell.engraving_windup_multiplier = data.get("engraving_windup_multiplier", 0.2)
	
	# 加载载体
	var carrier_data = data.get("carrier", null)
	if carrier_data != null:
		spell.carrier = CarrierConfigData.from_dict(carrier_data)
	
	# 加载拓扑规则
	var rules_data = data.get("topology_rules", [])
	var loaded_rules: Array[TopologyRuleData] = []
	for rule_data in rules_data:
		loaded_rules.append(TopologyRuleData.from_dict(rule_data))
	spell.topology_rules = loaded_rules
	
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
	
	return "[%s] %s - 类型: %s, 相态: %s, 规则数: %d, 不稳定性: %.1f" % [
		spell_id,
		spell_name,
		get_type_name(),
		phase_name,
		topology_rules.size(),
		calculate_total_instability()
	]

## 获取前摇信息摘要
func get_windup_summary(proficiency: float = 0.0) -> String:
	var normal_time = calculate_windup_time(proficiency, false)
	var engraved_time = calculate_windup_time(proficiency, true)
	
	return "前摇: %.2fs (刻录: %.2fs) | 熟练度: %.0f%%" % [
		normal_time,
		engraved_time,
		proficiency * 100
	]

## 验证法术结构是否合法
func validate() -> Dictionary:
	var result = {
		"valid": true,
		"errors": []
	}
	
	# 投射物法术需要载体
	if is_projectile_spell() and carrier == null:
		result.valid = false
		result.errors.append("投射物法术缺少载体配置")
	
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
