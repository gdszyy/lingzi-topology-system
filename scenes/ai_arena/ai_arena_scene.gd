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
@onready var battle_recorder: ArenaBattleRecorder = $BattleRecorder

# UI节点
@onready var ui: CanvasLayer = $UI
@onready var wave_label: Label = $UI/TopPanel/WaveLabel
@onready var enemy_count_label: Label = $UI/TopPanel/EnemyCountLabel
@onready var player_health_bar: ProgressBar = $UI/TopPanel/PlayerHealthBar
@onready var score_label: Label = $UI/TopPanel/ScoreLabel
@onready var timer_label: Label = $UI/TopPanel/TimerLabel
@onready var combo_label: Label = $UI/TopPanel/ComboLabel
@onready var back_button: Button = $UI/TopPanel/BackButton

# 控制面板
@onready var spawn_panel: PanelContainer = $UI/SpawnPanel
@onready var enemy_type_list: ItemList = $UI/SpawnPanel/VBoxContainer/EnemyTypeList
@onready var spawn_button: Button = $UI/SpawnPanel/VBoxContainer/SpawnButton
@onready var spawn_count_spinbox: SpinBox = $UI/SpawnPanel/VBoxContainer/CountContainer/SpawnCountSpinBox
@onready var start_wave_button: Button = $UI/SpawnPanel/VBoxContainer/StartWaveButton
@onready var pause_wave_button: Button = $UI/SpawnPanel/VBoxContainer/PauseWaveButton
@onready var clear_button: Button = $UI/SpawnPanel/VBoxContainer/ClearButton
@onready var difficulty_option: OptionButton = $UI/SpawnPanel/VBoxContainer/DifficultyContainer/DifficultyOption
@onready var mode_option: OptionButton = $UI/SpawnPanel/VBoxContainer/ModeContainer/ModeOption

# 调试面板
@onready var debug_panel: PanelContainer = $UI/DebugPanel
@onready var debug_toggle: CheckButton = $UI/DebugPanel/VBoxContainer/DebugToggle
@onready var ai_info_label: RichTextLabel = $UI/DebugPanel/VBoxContainer/AIInfoLabel
@onready var stats_label: RichTextLabel = $UI/DebugPanel/VBoxContainer/StatsLabel

# 结果面板
@onready var result_panel: PanelContainer = $UI/ResultPanel
@onready var result_title_label: Label = $UI/ResultPanel/VBoxContainer/TitleLabel
@onready var result_content_label: RichTextLabel = $UI/ResultPanel/VBoxContainer/ContentLabel
@onready var restart_button: Button = $UI/ResultPanel/VBoxContainer/RestartButton
@onready var menu_button: Button = $UI/ResultPanel/VBoxContainer/MenuButton

# 敌人预设
var enemy_presets: Array[Dictionary] = []

# 游戏状态
var current_wave: int = 0
var total_score: int = 0
var enemies_killed: int = 0
var is_wave_active: bool = false
var is_paused: bool = false
var debug_mode: bool = false
var battle_time: float = 0.0
var current_combo: int = 0
var max_combo: int = 0
var combo_timer: float = 0.0
const COMBO_TIMEOUT: float = 2.0

# 难度设置
enum Difficulty { EASY, NORMAL, HARD, NIGHTMARE }
var current_difficulty: Difficulty = Difficulty.NORMAL

# 游戏模式
enum GameMode { FREE_PLAY, WAVE_SURVIVAL, ENDLESS, BOSS_RUSH, TRAINING }
var current_mode: GameMode = GameMode.FREE_PLAY

# 波次配置
var wave_configs: Array[Dictionary] = []

# 难度倍率
var difficulty_multipliers = {
	Difficulty.EASY: {"health": 0.7, "damage": 0.5, "speed": 0.8, "score": 0.5},
	Difficulty.NORMAL: {"health": 1.0, "damage": 1.0, "speed": 1.0, "score": 1.0},
	Difficulty.HARD: {"health": 1.5, "damage": 1.5, "speed": 1.2, "score": 2.0},
	Difficulty.NIGHTMARE: {"health": 2.5, "damage": 2.0, "speed": 1.5, "score": 4.0}
}

