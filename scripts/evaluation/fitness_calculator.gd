class_name FitnessCalculator
extends RefCounted

var config: FitnessConfig

var population_cache: Array[SpellCoreData] = []

func _init(fitness_config: FitnessConfig = null):
	if fitness_config != null:
		config = fitness_config
	else:
		config = FitnessConfig.create_default()

func calculate_scenario_fitness(data: SimulationDataCollector, spell: SpellCoreData) -> float:
	var report = data.get_report()

	var cost_result = calculate_spell_cost(spell)
	if cost_result.over_limit:
		return cost_result.fitness_penalty

	var norm_damage = _normalize(report.total_damage, 0.0, config.max_expected_damage)
	var norm_ttk = 1.0 - _normalize(report.time_to_kill if report.time_to_kill > 0 else config.max_expected_ttk,
									 0.0, config.max_expected_ttk)
	var norm_accuracy = report.accuracy
	var norm_resource = 1.0 - _normalize(report.resource_consumed, 0.0, config.max_expected_resource)
	var norm_overkill = 1.0 - report.overkill_ratio
	var norm_instability = 1.0 - _normalize(spell.calculate_total_instability(), 0.0, config.max_instability)

	var complexity_score = calculate_complexity_score(spell)
	var norm_complexity = _normalize(complexity_score, 0.0, config.max_complexity_bonus)

	var kill_bonus = report.kill_rate * 0.15

	var fitness = (
		config.weight_damage * norm_damage +
		config.weight_ttk * norm_ttk +
		config.weight_accuracy * norm_accuracy +
		config.weight_resource_efficiency * norm_resource +
		config.weight_overkill * norm_overkill +
		config.weight_instability * norm_instability +
		config.weight_complexity * norm_complexity +
		kill_bonus
	)

	fitness *= cost_result.efficiency_multiplier

	return fitness

func calculate_total_fitness(scenario_results: Dictionary, spell: SpellCoreData) -> float:
	var total = 0.0
	var scenario_weights = config.get_scenario_weights()

	for scenario_type in scenario_results:
		var data = scenario_results[scenario_type]
		var scenario_fitness = calculate_scenario_fitness(data, spell)
		var weight = scenario_weights.get(scenario_type, 0.0)
		total += scenario_fitness * weight

	if config.diversity_weight > 0 and population_cache.size() > 0:
		var diversity_bonus = calculate_diversity_bonus(spell)
		total = total * (1.0 - config.diversity_weight) + diversity_bonus * config.diversity_weight

	return total

func calculate_spell_cost(spell: SpellCoreData) -> Dictionary:
	var total_cost = 0.0
	var over_limit = false
	var violations: Array[String] = []

	if spell.carrier != null:
		total_cost += spell.carrier.mass * 2.0
		total_cost += spell.carrier.velocity * 0.01
		total_cost += spell.carrier.homing_strength * 10.0
		total_cost += spell.carrier.piercing * 5.0

	var fission_depth = 0
	for rule in spell.topology_rules:
		for action in rule.actions:
			if action is DamageActionData:
				var dmg = action as DamageActionData
				var action_damage = dmg.damage_value * dmg.damage_multiplier
				total_cost += action_damage * config.cost_per_damage

				if action_damage > config.max_damage_per_action:
					violations.append("单动作伤害 %.1f 超过上限 %.1f" % [action_damage, config.max_damage_per_action])

			elif action is FissionActionData:
				var fission = action as FissionActionData
				total_cost += fission.spawn_count * config.cost_per_fission

				if fission.spawn_count > config.max_fission_count:
					violations.append("裂变数量 %d 超过上限 %d" % [fission.spawn_count, config.max_fission_count])

				if fission.child_spell_data != null and fission.child_spell_data is SpellCoreData:
					var child_cost = calculate_spell_cost(fission.child_spell_data)
					total_cost += child_cost.total_cost * 0.5
					fission_depth = maxi(fission_depth, child_cost.get("fission_depth", 0) + 1)

			elif action is ApplyStatusActionData:
				var status = action as ApplyStatusActionData
				total_cost += status.duration * config.cost_per_status

			elif action is AreaEffectActionData:
				var area = action as AreaEffectActionData
				total_cost += area.radius * config.cost_per_aoe_radius
				total_cost += area.damage_value * config.cost_per_damage * 0.5

	if fission_depth > config.max_fission_depth:
		violations.append("裂变深度 %d 超过上限 %d" % [fission_depth, config.max_fission_depth])

	if total_cost > config.max_total_cost:
		violations.append("总 cost %.1f 超过上限 %.1f" % [total_cost, config.max_total_cost])

	over_limit = violations.size() > 0

	var efficiency_multiplier = 1.0
	if total_cost > 0:
		efficiency_multiplier = clampf(config.max_total_cost / (total_cost + config.max_total_cost * 0.5), 0.5, 1.5)

	var fitness_penalty = 0.0
	if over_limit:
		fitness_penalty = maxf(0.1, 0.5 - violations.size() * 0.1)

	return {
		"total_cost": total_cost,
		"over_limit": over_limit,
		"violations": violations,
		"efficiency_multiplier": efficiency_multiplier,
		"fitness_penalty": fitness_penalty,
		"fission_depth": fission_depth
	}

