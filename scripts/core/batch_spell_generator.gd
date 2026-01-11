# batch_spell_generator.gd
# 批量差异化法术生成器 - 支持场景分类、批量生成、差异化控制
class_name BatchSpellGenerator
extends RefCounted

## 信号
signal batch_generated(batch_index: int, spells: Array)
signal all_batches_completed(all_spells: Dictionary)

## 配置
var scenario_generator: ScenarioSpellGenerator
var fitness_calculator: FitnessCalculator

## 生成配置
const SPELLS_PER_SCENARIO: int = 2          # 每个场景生成的法术数量
const BATCHES_PER_CLICK: int = 3            # 每次点击生成的批次数
const MIN_DIVERSITY_THRESHOLD: float = 0.4  # 最小差异阈值
const MAX_GENERATION_ATTEMPTS: int = 20     # 单个法术最大生成尝试次数

## Cost 平衡配置（支持1-4层嵌套）
const MAX_TOTAL_COST: float = 100.0
const COST_BUDGET_PER_LAYER: Dictionary = {
	1: 80.0,   # 1层嵌套：主法术最多80 cost
	2: 60.0,   # 2层嵌套：主法术最多60 cost
	3: 45.0,   # 3层嵌套：主法术最多45 cost
	4: 35.0    # 4层嵌套：主法术最多35 cost
}

func _init():
	scenario_generator = ScenarioSpellGenerator.new()
	fitness_calculator = FitnessCalculator.new()

## 生成所有场景的法术（3批）
func generate_all_batches() -> Dictionary:
	var all_batches: Dictionary = {}
	
	for batch_index in range(BATCHES_PER_CLICK):
		var batch_result = _generate_single_batch(batch_index, all_batches)
		all_batches[batch_index] = batch_result
		batch_generated.emit(batch_index, batch_result)
	
	all_batches_completed.emit(all_batches)
	return all_batches

## 生成单批法术
func _generate_single_batch(batch_index: int, previous_batches: Dictionary) -> Dictionary:
	var batch_spells: Dictionary = {}
	
	# 收集之前批次的所有法术用于差异化比较
	var existing_spells: Array[SpellCoreData] = []
	for prev_batch_idx in previous_batches:
		var prev_batch = previous_batches[prev_batch_idx]
		for scenario_key in prev_batch:
			for spell in prev_batch[scenario_key]:
				existing_spells.append(spell)
	
	# 为每个场景生成法术
	for scenario in SpellScenarioConfig.SpellScenario.values():
		var scenario_spells = _generate_spells_for_scenario_with_diversity(
			scenario, 
			SPELLS_PER_SCENARIO, 
			existing_spells,
			batch_spells
		)
		batch_spells[scenario] = scenario_spells
		
		# 将本批次已生成的法术加入比较池
		for spell in scenario_spells:
			existing_spells.append(spell)
	
	return batch_spells

## 为指定场景生成差异化法术
func _generate_spells_for_scenario_with_diversity(
	scenario: SpellScenarioConfig.SpellScenario, 
	count: int, 
	existing_spells: Array[SpellCoreData],
	current_batch: Dictionary
) -> Array[SpellCoreData]:
	var generated_spells: Array[SpellCoreData] = []
	
	for i in range(count):
		var best_spell: SpellCoreData = null
		var best_diversity_score: float = -1.0
		
		# 多次尝试生成，选择差异最大的
		for attempt in range(MAX_GENERATION_ATTEMPTS):
			var candidate = _generate_balanced_spell_for_scenario(scenario)
			if candidate == null:
				continue
			
			# 计算与现有法术的差异度
			var diversity_score = _calculate_diversity_score(
				candidate, 
				existing_spells, 
				generated_spells,
				current_batch
			)
			
			# 如果差异度足够高，直接使用
			if diversity_score >= MIN_DIVERSITY_THRESHOLD:
				best_spell = candidate
				best_diversity_score = diversity_score
				break
			
			# 否则保留最佳候选
			if diversity_score > best_diversity_score:
				best_spell = candidate
				best_diversity_score = diversity_score
		
		if best_spell != null:
			generated_spells.append(best_spell)
	
	return generated_spells