func _ready() -> void:
	_initialize_enemy_presets()
	_generate_wave_configs()
	_setup_ui()
	_connect_signals()
	_hide_result_panel()
	_update_ui()
	
	# 初始化战斗记录器
	if battle_recorder != null:
		battle_recorder.start_recording()

func _process(delta: float) -> void:
	if not is_paused:
		# 更新战斗时间
		if is_wave_active or current_mode == GameMode.FREE_PLAY:
			battle_time += delta
		
		# 更新连击计时器
		if combo_timer > 0:
			combo_timer -= delta
			if combo_timer <= 0:
				current_combo = 0
	
	_update_ui()
	
	if debug_mode:
		_update_debug_info()

## 初始化敌人预设
func _initialize_enemy_presets() -> void:
	enemy_presets = [
		{
			"name": "近战小兵",
			"description": "基础近战单位，数量众多但单体较弱",
			"profile": AIBehaviorProfile.create_melee_aggressive(),
			"color": Color(0.8, 0.2, 0.2),
			"health": 80.0,
			"damage": 8.0,
			"score": 10,
			"tier": 1
		},
		{
			"name": "远程射手",
			"description": "远程攻击单位，保持距离进行射击",
			"profile": AIBehaviorProfile.create_ranged_sniper(),
			"color": Color(0.2, 0.6, 0.8),
			"health": 60.0,
			"damage": 12.0,
			"score": 15,
			"tier": 2
		},
		{
			"name": "刺客",
			"description": "高机动性刺客，擅长闪避和偷袭",
			"profile": AIBehaviorProfile.create_assassin(),
			"color": Color(0.5, 0.2, 0.8),
			"health": 50.0,
			"damage": 20.0,
			"score": 25,
			"tier": 3
		},
		{
			"name": "坦克",
			"description": "高生命值坦克，移动缓慢但难以击杀",
			"profile": AIBehaviorProfile.create_tank(),
			"color": Color(0.4, 0.4, 0.4),
			"health": 200.0,
			"damage": 15.0,
			"score": 30,
			"tier": 3
		},
		{
			"name": "蜂群兵",
			"description": "弱小但成群出现的单位",
			"profile": AIBehaviorProfile.create_swarm(),
			"color": Color(0.6, 0.6, 0.2),
			"health": 30.0,
			"damage": 5.0,
			"score": 5,
			"tier": 1
		},
		{
			"name": "法师",
			"description": "远程法术攻击者，能够施放强力法术",
			"profile": _create_mage_profile(),
			"color": Color(0.3, 0.3, 0.9),
			"health": 70.0,
			"damage": 25.0,
			"score": 35,
			"tier": 3
		},
		{
			"name": "狂战士",
			"description": "生命值越低攻击力越高的疯狂战士",
			"profile": _create_berserker_profile(),
			"color": Color(0.9, 0.3, 0.1),
			"health": 120.0,
			"damage": 15.0,
			"score": 40,
			"tier": 3
		},
		{
			"name": "精英战士",
			"description": "强大的精英近战单位，具有多种战斗技能",
			"profile": _create_elite_profile(),
			"color": Color(0.8, 0.6, 0.1),
			"health": 300.0,
			"damage": 25.0,
			"score": 100,
			"tier": 4
		},
		{
			"name": "暗影领主",
			"description": "终极Boss，拥有多种攻击模式",
			"profile": _create_boss_profile(),
			"color": Color(0.2, 0.1, 0.3),
			"health": 500.0,
			"damage": 35.0,
			"score": 500,
			"tier": 5
		}
	]

