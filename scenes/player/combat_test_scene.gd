# combat_test_scene.gd
# 战斗测试场景 - 用于测试角色战斗系统、法术刻录系统和熟练度系统
extends Node2D

## 节点引用
@onready var player: PlayerController = $Player
@onready var enemy_container: Node2D = $EnemyContainer
@onready var state_label: Label = $UI/TopPanel/StateLabel
@onready var weapon_label: Label = $UI/TopPanel/WeaponLabel
@onready var weapon_list: ItemList = $UI/LeftPanel/WeaponList
@onready var spell_list: ItemList = $UI/LeftPanel/SpellList
@onready var health_label: Label = $UI/StatsPanel/HealthLabel
@onready var damage_label: Label = $UI/StatsPanel/DamageLabel
@onready var hits_label: Label = $UI/StatsPanel/HitsLabel
@onready var engravings_label: Label = $UI/StatsPanel/EngravingsLabel
@onready var spawn_enemy_button: Button = $UI/TopPanel/SpawnEnemyButton
@onready var clear_enemies_button: Button = $UI/TopPanel/ClearEnemiesButton
@onready var engraving_button: Button = $UI/TopPanel/EngravingButton
@onready var back_button: Button = $UI/TopPanel/BackButton

## 刻录面板
var engraving_panel: EngravingPanel = null
var engraving_panel_scene: PackedScene

## 预加载
var dummy_enemy_scene: PackedScene

## 可用武器列表
var available_weapons: Array[WeaponData] = []

## 可用法术列表（投射物法术）
var available_spells: Array[SpellCoreData] = []

## 可用刻录法术列表
var available_engraving_spells: Array[SpellCoreData] = []

func _ready() -> void:
	# 加载场景
	dummy_enemy_scene = preload("res://scenes/battle_test/entities/dummy_enemy.tscn")
	engraving_panel_scene = preload("res://scenes/player/ui/engraving_panel.tscn")
	
	# 设置UI回调
	_setup_ui()
	
	# 初始化武器列表
	_init_weapons()
	
	# 初始化法术列表
	_init_spells()
	
	# 初始化刻录法术列表
	_init_engraving_spells()
	
	# 连接玩家信号
	_connect_player_signals()
	
	# 生成初始敌人
	_spawn_initial_enemies()
	
	# 创建刻录面板
	_create_engraving_panel()

func _process(_delta: float) -> void:
	_update_ui()

## 设置UI
func _setup_ui() -> void:
	spawn_enemy_button.pressed.connect(_on_spawn_enemy_pressed)
	clear_enemies_button.pressed.connect(_on_clear_enemies_pressed)
	engraving_button.pressed.connect(_on_engraving_button_pressed)
	back_button.pressed.connect(_on_back_pressed)
	weapon_list.item_selected.connect(_on_weapon_selected)
	spell_list.item_selected.connect(_on_spell_selected)

## 初始化武器
func _init_weapons() -> void:
	# 获取所有预设武器
	available_weapons = WeaponPresets.get_all_presets()
	
	# 为每个武器初始化刻录槽
	for weapon in available_weapons:
		if weapon.engraving_slots.is_empty():
			weapon.initialize_engraving_slots()
	
	# 更新武器列表UI
	weapon_list.clear()
	for i in range(available_weapons.size()):
		var weapon = available_weapons[i]
		var slot_info = " [槽位:%d]" % weapon.get_engraving_slot_count() if weapon.get_engraving_slot_count() > 0 else ""
		weapon_list.add_item("%d. %s%s" % [i + 1, weapon.weapon_name, slot_info])
	
	# 选择第一把武器
	if available_weapons.size() > 0:
		weapon_list.select(0)
		_on_weapon_selected(0)

## 初始化法术
func _init_spells() -> void:
	# 创建一些测试法术
	available_spells = _create_test_spells()
	
	# 更新法术列表UI
	_refresh_spell_list()
	
	# 选择第一个法术
	if available_spells.size() > 0:
		spell_list.select(0)
		_on_spell_selected(0)

