# scenario_spell_generator.gd
# 场景化法术生成器 - 根据不同场景需求生成专门的法术
class_name ScenarioSpellGenerator
extends RefCounted

var scenario_config: SpellScenarioConfig

## Cost 预算配置（支持1-4层嵌套）
const COST_BUDGET: Dictionary = {
	1: {"main": 80.0, "child": 40.0},   # 1层嵌套
	2: {"main": 60.0, "child": 30.0},   # 2层嵌套
	3: {"main": 45.0, "child": 22.0},   # 3层嵌套
	4: {"main": 35.0, "child": 15.0}    # 4层嵌套
}

const MAX_TOTAL_COST: float = 100.0

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
	
	# 决定嵌套层数（1-4层）
	var target_nesting_depth = _decide_nesting_depth(scenario)
	var cost_budget = COST_BUDGET.get(target_nesting_depth, COST_BUDGET[1])
	
	# 根据场景配置生成载体
	spell.carrier = _generate_scenario_carrier(config, cost_budget.main)
	
	# 根据场景配置生成规则
	var rules_config = config.get("rules", {})
	var max_rules = rules_config.get("max_rules", 3)
	var rule_count = randi_range(1, max_rules)
	
	# 计算已使用的cost
	var used_cost = _calculate_carrier_cost(spell.carrier)
	var remaining_cost = cost_budget.main - used_cost
	
	for i in range(rule_count):
		var rule = _generate_scenario_rule(config, i == 0, remaining_cost, target_nesting_depth, cost_budget.child)
		rule.rule_name = "规则_%d" % (i + 1)
		spell.topology_rules.append(rule)
		remaining_cost -= _calculate_rule_cost(rule)
		if remaining_cost < 5.0:
			break
	
	# 确保至少有一条接触伤害规则
	_ensure_contact_damage(spell, config)
	
	# 计算资源消耗
	spell.resource_cost = _calculate_resource_cost(spell)
	spell.cooldown = _calculate_cooldown(scenario)
	
	return spell

## 决定嵌套层数
func _decide_nesting_depth(scenario: SpellScenarioConfig.SpellScenario) -> int:
	# 不同场景倾向不同的嵌套深度
	var depth_weights: Array
	
	match scenario:
		SpellScenarioConfig.SpellScenario.HARASS:
			# 消耗法术：倾向简单，1-2层
			depth_weights = [0.6, 0.3, 0.08, 0.02]
		SpellScenarioConfig.SpellScenario.SINGLE_TARGET:
			# 单体法术：中等复杂度，1-3层
			depth_weights = [0.4, 0.35, 0.2, 0.05]
		SpellScenarioConfig.SpellScenario.CLOSE_COMBAT:
			# 近战法术：倾向复杂，2-3层
			depth_weights = [0.2, 0.4, 0.3, 0.1]
		SpellScenarioConfig.SpellScenario.AOE:
			# 群伤法术：最复杂，2-4层
			depth_weights = [0.15, 0.3, 0.35, 0.2]
		SpellScenarioConfig.SpellScenario.AMBUSH:
			# 埋伏法术：中等复杂度，1-3层
			depth_weights = [0.3, 0.35, 0.25, 0.1]
		_:
			depth_weights = [0.4, 0.3, 0.2, 0.1]
	
	var roll = randf()
	var cumulative = 0.0
	for i in range(depth_weights.size()):
		cumulative += depth_weights[i]
		if roll < cumulative:
			return i + 1
	return 1

## 计算载体cost
func _calculate_carrier_cost(carrier: CarrierConfigData) -> float:
	if carrier == null:
		return 0.0
	var cost = 0.0
	cost += carrier.mass * 2.0
	cost += carrier.velocity * 0.008
	cost += carrier.homing_strength * 8.0
	cost += carrier.piercing * 4.0
	return cost

## 计算规则cost
func _calculate_rule_cost(rule: TopologyRuleData) -> float:
	var cost = 1.5  # 基础cost
	for action in rule.actions:
		cost += _calculate_action_cost(action)
	return cost

