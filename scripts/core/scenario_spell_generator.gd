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
		var rule = _generate_scenario_rule(config, scenario, i == 0, remaining_cost, target_nesting_depth, cost_budget.child)
		rule.rule_name = "规则_%d" % (i + 1)
		spell.topology_rules.append(rule)
		remaining_cost -= _calculate_rule_cost(rule)
		if remaining_cost < 5.0:
			break
	
	# 确保至少有一条接触伤害规则（非防御场景）
	if scenario != SpellScenarioConfig.SpellScenario.DEFENSE:
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
		SpellScenarioConfig.SpellScenario.DEFENSE:
			# 防御法术：简单，1-2层
			depth_weights = [0.5, 0.35, 0.12, 0.03]
		SpellScenarioConfig.SpellScenario.CONTROL:
			# 控制法术：中等，1-3层
			depth_weights = [0.35, 0.35, 0.22, 0.08]
		SpellScenarioConfig.SpellScenario.SUMMON:
			# 召唤法术：简单载体，1-2层
			depth_weights = [0.55, 0.3, 0.12, 0.03]
		SpellScenarioConfig.SpellScenario.CHAIN:
			# 链式法术：中等，1-3层
			depth_weights = [0.4, 0.35, 0.2, 0.05]
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
	
	elif action is ShieldActionData:
		var shield = action as ShieldActionData
		cost += shield.shield_amount * 0.15
		cost += shield.shield_duration * 0.5
		cost += shield.shield_radius * 0.03
	
	elif action is ReflectActionData:
		var reflect = action as ReflectActionData
		cost += reflect.reflect_duration * 1.0
		cost += reflect.max_reflects * 2.0
		cost += reflect.reflect_damage_ratio * 5.0
	
	elif action is DisplacementActionData:
		var disp = action as DisplacementActionData
		cost += disp.displacement_force * 0.01
		cost += disp.stun_after_displacement * 2.0
		cost += disp.damage_on_collision * 0.2
	
	elif action is ChainActionData:
		var chain = action as ChainActionData
		cost += chain.chain_count * 3.0
		cost += chain.chain_damage * 0.25
		cost += chain.chain_range * 0.02
	
	elif action is SummonActionData:
		var summon = action as SummonActionData
		cost += summon.summon_count * 5.0
		cost += summon.summon_duration * 0.3
		cost += summon.summon_damage * 0.2
		cost += summon.summon_health * 0.1
	
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
func _generate_scenario_rule(config: Dictionary, scenario: SpellScenarioConfig.SpellScenario, is_first_rule: bool, remaining_cost: float, target_depth: int, child_budget: float) -> TopologyRuleData:
	var rule = TopologyRuleData.new()
	var rules_config = config.get("rules", {})
	
	# 生成触发器
	rule.trigger = _generate_scenario_trigger(rules_config, is_first_rule, scenario)
	
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
		var action = _generate_scenario_action(rules_config, scenario, max_damage, target_depth, child_budget, action_budget)
		rule.actions.append(action)
		action_cost_used += _calculate_action_cost(action)
		if action_cost_used > remaining_cost * 0.9:
			break
	
	return rule

## 生成场景专用触发器
func _generate_scenario_trigger(rules_config: Dictionary, is_first_rule: bool, scenario: SpellScenarioConfig.SpellScenario) -> TriggerData:
	var preferred_triggers = rules_config.get("preferred_triggers", [TriggerData.TriggerType.ON_CONTACT])
	
	# 第一条规则优先使用接触触发（非防御场景）
	var trigger_type: int
	if is_first_rule and TriggerData.TriggerType.ON_CONTACT in preferred_triggers and scenario != SpellScenarioConfig.SpellScenario.DEFENSE:
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
		
		TriggerData.TriggerType.ON_ALLY_CONTACT:
			trigger = TriggerData.new()
			trigger.trigger_type = TriggerData.TriggerType.ON_ALLY_CONTACT
		
		TriggerData.TriggerType.ON_STATUS_APPLIED:
			var status_trigger = OnStatusAppliedTrigger.new()
			var preferred_status = rules_config.get("preferred_status_types", [1, 3, 4])  # FROZEN, SLOWED, STUNNED
			status_trigger.required_status_type = preferred_status[randi() % preferred_status.size()]
			trigger = status_trigger
		
		TriggerData.TriggerType.ON_CHAIN_END:
			trigger = TriggerData.new()
			trigger.trigger_type = TriggerData.TriggerType.ON_CHAIN_END
		
		_:
			trigger = TriggerData.new()
			trigger.trigger_type = TriggerData.TriggerType.ON_CONTACT
	
	trigger.trigger_once = randf() > 0.3
	return trigger