## 刷新法术列表（包含熟练度信息）
func _refresh_spell_list() -> void:
	spell_list.clear()
	for i in range(available_spells.size()):
		var spell = available_spells[i]
		var proficiency = _get_spell_proficiency(spell.spell_id)
		var prof_text = " (%.0f%%)" % (proficiency * 100) if proficiency > 0 else ""
		spell_list.add_item("%d. %s%s" % [i + 1, spell.spell_name, prof_text])

## 获取法术熟练度
func _get_spell_proficiency(spell_id: String) -> float:
	if player == null or player.engraving_manager == null:
		return 0.0
	return player.engraving_manager.get_spell_proficiency(spell_id)

## 初始化刻录法术
func _init_engraving_spells() -> void:
	# 获取所有预设刻录法术
	available_engraving_spells = EngravingSpellPresets.get_all_presets()

## 创建测试法术
func _create_test_spells() -> Array[SpellCoreData]:
	var spells: Array[SpellCoreData] = []
	
	# 火球术
	var fireball = SpellCoreData.new()
	fireball.generate_id()
	fireball.spell_name = "火球术"
	fireball.description = "发射一枚火球，造成范围伤害"
	fireball.spell_type = SpellCoreData.SpellType.PROJECTILE
	fireball.resource_cost = 25.0
	fireball.base_windup_time = 0.6
	fireball.cost_windup_ratio = 0.02
	fireball.carrier = CarrierConfigData.new()
	fireball.carrier.phase = CarrierConfigData.Phase.PLASMA
	fireball.carrier.velocity = 400.0
	fireball.carrier.lifetime = 3.0
	fireball.carrier.mass = 2.0
	fireball.carrier.size = 1.5
	
	var fireball_rule = TopologyRuleData.new()
	fireball_rule.rule_name = "爆炸伤害"
	fireball_rule.trigger = TriggerData.new()
	fireball_rule.trigger.trigger_type = TriggerData.TriggerType.ON_CONTACT
	
	var fireball_damage = DamageActionData.new()
	fireball_damage.damage_value = 30.0
	var fireball_actions: Array[ActionData] = [fireball_damage]
	fireball_rule.actions = fireball_actions
	
	var fireball_rules: Array[TopologyRuleData] = [fireball_rule]
	fireball.topology_rules = fireball_rules
	
	spells.append(fireball)
	
	# 冰箭
	var ice_arrow = SpellCoreData.new()
	ice_arrow.generate_id()
	ice_arrow.spell_name = "冰箭"
	ice_arrow.description = "发射穿透性冰箭"
	ice_arrow.spell_type = SpellCoreData.SpellType.PROJECTILE
	ice_arrow.resource_cost = 15.0
	ice_arrow.base_windup_time = 0.3
	ice_arrow.cost_windup_ratio = 0.015
	ice_arrow.carrier = CarrierConfigData.new()
	ice_arrow.carrier.phase = CarrierConfigData.Phase.SOLID
	ice_arrow.carrier.velocity = 600.0
	ice_arrow.carrier.lifetime = 2.0
	ice_arrow.carrier.mass = 1.0
	ice_arrow.carrier.size = 0.8
	ice_arrow.carrier.piercing = 2
	
	var ice_rule = TopologyRuleData.new()
	ice_rule.rule_name = "穿透伤害"
	ice_rule.trigger = TriggerData.new()
	ice_rule.trigger.trigger_type = TriggerData.TriggerType.ON_CONTACT
	
	var ice_damage = DamageActionData.new()
	ice_damage.damage_value = 15.0
	var ice_actions: Array[ActionData] = [ice_damage]
	ice_rule.actions = ice_actions
	
	var ice_rules: Array[TopologyRuleData] = [ice_rule]
	ice_arrow.topology_rules = ice_rules
	
	spells.append(ice_arrow)
	
	# 追踪弹
	var homing = SpellCoreData.new()
	homing.generate_id()
	homing.spell_name = "追踪弹"
	homing.description = "自动追踪最近敌人的魔法弹"
	homing.spell_type = SpellCoreData.SpellType.PROJECTILE
	homing.resource_cost = 20.0
	homing.base_windup_time = 0.4
	homing.cost_windup_ratio = 0.02
	homing.carrier = CarrierConfigData.new()
	homing.carrier.phase = CarrierConfigData.Phase.LIQUID
	homing.carrier.velocity = 300.0
	homing.carrier.lifetime = 5.0
	homing.carrier.mass = 0.5
	homing.carrier.size = 1.0
	homing.carrier.homing_strength = 5.0
	
	var homing_rule = TopologyRuleData.new()
	homing_rule.rule_name = "追踪伤害"
	homing_rule.trigger = TriggerData.new()
	homing_rule.trigger.trigger_type = TriggerData.TriggerType.ON_CONTACT
	
	var homing_damage = DamageActionData.new()
	homing_damage.damage_value = 20.0
	var homing_actions: Array[ActionData] = [homing_damage]
	homing_rule.actions = homing_actions
	
	var homing_rules: Array[TopologyRuleData] = [homing_rule]
	homing.topology_rules = homing_rules
	
	spells.append(homing)
	
	# 陨石术（高cost高前摇）
	var meteor = SpellCoreData.new()
	meteor.generate_id()
	meteor.spell_name = "陨石术"
	meteor.description = "召唤巨大陨石，造成毁灭性伤害（需要较长蓄能）"
	meteor.spell_type = SpellCoreData.SpellType.PROJECTILE
	meteor.resource_cost = 80.0
	meteor.base_windup_time = 1.5
	meteor.cost_windup_ratio = 0.025
	meteor.carrier = CarrierConfigData.new()
	meteor.carrier.phase = CarrierConfigData.Phase.SOLID
	meteor.carrier.velocity = 250.0
	meteor.carrier.lifetime = 4.0
	meteor.carrier.mass = 10.0
	meteor.carrier.size = 3.0
	
	var meteor_rule = TopologyRuleData.new()
	meteor_rule.rule_name = "陨石撞击"
	meteor_rule.trigger = TriggerData.new()
	meteor_rule.trigger.trigger_type = TriggerData.TriggerType.ON_CONTACT
	
	var meteor_damage = DamageActionData.new()
	meteor_damage.damage_value = 100.0
	var meteor_actions: Array[ActionData] = [meteor_damage]
	meteor_rule.actions = meteor_actions
	
	var meteor_rules: Array[TopologyRuleData] = [meteor_rule]
	meteor.topology_rules = meteor_rules
	
	spells.append(meteor)
	
	# 快速魔弹（低cost低前摇）
	var magic_bolt = SpellCoreData.new()
	magic_bolt.generate_id()
	magic_bolt.spell_name = "魔法弹"
	magic_bolt.description = "快速发射的基础魔法弹"
	magic_bolt.spell_type = SpellCoreData.SpellType.PROJECTILE
	magic_bolt.resource_cost = 5.0
	magic_bolt.base_windup_time = 0.1
	magic_bolt.cost_windup_ratio = 0.01
	magic_bolt.carrier = CarrierConfigData.new()
	magic_bolt.carrier.phase = CarrierConfigData.Phase.PLASMA
	magic_bolt.carrier.velocity = 500.0
	magic_bolt.carrier.lifetime = 2.0
	magic_bolt.carrier.mass = 0.3
	magic_bolt.carrier.size = 0.5
	
	var bolt_rule = TopologyRuleData.new()
	bolt_rule.rule_name = "魔弹伤害"
	bolt_rule.trigger = TriggerData.new()
	bolt_rule.trigger.trigger_type = TriggerData.TriggerType.ON_CONTACT
	
	var bolt_damage = DamageActionData.new()
	bolt_damage.damage_value = 8.0
	var bolt_actions: Array[ActionData] = [bolt_damage]
	bolt_rule.actions = bolt_actions
	
	var bolt_rules: Array[TopologyRuleData] = [bolt_rule]
	magic_bolt.topology_rules = bolt_rules
	
	spells.append(magic_bolt)
	
	return spells