## 计算动作cost
func _calculate_action_cost(action: ActionData, depth: int = 0) -> float:
	var cost = 0.0
	
	if action is DamageActionData:
		var dmg = action as DamageActionData
		cost += dmg.damage_value * dmg.damage_multiplier * 0.3
	
	elif action is FissionActionData:
		var fission = action as FissionActionData
		cost += fission.spawn_count * 2.5
		# 子法术cost（递归但衰减）
		if fission.child_spell_data != null and fission.child_spell_data is SpellCoreData:
			var child_cost = _calculate_resource_cost(fission.child_spell_data)
			var decay = 0.4 / pow(1.5, depth)
			cost += child_cost * decay
	
	elif action is AreaEffectActionData:
		var area = action as AreaEffectActionData
		cost += area.radius * 0.08
		cost += area.damage_value * 0.25
	
	elif action is ApplyStatusActionData:
		var status = action as ApplyStatusActionData
		cost += status.duration * 0.8
		cost += status.effect_value * 0.3
	
	elif action is SpawnExplosionActionData:
		var explosion = action as SpawnExplosionActionData
		cost += explosion.explosion_damage * 0.2
		cost += explosion.explosion_radius * 0.08
	
	elif action is SpawnDamageZoneActionData:
		var zone = action as SpawnDamageZoneActionData
		cost += zone.zone_damage * zone.zone_duration * 0.08
		cost += zone.zone_radius * 0.05
	
	return cost

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
func _generate_scenario_carrier(config: Dictionary, cost_budget: float) -> CarrierConfigData:
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
	
	# 设置其他属性（考虑cost预算）
	var lifetime_range = carrier_config.get("lifetime_range", Vector2(2.0, 6.0))
	carrier.lifetime = randf_range(lifetime_range.x, lifetime_range.y)
	
	var mass_range = carrier_config.get("mass_range", Vector2(0.5, 3.0))
	# 根据cost预算调整质量上限
	var max_mass = minf(mass_range.y, cost_budget * 0.15)
	carrier.mass = randf_range(mass_range.x, max_mass)
	
	# 追踪（地雷不追踪）
	var max_homing = carrier_config.get("max_homing_strength", 1.0)
	if carrier.carrier_type != CarrierConfigData.CarrierType.MINE and randf() < 0.3:
		# 根据cost预算调整追踪强度
		var budget_homing = minf(max_homing, cost_budget * 0.05)
		carrier.homing_strength = randf_range(0.1, budget_homing)
		carrier.homing_range = randf_range(150.0, 400.0)
		carrier.homing_turn_rate = randf_range(3.0, 8.0)
	else:
		carrier.homing_strength = 0.0
	
	# 穿透
	var max_piercing = carrier_config.get("max_piercing", 3)
	carrier.piercing = randi_range(0, mini(max_piercing, int(cost_budget * 0.1)))
	
	# 相态随机
	carrier.phase = randi() % 3
	carrier.size = randf_range(0.6, 1.8)
	carrier.instability_cost = randf_range(0.0, 3.0)
	
	return carrier

