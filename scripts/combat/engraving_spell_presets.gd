class_name EngravingSpellPresets

static func create_lightning_chain_on_hit() -> SpellCoreData:
	var spell = SpellCoreData.new()
	spell.generate_id()
	spell.spell_name = "闪电链"
	spell.description = "武器命中时，释放闪电链攻击周围敌人"
	spell.spell_type = SpellCoreData.SpellType.ENGRAVING
	spell.resource_cost = 15.0
	spell.cooldown = 2.0
	spell.base_windup_time = 0.3
	spell.cost_windup_ratio = 0.01

	var trigger = TriggerData.new()
	trigger.trigger_type = TriggerData.TriggerType.ON_WEAPON_HIT
	trigger.trigger_once = false

	var chain_action = ChainActionData.new()
	chain_action.chain_damage = 15.0
	chain_action.chain_count = 3
	chain_action.chain_range = 150.0
	chain_action.chain_damage_decay = 0.8

	var rule = TopologyRuleData.new()
	rule.rule_name = "闪电链"
	rule.trigger = trigger
	var actions: Array[ActionData] = [chain_action]
	rule.actions = actions

	var rules: Array[TopologyRuleData] = [rule]
	spell.topology_rules = rules

	return spell

static func create_fire_enchant_on_attack() -> SpellCoreData:
	var spell = SpellCoreData.new()
	spell.generate_id()
	spell.spell_name = "火焰附魔"
	spell.description = "攻击开始时，为武器附加火焰伤害"
	spell.spell_type = SpellCoreData.SpellType.ENGRAVING
	spell.resource_cost = 8.0
	spell.cooldown = 0.5
	spell.base_windup_time = 0.1
	spell.cost_windup_ratio = 0.005

	var trigger = TriggerData.new()
	trigger.trigger_type = TriggerData.TriggerType.ON_ATTACK_START
	trigger.trigger_once = false

	var damage_action = DamageActionData.new()
	damage_action.damage_value = 10.0
	damage_action.damage_type = CarrierConfigData.DamageType.ENTROPY_BURST

	var rule = TopologyRuleData.new()
	rule.rule_name = "火焰附魔"
	rule.trigger = trigger
	var actions: Array[ActionData] = [damage_action]
	rule.actions = actions

	var rules: Array[TopologyRuleData] = [rule]
	spell.topology_rules = rules

	return spell

static func create_shield_on_damage() -> SpellCoreData:
	var spell = SpellCoreData.new()
	spell.generate_id()
	spell.spell_name = "反伤护盾"
	spell.description = "受到伤害时，生成一个临时护盾"
	spell.spell_type = SpellCoreData.SpellType.ENGRAVING
	spell.resource_cost = 20.0
	spell.cooldown = 5.0
	spell.base_windup_time = 0.2
	spell.cost_windup_ratio = 0.01

	var trigger = TriggerData.new()
	trigger.trigger_type = TriggerData.TriggerType.ON_TAKE_DAMAGE
	trigger.trigger_once = false

	var shield_action = ShieldActionData.new()
	shield_action.shield_amount = 20.0
	shield_action.shield_duration = 3.0

	var rule = TopologyRuleData.new()
	rule.rule_name = "反伤护盾"
	rule.trigger = trigger
	var actions: Array[ActionData] = [shield_action]
	rule.actions = actions

	var rules: Array[TopologyRuleData] = [rule]
	spell.topology_rules = rules

	return spell

static func create_heal_while_flying() -> SpellCoreData:
	var spell = SpellCoreData.new()
	spell.generate_id()
	spell.spell_name = "风之祝福"
	spell.description = "飞行时持续恢复生命值"
	spell.spell_type = SpellCoreData.SpellType.ENGRAVING
	spell.resource_cost = 5.0
	spell.cooldown = 1.0
	spell.base_windup_time = 0.0
	spell.cost_windup_ratio = 0.0

	var trigger = TriggerData.new()
	trigger.trigger_type = TriggerData.TriggerType.ON_TICK
	trigger.trigger_once = false

	var status_action = ApplyStatusActionData.new()
	status_action.status_type = ApplyStatusActionData.StatusType.SPIRITON_SURGE
	status_action.duration = 0.5
	status_action.effect_value = 2.0

	var rule = TopologyRuleData.new()
	rule.rule_name = "风之祝福"
	rule.trigger = trigger
	var actions: Array[ActionData] = [status_action]
	rule.actions = actions

	var rules: Array[TopologyRuleData] = [rule]
	spell.topology_rules = rules

	return spell

static func create_explosion_on_kill() -> SpellCoreData:
	var spell = SpellCoreData.new()
	spell.generate_id()
	spell.spell_name = "死亡爆破"
	spell.description = "击杀敌人时，在其位置产生爆炸"
	spell.spell_type = SpellCoreData.SpellType.ENGRAVING
	spell.resource_cost = 25.0
	spell.cooldown = 3.0
	spell.base_windup_time = 0.4
	spell.cost_windup_ratio = 0.015

	var trigger = TriggerData.new()
	trigger.trigger_type = TriggerData.TriggerType.ON_KILL_ENEMY
	trigger.trigger_once = false

	var explosion_action = SpawnExplosionActionData.new()
	explosion_action.explosion_damage = 25.0
	explosion_action.explosion_radius = 100.0
	explosion_action.damage_falloff = 0.5

	var rule = TopologyRuleData.new()
	rule.rule_name = "死亡爆破"
	rule.trigger = trigger
	var actions: Array[ActionData] = [explosion_action]
	rule.actions = actions

	var rules: Array[TopologyRuleData] = [rule]
	spell.topology_rules = rules

	return spell