## 创建法师配置
func _create_mage_profile() -> AIBehaviorProfile:
	var profile = AIBehaviorProfile.new()
	profile.profile_name = "元素法师"
	profile.archetype = AIBehaviorProfile.AIArchetype.RANGED_MOBILE
	profile.combat_style = AIBehaviorProfile.CombatStyle.BALANCED
	profile.perception_radius = 600.0
	profile.engagement_distance = 350.0
	profile.min_engagement_distance = 250.0
	profile.move_speed = 100.0
	profile.aggression = 0.7
	profile.attack_cooldown = 2.5
	profile.attack_range = 400.0
	profile.flee_health_threshold = 0.25
	profile.dodge_chance = 0.2
	profile.skill_usage_enabled = true
	profile.use_body_part_targeting = true
	return profile

## 创建狂战士配置
func _create_berserker_profile() -> AIBehaviorProfile:
	var profile = AIBehaviorProfile.new()
	profile.profile_name = "狂战士"
	profile.archetype = AIBehaviorProfile.AIArchetype.MELEE_AGGRESSIVE
	profile.combat_style = AIBehaviorProfile.CombatStyle.AGGRESSIVE
	profile.perception_radius = 450.0
	profile.engagement_distance = 60.0
	profile.min_engagement_distance = 20.0
	profile.move_speed = 180.0
	profile.aggression = 1.0
	profile.attack_cooldown = 1.0
	profile.combo_chance = 0.7
	profile.max_combo_length = 5
	profile.attack_range = 70.0
	profile.flee_health_threshold = 0.0
	profile.dodge_chance = 0.0
	profile.use_body_part_targeting = false
	return profile

## 创建精英配置
func _create_elite_profile() -> AIBehaviorProfile:
	var profile = AIBehaviorProfile.new()
	profile.profile_name = "精英战士"
	profile.archetype = AIBehaviorProfile.AIArchetype.MELEE_AGGRESSIVE
	profile.combat_style = AIBehaviorProfile.CombatStyle.BALANCED
	profile.perception_radius = 500.0
	profile.engagement_distance = 80.0
	profile.min_engagement_distance = 30.0
	profile.move_speed = 140.0
	profile.aggression = 0.8
	profile.attack_cooldown = 1.5
	profile.combo_chance = 0.5
	profile.max_combo_length = 4
	profile.attack_range = 80.0
	profile.flee_health_threshold = 0.1
	profile.block_chance = 0.3
	profile.dodge_chance = 0.2
	profile.counter_attack_chance = 0.25
	profile.skill_usage_enabled = true
	profile.use_body_part_targeting = true
	return profile

## 创建Boss配置
func _create_boss_profile() -> AIBehaviorProfile:
	var profile = AIBehaviorProfile.new()
	profile.profile_name = "暗影领主"
	profile.archetype = AIBehaviorProfile.AIArchetype.ASSASSIN
	profile.combat_style = AIBehaviorProfile.CombatStyle.BALANCED
	profile.perception_radius = 800.0
	profile.engagement_distance = 100.0
	profile.min_engagement_distance = 40.0
	profile.move_speed = 160.0
	profile.aggression = 0.85
	profile.attack_cooldown = 1.2
	profile.combo_chance = 0.6
	profile.max_combo_length = 6
	profile.attack_range = 100.0
	profile.flee_health_threshold = 0.0
	profile.block_chance = 0.2
	profile.dodge_chance = 0.4
	profile.dodge_distance = 200.0
	profile.counter_attack_chance = 0.4
	profile.skill_usage_enabled = true
	profile.use_body_part_targeting = true
	return profile

