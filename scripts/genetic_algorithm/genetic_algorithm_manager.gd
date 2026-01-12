extends Node

signal evolution_started()
signal generation_completed(generation: int, best_fitness: float, avg_fitness: float)
signal evolution_completed(best_spells: Array)
signal evolution_progress(generation: int, max_generations: int, best_fitness: float)

@export_group("进化参数")
@export var population_size: int = 50
@export var max_generations: int = 100
@export var crossover_rate: float = 0.8
@export var mutation_rate: float = 0.1
@export var elitism_count: int = 2
@export var tournament_size: int = 3

@export_group("终止条件")
@export var target_fitness: float = 100.0
@export var stagnation_limit: int = 20
@export var min_improvement: float = 0.001

var is_running: bool = false
var current_generation: int = 0
var best_fitness_history: Array[float] = []
var avg_fitness_history: Array[float] = []
var stagnation_counter: int = 0

var population: Array[SpellCoreData] = []
var fitness_scores: Array[float] = []

var best_spell: SpellCoreData = null
var best_fitness: float = -INF
var top_spells: Array[SpellCoreData] = []

var genetic_operators: GeneticOperators
var selection_methods: SelectionMethods
var spell_factory: Node

func _ready():
	genetic_operators = GeneticOperators.new()
	selection_methods = SelectionMethods.new()

	genetic_operators.crossover_config.crossover_rate = crossover_rate
	genetic_operators.mutation_config.numeric_mutation_rate = mutation_rate

	selection_methods.config.elitism_count = elitism_count
	selection_methods.config.tournament_size = tournament_size

func start_evolution() -> void:
	if is_running:
		push_warning("进化已在运行中")
		return

	is_running = true
	current_generation = 0
	stagnation_counter = 0
	best_fitness = -INF
	best_spell = null
	best_fitness_history.clear()
	avg_fitness_history.clear()
	top_spells.clear()

	evolution_started.emit()

	_initialize_population()

	while is_running and current_generation < max_generations:
		_evolve_one_generation()

		if _check_termination():
			break

		current_generation += 1

		await get_tree().process_frame

	is_running = false

	_collect_top_spells(10)

	evolution_completed.emit(top_spells)

func stop_evolution() -> void:
	is_running = false

func _initialize_population() -> void:
	population.clear()
	fitness_scores.clear()

	if spell_factory == null:
		spell_factory = get_node_or_null("/root/SpellFactory")

	for i in range(population_size):
		var spell: SpellCoreData
		if spell_factory != null:
			spell = spell_factory.generate_random_spell()
		else:
			spell = _generate_fallback_spell()
		population.append(spell)

	_evaluate_population()

	print("初始种群生成完成，大小: %d" % population.size())

func _generate_fallback_spell() -> SpellCoreData:
	var spell = SpellCoreData.new()
	spell.generate_id()
	spell.spell_name = "法术_%d" % randi()

	spell.carrier = CarrierConfigData.new()
	spell.carrier.phase = randi() % 3
	spell.carrier.mass = randf_range(0.5, 3.0)
	spell.carrier.velocity = randf_range(300.0, 700.0)
	spell.carrier.lifetime = randf_range(2.0, 6.0)

	var rule = TopologyRuleData.new()
	rule.rule_name = "默认规则"
	rule.trigger = TriggerData.new()
	rule.trigger.trigger_type = TriggerData.TriggerType.ON_CONTACT

	var damage = DamageActionData.new()
	damage.damage_value = randf_range(10.0, 30.0)
	rule.actions.append(damage)

	spell.topology_rules.append(rule)

	return spell

func _evaluate_population() -> void:
	fitness_scores.clear()

	var eval_manager = get_node_or_null("/root/EvaluationManager")

	if eval_manager != null and eval_manager.fitness_calculator != null:
		eval_manager.fitness_calculator.set_population_cache(population)

	for spell in population:
		var fitness: float
		if eval_manager != null:
			fitness = eval_manager.quick_evaluate(spell)
		else:
			fitness = _fallback_evaluate(spell)

		fitness_scores.append(fitness)

		if fitness > best_fitness:
			best_fitness = fitness
			best_spell = spell.clone_deep()

func _fallback_evaluate(spell: SpellCoreData) -> float:
	var score = 10.0

	if spell.carrier != null:
		score += spell.carrier.mass * 5.0
		score += spell.carrier.velocity * 0.01
		score -= spell.carrier.instability_cost * 2.0

	for rule in spell.topology_rules:
		for action in rule.actions:
			if action is DamageActionData:
				score += (action as DamageActionData).damage_value * 0.5
			elif action is FissionActionData:
				score += (action as FissionActionData).spawn_count * 3.0

	return maxf(score, 0.0)