func calculate_complexity_score(spell: SpellCoreData) -> float:
	var score = 0.0

	score += spell.topology_rules.size() * config.complexity_bonus_per_rule

	var trigger_types: Dictionary = {}
	var action_types: Dictionary = {}
	var has_fission = false
	var has_status = false
	var has_aoe = false

	var max_nesting_depth = _calculate_nesting_depth(spell, 0)

	for rule in spell.topology_rules:
		if rule.trigger != null:
			trigger_types[rule.trigger.trigger_type] = true

		for action in rule.actions:
			action_types[action.action_type] = true

			if action is FissionActionData:
				has_fission = true
				var fission = action as FissionActionData
				score += fission.spawn_count * 1.5
			elif action is ApplyStatusActionData:
				has_status = true
			elif action is AreaEffectActionData:
				has_aoe = true
				var area = action as AreaEffectActionData
				score += area.radius * 0.05

	score += trigger_types.size() * config.complexity_bonus_per_trigger_type

	score += action_types.size() * config.complexity_bonus_per_action_type

	if has_fission:
		score += config.complexity_bonus_fission
	if has_status:
		score += config.complexity_bonus_status

	var mechanism_count = 0
	if has_fission:
		mechanism_count += 1
	if has_status:
		mechanism_count += 1
	if has_aoe:
		mechanism_count += 1

	if mechanism_count >= 2:
		score += config.complexity_bonus_combo * (mechanism_count - 1)

	if max_nesting_depth > 0:
		var nesting_bonus = 0.0
		for depth in range(1, max_nesting_depth + 1):
			nesting_bonus += config.nesting_depth_bonus * pow(config.nesting_depth_multiplier, depth - 1)
		score += nesting_bonus

	return minf(score, config.max_complexity_bonus)

func _calculate_nesting_depth(spell: SpellCoreData, current_depth: int) -> int:
	if current_depth > 10:
		return current_depth

	var max_depth = current_depth

	for rule in spell.topology_rules:
		for action in rule.actions:
			if action is FissionActionData:
				var fission = action as FissionActionData
				if fission.child_spell_data != null and fission.child_spell_data is SpellCoreData:
					var child_depth = _calculate_nesting_depth(fission.child_spell_data, current_depth + 1)
					max_depth = maxi(max_depth, child_depth)

	return max_depth

func calculate_diversity_bonus(spell: SpellCoreData) -> float:
	if population_cache.is_empty():
		return 1.0

	var total_distance = 0.0
	var min_distance = INF
	var duplicate_count = 0
	var very_similar_count = 0
	var spell_fingerprint = calculate_spell_fingerprint(spell)

	for other_spell in population_cache:
		if other_spell.spell_id == spell.spell_id:
			continue

		if calculate_spell_fingerprint(other_spell) == spell_fingerprint:
			if is_duplicate_spell(spell, other_spell):
				duplicate_count += 1
				continue

		var distance = calculate_spell_distance(spell, other_spell)
		total_distance += distance
		min_distance = minf(min_distance, distance)

		if distance < config.niche_radius:
			very_similar_count += 1

	if duplicate_count > 0:
		return maxf(0.1, 0.3 - duplicate_count * 0.1)

	var valid_comparisons = population_cache.size() - 1 - duplicate_count
	if valid_comparisons <= 0:
		return 1.0

	var avg_distance = total_distance / maxf(valid_comparisons, 1)

	if very_similar_count >= 2:
		return maxf(0.4, 0.8 - very_similar_count * 0.1)

	if min_distance < config.niche_radius:
		return maxf(0.5, 1.0 - config.similarity_penalty)

	var diversity_score = 1.0 + avg_distance * 0.4

	if spell.carrier != null:
		var type_count = _count_carrier_type_in_population(spell.carrier.carrier_type)
		var type_ratio = float(type_count) / maxf(population_cache.size(), 1)
		if type_ratio < 0.15:
			diversity_score += 0.2

	return minf(1.8, diversity_score)

