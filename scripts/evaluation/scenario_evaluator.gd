# scenario_evaluator.gd
# 场景化测试评估器 - 根据不同场景进行专项测试和评估
class_name ScenarioEvaluator
extends RefCounted

var scenario_config: SpellScenarioConfig
var fitness_calculator: FitnessCalculator

func _init():
	scenario_config = SpellScenarioConfig.create_default()
	fitness_calculator = FitnessCalculator.new()

## 评估法术在指定场景下的表现
func evaluate_spell_for_scenario(spell: SpellCoreData, scenario: SpellScenarioConfig.SpellScenario) -> Dictionary:
	var config = scenario_config.get_scenario_config(scenario)
	if config.is_empty():
		return {"error": "未知场景", "fitness": 0.0}
	
	var test_limits = config.get("test_limits", {})
	var test_weights = config.get("test_weights", {})
	var cost_limits = config.get("cost", {})
	
	# 检查 cost 限制
	var spell_cost = _calculate_spell_cost(spell)
	var max_cost = cost_limits.get("max_total_cost", 100.0)
	
	if spell_cost > max_cost:
		return {
			"scenario": scenario,
			"scenario_name": scenario_config.get_scenario_name(scenario),
			"fitness": 0.1,
			"cost_violation": true,
			"spell_cost": spell_cost,
			"max_cost": max_cost,
			"details": "法术 cost (%.1f) 超过场景限制 (%.1f)" % [spell_cost, max_cost]
		}
	
	# 模拟测试
	var simulation_result = _simulate_scenario_test(spell, scenario, config)
	
	# 计算加权适应度
	var fitness = _calculate_scenario_fitness(simulation_result, test_weights)
	
	# 应用 cost 效率调整
	var cost_efficiency = 1.0 - (spell_cost / max_cost) * 0.3
	fitness *= cost_efficiency
	
	return {
		"scenario": scenario,
		"scenario_name": scenario_config.get_scenario_name(scenario),
		"fitness": fitness,
		"cost_violation": false,
		"spell_cost": spell_cost,
		"simulation_result": simulation_result,
		"cost_efficiency": cost_efficiency
	}

## 评估法术在所有场景下的表现
func evaluate_spell_all_scenarios(spell: SpellCoreData) -> Dictionary:
	var results: Dictionary = {}
	var total_fitness = 0.0
	var scenario_count = 0
	
	for scenario in scenario_config.get_all_scenarios():
		var result = evaluate_spell_for_scenario(spell, scenario)
		results[scenario] = result
		total_fitness += result.get("fitness", 0.0)
		scenario_count += 1
	
	return {
		"spell_id": spell.spell_id,
		"spell_name": spell.spell_name,
		"scenario_results": results,
		"average_fitness": total_fitness / maxf(scenario_count, 1),
		"best_scenario": _find_best_scenario(results),
		"worst_scenario": _find_worst_scenario(results)
	}

## 模拟场景测试
func _simulate_scenario_test(spell: SpellCoreData, scenario: SpellScenarioConfig.SpellScenario, config: Dictionary) -> Dictionary:
	var test_limits = config.get("test_limits", {})
	
	var max_casts = test_limits.get("max_casts", 10)
	var max_total_cost = test_limits.get("max_total_cost", 200.0)
	var simulation_duration = test_limits.get("simulation_duration", 30.0)
	var target_count = test_limits.get("target_count", 5)
	var spawn_distance = test_limits.get("spawn_distance", 300.0)
	
	# 模拟结果
	var result = {
		"total_damage": 0.0,
		"enemies_hit": 0,
		"enemies_killed": 0,
		"casts_used": 0,
		"cost_used": 0.0,
		"accuracy": 0.0,
		"area_coverage": 0.0,
		"time_to_first_kill": simulation_duration,
		"damage_efficiency": 0.0
	}
	
	# 根据场景类型进行不同的模拟
	match scenario:
		SpellScenarioConfig.SpellScenario.HARASS:
			result = _simulate_harass_scenario(spell, max_casts, max_total_cost, target_count)
		SpellScenarioConfig.SpellScenario.SINGLE_TARGET:
			result = _simulate_single_target_scenario(spell, max_casts, max_total_cost)
		SpellScenarioConfig.SpellScenario.CLOSE_COMBAT:
			result = _simulate_close_combat_scenario(spell, max_casts, max_total_cost, spawn_distance)
		SpellScenarioConfig.SpellScenario.AOE:
			result = _simulate_aoe_scenario(spell, max_casts, max_total_cost, target_count)
		SpellScenarioConfig.SpellScenario.AMBUSH:
			result = _simulate_ambush_scenario(spell, max_casts, max_total_cost, target_count)
	
	return result