## 生成cost平衡的法术
func _generate_balanced_spell_for_scenario(scenario: SpellScenarioConfig.SpellScenario) -> SpellCoreData:
	var spell = scenario_generator.generate_spell_for_scenario(scenario)
	if spell == null:
		return null
	
	# 计算当前cost和嵌套层数
	var cost_info = _calculate_spell_cost_with_nesting(spell)
	
	# 如果超出限制，尝试调整
	if cost_info.total_cost > MAX_TOTAL_COST:
		spell = _balance_spell_cost(spell, cost_info)
	
	# 重新计算并设置resource_cost
	var final_cost_info = _calculate_spell_cost_with_nesting(spell)
	spell.resource_cost = final_cost_info.total_cost
	
	return spell

## 计算法术cost（包含嵌套）
func _calculate_spell_cost_with_nesting(spell: SpellCoreData, depth: int = 0) -> Dictionary:
	var total_cost: float = 0.0
	var max_nesting_depth: int = depth
	
	# 载体cost
	if spell.carrier != null:
		total_cost += spell.carrier.mass * 2.0
		total_cost += spell.carrier.velocity * 0.008  # 降低速度cost系数
		total_cost += spell.carrier.homing_strength * 8.0
		total_cost += spell.carrier.piercing * 4.0
	
	# 规则cost
	for rule in spell.topology_rules:
		total_cost += 1.5  # 每条规则基础cost
		
		for action in rule.actions:
			if action is DamageActionData:
				var dmg = action as DamageActionData
				total_cost += dmg.damage_value * dmg.damage_multiplier * 0.3
			
			elif action is FissionActionData:
				var fission = action as FissionActionData
				total_cost += fission.spawn_count * 2.5
				
				# 递归计算子法术cost
				if fission.child_spell_data != null and fission.child_spell_data is SpellCoreData:
					var child_cost_info = _calculate_spell_cost_with_nesting(
						fission.child_spell_data, 
						depth + 1
					)
					# 子法术cost按比例计入（每层递减）
					var child_cost_ratio = 0.4 / pow(1.5, depth)
					total_cost += child_cost_info.total_cost * child_cost_ratio
					max_nesting_depth = maxi(max_nesting_depth, child_cost_info.max_nesting_depth)
			
			elif action is AreaEffectActionData:
				var area = action as AreaEffectActionData
				total_cost += area.radius * 0.08
				total_cost += area.damage_value * 0.25
			
			elif action is ApplyStatusActionData:
				var status = action as ApplyStatusActionData
				total_cost += status.duration * 0.8
				total_cost += status.effect_value * 0.3
			
			elif action is SpawnExplosionActionData:
				var explosion = action as SpawnExplosionActionData
				total_cost += explosion.explosion_damage * 0.2
				total_cost += explosion.explosion_radius * 0.08
			
			elif action is SpawnDamageZoneActionData:
				var zone = action as SpawnDamageZoneActionData
				total_cost += zone.zone_damage * zone.zone_duration * 0.08
				total_cost += zone.zone_radius * 0.05
			
			elif action is ShieldActionData:
				var shield = action as ShieldActionData
				total_cost += shield.shield_amount * 0.15
				total_cost += shield.shield_duration * 0.5
				total_cost += shield.shield_radius * 0.03
			
			elif action is ReflectActionData:
				var reflect = action as ReflectActionData
				total_cost += reflect.reflect_duration * 1.0
				total_cost += reflect.max_reflects * 2.0
				total_cost += reflect.reflect_damage_ratio * 5.0
			
			elif action is DisplacementActionData:
				var disp = action as DisplacementActionData
				total_cost += disp.displacement_force * 0.01
				total_cost += disp.stun_after_displacement * 2.0
				total_cost += disp.damage_on_collision * 0.2
			
			elif action is ChainActionData:
				var chain = action as ChainActionData
				total_cost += chain.chain_count * 3.0
				total_cost += chain.chain_damage * 0.25
				total_cost += chain.chain_range * 0.02
			
			elif action is SummonActionData:
				var summon = action as SummonActionData
				total_cost += summon.summon_count * 5.0
				total_cost += summon.summon_duration * 0.3
				total_cost += summon.summon_damage * 0.2
				total_cost += summon.summon_health * 0.1
	
	return {
		"total_cost": total_cost,
		"max_nesting_depth": max_nesting_depth,
		"depth": depth
	}