## 创建刻录面板
func _create_engraving_panel() -> void:
	engraving_panel = engraving_panel_scene.instantiate() as EngravingPanel
	engraving_panel.visible = false
	$UI.add_child(engraving_panel)
	
	# 连接信号
	engraving_panel.spell_engraved.connect(_on_spell_engraved)
	engraving_panel.spell_removed.connect(_on_spell_removed)
	engraving_panel.panel_closed.connect(_on_engraving_panel_closed)

## 连接玩家信号
func _connect_player_signals() -> void:
	if player == null:
		return
	
	player.state_changed.connect(_on_player_state_changed)
	player.weapon_changed.connect(_on_player_weapon_changed)
	player.attack_hit.connect(_on_player_attack_hit)
	player.spell_cast.connect(_on_player_spell_cast)
	
	# 连接刻录管理器信号
	if player.engraving_manager != null:
		player.engraving_manager.engraving_triggered.connect(_on_engraving_triggered)
		player.engraving_manager.proficiency_updated.connect(_on_proficiency_updated)
		player.engraving_manager.engraving_windup_started.connect(_on_engraving_windup_started)

## 生成初始敌人
func _spawn_initial_enemies() -> void:
	_spawn_enemy(Vector2(700, 300))
	_spawn_enemy(Vector2(700, 400))
	_spawn_enemy(Vector2(300, 350))