## 生成场景专用动作
func _generate_scenario_action(rules_config: Dictionary, scenario: SpellScenarioConfig.SpellScenario, max_damage: float, target_depth: int, child_budget: float, action_budget: float) -> ActionData:
	# 根据场景获取允许的动作类型和概率
	var allow_fission = rules_config.get("allow_fission", true) and target_depth > 0
	var allow_aoe = rules_config.get("allow_aoe", true)
	var allow_shield = rules_config.get("allow_shield", false)
	var allow_reflect = rules_config.get("allow_reflect", false)
	var allow_displacement = rules_config.get("allow_displacement", false)
	var allow_chain = rules_config.get("allow_chain", false)
	var allow_summon = rules_config.get("allow_summon", false)
	var allow_status = rules_config.get("allow_status", true)
	
	var fission_prob = rules_config.get("fission_probability", 0.3) if allow_fission else 0.0
	var aoe_prob = rules_config.get("aoe_probability", 0.3) if allow_aoe else 0.0
	var shield_prob = rules_config.get("shield_probability", 0.0) if allow_shield else 0.0
	var reflect_prob = rules_config.get("reflect_probability", 0.0) if allow_reflect else 0.0
	var displacement_prob = rules_config.get("displacement_probability", 0.0) if allow_displacement else 0.0
	var chain_prob = rules_config.get("chain_probability", 0.0) if allow_chain else 0.0
	var summon_prob = rules_config.get("summon_probability", 0.0) if allow_summon else 0.0
	var status_prob = rules_config.get("status_probability", 0.15) if allow_status else 0.0
	
	# 决定动作类型
	var roll = randf()
	var cumulative = 0.0
	var action_type: int = ActionData.ActionType.DAMAGE
	
	# 按概率选择动作类型
	var action_probs = [
		[ActionData.ActionType.SHIELD, shield_prob],
		[ActionData.ActionType.REFLECT, reflect_prob],
		[ActionData.ActionType.CHAIN, chain_prob],
		[ActionData.ActionType.SUMMON, summon_prob],
		[ActionData.ActionType.DISPLACEMENT, displacement_prob],
		[ActionData.ActionType.FISSION, fission_prob],
		[ActionData.ActionType.SPAWN_ENTITY, aoe_prob],
		[ActionData.ActionType.APPLY_STATUS, status_prob],
	]
	
	for prob_pair in action_probs:
		cumulative += prob_pair[1]
		if roll < cumulative:
			action_type = prob_pair[0]
			break
	
	# 如果没有选中特殊动作，默认伤害
	if roll >= cumulative:
		action_type = ActionData.ActionType.DAMAGE
	
	var action: ActionData
	
	match action_type:
		ActionData.ActionType.DAMAGE:
			action = _generate_damage_action(max_damage, action_budget)
		
		ActionData.ActionType.FISSION:
			action = _generate_fission_action(rules_config, max_damage, target_depth, child_budget, action_budget)
		
		ActionData.ActionType.SPAWN_ENTITY:
			action = _generate_aoe_action(max_damage, action_budget)
		
		ActionData.ActionType.APPLY_STATUS:
			action = _generate_status_action(rules_config, action_budget)
		
		ActionData.ActionType.SHIELD:
			action = _generate_shield_action(action_budget)
		
		ActionData.ActionType.REFLECT:
			action = _generate_reflect_action(action_budget)
		
		ActionData.ActionType.DISPLACEMENT:
			action = _generate_displacement_action(rules_config, action_budget)
		
		ActionData.ActionType.CHAIN:
			action = _generate_chain_action(rules_config, max_damage, action_budget)
		
		ActionData.ActionType.SUMMON:
			action = _generate_summon_action(rules_config, action_budget)
		
		_:
			action = _generate_damage_action(max_damage, action_budget)
	
	return action