## 生成波次配置
func _generate_wave_configs() -> void:
	wave_configs.clear()
	
	# 根据难度生成不同的波次配置
	var base_count = 3
	var increment = 2
	var max_waves = 10
	
	match current_difficulty:
		Difficulty.EASY:
			base_count = 2
			increment = 1
			max_waves = 5
		Difficulty.NORMAL:
			base_count = 3
			increment = 2
			max_waves = 10
		Difficulty.HARD:
			base_count = 4
			increment = 3
			max_waves = 15
		Difficulty.NIGHTMARE:
			base_count = 5
			increment = 4
			max_waves = 20
	
	for i in range(max_waves):
		var wave_num = i + 1
		var enemy_count = base_count + i * increment
		
		# 根据波次解锁不同敌人类型
		var available_types: Array[int] = [0]  # 总是有小兵
		if wave_num >= 2:
			available_types.append(1)  # 射手
		if wave_num >= 3:
			available_types.append(4)  # 蜂群
		if wave_num >= 4:
			available_types.append(2)  # 刺客
		if wave_num >= 5:
			available_types.append(3)  # 坦克
		if wave_num >= 6:
			available_types.append(5)  # 法师
		if wave_num >= 7:
			available_types.append(6)  # 狂战士
		if wave_num >= 8:
			available_types.append(7)  # 精英
		if wave_num == max_waves:
			available_types.append(8)  # Boss
		
		var spawn_delay = max(0.3, 1.0 - i * 0.05)
		
		wave_configs.append({
			"wave_number": wave_num,
			"enemy_count": enemy_count,
			"types": available_types,
			"spawn_delay": spawn_delay,
			"is_boss_wave": wave_num == max_waves
		})

## 设置UI
func _setup_ui() -> void:
	# 返回按钮
	back_button.pressed.connect(_on_back_pressed)
	
	# 生成控制
	spawn_button.pressed.connect(_on_spawn_pressed)
	start_wave_button.pressed.connect(_on_start_wave_pressed)
	pause_wave_button.pressed.connect(_on_pause_wave_pressed)
	clear_button.pressed.connect(_on_clear_pressed)
	
	# 调试开关
	debug_toggle.toggled.connect(_on_debug_toggled)
	
	# 难度选择
	difficulty_option.clear()
	difficulty_option.add_item("简单", Difficulty.EASY)
	difficulty_option.add_item("普通", Difficulty.NORMAL)
	difficulty_option.add_item("困难", Difficulty.HARD)
	difficulty_option.add_item("噩梦", Difficulty.NIGHTMARE)
	difficulty_option.select(Difficulty.NORMAL)
	difficulty_option.item_selected.connect(_on_difficulty_changed)
	
	# 模式选择
	mode_option.clear()
	mode_option.add_item("自由模式", GameMode.FREE_PLAY)
	mode_option.add_item("波次生存", GameMode.WAVE_SURVIVAL)
	mode_option.add_item("无尽模式", GameMode.ENDLESS)
	mode_option.add_item("Boss连战", GameMode.BOSS_RUSH)
	mode_option.add_item("训练模式", GameMode.TRAINING)
	mode_option.select(GameMode.FREE_PLAY)
	mode_option.item_selected.connect(_on_mode_changed)
	
	# 填充敌人类型列表
	_refresh_enemy_list()
	
	# 结果面板按钮
	restart_button.pressed.connect(_on_restart_pressed)
	menu_button.pressed.connect(_on_back_pressed)

## 刷新敌人列表
func _refresh_enemy_list() -> void:
	enemy_type_list.clear()
	for i in range(enemy_presets.size()):
		var preset = enemy_presets[i]
		var tier_stars = "★".repeat(preset.tier)
		enemy_type_list.add_item("%s %s" % [tier_stars, preset.name])
		enemy_type_list.set_item_tooltip(i, preset.description)
	
	if enemy_presets.size() > 0:
		enemy_type_list.select(0)

## 连接信号
func _connect_signals() -> void:
	# 敌人管理器信号
	if enemy_manager != null:
		enemy_manager.enemy_died.connect(_on_enemy_died)
		enemy_manager.all_enemies_defeated.connect(_on_all_enemies_defeated)
	
	# 玩家信号
	if player != null:
		if player.has_signal("died"):
			player.died.connect(_on_player_died)
		if player.has_signal("attack_hit"):
			player.attack_hit.connect(_on_player_attack_hit)

