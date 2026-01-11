# battle_test_scene.gd
# 法术测试场景 - 可视化测试生成的法术效果
extends Node2D

## 场景配置
enum TestScenario {
	SINGLE_TARGET,      # 单体目标
	GROUP_TARGETS,      # 群体目标
	MOVING_TARGETS,     # 移动目标
	SURVIVAL            # 生存模式
}

## UI 引用
@onready var scenario_option: OptionButton = $UI/TopPanel/ScenarioOption
@onready var start_button: Button = $UI/TopPanel/StartButton
@onready var stop_button: Button = $UI/TopPanel/StopButton
@onready var reset_button: Button = $UI/TopPanel/ResetButton
@onready var spell_list: ItemList = $UI/LeftPanel/SpellList
@onready var load_from_ga_button: Button = $UI/LeftPanel/LoadFromGAButton
@onready var back_button: Button = $UI/TopPanel/BackButton

## 统计面板
@onready var stats_label: RichTextLabel = $UI/RightPanel/StatsLabel
@onready var dps_label: Label = $UI/RightPanel/DPSLabel
@onready var hit_rate_label: Label = $UI/RightPanel/HitRateLabel

## 场景组件
@onready var spell_caster: SpellCaster = $SpellCaster
@onready var enemy_container: Node2D = $EnemyContainer
@onready var battle_area: ColorRect = $BattleArea

## 预加载
var enemy_scene: PackedScene

## 状态
var current_scenario: TestScenario = TestScenario.SINGLE_TARGET
var is_running: bool = false
var test_duration: float = 0.0
var available_spells: Array[SpellCoreData] = []
var current_spell_index: int = -1

## 统计
var total_damage_dealt: float = 0.0
var enemies_killed: int = 0
var test_start_time: float = 0.0

func _ready():
	enemy_scene = preload("res://scenes/battle_test/entities/enemy.tscn")
	
	_setup_ui()
	_setup_scenario_options()
	_create_default_spell()

func _process(delta: float) -> void:
	if is_running:
		test_duration += delta
		_update_stats_display()

