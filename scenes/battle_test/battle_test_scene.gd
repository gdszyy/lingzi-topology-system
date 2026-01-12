extends Node2D

enum TestScenario {
	SINGLE_TARGET,
	GROUP_TARGETS,
	MOVING_TARGETS,
	SURVIVAL,
	CLOSE_RANGE,
	DUMMY_TARGETS,
	SHIELD_TEST
}

@onready var scenario_option: OptionButton = $UI/TopPanel/ScenarioOption
@onready var start_button: Button = $UI/TopPanel/StartButton
@onready var stop_button: Button = $UI/TopPanel/StopButton
@onready var reset_button: Button = $UI/TopPanel/ResetButton
@onready var spell_list: ItemList = $UI/LeftPanel/SpellList
@onready var load_from_ga_button: Button = $UI/LeftPanel/LoadFromGAButton
@onready var back_button: Button = $UI/TopPanel/BackButton
@onready var new_spell_button: Button = $UI/LeftPanel/NewSpellButton
@onready var edit_spell_button: Button = $UI/LeftPanel/EditSpellButton
@onready var delete_spell_button: Button = $UI/LeftPanel/DeleteSpellButton
@onready var generate_batch_button: Button = $UI/LeftPanel/GenerateBatchButton

var spell_editor_scene: PackedScene
var spell_editor: SpellEditor = null

@onready var stats_label: RichTextLabel = $UI/RightPanel/StatsLabel
@onready var dps_label: Label = $UI/RightPanel/DPSLabel
@onready var hit_rate_label: Label = $UI/RightPanel/HitRateLabel

@onready var spell_caster: SpellCaster = $SpellCaster
@onready var enemy_container: Node2D = $EnemyContainer
@onready var battle_area: ColorRect = $BattleArea

var enemy_scene: PackedScene
var dummy_enemy_scene: PackedScene
var attacking_enemy_scene: PackedScene

var batch_generator: BatchSpellGenerator

var current_scenario: TestScenario = TestScenario.SINGLE_TARGET
var is_running: bool = false
var test_duration: float = 0.0
var available_spells: Array[SpellCoreData] = []
var current_spell_index: int = -1

var total_damage_dealt: float = 0.0
var enemies_killed: int = 0
var test_start_time: float = 0.0

var player_position: Vector2

var survival_timer: Timer = null

var last_batch_result: Dictionary = {}

# 护盾测试统计
var shield_test_stats = {
	"current_shield": 0.0,
	"damage_absorbed": 0.0,
	"shield_activations": 0,
	"shield_breaks": 0,
	"attacks_received": 0
}

var shield_test_timer: Timer = null
var shield_test_player: Node2D = null

func _ready():
	# 创建运行时系统管理器（用于处理链式、护盾、状态等效果）
	var runtime_manager = RuntimeSystemsManager.new()
	runtime_manager.name = "RuntimeSystemsManager"
	add_child(runtime_manager)
	print("[BattleTestScene] RuntimeSystemsManager 已创建并添加到场景")
	
	enemy_scene = preload("res://scenes/battle_test/entities/enemy.tscn")
	dummy_enemy_scene = preload("res://scenes/battle_test/entities/dummy_enemy.tscn")
	attacking_enemy_scene = preload("res://scenes/battle_test/entities/attacking_enemy.tscn")
	spell_editor_scene = preload("res://scenes/battle_test/spell_editor.tscn")

	batch_generator = BatchSpellGenerator.new()
	batch_generator.batch_generated.connect(_on_batch_generated)
	batch_generator.all_batches_completed.connect(_on_all_batches_completed)

	_setup_ui()
	_setup_scenario_options()
	_create_default_spell()

	player_position = spell_caster.global_position

func _process(delta: float) -> void:
	if is_running:
		test_duration += delta
		_update_stats_display()

		_update_enemy_targets()

		if current_scenario == TestScenario.CLOSE_RANGE or current_scenario == TestScenario.SURVIVAL:
			_check_enemy_reach_player()
		
		if current_scenario == TestScenario.SHIELD_TEST:
			_update_shield_test_stats()

