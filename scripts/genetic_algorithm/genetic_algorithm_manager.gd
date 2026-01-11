# genetic_algorithm_manager.gd
# 遗传算法管理器 - 核心控制器，管理整个进化过程
extends Node

## 信号
signal evolution_started()
signal generation_completed(generation: int, best_fitness: float, avg_fitness: float)
signal evolution_completed(best_spells: Array)
signal evolution_progress(generation: int, max_generations: int, best_fitness: float)

## 进化配置
@export_group("进化参数")
@export var population_size: int = 50           # 种群大小
@export var max_generations: int = 100          # 最大代数
@export var crossover_rate: float = 0.8         # 交叉率
@export var mutation_rate: float = 0.1          # 变异率
@export var elitism_count: int = 2              # 精英保留数量
@export var tournament_size: int = 3            # 锦标赛大小

## 终止条件
@export_group("终止条件")
@export var target_fitness: float = 100.0       # 目标适应度
@export var stagnation_limit: int = 20          # 停滞代数限制
@export var min_improvement: float = 0.001      # 最小改进阈值

## 运行状态
var is_running: bool = false
var current_generation: int = 0
var best_fitness_history: Array[float] = []
var avg_fitness_history: Array[float] = []
var stagnation_counter: int = 0

## 当前种群
var population: Array[SpellCoreData] = []
var fitness_scores: Array[float] = []

## 最佳结果
var best_spell: SpellCoreData = null
var best_fitness: float = -INF
var top_spells: Array[SpellCoreData] = []

## 组件
var genetic_operators: GeneticOperators
var selection_methods: SelectionMethods
var spell_factory: Node  # 引用 SpellFactory 单例

func _ready():
	genetic_operators = GeneticOperators.new()
	selection_methods = SelectionMethods.new()
	
	# 配置遗传操作器
	genetic_operators.crossover_config.crossover_rate = crossover_rate
	genetic_operators.mutation_config.numeric_mutation_rate = mutation_rate
	
	# 配置选择方法
	selection_methods.config.elitism_count = elitism_count
	selection_methods.config.tournament_size = tournament_size

## 开始进化
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
	
	# 初始化种群
	_initialize_population()
	
	# 主进化循环
	while is_running and current_generation < max_generations:
		_evolve_one_generation()
		
		# 检查终止条件
		if _check_termination():
			break
		
		current_generation += 1
		
		# 让出控制权，避免阻塞
		await get_tree().process_frame
	
	is_running = false
	
	# 收集最佳法术
	_collect_top_spells(10)
	
	evolution_completed.emit(top_spells)

## 停止进化
func stop_evolution() -> void:
	is_running = false

## 初始化种群
func _initialize_population() -> void:
	population.clear()
	fitness_scores.clear()
	
	# 获取 SpellFactory 引用
	if spell_factory == null:
		spell_factory = get_node_or_null("/root/SpellFactory")
	
	# 生成初始种群
	for i in range(population_size):
		var spell: SpellCoreData
		if spell_factory != null:
			spell = spell_factory.generate_random_spell()
		else:
			spell = _generate_fallback_spell()
		population.append(spell)
	
	# 评估初始种群
	_evaluate_population()
	
	print("初始种群生成完成，大小: %d" % population.size())

## 备用法术生成（如果 SpellFactory 不可用）
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

## 评估种群
func _evaluate_population() -> void:
	fitness_scores.clear()
	
	# 获取 EvaluationManager 引用
	var eval_manager = get_node_or_null("/root/EvaluationManager")
	
	# 设置种群缓存用于多样性计算
	if eval_manager != null and eval_manager.fitness_calculator != null:
		eval_manager.fitness_calculator.set_population_cache(population)
	
	for spell in population:
		var fitness: float
		if eval_manager != null:
			fitness = eval_manager.quick_evaluate(spell)
		else:
			fitness = _fallback_evaluate(spell)
		
		fitness_scores.append(fitness)
		
		# 更新最佳
		if fitness > best_fitness:
			best_fitness = fitness
			best_spell = spell.clone_deep()

## 备用评估函数
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

## 进化一代
func _evolve_one_generation() -> void:
	var new_population: Array[SpellCoreData] = []
	
	# 1. 精英保留
	var elites = selection_methods.elitism_selection(population, fitness_scores, elitism_count)
	for elite in elites:
		new_population.append(elite.clone_deep())
	
	# 2. 选择、交叉、变异生成新个体
	while new_population.size() < population_size:
		# 选择父代
		var parents = selection_methods.tournament_selection(population, fitness_scores, 2)
		
		if parents.size() >= 2:
			# 交叉
			var offspring = genetic_operators.crossover(parents[0], parents[1])
			
			# 变异
			for child in offspring:
				genetic_operators.mutate(child)
				
				if new_population.size() < population_size:
					new_population.append(child)
	
	# 3. 替换种群
	population = new_population
	
	# 4. 评估新种群
	_evaluate_population()
	
	# 5. 记录统计
	var stats = selection_methods.get_population_stats(fitness_scores)
	best_fitness_history.append(stats.max)
	avg_fitness_history.append(stats.avg)
	
	# 6. 检查停滞
	if best_fitness_history.size() >= 2:
		var improvement = best_fitness_history[-1] - best_fitness_history[-2]
		if improvement < min_improvement:
			stagnation_counter += 1
		else:
			stagnation_counter = 0
	
	# 7. 发送信号
	generation_completed.emit(current_generation, stats.max, stats.avg)
	evolution_progress.emit(current_generation, max_generations, best_fitness)
	
	print("第 %d 代 - 最佳: %.2f, 平均: %.2f, 停滞: %d" % [
		current_generation, stats.max, stats.avg, stagnation_counter
	])

## 检查终止条件
func _check_termination() -> bool:
	# 达到目标适应度
	if best_fitness >= target_fitness:
		print("达到目标适应度，终止进化")
		return true
	
	# 停滞过久
	if stagnation_counter >= stagnation_limit:
		print("进化停滞，终止进化")
		return true
	
	return false

## 收集最佳法术
func _collect_top_spells(count: int) -> void:
	top_spells.clear()
	
	# 创建索引-适应度对
	var indexed = []
	for i in range(population.size()):
		indexed.append({"index": i, "fitness": fitness_scores[i]})
	
	# 排序
	indexed.sort_custom(func(a, b): return a.fitness > b.fitness)
	
	# 收集
	for i in range(mini(count, indexed.size())):
		top_spells.append(population[indexed[i].index].clone_deep())

## 获取当前状态
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

## 获取进化历史
func get_history() -> Dictionary:
	return {
		"best_fitness_history": best_fitness_history.duplicate(),
		"avg_fitness_history": avg_fitness_history.duplicate()
	}

## 保存最佳法术到文件
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

## 从文件加载种群
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

## 注入自定义法术到种群
func inject_spell(spell: SpellCoreData) -> void:
	if population.size() >= population_size:
		# 替换最差的个体
		var worst_idx = 0
		var worst_fitness = fitness_scores[0]
		for i in range(fitness_scores.size()):
			if fitness_scores[i] < worst_fitness:
				worst_fitness = fitness_scores[i]
				worst_idx = i
		population[worst_idx] = spell.clone_deep()
	else:
		population.append(spell.clone_deep())
	
	# 重新评估
	_evaluate_population()
