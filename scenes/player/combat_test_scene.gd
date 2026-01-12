# combat_test_scene.gd
# 战斗测试场景 - 用于测试角色战斗系统
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
@onready var spawn_enemy_button: Button = $UI/TopPanel/SpawnEnemyButton
@onready var clear_enemies_button: Button = $UI/TopPanel/ClearEnemiesButton
@onready var back_button: Button = $UI/TopPanel/BackButton

## 预加载
var dummy_enemy_scene: PackedScene

## 可用武器列表
var available_weapons: Array[WeaponData] = []

## 可用法术列表
var available_spells: Array[SpellCoreData] = []

func _ready() -> void:
	# 加载敌人场景
	dummy_enemy_scene = preload("res://scenes/battle_test/entities/dummy_enemy.tscn")
	
	# 设置UI回调
	_setup_ui()
	
	# 初始化武器列表
	_init_weapons()
	
	# 初始化法术列表
	_init_spells()
	
	# 连接玩家信号
	_connect_player_signals()
	
	# 生成初始敌人
	_spawn_initial_enemies()

func _process(_delta: float) -> void:
	_update_ui()

## 设置UI
func _setup_ui() -> void:
	spawn_enemy_button.pressed.connect(_on_spawn_enemy_pressed)
	clear_enemies_button.pressed.connect(_on_clear_enemies_pressed)
	back_button.pressed.connect(_on_back_pressed)
	weapon_list.item_selected.connect(_on_weapon_selected)
	spell_list.item_selected.connect(_on_spell_selected)

## 初始化武器
func _init_weapons() -> void:
	# 获取所有预设武器
	available_weapons = WeaponPresets.get_all_presets()
	
	# 更新武器列表UI
	weapon_list.clear()
	for i in range(available_weapons.size()):
		var weapon = available_weapons[i]
		weapon_list.add_item("%d. %s" % [i + 1, weapon.weapon_name])
	
	# 选择第一把武器
	if available_weapons.size() > 0:
		weapon_list.select(0)
		_on_weapon_selected(0)

## 初始化法术
func _init_spells() -> void:
	# 创建一些测试法术
	available_spells = _create_test_spells()
	
	# 更新法术列表UI
	spell_list.clear()
	for i in range(available_spells.size()):
		var spell = available_spells[i]
		spell_list.add_item("%d. %s" % [i + 1, spell.spell_name])
	
	# 选择第一个法术
	if available_spells.size() > 0:
		spell_list.select(0)
		_on_spell_selected(0)

## 创建测试法术
func _create_test_spells() -> Array[SpellCoreData]:
	var spells: Array[SpellCoreData] = []
	
	# 火球术
	var fireball = SpellCoreData.new()
	fireball.generate_id()
	fireball.spell_name = "火球术"
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
	
	return spells

## 连接玩家信号
func _connect_player_signals() -> void:
	if player == null:
		return
	
	player.state_changed.connect(_on_player_state_changed)
	player.weapon_changed.connect(_on_player_weapon_changed)
	player.attack_hit.connect(_on_player_attack_hit)
	player.spell_cast.connect(_on_player_spell_cast)

## 生成初始敌人
func _spawn_initial_enemies() -> void:
	# 生成几个测试敌人
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
	
	# 更新状态标签
	var state_name = "Unknown"
	if player.state_machine != null:
		state_name = player.state_machine.get_current_state_name()
	state_label.text = "状态: %s" % state_name
	
	# 更新武器标签
	var weapon_name = "无"
	if player.current_weapon != null:
		weapon_name = player.current_weapon.weapon_name
	weapon_label.text = "武器: %s" % weapon_name
	
	# 更新统计
	health_label.text = "HP: %.0f/%.0f" % [player.current_health, player.max_health]
	damage_label.text = "伤害: %.0f" % player.stats.total_damage_dealt
	hits_label.text = "命中: %d" % player.stats.total_hits

## 处理输入（武器切换快捷键）
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key = event.keycode
		# 数字键1-6切换武器
		if key >= KEY_1 and key <= KEY_6:
			var index = key - KEY_1
			if index < available_weapons.size():
				weapon_list.select(index)
				_on_weapon_selected(index)

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

## 生成敌人按钮回调
func _on_spawn_enemy_pressed() -> void:
	# 在随机位置生成敌人
	var x = randf_range(200, 800)
	var y = randf_range(150, 550)
	_spawn_enemy(Vector2(x, y))

## 清除敌人按钮回调
func _on_clear_enemies_pressed() -> void:
	for enemy in enemy_container.get_children():
		enemy.queue_free()

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