func _count_carrier_type_in_population(carrier_type: int) -> int:
	var count = 0
	for spell in population_cache:
		if spell.carrier != null and spell.carrier.carrier_type == carrier_type:
			count += 1
	return count

func calculate_spell_fingerprint(spell: SpellCoreData) -> int:
	var hash_value: int = 0

	if spell.carrier != null:
		var c = spell.carrier
		hash_value ^= int(c.velocity * 10) << 0
		hash_value ^= int(c.mass * 100) << 8
		hash_value ^= c.phase << 16
		hash_value ^= c.carrier_type << 18
		hash_value ^= int(c.homing_strength * 100) << 20
		hash_value ^= c.piercing << 27

	hash_value ^= spell.topology_rules.size() << 30

	for i in range(mini(spell.topology_rules.size(), 4)):
		var rule = spell.topology_rules[i]
		if rule.trigger != null:
			hash_value ^= rule.trigger.trigger_type << (i * 3)
		for j in range(mini(rule.actions.size(), 3)):
			hash_value ^= rule.actions[j].action_type << (i * 3 + j + 12)

	return hash_value

func is_duplicate_spell(spell_a: SpellCoreData, spell_b: SpellCoreData) -> bool:
	if calculate_spell_fingerprint(spell_a) != calculate_spell_fingerprint(spell_b):
		return false
	return calculate_spell_distance(spell_a, spell_b) < 0.05

func calculate_spell_distance(spell_a: SpellCoreData, spell_b: SpellCoreData) -> float:
	var distance = 0.0

	if spell_a.carrier != null and spell_b.carrier != null:
		var ca = spell_a.carrier
		var cb = spell_b.carrier

		if ca.carrier_type != cb.carrier_type:
			distance += 0.8

		var vel_diff = absf(ca.get_effective_velocity() - cb.get_effective_velocity())
		distance += vel_diff / 400.0

		distance += absf(ca.mass - cb.mass) / 5.0

		distance += absf(ca.homing_strength - cb.homing_strength) * 0.5

		if ca.phase != cb.phase:
			distance += 0.3

		distance += absf(ca.piercing - cb.piercing) * 0.15

		var life_diff = absf(ca.get_effective_lifetime() - cb.get_effective_lifetime())
		distance += life_diff / 10.0

	var rule_count_diff = absf(spell_a.topology_rules.size() - spell_b.topology_rules.size())
	distance += rule_count_diff * 0.25

	var triggers_a = _get_trigger_signature(spell_a)
	var triggers_b = _get_trigger_signature(spell_b)

	for type_key in triggers_a.types:
		if not triggers_b.types.has(type_key):
			distance += 0.4
	for type_key in triggers_b.types:
		if not triggers_a.types.has(type_key):
			distance += 0.4

	if triggers_a.has_timer and triggers_b.has_timer:
		distance += absf(triggers_a.timer_delay - triggers_b.timer_delay) / 3.0
	if triggers_a.has_proximity and triggers_b.has_proximity:
		distance += absf(triggers_a.proximity_radius - triggers_b.proximity_radius) / 200.0

	var actions_a = _get_action_signature(spell_a)
	var actions_b = _get_action_signature(spell_b)

	for type_key in actions_a.types:
		if not actions_b.types.has(type_key):
			distance += 0.35
	for type_key in actions_b.types:
		if not actions_a.types.has(type_key):
			distance += 0.35

	if actions_a.total_damage > 0 and actions_b.total_damage > 0:
		var dmg_ratio = maxf(actions_a.total_damage, actions_b.total_damage) / minf(actions_a.total_damage, actions_b.total_damage)
		distance += (dmg_ratio - 1.0) * 0.2

	if actions_a.has_fission != actions_b.has_fission:
		distance += 0.5
	elif actions_a.has_fission and actions_b.has_fission:
		distance += absf(actions_a.fission_count - actions_b.fission_count) * 0.1

	return clampf(distance, 0.0, 3.0)

func _get_trigger_signature(spell: SpellCoreData) -> Dictionary:
	var sig = {
		"types": {},
		"has_timer": false,
		"timer_delay": 0.0,
		"has_proximity": false,
		"proximity_radius": 0.0
	}

	for rule in spell.topology_rules:
		if rule.trigger != null:
			sig.types[rule.trigger.trigger_type] = true

			if rule.trigger is OnTimerTrigger:
				sig.has_timer = true
				sig.timer_delay = maxf(sig.timer_delay, (rule.trigger as OnTimerTrigger).delay)
			elif rule.trigger is OnProximityTrigger:
				sig.has_proximity = true
				sig.proximity_radius = maxf(sig.proximity_radius, (rule.trigger as OnProximityTrigger).detection_radius)

	return sig

