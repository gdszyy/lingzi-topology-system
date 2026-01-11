# test_main.gd
# 测试主场景 - 演示遗传算法法术生成系统
extends Control

## UI 引用
@onready var start_button: Button = $VBoxContainer/ControlPanel/StartButton
@onready var stop_button: Button = $VBoxContainer/ControlPanel/StopButton
@onready var back_button: Button = $VBoxContainer/ControlPanel/BackButton
@onready var status_label: Label = $VBoxContainer/StatusPanel/StatusLabel
@onready var generation_label: Label = $VBoxContainer/StatusPanel/GenerationLabel
@onready var best_fitness_label: Label = $VBoxContainer/StatusPanel/BestFitnessLabel
@onready var progress_bar: ProgressBar = $VBoxContainer/StatusPanel/ProgressBar
@onready var results_list: ItemList = $VBoxContainer/ResultsPanel/ResultsList
@onready var spell_details: RichTextLabel = $VBoxContainer/ResultsPanel/SpellDetails

## 配置
@onready var population_spin: SpinBox = $VBoxContainer/ConfigPanel/PopulationSpin
@onready var generations_spin: SpinBox = $VBoxContainer/ConfigPanel/GenerationsSpin
@onready var mutation_spin: SpinBox = $VBoxContainer/ConfigPanel/MutationSpin

## 遗传算法管理器引用
var ga_manager: Node

func _ready():
	# 获取遗传算法管理器
	ga_manager = get_node_or_null("/root/GeneticAlgorithmManager")
	
	if ga_manager == null:
		push_error("GeneticAlgorithmManager 未找到！")
		return
	
	# 连接信号
	ga_manager.evolution_started.connect(_on_evolution_started)
	ga_manager.generation_completed.connect(_on_generation_completed)
	ga_manager.evolution_completed.connect(_on_evolution_completed)
	ga_manager.evolution_progress.connect(_on_evolution_progress)
	
	# 初始化 UI
	_setup_ui()
	_update_status()

func _setup_ui():
	# 设置默认值
	if population_spin:
		population_spin.value = ga_manager.population_size
	if generations_spin:
		generations_spin.value = ga_manager.max_generations
	if mutation_spin:
		mutation_spin.value = ga_manager.mutation_rate * 100
	
	# 连接按钮
	if start_button:
		start_button.pressed.connect(_on_start_pressed)
	if stop_button:
		stop_button.pressed.connect(_on_stop_pressed)
		stop_button.disabled = true
	
	# 连接结果列表
	if results_list:
		results_list.item_selected.connect(_on_result_selected)
	
	# 连接返回按钮
	if back_button:
		back_button.pressed.connect(_on_back_pressed)

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")

func _on_start_pressed():
	# 应用配置
	if population_spin:
		ga_manager.population_size = int(population_spin.value)
	if generations_spin:
		ga_manager.max_generations = int(generations_spin.value)
	if mutation_spin:
		ga_manager.mutation_rate = mutation_spin.value / 100.0
	
	# 开始进化
	ga_manager.start_evolution()

func _on_stop_pressed():
	ga_manager.stop_evolution()

func _on_evolution_started():
	if start_button:
		start_button.disabled = true
	if stop_button:
		stop_button.disabled = false
	if status_label:
		status_label.text = "状态: 进化中..."
	if results_list:
		results_list.clear()

func _on_generation_completed(generation: int, best_fitness: float, avg_fitness: float):
	if generation_label:
		generation_label.text = "当前代数: %d" % generation
	if best_fitness_label:
		best_fitness_label.text = "最佳适应度: %.2f (平均: %.2f)" % [best_fitness, avg_fitness]

func _on_evolution_progress(generation: int, max_generations: int, _best_fitness: float):
	if progress_bar:
		progress_bar.value = float(generation) / float(max_generations) * 100.0