## 隐藏结果面板
func _hide_result_panel() -> void:
	if result_panel != null:
		result_panel.visible = false

## 显示结果面板
func _show_result_panel(is_victory: bool) -> void:
	if result_panel == null:
		return
	
	result_panel.visible = true
	
	if is_victory:
		result_title_label.text = "胜利！"
		result_title_label.add_theme_color_override("font_color", Color.GOLD)
	else:
		result_title_label.text = "失败"
		result_title_label.add_theme_color_override("font_color", Color.RED)
	
	# 生成结果内容
	var content = "[center][b]战斗统计[/b][/center]\n\n"
	content += "到达波次: [color=yellow]%d[/color]\n" % current_wave
	content += "击杀敌人: [color=yellow]%d[/color]\n" % enemies_killed
	content += "总分数: [color=yellow]%d[/color]\n" % total_score
	content += "最高连击: [color=yellow]%d[/color]\n" % max_combo
	content += "战斗时长: [color=yellow]%.1f[/color] 秒\n" % battle_time
	
	if battle_recorder != null:
		var stats = battle_recorder.get_stats()
		content += "\n[b]详细数据[/b]\n"
		content += "总输出伤害: [color=green]%.0f[/color]\n" % stats.total_damage_dealt
		content += "总承受伤害: [color=red]%.0f[/color]\n" % stats.total_damage_taken
		content += "DPS: [color=cyan]%.1f[/color]\n" % (stats.total_damage_dealt / max(1.0, battle_time))
	
	result_content_label.text = content

## 更新UI
func _update_ui() -> void:
	# 波次信息
	if current_mode == GameMode.FREE_PLAY:
		wave_label.text = "自由模式"
	else:
		wave_label.text = "波次: %d/%d" % [current_wave, wave_configs.size()]
	
	# 敌人数量
	var enemy_count = get_tree().get_nodes_in_group("enemies").size()
	enemy_count_label.text = "敌人: %d" % enemy_count
	
	# 玩家生命值
	if player != null and player.energy_system != null:
		player_health_bar.value = player.energy_system.get_cap_percent() * 100.0
	
	# 分数
	score_label.text = "分数: %d" % total_score
	
	# 时间
	var minutes = int(battle_time) / 60
	var seconds = int(battle_time) % 60
	timer_label.text = "时间: %02d:%02d" % [minutes, seconds]
	
	# 连击
	if current_combo > 1:
		combo_label.text = "连击: x%d" % current_combo
		combo_label.visible = true
	else:
		combo_label.visible = false
	
	# 暂停按钮状态
	if is_wave_active:
		pause_wave_button.text = "暂停" if not is_paused else "继续"
		pause_wave_button.disabled = false
	else:
		pause_wave_button.text = "暂停"
		pause_wave_button.disabled = true

## 更新调试信息
func _update_debug_info() -> void:
	if ai_info_label == null:
		return
	
	var info_text = "[b]AI调试信息[/b]\n\n"
	
	var enemies = get_tree().get_nodes_in_group("enemies")
	var displayed = 0
	for enemy in enemies:
		if displayed >= 5:  # 最多显示5个敌人
			info_text += "[color=gray]... 还有 %d 个敌人[/color]\n" % (enemies.size() - displayed)
			break
		
		if enemy is EnemyAIController:
			var ai = enemy as EnemyAIController
			var state_name = "Unknown"
			if ai.state_machine != null and ai.state_machine.current_state != null:
				state_name = ai.state_machine.current_state.name
			
			var target_info = "无目标"
			if ai.current_target != null:
				var dist = ai.get_distance_to_target()
				target_info = "距离: %.0f" % dist
			
			var health_percent = ai.get_health_percent() * 100.0
			var health_color = "green" if health_percent > 50 else ("yellow" if health_percent > 25 else "red")
			
			info_text += "[color=yellow]%s[/color]\n" % ai.behavior_profile.profile_name if ai.behavior_profile else ai.name
			info_text += "  状态: [color=cyan]%s[/color]\n" % state_name
			info_text += "  生命: [color=%s]%.0f%%[/color]\n" % [health_color, health_percent]
			info_text += "  %s\n\n" % target_info
			displayed += 1
	
	if enemies.is_empty():
		info_text += "[color=gray]暂无敌人[/color]\n"
	
	ai_info_label.text = info_text
	
	# 更新统计面板
	if stats_label != null and battle_recorder != null:
		var stats = battle_recorder.get_stats()
		var stats_text = "[b]战斗统计[/b]\n\n"
		stats_text += "击杀: %d\n" % stats.enemies_killed
		stats_text += "输出: %.0f\n" % stats.total_damage_dealt
		stats_text += "承伤: %.0f\n" % stats.total_damage_taken
		stats_text += "连击: %d\n" % max_combo
		stats_label.text = stats_text