static func create_berserk_on_low_health() -> SpellCoreData:
	var spell = SpellCoreData.new()
	spell.generate_id()
	spell.spell_name = "狂暴本能"
	spell.description = "生命值低于30%时，大幅提升攻击力"
	spell.spell_type = SpellCoreData.SpellType.ENGRAVING
	spell.resource_cost = 0.0
	spell.cooldown = 10.0
	spell.base_windup_time = 0.0
	spell.cost_windup_ratio = 0.0

	var trigger = TriggerData.new()
	trigger.trigger_type = TriggerData.TriggerType.ON_HEALTH_LOW
	trigger.trigger_once = false

	var status_action = ApplyStatusActionData.new()
	status_action.status_type = ApplyStatusActionData.StatusType.SPIRITON_SURGE
	status_action.duration = 5.0
	status_action.effect_value = 1.5

	var rule = TopologyRuleData.new()
	rule.rule_name = "狂暴本能"
	rule.trigger = trigger
	var actions: Array[ActionData] = [status_action]
	rule.actions = actions

	var rules: Array[TopologyRuleData] = [rule]
	spell.topology_rules = rules

	return spell

static func create_fission_on_spell_cast() -> SpellCoreData:
	var spell = SpellCoreData.new()
	spell.generate_id()
	spell.spell_name = "法术分裂"
	spell.description = "施放法术时，额外发射多个小型弹幕"
	spell.spell_type = SpellCoreData.SpellType.ENGRAVING
	spell.resource_cost = 30.0
	spell.cooldown = 4.0
	spell.base_windup_time = 0.5
	spell.cost_windup_ratio = 0.02

	var trigger = TriggerData.new()
	trigger.trigger_type = TriggerData.TriggerType.ON_SPELL_CAST
	trigger.trigger_once = false

	var child_spell = SpellCoreData.new()
	child_spell.generate_id()
	child_spell.spell_name = "分裂弹"
	child_spell.spell_type = SpellCoreData.SpellType.PROJECTILE
	child_spell.carrier = CarrierConfigData.new()
	child_spell.carrier.velocity = 300.0
	child_spell.carrier.lifetime = 2.0
	child_spell.carrier.size = 0.5

	var child_rule = TopologyRuleData.new()
	child_rule.rule_name = "碰撞伤害"
	var child_trigger = TriggerData.new()
	child_trigger.trigger_type = TriggerData.TriggerType.ON_CONTACT
	child_rule.trigger = child_trigger
	var child_damage = DamageActionData.new()
	child_damage.damage_value = 8.0
	var child_actions: Array[ActionData] = [child_damage]
	child_rule.actions = child_actions
	var child_rules: Array[TopologyRuleData] = [child_rule]
	child_spell.topology_rules = child_rules

	var fission_action = FissionActionData.new()
	fission_action.spawn_count = 3
	fission_action.spread_angle = 45.0
	fission_action.child_spell_data = child_spell

	var rule = TopologyRuleData.new()
	rule.rule_name = "法术分裂"
	rule.trigger = trigger
	var actions: Array[ActionData] = [fission_action]
	rule.actions = actions

	var rules: Array[TopologyRuleData] = [rule]
	spell.topology_rules = rules

	return spell

static func create_damage_trail_on_move() -> SpellCoreData:
	var spell = SpellCoreData.new()
	spell.generate_id()
	spell.spell_name = "毒雾轨迹"
	spell.description = "移动时在身后留下伤害区域"
	spell.spell_type = SpellCoreData.SpellType.ENGRAVING
	spell.resource_cost = 12.0
	spell.cooldown = 2.0
	spell.base_windup_time = 0.2
	spell.cost_windup_ratio = 0.01

	var trigger = TriggerData.new()
	trigger.trigger_type = TriggerData.TriggerType.ON_MOVE_START
	trigger.trigger_once = false

	var zone_action = SpawnDamageZoneActionData.new()
	zone_action.zone_damage = 5.0
	zone_action.tick_interval = 0.5
	zone_action.zone_duration = 3.0
	zone_action.zone_radius = 50.0

	var rule = TopologyRuleData.new()
	rule.rule_name = "毒雾轨迹"
	rule.trigger = trigger
	var actions: Array[ActionData] = [zone_action]
	rule.actions = actions

	var rules: Array[TopologyRuleData] = [rule]
	spell.topology_rules = rules

	return spell

static func get_all_presets() -> Array[SpellCoreData]:
	return [
		create_lightning_chain_on_hit(),
		create_fire_enchant_on_attack(),
		create_shield_on_damage(),
		create_heal_while_flying(),
		create_explosion_on_kill(),
		create_berserk_on_low_health(),
		create_fission_on_spell_cast(),
		create_damage_trail_on_move()
	]

static func get_presets_by_category() -> Dictionary:
	return {
		"攻击增强": [
			create_lightning_chain_on_hit(),
			create_fire_enchant_on_attack(),
			create_explosion_on_kill()
		],
		"防御增强": [
			create_shield_on_damage(),
			create_berserk_on_low_health()
		],
		"移动增强": [
			create_heal_while_flying(),
			create_damage_trail_on_move()
		],
		"施法增强": [
			create_fission_on_spell_cast()
		]
	}

static func get_spell_windup_info(spell: SpellCoreData, proficiency: float = 0.0) -> Dictionary:
	var normal_windup = spell.calculate_windup_time(proficiency, false)
	var engraved_windup = spell.calculate_windup_time(proficiency, true)

	return {
		"spell_name": spell.spell_name,
		"spell_type": spell.get_type_name(),
		"cost": spell.resource_cost,
		"normal_windup": normal_windup,
		"engraved_windup": engraved_windup,
		"windup_reduction": (1.0 - engraved_windup / normal_windup) * 100 if normal_windup > 0 else 0,
		"proficiency": proficiency * 100
	}
