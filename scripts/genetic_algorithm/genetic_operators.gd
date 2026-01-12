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

func mutate(spell: SpellCoreData) -> void:
	_mutate_carrier(spell)

	_mutate_rules_structure(spell)

	for rule in spell.topology_rules:
		_mutate_rule(rule)

	_ensure_valid_spell(spell)

func _mutate_carrier(spell: SpellCoreData) -> void:
	if spell.carrier == null:
		return

	var carrier = spell.carrier

	if randf() < mutation_config.categorical_mutation_rate:
		carrier.phase = randi() % 3

	if randf() < mutation_config.categorical_mutation_rate * 0.5:
		var old_type = carrier.carrier_type
		carrier.carrier_type = randi() % 3
		if carrier.carrier_type == CarrierConfigData.CarrierType.MINE:
			carrier.velocity = 0.0
			carrier.homing_strength = 0.0
			if carrier.lifetime < 5.0:
				carrier.lifetime = randf_range(5.0, 15.0)
		elif carrier.carrier_type == CarrierConfigData.CarrierType.SLOW_ORB:
			if carrier.velocity > 150.0 or carrier.velocity == 0.0:
				carrier.velocity = randf_range(30.0, 150.0)
		elif old_type == CarrierConfigData.CarrierType.MINE:
			carrier.velocity = randf_range(200.0, 600.0)

	if randf() < mutation_config.numeric_mutation_rate:
		carrier.mass = _mutate_numeric(carrier.mass, 0.3, 10.0)

	if randf() < mutation_config.numeric_mutation_rate:
		match carrier.carrier_type:
			CarrierConfigData.CarrierType.MINE:
				pass
			CarrierConfigData.CarrierType.SLOW_ORB:
				carrier.velocity = _mutate_numeric(carrier.velocity, 20.0, 150.0)
			_:
				carrier.velocity = _mutate_numeric(carrier.velocity, 50.0, 1000.0)

	if randf() < mutation_config.numeric_mutation_rate:
		carrier.lifetime = _mutate_numeric(carrier.lifetime, 0.5, 15.0)

	if randf() < mutation_config.numeric_mutation_rate:
		carrier.size = _mutate_numeric(carrier.size, 0.2, 3.0)

	if randf() < mutation_config.numeric_mutation_rate:
		carrier.piercing = clampi(carrier.piercing + randi_range(-1, 1), 0, 5)

	if randf() < mutation_config.numeric_mutation_rate and carrier.carrier_type != CarrierConfigData.CarrierType.MINE:
		carrier.homing_strength = _mutate_numeric(carrier.homing_strength, 0.0, 1.0)

	if randf() < mutation_config.numeric_mutation_rate:
		carrier.instability_cost = _mutate_numeric(carrier.instability_cost, 0.0, 10.0)

func _mutate_rules_structure(spell: SpellCoreData) -> void:
	if randf() < mutation_config.add_rule_rate and spell.topology_rules.size() < mutation_config.max_rules:
		var new_rule = _generate_random_rule()
		new_rule.rule_name = "变异规则_%d" % spell.topology_rules.size()
		spell.topology_rules.append(new_rule)

	if randf() < mutation_config.remove_rule_rate and spell.topology_rules.size() > mutation_config.min_rules:
		var remove_index = randi() % spell.topology_rules.size()
		spell.topology_rules.remove_at(remove_index)

func _mutate_rule(rule: TopologyRuleData) -> void:
	if randf() < mutation_config.replace_trigger_rate:
		rule.trigger = _generate_random_trigger()
	elif rule.trigger != null:
		_mutate_trigger(rule.trigger)

	_mutate_actions_structure(rule)

	for action in rule.actions:
		_mutate_action(action)

func _mutate_trigger(trigger: TriggerData) -> void:
	if trigger is OnTimerTrigger:
		var timer = trigger as OnTimerTrigger
		if randf() < mutation_config.numeric_mutation_rate:
			timer.delay = _mutate_numeric(timer.delay, 0.1, 5.0)
		if randf() < mutation_config.numeric_mutation_rate:
			timer.repeat_interval = _mutate_numeric(timer.repeat_interval, 0.0, 3.0)

	elif trigger is OnProximityTrigger:
		var prox = trigger as OnProximityTrigger
		if randf() < mutation_config.numeric_mutation_rate:
			prox.detection_radius = _mutate_numeric(prox.detection_radius, 20.0, 300.0)

