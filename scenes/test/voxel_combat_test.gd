extends Node2D

# 二维体素战斗系统测试场景
# 用于测试肢体目标伤害、肢体摧毁、法术失效等核心功能

@onready var player: PlayerController = $Player
@onready var enemy: Enemy = $Enemy
@onready var ui: CanvasLayer = $UI
@onready var log_label: RichTextLabel = $UI/LogLabel
@onready var player_status_label: Label = $UI/PlayerStatusLabel
@onready var enemy_status_label: Label = $UI/EnemyStatusLabel

var test_spell: SpellCoreData

func _ready() -> void:
	# 设置敌人和玩家的位置
	player.global_position = Vector2(200, 300)
	enemy.global_position = Vector2(800, 300)
	enemy.set_target_position(player.global_position)

	# 创建一个用于测试的法术
	_create_test_spell()
	
	# 将测试法术篆刻到玩家的右臂和右手上
	player.engrave_to_body(BodyPartData.PartType.RIGHT_ARM, 0, test_spell)
	player.engrave_to_body(BodyPartData.PartType.RIGHT_HAND, 0, test_spell)
	
	# 连接信号
	player.body_part_destroyed.connect(_on_player_part_destroyed)
	enemy.body_part_destroyed.connect(_on_enemy_part_destroyed)
	
	log("测试场景已初始化。")
	log("玩家右臂和右手已篆刻 '测试闪电' 法术。")
	log("按 [1] 攻击敌人躯干。")
	log("按 [2] 攻击敌人右臂。")
	log("按 [3] 攻击敌人腿部。")
	log("按 [4] 恢复敌人所有肢体。")
	log("按 [5] 触发玩家右臂法术 (如果功能正常)。")

func _process(_delta: float) -> void:
	_update_status_labels()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				_attack_enemy_part(BodyPartData.PartType.TORSO)
			KEY_2:
				_attack_enemy_part(BodyPartData.PartType.RIGHT_ARM)
			KEY_3:
				_attack_enemy_part(BodyPartData.PartType.LEGS)
			KEY_4:
				_restore_enemy_parts()
			KEY_5:
				_trigger_player_spell()

func _create_test_spell() -> void:
	test_spell = SpellCoreData.new()
	test_spell.spell_name = "测试闪电"
	
	var rule = TopologyRuleData.new()
	
	# 设置一个手动触发器（这里用ON_ATTACK_START代替，方便测试）
	var trigger = TriggerData.new()
	trigger.trigger_type = TriggerData.TriggerType.ON_ATTACK_START
	rule.trigger = trigger
	
	# 设置一个伤害动作
	var action = DamageActionData.new()
	action.damage_value = 25.0
	action.damage_type = CarrierConfigData.DamageType.ENTROPY_BURST
	rule.actions.append(action)
	
	test_spell.topology_rules.append(rule)

func _attack_enemy_part(part_type: int) -> void:
	var part_name = BodyPartData.new().get_type_name()
	log("玩家攻击敌人的 %s..." % part_name)
	enemy.take_damage(30.0, 0, part_type)

func _restore_enemy_parts() -> void:
	log("恢复敌人所有肢体...")
	for part in enemy.body_parts:
		part.fully_restore()
	enemy.get_energy_system().restore_energy_cap(9999)

func _trigger_player_spell() -> void:
	log("尝试触发玩家右臂的法术...")
	var context = {"player": player, "position": player.global_position}
	player.get_engraving_manager().distribute_trigger(TriggerData.TriggerType.ON_ATTACK_START, context)

func _on_player_part_destroyed(part: BodyPartData) -> void:
	log("[玩家肢体摧毁] %s 已被摧毁！" % part.part_name, Color.ORANGE_RED)

func _on_enemy_part_destroyed(part: BodyPartData) -> void:
	log("[敌人肢体摧毁] 敌人的 %s 已被摧毁！" % part.part_name, Color.PALE_VIOLET_RED)

func _update_status_labels() -> void:
	player_status_label.text = "玩家状态:\n" + player.get_body_parts_summary()
	enemy_status_label.text = "敌人状态:\n" + enemy.get_body_parts_summary()

func log(message: String, color: Color = Color.WHITE) -> void:
	print(message)
	log_label.add_text("\n- " + message)
	log_label.scroll_to_bottom()