## 设置 UI
func _setup_ui() -> void:
	start_button.pressed.connect(_on_start_pressed)
	stop_button.pressed.connect(_on_stop_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	load_from_ga_button.pressed.connect(_on_load_from_ga_pressed)
	scenario_option.item_selected.connect(_on_scenario_selected)
	spell_list.item_selected.connect(_on_spell_selected)
	back_button.pressed.connect(_on_back_pressed)
	
	stop_button.disabled = true

## 返回主菜单
func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")

## 设置场景选项
func _setup_scenario_options() -> void:
	scenario_option.clear()
	scenario_option.add_item("单体目标", TestScenario.SINGLE_TARGET)
	scenario_option.add_item("群体目标 (5个)", TestScenario.GROUP_TARGETS)
	scenario_option.add_item("移动目标", TestScenario.MOVING_TARGETS)
	scenario_option.add_item("生存模式", TestScenario.SURVIVAL)

## 创建默认测试法术
func _create_default_spell() -> void:
	var spell = SpellCoreData.new()
	spell.generate_id()
	spell.spell_name = "默认测试法术"
	
	spell.carrier = CarrierConfigData.new()
	spell.carrier.phase = CarrierConfigData.Phase.PLASMA
	spell.carrier.velocity = 500.0
	spell.carrier.lifetime = 3.0
	spell.carrier.mass = 1.5
	spell.carrier.size = 1.0
	
	var rule = TopologyRuleData.new()
	rule.rule_name = "碰撞伤害"
	rule.trigger = TriggerData.new()
	rule.trigger.trigger_type = TriggerData.TriggerType.ON_CONTACT
	
	var damage = DamageActionData.new()
	damage.damage_value = 25.0
	var actions: Array[ActionData] = [damage]
	rule.actions = actions
	
	var rules: Array[TopologyRuleData] = [rule]
	spell.topology_rules = rules
	
	available_spells.append(spell)
	_update_spell_list()

## 更新法术列表
func _update_spell_list() -> void:
	spell_list.clear()
	for i in range(available_spells.size()):
		var spell = available_spells[i]
		spell_list.add_item("%d. %s" % [i + 1, spell.spell_name])

## 场景选择
func _on_scenario_selected(index: int) -> void:
	current_scenario = index as TestScenario

## 法术选择
func _on_spell_selected(index: int) -> void:
	current_spell_index = index
	if index >= 0 and index < available_spells.size():
		spell_caster.set_spell(available_spells[index])
		_display_spell_info(available_spells[index])

## 显示法术信息
func _display_spell_info(spell: SpellCoreData) -> void:
	var info = "[b]%s[/b]\n\n" % spell.spell_name
	
	if spell.carrier != null:
		var phase_names = ["固态", "液态", "等离子态"]
		info += "[u]载体配置[/u]\n"
		info += "相态: %s\n" % phase_names[spell.carrier.phase]
		info += "速度: %.0f\n" % spell.carrier.velocity
		info += "存活: %.1fs\n" % spell.carrier.lifetime
		info += "穿透: %d\n" % spell.carrier.piercing
		info += "追踪: %.1f\n\n" % spell.carrier.homing_strength
	
	info += "[u]拓扑规则[/u]\n"
	for rule in spell.topology_rules:
		info += "• %s\n" % rule.rule_name
		if rule.trigger != null:
			info += "  触发: %s\n" % rule.trigger.get_type_name()
		for action in rule.actions:
			info += "  效果: %s\n" % action.get_type_name()
	
	stats_label.text = info

## 开始测试
func _on_start_pressed() -> void:
	if current_spell_index < 0:
		return
	
	is_running = true
	test_duration = 0.0
	total_damage_dealt = 0.0
	enemies_killed = 0
	test_start_time = Time.get_unix_time_from_system()
	
	start_button.disabled = true
	stop_button.disabled = false
	
	# 清除现有敌人
	_clear_enemies()
	
	# 根据场景生成敌人
	_spawn_enemies_for_scenario()
	
	# 开始自动发射
	spell_caster.auto_fire = true
	spell_caster.fire_rate = 2.0

## 停止测试
func _on_stop_pressed() -> void:
	is_running = false
	spell_caster.auto_fire = false
	spell_caster.clear_projectiles()
	
	start_button.disabled = false
	stop_button.disabled = true
	
	_show_final_results()

## 重置
func _on_reset_pressed() -> void:
	_on_stop_pressed()
	_clear_enemies()
	spell_caster.reset_stats()
	test_duration = 0.0
	total_damage_dealt = 0.0
	enemies_killed = 0

## 从遗传算法加载法术
func _on_load_from_ga_pressed() -> void:
	var ga_manager = get_node_or_null("/root/GeneticAlgorithmManager")
	if ga_manager == null:
		push_warning("GeneticAlgorithmManager 未找到")
		return
	
	# 获取最佳法术
	if ga_manager.top_spells.size() > 0:
		for spell in ga_manager.top_spells:
			if not _spell_exists(spell):
				available_spells.append(spell)
		_update_spell_list()
	elif ga_manager.best_spell != null:
		if not _spell_exists(ga_manager.best_spell):
			available_spells.append(ga_manager.best_spell)
		_update_spell_list()

## 检查法术是否已存在
func _spell_exists(spell: SpellCoreData) -> bool:
	for existing in available_spells:
		if existing.spell_id == spell.spell_id:
			return true
	return false

## 根据场景生成敌人
func _spawn_enemies_for_scenario() -> void:
	var battle_center = battle_area.position + battle_area.size / 2
	
	match current_scenario:
		TestScenario.SINGLE_TARGET:
			_spawn_enemy(battle_center + Vector2(300, 0), 200.0, Enemy.MovePattern.STATIC)
		
		TestScenario.GROUP_TARGETS:
			_spawn_enemy(battle_center + Vector2(250, -100), 80.0, Enemy.MovePattern.STATIC)
			_spawn_enemy(battle_center + Vector2(300, 0), 80.0, Enemy.MovePattern.STATIC)
			_spawn_enemy(battle_center + Vector2(250, 100), 80.0, Enemy.MovePattern.STATIC)
			_spawn_enemy(battle_center + Vector2(350, -50), 80.0, Enemy.MovePattern.STATIC)
			_spawn_enemy(battle_center + Vector2(350, 50), 80.0, Enemy.MovePattern.STATIC)
		
		TestScenario.MOVING_TARGETS:
			_spawn_enemy(battle_center + Vector2(300, -80), 100.0, Enemy.MovePattern.HORIZONTAL, 80.0)
			_spawn_enemy(battle_center + Vector2(300, 80), 100.0, Enemy.MovePattern.CIRCULAR, 60.0)
			_spawn_enemy(battle_center + Vector2(400, 0), 100.0, Enemy.MovePattern.RANDOM, 100.0)
		
		TestScenario.SURVIVAL:
			# 持续生成敌人
			_spawn_enemy(battle_center + Vector2(300, 0), 50.0, Enemy.MovePattern.RANDOM, 50.0)
			# 启动生成计时器
			_start_survival_spawner()

## 生成单个敌人
func _spawn_enemy(pos: Vector2, health: float, pattern: Enemy.MovePattern, speed: float = 0.0) -> Enemy:
	var enemy = enemy_scene.instantiate() as Enemy
	enemy_container.add_child(enemy)
	enemy.global_position = pos
	enemy.max_health = health
	enemy.current_health = health
	enemy.move_pattern = pattern
	enemy.move_speed = speed
	
	enemy.damage_taken.connect(_on_enemy_damage_taken)
	enemy.enemy_died.connect(_on_enemy_died)
	
	return enemy

## 清除所有敌人
func _clear_enemies() -> void:
	for child in enemy_container.get_children():
		child.queue_free()

## 敌人受伤
func _on_enemy_damage_taken(amount: float) -> void:
	total_damage_dealt += amount

## 敌人死亡
func _on_enemy_died(enemy: Enemy) -> void:
	enemies_killed += 1
	
	# 生存模式下补充敌人
	if is_running and current_scenario == TestScenario.SURVIVAL:
		var battle_center = battle_area.position + battle_area.size / 2
		var spawn_pos = battle_center + Vector2(randf_range(200, 400), randf_range(-150, 150))
		_spawn_enemy(spawn_pos, 50.0 + enemies_killed * 5.0, Enemy.MovePattern.RANDOM, 50.0 + enemies_killed * 2.0)

## 启动生存模式生成器
func _start_survival_spawner() -> void:
	var timer = Timer.new()
	timer.wait_time = 3.0
	timer.timeout.connect(_on_survival_spawn_timer)
	add_child(timer)
	timer.start()

## 生存模式定时生成
func _on_survival_spawn_timer() -> void:
	if not is_running or current_scenario != TestScenario.SURVIVAL:
		return
	
	var battle_center = battle_area.position + battle_area.size / 2
	var spawn_pos = battle_center + Vector2(randf_range(200, 400), randf_range(-150, 150))
	_spawn_enemy(spawn_pos, 50.0 + enemies_killed * 3.0, Enemy.MovePattern.RANDOM, 40.0)

## 更新统计显示
func _update_stats_display() -> void:
	var caster_stats = spell_caster.get_stats()
	
	# DPS 计算
	var dps = 0.0
	if test_duration > 0:
		dps = total_damage_dealt / test_duration
	
	dps_label.text = "DPS: %.1f" % dps
	hit_rate_label.text = "命中率: %.1f%%" % caster_stats.hit_rate
	
	# 更新详细统计
	var stats_text = "[b]测试统计[/b]\n\n"
	stats_text += "测试时间: %.1fs\n" % test_duration
	stats_text += "总伤害: %.0f\n" % total_damage_dealt
	stats_text += "击杀数: %d\n" % enemies_killed
	stats_text += "发射数: %d\n" % caster_stats.total_shots
	stats_text += "命中数: %d\n" % caster_stats.total_hits
	stats_text += "裂变次数: %d\n" % caster_stats.fissions_triggered
	stats_text += "活跃子弹: %d\n" % caster_stats.active_projectiles
	
	stats_label.text = stats_text

## 显示最终结果
func _show_final_results() -> void:
	var caster_stats = spell_caster.get_stats()
	var dps = total_damage_dealt / test_duration if test_duration > 0 else 0.0
	
	var result_text = "[b]===== 测试结果 =====[/b]\n\n"
	result_text += "[u]效率指标[/u]\n"
	result_text += "DPS: %.1f\n" % dps
	result_text += "命中率: %.1f%%\n" % caster_stats.hit_rate
	result_text += "每发伤害: %.1f\n" % (total_damage_dealt / caster_stats.total_shots if caster_stats.total_shots > 0 else 0)
	result_text += "\n[u]总计[/u]\n"
	result_text += "测试时间: %.1fs\n" % test_duration
	result_text += "总伤害: %.0f\n" % total_damage_dealt
	result_text += "击杀数: %d\n" % enemies_killed
	result_text += "发射数: %d\n" % caster_stats.total_shots
	result_text += "裂变次数: %d\n" % caster_stats.fissions_triggered
	
	stats_label.text = result_text

## 手动发射（鼠标点击）
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if current_spell_index >= 0 and not spell_caster.auto_fire:
				spell_caster.fire(event.position)