func _setup_ui() -> void:
	start_button.pressed.connect(_on_start_pressed)
	stop_button.pressed.connect(_on_stop_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	load_from_ga_button.pressed.connect(_on_load_from_ga_pressed)
	scenario_option.item_selected.connect(_on_scenario_selected)
	spell_list.item_selected.connect(_on_spell_selected)
	back_button.pressed.connect(_on_back_pressed)

	new_spell_button.pressed.connect(_on_new_spell_pressed)
	edit_spell_button.pressed.connect(_on_edit_spell_pressed)
	delete_spell_button.pressed.connect(_on_delete_spell_pressed)

	if generate_batch_button:
		generate_batch_button.pressed.connect(_on_generate_batch_pressed)

	stop_button.disabled = true

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")

func _setup_scenario_options() -> void:
	scenario_option.clear()
	scenario_option.add_item("单体目标", TestScenario.SINGLE_TARGET)
	scenario_option.add_item("群体目标 (5个)", TestScenario.GROUP_TARGETS)
	scenario_option.add_item("移动目标", TestScenario.MOVING_TARGETS)
	scenario_option.add_item("生存模式 (敌人接近)", TestScenario.SURVIVAL)
	scenario_option.add_item("近战场景", TestScenario.CLOSE_RANGE)
	scenario_option.add_item("沙包测试 (不死亡)", TestScenario.DUMMY_TARGETS)
	scenario_option.add_item("护盾测试", TestScenario.SHIELD_TEST)

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
	
	# 添加护盾测试法术
	var shield_spell = _create_shield_test_spell()
	available_spells.append(shield_spell)
	
	_update_spell_list()

func _update_spell_list() -> void:
	spell_list.clear()
	for i in range(available_spells.size()):
		var spell = available_spells[i]
		spell_list.add_item("%d. %s [Cost: %.1f]" % [i + 1, spell.spell_name, spell.resource_cost])

func _on_scenario_selected(index: int) -> void:
	current_scenario = index as TestScenario

func _on_spell_selected(index: int) -> void:
	current_spell_index = index
	if index >= 0 and index < available_spells.size():
		spell_caster.set_spell(available_spells[index])
		_display_spell_info(available_spells[index])

func _display_spell_info(spell: SpellCoreData) -> void:
	var info = "[b]%s[/b]\n" % spell.spell_name
	info += "[color=yellow]Cost: %.1f[/color] | CD: %.1fs\n\n" % [spell.resource_cost, spell.cooldown]

	if spell.carrier != null:
		var phase_names = ["固态", "液态", "等离子态"]
		var type_names = ["投射物", "地雷", "慢速球"]
		info += "[u]载体配置[/u]\n"
		info += "类型: %s\n" % type_names[spell.carrier.carrier_type]
		info += "相态: %s\n" % phase_names[spell.carrier.phase]
		info += "速度: %.0f (实际: %.0f)\n" % [spell.carrier.velocity, spell.carrier.get_effective_velocity()]
		info += "存活: %.1fs (实际: %.1fs)\n" % [spell.carrier.lifetime, spell.carrier.get_effective_lifetime()]
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

	_clear_enemies()

	_spawn_enemies_for_scenario()

	spell_caster.auto_fire = true
	spell_caster.fire_rate = 2.0

func _on_stop_pressed() -> void:
	is_running = false
	spell_caster.auto_fire = false
	spell_caster.clear_projectiles()

	start_button.disabled = false
	stop_button.disabled = true

	if survival_timer != null:
		survival_timer.stop()
	
	if shield_test_timer != null:
		shield_test_timer.stop()

	_show_final_results()

func _on_reset_pressed() -> void:
	_on_stop_pressed()
	_clear_enemies()
	spell_caster.reset_stats()
	test_duration = 0.0
	total_damage_dealt = 0.0
	enemies_killed = 0
	
	# 重置护盾测试统计
	shield_test_stats.current_shield = 0.0
	shield_test_stats.damage_absorbed = 0.0
	shield_test_stats.shield_activations = 0
	shield_test_stats.shield_breaks = 0
	shield_test_stats.attacks_received = 0
	
	# 清理护盾测试玩家
	if shield_test_player != null:
		shield_test_player.queue_free()
		shield_test_player = null

	for enemy in enemy_container.get_children():
		if enemy is DummyEnemy:
			enemy.reset_stats()

func _on_load_from_ga_pressed() -> void:
	var ga_manager = get_node_or_null("/root/GeneticAlgorithmManager")
	if ga_manager == null:
		push_warning("GeneticAlgorithmManager 未找到")
		return

	if ga_manager.top_spells.size() > 0:
		for spell in ga_manager.top_spells:
			if not _spell_exists(spell):
				available_spells.append(spell)
		_update_spell_list()
	elif ga_manager.best_spell != null:
		if not _spell_exists(ga_manager.best_spell):
			available_spells.append(ga_manager.best_spell)
		_update_spell_list()

func _on_generate_batch_pressed() -> void:
	print("开始批量生成法术...")
	last_batch_result = batch_generator.generate_all_batches()

	for batch_idx in last_batch_result:
		var batch = last_batch_result[batch_idx]
		for scenario_key in batch:
			for spell in batch[scenario_key]:
				if not _spell_exists(spell):
					available_spells.append(spell)

	_update_spell_list()

	_display_batch_statistics()

func _on_batch_generated(batch_index: int, spells: Dictionary) -> void:
	print("批次 %d 生成完成，包含 %d 个场景" % [batch_index + 1, spells.size()])

func _on_all_batches_completed(all_spells: Dictionary) -> void:
	print("所有批次生成完成，共 %d 批" % all_spells.size())

func _display_batch_statistics() -> void:
	if last_batch_result.is_empty():
		return

	var total_spells = 0
	var stats_text = "[b]===== 批量生成统计 =====[/b]\n\n"

	for batch_idx in last_batch_result:
		var batch = last_batch_result[batch_idx]
		var batch_stats = batch_generator.get_batch_statistics(batch)

		stats_text += "[u]批次 %d[/u]\n" % (batch_idx + 1)
		stats_text += "法术数: %d\n" % batch_stats.total_spells
		stats_text += "平均差异度: %.2f\n" % batch_stats.avg_diversity
		stats_text += "嵌套分布: 0层=%d, 1层=%d, 2层=%d, 3层=%d\n\n" % [
			batch_stats.nesting_distribution["0"],
			batch_stats.nesting_distribution["1"],
			batch_stats.nesting_distribution["2"],
			batch_stats.nesting_distribution["3"]
		]

		total_spells += batch_stats.total_spells

	stats_text += "[color=green]总计生成: %d 个法术[/color]\n" % total_spells
	stats_label.text = stats_text

func _spell_exists(spell: SpellCoreData) -> bool:
	for existing in available_spells:
		if existing.spell_id == spell.spell_id:
			return true
	return false

func _spawn_enemies_for_scenario() -> void:
	var battle_center = battle_area.position + battle_area.size / 2

	match current_scenario:
		TestScenario.SINGLE_TARGET:
			_spawn_enemy_deferred(battle_center + Vector2(300, 0), 200.0, Enemy.MovePattern.STATIC)

		TestScenario.GROUP_TARGETS:
			_spawn_enemy_deferred(battle_center + Vector2(250, -100), 80.0, Enemy.MovePattern.STATIC)
			_spawn_enemy_deferred(battle_center + Vector2(300, 0), 80.0, Enemy.MovePattern.STATIC)
			_spawn_enemy_deferred(battle_center + Vector2(250, 100), 80.0, Enemy.MovePattern.STATIC)
			_spawn_enemy_deferred(battle_center + Vector2(350, -50), 80.0, Enemy.MovePattern.STATIC)
			_spawn_enemy_deferred(battle_center + Vector2(350, 50), 80.0, Enemy.MovePattern.STATIC)

		TestScenario.MOVING_TARGETS:
			_spawn_enemy_deferred(battle_center + Vector2(300, -80), 100.0, Enemy.MovePattern.HORIZONTAL, 80.0)
			_spawn_enemy_deferred(battle_center + Vector2(300, 80), 100.0, Enemy.MovePattern.CIRCULAR, 60.0)
			_spawn_enemy_deferred(battle_center + Vector2(400, 0), 100.0, Enemy.MovePattern.RANDOM, 100.0)

		TestScenario.SURVIVAL:
			_spawn_approaching_enemy(battle_center + Vector2(500, 0), 60.0, 80.0)
			_spawn_approaching_enemy(battle_center + Vector2(450, -100), 60.0, 70.0)
			_spawn_approaching_enemy(battle_center + Vector2(450, 100), 60.0, 70.0)
			_start_survival_spawner()

		TestScenario.CLOSE_RANGE:
			_spawn_approaching_enemy(battle_center + Vector2(200, 0), 80.0, 120.0)
			_spawn_approaching_enemy(battle_center + Vector2(-200, 0), 80.0, 120.0)
			_spawn_approaching_enemy(battle_center + Vector2(0, 150), 80.0, 100.0)
			_spawn_approaching_enemy(battle_center + Vector2(0, -150), 80.0, 100.0)
			_start_close_range_spawner()

		TestScenario.DUMMY_TARGETS:
			_spawn_dummy_enemy(battle_center + Vector2(300, 0), DummyEnemy.MovePattern.PATROL, 80.0)
			_spawn_dummy_enemy(battle_center + Vector2(250, -120), DummyEnemy.MovePattern.CIRCULAR, 60.0)
			_spawn_dummy_enemy(battle_center + Vector2(250, 120), DummyEnemy.MovePattern.FIGURE_EIGHT, 70.0)
			_spawn_dummy_enemy(battle_center + Vector2(400, -80), DummyEnemy.MovePattern.RANDOM_WALK, 90.0)
			_spawn_dummy_enemy(battle_center + Vector2(400, 80), DummyEnemy.MovePattern.ORBIT, 100.0)
			call_deferred("_setup_orbit_dummy", battle_center)
		
		TestScenario.SHIELD_TEST:
			_spawn_attacking_enemy(battle_center + Vector2(250, 0), 100.0, 80.0, 15.0, 1.5)
			_spawn_attacking_enemy(battle_center + Vector2(200, -150), 80.0, 70.0, 10.0, 2.0)
			_spawn_attacking_enemy(battle_center + Vector2(200, 150), 80.0, 70.0, 10.0, 2.0)
			_start_shield_test_spawner()

func _setup_orbit_dummy(center: Vector2) -> void:
	for enemy in enemy_container.get_children():
		if enemy is DummyEnemy and enemy.move_pattern == DummyEnemy.MovePattern.ORBIT:
			enemy.set_orbit_center(center + Vector2(350, 0), 120.0)

func _spawn_dummy_enemy(pos: Vector2, pattern: DummyEnemy.MovePattern, speed: float) -> void:
	call_deferred("_spawn_dummy_enemy_internal", pos, pattern, speed)

func _spawn_dummy_enemy_internal(pos: Vector2, pattern: DummyEnemy.MovePattern, speed: float) -> DummyEnemy:
	var dummy = dummy_enemy_scene.instantiate() as DummyEnemy
	enemy_container.add_child(dummy)
	dummy.global_position = pos
	dummy.move_pattern = pattern
	dummy.move_speed = speed

	dummy.damage_taken.connect(_on_enemy_damage_taken)

	return dummy

func _spawn_approaching_enemy(pos: Vector2, health: float, speed: float, zigzag: bool = false) -> void:
	var pattern = Enemy.MovePattern.APPROACH_ZIGZAG if zigzag else Enemy.MovePattern.APPROACH
	call_deferred("_spawn_enemy_internal", pos, health, pattern, speed)

func _spawn_enemy_deferred(pos: Vector2, health: float, pattern: Enemy.MovePattern, speed: float = 0.0) -> void:
	call_deferred("_spawn_enemy_internal", pos, health, pattern, speed)

func _spawn_enemy_internal(pos: Vector2, health: float, pattern: Enemy.MovePattern, speed: float = 0.0) -> Enemy:
	var enemy = enemy_scene.instantiate() as Enemy
	enemy_container.add_child(enemy)
	enemy.global_position = pos
	# 使用新的能量系统设置敌人属性
	enemy.set_max_energy_cap(health)
	enemy.move_pattern = pattern
	enemy.move_speed = speed
	enemy.set_target_position(player_position)

	enemy.damage_taken.connect(_on_enemy_damage_taken)
	enemy.enemy_died.connect(_on_enemy_died)

	return enemy

func _clear_enemies() -> void:
	for child in enemy_container.get_children():
		child.queue_free()

func _on_enemy_damage_taken(amount: float) -> void:
	total_damage_dealt += amount

func _on_enemy_died(_enemy: Enemy) -> void:
	enemies_killed += 1

	if is_running:
		var battle_center = battle_area.position + battle_area.size / 2

		if current_scenario == TestScenario.SURVIVAL:
			var angle = randf() * TAU
			var distance = randf_range(400, 600)
			var spawn_pos = battle_center + Vector2(cos(angle), sin(angle)) * distance
			var health = 60.0 + enemies_killed * 5.0
			var speed = 80.0 + enemies_killed * 3.0
			var use_zigzag = randf() > 0.5
			call_deferred("_spawn_approaching_enemy", spawn_pos, health, speed, use_zigzag)

		elif current_scenario == TestScenario.CLOSE_RANGE:
			var angle = randf() * TAU
			var distance = randf_range(150, 250)
			var spawn_pos = battle_center + Vector2(cos(angle), sin(angle)) * distance
			var health = 80.0 + enemies_killed * 3.0
			var speed = 120.0 + enemies_killed * 5.0
			call_deferred("_spawn_approaching_enemy", spawn_pos, health, speed, true)

func _start_survival_spawner() -> void:
	if survival_timer != null:
		survival_timer.queue_free()

	survival_timer = Timer.new()
	survival_timer.wait_time = 2.5
	survival_timer.timeout.connect(_on_survival_spawn_timer)
	add_child(survival_timer)
	survival_timer.start()

func _start_close_range_spawner() -> void:
	if survival_timer != null:
		survival_timer.queue_free()

	survival_timer = Timer.new()
	survival_timer.wait_time = 1.5
	survival_timer.timeout.connect(_on_close_range_spawn_timer)
	add_child(survival_timer)
	survival_timer.start()

func _on_survival_spawn_timer() -> void:
	if not is_running or current_scenario != TestScenario.SURVIVAL:
		return

	var battle_center = battle_area.position + battle_area.size / 2
	var angle = randf() * TAU
	var distance = randf_range(400, 600)
	var spawn_pos = battle_center + Vector2(cos(angle), sin(angle)) * distance
	var health = 60.0 + enemies_killed * 3.0
	var speed = 80.0 + mini(enemies_killed * 2, 50)
	var use_zigzag = randf() > 0.6
	_spawn_approaching_enemy(spawn_pos, health, speed, use_zigzag)

func _on_close_range_spawn_timer() -> void:
	if not is_running or current_scenario != TestScenario.CLOSE_RANGE:
		return

	var battle_center = battle_area.position + battle_area.size / 2
	var angle = randf() * TAU
	var distance = randf_range(150, 300)
	var spawn_pos = battle_center + Vector2(cos(angle), sin(angle)) * distance
	var health = 80.0 + enemies_killed * 2.0
	var speed = 120.0 + mini(enemies_killed * 3, 80)
	_spawn_approaching_enemy(spawn_pos, health, speed, true)

func _update_enemy_targets() -> void:
	for enemy in enemy_container.get_children():
		if enemy is Enemy:
			enemy.set_target_position(player_position)
		elif enemy is AttackingEnemy:
			enemy.set_target_position(player_position)

func _check_enemy_reach_player() -> void:
	for enemy in enemy_container.get_children():
		if enemy is Enemy:
			var distance = enemy.global_position.distance_to(player_position)
			if distance < 30.0:
				enemy.take_damage(enemy.current_health)

func _update_stats_display() -> void:
	var caster_stats = spell_caster.get_stats()

	var dps = 0.0
	if test_duration > 0:
		dps = total_damage_dealt / test_duration

	dps_label.text = "DPS: %.1f" % dps
	hit_rate_label.text = "命中率: %.1f%%" % caster_stats.hit_rate

	var stats_text = "[b]测试统计[/b]\n\n"
	stats_text += "测试时间: %.1fs\n" % test_duration
	stats_text += "总伤害: %.0f\n" % total_damage_dealt
	stats_text += "击杀数: %d\n" % enemies_killed
	stats_text += "发射数: %d\n" % caster_stats.total_shots
	stats_text += "命中数: %d\n" % caster_stats.total_hits
	stats_text += "裂变次数: %d\n" % caster_stats.fissions_triggered
	stats_text += "活跃子弹: %d\n" % caster_stats.active_projectiles

	var scenario_names = ["单体目标", "群体目标", "移动目标", "生存模式", "近战场景", "沙包测试", "护盾测试"]
	stats_text += "\n[u]场景: %s[/u]\n" % scenario_names[current_scenario]

	if current_scenario == TestScenario.SURVIVAL or current_scenario == TestScenario.CLOSE_RANGE:
		var enemy_count = enemy_container.get_child_count()
		stats_text += "当前敌人数: %d\n" % enemy_count
	
	if current_scenario == TestScenario.SHIELD_TEST:
		stats_text += "\n[u]护盾统计[/u]\n"
		stats_text += "护盾值: %.0f\n" % shield_test_stats.current_shield
		stats_text += "吸收伤害: %.0f\n" % shield_test_stats.damage_absorbed
		stats_text += "护盾激活次数: %d\n" % shield_test_stats.shield_activations
		stats_text += "护盾破碎次数: %d\n" % shield_test_stats.shield_breaks
		stats_text += "受到攻击: %d\n" % shield_test_stats.attacks_received
		var enemy_count = enemy_container.get_child_count()
		stats_text += "当前敌人数: %d\n" % enemy_count

	if current_scenario == TestScenario.DUMMY_TARGETS:
		stats_text += "\n[u]沙包统计[/u]\n"
		var dummy_index = 1
		for enemy in enemy_container.get_children():
			if enemy is DummyEnemy:
				var dummy_stats = enemy.get_stats()
				stats_text += "沙包%d: 伤害=%.0f, 命中=%d\n" % [
					dummy_index,
					dummy_stats.total_damage,
					dummy_stats.hit_count
				]
				dummy_index += 1

	stats_label.text = stats_text

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

	if current_scenario == TestScenario.DUMMY_TARGETS:
		result_text += "\n[u]沙包详细统计[/u]\n"
		var pattern_names = ["巡逻", "圆周", "8字形", "随机", "轨道"]
		var dummy_index = 1
		for enemy in enemy_container.get_children():
			if enemy is DummyEnemy:
				var dummy_stats = enemy.get_stats()
				result_text += "沙包%d (%s):\n" % [dummy_index, pattern_names[dummy_stats.move_pattern]]
				result_text += "  总伤害: %.0f\n" % dummy_stats.total_damage
				result_text += "  命中次数: %d\n" % dummy_stats.hit_count
				result_text += "  平均单次伤害: %.1f\n" % dummy_stats.avg_damage_per_hit
				dummy_index += 1
	
	if current_scenario == TestScenario.SHIELD_TEST:
		result_text += "\n[u]护盾测试结果[/u]\n"
		result_text += "护盾激活次数: %d\n" % shield_test_stats.shield_activations
		result_text += "护盾破碎次数: %d\n" % shield_test_stats.shield_breaks
		result_text += "总吸收伤害: %.0f\n" % shield_test_stats.damage_absorbed
		result_text += "受到攻击次数: %d\n" % shield_test_stats.attacks_received
		if shield_test_stats.attacks_received > 0:
			var avg_absorbed = shield_test_stats.damage_absorbed / shield_test_stats.attacks_received
			result_text += "平均每次吸收: %.1f\n" % avg_absorbed
		if shield_test_stats.shield_activations > 0:
			var avg_per_shield = shield_test_stats.damage_absorbed / shield_test_stats.shield_activations
			result_text += "每次护盾平均吸收: %.1f\n" % avg_per_shield

	stats_label.text = result_text

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if current_spell_index >= 0 and not spell_caster.auto_fire:
				spell_caster.fire(event.position)

func _on_new_spell_pressed() -> void:
	_open_spell_editor(null)

func _on_edit_spell_pressed() -> void:
	if current_spell_index < 0 or current_spell_index >= available_spells.size():
		return
	_open_spell_editor(available_spells[current_spell_index])

func _on_delete_spell_pressed() -> void:
	if current_spell_index < 0 or current_spell_index >= available_spells.size():
		return

	available_spells.remove_at(current_spell_index)
	current_spell_index = -1
	_update_spell_list()
	stats_label.text = "选择一个法术开始测试..."

func _open_spell_editor(spell: SpellCoreData) -> void:
	if spell_editor != null:
		spell_editor.queue_free()

	spell_editor = spell_editor_scene.instantiate() as SpellEditor
	spell_editor.spell_saved.connect(_on_spell_editor_saved)
	spell_editor.editor_closed.connect(_on_spell_editor_closed)

	$UI.add_child(spell_editor)
	spell_editor.edit_spell(spell)

func _on_spell_editor_saved(spell: SpellCoreData) -> void:
	var found_index = -1
	for i in range(available_spells.size()):
		if available_spells[i].spell_id == spell.spell_id:
			found_index = i
			break

	if found_index >= 0:
		available_spells[found_index] = spell
	else:
		available_spells.append(spell)

	_update_spell_list()

	for i in range(available_spells.size()):
		if available_spells[i].spell_id == spell.spell_id:
			spell_list.select(i)
			_on_spell_selected(i)
			break

	_cleanup_spell_editor()

func _on_spell_editor_closed() -> void:
	_cleanup_spell_editor()

func _cleanup_spell_editor() -> void:
	if spell_editor != null:
		spell_editor.queue_free()
		spell_editor = null


## ========== 护盾测试相关函数 ==========

func _spawn_attacking_enemy(pos: Vector2, health: float, speed: float, damage: float, cooldown: float) -> void:
	call_deferred("_spawn_attacking_enemy_internal", pos, health, speed, damage, cooldown)

func _spawn_attacking_enemy_internal(pos: Vector2, health: float, speed: float, damage: float, cooldown: float) -> AttackingEnemy:
	var enemy = attacking_enemy_scene.instantiate() as AttackingEnemy
	enemy_container.add_child(enemy)
	enemy.global_position = pos
	enemy.set_max_energy_cap(health)
	enemy.move_speed = speed
	enemy.attack_damage = damage
	enemy.attack_cooldown = cooldown
	enemy.set_target_position(player_position)
	
	enemy.damage_taken.connect(_on_enemy_damage_taken)
	enemy.enemy_died.connect(_on_attacking_enemy_died)
	enemy.attack_performed.connect(_on_enemy_attack_performed)
	
	return enemy

func _on_attacking_enemy_died(_enemy: AttackingEnemy) -> void:
	enemies_killed += 1
	
	if is_running and current_scenario == TestScenario.SHIELD_TEST:
		# 生成新的攻击型敌人
		var battle_center = battle_area.position + battle_area.size / 2
		var angle = randf() * TAU
		var distance = randf_range(200, 350)
		var spawn_pos = battle_center + Vector2(cos(angle), sin(angle)) * distance
		var health = 80.0 + enemies_killed * 5.0
		var speed = 70.0 + mini(enemies_killed * 2, 40)
		var damage = 10.0 + enemies_killed * 0.5
		var cooldown = maxf(1.0, 2.0 - enemies_killed * 0.05)
		_spawn_attacking_enemy(spawn_pos, health, speed, damage, cooldown)

func _on_enemy_attack_performed(damage: float) -> void:
	shield_test_stats.attacks_received += 1
	
	# 检查护盾状态
	if shield_test_player and is_instance_valid(shield_test_player):
		var old_shield = shield_test_stats.current_shield
		shield_test_stats.current_shield = shield_test_player.current_shield
		
		if old_shield > 0 and shield_test_stats.current_shield < old_shield:
			var absorbed = old_shield - shield_test_stats.current_shield
			shield_test_stats.damage_absorbed += absorbed
		
		if old_shield > 0 and shield_test_stats.current_shield <= 0:
			shield_test_stats.shield_breaks += 1

func _start_shield_test_spawner() -> void:
	if shield_test_timer != null:
		shield_test_timer.queue_free()
	
	shield_test_timer = Timer.new()
	shield_test_timer.wait_time = 3.0
	shield_test_timer.timeout.connect(_on_shield_test_spawn_timer)
	add_child(shield_test_timer)
	shield_test_timer.start()
	
	# 创建测试用玩家实体
	_setup_shield_test_player()

func _setup_shield_test_player() -> void:
	# 创建一个简单的玩家实体用于护盾测试
	if shield_test_player != null:
		shield_test_player.queue_free()
	
	shield_test_player = Node2D.new()
	shield_test_player.name = "ShieldTestPlayer"
	shield_test_player.set_script(load("res://scenes/battle_test/shield_test_player.gd"))
	shield_test_player.global_position = player_position
	add_child(shield_test_player)
	
	shield_test_player.add_to_group("players")
	
	# 连接护盾信号
	if shield_test_player.has_signal("shield_changed"):
		shield_test_player.shield_changed.connect(_on_shield_test_player_shield_changed)
	
	# 重置统计
	shield_test_stats.current_shield = 0.0
	shield_test_stats.damage_absorbed = 0.0
	shield_test_stats.shield_activations = 0
	shield_test_stats.shield_breaks = 0
	shield_test_stats.attacks_received = 0

func _on_shield_test_player_shield_changed(new_shield: float, old_shield: float) -> void:
	shield_test_stats.current_shield = new_shield
	
	if new_shield > old_shield:
		shield_test_stats.shield_activations += 1
	elif old_shield > 0 and new_shield <= 0:
		shield_test_stats.shield_breaks += 1

func _on_shield_test_spawn_timer() -> void:
	if not is_running or current_scenario != TestScenario.SHIELD_TEST:
		return
	
	var battle_center = battle_area.position + battle_area.size / 2
	var angle = randf() * TAU
	var distance = randf_range(250, 400)
	var spawn_pos = battle_center + Vector2(cos(angle), sin(angle)) * distance
	var health = 80.0 + enemies_killed * 3.0
	var speed = 70.0 + mini(enemies_killed * 2, 50)
	var damage = 10.0 + enemies_killed * 0.3
	var cooldown = maxf(1.0, 2.0 - enemies_killed * 0.03)
	_spawn_attacking_enemy(spawn_pos, health, speed, damage, cooldown)

func _update_shield_test_targets() -> void:
	for enemy in enemy_container.get_children():
		if enemy is AttackingEnemy:
			enemy.set_target_position(player_position)

func _create_shield_test_spell() -> SpellCoreData:
	## 创建一个护盾测试法术
	var spell = SpellCoreData.new()
	spell.generate_id()
	spell.spell_name = "测试护盾"
	spell.description = "生成一个护盾保护自身"
	spell.spell_type = SpellCoreData.SpellType.ENGRAVING
	spell.resource_cost = 15.0
	spell.cooldown = 3.0
	
	var trigger = TriggerData.new()
	trigger.trigger_type = TriggerData.TriggerType.ON_TAKE_DAMAGE
	trigger.trigger_once = false
	
	var shield_action = ShieldActionData.new()
	shield_action.shield_type = ShieldActionData.ShieldType.PERSONAL
	shield_action.shield_amount = 30.0
	shield_action.shield_duration = 5.0
	
	var rule = TopologyRuleData.new()
	rule.rule_name = "受伤护盾"
	rule.trigger = trigger
	var actions: Array[ActionData] = [shield_action]
	rule.actions = actions
	
	var rules: Array[TopologyRuleData] = [rule]
	spell.topology_rules = rules
	
	return spell


func _update_shield_test_stats() -> void:
	# 更新护盾测试玩家的护盾状态
	if shield_test_player and is_instance_valid(shield_test_player):
		shield_test_stats.current_shield = shield_test_player.current_shield