func _on_evolution_completed(best_spells: Array):
	if start_button:
		start_button.disabled = false
	if stop_button:
		stop_button.disabled = true
	if status_label:
		status_label.text = "状态: 进化完成！"
	if progress_bar:
		progress_bar.value = 100.0
	
	# 显示结果
	_display_results(best_spells)

func _display_results(spells: Array):
	if results_list == null:
		return
	
	results_list.clear()
	
	for i in range(spells.size()):
		var spell = spells[i] as SpellCoreData
		if spell != null:
			var eval_manager = get_node_or_null("/root/EvaluationManager")
			var fitness = 0.0
			if eval_manager:
				fitness = eval_manager.quick_evaluate(spell)
			
			results_list.add_item("#%d %s (适应度: %.2f)" % [i + 1, spell.spell_name, fitness])
			results_list.set_item_metadata(i, spell)

func _on_result_selected(index: int):
	if results_list == null or spell_details == null:
		return
	
	var spell = results_list.get_item_metadata(index) as SpellCoreData
	if spell == null:
		return
	
	# 显示法术详情
	var details = _format_spell_details(spell)
	spell_details.text = details

func _format_spell_details(spell: SpellCoreData) -> String:
	var text = "[b]%s[/b]\n" % spell.spell_name
	text += "ID: %s\n\n" % spell.spell_id
	
	# 载体信息
	if spell.carrier != null:
		var phase_names = ["固态", "液态", "等离子态"]
		text += "[b]【载体配置】[/b]\n"
		text += "相态: %s\n" % phase_names[spell.carrier.phase]
		text += "质量: %.2f\n" % spell.carrier.mass
		text += "速度: %.2f\n" % spell.carrier.velocity
		text += "存活时间: %.2fs\n" % spell.carrier.lifetime
		text += "穿透: %d\n" % spell.carrier.piercing
		text += "追踪强度: %.2f\n" % spell.carrier.homing_strength
		text += "不稳定性: %.2f\n\n" % spell.carrier.instability_cost
	
	# 拓扑规则
	text += "[b]【拓扑规则】[/b]\n"
	for i in range(spell.topology_rules.size()):
		var rule = spell.topology_rules[i]
		text += "\n[u]规则 %d: %s[/u]\n" % [i + 1, rule.rule_name]
		
		# 触发器
		if rule.trigger != null:
			text += "触发: %s\n" % rule.trigger.get_type_name()
			if rule.trigger is OnTimerTrigger:
				var timer = rule.trigger as OnTimerTrigger
				text += "  延迟: %.2fs\n" % timer.delay
			elif rule.trigger is OnProximityTrigger:
				var prox = rule.trigger as OnProximityTrigger
				text += "  检测半径: %.2f\n" % prox.detection_radius
		
		# 动作
		text += "效果:\n"
		for action in rule.actions:
			text += "  - %s" % action.get_type_name()
			if action is DamageActionData:
				var dmg = action as DamageActionData
				text += " (伤害: %.2f, 倍率: %.2f)" % [dmg.damage_value, dmg.damage_multiplier]
			elif action is FissionActionData:
				var fission = action as FissionActionData
				text += " (数量: %d, 角度: %.1f°)" % [fission.spawn_count, fission.spread_angle]
			elif action is AreaEffectActionData:
				var area = action as AreaEffectActionData
				text += " (半径: %.2f, 伤害: %.2f)" % [area.radius, area.damage_value]
			elif action is ApplyStatusActionData:
				var status = action as ApplyStatusActionData
				text += " (持续: %.2fs, 效果值: %.2f)" % [status.duration, status.effect_value]
			text += "\n"
	
	# 总体信息
	text += "\n[b]【总体信息】[/b]\n"
	text += "资源消耗: %.2f\n" % spell.resource_cost
	text += "冷却时间: %.2fs\n" % spell.cooldown
	text += "总不稳定性: %.2f\n" % spell.calculate_total_instability()
	
	return text

func _update_status():
	if ga_manager == null:
		return
	
	var status = ga_manager.get_status()
	if status_label:
		status_label.text = "状态: %s" % ("运行中" if status.is_running else "空闲")