## 模拟牵制消耗场景
func _simulate_harass_scenario(spell: SpellCoreData, max_casts: int, max_cost: float, target_count: int) -> Dictionary:
	var spell_cost = _calculate_spell_cost(spell)
	var possible_casts = mini(max_casts, int(max_cost / maxf(spell_cost, 1.0)))
	
	var base_damage = _estimate_spell_damage(spell)
	var accuracy = _estimate_accuracy(spell, 300.0)  # 中等距离
	
	var total_damage = base_damage * possible_casts * accuracy
	var enemies_hit = int(possible_casts * accuracy * 0.8)
	
	return {
		"total_damage": total_damage,
		"enemies_hit": enemies_hit,
		"enemies_killed": int(total_damage / 100.0),  # 假设敌人100血
		"casts_used": possible_casts,
		"cost_used": spell_cost * possible_casts,
		"accuracy": accuracy,
		"damage_efficiency": total_damage / maxf(spell_cost * possible_casts, 1.0)
	}

## 模拟单体远程场景
func _simulate_single_target_scenario(spell: SpellCoreData, max_casts: int, max_cost: float) -> Dictionary:
	var spell_cost = _calculate_spell_cost(spell)
	var possible_casts = mini(max_casts, int(max_cost / maxf(spell_cost, 1.0)))
	
	var base_damage = _estimate_spell_damage(spell)
	var accuracy = _estimate_accuracy(spell, 500.0)  # 远距离
	
	# 单体伤害加成（追踪、高速）
	var single_target_bonus = 1.0
	if spell.carrier != null:
		if spell.carrier.homing_strength > 0.3:
			single_target_bonus += 0.3
		if spell.carrier.velocity > 500.0:
			single_target_bonus += 0.2
	
	var total_damage = base_damage * possible_casts * accuracy * single_target_bonus
	var time_to_kill = 100.0 / maxf(base_damage * accuracy, 1.0)  # 假设敌人100血
	
	return {
		"total_damage": total_damage,
		"single_target_damage": base_damage * single_target_bonus,
		"enemies_killed": int(total_damage / 100.0),
		"casts_used": possible_casts,
		"cost_used": spell_cost * possible_casts,
		"accuracy": accuracy,
		"time_to_kill": time_to_kill,
		"damage_efficiency": total_damage / maxf(spell_cost * possible_casts, 1.0)
	}

## 模拟近战场景
func _simulate_close_combat_scenario(spell: SpellCoreData, max_casts: int, max_cost: float, spawn_distance: float) -> Dictionary:
	var spell_cost = _calculate_spell_cost(spell)
	var possible_casts = mini(max_casts, int(max_cost / maxf(spell_cost, 1.0)))
	
	var base_damage = _estimate_spell_damage(spell)
	var accuracy = _estimate_accuracy(spell, spawn_distance)  # 近距离
	
	# 近战加成（穿透、范围效果）
	var close_combat_bonus = 1.0
	if spell.carrier != null and spell.carrier.piercing > 0:
		close_combat_bonus += spell.carrier.piercing * 0.15
	
	# 检查是否有范围效果
	var has_aoe = false
	for rule in spell.topology_rules:
		for action in rule.actions:
			if action is AreaEffectActionData or action is FissionActionData:
				has_aoe = true
				close_combat_bonus += 0.3
				break
	
	var total_damage = base_damage * possible_casts * accuracy * close_combat_bonus
	var multi_hit = 1.0 + (0.5 if has_aoe else 0.0)
	
	return {
		"total_damage": total_damage,
		"close_range_damage": base_damage * close_combat_bonus,
		"enemies_hit": int(possible_casts * accuracy * multi_hit),
		"casts_used": possible_casts,
		"cost_used": spell_cost * possible_casts,
		"accuracy": accuracy,
		"multi_hit": multi_hit,
		"survivability": 1.0 - (spell.carrier.lifetime if spell.carrier else 2.0) * 0.1  # 短寿命更安全
	}

