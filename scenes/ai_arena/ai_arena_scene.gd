extends Node2D

## AI演武厂场景
## 用于测试和演示敌人AI系统
## 支持多种敌人类型、波次战斗、AI行为调试

signal wave_completed(wave_number: int)
signal battle_ended(result: String)

# 节点引用
@onready var player: PlayerController = $Player
@onready var enemy_container: Node2D = $EnemyContainer
@onready var enemy_manager: EnemyManager = $EnemyManager
@onready var arena_bounds: Area2D = $ArenaBounds

# UI节点
@onready var ui: Control = $UI
@onready var wave_label: Label = $UI/TopPanel/WaveLabel
@onready var enemy_count_label: Label = $UI/TopPanel/EnemyCountLabel
@onready var player_health_bar: ProgressBar = $UI/TopPanel/PlayerHealthBar
@onready var score_label: Label = $UI/TopPanel/ScoreLabel
@onready var back_button: Button = $UI/TopPanel/BackButton

# 控制面板
@onready var spawn_panel: Control = $UI/SpawnPanel
@onready var enemy_type_list: ItemList = $UI/SpawnPanel/EnemyTypeList
@onready var spawn_button: Button = $UI/SpawnPanel/SpawnButton
@onready var spawn_count_spinbox: SpinBox = $UI/SpawnPanel/SpawnCountSpinBox
@onready var start_wave_button: Button = $UI/SpawnPanel/StartWaveButton
@onready var clear_button: Button = $UI/SpawnPanel/ClearButton

# 调试面板
@onready var debug_panel: Control = $UI/DebugPanel
@onready var debug_toggle: CheckButton = $UI/DebugPanel/DebugToggle
@onready var ai_info_label: RichTextLabel = $UI/DebugPanel/AIInfoLabel

# 敌人预设
var enemy_presets: Array[Dictionary] = []

# 游戏状态
var current_wave: int = 0
var total_score: int = 0
var enemies_killed: int = 0
var is_wave_active: bool = false
var debug_mode: bool = false

# 波次配置
var wave_configs: Array[Dictionary] = [
	{"enemy_count": 3, "types": [0], "spawn_delay": 1.0},
	{"enemy_count": 5, "types": [0, 1], "spawn_delay": 0.8},
	{"enemy_count": 7, "types": [0, 1, 2], "spawn_delay": 0.6},
	{"enemy_count": 10, "types": [0, 1, 2, 3], "spawn_delay": 0.5},
	{"enemy_count": 15, "types": [0, 1, 2, 3, 4], "spawn_delay": 0.4}
]

func _ready() -> void:
	_initialize_enemy_presets()
	_setup_ui()
	_connect_signals()
	_update_ui()

func _process(_delta: float) -> void:
	_update_ui()
	
	if debug_mode:
		_update_debug_info()

## 初始化敌人预设
func _initialize_enemy_presets() -> void:
	enemy_presets = [
		{
			"name": "近战小兵",
			"profile": AIBehaviorProfile.create_melee_aggressive(),
			"color": Color(0.8, 0.2, 0.2),
			"health": 80.0,
			"score": 10
		},
		{
			"name": "远程射手",
			"profile": AIBehaviorProfile.create_ranged_sniper(),
			"color": Color(0.2, 0.6, 0.8),
			"health": 60.0,
			"score": 15
		},
		{
			"name": "刺客",
			"profile": AIBehaviorProfile.create_assassin(),
			"color": Color(0.5, 0.2, 0.8),
			"health": 50.0,
			"score": 20
		},
		{
			"name": "坦克",
			"profile": AIBehaviorProfile.create_tank(),
			"color": Color(0.4, 0.4, 0.4),
			"health": 200.0,
			"score": 25
		},
		{
			"name": "蜂群兵",
			"profile": AIBehaviorProfile.create_swarm(),
			"color": Color(0.6, 0.6, 0.2),
			"health": 30.0,
			"score": 5
		}
	]

## 设置UI
func _setup_ui() -> void:
	# 返回按钮
	back_button.pressed.connect(_on_back_pressed)
	
	# 生成控制
	spawn_button.pressed.connect(_on_spawn_pressed)
	start_wave_button.pressed.connect(_on_start_wave_pressed)
	clear_button.pressed.connect(_on_clear_pressed)
	
	# 调试开关
	debug_toggle.toggled.connect(_on_debug_toggled)
	
	# 填充敌人类型列表
	enemy_type_list.clear()
	for i in range(enemy_presets.size()):
		var preset = enemy_presets[i]
		enemy_type_list.add_item("%d. %s" % [i + 1, preset.name])
	
	if enemy_presets.size() > 0:
		enemy_type_list.select(0)

