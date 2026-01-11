# scenario_spell_generator.gd
# 场景化法术生成器 - 根据不同场景需求生成专门的法术
class_name ScenarioSpellGenerator
extends RefCounted

var scenario_config: SpellScenarioConfig

func _init():
	scenario_config = SpellScenarioConfig.create_default()

## 为指定场景生成法术
func generate_spell_for_scenario(scenario: SpellScenarioConfig.SpellScenario) -> SpellCoreData:
	var config = scenario_config.get_scenario_config(scenario)
	if config.is_empty():
		push_error("未知场景: %d" % scenario)
		return null
	
	var spell = SpellCoreData.new()
	spell.generate_id()
	spell.spell_name = _generate_scenario_spell_name(scenario)
	
	# 根据场景配置生成载体
	spell.carrier = _generate_scenario_carrier(config)
	
	# 根据场景配置生成规则
	var rules_config = config.get("rules", {})
	var max_rules = rules_config.get("max_rules", 3)
	var rule_count = randi_range(1, max_rules)
	
	for i in range(rule_count):
		var rule = _generate_scenario_rule(config, i == 0)
		rule.rule_name = "规则_%d" % (i + 1)
		spell.topology_rules.append(rule)
	
	# 确保至少有一条接触伤害规则
	_ensure_contact_damage(spell, config)
	
	# 计算资源消耗
	spell.resource_cost = _calculate_resource_cost(spell)
	spell.cooldown = _calculate_cooldown(scenario)
	
	return spell

## 为指定场景批量生成法术
func generate_spells_for_scenario(scenario: SpellScenarioConfig.SpellScenario, count: int = -1) -> Array[SpellCoreData]:
	var config = scenario_config.get_scenario_config(scenario)
	var target_count = count if count > 0 else config.get("target_count", 5)
	
	var spells: Array[SpellCoreData] = []
	for i in range(target_count):
		var spell = generate_spell_for_scenario(scenario)
		if spell != null:
			spells.append(spell)
	
	return spells

## 为所有场景生成法术
func generate_spells_for_all_scenarios() -> Dictionary:
	var result: Dictionary = {}
	
	for scenario in scenario_config.get_all_scenarios():
		result[scenario] = generate_spells_for_scenario(scenario)
	
	return result

## 生成场景专用载体
func _generate_scenario_carrier(config: Dictionary) -> CarrierConfigData:
	var carrier = CarrierConfigData.new()
	var carrier_config = config.get("carrier", {})
	
	# 选择载体类型
	var allowed_types = carrier_config.get("allowed_types", [CarrierConfigData.CarrierType.PROJECTILE])
	carrier.carrier_type = allowed_types[randi() % allowed_types.size()]
	
	# 根据载体类型设置速度
	var velocity_range = carrier_config.get("velocity_range", Vector2(200.0, 600.0))
	match carrier.carrier_type:
		CarrierConfigData.CarrierType.MINE:
			carrier.velocity = 0.0
		CarrierConfigData.CarrierType.SLOW_ORB:
			carrier.velocity = randf_range(velocity_range.x, minf(velocity_range.y, 150.0))
		_:
			carrier.velocity = randf_range(velocity_range.x, velocity_range.y)
	
	# 设置其他属性
	var lifetime_range = carrier_config.get("lifetime_range", Vector2(2.0, 6.0))
	carrier.lifetime = randf_range(lifetime_range.x, lifetime_range.y)
	
	var mass_range = carrier_config.get("mass_range", Vector2(0.5, 3.0))
	carrier.mass = randf_range(mass_range.x, mass_range.y)
	
	# 追踪（地雷不追踪）
	var max_homing = carrier_config.get("max_homing_strength", 1.0)
	if carrier.carrier_type != CarrierConfigData.CarrierType.MINE and randf() < 0.3:
		carrier.homing_strength = randf_range(0.1, max_homing)
		carrier.homing_range = randf_range(150.0, 400.0)
		carrier.homing_turn_rate = randf_range(3.0, 8.0)
	else:
		carrier.homing_strength = 0.0
	
	# 穿透
	var max_piercing = carrier_config.get("max_piercing", 3)
	carrier.piercing = randi_range(0, max_piercing)
	
	# 相态随机
	carrier.phase = randi() % 3
	carrier.size = randf_range(0.6, 1.8)
	carrier.instability_cost = randf_range(0.0, 3.0)
	
	return carrier

