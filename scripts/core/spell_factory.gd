# spell_factory.gd
# 法术工厂 - 负责随机生成和创建法术
extends Node

## 生成配置
var config = {
	"mass_range": Vector2(0.5, 5.0),
	"velocity_range": Vector2(200.0, 800.0),
	"lifetime_range": Vector2(1.0, 8.0),
	"size_range": Vector2(0.5, 2.0),
	"damage_range": Vector2(5.0, 50.0),
	"timer_delay_range": Vector2(0.2, 3.0),
	"radius_range": Vector2(30.0, 150.0),
	"spawn_count_range": Vector2i(2, 8),
	"max_rules": 4,
	"max_actions_per_rule": 3
}

## 生成随机法术
func generate_random_spell() -> SpellCoreData:
	var spell = SpellCoreData.new()
	spell.generate_id()
	spell.spell_name = _generate_spell_name()
	
	# 生成载体
	spell.carrier = _generate_random_carrier()
	
	# 生成拓扑规则（1-4条）
	var rule_count = randi_range(1, config.max_rules)
	for i in range(rule_count):
		var rule = _generate_random_rule()
		rule.rule_name = "规则_%d" % (i + 1)
		spell.topology_rules.append(rule)
	
	# 计算资源消耗
	spell.resource_cost = _calculate_resource_cost(spell)
	spell.cooldown = randf_range(0.5, 3.0)
	
	return spell

## 生成随机载体配置
func _generate_random_carrier() -> CarrierConfigData:
	var carrier = CarrierConfigData.new()
	carrier.phase = randi() % 3  # 随机相态
	carrier.mass = randf_range(config.mass_range.x, config.mass_range.y)
	carrier.velocity = randf_range(config.velocity_range.x, config.velocity_range.y)
	carrier.lifetime = randf_range(config.lifetime_range.x, config.lifetime_range.y)
	carrier.size = randf_range(config.size_range.x, config.size_range.y)
	carrier.piercing = randi_range(0, 3)
	carrier.homing_strength = randf() * 0.5 if randf() < 0.3 else 0.0  # 30%概率有追踪
	carrier.instability_cost = randf_range(0.0, 5.0)
	return carrier

## 生成随机拓扑规则
func _generate_random_rule() -> TopologyRuleData:
	var rule = TopologyRuleData.new()
	
	# 生成触发器
	rule.trigger = _generate_random_trigger()
	
	# 生成动作（1-3个）
	var action_count = randi_range(1, config.max_actions_per_rule)
	for i in range(action_count):
		var action = _generate_random_action()
		rule.actions.append(action)
	
	return rule

## 生成随机触发器
func _generate_random_trigger() -> TriggerData:
	var trigger_type = randi() % 4  # 0-3
	var trigger: TriggerData
	
	match trigger_type:
		TriggerData.TriggerType.ON_CONTACT:
			trigger = TriggerData.new()
			trigger.trigger_type = TriggerData.TriggerType.ON_CONTACT
		TriggerData.TriggerType.ON_TIMER:
			var timer_trigger = OnTimerTrigger.new()
			timer_trigger.delay = randf_range(config.timer_delay_range.x, config.timer_delay_range.y)
			timer_trigger.repeat_interval = randf_range(0.5, 2.0) if randf() < 0.3 else 0.0
			trigger = timer_trigger
		TriggerData.TriggerType.ON_PROXIMITY:
			var prox_trigger = OnProximityTrigger.new()
			prox_trigger.detection_radius = randf_range(50.0, 200.0)
			trigger = prox_trigger
		_:
			trigger = TriggerData.new()
			trigger.trigger_type = TriggerData.TriggerType.ON_DEATH
	
	trigger.trigger_once = randf() > 0.3  # 70%概率只触发一次
	return trigger

## 生成随机动作
func _generate_random_action(allow_fission: bool = true) -> ActionData:
	var action_type = randi() % 4  # 0-3
	
	# 控制裂变的生成概率
	if action_type == ActionData.ActionType.FISSION and (not allow_fission or randf() > 0.4):
		action_type = ActionData.ActionType.DAMAGE
	
	var action: ActionData
	
	match action_type:
		ActionData.ActionType.DAMAGE:
			action = _generate_damage_action()
		ActionData.ActionType.FISSION:
			action = _generate_fission_action()
		ActionData.ActionType.APPLY_STATUS:
			action = _generate_status_action()
		ActionData.ActionType.AREA_EFFECT:
			action = _generate_area_effect_action()
		_:
			action = _generate_damage_action()
	
	return action

