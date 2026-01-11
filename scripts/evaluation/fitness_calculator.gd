# fitness_calculator.gd
# 适应度计算器 - 根据模拟数据计算法术适应度
class_name FitnessCalculator
extends RefCounted

var config: FitnessConfig

func _init(fitness_config: FitnessConfig = null):
	if fitness_config != null:
		config = fitness_config
	else:
		config = FitnessConfig.create_default()

## 计算单场景适应度
func calculate_scenario_fitness(data: SimulationDataCollector, spell: SpellCoreData) -> float:
	var report = data.get_report()
	
	# 归一化各项指标
	var norm_damage = _normalize(report.total_damage, 0.0, config.max_expected_damage)
	var norm_ttk = 1.0 - _normalize(report.time_to_kill if report.time_to_kill > 0 else config.max_expected_ttk, 
									 0.0, config.max_expected_ttk)
	var norm_accuracy = report.accuracy
	var norm_resource = 1.0 - _normalize(report.resource_consumed, 0.0, config.max_expected_resource)
	var norm_overkill = 1.0 - report.overkill_ratio
	var norm_instability = 1.0 - _normalize(spell.calculate_total_instability(), 0.0, config.max_instability)
	
	# 击杀奖励
	var kill_bonus = report.kill_rate * 0.2  # 额外20%奖励
	
	# 加权求和
	var fitness = (
		config.weight_damage * norm_damage +
		config.weight_ttk * norm_ttk +
		config.weight_accuracy * norm_accuracy +
		config.weight_resource_efficiency * norm_resource +
		config.weight_overkill * norm_overkill +
		config.weight_instability * norm_instability +
		kill_bonus
	)
	
	return fitness

## 计算综合适应度（多场景）
func calculate_total_fitness(scenario_results: Dictionary, spell: SpellCoreData) -> float:
	var total = 0.0
	var scenario_weights = config.get_scenario_weights()
	
	for scenario_type in scenario_results:
		var data = scenario_results[scenario_type]
		var scenario_fitness = calculate_scenario_fitness(data, spell)
		var weight = scenario_weights.get(scenario_type, 0.0)
		total += scenario_fitness * weight
	
	return total

## 快速评估（不需要完整模拟）
func quick_evaluate(spell: SpellCoreData) -> float:
	var score = 0.0
	
	# 基础分数
	score += 10.0
	
	# 载体评估
	if spell.carrier != null:
		var carrier = spell.carrier
		# 伤害潜力
		score += carrier.calculate_kinetic_damage() * 0.1
		# 追踪能力
		score += carrier.homing_strength * 20.0
		# 穿透
		score += carrier.piercing * 5.0
		# 不稳定性惩罚
		score -= carrier.instability_cost * 2.0
	
	# 规则评估
	for rule in spell.topology_rules:
		if not rule.enabled:
			continue
		
		# 触发器评估
		if rule.trigger != null:
			match rule.trigger.trigger_type:
				TriggerData.TriggerType.ON_CONTACT:
					score += 5.0  # 直接命中
				TriggerData.TriggerType.ON_TIMER:
					score += 3.0  # 延时效果
				TriggerData.TriggerType.ON_PROXIMITY:
					score += 4.0  # 范围触发
				TriggerData.TriggerType.ON_DEATH:
					score += 2.0  # 死亡效果
		
		# 动作评估
		for action in rule.actions:
			if action is DamageActionData:
				var dmg = action as DamageActionData
				score += dmg.damage_value * dmg.damage_multiplier * 0.5
			
			elif action is FissionActionData:
				var fission = action as FissionActionData
				score += fission.spawn_count * 3.0
				# 递归评估子法术
				if fission.child_spell_data != null and fission.child_spell_data is SpellCoreData:
					score += quick_evaluate(fission.child_spell_data) * 0.3
			
			elif action is AreaEffectActionData:
				var area = action as AreaEffectActionData
				score += area.radius * 0.1 + area.damage_value * 0.3
			
			elif action is ApplyStatusActionData:
				var status = action as ApplyStatusActionData
				score += status.duration * status.effect_value * 0.2
	
	# 复杂度惩罚（过于复杂的法术可能不实用）
	var complexity = spell.topology_rules.size()
	for rule in spell.topology_rules:
		complexity += rule.actions.size()
	if complexity > 10:
		score -= (complexity - 10) * 2.0
	
	# 总不稳定性惩罚
	score -= spell.calculate_total_instability() * 1.5
	
	return maxf(score, 0.0)

## 归一化函数
func _normalize(value: float, min_val: float, max_val: float) -> float:
	if max_val <= min_val:
		return 0.0
	return clampf((value - min_val) / (max_val - min_val), 0.0, 1.0)

## 比较两个法术
func compare_spells(spell_a: SpellCoreData, spell_b: SpellCoreData) -> int:
	var score_a = quick_evaluate(spell_a)
	var score_b = quick_evaluate(spell_b)
	
	if score_a > score_b:
		return 1
	elif score_a < score_b:
		return -1
	else:
		return 0

## 获取法术评估详情
func get_evaluation_details(spell: SpellCoreData) -> Dictionary:
	var details = {
		"quick_score": quick_evaluate(spell),
		"instability": spell.calculate_total_instability(),
		"rule_count": spell.topology_rules.size(),
		"total_actions": 0,
		"has_fission": false,
		"has_aoe": false,
		"has_status": false,
		"estimated_damage": 0.0
	}
	
	for rule in spell.topology_rules:
		details.total_actions += rule.actions.size()
		for action in rule.actions:
			if action is FissionActionData:
				details.has_fission = true
			elif action is AreaEffectActionData:
				details.has_aoe = true
				details.estimated_damage += (action as AreaEffectActionData).damage_value
			elif action is ApplyStatusActionData:
				details.has_status = true
			elif action is DamageActionData:
				var dmg = action as DamageActionData
				details.estimated_damage += dmg.damage_value * dmg.damage_multiplier
	
	return details