## 生成场景专用规则
func _generate_scenario_rule(config: Dictionary, is_first_rule: bool) -> TopologyRuleData:
	var rule = TopologyRuleData.new()
	var rules_config = config.get("rules", {})
	
	# 生成触发器
	rule.trigger = _generate_scenario_trigger(rules_config, is_first_rule)
	
	# 生成动作
	var max_actions = rules_config.get("max_actions_per_rule", 3)
	var action_count = randi_range(1, max_actions)
	
	var cost_config = config.get("cost", {})
	var max_damage = cost_config.get("max_damage_per_action", 50.0)
	
	for i in range(action_count):
		var action = _generate_scenario_action(rules_config, max_damage)
		rule.actions.append(action)
	
	return rule

## 生成场景专用触发器
func _generate_scenario_trigger(rules_config: Dictionary, is_first_rule: bool) -> TriggerData:
	var preferred_triggers = rules_config.get("preferred_triggers", [TriggerData.TriggerType.ON_CONTACT])
	
	# 第一条规则优先使用接触触发
	var trigger_type: int
	if is_first_rule and TriggerData.TriggerType.ON_CONTACT in preferred_triggers:
		trigger_type = TriggerData.TriggerType.ON_CONTACT
	else:
		trigger_type = preferred_triggers[randi() % preferred_triggers.size()]
	
	var trigger: TriggerData
	
	match trigger_type:
		TriggerData.TriggerType.ON_CONTACT:
			trigger = TriggerData.new()
			trigger.trigger_type = TriggerData.TriggerType.ON_CONTACT
		
		TriggerData.TriggerType.ON_TIMER:
			var timer_trigger = OnTimerTrigger.new()
			timer_trigger.delay = randf_range(0.3, 2.5)
			timer_trigger.repeat_interval = randf_range(0.5, 2.0) if randf() < 0.3 else 0.0
			trigger = timer_trigger
		
		TriggerData.TriggerType.ON_PROXIMITY:
			var prox_trigger = OnProximityTrigger.new()
			prox_trigger.detection_radius = randf_range(50.0, 150.0)
			trigger = prox_trigger
		
		TriggerData.TriggerType.ON_DEATH:
			trigger = TriggerData.new()
			trigger.trigger_type = TriggerData.TriggerType.ON_DEATH
		
		_:
			trigger = TriggerData.new()
			trigger.trigger_type = TriggerData.TriggerType.ON_CONTACT
	
	trigger.trigger_once = randf() > 0.3
	return trigger