## 连接信号
func _connect_signals() -> void:
	# 敌人管理器信号
	if enemy_manager != null:
		enemy_manager.enemy_died.connect(_on_enemy_died)
		enemy_manager.all_enemies_defeated.connect(_on_all_enemies_defeated)
		enemy_manager.wave_completed.connect(_on_wave_completed)
	
	# 玩家信号
	if player != null:
		if player.has_signal("died"):
			player.died.connect(_on_player_died)

## 更新UI
func _update_ui() -> void:
	# 波次信息
	wave_label.text = "波次: %d" % current_wave
	
	# 敌人数量
	var enemy_count = enemy_manager.get_active_enemy_count() if enemy_manager else 0
	enemy_count_label.text = "敌人: %d" % enemy_count
	
	# 玩家生命值
	if player != null and player.energy_system != null:
		player_health_bar.value = player.energy_system.get_cap_percent() * 100.0
	
	# 分数
	score_label.text = "分数: %d" % total_score

## 更新调试信息
func _update_debug_info() -> void:
	if ai_info_label == null:
		return
	
	var info_text = "[b]AI调试信息[/b]\n\n"
	
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy is EnemyAIController:
			var ai = enemy as EnemyAIController
			var state_name = "Unknown"
			if ai.state_machine != null and ai.state_machine.current_state != null:
				state_name = ai.state_machine.current_state.name
			
			var target_info = "无目标"
			if ai.current_target != null:
				var dist = ai.get_distance_to_target()
				target_info = "目标距离: %.0f" % dist
			
			var health_percent = ai.get_health_percent() * 100.0
			
			info_text += "[color=yellow]%s[/color]\n" % ai.name
			info_text += "  状态: %s\n" % state_name
			info_text += "  生命: %.0f%%\n" % health_percent
			info_text += "  %s\n\n" % target_info
	
	ai_info_label.text = info_text

## 生成敌人
func spawn_enemy_at(preset_index: int, position: Vector2) -> EnemyAIController:
	if preset_index < 0 or preset_index >= enemy_presets.size():
		return null
	
	var preset = enemy_presets[preset_index]
	
	# 创建敌人实例
	var enemy = _create_enemy_instance(preset)
	if enemy == null:
		return null
	
	enemy.global_position = position
	enemy_container.add_child(enemy)
	
	# 注册到敌人管理器
	if enemy_manager != null:
		enemy_manager._register_enemy(enemy)
	
	return enemy

## 创建敌人实例
func _create_enemy_instance(preset: Dictionary) -> EnemyAIController:
	var enemy = EnemyAIController.new()
	enemy.name = preset.name + "_" + str(randi())
	
	# 设置行为配置
	enemy.behavior_profile = preset.profile.duplicate()
	
	# 设置能量系统
	enemy.energy_system = EnergySystemData.create_enemy_default(preset.health)
	
	# 添加碰撞形状
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 20.0
	collision.shape = shape
	enemy.add_child(collision)
	
	# 添加视觉效果
	var visuals = Node2D.new()
	visuals.name = "Visuals"
	
	var body = Polygon2D.new()
	body.name = "Body"
	body.color = preset.color
	body.polygon = PackedVector2Array([
		Vector2(-15, -20), Vector2(15, -20), Vector2(20, 0),
		Vector2(15, 20), Vector2(-15, 20), Vector2(-20, 0)
	])
	visuals.add_child(body)
	
	var indicator = Polygon2D.new()
	indicator.name = "DirectionIndicator"
	indicator.color = preset.color.lightened(0.3)
	indicator.polygon = PackedVector2Array([
		Vector2(20, 0), Vector2(30, -5), Vector2(30, 5)
	])
	visuals.add_child(indicator)
	
	enemy.add_child(visuals)
	
	# 添加状态机
	var state_machine = StateMachine.new()
	state_machine.name = "StateMachine"
	
	var idle_state = AIIdleState.new()
	idle_state.name = "AIIdle"
	state_machine.add_child(idle_state)
	
	var patrol_state = AIPatrolState.new()
	patrol_state.name = "AIPatrol"
	state_machine.add_child(patrol_state)
	
	var chase_state = AIChaseState.new()
	chase_state.name = "AIChase"
	state_machine.add_child(chase_state)
	
	var attack_state = AIAttackState.new()
	attack_state.name = "AIAttack"
	state_machine.add_child(attack_state)
	
	var flee_state = AIFleeState.new()
	flee_state.name = "AIFlee"
	state_machine.add_child(flee_state)
	
	var skill_state = AIUseSkillState.new()
	skill_state.name = "AIUseSkill"
	state_machine.add_child(skill_state)
	
	enemy.add_child(state_machine)
	
	# 添加感知系统
	var perception = PerceptionSystem.new()
	perception.name = "Perception"
	perception.perception_radius = preset.profile.perception_radius
	perception.attack_radius = preset.profile.attack_range
	enemy.add_child(perception)
	
	# 添加目标选择器
	var target_selector = TargetSelector.new()
	target_selector.name = "TargetSelector"
	enemy.add_child(target_selector)
	
	# 添加血条
	var health_bar = ProgressBar.new()
	health_bar.name = "HealthBar"
	health_bar.position = Vector2(-25, -35)
	health_bar.size = Vector2(50, 7)
	health_bar.value = 100.0
	health_bar.show_percentage = false
	enemy.add_child(health_bar)
	
	# 添加调试可视化
	if debug_mode:
		var debug_viz = AIDebugVisualizer.new()
		debug_viz.name = "DebugVisualizer"
		debug_viz.enabled = true
		enemy.add_child(debug_viz)
	
	# 添加到敌人组
	enemy.add_to_group("enemies")
	
	return enemy

