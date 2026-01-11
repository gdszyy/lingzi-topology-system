# evaluation_manager.gd
# 评估管理器 - 管理法术评估流程
extends Node

signal evaluation_started(spell: SpellCoreData)
signal evaluation_completed(spell: SpellCoreData, fitness: float)
signal batch_evaluation_progress(current: int, total: int)
signal batch_evaluation_completed(results: Array)

## 配置
var fitness_config: FitnessConfig
var fitness_calculator: FitnessCalculator

## 模拟场景配置
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

## 缓存的评估结果
var evaluation_cache: Dictionary = {}
var cache_enabled: bool = true

func _ready():
	fitness_config = FitnessConfig.create_default()
	fitness_calculator = FitnessCalculator.new(fitness_config)

## 设置适应度配置
func set_fitness_config(config: FitnessConfig) -> void:
	fitness_config = config
	fitness_calculator = FitnessCalculator.new(config)
	# 清空缓存，因为配置改变了
	evaluation_cache.clear()

## 快速评估单个法术（不需要模拟）
func quick_evaluate(spell: SpellCoreData) -> float:
	# 检查缓存
	if cache_enabled and evaluation_cache.has(spell.spell_id):
		return evaluation_cache[spell.spell_id]
	
	var fitness = fitness_calculator.quick_evaluate(spell)
	
	# 存入缓存
	if cache_enabled:
		evaluation_cache[spell.spell_id] = fitness
	
	return fitness

## 批量快速评估
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

## 模拟评估单个法术（完整模拟）
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

## 运行模拟（简化版，实际需要完整的游戏场景）
func _run_simulation(spell: SpellCoreData, scenario_type: int) -> SimulationDataCollector:
	var data = SimulationDataCollector.new()
	var config = scenario_configs.get(scenario_type, scenario_configs[FitnessConfig.ScenarioType.SINGLE_TARGET])
	
	data.set_total_enemies(config.enemy_count)
	
	# 简化模拟逻辑（实际应该在真实场景中运行）
	var simulation_time = fitness_config.simulation_duration
	var cast_count = int(simulation_time / maxf(spell.cooldown, 0.1))
	
	# 模拟施法
	for i in range(cast_count):
		data.record_resource_consumed(spell.resource_cost)
		
		# 模拟子弹发射和命中
		var projectiles = _estimate_projectiles(spell)
		for j in range(projectiles):
			data.record_projectile_fired()
			
			# 根据场景类型计算命中概率
			var hit_chance = _calculate_hit_chance(spell, config)
			if randf() < hit_chance:
				data.record_projectile_hit()
				
				# 计算伤害
				var damage = _estimate_damage(spell)
				var enemy_hp = config.enemy_hp
				data.record_damage(damage, 0, enemy_hp - damage)
				
				# 检查击杀
				if damage >= enemy_hp and data.enemies_killed < config.enemy_count:
					data.record_kill(i * spell.cooldown)
		
		data.update_time(spell.cooldown)
	
	return data

## 估算子弹数量
func _estimate_projectiles(spell: SpellCoreData) -> int:
	var count = 1
	
	for rule in spell.topology_rules:
		for action in rule.actions:
			if action is FissionActionData:
				count += (action as FissionActionData).spawn_count
	
	return count

## 估算伤害
func _estimate_damage(spell: SpellCoreData) -> float:
	var damage = 0.0
	
	# 载体动能伤害
	if spell.carrier != null:
		damage += spell.carrier.calculate_kinetic_damage()
	
	# 动作伤害
	for rule in spell.topology_rules:
		for action in rule.actions:
			if action is DamageActionData:
				var dmg = action as DamageActionData
				damage += dmg.damage_value * dmg.damage_multiplier
			elif action is AreaEffectActionData:
				damage += (action as AreaEffectActionData).damage_value
	
	return damage

## 计算命中概率
func _calculate_hit_chance(spell: SpellCoreData, scenario_config: Dictionary) -> float:
	var base_chance = 0.7
	
	# 追踪增加命中率
	if spell.carrier != null:
		base_chance += spell.carrier.homing_strength * 0.3
	
	# 敌人速度降低命中率
	var enemy_speed = scenario_config.enemy_speed
	base_chance -= enemy_speed * 0.001
	
	# 载体速度增加命中率
	if spell.carrier != null:
		base_chance += spell.carrier.velocity * 0.0001
	
	return clampf(base_chance, 0.1, 0.95)

## 获取评估详情
func get_spell_details(spell: SpellCoreData) -> Dictionary:
	return fitness_calculator.get_evaluation_details(spell)

## 清空缓存
func clear_cache() -> void:
	evaluation_cache.clear()

## 获取缓存统计
func get_cache_stats() -> Dictionary:
	return {
		"cached_count": evaluation_cache.size(),
		"cache_enabled": cache_enabled
	}