func _get_action_signature(spell: SpellCoreData) -> Dictionary:
	var sig = {
		"types": {},
		"total_damage": 0.0,
		"has_fission": false,
		"fission_count": 0,
		"has_aoe": false,
		"aoe_radius": 0.0
	}

	for rule in spell.topology_rules:
		for action in rule.actions:
			sig.types[action.action_type] = true

			if action is DamageActionData:
				var dmg = action as DamageActionData
				sig.total_damage += dmg.damage_value * dmg.damage_multiplier
			elif action is FissionActionData:
				var fission = action as FissionActionData
				sig.has_fission = true
				sig.fission_count += fission.spawn_count
			elif action is AreaEffectActionData:
				var area = action as AreaEffectActionData
				sig.has_aoe = true
				sig.aoe_radius = maxf(sig.aoe_radius, area.radius)
				sig.total_damage += area.damage_value

	return sig

func _get_action_types(spell: SpellCoreData) -> Dictionary:
	var types: Dictionary = {}
	for rule in spell.topology_rules:
		for action in rule.actions:
			types[action.action_type] = true
	return types

func set_population_cache(population: Array) -> void:
	population_cache.clear()
	for spell in population:
		if spell is SpellCoreData:
			population_cache.append(spell)

func quick_evaluate(spell: SpellCoreData) -> float:
	var score = 0.0

	var cost_result = calculate_spell_cost(spell)
	if cost_result.over_limit:
		return cost_result.fitness_penalty * 10.0

	score += 10.0

	if spell.carrier != null:
		var carrier = spell.carrier
		score += carrier.calculate_kinetic_damage() * 0.05
		score += carrier.homing_strength * 15.0
		score += carrier.piercing * 3.0
		score -= carrier.instability_cost * 2.0

	for rule in spell.topology_rules:
		if not rule.enabled:
			continue

		if rule.trigger != null:
			match rule.trigger.trigger_type:
				TriggerData.TriggerType.ON_CONTACT:
					score += 5.0
				TriggerData.TriggerType.ON_TIMER:
					score += 4.0
				TriggerData.TriggerType.ON_PROXIMITY:
					score += 6.0
				TriggerData.TriggerType.ON_DEATH:
					score += 3.0

		for action in rule.actions:
			if action is DamageActionData:
				var dmg = action as DamageActionData
				var damage_value = dmg.damage_value * dmg.damage_multiplier
				score += sqrt(damage_value) * 2.0

			elif action is FissionActionData:
				var fission = action as FissionActionData
				score += fission.spawn_count * 4.0
				if fission.child_spell_data != null and fission.child_spell_data is SpellCoreData:
					score += quick_evaluate(fission.child_spell_data) * 0.25

			elif action is AreaEffectActionData:
				var area = action as AreaEffectActionData
				score += area.radius * 0.15 + sqrt(area.damage_value) * 1.5

			elif action is ApplyStatusActionData:
				var status = action as ApplyStatusActionData
				score += status.duration * 2.0 + status.effect_value * 0.5

	var complexity = calculate_complexity_score(spell)
	score += complexity * 0.3

	score -= spell.calculate_total_instability() * 1.5

	score *= cost_result.efficiency_multiplier

	return maxf(score, 0.0)

func _normalize(value: float, min_val: float, max_val: float) -> float:
	if max_val <= min_val:
		return 0.0
	return clampf((value - min_val) / (max_val - min_val), 0.0, 1.0)

func compare_spells(spell_a: SpellCoreData, spell_b: SpellCoreData) -> int:
	var score_a = quick_evaluate(spell_a)
	var score_b = quick_evaluate(spell_b)

	if score_a > score_b:
		return 1
	elif score_a < score_b:
		return -1
	else:
		return 0

func get_evaluation_details(spell: SpellCoreData) -> Dictionary:
	var cost_result = calculate_spell_cost(spell)
	var complexity = calculate_complexity_score(spell)

	var details = {
		"quick_score": quick_evaluate(spell),
		"instability": spell.calculate_total_instability(),
		"rule_count": spell.topology_rules.size(),
		"total_actions": 0,
		"has_fission": false,
		"has_aoe": false,
		"has_status": false,
		"estimated_damage": 0.0,
		"total_cost": cost_result.total_cost,
		"cost_over_limit": cost_result.over_limit,
		"cost_violations": cost_result.violations,
		"complexity_score": complexity,
		"efficiency_multiplier": cost_result.efficiency_multiplier
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