## 生成场景专用规则
func _generate_scenario_rule(config: Dictionary, is_first_rule: bool, remaining_cost: float, target_depth: int, child_budget: float) -> TopologyRuleData:
	var rule = TopologyRuleData.new()
	var rules_config = config.get("rules", {})
	
	# 生成触发器
	rule.trigger = _generate_scenario_trigger(rules_config, is_first_rule)
	
	# 生成动作
	var max_actions = rules_config.get("max_actions_per_rule", 3)
	var action_count = randi_range(1, max_actions)
	
	var cost_config = config.get("cost", {})
	var max_damage = cost_config.get("max_damage_per_action", 50.0)
	
	# 根据剩余cost调整最大伤害
	max_damage = minf(max_damage, remaining_cost * 0.8)
	
	var action_cost_used = 0.0
	for i in range(action_count):
		var action_budget = (remaining_cost - action_cost_used) / (action_count - i)
		var action = _generate_scenario_action(rules_config, max_damage, target_depth, child_budget, action_budget)
		rule.actions.append(action)
		action_cost_used += _calculate_action_cost(action)
		if action_cost_used > remaining_cost * 0.9:
			break
	
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
func _generate_scenario_action(rules_config: Dictionary, max_damage: float, target_depth: int, child_budget: float, action_budget: float) -> ActionData:
	var allow_fission = rules_config.get("allow_fission", true) and target_depth > 0
	var allow_aoe = rules_config.get("allow_aoe", true)
	var fission_prob = rules_config.get("fission_probability", 0.3) if allow_fission else 0.0
	var aoe_prob = rules_config.get("aoe_probability", 0.3) if allow_aoe else 0.0
	
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
			# 根据action_budget调整伤害
			var budget_max_damage = minf(max_damage, action_budget / 0.3)
			damage.damage_value = randf_range(8.0, budget_max_damage)
			damage.damage_type = randi() % 4
			damage.damage_multiplier = randf_range(0.8, 1.3)
			action = damage
		
		ActionData.ActionType.FISSION:
			var fission = FissionActionData.new()
			# 根据action_budget调整裂变数量
			var max_spawn = mini(8, int(action_budget / 2.5))
			fission.spawn_count = randi_range(2, maxi(2, max_spawn))
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
			
			# 生成子法术（根据目标深度决定子法术复杂度）
			if target_depth > 1:
				# 多层嵌套：子法术也可能有裂变
				var child_roll = randf()
				if child_roll < 0.4:
					fission.child_spell_data = _generate_nested_child_spell(child_budget, target_depth - 1)
				elif child_roll < 0.6:
					fission.child_spell_data = generate_advanced_child_spell("mine", child_budget * 0.8)
				elif child_roll < 0.8:
					fission.child_spell_data = generate_advanced_child_spell("homing", child_budget * 0.6)
				else:
					fission.child_spell_data = generate_advanced_child_spell("explosive", child_budget * 0.7)
			else:
				# 单层嵌套：简单子法术
				var child_roll = randf()
				if child_roll < 0.5:
					fission.child_spell_data = _generate_simple_child_spell(child_budget * 0.6)
				elif child_roll < 0.7:
					fission.child_spell_data = generate_advanced_child_spell("mine", child_budget * 0.8)
				elif child_roll < 0.85:
					fission.child_spell_data = generate_advanced_child_spell("homing", child_budget * 0.5)
				else:
					fission.child_spell_data = generate_advanced_child_spell("explosive", child_budget * 0.6)
			
			action = fission
		
		ActionData.ActionType.AREA_EFFECT:
			var area = AreaEffectActionData.new()
			# 根据action_budget调整范围和伤害
			var budget_radius = minf(120.0, action_budget / 0.08)
			area.radius = randf_range(40.0, budget_radius)
			var budget_aoe_damage = minf(max_damage * 0.7, (action_budget - area.radius * 0.08) / 0.25)
			area.damage_value = randf_range(5.0, maxf(5.0, budget_aoe_damage))
			area.damage_falloff = randf_range(0.3, 0.7)
			action = area
		
		ActionData.ActionType.APPLY_STATUS:
			var status = ApplyStatusActionData.new()
			status.status_type = randi() % 6
			status.duration = randf_range(1.0, minf(4.0, action_budget / 0.8))
			status.effect_value = randf_range(3.0, 12.0)
			action = status
		
		_:
			var damage = DamageActionData.new()
			damage.damage_value = randf_range(8.0, max_damage)
			action = damage
	
	return action