## 生成伤害动作
func _generate_damage_action(max_damage: float, action_budget: float) -> DamageActionData:
	var damage = DamageActionData.new()
	var budget_max_damage = minf(max_damage, action_budget / 0.3)
	damage.damage_value = randf_range(8.0, budget_max_damage)
	damage.damage_type = randi() % 4
	damage.damage_multiplier = randf_range(0.8, 1.3)
	return damage

## 生成裂变动作
func _generate_fission_action(rules_config: Dictionary, max_damage: float, target_depth: int, child_budget: float, action_budget: float) -> FissionActionData:
	var fission = FissionActionData.new()
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
	
	# 生成子法术
	if target_depth > 1:
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
		var child_roll = randf()
		if child_roll < 0.5:
			fission.child_spell_data = _generate_simple_child_spell(child_budget * 0.6)
		elif child_roll < 0.7:
			fission.child_spell_data = generate_advanced_child_spell("mine", child_budget * 0.8)
		elif child_roll < 0.85:
			fission.child_spell_data = generate_advanced_child_spell("homing", child_budget * 0.5)
		else:
			fission.child_spell_data = generate_advanced_child_spell("explosive", child_budget * 0.6)
	
	return fission

## 生成AOE动作
func _generate_aoe_action(max_damage: float, action_budget: float) -> SpawnExplosionActionData:
	var explosion = SpawnExplosionActionData.new()
	var budget_radius = minf(120.0, action_budget / 0.08)
	explosion.explosion_radius = randf_range(40.0, budget_radius)
	var budget_damage = minf(max_damage * 0.7, (action_budget - explosion.explosion_radius * 0.08) / 0.2)
	explosion.explosion_damage = randf_range(10.0, maxf(10.0, budget_damage))
	explosion.damage_falloff = randf_range(0.3, 0.7)
	return explosion

## 生成状态动作
func _generate_status_action(rules_config: Dictionary, action_budget: float) -> ApplyStatusActionData:
	var status = ApplyStatusActionData.new()
	var preferred_status = rules_config.get("preferred_status_types", [])
	if preferred_status.size() > 0:
		status.status_type = preferred_status[randi() % preferred_status.size()]
	else:
		status.status_type = randi() % 6
	status.duration = randf_range(1.0, minf(4.0, action_budget / 0.8))
	status.effect_value = randf_range(3.0, 12.0)
	return status

## 生成护盾动作
func _generate_shield_action(action_budget: float) -> ShieldActionData:
	var shield = ShieldActionData.new()
	shield.shield_type = randi() % 3
	shield.shield_amount = randf_range(30.0, minf(80.0, action_budget / 0.15))
	shield.shield_duration = randf_range(3.0, minf(8.0, action_budget / 0.5))
	shield.shield_radius = randf_range(60.0, 120.0) if shield.shield_type == ShieldActionData.ShieldType.AREA else 0.0
	shield.on_break_explode = randf() < 0.3
	if shield.on_break_explode:
		shield.break_explosion_damage = randf_range(20.0, 50.0)
	return shield

## 生成反弹动作
func _generate_reflect_action(action_budget: float) -> ReflectActionData:
	var reflect = ReflectActionData.new()
	reflect.reflect_type = randi() % 3
	reflect.reflect_damage_ratio = randf_range(0.3, minf(0.8, action_budget / 5.0))
	reflect.reflect_duration = randf_range(1.5, minf(4.0, action_budget / 1.0))
	reflect.max_reflects = randi_range(2, mini(5, int(action_budget / 2.0)))
	reflect.reflect_radius = randf_range(50.0, 100.0)
	return reflect

