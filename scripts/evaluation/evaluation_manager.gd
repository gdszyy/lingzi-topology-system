extends Node

signal evaluation_started(spell: SpellCoreData)
signal evaluation_completed(spell: SpellCoreData, fitness: float)
signal batch_evaluation_progress(current: int, total: int)
signal batch_evaluation_completed(results: Array)

var fitness_config: FitnessConfig
var fitness_calculator: FitnessCalculator

var scenario_configs = {
	FitnessConfig.ScenarioType.SINGLE_TARGET: {
		"enemy_count": 1,
		"enemy_hp": 500.0,
		"enemy_speed": 0.0,
		"arena_size": Vector2(800, 600)
	},
	FitnessConfig.ScenarioType.MULTI_TARGET: {
		"enemy_count": 10,
		"enemy_hp": 50.0,
		"enemy_speed": 50.0,
		"arena_size": Vector2(1000, 800)
	},
	FitnessConfig.ScenarioType.HIGH_MOBILITY: {
		"enemy_count": 3,
		"enemy_hp": 150.0,
		"enemy_speed": 200.0,
		"arena_size": Vector2(1200, 900)
	},
	FitnessConfig.ScenarioType.SURVIVAL: {
		"enemy_count": 20,
		"enemy_hp": 30.0,
		"enemy_speed": 100.0,
		"arena_size": Vector2(800, 600)
	}
}

var evaluation_cache: Dictionary = {}
var cache_enabled: bool = true

func _ready():
	fitness_config = FitnessConfig.create_default()
	fitness_calculator = FitnessCalculator.new(fitness_config)

func set_fitness_config(config: FitnessConfig) -> void:
	fitness_config = config
	fitness_calculator = FitnessCalculator.new(config)
	evaluation_cache.clear()

func quick_evaluate(spell: SpellCoreData) -> float:
	if cache_enabled and evaluation_cache.has(spell.spell_id):
		return evaluation_cache[spell.spell_id]

	var fitness = fitness_calculator.quick_evaluate(spell)

	if cache_enabled:
		evaluation_cache[spell.spell_id] = fitness

	return fitness

func batch_quick_evaluate(spells: Array[SpellCoreData]) -> Array[float]:
	var results: Array[float] = []
	var total = spells.size()

	for i in range(total):
		var fitness = quick_evaluate(spells[i])
		results.append(fitness)

		if i % 10 == 0:
			batch_evaluation_progress.emit(i, total)

	batch_evaluation_progress.emit(total, total)
	return results

func simulate_evaluate(spell: SpellCoreData, scenarios: Array = []) -> float:
	evaluation_started.emit(spell)

	if scenarios.is_empty():
		scenarios = [
			FitnessConfig.ScenarioType.SINGLE_TARGET,
			FitnessConfig.ScenarioType.MULTI_TARGET
		]

	var scenario_results = {}

	for scenario_type in scenarios:
		var data = _run_simulation(spell, scenario_type)
		scenario_results[scenario_type] = data

	var fitness = fitness_calculator.calculate_total_fitness(scenario_results, spell)

	evaluation_completed.emit(spell, fitness)
	return fitness

func _run_simulation(spell: SpellCoreData, scenario_type: int) -> SimulationDataCollector:
	var data = SimulationDataCollector.new()
	var config = scenario_configs.get(scenario_type, scenario_configs[FitnessConfig.ScenarioType.SINGLE_TARGET])

	data.set_total_enemies(config.enemy_count)

	var simulation_time = fitness_config.simulation_duration
	var cast_count = int(simulation_time / maxf(spell.cooldown, 0.1))

	for i in range(cast_count):
		data.record_resource_consumed(spell.resource_cost)

		var projectiles = _estimate_projectiles(spell)
		for j in range(projectiles):
			data.record_projectile_fired()

			var hit_chance = _calculate_hit_chance(spell, config)
			if randf() < hit_chance:
				data.record_projectile_hit()

				var damage = _estimate_damage(spell)
				var enemy_hp = config.enemy_hp
				data.record_damage(damage, 0, enemy_hp - damage)

				if damage >= enemy_hp and data.enemies_killed < config.enemy_count:
					data.record_kill(i * spell.cooldown)

		data.update_time(spell.cooldown)

	return data

func _estimate_projectiles(spell: SpellCoreData) -> int:
	var count = 1

	for rule in spell.topology_rules:
		for action in rule.actions:
			if action is FissionActionData:
				count += (action as FissionActionData).spawn_count

	return count

func _estimate_damage(spell: SpellCoreData) -> float:
	var damage = 0.0

	if spell.carrier != null:
		damage += spell.carrier.calculate_kinetic_damage()

	for rule in spell.topology_rules:
		for action in rule.actions:
			if action is DamageActionData:
				var dmg = action as DamageActionData
				damage += dmg.damage_value * dmg.damage_multiplier
			elif action is AreaEffectActionData:
				damage += (action as AreaEffectActionData).damage_value

	return damage

func _calculate_hit_chance(spell: SpellCoreData, scenario_config: Dictionary) -> float:
	var base_chance = 0.7

	if spell.carrier != null:
		base_chance += spell.carrier.homing_strength * 0.3

	var enemy_speed = scenario_config.enemy_speed
	base_chance -= enemy_speed * 0.001

	if spell.carrier != null:
		base_chance += spell.carrier.velocity * 0.0001

	return clampf(base_chance, 0.1, 0.95)

func get_spell_details(spell: SpellCoreData) -> Dictionary:
	return fitness_calculator.get_evaluation_details(spell)

func clear_cache() -> void:
	evaluation_cache.clear()

func get_cache_stats() -> Dictionary:
	return {
		"cached_count": evaluation_cache.size(),
		"cache_enabled": cache_enabled
	}