## 模拟群伤场景
func _simulate_aoe_scenario(spell: SpellCoreData, max_casts: int, max_cost: float, target_count: int) -> Dictionary:
	var spell_cost = _calculate_spell_cost(spell)
	var possible_casts = mini(max_casts, int(max_cost / maxf(spell_cost, 1.0)))
	
	var base_damage = _estimate_spell_damage(spell)
	var accuracy = _estimate_accuracy(spell, 250.0)
	
	# 计算范围覆盖
	var area_coverage = 0.0
	var aoe_damage_bonus = 0.0
	var fission_count = 0
	
	for rule in spell.topology_rules:
		for action in rule.actions:
			if action is AreaEffectActionData:
				var area = action as AreaEffectActionData
				area_coverage += area.radius * area.radius * PI / 10000.0  # 归一化
				aoe_damage_bonus += area.damage_value
			elif action is FissionActionData:
				var fission = action as FissionActionData
				fission_count += fission.spawn_count
				area_coverage += fission.spawn_count * 0.1
	
	var enemies_hit_per_cast = minf(target_count, 1.0 + area_coverage * 3.0 + fission_count * 0.5)
	var total_damage = (base_damage + aoe_damage_bonus) * possible_casts * accuracy * enemies_hit_per_cast
	
	return {
		"total_damage": total_damage,
		"enemies_hit": int(possible_casts * accuracy * enemies_hit_per_cast),
		"enemies_killed": int(total_damage / 100.0),
		"casts_used": possible_casts,
		"cost_used": spell_cost * possible_casts,
		"accuracy": accuracy,
		"area_coverage": minf(area_coverage, 1.0),
		"fission_count": fission_count
	}

## 模拟埋伏场景
func _simulate_ambush_scenario(spell: SpellCoreData, max_casts: int, max_cost: float, target_count: int) -> Dictionary:
	var spell_cost = _calculate_spell_cost(spell)
	var possible_casts = mini(max_casts, int(max_cost / maxf(spell_cost, 1.0)))
	
	var base_damage = _estimate_spell_damage(spell)
	
	# 埋伏效果（地雷、接近触发）
	var trap_effectiveness = 0.5
	var area_denial = 0.0
	
	if spell.carrier != null:
		if spell.carrier.carrier_type == CarrierConfigData.CarrierType.MINE:
			trap_effectiveness += 0.3
			area_denial += 0.2
		if spell.carrier.lifetime > 10.0:
			trap_effectiveness += 0.2
			area_denial += 0.1
	
	# 检查接近触发
	for rule in spell.topology_rules:
		if rule.trigger is OnProximityTrigger:
			trap_effectiveness += 0.3
			var prox = rule.trigger as OnProximityTrigger
			area_denial += prox.detection_radius / 300.0
	
	# 检查范围效果
	for rule in spell.topology_rules:
		for action in rule.actions:
			if action is AreaEffectActionData:
				var area = action as AreaEffectActionData
				area_denial += area.radius / 200.0
			elif action is FissionActionData:
				trap_effectiveness += 0.2
	
	var total_damage = base_damage * possible_casts * trap_effectiveness
	
	return {
		"total_damage": total_damage,
		"trap_effectiveness": minf(trap_effectiveness, 1.0),
		"area_denial": minf(area_denial, 1.0),
		"enemies_hit": int(possible_casts * trap_effectiveness * 2),
		"casts_used": possible_casts,
		"cost_used": spell_cost * possible_casts
	}