## 生成场景专用动作
func _generate_scenario_action(rules_config: Dictionary, max_damage: float) -> ActionData:
	var allow_fission = rules_config.get("allow_fission", true)
	var allow_aoe = rules_config.get("allow_aoe", true)
	var fission_prob = rules_config.get("fission_probability", 0.3)
	var aoe_prob = rules_config.get("aoe_probability", 0.3)
	
	# 决定动作类型
	var roll = randf()
	var action_type: int
	
	if allow_fission and roll < fission_prob:
		action_type = ActionData.ActionType.FISSION
	elif allow_aoe and roll < fission_prob + aoe_prob:
		action_type = ActionData.ActionType.AREA_EFFECT
	elif roll < 0.85:
		action_type = ActionData.ActionType.DAMAGE
	else:
		action_type = ActionData.ActionType.APPLY_STATUS
	
	var action: ActionData
	
	match action_type:
		ActionData.ActionType.DAMAGE:
			var damage = DamageActionData.new()
			damage.damage_value = randf_range(8.0, max_damage)
			damage.damage_type = randi() % 4
			damage.damage_multiplier = randf_range(0.8, 1.3)
			action = damage
		
		ActionData.ActionType.FISSION:
			var fission = FissionActionData.new()
			fission.spawn_count = randi_range(2, 6)
			fission.spread_angle = randf_range(30.0, 180.0)
			fission.inherit_velocity = randf_range(0.4, 0.9)
			# 随机选择方向模式
			var mode_roll = randf()
			if mode_roll < 0.5:
				fission.direction_mode = FissionActionData.DirectionMode.INHERIT_PARENT
			elif mode_roll < 0.7:
				fission.direction_mode = FissionActionData.DirectionMode.TOWARD_NEAREST
			elif mode_roll < 0.9:
				fission.direction_mode = FissionActionData.DirectionMode.FIXED_WORLD
			else:
				fission.direction_mode = FissionActionData.DirectionMode.RANDOM
			# 随机选择子法术类型
			var child_roll = randf()
			if child_roll < 0.5:
				fission.child_spell_data = _generate_simple_child_spell(max_damage * 0.6)
			elif child_roll < 0.7:
				fission.child_spell_data = generate_advanced_child_spell("mine", max_damage * 0.8)
			elif child_roll < 0.85:
				fission.child_spell_data = generate_advanced_child_spell("homing", max_damage * 0.5)
			else:
				fission.child_spell_data = generate_advanced_child_spell("explosive", max_damage * 0.6)
			action = fission
		
		ActionData.ActionType.AREA_EFFECT:
			var area = AreaEffectActionData.new()
			area.radius = randf_range(40.0, 120.0)
			area.damage_value = randf_range(5.0, max_damage * 0.7)
			area.damage_falloff = randf_range(0.3, 0.7)
			action = area
		
		ActionData.ActionType.APPLY_STATUS:
			var status = ApplyStatusActionData.new()
			status.status_type = randi() % 6
			status.duration = randf_range(1.0, 4.0)
			status.effect_value = randf_range(3.0, 12.0)
			action = status
		
		_:
			var damage = DamageActionData.new()
			damage.damage_value = randf_range(8.0, max_damage)
			action = damage
	
	return action

## 生成简化子法术
func _generate_simple_child_spell(max_damage: float) -> SpellCoreData:
	var spell = SpellCoreData.new()
	spell.generate_id()
	spell.spell_name = "子弹"
	
	spell.carrier = CarrierConfigData.new()
	spell.carrier.phase = randi() % 3
	spell.carrier.mass = randf_range(0.3, 1.2)
	spell.carrier.velocity = randf_range(250.0, 500.0)
	spell.carrier.lifetime = randf_range(1.5, 3.5)
	spell.carrier.size = randf_range(0.6, 1.2)
	
	var rule = TopologyRuleData.new()
	rule.rule_name = "碰撞伤害"
	rule.trigger = TriggerData.new()
	rule.trigger.trigger_type = TriggerData.TriggerType.ON_CONTACT
	
	var damage = DamageActionData.new()
	damage.damage_value = randf_range(5.0, max_damage)
	damage.damage_multiplier = randf_range(0.8, 1.2)
	rule.actions.append(damage)
	
	spell.topology_rules.append(rule)
	
	return spell

## 生成带完整规则的子法术（如远程布置地雷）
func generate_advanced_child_spell(child_type: String, max_damage: float) -> SpellCoreData:
	match child_type:
		"mine":
			return _generate_mine_child_spell(max_damage)
		"homing":
			return _generate_homing_child_spell(max_damage)
		"explosive":
			return _generate_explosive_child_spell(max_damage)
		"chain":
			return _generate_chain_child_spell(max_damage)
		_:
			return _generate_simple_child_spell(max_damage)