## 生成敌人
func _spawn_enemy(pos: Vector2) -> void:
	if dummy_enemy_scene == null:
		return
	
	var enemy = dummy_enemy_scene.instantiate()
	enemy.global_position = pos
	enemy_container.add_child(enemy)

## 更新UI
func _update_ui() -> void:
	if player == null:
		return
	
	# 更新状态标签（包含施法阶段）
	var state_name = "Unknown"
	if player.state_machine != null:
		state_name = player.state_machine.get_current_state_name()
		
		# 如果在施法状态，显示施法阶段
		var current_state = player.state_machine.current_state
		if current_state is SpellCastState:
			var cast_state = current_state as SpellCastState
			state_name += " (%s %.0f%%)" % [cast_state.get_phase_name(), cast_state.get_cast_progress() * 100]
	
	state_label.text = "状态: %s" % state_name
	
	# 更新武器标签
	var weapon_name = "无"
	if player.current_weapon != null:
		weapon_name = player.current_weapon.weapon_name
	weapon_label.text = "武器: %s" % weapon_name
	
	# 更新统计
	var stats = player.get_stats()
	health_label.text = "HP: %.0f/%.0f" % [player.current_health, player.max_health]
	damage_label.text = "伤害: %.0f" % stats.total_damage_dealt
	hits_label.text = "命中: %d" % stats.total_hits
	
	# 更新刻录统计
	if engravings_label != null:
		var trigger_count = 0
		if player.engraving_manager != null:
			trigger_count = player.engraving_manager.get_trigger_count()
		engravings_label.text = "刻录触发: %d" % trigger_count

## 处理输入
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key = event.keycode
		
		# 数字键1-6切换武器
		if key >= KEY_1 and key <= KEY_6:
			var index = key - KEY_1
			if index < available_weapons.size():
				weapon_list.select(index)
				_on_weapon_selected(index)
		
		# E键打开刻录面板
		if key == KEY_E:
			_toggle_engraving_panel()
		
		# ESC键关闭刻录面板
		if key == KEY_ESCAPE and engraving_panel != null and engraving_panel.visible:
			engraving_panel.hide_panel()
		
		# P键显示熟练度统计
		if key == KEY_P:
			_print_proficiency_stats()

## 打印熟练度统计
func _print_proficiency_stats() -> void:
	if player == null or player.engraving_manager == null:
		return
	
	print("\n=== 熟练度统计 ===")
	var stats = player.engraving_manager.get_stats()
	print(stats.proficiency_stats)
	
	print("\n--- 法术前摇信息 ---")
	for spell in available_spells:
		var proficiency = _get_spell_proficiency(spell.spell_id)
		var normal_windup = spell.calculate_windup_time(proficiency, false)
		var engraved_windup = spell.calculate_windup_time(proficiency, true)
		print("%s: 熟练度 %.0f%% | 普通前摇 %.2fs | 刻录前摇 %.2fs" % [
			spell.spell_name,
			proficiency * 100,
			normal_windup,
			engraved_windup
		])
	print("==================\n")

