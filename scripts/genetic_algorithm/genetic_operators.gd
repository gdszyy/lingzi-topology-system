class_name GeneticOperators
extends RefCounted

var mutation_config = {
	"numeric_mutation_rate": 0.1,
	"categorical_mutation_rate": 0.05,

	"add_rule_rate": 0.02,
	"remove_rule_rate": 0.02,
	"add_action_rate": 0.03,
	"remove_action_rate": 0.03,
	"replace_trigger_rate": 0.02,

	"numeric_mutation_strength": 0.2,

	"max_rules": 6,
	"max_actions_per_rule": 4,
	"min_rules": 1
}

var crossover_config = {
	"crossover_rate": 0.8,
	"rule_swap_rate": 0.5,
	"action_swap_rate": 0.3
}

func crossover(parent_a: SpellCoreData, parent_b: SpellCoreData) -> Array[SpellCoreData]:
	if randf() > crossover_config.crossover_rate:
		return [parent_a.clone_deep(), parent_b.clone_deep()]

	var child_a = parent_a.clone_deep()
	var child_b = parent_b.clone_deep()

	_crossover_carriers(child_a, child_b, parent_a, parent_b)

	_crossover_rules(child_a, child_b, parent_a, parent_b)

	child_a.generate_id()
	child_b.generate_id()
	child_a.spell_name = parent_a.spell_name + "×" + parent_b.spell_name.substr(0, 1)
	child_b.spell_name = parent_b.spell_name + "×" + parent_a.spell_name.substr(0, 1)

	return [child_a, child_b]

func _crossover_carriers(child_a: SpellCoreData, child_b: SpellCoreData,
						  parent_a: SpellCoreData, parent_b: SpellCoreData) -> void:
	if parent_a.carrier == null or parent_b.carrier == null:
		return

	var ca = child_a.carrier
	var cb = child_b.carrier
	var pa = parent_a.carrier
	var pb = parent_b.carrier

	if randf() > 0.5:
		ca.phase = pb.phase
		cb.phase = pa.phase

	if randf() > 0.5:
		ca.mass = pb.mass
		cb.mass = pa.mass

	if randf() > 0.5:
		ca.velocity = pb.velocity
		cb.velocity = pa.velocity

	if randf() > 0.5:
		ca.lifetime = pb.lifetime
		cb.lifetime = pa.lifetime

	if randf() > 0.5:
		ca.size = pb.size
		cb.size = pa.size

	if randf() > 0.5:
		ca.piercing = pb.piercing
		cb.piercing = pa.piercing

	if randf() > 0.5:
		ca.homing_strength = pb.homing_strength
		cb.homing_strength = pa.homing_strength

func _crossover_rules(child_a: SpellCoreData, child_b: SpellCoreData,
					   parent_a: SpellCoreData, parent_b: SpellCoreData) -> void:
	if randf() < crossover_config.rule_swap_rate:
		if parent_a.topology_rules.size() > 0 and parent_b.topology_rules.size() > 0:
			var point_a = randi() % parent_a.topology_rules.size()
			var point_b = randi() % parent_b.topology_rules.size()

			var rules_a_before = child_a.topology_rules.slice(0, point_a)
			var rules_b_before = child_b.topology_rules.slice(0, point_b)

			var new_rules_a: Array[TopologyRuleData] = []
			for rule in rules_a_before:
				new_rules_a.append(rule)
			for rule in parent_b.topology_rules.slice(point_b):
				new_rules_a.append(rule.clone_deep())
			child_a.topology_rules = new_rules_a

			var new_rules_b: Array[TopologyRuleData] = []
			for rule in rules_b_before:
				new_rules_b.append(rule)
			for rule in parent_a.topology_rules.slice(point_a):
				new_rules_b.append(rule.clone_deep())
			child_b.topology_rules = new_rules_b

	for i in range(min(child_a.topology_rules.size(), child_b.topology_rules.size())):
		if randf() < crossover_config.action_swap_rate:
			var rule_a = child_a.topology_rules[i]
			var rule_b = child_b.topology_rules[i]
			if rule_a.actions.size() > 0 and rule_b.actions.size() > 0:
				var idx_a = randi() % rule_a.actions.size()
				var idx_b = randi() % rule_b.actions.size()
				var temp = rule_a.actions[idx_a]
				rule_a.actions[idx_a] = rule_b.actions[idx_b]
				rule_b.actions[idx_b] = temp

func mutate(spell: SpellCoreData) -> void:
	_mutate_carrier(spell.carrier)

	if randf() < mutation_config.add_rule_rate and spell.topology_rules.size() < mutation_config.max_rules:
		spell.topology_rules.append(_generate_random_rule())

	if randf() < mutation_config.remove_rule_rate and spell.topology_rules.size() > mutation_config.min_rules:
		spell.topology_rules.remove_at(randi() % spell.topology_rules.size())

	for rule in spell.topology_rules:
		_mutate_rule(rule)

func _mutate_carrier(carrier: CarrierConfigData) -> void:
	if carrier == null: return

	if randf() < mutation_config.numeric_mutation_rate:
		carrier.mass *= randf_range(1.0 - mutation_config.numeric_mutation_strength, 1.0 + mutation_config.numeric_mutation_strength)
	if randf() < mutation_config.numeric_mutation_rate:
		carrier.velocity *= randf_range(1.0 - mutation_config.numeric_mutation_strength, 1.0 + mutation_config.numeric_mutation_strength)
	if randf() < mutation_config.numeric_mutation_rate:
		carrier.lifetime *= randf_range(1.0 - mutation_config.numeric_mutation_strength, 1.0 + mutation_config.numeric_mutation_strength)
	if randf() < mutation_config.numeric_mutation_rate:
		carrier.size *= randf_range(1.0 - mutation_config.numeric_mutation_strength, 1.0 + mutation_config.numeric_mutation_strength)