## 生成地雷型子法术（远程布置地雷）
func _generate_mine_child_spell(max_damage: float) -> SpellCoreData:
	var spell = SpellCoreData.new()
	spell.generate_id()
	spell.spell_name = "布置地雷"
	
	# 地雷载体
	spell.carrier = CarrierConfigData.new()
	spell.carrier.carrier_type = CarrierConfigData.CarrierType.MINE
	spell.carrier.phase = randi() % 3
	spell.carrier.mass = randf_range(1.0, 2.5)
	spell.carrier.velocity = 0.0  # 地雷不移动
	spell.carrier.lifetime = randf_range(8.0, 15.0)  # 实际会翻倍
	spell.carrier.size = randf_range(1.0, 1.8)
	spell.carrier.homing_strength = 0.0
	
	# 接近触发规则
	var prox_rule = TopologyRuleData.new()
	prox_rule.rule_name = "接近引爆"
	var prox_trigger = OnProximityTrigger.new()
	prox_trigger.detection_radius = randf_range(60.0, 120.0)
	prox_trigger.trigger_once = true
	prox_rule.trigger = prox_trigger
	
	# 爆炸效果
	var area = AreaEffectActionData.new()
	area.radius = randf_range(80.0, 150.0)
	area.damage_value = randf_range(max_damage * 0.8, max_damage * 1.5)
	area.damage_falloff = randf_range(0.3, 0.6)
	prox_rule.actions.append(area)
	
	spell.topology_rules.append(prox_rule)
	
	# 可选：死亡时也爆炸
	if randf() < 0.5:
		var death_rule = TopologyRuleData.new()
		death_rule.rule_name = "超时爆炸"
		death_rule.trigger = TriggerData.new()
		death_rule.trigger.trigger_type = TriggerData.TriggerType.ON_DEATH
		
		var death_area = AreaEffectActionData.new()
		death_area.radius = area.radius * 0.7
		death_area.damage_value = area.damage_value * 0.5
		death_rule.actions.append(death_area)
		
		spell.topology_rules.append(death_rule)
	
	return spell

## 生成追踪型子法术
func _generate_homing_child_spell(max_damage: float) -> SpellCoreData:
	var spell = SpellCoreData.new()
	spell.generate_id()
	spell.spell_name = "追踪弹"
	
	spell.carrier = CarrierConfigData.new()
	spell.carrier.phase = randi() % 3
	spell.carrier.mass = randf_range(0.3, 0.8)
	spell.carrier.velocity = randf_range(300.0, 500.0)
	spell.carrier.lifetime = randf_range(3.0, 5.0)
	spell.carrier.size = randf_range(0.5, 1.0)
	spell.carrier.homing_strength = randf_range(0.5, 1.0)
	spell.carrier.homing_range = randf_range(200.0, 400.0)
	spell.carrier.homing_turn_rate = randf_range(5.0, 10.0)
	spell.carrier.homing_delay = randf_range(0.1, 0.3)
	
	var rule = TopologyRuleData.new()
	rule.rule_name = "碰撞伤害"
	rule.trigger = TriggerData.new()
	rule.trigger.trigger_type = TriggerData.TriggerType.ON_CONTACT
	
	var damage = DamageActionData.new()
	damage.damage_value = randf_range(max_damage * 0.6, max_damage)
	damage.damage_multiplier = 1.0
	rule.actions.append(damage)
	
	spell.topology_rules.append(rule)
	
	return spell