## 切换刻录面板
func _toggle_engraving_panel() -> void:
	if engraving_panel == null:
		return
	
	if engraving_panel.visible:
		engraving_panel.hide_panel()
	else:
		# 合并投射物法术和刻录法术
		var all_spells: Array[SpellCoreData] = []
		all_spells.append_array(available_spells)
		all_spells.append_array(available_engraving_spells)
		
		engraving_panel.initialize(player, all_spells)
		engraving_panel.show_panel()

## 武器选择回调
func _on_weapon_selected(index: int) -> void:
	if index < 0 or index >= available_weapons.size():
		return
	
	var weapon = available_weapons[index]
	if player != null:
		player.set_weapon(weapon)

## 法术选择回调
func _on_spell_selected(index: int) -> void:
	if index < 0 or index >= available_spells.size():
		return
	
	var spell = available_spells[index]
	if player != null:
		player.set_spell(spell)
		
		# 显示法术前摇信息
		var proficiency = _get_spell_proficiency(spell.spell_id)
		var normal_windup = spell.calculate_windup_time(proficiency, false)
		print("[选择法术] %s | 消耗: %.0f | 前摇: %.2fs | 熟练度: %.0f%%" % [
			spell.spell_name,
			spell.resource_cost,
			normal_windup,
			proficiency * 100
		])

## 生成敌人按钮回调
func _on_spawn_enemy_pressed() -> void:
	var x = randf_range(200, 800)
	var y = randf_range(150, 550)
	_spawn_enemy(Vector2(x, y))

## 清除敌人按钮回调
func _on_clear_enemies_pressed() -> void:
	for enemy in enemy_container.get_children():
		enemy.queue_free()

## 刻录按钮回调
func _on_engraving_button_pressed() -> void:
	_toggle_engraving_panel()

## 返回按钮回调
func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")

## 玩家状态改变回调
func _on_player_state_changed(state_name: String) -> void:
	print("玩家状态: %s" % state_name)

## 玩家武器改变回调
func _on_player_weapon_changed(weapon: WeaponData) -> void:
	print("装备武器: %s" % weapon.weapon_name)

## 玩家攻击命中回调
func _on_player_attack_hit(target: Node2D, damage: float) -> void:
	print("攻击命中: %s, 伤害: %.1f" % [target.name, damage])

## 玩家施法回调
func _on_player_spell_cast(spell: SpellCoreData) -> void:
	print("施放法术: %s" % spell.spell_name)
	# 刷新法术列表以更新熟练度显示
	_refresh_spell_list()

## 刻录触发回调
func _on_engraving_triggered(trigger_type: int, spell: SpellCoreData, source: String) -> void:
	var trigger_name = TriggerData.new()
	trigger_name.trigger_type = trigger_type
	print("[刻录效果] %s 触发了 %s (来源: %s)" % [trigger_name.get_type_name(), spell.spell_name, source])

## 熟练度更新回调
func _on_proficiency_updated(spell_id: String, proficiency: float) -> void:
	# 刷新法术列表以更新熟练度显示
	_refresh_spell_list()

## 刻录前摇开始回调
func _on_engraving_windup_started(slot: EngravingSlot, windup_time: float) -> void:
	print("[刻录蓄能] %s 开始蓄能 %.2fs" % [slot.slot_name, windup_time])

## 法术刻录回调
func _on_spell_engraved(target_type: String, target_index: int, slot_index: int, spell: SpellCoreData) -> void:
	print("刻录成功: %s -> %s[%d] 槽位%d" % [spell.spell_name, target_type, target_index, slot_index])

## 法术移除回调
func _on_spell_removed(target_type: String, target_index: int, slot_index: int) -> void:
	print("移除刻录: %s[%d] 槽位%d" % [target_type, target_index, slot_index])

## 刻录面板关闭回调
func _on_engraving_panel_closed() -> void:
	print("刻录面板已关闭")