func _mutate_actions_structure(rule: TopologyRuleData) -> void:
	if randf() < mutation_config.add_action_rate and rule.actions.size() < mutation_config.max_actions_per_rule:
		var new_action = _generate_random_action(false)
		rule.actions.append(new_action)

	if randf() < mutation_config.remove_action_rate and rule.actions.size() > 1:
		var remove_index = randi() % rule.actions.size()
		rule.actions.remove_at(remove_index)

func _mutate_action(action: ActionData) -> void:
	if action is DamageActionData:
		var dmg = action as DamageActionData
		if randf() < mutation_config.numeric_mutation_rate:
			dmg.damage_value = _mutate_numeric(dmg.damage_value, 1.0, 100.0)
		if randf() < mutation_config.categorical_mutation_rate:
			dmg.damage_type = randi() % 4
		if randf() < mutation_config.numeric_mutation_rate:
			dmg.damage_multiplier = _mutate_numeric(dmg.damage_multiplier, 0.5, 2.0)

	elif action is FissionActionData:
		var fission = action as FissionActionData
		if randf() < mutation_config.numeric_mutation_rate:
			fission.spawn_count = clampi(fission.spawn_count + randi_range(-2, 2), 1, 12)
		if randf() < mutation_config.numeric_mutation_rate:
			fission.spread_angle = _mutate_numeric(fission.spread_angle, 10.0, 360.0)
		if randf() < mutation_config.numeric_mutation_rate:
			fission.inherit_velocity = _mutate_numeric(fission.inherit_velocity, 0.1, 1.0)

	elif action is ApplyStatusActionData:
		var status = action as ApplyStatusActionData
		if randf() < mutation_config.categorical_mutation_rate:
			status.status_type = randi() % 6
		if randf() < mutation_config.numeric_mutation_rate:
			status.duration = _mutate_numeric(status.duration, 0.5, 10.0)
		if randf() < mutation_config.numeric_mutation_rate:
			status.effect_value = _mutate_numeric(status.effect_value, 1.0, 30.0)

	elif action is AreaEffectActionData:
		var area = action as AreaEffectActionData
		if randf() < mutation_config.categorical_mutation_rate:
			area.area_shape = randi() % 4
		if randf() < mutation_config.numeric_mutation_rate:
			area.radius = _mutate_numeric(area.radius, 20.0, 200.0)
		if randf() < mutation_config.numeric_mutation_rate:
			area.damage_value = _mutate_numeric(area.damage_value, 1.0, 80.0)
	
	# 召唤动作变异 - 支持所有召唤实体类型
	elif action is SummonActionData:
		var summon = action as SummonActionData
		if randf() < mutation_config.categorical_mutation_rate:
			summon.summon_type = randi() % 6  # TURRET, MINION, ORBITER, DECOY, BARRIER, TOTEM
		if randf() < mutation_config.categorical_mutation_rate:
			summon.behavior_mode = randi() % 4
		if randf() < mutation_config.numeric_mutation_rate:
			summon.summon_count = clampi(summon.summon_count + randi_range(-1, 1), 1, 5)
		if randf() < mutation_config.numeric_mutation_rate:
			summon.summon_duration = _mutate_numeric(summon.summon_duration, 3.0, 20.0)
		if randf() < mutation_config.numeric_mutation_rate:
			summon.summon_health = _mutate_numeric(summon.summon_health, 20.0, 150.0)
		if randf() < mutation_config.numeric_mutation_rate:
			summon.summon_damage = _mutate_numeric(summon.summon_damage, 5.0, 50.0)
		# 环绕体特殊参数变异
		if summon.summon_type == SummonActionData.SummonType.ORBITER:
			if randf() < mutation_config.numeric_mutation_rate:
				summon.orbit_radius = _mutate_numeric(summon.orbit_radius, 30.0, 150.0)
			if randf() < mutation_config.numeric_mutation_rate:
				summon.orbit_speed = _mutate_numeric(summon.orbit_speed, 1.0, 5.0)
		# 图腾特殊参数变异
		if summon.summon_type == SummonActionData.SummonType.TOTEM:
			if randf() < mutation_config.numeric_mutation_rate:
				summon.totem_effect_radius = _mutate_numeric(summon.totem_effect_radius, 50.0, 200.0)
			if randf() < mutation_config.numeric_mutation_rate:
				summon.totem_effect_interval = _mutate_numeric(summon.totem_effect_interval, 0.3, 2.0)
	
	# 链式动作变异 - 华丽视觉效果
	elif action is ChainActionData:
		var chain = action as ChainActionData
		if randf() < mutation_config.categorical_mutation_rate:
			chain.chain_type = randi() % 4  # LIGHTNING, FIRE, ICE, VOID
		if randf() < mutation_config.categorical_mutation_rate:
			chain.target_selection = randi() % 4
		if randf() < mutation_config.numeric_mutation_rate:
			chain.chain_count = clampi(chain.chain_count + randi_range(-1, 2), 2, 8)
		if randf() < mutation_config.numeric_mutation_rate:
			chain.chain_range = _mutate_numeric(chain.chain_range, 100.0, 400.0)
		if randf() < mutation_config.numeric_mutation_rate:
			chain.chain_damage = _mutate_numeric(chain.chain_damage, 10.0, 60.0)
		if randf() < mutation_config.numeric_mutation_rate:
			chain.chain_damage_decay = _mutate_numeric(chain.chain_damage_decay, 0.5, 0.95)
		# 分叉变异（增加华丽度）
		if randf() < mutation_config.numeric_mutation_rate * 0.5:
			if chain.fork_chance == 0 and randf() < 0.3:
				chain.fork_chance = randf_range(0.15, 0.4)
				chain.fork_count = randi_range(1, 2)
			elif chain.fork_chance > 0:
				chain.fork_chance = _mutate_numeric(chain.fork_chance, 0.0, 0.6)