## 平衡法术cost
func _balance_spell_cost(spell: SpellCoreData, cost_info: Dictionary) -> SpellCoreData:
	var target_cost = MAX_TOTAL_COST * 0.9  # 目标cost为限制的90%
	var current_cost = cost_info.total_cost
	var reduction_ratio = target_cost / current_cost
	
	# 调整载体属性
	if spell.carrier != null:
		spell.carrier.velocity *= clampf(reduction_ratio, 0.6, 1.0)
		spell.carrier.homing_strength *= clampf(reduction_ratio, 0.5, 1.0)
		spell.carrier.piercing = maxi(0, int(spell.carrier.piercing * reduction_ratio))
	
	# 调整动作参数
	for rule in spell.topology_rules:
		for action in rule.actions:
			if action is DamageActionData:
				var dmg = action as DamageActionData
				dmg.damage_value *= clampf(reduction_ratio, 0.5, 1.0)
			
			elif action is FissionActionData:
				var fission = action as FissionActionData
				fission.spawn_count = maxi(2, int(fission.spawn_count * reduction_ratio))
				
				# 递归平衡子法术
				if fission.child_spell_data != null and fission.child_spell_data is SpellCoreData:
					var child_cost_info = _calculate_spell_cost_with_nesting(fission.child_spell_data)
					if child_cost_info.total_cost > COST_BUDGET_PER_LAYER.get(cost_info.max_nesting_depth, 30.0):
						fission.child_spell_data = _balance_spell_cost(fission.child_spell_data, child_cost_info)
			
			elif action is AreaEffectActionData:
				var area = action as AreaEffectActionData
				area.radius *= clampf(reduction_ratio, 0.6, 1.0)
				area.damage_value *= clampf(reduction_ratio, 0.5, 1.0)
			
			elif action is SpawnExplosionActionData:
				var explosion = action as SpawnExplosionActionData
				explosion.explosion_radius *= clampf(reduction_ratio, 0.6, 1.0)
				explosion.explosion_damage *= clampf(reduction_ratio, 0.5, 1.0)
			
			elif action is ShieldActionData:
				var shield = action as ShieldActionData
				shield.shield_amount *= clampf(reduction_ratio, 0.5, 1.0)
				shield.shield_duration *= clampf(reduction_ratio, 0.6, 1.0)
			
			elif action is ChainActionData:
				var chain = action as ChainActionData
				chain.chain_count = maxi(2, int(chain.chain_count * reduction_ratio))
				chain.chain_damage *= clampf(reduction_ratio, 0.5, 1.0)
			
			elif action is SummonActionData:
				var summon = action as SummonActionData
				summon.summon_count = maxi(1, int(summon.summon_count * reduction_ratio))
				summon.summon_duration *= clampf(reduction_ratio, 0.6, 1.0)
				summon.summon_damage *= clampf(reduction_ratio, 0.5, 1.0)
	
	return spell

