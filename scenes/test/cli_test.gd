extends SceneTree

func _init():
	print("========================================")
	print("灵子拓扑构筑系统 - 遗传算法测试")
	print("========================================\n")

	test_spell_factory()

	test_genetic_operators()

	test_fitness_calculator()

	test_evolution()

	print("\n========================================")
	print("所有测试完成！")
	print("========================================")

	quit()

func test_spell_factory():
	print("\n--- 测试法术工厂 ---")

	var factory_script = load("res://scripts/core/spell_factory.gd")
	var factory = Node.new()
	factory.set_script(factory_script)

	for i in range(3):
		var spell = factory.generate_random_spell()
		print("生成法术 #%d: %s" % [i + 1, spell.get_summary()])

	factory.free()
	print("法术工厂测试通过 ✓")

func test_genetic_operators():
	print("\n--- 测试遗传操作 ---")

	var operators = GeneticOperators.new()

	var spell_a = _create_test_spell("测试法术A")
	var spell_b = _create_test_spell("测试法术B")

	var offspring = operators.crossover(spell_a, spell_b)
	print("交叉产生 %d 个子代" % offspring.size())
	for i in range(offspring.size()):
		print("  子代 #%d: %s" % [i + 1, offspring[i].spell_name])

	var mutated = spell_a.clone_deep()
	operators.mutate(mutated)
	print("变异后法术: %s" % mutated.get_summary())

	print("遗传操作测试通过 ✓")

func test_fitness_calculator():
	print("\n--- 测试适应度计算 ---")

	var config = FitnessConfig.create_default()
	var calculator = FitnessCalculator.new(config)

	var spell = _create_test_spell("评估测试法术")

	var fitness = calculator.quick_evaluate(spell)
	print("快速评估分数: %.2f" % fitness)

	var details = calculator.get_evaluation_details(spell)
	print("评估详情:")
	print("  规则数: %d" % details.rule_count)
	print("  总动作数: %d" % details.total_actions)
	print("  预估伤害: %.2f" % details.estimated_damage)
	print("  不稳定性: %.2f" % details.instability)

	print("适应度计算测试通过 ✓")

func test_evolution():
	print("\n--- 测试进化流程（简化版）---")

	var operators = GeneticOperators.new()
	var selection = SelectionMethods.new()
	var config = FitnessConfig.create_default()
	var calculator = FitnessCalculator.new(config)

	var population: Array[SpellCoreData] = []
	var population_size = 20

	for i in range(population_size):
		population.append(_create_random_spell())

	print("初始种群大小: %d" % population.size())

	var generations = 5
	for gen in range(generations):
		var fitness_scores: Array[float] = []
		for spell in population:
			fitness_scores.append(calculator.quick_evaluate(spell))

		var stats = selection.get_population_stats(fitness_scores)
		print("第 %d 代 - 最佳: %.2f, 平均: %.2f" % [gen, stats.max, stats.avg])

		var parents = selection.tournament_selection(population, fitness_scores, population_size)

		var new_population: Array[SpellCoreData] = []

		var elites = selection.elitism_selection(population, fitness_scores, 2)
		for elite in elites:
			new_population.append(elite.clone_deep())

		var i = 0
		while new_population.size() < population_size:
			var p1 = parents[i % parents.size()]
			var p2 = parents[(i + 1) % parents.size()]
			var offspring = operators.crossover(p1, p2)

			for child in offspring:
				operators.mutate(child)
				if new_population.size() < population_size:
					new_population.append(child)
			i += 2

		population = new_population

	var final_scores: Array[float] = []
	for spell in population:
		final_scores.append(calculator.quick_evaluate(spell))

	var final_stats = selection.get_population_stats(final_scores)
	print("\n最终结果:")
	print("  最佳适应度: %.2f" % final_stats.max)
	print("  平均适应度: %.2f" % final_stats.avg)

	var best_idx = 0
	for i in range(final_scores.size()):
		if final_scores[i] > final_scores[best_idx]:
			best_idx = i

	print("  最佳法术: %s" % population[best_idx].get_summary())

	print("进化流程测试通过 ✓")

func _create_test_spell(name: String) -> SpellCoreData:
	var spell = SpellCoreData.new()
	spell.generate_id()
	spell.spell_name = name

	spell.carrier = CarrierConfigData.new()
	spell.carrier.phase = CarrierConfigData.Phase.SOLID
	spell.carrier.mass = 2.0
	spell.carrier.velocity = 500.0
	spell.carrier.lifetime = 3.0

	var rule = TopologyRuleData.new()
	rule.rule_name = "碰撞伤害"
	rule.trigger = TriggerData.new()
	rule.trigger.trigger_type = TriggerData.TriggerType.ON_CONTACT

	var damage = DamageActionData.new()
	damage.damage_value = 20.0
	rule.actions.append(damage)

	spell.topology_rules.append(rule)

	return spell

func _create_random_spell() -> SpellCoreData:
	var spell = SpellCoreData.new()
	spell.generate_id()
	spell.spell_name = "随机法术_%d" % randi()

	spell.carrier = CarrierConfigData.new()
	spell.carrier.phase = randi() % 3
	spell.carrier.mass = randf_range(0.5, 5.0)
	spell.carrier.velocity = randf_range(200.0, 800.0)
	spell.carrier.lifetime = randf_range(1.0, 6.0)
	spell.carrier.piercing = randi_range(0, 3)
	spell.carrier.homing_strength = randf() * 0.5 if randf() < 0.3 else 0.0

	var rule_count = randi_range(1, 3)
	for i in range(rule_count):
		var rule = TopologyRuleData.new()
		rule.rule_name = "规则_%d" % i

		var trigger_type = randi() % 3
		match trigger_type:
			0:
				rule.trigger = TriggerData.new()
				rule.trigger.trigger_type = TriggerData.TriggerType.ON_CONTACT
			1:
				var timer = OnTimerTrigger.new()
				timer.delay = randf_range(0.5, 2.0)
				rule.trigger = timer
			2:
				var prox = OnProximityTrigger.new()
				prox.detection_radius = randf_range(50.0, 150.0)
				rule.trigger = prox

		var action_count = randi_range(1, 2)
		for j in range(action_count):
			var action_type = randi() % 3
			match action_type:
				0:
					var damage = DamageActionData.new()
					damage.damage_value = randf_range(10.0, 40.0)
					rule.actions.append(damage)
				1:
					var area = AreaEffectActionData.new()
					area.radius = randf_range(30.0, 100.0)
					area.damage_value = randf_range(5.0, 25.0)
					rule.actions.append(area)
				2:
					var status = ApplyStatusActionData.new()
					status.status_type = randi() % 6
					status.duration = randf_range(1.0, 4.0)
					status.effect_value = randf_range(3.0, 15.0)
					rule.actions.append(status)

		spell.topology_rules.append(rule)

	return spell