func _mutate_numeric(value: float, min_val: float, max_val: float) -> float:
	var mutation_amount = value * mutation_config.numeric_mutation_strength * randf_range(-1.0, 1.0)
	return clampf(value + mutation_amount, min_val, max_val)

func _ensure_valid_spell(spell: SpellCoreData) -> void:
	if spell.carrier == null:
		spell.carrier = CarrierConfigData.new()

	if spell.topology_rules.is_empty():
		var rule = TopologyRuleData.new()
		rule.rule_name = "默认规则"
		rule.trigger = TriggerData.new()
		rule.trigger.trigger_type = TriggerData.TriggerType.ON_CONTACT
		var damage = DamageActionData.new()
		damage.damage_value = 10.0
		rule.actions.append(damage)
		spell.topology_rules.append(rule)

	for rule in spell.topology_rules:
		if rule.trigger == null:
			rule.trigger = TriggerData.new()
		if rule.actions.is_empty():
			var damage = DamageActionData.new()
			damage.damage_value = randf_range(10.0, 30.0)
			rule.actions.append(damage)
		else:
			for action in rule.actions:
				if action is DamageActionData:
					var dmg = action as DamageActionData
					if dmg.damage_value <= 0:
						dmg.damage_value = randf_range(10.0, 30.0)

func _generate_random_rule() -> TopologyRuleData:
	var rule = TopologyRuleData.new()
	rule.rule_name = "规则_%d" % randi()
	rule.trigger = _generate_random_trigger()

	var action_count = randi_range(1, 3)
	var actions_array: Array[ActionData] = []
	for i in range(action_count):
		actions_array.append(_generate_random_action(i == 0))
	rule.actions = actions_array

	return rule

func _generate_random_trigger() -> TriggerData:
	var trigger_type = randi() % 4
	var trigger: TriggerData

	match trigger_type:
		TriggerData.TriggerType.ON_CONTACT:
			trigger = TriggerData.new()
			trigger.trigger_type = TriggerData.TriggerType.ON_CONTACT
		TriggerData.TriggerType.ON_TIMER:
			var timer_trigger = OnTimerTrigger.new()
			timer_trigger.delay = randf_range(0.5, 3.0)
			timer_trigger.repeat_interval = randf_range(0.5, 2.0) if randf() < 0.3 else 0.0
			trigger = timer_trigger
		TriggerData.TriggerType.ON_PROXIMITY:
			var prox_trigger = OnProximityTrigger.new()
			prox_trigger.detection_radius = randf_range(50.0, 200.0)
			trigger = prox_trigger
		_:
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
		
		4:  # 召唤动作 - 支持所有召唤实体类型
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
		
		5:  # 链式动作 - 华丽视觉效果
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