## 计算法术与现有法术的差异度
func _calculate_diversity_score(
	spell: SpellCoreData, 
	existing_spells: Array[SpellCoreData],
	current_scenario_spells: Array[SpellCoreData],
	current_batch: Dictionary
) -> float:
	if existing_spells.is_empty() and current_scenario_spells.is_empty():
		return 1.0  # 没有比较对象，差异度最大
	
	var min_distance: float = INF
	var total_distance: float = 0.0
	var comparison_count: int = 0
	
	# 与现有法术比较
	for other_spell in existing_spells:
		var distance = fitness_calculator.calculate_spell_distance(spell, other_spell)
		min_distance = minf(min_distance, distance)
		total_distance += distance
		comparison_count += 1
	
	# 与当前场景已生成的法术比较（权重更高）
	for other_spell in current_scenario_spells:
		var distance = fitness_calculator.calculate_spell_distance(spell, other_spell)
		min_distance = minf(min_distance, distance * 0.8)  # 同场景法术差异要求更高
		total_distance += distance
		comparison_count += 1
	
	# 与当前批次其他场景的法术比较
	for scenario_key in current_batch:
		for other_spell in current_batch[scenario_key]:
			var distance = fitness_calculator.calculate_spell_distance(spell, other_spell)
			total_distance += distance
			comparison_count += 1
	
	if comparison_count == 0:
		return 1.0
	
	# 综合评分：最小距离和平均距离的加权
	var avg_distance = total_distance / comparison_count
	var diversity_score = min_distance * 0.6 + avg_distance * 0.4
	
	return clampf(diversity_score, 0.0, 1.5)

## 获取批次统计信息
func get_batch_statistics(batch_spells: Dictionary) -> Dictionary:
	var stats: Dictionary = {
		"total_spells": 0,
		"scenarios": {},
		"avg_diversity": 0.0,
		"cost_distribution": {
			"under_50": 0,
			"50_to_75": 0,
			"75_to_100": 0,
			"over_100": 0
		},
		"nesting_distribution": {
			"0": 0,
			"1": 0,
			"2": 0,
			"3": 0,
			"4+": 0
		}
	}
	
	var all_spells: Array[SpellCoreData] = []
	
	for scenario_key in batch_spells:
		var scenario_spells = batch_spells[scenario_key]
		stats.scenarios[scenario_key] = {
			"count": scenario_spells.size(),
			"spells": []
		}
		
		for spell in scenario_spells:
			all_spells.append(spell)
			stats.total_spells += 1
			
			var cost_info = _calculate_spell_cost_with_nesting(spell)
			
			# Cost分布统计
			if cost_info.total_cost < 50:
				stats.cost_distribution.under_50 += 1
			elif cost_info.total_cost < 75:
				stats.cost_distribution["50_to_75"] += 1
			elif cost_info.total_cost <= 100:
				stats.cost_distribution["75_to_100"] += 1
			else:
				stats.cost_distribution.over_100 += 1
			
			# 嵌套层数统计
			var nesting = cost_info.max_nesting_depth
			if nesting == 0:
				stats.nesting_distribution["0"] += 1
			elif nesting == 1:
				stats.nesting_distribution["1"] += 1
			elif nesting == 2:
				stats.nesting_distribution["2"] += 1
			elif nesting == 3:
				stats.nesting_distribution["3"] += 1
			else:
				stats.nesting_distribution["4+"] += 1
			
			stats.scenarios[scenario_key].spells.append({
				"name": spell.spell_name,
				"cost": cost_info.total_cost,
				"nesting_depth": cost_info.max_nesting_depth
			})
	
	# 计算平均差异度
	if all_spells.size() > 1:
		var total_diversity = 0.0
		var comparisons = 0
		for i in range(all_spells.size()):
			for j in range(i + 1, all_spells.size()):
				total_diversity += fitness_calculator.calculate_spell_distance(all_spells[i], all_spells[j])
				comparisons += 1
		stats.avg_diversity = total_diversity / comparisons if comparisons > 0 else 0.0
	
	return stats

## 获取场景名称
func get_scenario_name(scenario: SpellScenarioConfig.SpellScenario) -> String:
	return scenario_generator.scenario_config.get_scenario_name(scenario)

## 获取所有场景
func get_all_scenarios() -> Array:
	return SpellScenarioConfig.SpellScenario.values()