## 计算场景适应度
func _calculate_scenario_fitness(simulation_result: Dictionary, test_weights: Dictionary) -> float:
	var fitness = 0.0
	
	# 通用指标
	if test_weights.has("damage_efficiency"):
		var efficiency = simulation_result.get("damage_efficiency", 0.0)
		fitness += test_weights.damage_efficiency * minf(efficiency / 2.0, 1.0)
	
	if test_weights.has("accuracy"):
		fitness += test_weights.accuracy * simulation_result.get("accuracy", 0.0)
	
	if test_weights.has("resource_efficiency"):
		var cost_used = simulation_result.get("cost_used", 1.0)
		var damage = simulation_result.get("total_damage", 0.0)
		var efficiency = damage / maxf(cost_used, 1.0)
		fitness += test_weights.resource_efficiency * minf(efficiency / 2.0, 1.0)
	
	if test_weights.has("ttk"):
		var ttk = simulation_result.get("time_to_kill", 30.0)
		fitness += test_weights.ttk * maxf(0.0, 1.0 - ttk / 30.0)
	
	# 场景特定指标
	if test_weights.has("single_target_damage"):
		var damage = simulation_result.get("single_target_damage", 0.0)
		fitness += test_weights.single_target_damage * minf(damage / 50.0, 1.0)
	
	if test_weights.has("close_range_damage"):
		var damage = simulation_result.get("close_range_damage", 0.0)
		fitness += test_weights.close_range_damage * minf(damage / 40.0, 1.0)
	
	if test_weights.has("survivability"):
		fitness += test_weights.survivability * simulation_result.get("survivability", 0.5)
	
	if test_weights.has("multi_hit"):
		fitness += test_weights.multi_hit * minf(simulation_result.get("multi_hit", 1.0) / 2.0, 1.0)
	
	if test_weights.has("total_damage"):
		var damage = simulation_result.get("total_damage", 0.0)
		fitness += test_weights.total_damage * minf(damage / 500.0, 1.0)
	
	if test_weights.has("enemies_hit"):
		var hits = simulation_result.get("enemies_hit", 0)
		fitness += test_weights.enemies_hit * minf(hits / 20.0, 1.0)
	
	if test_weights.has("area_coverage"):
		fitness += test_weights.area_coverage * simulation_result.get("area_coverage", 0.0)
	
	if test_weights.has("trap_effectiveness"):
		fitness += test_weights.trap_effectiveness * simulation_result.get("trap_effectiveness", 0.0)
	
	if test_weights.has("area_denial"):
		fitness += test_weights.area_denial * simulation_result.get("area_denial", 0.0)
	
	return clampf(fitness, 0.0, 1.0)

## 估算法术伤害
func _estimate_spell_damage(spell: SpellCoreData) -> float:
	var total = 0.0
	
	for rule in spell.topology_rules:
		for action in rule.actions:
			if action is DamageActionData:
				var dmg = action as DamageActionData
				total += dmg.damage_value * dmg.damage_multiplier
			elif action is AreaEffectActionData:
				var area = action as AreaEffectActionData
				total += area.damage_value * 0.7  # 范围伤害折算
			elif action is FissionActionData:
				var fission = action as FissionActionData
				if fission.child_spell_data != null:
					total += _estimate_spell_damage(fission.child_spell_data) * fission.spawn_count * 0.5
	
	# 质量加成
	if spell.carrier != null:
		total *= (1.0 + spell.carrier.mass * 0.1)
	
	return total

## 估算命中率
func _estimate_accuracy(spell: SpellCoreData, distance: float) -> float:
	if spell.carrier == null:
		return 0.5
	
	var accuracy = 0.7  # 基础命中率
	
	# 速度影响
	var velocity = spell.carrier.get_effective_velocity()
	if velocity > 400.0:
		accuracy += 0.15
	elif velocity < 150.0:
		accuracy -= 0.1
	
	# 追踪影响
	if spell.carrier.homing_strength > 0.3:
		accuracy += 0.2
	
	# 距离影响
	if distance > 400.0:
		accuracy -= 0.15
	elif distance < 150.0:
		accuracy += 0.1
	
	return clampf(accuracy, 0.2, 0.95)

## 计算法术 cost
func _calculate_spell_cost(spell: SpellCoreData) -> float:
	var cost = 5.0
	
	if spell.carrier != null:
		cost += spell.carrier.mass * 2.0
		cost += spell.carrier.velocity * 0.01
		cost += spell.carrier.piercing * 3.0
		cost += spell.carrier.homing_strength * 10.0
	
	for rule in spell.topology_rules:
		cost += 2.0
		for action in rule.actions:
			if action is DamageActionData:
				cost += action.damage_value * 0.2
			elif action is FissionActionData:
				cost += action.spawn_count * 3.0
			elif action is AreaEffectActionData:
				cost += action.radius * 0.1 + action.damage_value * 0.15
	
	return cost

## 找到最佳场景
func _find_best_scenario(results: Dictionary) -> int:
	var best_scenario = -1
	var best_fitness = -1.0
	
	for scenario in results:
		var fitness = results[scenario].get("fitness", 0.0)
		if fitness > best_fitness:
			best_fitness = fitness
			best_scenario = scenario
	
	return best_scenario

## 找到最差场景
func _find_worst_scenario(results: Dictionary) -> int:
	var worst_scenario = -1
	var worst_fitness = INF
	
	for scenario in results:
		var fitness = results[scenario].get("fitness", 0.0)
		if fitness < worst_fitness:
			worst_fitness = fitness
			worst_scenario = scenario
	
	return worst_scenario