func _mutate_rule(rule: TopologyRuleData) -> void:
	if randf() < mutation_config.replace_trigger_rate:
		rule.trigger = _generate_random_trigger()

	if randf() < mutation_config.add_action_rate and rule.actions.size() < mutation_config.max_actions_per_rule:
		rule.actions.append(_generate_random_action())

	if randf() < mutation_config.remove_action_rate and rule.actions.size() > 1:
		rule.actions.remove_at(randi() % rule.actions.size())

	for action in rule.actions:
		_mutate_action(action)

func _mutate_action(action: ActionData) -> void:
	if action is DamageActionData:
		if randf() < mutation_config.numeric_mutation_rate:
			action.damage_value *= randf_range(1.0 - mutation_config.numeric_mutation_strength, 1.0 + mutation_config.numeric_mutation_strength)
	elif action is FissionActionData:
		if randf() < mutation_config.numeric_mutation_rate:
			action.spawn_count = clampi(action.spawn_count + (randi() % 3 - 1), 2, 10)
	elif action is ApplyStatusActionData:
		if randf() < mutation_config.categorical_mutation_rate:
			action.status_type = randi() % 6

func _generate_random_rule() -> TopologyRuleData:
	var rule = TopologyRuleData.new()
	rule.trigger = _generate_random_trigger()
	rule.actions.append(_generate_random_action())
	return rule

func _generate_random_trigger() -> TriggerData:
	var type = randi() % 4
	var trigger: TriggerData
	match type:
		0:
			trigger = OnTimerTrigger.new()
			trigger.trigger_type = TriggerData.TriggerType.ON_TIMER
			trigger.interval = randf_range(0.5, 3.0)
		1:
			trigger = OnProximityTrigger.new()
			trigger.trigger_type = TriggerData.TriggerType.ON_PROXIMITY
			trigger.radius = randf_range(50.0, 150.0)
			trigger.target_group = "enemy"
		2:
			trigger = TriggerData.new()
			trigger.trigger_type = TriggerData.TriggerType.ON_CONTACT
		3:
			trigger = TriggerData.new()
			trigger.trigger_type = TriggerData.TriggerType.ON_DEATH

	trigger.trigger_once = randf() > 0.3
	return trigger

func _generate_random_action(allow_fission: bool = true) -> ActionData:
	var action_type = randi() % 6  # 扩展为6种动作类型

	if action_type == ActionData.ActionType.FISSION and (not allow_fission or randf() > 0.4):
		action_type = ActionData.ActionType.DAMAGE

	match action_type:
		ActionData.ActionType.DAMAGE:
			var damage = DamageActionData.new()
			damage.damage_value = randf_range(5.0, 40.0)
			damage.damage_type = randi() % 4
			damage.damage_multiplier = randf_range(0.8, 1.5)
			return damage

		ActionData.ActionType.FISSION:
			var fission = FissionActionData.new()
			fission.spawn_count = randi_range(2, 8)
			fission.spread_angle = randf_range(30.0, 180.0)
			fission.inherit_velocity = randf_range(0.3, 1.0)
			return fission

		ActionData.ActionType.APPLY_STATUS:
			var status = ApplyStatusActionData.new()
			status.status_type = randi() % 6
			status.duration = randf_range(1.0, 5.0)
			status.effect_value = randf_range(2.0, 15.0)
			return status

		ActionData.ActionType.AREA_EFFECT:
			var area = AreaEffectActionData.new()
			area.area_shape = randi() % 4
			area.radius = randf_range(30.0, 120.0)
			area.damage_value = randf_range(5.0, 30.0)
			return area

		ActionData.ActionType.SUMMON:
			var summon = SummonActionData.new()
			summon.summon_type = randi() % 6  # TURRET, MINION, ORBITER, DECOY, BARRIER, TOTEM
			summon.behavior_mode = randi() % 4
			summon.summon_count = randi_range(1, 3)
			summon.summon_duration = randf_range(5.0, 12.0)
			summon.summon_health = randf_range(30.0, 80.0)
			summon.summon_damage = randf_range(10.0, 25.0)
			# 环绕体特殊处理
			if summon.summon_type == SummonActionData.SummonType.ORBITER:
				summon.orbit_radius = randf_range(50.0, 100.0)
				summon.orbit_speed = randf_range(1.5, 3.5)
				summon.summon_count = randi_range(2, 4)
			return summon

		ActionData.ActionType.CHAIN:
			var chain = ChainActionData.new()
			chain.chain_type = randi() % 4  # LIGHTNING, FIRE, ICE, VOID
			chain.chain_count = randi_range(2, 5)
			chain.chain_range = randf_range(150.0, 250.0)
			chain.chain_damage = randf_range(15.0, 35.0)
			chain.chain_damage_decay = randf_range(0.65, 0.85)
			# 小概率分叉
			if randf() < 0.2:
				chain.fork_chance = randf_range(0.2, 0.4)
				chain.fork_count = randi_range(1, 2)
			return chain

		_:
			var damage = DamageActionData.new()
			damage.damage_value = randf_range(5.0, 40.0)
			return damage