## 生成爆炸型子法术
func _generate_explosive_child_spell(max_damage: float) -> SpellCoreData:
	var spell = SpellCoreData.new()
	spell.generate_id()
	spell.spell_name = "爆裂弹"
	
	spell.carrier = CarrierConfigData.new()
	spell.carrier.phase = CarrierConfigData.Phase.PLASMA
	spell.carrier.mass = randf_range(0.5, 1.5)
	spell.carrier.velocity = randf_range(200.0, 400.0)
	spell.carrier.lifetime = randf_range(2.0, 4.0)
	spell.carrier.size = randf_range(0.8, 1.5)
	
	# 碰撞规则
	var contact_rule = TopologyRuleData.new()
	contact_rule.rule_name = "碰撞爆炸"
	contact_rule.trigger = TriggerData.new()
	contact_rule.trigger.trigger_type = TriggerData.TriggerType.ON_CONTACT
	
	var damage = DamageActionData.new()
	damage.damage_value = randf_range(max_damage * 0.3, max_damage * 0.5)
	contact_rule.actions.append(damage)
	
	var area = AreaEffectActionData.new()
	area.radius = randf_range(50.0, 100.0)
	area.damage_value = randf_range(max_damage * 0.4, max_damage * 0.7)
	contact_rule.actions.append(area)
	
	spell.topology_rules.append(contact_rule)
	
	# 死亡规则
	var death_rule = TopologyRuleData.new()
	death_rule.rule_name = "死亡爆炸"
	death_rule.trigger = TriggerData.new()
	death_rule.trigger.trigger_type = TriggerData.TriggerType.ON_DEATH
	
	var death_area = AreaEffectActionData.new()
	death_area.radius = randf_range(40.0, 80.0)
	death_area.damage_value = randf_range(max_damage * 0.3, max_damage * 0.5)
	death_rule.actions.append(death_area)
	
	spell.topology_rules.append(death_rule)
	
	return spell

## 生成链式子法术（可以再次裂变）
func _generate_chain_child_spell(max_damage: float) -> SpellCoreData:
	var spell = SpellCoreData.new()
	spell.generate_id()
	spell.spell_name = "链式弹"
	
	spell.carrier = CarrierConfigData.new()
	spell.carrier.phase = randi() % 3
	spell.carrier.mass = randf_range(0.3, 0.8)
	spell.carrier.velocity = randf_range(350.0, 550.0)
	spell.carrier.lifetime = randf_range(2.0, 3.5)
	spell.carrier.size = randf_range(0.6, 1.0)
	
	# 碰撞规则
	var contact_rule = TopologyRuleData.new()
	contact_rule.rule_name = "碰撞伤害"
	contact_rule.trigger = TriggerData.new()
	contact_rule.trigger.trigger_type = TriggerData.TriggerType.ON_CONTACT
	
	var damage = DamageActionData.new()
	damage.damage_value = randf_range(max_damage * 0.4, max_damage * 0.6)
	contact_rule.actions.append(damage)
	
	spell.topology_rules.append(contact_rule)
	
	# 死亡时裂变（链式效果）
	if randf() < 0.6:
		var death_rule = TopologyRuleData.new()
		death_rule.rule_name = "死亡裂变"
		death_rule.trigger = TriggerData.new()
		death_rule.trigger.trigger_type = TriggerData.TriggerType.ON_DEATH
		
		var fission = FissionActionData.new()
		fission.spawn_count = randi_range(2, 3)
		fission.spread_angle = randf_range(60.0, 120.0)
		fission.inherit_velocity = 0.8
		fission.direction_mode = FissionActionData.DirectionMode.INHERIT_PARENT
		# 终止链式：子弹不再裂变
		fission.child_spell_data = _generate_simple_child_spell(max_damage * 0.4)
		death_rule.actions.append(fission)
		
		spell.topology_rules.append(death_rule)
	
	return spell