## 生成位移动作
func _generate_displacement_action(rules_config: Dictionary, action_budget: float) -> DisplacementActionData:
	var disp = DisplacementActionData.new()
	disp.displacement_type = randi() % 4  # KNOCKBACK, PULL, TELEPORT, LAUNCH
	disp.displacement_force = randf_range(200.0, minf(500.0, action_budget / 0.01))
	disp.displacement_duration = randf_range(0.2, 0.5)
	disp.stun_after_displacement = randf_range(0.0, minf(1.0, action_budget / 2.0))
	disp.damage_on_collision = randf_range(0.0, 20.0) if randf() < 0.3 else 0.0
	return disp

## 生成链式动作
func _generate_chain_action(rules_config: Dictionary, max_damage: float, action_budget: float) -> ChainActionData:
	var chain = ChainActionData.new()
	var preferred_chain = rules_config.get("preferred_chain_types", [0, 1, 2])
	chain.chain_type = preferred_chain[randi() % preferred_chain.size()]
	chain.chain_count = randi_range(2, mini(5, int(action_budget / 3.0)))
	chain.chain_damage = randf_range(15.0, minf(max_damage * 0.8, action_budget / 0.25))
	chain.chain_damage_decay = randf_range(0.7, 0.9)
	chain.chain_range = randf_range(150.0, 250.0)
	chain.chain_delay = randf_range(0.05, 0.15)
	chain.chain_can_return = randf() < 0.2
	
	# 链式附带状态
	if randf() < 0.4:
		match chain.chain_type:
			ChainActionData.ChainType.LIGHTNING:
				chain.apply_status_type = ApplyStatusActionData.StatusType.STUNNED
			ChainActionData.ChainType.FIRE:
				chain.apply_status_type = ApplyStatusActionData.StatusType.BURNING
			ChainActionData.ChainType.ICE:
				chain.apply_status_type = ApplyStatusActionData.StatusType.FROZEN
			ChainActionData.ChainType.VOID:
				chain.apply_status_type = ApplyStatusActionData.StatusType.MARKED
		chain.apply_status_duration = randf_range(1.0, 2.5)
	
	return chain