## 生成敌人
func spawn_enemy_at(preset_index: int, position: Vector2) -> EnemyAIController:
	if preset_index < 0 or preset_index >= enemy_presets.size():
		return null
	
	var preset = enemy_presets[preset_index]
	var multiplier = difficulty_multipliers[current_difficulty]
	
	# 创建敌人实例
	var enemy = _create_enemy_instance(preset, multiplier)
	if enemy == null:
		return null
	
	enemy.global_position = position
	enemy_container.add_child(enemy)
	
	# 注册到敌人管理器
	if enemy_manager != null:
		enemy_manager._register_enemy(enemy)
	
	return enemy

## 创建敌人实例
func _create_enemy_instance(preset: Dictionary, multiplier: Dictionary) -> EnemyAIController:
	var enemy = EnemyAIController.new()
	enemy.name = preset.name + "_" + str(randi())
	
	# 设置行为配置
	var profile = preset.profile.duplicate() as AIBehaviorProfile
	profile.move_speed *= multiplier.speed
	enemy.behavior_profile = profile
	
	# 设置能量系统（应用难度倍率）
	var health = preset.health * multiplier.health
	enemy.energy_system = EnergySystemData.create_enemy_default(health)
	
	# 添加碰撞形状
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 20.0 + preset.tier * 2  # 高等级敌人稍大
	collision.shape = shape
	enemy.add_child(collision)
	
	# 添加视觉效果
	var visuals = Node2D.new()
	visuals.name = "Visuals"
	
	var body = Polygon2D.new()
	body.name = "Body"
	body.color = preset.color
	
	# 根据等级调整外观
	var size_mult = 1.0 + (preset.tier - 1) * 0.15
	body.polygon = PackedVector2Array([
		Vector2(-15, -20) * size_mult, Vector2(15, -20) * size_mult, Vector2(20, 0) * size_mult,
		Vector2(15, 20) * size_mult, Vector2(-15, 20) * size_mult, Vector2(-20, 0) * size_mult
	])
	visuals.add_child(body)
	
	var indicator = Polygon2D.new()
	indicator.name = "DirectionIndicator"
	indicator.color = preset.color.lightened(0.3)
	indicator.polygon = PackedVector2Array([
		Vector2(20, 0) * size_mult, Vector2(30, -5) * size_mult, Vector2(30, 5) * size_mult
	])
	visuals.add_child(indicator)
	
	# Boss添加光环效果
	if preset.tier >= 4:
		var aura = Polygon2D.new()
		aura.name = "Aura"
		aura.color = preset.color.lightened(0.5)
		aura.color.a = 0.3
		var aura_points: PackedVector2Array = []
		for i in range(12):
			var angle = i * TAU / 12
			aura_points.append(Vector2(cos(angle), sin(angle)) * 35 * size_mult)
		aura.polygon = aura_points
		visuals.add_child(aura)
	
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
	perception.perception_radius = profile.perception_radius
	perception.attack_radius = profile.attack_range
	enemy.add_child(perception)
	
	# 添加目标选择器
	var target_selector = TargetSelector.new()
	target_selector.name = "TargetSelector"
	enemy.add_child(target_selector)
	
	# 添加血条
	var health_bar = ProgressBar.new()
	health_bar.name = "HealthBar"
	health_bar.position = Vector2(-25 * size_mult, -40 * size_mult)
	health_bar.size = Vector2(50 * size_mult, 7)
	health_bar.value = 100.0
	health_bar.show_percentage = false
	enemy.add_child(health_bar)
	
	# 添加名称标签（Boss和精英）
	if preset.tier >= 4:
		var name_label = Label.new()
		name_label.name = "NameLabel"
		name_label.text = preset.name
		name_label.position = Vector2(-30 * size_mult, -55 * size_mult)
		name_label.add_theme_font_size_override("font_size", 12)
		name_label.add_theme_color_override("font_color", preset.color.lightened(0.3))
		enemy.add_child(name_label)
	
	# 添加调试可视化
	if debug_mode:
		var debug_viz = AIDebugVisualizer.new()
		debug_viz.name = "DebugVisualizer"
		debug_viz.enabled = true
		enemy.add_child(debug_viz)
	
	# 存储预设信息用于计分
	enemy.set_meta("preset", preset)
	enemy.set_meta("score_multiplier", multiplier.score)
	
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
	var distance = randf_range(350, 550)
	
	var pos = player_pos + Vector2(cos(angle), sin(angle)) * distance
	
	# 确保在屏幕范围内
	pos.x = clamp(pos.x, margin, viewport_size.x - margin)
	pos.y = clamp(pos.y, margin, viewport_size.y - margin)
	
	return pos