func _evolve_one_generation() -> void:
	var new_population: Array[SpellCoreData] = []

	var elites = selection_methods.elitism_selection(population, fitness_scores, elitism_count)
	for elite in elites:
		new_population.append(elite.clone_deep())

	var duplicate_rejections = 0
	var max_attempts = population_size * 3
	var attempts = 0

	while new_population.size() < population_size and attempts < max_attempts:
		attempts += 1

		var parents = selection_methods.tournament_selection(population, fitness_scores, 2)

		if parents.size() >= 2:
			var offspring = genetic_operators.crossover(parents[0], parents[1])

			for child in offspring:
				genetic_operators.mutate(child)

				var is_duplicate = _check_duplicate_in_population(child, new_population)

				if is_duplicate:
					duplicate_rejections += 1
					genetic_operators.mutate(child)
					genetic_operators.mutate(child)

				if new_population.size() < population_size:
					new_population.append(child)

	population = new_population

	_evaluate_population()

	var stats = selection_methods.get_population_stats(fitness_scores)
	best_fitness_history.append(stats.max)
	avg_fitness_history.append(stats.avg)

	var diversity_stats = _calculate_diversity_stats()

	if best_fitness_history.size() >= 2:
		var improvement = best_fitness_history[-1] - best_fitness_history[-2]
		if improvement < min_improvement:
			stagnation_counter += 1
		else:
			stagnation_counter = 0

	generation_completed.emit(current_generation, stats.max, stats.avg)
	evolution_progress.emit(current_generation, max_generations, best_fitness)

	print("第 %d 代 - 最佳: %.2f, 平均: %.2f, 停滞: %d, 多样性: %.2f, 拒绝重复: %d" % [
		current_generation, stats.max, stats.avg, stagnation_counter,
		diversity_stats.avg_distance, duplicate_rejections
	])

func _check_duplicate_in_population(spell: SpellCoreData, pop: Array) -> bool:
	var eval_manager = get_node_or_null("/root/EvaluationManager")
	if eval_manager == null or eval_manager.fitness_calculator == null:
		return false

	var calculator = eval_manager.fitness_calculator
	var spell_fingerprint = calculator.calculate_spell_fingerprint(spell)

	for other in pop:
		if other is SpellCoreData:
			if calculator.calculate_spell_fingerprint(other) == spell_fingerprint:
				if calculator.is_duplicate_spell(spell, other):
					return true
	return false

func _calculate_diversity_stats() -> Dictionary:
	var eval_manager = get_node_or_null("/root/EvaluationManager")
	if eval_manager == null or eval_manager.fitness_calculator == null:
		return {"avg_distance": 0.0, "unique_types": 0}

	var calculator = eval_manager.fitness_calculator
	var total_distance = 0.0
	var comparisons = 0
	var carrier_types = {}

	for spell in population:
		if spell.carrier != null:
			var ctype = spell.carrier.carrier_type
			carrier_types[ctype] = carrier_types.get(ctype, 0) + 1

	var sample_size = mini(population.size(), 20)
	for i in range(sample_size):
		for j in range(i + 1, sample_size):
			var dist = calculator.calculate_spell_distance(population[i], population[j])
			total_distance += dist
			comparisons += 1

	var avg_distance = total_distance / maxf(comparisons, 1)

	return {
		"avg_distance": avg_distance,
		"unique_types": carrier_types.size(),
		"type_distribution": carrier_types
	}

func _check_termination() -> bool:
	if best_fitness >= target_fitness:
		print("达到目标适应度，终止进化")
		return true

	if stagnation_counter >= stagnation_limit:
		print("进化停滞，终止进化")
		return true

	return false

func _collect_top_spells(count: int) -> void:
	top_spells.clear()

	var indexed = []
	for i in range(population.size()):
		indexed.append({"index": i, "fitness": fitness_scores[i]})

	indexed.sort_custom(func(a, b): return a.fitness > b.fitness)

	for i in range(mini(count, indexed.size())):
		top_spells.append(population[indexed[i].index].clone_deep())

func get_status() -> Dictionary:
	return {
		"is_running": is_running,
		"current_generation": current_generation,
		"max_generations": max_generations,
		"population_size": population.size(),
		"best_fitness": best_fitness,
		"stagnation_counter": stagnation_counter,
		"best_spell_name": best_spell.spell_name if best_spell != null else "无"
	}

func get_history() -> Dictionary:
	return {
		"best_fitness_history": best_fitness_history.duplicate(),
		"avg_fitness_history": avg_fitness_history.duplicate()
	}

func save_best_spells(path: String) -> void:
	var data = []
	for spell in top_spells:
		data.append(spell.to_dict())

	var json = JSON.stringify(data, "\t")
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(json)
		file.close()
		print("最佳法术已保存到: %s" % path)
	else:
		push_error("无法保存文件: %s" % path)

func load_population(path: String) -> bool:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("无法打开文件: %s" % path)
		return false

	var json = file.get_as_text()
	file.close()

	var data = JSON.parse_string(json)
	if data == null or not data is Array:
		push_error("无效的JSON数据")
		return false

	population.clear()
	for spell_data in data:
		var spell = SpellCoreData.from_dict(spell_data)
		population.append(spell)

	print("已加载 %d 个法术" % population.size())
	return true

func inject_spell(spell: SpellCoreData) -> void:
	if population.size() >= population_size:
		var worst_idx = 0
		var worst_fitness = fitness_scores[0]
		for i in range(fitness_scores.size()):
			if fitness_scores[i] < worst_fitness:
				worst_fitness = fitness_scores[i]
				worst_idx = i
		population[worst_idx] = spell.clone_deep()
	else:
		population.append(spell.clone_deep())

	_evaluate_population()
