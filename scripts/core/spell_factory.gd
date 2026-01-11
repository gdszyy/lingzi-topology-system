# spell_factory.gd
# 法术工厂 - 负责随机生成和创建法术
extends Node

## 生成配置
var config = {
	"mass_range": Vector2(0.5, 5.0),
	"velocity_range": Vector2(50.0, 800.0),       # 扩展速度范围，支持慢速子弹
	"slow_velocity_range": Vector2(30.0, 150.0),  # 慢速球专用速度范围
	"lifetime_range": Vector2(1.0, 8.0),
	"mine_lifetime_range": Vector2(5.0, 15.0),    # 地雷基础寿命（实际会翻倍）
	"size_range": Vector2(0.5, 2.0),
	"mine_size_range": Vector2(1.0, 2.5),         # 地雷较大以便观察
	"damage_range": Vector2(5.0, 50.0),
	"timer_delay_range": Vector2(0.2, 3.0),
	"radius_range": Vector2(30.0, 150.0),
	"spawn_count_range": Vector2i(2, 8),
	"max_rules": 4,
	"max_actions_per_rule": 3,
	"mine_probability": 0.15,                     # 生成地雷的概率
	"slow_orb_probability": 0.20                  # 生成慢速球的概率
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
	
	# 随机选择载体类型
	var type_roll = randf()
	if type_roll < config.mine_probability:
		# 生成地雷类型
		carrier.carrier_type = CarrierConfigData.CarrierType.MINE
		carrier.velocity = 0.0  # 地雷速度为0
		carrier.lifetime = randf_range(config.mine_lifetime_range.x, config.mine_lifetime_range.y)
		carrier.size = randf_range(config.mine_size_range.x, config.mine_size_range.y)
		carrier.homing_strength = 0.0  # 地雷不追踪
	elif type_roll < config.mine_probability + config.slow_orb_probability:
		# 生成慢速球类型
		carrier.carrier_type = CarrierConfigData.CarrierType.SLOW_ORB
		carrier.velocity = randf_range(config.slow_velocity_range.x, config.slow_velocity_range.y)
		carrier.lifetime = randf_range(config.lifetime_range.x, config.lifetime_range.y * 1.5)  # 稍长寿命
		carrier.size = randf_range(config.size_range.x, config.size_range.y)
		# 慢速球可以有追踪
		if randf() < 0.4:
			carrier.homing_strength = randf_range(0.3, 0.8)
			carrier.homing_range = randf_range(200.0, 400.0)
			carrier.homing_turn_rate = randf_range(3.0, 8.0)
		else:
			carrier.homing_strength = 0.0
	else:
		# 生成普通投射物
		carrier.carrier_type = CarrierConfigData.CarrierType.PROJECTILE
		carrier.velocity = randf_range(config.velocity_range.x, config.velocity_range.y)
		carrier.lifetime = randf_range(config.lifetime_range.x, config.lifetime_range.y)
		carrier.size = randf_range(config.size_range.x, config.size_range.y)
		# 追踪属性 - 30%概率有追踪
		if randf() < 0.3:
			carrier.homing_strength = randf_range(0.2, 1.0)
			carrier.homing_range = randf_range(150.0, 500.0)
			carrier.homing_turn_rate = randf_range(2.0, 10.0)
			carrier.homing_delay = randf_range(0.0, 0.5)
		else:
			carrier.homing_strength = 0.0
	
	carrier.mass = randf_range(config.mass_range.x, config.mass_range.y)
	carrier.piercing = randi_range(0, 3)
	carrier.instability_cost = randf_range(0.0, 5.0)
	# 基础伤害，确保不为0
	carrier.base_damage = maxf(randf_range(config.damage_range.x, config.damage_range.y), 1.0)
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
	var action_type = randi() % 6  # 0-5，扩展了动作类型
	
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
		4:  # 生成爆炸
			action = _generate_explosion_action()
		5:  # 生成伤害区域
			action = _generate_damage_zone_action()
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
	spell.carrier.lifetime = randf_range(1.5, 4.0)  # 增加生命时间
	spell.carrier.size = randf_range(0.8, 1.5)  # 增大尺寸确保可见
	
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

## 生成爆炸动作
func _generate_explosion_action() -> SpawnExplosionActionData:
	var action = SpawnExplosionActionData.new()
	action.explosion_damage = randf_range(config.damage_range.x * 0.8, config.damage_range.y * 1.5)
	action.explosion_radius = randf_range(60.0, 150.0)
	action.damage_falloff = randf_range(0.3, 0.7)
	action.explosion_damage_type = randi() % 4
	return action

## 生成伤害区域动作
func _generate_damage_zone_action() -> SpawnDamageZoneActionData:
	var action = SpawnDamageZoneActionData.new()
	action.zone_damage = randf_range(config.damage_range.x * 0.3, config.damage_range.y * 0.5)
	action.zone_radius = randf_range(50.0, 120.0)
	action.zone_duration = randf_range(2.0, 6.0)
	action.tick_interval = randf_range(0.3, 0.8)
	action.zone_damage_type = randi() % 4
	action.slow_amount = randf_range(0.0, 0.5) if randf() < 0.4 else 0.0  # 40%概率有减速
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
			elif action is SpawnExplosionActionData:
				cost += action.explosion_damage * 0.15 + action.explosion_radius * 0.1
			elif action is SpawnDamageZoneActionData:
				cost += action.zone_damage * action.zone_duration * 0.1 + action.zone_radius * 0.05
	
	return cost

## 生成法术名称
func _generate_spell_name() -> String:
	return _generate_spell_name_with_scenario(-1)

## 生成带场景前缀的法术名称
func _generate_spell_name_with_scenario(scenario: int = -1) -> String:
	var scenario_prefix: String = ""
	var prefixes: Array
	var middles: Array
	var suffixes: Array
	
	# 根据场景选择前缀
	match scenario:
		0:  # HARASS - 消耗
			scenario_prefix = "消耗法术-"
			prefixes = ["轻", "疾", "连", "散", "扰"]
			middles = ["灵", "影", "风", "雷", "光"]
			suffixes = ["刺", "箭", "弹", "针", "羽"]
		1:  # SINGLE_TARGET - 单体
			scenario_prefix = "单体法术-"
			prefixes = ["穿", "贯", "狙", "精", "锐"]
			middles = ["炎", "冰", "雷", "暗", "光"]
			suffixes = ["矛", "枪", "射", "击", "穿"]
		2:  # CLOSE_COMBAT - 近战
			scenario_prefix = "近战法术-"
			prefixes = ["烈", "猛", "暴", "狂", "怒"]
			middles = ["炎", "雷", "风", "光", "灵"]
			suffixes = ["斩", "击", "爆", "裂", "碎"]
		3:  # AOE - 群伤
			scenario_prefix = "群伤法术-"
			prefixes = ["广", "散", "爆", "环", "域"]
			middles = ["炎", "冰", "雷", "毒", "暗"]
			suffixes = ["波", "雨", "环", "阵", "域"]
		4:  # AMBUSH - 埋伏
			scenario_prefix = "埋伏法术-"
			prefixes = ["伏", "潜", "隐", "陷", "诡"]
			middles = ["暗", "毒", "影", "灵", "玄"]
			suffixes = ["雷", "阱", "伏", "网", "陷"]
		_:  # 默认/未知场景
			# 随机选择一个场景前缀
			var scenario_prefixes = ["消耗法术-", "单体法术-", "近战法术-", "群伤法术-", "埋伏法术-"]
			scenario_prefix = scenario_prefixes[randi() % scenario_prefixes.size()]
			prefixes = ["炎", "冰", "雷", "风", "暗", "光", "毒", "灵", "玄", "天"]
			middles = ["焐", "霜", "电", "刃", "影", "芒", "蚀", "魂", "元", "罡"]
			suffixes = ["弹", "箭", "球", "波", "刺", "爆", "环", "雨", "阵", "诀"]
	
	return scenario_prefix + prefixes[randi() % prefixes.size()] + middles[randi() % middles.size()] + suffixes[randi() % suffixes.size()]