## 生成可嵌套的子法术（支持多层嵌套）
func _generate_nested_child_spell(cost_budget: float, remaining_depth: int) -> SpellCoreData:
	var spell = SpellCoreData.new()
	spell.generate_id()
	spell.spell_name = "嵌套子弹_L%d" % (4 - remaining_depth)
	
	# 简化载体
	spell.carrier = CarrierConfigData.new()
	spell.carrier.phase = randi() % 3
	spell.carrier.mass = randf_range(0.3, minf(1.2, cost_budget * 0.1))
	spell.carrier.velocity = randf_range(250.0, 500.0)
	spell.carrier.lifetime = randf_range(1.5, 3.5)
	spell.carrier.size = randf_range(0.6, 1.2)
	
	var used_cost = _calculate_carrier_cost(spell.carrier)
	var remaining_cost = cost_budget - used_cost
	
	# 碰撞伤害规则
	var contact_rule = TopologyRuleData.new()
	contact_rule.rule_name = "碰撞伤害"
	contact_rule.trigger = TriggerData.new()
	contact_rule.trigger.trigger_type = TriggerData.TriggerType.ON_CONTACT
	
	var damage = DamageActionData.new()
	damage.damage_value = randf_range(5.0, minf(30.0, remaining_cost * 0.5))
	damage.damage_multiplier = randf_range(0.8, 1.2)
	contact_rule.actions.append(damage)
	spell.topology_rules.append(contact_rule)
	
	remaining_cost -= _calculate_action_cost(damage)
	
	# 如果还有嵌套深度且cost足够，添加裂变规则
	if remaining_depth > 0 and remaining_cost > 15.0 and randf() < 0.5:
		var death_rule = TopologyRuleData.new()
		death_rule.rule_name = "死亡裂变"
		death_rule.trigger = TriggerData.new()
		death_rule.trigger.trigger_type = TriggerData.TriggerType.ON_DEATH
		
		var fission = FissionActionData.new()
		fission.spawn_count = randi_range(2, mini(4, int(remaining_cost / 5)))
		fission.spread_angle = randf_range(60.0, 180.0)
		fission.inherit_velocity = 0.7
		fission.direction_mode = FissionActionData.DirectionMode.INHERIT_PARENT
		
		# 递归生成更深层的子法术
		var child_budget = remaining_cost * 0.4
		if remaining_depth > 1 and child_budget > 10.0:
			fission.child_spell_data = _generate_nested_child_spell(child_budget, remaining_depth - 1)
		else:
			fission.child_spell_data = _generate_simple_child_spell(child_budget)
		
		death_rule.actions.append(fission)
		spell.topology_rules.append(death_rule)
	
	return spell

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
	prox_rule.rule_name = "接近爆炸"
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
		cost += _calculate_carrier_cost(spell.carrier)
	
	for rule in spell.topology_rules:
		cost += _calculate_rule_cost(rule)
	
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
	var scenario_prefix: String
	var prefixes: Array
	var suffixes: Array
	
	match scenario:
		SpellScenarioConfig.SpellScenario.HARASS:
			scenario_prefix = "消耗法术-"
			prefixes = ["轻", "疾", "连", "散", "扰"]
			suffixes = ["刺", "箭", "弹", "针", "羽"]
		SpellScenarioConfig.SpellScenario.SINGLE_TARGET:
			scenario_prefix = "单体法术-"
			prefixes = ["穿", "贯", "狙", "精", "锐"]
			suffixes = ["矛", "枪", "射", "击", "穿"]
		SpellScenarioConfig.SpellScenario.CLOSE_COMBAT:
			scenario_prefix = "近战法术-"
			prefixes = ["烈", "猛", "暴", "狂", "怒"]
			suffixes = ["斩", "击", "爆", "裂", "碎"]
		SpellScenarioConfig.SpellScenario.AOE:
			scenario_prefix = "群伤法术-"
			prefixes = ["广", "散", "爆", "环", "域"]
			suffixes = ["波", "雨", "环", "阵", "域"]
		SpellScenarioConfig.SpellScenario.AMBUSH:
			scenario_prefix = "埋伏法术-"
			prefixes = ["伏", "潜", "隐", "陷", "诡"]
			suffixes = ["雷", "阱", "伏", "网", "陷"]
		_:
			scenario_prefix = "法术-"
			prefixes = ["灵", "玄", "幻", "魔", "咒"]
			suffixes = ["术", "法", "咒", "诀", "式"]
	
	var elements = ["炎", "冰", "雷", "风", "暗", "光", "毒", "灵"]
	
	return scenario_prefix + prefixes[randi() % prefixes.size()] + elements[randi() % elements.size()] + suffixes[randi() % suffixes.size()]