## 开始波次
func _start_wave(wave_index: int) -> void:
	if wave_index >= wave_configs.size():
		if current_mode == GameMode.ENDLESS:
			# 无尽模式：重新生成更难的波次
			_generate_endless_wave(wave_index)
		else:
			wave_index = wave_configs.size() - 1
	
	var config = wave_configs[wave_index]
	current_wave = config.wave_number
	is_wave_active = true
	is_paused = false
	
	# 记录波次开始
	if battle_recorder != null:
		battle_recorder.record_wave_started(current_wave)
	
	# 生成敌人
	_spawn_wave_enemies(config)

## 生成无尽模式波次
func _generate_endless_wave(wave_index: int) -> void:
	var enemy_count = 5 + wave_index * 3
	var available_types: Array[int] = []
	for i in range(enemy_presets.size()):
		available_types.append(i)
	
	wave_configs.append({
		"wave_number": wave_index + 1,
		"enemy_count": enemy_count,
		"types": available_types,
		"spawn_delay": max(0.2, 0.8 - wave_index * 0.02),
		"is_boss_wave": wave_index % 5 == 4  # 每5波一个Boss
	})

## 生成波次敌人
func _spawn_wave_enemies(config: Dictionary) -> void:
	var count = config.enemy_count
	var types = config.types
	var delay = config.spawn_delay
	var is_boss_wave = config.get("is_boss_wave", false)
	
	for i in range(count):
		if is_paused:
			await get_tree().create_timer(0.1).timeout
			continue
		
		await get_tree().create_timer(delay).timeout
		
		if not is_wave_active:
			break
		
		var type_index: int
		if is_boss_wave and i == count - 1:
			# 最后一个敌人是Boss
			type_index = enemy_presets.size() - 1
		else:
			# 根据权重随机选择
			type_index = _get_weighted_random_type(types)
		
		var position = _get_random_spawn_position()
		spawn_enemy_at(type_index, position)

## 获取加权随机敌人类型
func _get_weighted_random_type(available_types: Array) -> int:
	# 低等级敌人更常见
	var weights: Array[float] = []
	var total_weight = 0.0
	
	for type_idx in available_types:
		var tier = enemy_presets[type_idx].tier
		var weight = 1.0 / tier  # 等级越高，权重越低
		weights.append(weight)
		total_weight += weight
	
	var roll = randf() * total_weight
	var cumulative = 0.0
	
	for i in range(available_types.size()):
		cumulative += weights[i]
		if roll <= cumulative:
			return available_types[i]
	
	return available_types[0]

