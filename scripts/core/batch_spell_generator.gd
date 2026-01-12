class_name BatchSpellGenerator
extends RefCounted

signal batch_generated(batch_index: int, spells: Array)
signal all_batches_completed(all_spells: Dictionary)

var scenario_generator: ScenarioSpellGenerator
var fitness_calculator: FitnessCalculator

const SPELLS_PER_SCENARIO: int = 2
const BATCHES_PER_CLICK: int = 3
const MIN_DIVERSITY_THRESHOLD: float = 0.4
const MAX_GENERATION_ATTEMPTS: int = 20

const MAX_TOTAL_COST: float = 100.0
const COST_BUDGET_PER_LAYER: Dictionary = {
	1: 80.0,
	2: 60.0,
	3: 45.0,
	4: 35.0
}

func _init():
	scenario_generator = ScenarioSpellGenerator.new()
	fitness_calculator = FitnessCalculator.new()

func generate_all_batches() -> Dictionary:
	var all_batches: Dictionary = {}

	for batch_index in range(BATCHES_PER_CLICK):
		var batch_result = _generate_single_batch(batch_index, all_batches)
		all_batches[batch_index] = batch_result
		batch_generated.emit(batch_index, batch_result)

	all_batches_completed.emit(all_batches)
	return all_batches

func _generate_single_batch(batch_index: int, previous_batches: Dictionary) -> Dictionary:
	var batch_spells: Dictionary = {}

	var existing_spells: Array[SpellCoreData] = []
	for prev_batch_idx in previous_batches:
		var prev_batch = previous_batches[prev_batch_idx]
		for scenario_key in prev_batch:
			for spell in prev_batch[scenario_key]:
				existing_spells.append(spell)

	for scenario in SpellScenarioConfig.SpellScenario.values():
		var scenario_spells = _generate_spells_for_scenario_with_diversity(
			scenario,
			SPELLS_PER_SCENARIO,
			existing_spells,
			batch_spells
		)
		batch_spells[scenario] = scenario_spells

		for spell in scenario_spells:
			existing_spells.append(spell)

	return batch_spells

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

		for attempt in range(MAX_GENERATION_ATTEMPTS):
			var candidate = _generate_balanced_spell_for_scenario(scenario)
			if candidate == null:
				continue

			var diversity_score = _calculate_diversity_score(
				candidate,
				existing_spells,
				generated_spells,
				current_batch
			)

			if diversity_score >= MIN_DIVERSITY_THRESHOLD:
				best_spell = candidate
				best_diversity_score = diversity_score
				break

			if diversity_score > best_diversity_score:
				best_spell = candidate
				best_diversity_score = diversity_score

		if best_spell != null:
			generated_spells.append(best_spell)

	return generated_spells

func _generate_balanced_spell_for_scenario(scenario: SpellScenarioConfig.SpellScenario) -> SpellCoreData:
	var spell = scenario_generator.generate_spell_for_scenario(scenario)
	if spell == null:
		return null

	var cost_info = _calculate_spell_cost_with_nesting(spell)

	if cost_info.total_cost > MAX_TOTAL_COST:
		spell = _balance_spell_cost(spell, cost_info)

	var final_cost_info = _calculate_spell_cost_with_nesting(spell)
	spell.resource_cost = final_cost_info.total_cost

	return spell

func _calculate_spell_cost_with_nesting(spell: SpellCoreData, depth: int = 0) -> Dictionary:
	var total_cost: float = 0.0
	var max_nesting_depth: int = depth

	if spell.carrier != null:
		total_cost += spell.carrier.mass * 2.0
		total_cost += spell.carrier.velocity * 0.008
		total_cost += spell.carrier.homing_strength * 8.0
		total_cost += spell.carrier.piercing * 4.0

	for rule in spell.topology_rules:
		total_cost += 1.5

		for action in rule.actions:
			if action is DamageActionData:
				var dmg = action as DamageActionData
				total_cost += dmg.damage_value * dmg.damage_multiplier * 0.3

			elif action is FissionActionData:
				var fission = action as FissionActionData
				total_cost += fission.spawn_count * 2.5

				if fission.child_spell_data != null and fission.child_spell_data is SpellCoreData:
					var child_cost_info = _calculate_spell_cost_with_nesting(
						fission.child_spell_data,
						depth + 1
					)
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

func _balance_spell_cost(spell: SpellCoreData, cost_info: Dictionary) -> SpellCoreData:
	var target_cost = MAX_TOTAL_COST * 0.9
	var current_cost = cost_info.total_cost
	var reduction_ratio = target_cost / current_cost

	if spell.carrier != null:
		spell.carrier.velocity *= clampf(reduction_ratio, 0.6, 1.0)
		spell.carrier.homing_strength *= clampf(reduction_ratio, 0.5, 1.0)
		spell.carrier.piercing = maxi(0, int(spell.carrier.piercing * reduction_ratio))

	for rule in spell.topology_rules:
		for action in rule.actions:
			if action is DamageActionData:
				var dmg = action as DamageActionData
				dmg.damage_value *= clampf(reduction_ratio, 0.5, 1.0)

			elif action is FissionActionData:
				var fission = action as FissionActionData
				fission.spawn_count = maxi(2, int(fission.spawn_count * reduction_ratio))

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

func _calculate_diversity_score(
	spell: SpellCoreData,
	existing_spells: Array[SpellCoreData],
	current_scenario_spells: Array[SpellCoreData],
	current_batch: Dictionary
) -> float:
	if existing_spells.is_empty() and current_scenario_spells.is_empty():
		return 1.0

	var min_distance: float = INF
	var total_distance: float = 0.0
	var comparison_count: int = 0

	for other_spell in existing_spells:
		var distance = fitness_calculator.calculate_spell_distance(spell, other_spell)
		min_distance = minf(min_distance, distance)
		total_distance += distance
		comparison_count += 1

	for other_spell in current_scenario_spells:
		var distance = fitness_calculator.calculate_spell_distance(spell, other_spell)
		min_distance = minf(min_distance, distance * 0.8)
		total_distance += distance
		comparison_count += 1

	for scenario_key in current_batch:
		for other_spell in current_batch[scenario_key]:
			var distance = fitness_calculator.calculate_spell_distance(spell, other_spell)
			total_distance += distance
			comparison_count += 1

	if comparison_count == 0:
		return 1.0

	var avg_distance = total_distance / comparison_count
	var diversity_score = min_distance * 0.6 + avg_distance * 0.4

	return clampf(diversity_score, 0.0, 1.5)

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

			if cost_info.total_cost < 50:
				stats.cost_distribution.under_50 += 1
			elif cost_info.total_cost < 75:
				stats.cost_distribution["50_to_75"] += 1
			elif cost_info.total_cost <= 100:
				stats.cost_distribution["75_to_100"] += 1
			else:
				stats.cost_distribution.over_100 += 1

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

	if all_spells.size() > 1:
		var total_diversity = 0.0
		var comparisons = 0
		for i in range(all_spells.size()):
			for j in range(i + 1, all_spells.size()):
				total_diversity += fitness_calculator.calculate_spell_distance(all_spells[i], all_spells[j])
				comparisons += 1
		stats.avg_diversity = total_diversity / comparisons if comparisons > 0 else 0.0

	return stats

func get_scenario_name(scenario: SpellScenarioConfig.SpellScenario) -> String:
	return scenario_generator.scenario_config.get_scenario_name(scenario)

func get_all_scenarios() -> Array:
	return SpellScenarioConfig.SpellScenario.values()