## 生成召唤动作
func _generate_summon_action(rules_config: Dictionary, action_budget: float) -> SummonActionData:
	var summon = SummonActionData.new()
	var preferred_summon = rules_config.get("preferred_summon_types", [0, 1, 2, 5])
	summon.summon_type = preferred_summon[randi() % preferred_summon.size()]
	summon.summon_count = randi_range(1, mini(3, int(action_budget / 5.0)))
	summon.summon_duration = randf_range(6.0, minf(15.0, action_budget / 0.3))
	summon.summon_damage = randf_range(10.0, minf(25.0, action_budget / 0.2))
	summon.summon_health = randf_range(30.0, minf(80.0, action_budget / 0.1))
	summon.summon_attack_interval = randf_range(0.8, 1.5)
	summon.summon_attack_range = randf_range(150.0, 250.0)
	
	# 根据召唤物类型设置特定属性
	match summon.summon_type:
		SummonActionData.SummonType.MINION:
			summon.summon_move_speed = randf_range(80.0, 150.0)
			summon.behavior_mode = SummonActionData.BehaviorMode.AGGRESSIVE
		SummonActionData.SummonType.ORBITER:
			summon.orbit_radius = randf_range(60.0, 100.0)
			summon.orbit_speed = randf_range(1.5, 3.0)
			summon.behavior_mode = SummonActionData.BehaviorMode.FOLLOW
		SummonActionData.SummonType.DECOY:
			summon.aggro_radius = randf_range(120.0, 200.0)
			summon.behavior_mode = SummonActionData.BehaviorMode.PASSIVE
		SummonActionData.SummonType.TOTEM:
			summon.totem_effect_radius = randf_range(100.0, 150.0)
			summon.totem_effect_interval = randf_range(0.8, 1.5)
			summon.behavior_mode = SummonActionData.BehaviorMode.DEFENSIVE
		_:
			summon.behavior_mode = SummonActionData.BehaviorMode.DEFENSIVE
	
	return summon

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
	
	# 爆炸效果（使用SpawnExplosionActionData替代AreaEffectActionData）
	var explosion = SpawnExplosionActionData.new()
	explosion.explosion_radius = randf_range(80.0, 150.0)
	explosion.explosion_damage = randf_range(max_damage * 0.8, max_damage * 1.5)
	explosion.damage_falloff = randf_range(0.3, 0.6)
	prox_rule.actions.append(explosion)
	
	spell.topology_rules.append(prox_rule)
	
	# 可选：死亡时也爆炸
	if randf() < 0.5:
		var death_rule = TopologyRuleData.new()
		death_rule.rule_name = "超时爆炸"
		death_rule.trigger = TriggerData.new()
		death_rule.trigger.trigger_type = TriggerData.TriggerType.ON_DEATH
		
		var death_explosion = SpawnExplosionActionData.new()
		death_explosion.explosion_radius = explosion.explosion_radius * 0.7
		death_explosion.explosion_damage = explosion.explosion_damage * 0.5
		death_rule.actions.append(death_explosion)
		
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
	
	var explosion = SpawnExplosionActionData.new()
	explosion.explosion_radius = randf_range(50.0, 100.0)
	explosion.explosion_damage = randf_range(max_damage * 0.4, max_damage * 0.7)
	contact_rule.actions.append(explosion)
	
	spell.topology_rules.append(contact_rule)
	
	# 死亡规则
	var death_rule = TopologyRuleData.new()
	death_rule.rule_name = "死亡爆炸"
	death_rule.trigger = TriggerData.new()
	death_rule.trigger.trigger_type = TriggerData.TriggerType.ON_DEATH
	
	var death_explosion = SpawnExplosionActionData.new()
	death_explosion.explosion_radius = randf_range(40.0, 80.0)
	death_explosion.explosion_damage = randf_range(max_damage * 0.3, max_damage * 0.5)
	death_rule.actions.append(death_explosion)
	
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
		SpellScenarioConfig.SpellScenario.DEFENSE:
			return randf_range(1.5, 3.0)  # 中等冷却
		SpellScenarioConfig.SpellScenario.CONTROL:
			return randf_range(1.0, 2.5)  # 中等冷却
		SpellScenarioConfig.SpellScenario.SUMMON:
			return randf_range(3.0, 5.0)  # 长冷却
		SpellScenarioConfig.SpellScenario.CHAIN:
			return randf_range(1.2, 2.5)  # 中等冷却
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
		SpellScenarioConfig.SpellScenario.DEFENSE:
			scenario_prefix = "防御法术-"
			prefixes = ["护", "盾", "壁", "障", "御"]
			suffixes = ["盾", "壁", "障", "甲", "卫"]
		SpellScenarioConfig.SpellScenario.CONTROL:
			scenario_prefix = "控制法术-"
			prefixes = ["冰", "缚", "锁", "封", "禁"]
			suffixes = ["缚", "锁", "封", "禁", "困"]
		SpellScenarioConfig.SpellScenario.SUMMON:
			scenario_prefix = "召唤法术-"
			prefixes = ["召", "唤", "灵", "魂", "影"]
			suffixes = ["灵", "仆", "卫", "兵", "魂"]
		SpellScenarioConfig.SpellScenario.CHAIN:
			scenario_prefix = "链式法术-"
			prefixes = ["连", "链", "弧", "闪", "跃"]
			suffixes = ["链", "弧", "电", "闪", "跃"]
		_:
			scenario_prefix = "法术-"
			prefixes = ["灵", "玄", "幻", "魔", "咒"]
			suffixes = ["术", "法", "咒", "诀", "式"]
	
	var elements = ["炎", "冰", "雷", "风", "暗", "光", "毒", "灵"]
	
	return scenario_prefix + prefixes[randi() % prefixes.size()] + elements[randi() % elements.size()] + suffixes[randi() % suffixes.size()]