## 生成伤害动作
func _generate_damage_action() -> DamageActionData:
	var action = DamageActionData.new()
	action.damage_value = randf_range(config.damage_range.x, config.damage_range.y)
	action.damage_type = randi() % 4
	action.use_carrier_kinetic = randf() > 0.5
	action.damage_multiplier = randf_range(0.8, 1.5)
	return action

## 生成裂变动作
func _generate_fission_action() -> FissionActionData:
	var action = FissionActionData.new()
	action.spawn_count = randi_range(config.spawn_count_range.x, config.spawn_count_range.y)
	action.spread_angle = randf_range(30.0, 360.0)
	action.inherit_velocity = randf_range(0.3, 0.8)
	action.spawn_offset = randf_range(5.0, 20.0)
	
	# 生成简化的子法术（避免过深递归）
	action.child_spell_data = _generate_simple_child_spell()
	
	return action

## 生成简化的子法术（用于裂变）
func _generate_simple_child_spell() -> SpellCoreData:
	var spell = SpellCoreData.new()
	spell.generate_id()
	spell.spell_name = "子弹"
	
	# 简化载体
	spell.carrier = CarrierConfigData.new()
	spell.carrier.phase = randi() % 3
	spell.carrier.mass = randf_range(0.3, 1.5)
	spell.carrier.velocity = randf_range(300.0, 600.0)
	spell.carrier.lifetime = randf_range(1.0, 3.0)
	spell.carrier.size = randf_range(0.3, 1.0)
	
	# 只有一条简单规则
	var rule = TopologyRuleData.new()
	rule.rule_name = "碰撞伤害"
	rule.trigger = TriggerData.new()
	rule.trigger.trigger_type = TriggerData.TriggerType.ON_CONTACT
	rule.actions.append(_generate_damage_action())
	spell.topology_rules.append(rule)
	
	return spell

## 生成状态效果动作
func _generate_status_action() -> ApplyStatusActionData:
	var action = ApplyStatusActionData.new()
	action.status_type = randi() % 6
	action.duration = randf_range(1.0, 5.0)
	action.tick_interval = randf_range(0.3, 1.0)
	action.effect_value = randf_range(3.0, 15.0)
	action.stack_limit = randi_range(1, 5)
	return action

## 生成范围效果动作
func _generate_area_effect_action() -> AreaEffectActionData:
	var action = AreaEffectActionData.new()
	action.area_shape = randi() % 4
	action.radius = randf_range(config.radius_range.x, config.radius_range.y)
	action.angle = randf_range(45.0, 180.0)
	action.length = randf_range(50.0, 150.0)
	action.width = randf_range(15.0, 50.0)
	action.damage_value = randf_range(config.damage_range.x * 0.5, config.damage_range.y * 0.8)
	action.damage_falloff = randf_range(0.3, 0.8)
	return action

## 计算资源消耗
func _calculate_resource_cost(spell: SpellCoreData) -> float:
	var cost = 5.0  # 基础消耗
	
	if spell.carrier != null:
		cost += spell.carrier.mass * 2.0
		cost += spell.carrier.velocity * 0.01
		cost += spell.carrier.piercing * 3.0
		cost += spell.carrier.homing_strength * 10.0
	
	for rule in spell.topology_rules:
		cost += 2.0  # 每条规则增加消耗
		for action in rule.actions:
			if action is DamageActionData:
				cost += action.damage_value * 0.2
			elif action is FissionActionData:
				cost += action.spawn_count * 3.0
			elif action is AreaEffectActionData:
				cost += action.radius * 0.1
	
	return cost

## 生成法术名称
func _generate_spell_name() -> String:
	var prefixes = ["炎", "冰", "雷", "风", "暗", "光", "毒", "灵", "玄", "天"]
	var middles = ["焰", "霜", "电", "刃", "影", "芒", "蚀", "魂", "元", "罡"]
	var suffixes = ["弹", "箭", "球", "波", "刺", "爆", "环", "雨", "阵", "诀"]
	
	return prefixes[randi() % prefixes.size()] + middles[randi() % middles.size()] + suffixes[randi() % suffixes.size()]