## 确保有接触伤害规则
func _ensure_contact_damage(spell: SpellCoreData, config: Dictionary) -> void:
	var has_contact_damage = false
	
	for rule in spell.topology_rules:
		if rule.trigger.trigger_type == TriggerData.TriggerType.ON_CONTACT:
			for action in rule.actions:
				if action is DamageActionData:
					has_contact_damage = true
					break
		if has_contact_damage:
			break
	
	if not has_contact_damage:
		# 添加一条接触伤害规则
		var rule = TopologyRuleData.new()
		rule.rule_name = "基础伤害"
		rule.trigger = TriggerData.new()
		rule.trigger.trigger_type = TriggerData.TriggerType.ON_CONTACT
		
		var cost_config = config.get("cost", {})
		var max_damage = cost_config.get("max_damage_per_action", 30.0)
		
		var damage = DamageActionData.new()
		damage.damage_value = randf_range(8.0, max_damage * 0.6)
		damage.damage_multiplier = 1.0
		rule.actions.append(damage)
		
		spell.topology_rules.insert(0, rule)

## 计算资源消耗
func _calculate_resource_cost(spell: SpellCoreData) -> float:
	var cost = 5.0
	
	if spell.carrier != null:
		cost += spell.carrier.mass * 2.0
		cost += spell.carrier.velocity * 0.01
		cost += spell.carrier.piercing * 3.0
		cost += spell.carrier.homing_strength * 10.0
	
	for rule in spell.topology_rules:
		cost += 2.0
		for action in rule.actions:
			if action is DamageActionData:
				cost += action.damage_value * 0.2
			elif action is FissionActionData:
				cost += action.spawn_count * 3.0
			elif action is AreaEffectActionData:
				cost += action.radius * 0.1 + action.damage_value * 0.15
	
	return cost

## 计算冷却时间
func _calculate_cooldown(scenario: SpellScenarioConfig.SpellScenario) -> float:
	match scenario:
		SpellScenarioConfig.SpellScenario.HARASS:
			return randf_range(0.3, 0.8)  # 快速释放
		SpellScenarioConfig.SpellScenario.SINGLE_TARGET:
			return randf_range(1.0, 2.0)  # 中等冷却
		SpellScenarioConfig.SpellScenario.CLOSE_COMBAT:
			return randf_range(0.4, 1.0)  # 较快
		SpellScenarioConfig.SpellScenario.AOE:
			return randf_range(1.5, 3.0)  # 较长冷却
		SpellScenarioConfig.SpellScenario.AMBUSH:
			return randf_range(2.0, 4.0)  # 长冷却
		_:
			return 1.0

## 生成场景专用法术名称
func _generate_scenario_spell_name(scenario: SpellScenarioConfig.SpellScenario) -> String:
	var prefixes: Array
	var suffixes: Array
	
	match scenario:
		SpellScenarioConfig.SpellScenario.HARASS:
			prefixes = ["轻", "疾", "连", "散", "扰"]
			suffixes = ["刺", "箭", "弹", "针", "羽"]
		SpellScenarioConfig.SpellScenario.SINGLE_TARGET:
			prefixes = ["穿", "贯", "狙", "精", "锐"]
			suffixes = ["矛", "枪", "射", "击", "穿"]
		SpellScenarioConfig.SpellScenario.CLOSE_COMBAT:
			prefixes = ["烈", "猛", "暴", "狂", "怒"]
			suffixes = ["斩", "击", "爆", "裂", "碎"]
		SpellScenarioConfig.SpellScenario.AOE:
			prefixes = ["广", "散", "爆", "环", "域"]
			suffixes = ["波", "雨", "环", "阵", "域"]
		SpellScenarioConfig.SpellScenario.AMBUSH:
			prefixes = ["伏", "潜", "隐", "陷", "诡"]
			suffixes = ["雷", "阱", "伏", "网", "陷"]
		_:
			prefixes = ["灵", "玄", "幻", "魔", "咒"]
			suffixes = ["术", "法", "咒", "诀", "式"]
	
	var elements = ["炎", "冰", "雷", "风", "暗", "光", "毒", "灵"]
	
	return prefixes[randi() % prefixes.size()] + elements[randi() % elements.size()] + suffixes[randi() % suffixes.size()]
