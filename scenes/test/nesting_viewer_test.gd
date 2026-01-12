extends Control
## 嵌套查看器测试场景

@onready var open_viewer_button: Button = $VBox/OpenViewerButton
@onready var load_sample_button: Button = $VBox/LoadSampleButton
@onready var spell_name_label: Label = $VBox/SpellNameLabel

var test_spell: SpellCoreData = null

func _ready() -> void:
	open_viewer_button.pressed.connect(_on_open_viewer_pressed)
	load_sample_button.pressed.connect(_on_load_sample_pressed)
	
	# 自动加载示例法术
	_on_load_sample_pressed()

func _on_load_sample_pressed() -> void:
	test_spell = _create_complex_nested_spell()
	spell_name_label.text = "已加载法术: %s" % test_spell.spell_name
	open_viewer_button.disabled = false

func _on_open_viewer_pressed() -> void:
	if test_spell == null:
		return
	
	var viewer_scene = preload("res://scenes/player/ui/spell_nesting_viewer.tscn")
	var viewer = viewer_scene.instantiate()
	get_tree().root.add_child(viewer)
	viewer.show_spell(test_spell)
	viewer.viewer_closed.connect(func(): viewer.queue_free())

## 创建一个复杂的多层嵌套法术用于测试
func _create_complex_nested_spell() -> SpellCoreData:
	var spell = SpellCoreData.new()
	spell.generate_id()
	spell.spell_name = "三层嵌套裂变测试法术"
	spell.resource_cost = 50.0
	spell.cooldown = 2.0
	
	# 载体配置
	spell.carrier = CarrierConfigData.new()
	spell.carrier.carrier_type = CarrierConfigData.CarrierType.PROJECTILE
	spell.carrier.phase = CarrierConfigData.Phase.PLASMA
	spell.carrier.velocity = 300.0
	spell.carrier.lifetime = 3.0
	spell.carrier.mass = 1.0
	spell.carrier.size = 1.0
	
	# 规则1: 碰撞时造成伤害
	var rule1 = TopologyRuleData.new()
	rule1.rule_name = "碰撞伤害"
	rule1.trigger = TriggerData.new()
	rule1.trigger.trigger_type = TriggerData.TriggerType.ON_CONTACT
	rule1.trigger.trigger_once = true
	
	var damage1 = DamageActionData.new()
	damage1.damage_value = 30.0
	damage1.damage_multiplier = 1.0
	rule1.actions.append(damage1)
	
	spell.topology_rules.append(rule1)
	
	# 规则2: 死亡时裂变(第1层)
	var rule2 = TopologyRuleData.new()
	rule2.rule_name = "死亡裂变"
	rule2.trigger = TriggerData.new()
	rule2.trigger.trigger_type = TriggerData.TriggerType.ON_DEATH
	rule2.trigger.trigger_once = true
	
	var fission1 = FissionActionData.new()
	fission1.spawn_count = 4
	fission1.spread_angle = 90.0
	fission1.child_spell_data = _create_level2_spell()
	rule2.actions.append(fission1)
	
	spell.topology_rules.append(rule2)
	
	# 规则3: 定时召唤
	var rule3 = TopologyRuleData.new()
	rule3.rule_name = "定时召唤"
	var timer_trigger = OnTimerTrigger.new()
	timer_trigger.trigger_type = TriggerData.TriggerType.ON_TIMER
	timer_trigger.delay = 1.0
	timer_trigger.repeat_interval = 0.0
	rule3.trigger = timer_trigger
	
	var summon1 = SummonActionData.new()
	summon1.summon_type = SummonActionData.SummonType.ORBITER
	summon1.summon_count = 3
	summon1.summon_duration = 5.0
	summon1.summon_damage = 15.0
	summon1.summon_health = 50.0
	rule3.actions.append(summon1)
	
	spell.topology_rules.append(rule3)
	
	return spell

## 创建第2层子法术
func _create_level2_spell() -> SpellCoreData:
	var spell = SpellCoreData.new()
	spell.generate_id()
	spell.spell_name = "第2层子弹"
	spell.resource_cost = 20.0
	spell.cooldown = 0.5
	
	spell.carrier = CarrierConfigData.new()
	spell.carrier.carrier_type = CarrierConfigData.CarrierType.PROJECTILE
	spell.carrier.phase = CarrierConfigData.Phase.LIQUID
	spell.carrier.velocity = 250.0
	spell.carrier.lifetime = 2.0
	
	# 碰撞伤害
	var rule1 = TopologyRuleData.new()
	rule1.rule_name = "碰撞伤害"
	rule1.trigger = TriggerData.new()
	rule1.trigger.trigger_type = TriggerData.TriggerType.ON_CONTACT
	
	var damage = DamageActionData.new()
	damage.damage_value = 15.0
	rule1.actions.append(damage)
	spell.topology_rules.append(rule1)
	
	# 死亡时再次裂变(第2层)
	var rule2 = TopologyRuleData.new()
	rule2.rule_name = "二次裂变"
	rule2.trigger = TriggerData.new()
	rule2.trigger.trigger_type = TriggerData.TriggerType.ON_DEATH
	
	var fission2 = FissionActionData.new()
	fission2.spawn_count = 3
	fission2.spread_angle = 120.0
	fission2.child_spell_data = _create_level3_spell()
	rule2.actions.append(fission2)
	
	spell.topology_rules.append(rule2)
	
	# 范围效果
	var rule3 = TopologyRuleData.new()
	rule3.rule_name = "范围伤害"
	rule3.trigger = TriggerData.new()
	rule3.trigger.trigger_type = TriggerData.TriggerType.ON_CONTACT
	
	var area = AreaEffectActionData.new()
	area.radius = 50.0
	area.damage_value = 10.0
	rule3.actions.append(area)
	
	spell.topology_rules.append(rule3)
	
	return spell

## 创建第3层子法术
func _create_level3_spell() -> SpellCoreData:
	var spell = SpellCoreData.new()
	spell.generate_id()
	spell.spell_name = "第3层子弹(最终)"
	spell.resource_cost = 10.0
	spell.cooldown = 0.3
	
	spell.carrier = CarrierConfigData.new()
	spell.carrier.carrier_type = CarrierConfigData.CarrierType.PROJECTILE
	spell.carrier.phase = CarrierConfigData.Phase.SOLID
	spell.carrier.velocity = 200.0
	spell.carrier.lifetime = 1.5
	
	# 简单的碰撞伤害
	var rule = TopologyRuleData.new()
	rule.rule_name = "碰撞伤害"
	rule.trigger = TriggerData.new()
	rule.trigger.trigger_type = TriggerData.TriggerType.ON_CONTACT
	
	var damage = DamageActionData.new()
	damage.damage_value = 8.0
	rule.actions.append(damage)
	
	# 爆炸效果
	var explosion = SpawnExplosionActionData.new()
	explosion.explosion_damage = 12.0
	explosion.explosion_radius = 30.0
	rule.actions.append(explosion)
	
	spell.topology_rules.append(rule)
	
	return spell