## 获取随机生成位置
func _get_random_spawn_position() -> Vector2:
	var viewport_size = get_viewport().get_visible_rect().size
	var margin = 100.0
	
	# 在玩家周围生成，但保持一定距离
	var player_pos = player.global_position if player else viewport_size / 2
	var angle = randf() * TAU
	var distance = randf_range(300, 500)
	
	var pos = player_pos + Vector2(cos(angle), sin(angle)) * distance
	
	# 确保在屏幕范围内
	pos.x = clamp(pos.x, margin, viewport_size.x - margin)
	pos.y = clamp(pos.y, margin, viewport_size.y - margin)
	
	return pos

## 开始波次
func _start_wave(wave_index: int) -> void:
	if wave_index >= wave_configs.size():
		wave_index = wave_configs.size() - 1
	
	var config = wave_configs[wave_index]
	current_wave = wave_index + 1
	is_wave_active = true
	
	# 生成敌人
	_spawn_wave_enemies(config)

## 生成波次敌人
func _spawn_wave_enemies(config: Dictionary) -> void:
	var count = config.enemy_count
	var types = config.types
	var delay = config.spawn_delay
	
	for i in range(count):
		await get_tree().create_timer(delay).timeout
		
		if not is_wave_active:
			break
		
		var type_index = types[i % types.size()]
		var position = _get_random_spawn_position()
		spawn_enemy_at(type_index, position)

# ==================== 回调函数 ====================

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")

func _on_spawn_pressed() -> void:
	var selected = enemy_type_list.get_selected_items()
	if selected.is_empty():
		return
	
	var type_index = selected[0]
	var count = int(spawn_count_spinbox.value)
	
	for i in range(count):
		var position = _get_random_spawn_position()
		spawn_enemy_at(type_index, position)

func _on_start_wave_pressed() -> void:
	if is_wave_active:
		return
	
	_start_wave(current_wave)

func _on_clear_pressed() -> void:
	is_wave_active = false
	
	# 清除所有敌人
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	
	if enemy_manager != null:
		enemy_manager.active_enemies.clear()

func _on_debug_toggled(toggled_on: bool) -> void:
	debug_mode = toggled_on
	
	# 更新所有敌人的调试可视化
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is EnemyAIController:
			var debug_viz = enemy.get_node_or_null("DebugVisualizer")
			if debug_viz != null:
				debug_viz.enabled = toggled_on
			elif toggled_on:
				# 添加调试可视化
				var new_viz = AIDebugVisualizer.new()
				new_viz.name = "DebugVisualizer"
				new_viz.enabled = true
				enemy.add_child(new_viz)

func _on_enemy_died(enemy: EnemyAIController) -> void:
	enemies_killed += 1
	
	# 计算分数
	for preset in enemy_presets:
		if enemy.behavior_profile != null and enemy.behavior_profile.profile_name == preset.profile.profile_name:
			total_score += preset.score
			break

func _on_all_enemies_defeated() -> void:
	if is_wave_active:
		is_wave_active = false
		wave_completed.emit(current_wave)
		
		# 自动开始下一波
		if current_wave < wave_configs.size():
			await get_tree().create_timer(2.0).timeout
			_start_wave(current_wave)
		else:
			battle_ended.emit("victory")

func _on_wave_completed(wave_number: int) -> void:
	print("[AI演武厂] 波次 %d 完成！" % wave_number)

func _on_player_died() -> void:
	is_wave_active = false
	battle_ended.emit("defeat")