# ==================== 回调函数 ====================

func _on_back_pressed() -> void:
	if battle_recorder != null:
		battle_recorder.stop_recording()
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
	
	if current_mode == GameMode.FREE_PLAY:
		# 自由模式下开始波次生存
		current_mode = GameMode.WAVE_SURVIVAL
		mode_option.select(GameMode.WAVE_SURVIVAL)
		_generate_wave_configs()
	
	_start_wave(current_wave)

func _on_pause_wave_pressed() -> void:
	is_paused = not is_paused
	get_tree().paused = is_paused

func _on_clear_pressed() -> void:
	is_wave_active = false
	is_paused = false
	
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
				var new_viz = AIDebugVisualizer.new()
				new_viz.name = "DebugVisualizer"
				new_viz.enabled = true
				enemy.add_child(new_viz)

func _on_difficulty_changed(index: int) -> void:
	current_difficulty = index as Difficulty
	_generate_wave_configs()

func _on_mode_changed(index: int) -> void:
	current_mode = index as GameMode
	_generate_wave_configs()
	
	# 训练模式下玩家无敌
	if current_mode == GameMode.TRAINING and player != null:
		# 可以在这里设置玩家无敌状态
		pass

func _on_restart_pressed() -> void:
	_hide_result_panel()
	_reset_game()

func _reset_game() -> void:
	# 重置状态
	current_wave = 0
	total_score = 0
	enemies_killed = 0
	is_wave_active = false
	is_paused = false
	battle_time = 0.0
	current_combo = 0
	max_combo = 0
	
	# 清除敌人
	_on_clear_pressed()
	
	# 重置玩家
	if player != null:
		player.global_position = Vector2(960, 540)
		if player.energy_system != null:
			player.energy_system.reset()
	
	# 重新生成波次配置
	_generate_wave_configs()
	
	# 重新开始记录
	if battle_recorder != null:
		battle_recorder.start_recording()

func _on_enemy_died(enemy: EnemyAIController) -> void:
	enemies_killed += 1
	
	# 增加连击
	current_combo += 1
	combo_timer = COMBO_TIMEOUT
	if current_combo > max_combo:
		max_combo = current_combo
	
	# 计算分数
	var preset = enemy.get_meta("preset", null)
	var score_mult = enemy.get_meta("score_multiplier", 1.0)
	if preset != null:
		var base_score = preset.score
		var combo_bonus = 1.0 + (current_combo - 1) * 0.1  # 连击加成
		total_score += int(base_score * score_mult * combo_bonus)
	
	# 记录击杀
	if battle_recorder != null:
		battle_recorder.record_enemy_killed(enemy, player)

func _on_all_enemies_defeated() -> void:
	if is_wave_active:
		is_wave_active = false
		wave_completed.emit(current_wave)
		
		# 记录波次完成
		if battle_recorder != null:
			battle_recorder.record_wave_completed(current_wave, enemies_killed)
		
		# 检查是否完成所有波次
		if current_wave >= wave_configs.size() and current_mode != GameMode.ENDLESS:
			# 胜利
			if battle_recorder != null:
				battle_recorder.stop_recording()
			_show_result_panel(true)
			battle_ended.emit("victory")
		else:
			# 自动开始下一波
			await get_tree().create_timer(2.0).timeout
			if not is_wave_active:  # 确保没有被手动开始
				_start_wave(current_wave)

func _on_player_died() -> void:
	is_wave_active = false
	
	if battle_recorder != null:
		battle_recorder.stop_recording()
	
	_show_result_panel(false)
	battle_ended.emit("defeat")

func _on_player_attack_hit(target: Node2D, damage: float, part_type: int) -> void:
	if battle_recorder != null:
		battle_recorder.record_damage_dealt(damage, target, player, part_type)
