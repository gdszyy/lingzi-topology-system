class_name EngravingManager extends Node

## 篆刻管理器
## 管理角色的肢体篆刻系统，实现二维体素战斗机制
## 当肢体被摧毁时，其上的法术自动失效

signal engraving_triggered(trigger_type: int, spell: SpellCoreData, source: String)
signal engraving_windup_started(slot: EngravingSlot, windup_time: float)
signal engraving_windup_completed(slot: EngravingSlot)
signal action_executed(action: ActionData, context: Dictionary)
signal engraving_effect_applied(effect_type: String, target: Node2D, value: float)
signal proficiency_updated(spell_id: String, proficiency: float)

## 二维体素战斗系统信号
signal body_part_damaged(part: BodyPartData, damage: float, remaining_health: float)
signal body_part_destroyed(part: BodyPartData)
signal body_part_restored(part: BodyPartData)
signal spells_disabled(part: BodyPartData, spell_count: int)
signal spells_enabled(part: BodyPartData, spell_count: int)

var player: PlayerController = null

var body_parts: Array[BodyPartData] = []

var all_slots: Array[EngravingSlot] = []

var action_executor: ActionExecutor = null

var proficiency_manager: ProficiencyManager = null

var current_context: Dictionary = {}

var trigger_stats: Dictionary = {}

var engraving_trigger_count: int = 0

var is_enabled: bool = true

## 二维体素战斗系统统计
var body_part_stats: Dictionary = {
	"total_parts_destroyed": 0,
	"total_parts_restored": 0,
	"total_spells_disabled": 0,
	"damage_by_part": {}
}

func _ready() -> void:
	action_executor = ActionExecutor.new()
	action_executor.name = "ActionExecutor"
	add_child(action_executor)

	proficiency_manager = ProficiencyManager.new()
	proficiency_manager.name = "ProficiencyManager"
	add_child(proficiency_manager)

	proficiency_manager.proficiency_changed.connect(_on_proficiency_changed)
	proficiency_manager.level_up.connect(_on_proficiency_level_up)

func _process(delta: float) -> void:
	_update_slots(delta)
	_process_periodic_triggers(delta)

func initialize(_player: PlayerController) -> void:
	player = _player

	body_parts = BodyPartData.create_default_body_parts()
	
	# 连接肢体信号
	_connect_body_part_signals()

	_register_all_slots()

	_connect_player_signals()

	action_executor.initialize(player)

## 连接所有肢体的信号
func _connect_body_part_signals() -> void:
	for part in body_parts:
		if not part.damage_taken.is_connected(_on_body_part_damage_taken):
			part.damage_taken.connect(_on_body_part_damage_taken.bind(part))
		if not part.destroyed.is_connected(_on_body_part_destroyed):
			part.destroyed.connect(_on_body_part_destroyed)
		if not part.restored.is_connected(_on_body_part_restored):
			part.restored.connect(_on_body_part_restored)
		if not part.health_changed.is_connected(_on_body_part_health_changed):
			part.health_changed.connect(_on_body_part_health_changed.bind(part))

func _register_all_slots() -> void:
	all_slots.clear()

	for part in body_parts:
		# 只注册功能完好的肢体的槽位
		if part.is_functional:
			for slot in part.engraving_slots:
				all_slots.append(slot)
				if not slot.windup_started.is_connected(_on_slot_windup_started):
					slot.windup_started.connect(_on_slot_windup_started.bind(slot))
				if not slot.windup_completed.is_connected(_on_slot_windup_completed):
					slot.windup_completed.connect(_on_slot_windup_completed.bind(slot))

	if player != null and player.current_weapon != null:
		for slot in player.current_weapon.engraving_slots:
			all_slots.append(slot)
			if not slot.windup_started.is_connected(_on_slot_windup_started):
				slot.windup_started.connect(_on_slot_windup_started.bind(slot))
			if not slot.windup_completed.is_connected(_on_slot_windup_completed):
				slot.windup_completed.connect(_on_slot_windup_completed.bind(slot))

func _connect_player_signals() -> void:
	if player == null:
		return

	if player.has_signal("attack_started"):
		player.attack_started.connect(_on_attack_started)
	if player.has_signal("attack_hit"):
		player.attack_hit.connect(_on_attack_hit)
	if player.has_signal("attack_ended"):
		player.attack_ended.connect(_on_attack_ended)

	if player.has_signal("state_changed"):
		player.state_changed.connect(_on_state_changed)

	if player.has_signal("took_damage"):
		player.took_damage.connect(_on_took_damage)
	if player.has_signal("energy_cap_changed"):
		player.energy_cap_changed.connect(_on_health_changed)

	if player.has_signal("spell_cast"):
		player.spell_cast.connect(_on_spell_cast)
	if player.has_signal("spell_hit"):
		player.spell_hit.connect(_on_spell_hit)

	if player.has_signal("weapon_changed"):
		player.weapon_changed.connect(_on_weapon_changed)

func _update_slots(delta: float) -> void:
	for slot in all_slots:
		slot.update(delta)

func _process_periodic_triggers(delta: float) -> void:
	if not is_enabled:
		return

	current_context = {
		"delta": delta,
		"player": player,
		"position": player.global_position if player != null else Vector2.ZERO,
		"is_attacking": player.is_attacking if player != null else false,
		"is_moving": player.velocity.length_squared() > 100 if player != null else false
	}

	distribute_trigger(TriggerData.TriggerType.ON_TICK, current_context)

## 分发触发器（二维体素战斗系统核心方法）
## 只有功能完好的肢体上的法术才会被触发
func distribute_trigger(trigger_type: int, context: Dictionary = {}) -> void:
	if not is_enabled:
		return

	if not trigger_stats.has(trigger_type):
		trigger_stats[trigger_type] = 0
	trigger_stats[trigger_type] += 1

	# 遍历所有肢体
	for part in body_parts:
		# 核心检查：只处理功能完好的肢体
		if not part.is_functional:
			continue
		
		# 遍历该肢体的所有篆刻槽
		for slot in part.engraving_slots:
			if not slot.can_trigger():
				continue

			if slot.engraved_spell == null:
				continue

			var proficiency = proficiency_manager.get_proficiency_value(slot.engraved_spell.spell_id)
			
			# 应用肢体效率修正
			var efficiency_context = context.duplicate()
			efficiency_context["part_efficiency"] = part.efficiency
			efficiency_context["body_part"] = part

			var started = slot.start_trigger(trigger_type, efficiency_context, proficiency)

			if started:
				if not slot.spell_triggered.is_connected(_on_slot_spell_triggered):
					slot.spell_triggered.connect(_on_slot_spell_triggered.bind(slot, efficiency_context))

	# 武器槽位单独处理（不受肢体损伤影响，但受手臂状态影响）
	# 应用武器特质修正器
	if player != null and player.current_weapon != null:
		var weapon = player.current_weapon
		var trait_modifier = weapon.get_trait_modifier()
		
		# 检查是否可以使用武器
		var can_use_weapon = _can_use_weapon()
		if not can_use_weapon:
			return
		
		# 检查武器特质规则
		var is_attacking = context.get("is_attacking", false)
		var is_moving = context.get("is_moving", false)
		if not trait_modifier.can_trigger_in_state(is_attacking, is_moving):
			return
		
		# 检查武器命中要求
		if not trait_modifier.check_weapon_hit_requirement(trigger_type):
			return
		
		for slot in weapon.engraving_slots:
			if not slot.can_trigger():
				continue

			if slot.engraved_spell == null:
				continue
			
			# 设置武器特质修正器
			slot.set_weapon_modifier(trait_modifier)

			var proficiency = proficiency_manager.get_proficiency_value(slot.engraved_spell.spell_id)
			
			# 计算调整后的能量消耗
			var modified_cost = slot.calculate_modified_cost(trigger_type)
			
			# 检查能量是否足够
			if player.energy_system != null and not player.energy_system.can_consume(modified_cost):
				continue
			
			# 准备上下文，包含武器特质信息
			var weapon_context = context.duplicate()
			weapon_context["weapon_trait_modifier"] = trait_modifier
			weapon_context["trigger_type"] = trigger_type
			weapon_context["modified_cost"] = modified_cost
			weapon_context["consecutive_count"] = slot.consecutive_trigger_count
			weapon_context["chain_bonus"] = slot.get_chain_bonus()

			var started = slot.start_trigger(trigger_type, weapon_context, proficiency)

			if started:
				# 扣除能量
				if player.energy_system != null:
					player.energy_system.consume_energy(modified_cost)
				
				# 更新连续触发计数
				slot.update_consecutive_count()
				
				if not slot.spell_triggered.is_connected(_on_slot_spell_triggered):
					slot.spell_triggered.connect(_on_slot_spell_triggered.bind(slot, weapon_context))

## 检查是否可以使用武器（需要至少一只手臂功能正常）
func _can_use_weapon() -> bool:
	var right_arm = get_body_part(BodyPartData.PartType.RIGHT_ARM)
	var left_arm = get_body_part(BodyPartData.PartType.LEFT_ARM)
	
	# 双手武器需要两只手臂
	if player.current_weapon != null and player.current_weapon.is_two_handed():
		return (right_arm != null and right_arm.is_functional) and (left_arm != null and left_arm.is_functional)
	
	# 单手武器只需要一只手臂
	return (right_arm != null and right_arm.is_functional) or (left_arm != null and left_arm.is_functional)

func distribute_trigger_immediate(trigger_type: int, context: Dictionary = {}) -> void:
	if not is_enabled:
		return

	# 遍历所有肢体
	for part in body_parts:
		# 核心检查：只处理功能完好的肢体
		if not part.is_functional:
			continue
		
		for slot in part.engraving_slots:
			if not slot.can_trigger():
				continue

			var triggered_rules = slot.trigger(trigger_type, context)

			for rule in triggered_rules:
				# 应用肢体效率到效果
				var efficiency_context = context.duplicate()
				efficiency_context["part_efficiency"] = part.efficiency
				efficiency_context["body_part"] = part
				_execute_rule_actions(rule, efficiency_context, slot)
				engraving_triggered.emit(trigger_type, slot.engraved_spell, slot.slot_name)
				engraving_trigger_count += 1

func _on_slot_windup_started(spell: SpellCoreData, windup_time: float, slot: EngravingSlot) -> void:
	engraving_windup_started.emit(slot, windup_time)
	print("[刻录前摇] %s - %s: %.2fs" % [slot.slot_name, spell.spell_name, windup_time])

func _on_slot_windup_completed(spell: SpellCoreData, slot: EngravingSlot) -> void:
	engraving_windup_completed.emit(slot)
	print("[刻录触发] %s - %s" % [slot.slot_name, spell.spell_name])

func _on_slot_spell_triggered(spell: SpellCoreData, trigger_type: int, slot: EngravingSlot, context: Dictionary) -> void:
	for rule in spell.topology_rules:
		if rule.trigger != null and rule.trigger.trigger_type == trigger_type:
			if rule.enabled:
				_execute_rule_actions(rule, context, slot)

	engraving_triggered.emit(trigger_type, spell, slot.slot_name)
	engraving_trigger_count += 1

	proficiency_manager.record_spell_use(spell.spell_id)

	if slot.spell_triggered.is_connected(_on_slot_spell_triggered):
		slot.spell_triggered.disconnect(_on_slot_spell_triggered)

func _execute_rule_actions(rule: TopologyRuleData, context: Dictionary, slot: EngravingSlot) -> void:
	var modified_context = context.duplicate()
	
	# 应用武器特质对效果强度的修正
	if slot.weapon_modifier != null:
		for action in rule.actions:
			var effect_multiplier = slot.calculate_modified_effect(action.action_type)
			modified_context["effect_multiplier"] = effect_multiplier
			
			# 应用连续触发加成
			var chain_bonus = slot.get_chain_bonus()
			modified_context["effect_multiplier"] += chain_bonus
			
			action_executor.execute_action(action, modified_context)
			action_executed.emit(action, modified_context)
	else:
		# 肢体篆刻，应用肢体效率
		var efficiency = context.get("part_efficiency", 1.0)
		modified_context["effect_multiplier"] = efficiency
		
		for action in rule.actions:
			action_executor.execute_action(action, modified_context)
			action_executed.emit(action, modified_context)

func get_body_parts() -> Array[BodyPartData]:
	return body_parts

func get_body_part(type: int) -> BodyPartData:
	for part in body_parts:
		if part.part_type == type:
			return part
	return null

func get_functional_body_parts() -> Array[BodyPartData]:
	var functional: Array[BodyPartData] = []
	for part in body_parts:
		if part.is_functional:
			functional.append(part)
	return functional

func damage_body_part(type: int, damage: float) -> float:
	var part = get_body_part(type)
	if part != null:
		return part.take_damage(damage)
	return damage # 如果找不到肢体，伤害直接传递给核心

func _on_body_part_damage_taken(damage: float, _remaining_health: float, part: BodyPartData) -> void:
	body_part_damaged.emit(part, damage, part.current_health)
	
	var part_name = BodyPartData.PartType.keys()[part.part_type]
	if not body_part_stats.damage_by_part.has(part_name):
		body_part_stats.damage_by_part[part_name] = 0.0
	body_part_stats.damage_by_part[part_name] += damage

func _on_body_part_destroyed(part: BodyPartData) -> void:
	body_part_destroyed.emit(part)
	body_part_stats.total_parts_destroyed += 1
	
	# 禁用该肢体上的所有篆刻
	var disabled_count = part.engraving_slots.size()
	body_part_stats.total_spells_disabled += disabled_count
	spells_disabled.emit(part, disabled_count)
	
	# 重新注册可用槽位
	_register_all_slots()
	
	print("[肢体摧毁] %s 已损坏，其上的 %d 个篆刻法术失效！" % [part.part_name, disabled_count])

func _on_body_part_restored(part: BodyPartData) -> void:
	body_part_restored.emit(part)
	body_part_stats.total_parts_restored += 1
	
	# 重新启用该肢体上的篆刻
	var enabled_count = part.engraving_slots.size()
	spells_enabled.emit(part, enabled_count)
	
	# 重新注册可用槽位
	_register_all_slots()
	
	print("[肢体修复] %s 已修复，其上的 %d 个篆刻法术重新激活！" % [part.part_name, enabled_count])

func _on_body_part_health_changed(current: float, _max_val: float, part: BodyPartData) -> void:
	# 可以在这里处理肢体效率随血量下降的逻辑
	pass

## 治疗特定肢体
func heal_body_part(part_type: int, amount: float) -> float:
	var part = get_body_part(part_type)
	if part != null:
		return part.heal(amount)
	return 0.0

## 完全恢复所有肢体
func restore_all_body_parts() -> void:
	for part in body_parts:
		part.fully_restore()
	_register_all_slots()

## 将法术篆刻到肢体的指定槽位
func engrave_to_body_part(part_type: int, slot_index: int, spell: SpellCoreData) -> bool:
	var part = get_body_part(part_type)
	if part == null:
		push_warning("[EngravingManager] 找不到肢体类型: %d" % part_type)
		return false
	if slot_index < 0 or slot_index >= part.engraving_slots.size():
		push_warning("[EngravingManager] 槽位索引越界: %d (肢体 %s 只有 %d 个槽位)" % [slot_index, part.part_name, part.engraving_slots.size()])
		return false
	var result = part.engraving_slots[slot_index].engrave_spell(spell)
	if result:
		_register_all_slots()
	return result

## 将法术篆刻到武器的指定槽位
func engrave_to_weapon(slot_index: int, spell: SpellCoreData) -> bool:
	if player == null or player.current_weapon == null:
		push_warning("[EngravingManager] 玩家或武器为空，无法篆刻")
		return false
	var result = player.current_weapon.engrave_spell_to_slot(slot_index, spell)
	if result:
		_register_all_slots()
	return result

func get_all_engraved_spells() -> Array[SpellCoreData]:
	var spells: Array[SpellCoreData] = []

	for part in body_parts:
		if part.is_functional:
			spells.append_array(part.get_engraved_spells())

	if player != null and player.current_weapon != null:
		spells.append_array(player.current_weapon.get_engraved_spells())

	return spells

## 获取所有法术（包括失效的）
func get_all_engraved_spells_including_disabled() -> Array[SpellCoreData]:
	var spells: Array[SpellCoreData] = []

	for part in body_parts:
		for slot in part.engraving_slots:
			if slot.engraved_spell != null:
				spells.append(slot.engraved_spell)

	if player != null and player.current_weapon != null:
		spells.append_array(player.current_weapon.get_engraved_spells())

	return spells

func get_spell_proficiency(spell_id: String) -> float:
	return proficiency_manager.get_proficiency_value(spell_id)

func get_spell_proficiency_data(spell_id: String) -> SpellProficiency:
	return proficiency_manager.get_proficiency(spell_id)

func get_stats() -> Dictionary:
	var total_slots = all_slots.size()
	var used_slots = 0
	var winding_up_count = 0

	for slot in all_slots:
		if slot.engraved_spell != null:
			used_slots += 1
		if slot.is_winding_up:
			winding_up_count += 1

	return {
		"total_slots": total_slots,
		"used_slots": used_slots,
		"winding_up_count": winding_up_count,
		"trigger_count": engraving_trigger_count,
		"trigger_stats": trigger_stats.duplicate(),
		"proficiency_stats": proficiency_manager.get_stats_summary(),
		"body_part_stats": body_part_stats.duplicate()
	}

## 获取肢体状态摘要
func get_body_parts_summary() -> String:
	var summary_lines = []
	for part in body_parts:
		summary_lines.append(part.get_status_summary())
	return "\n".join(summary_lines)

func get_trigger_count() -> int:
	return engraving_trigger_count

func _on_proficiency_changed(spell_id: String, proficiency: float) -> void:
	proficiency_updated.emit(spell_id, proficiency)

func _on_proficiency_level_up(spell_id: String, new_level: int) -> void:
	var level_names = ["新手", "学徒", "熟练", "专家", "大师"]
	var level_name = level_names[new_level] if new_level < level_names.size() else "未知"
	print("[熟练度提升] %s 达到 %s 级别!" % [spell_id, level_name])

func _on_attack_started(attack: AttackData) -> void:
	current_context = {
		"attack": attack,
		"player": player,
		"position": player.global_position,
		"is_attacking": true,
		"is_moving": player.velocity.length_squared() > 100 if player != null else false
	}
	distribute_trigger(TriggerData.TriggerType.ON_ATTACK_START, current_context)

func _on_attack_hit(target: Node2D, damage: float) -> void:
	current_context = {
		"target": target,
		"damage": damage,
		"player": player,
		"position": player.global_position,
		"target_position": target.global_position if target != null else Vector2.ZERO,
		"is_attacking": true,
		"is_moving": player.velocity.length_squared() > 100 if player != null else false
	}

	distribute_trigger(TriggerData.TriggerType.ON_WEAPON_HIT, current_context)

	distribute_trigger(TriggerData.TriggerType.ON_DEAL_DAMAGE, current_context)

	if target != null and target.has_method("is_dead") and target.is_dead():
		distribute_trigger(TriggerData.TriggerType.ON_KILL_ENEMY, current_context)

		for spell in get_all_engraved_spells():
			proficiency_manager.record_spell_kill(spell.spell_id)

func _on_attack_ended(attack: AttackData) -> void:
	current_context = {
		"attack": attack,
		"player": player,
		"position": player.global_position,
		"is_attacking": false,
		"is_moving": player.velocity.length_squared() > 100 if player != null else false
	}
	distribute_trigger(TriggerData.TriggerType.ON_ATTACK_END, current_context)

func _on_state_changed(state_name: String) -> void:
	current_context = {
		"state_name": state_name,
		"player": player,
		"position": player.global_position,
		"is_attacking": player.is_attacking if player != null else false,
		"is_moving": state_name == "Move" or state_name == "Fly"
	}

	distribute_trigger(TriggerData.TriggerType.ON_STATE_ENTER, current_context)

	match state_name:
		"Fly":
			distribute_trigger(TriggerData.TriggerType.ON_FLY_START, current_context)
		"Move":
			distribute_trigger(TriggerData.TriggerType.ON_MOVE_START, current_context)
		"Idle":
			if player.was_flying:
				distribute_trigger(TriggerData.TriggerType.ON_FLY_END, current_context)
			distribute_trigger(TriggerData.TriggerType.ON_MOVE_STOP, current_context)

func _on_took_damage(damage: float, source: Node2D) -> void:
	current_context = {
		"damage": damage,
		"source": source,
		"player": player,
		"position": player.global_position,
		"is_attacking": player.is_attacking if player != null else false,
		"is_moving": player.velocity.length_squared() > 100 if player != null else false
	}
	distribute_trigger(TriggerData.TriggerType.ON_TAKE_DAMAGE, current_context)

func _on_health_changed(current: float, maximum: float) -> void:
	var ratio = current / maximum if maximum > 0 else 0

	current_context = {
		"current_health": current,
		"max_health": maximum,
		"health_ratio": ratio,
		"player": player,
		"position": player.global_position,
		"is_attacking": player.is_attacking if player != null else false,
		"is_moving": player.velocity.length_squared() > 100 if player != null else false
	}

	if ratio < 0.3:
		distribute_trigger(TriggerData.TriggerType.ON_HEALTH_LOW, current_context)

func _on_spell_cast(spell: SpellCoreData) -> void:
	current_context = {
		"spell": spell,
		"player": player,
		"position": player.global_position,
		"is_attacking": player.is_attacking if player != null else false,
		"is_moving": player.velocity.length_squared() > 100 if player != null else false
	}
	distribute_trigger(TriggerData.TriggerType.ON_SPELL_CAST, current_context)

func _on_spell_hit(target: Node2D, damage: float) -> void:
	current_context = {
		"target": target,
		"damage": damage,
		"player": player,
		"position": player.global_position,
		"is_attacking": player.is_attacking if player != null else false,
		"is_moving": player.velocity.length_squared() > 100 if player != null else false
	}

	if player.current_spell != null:
		proficiency_manager.record_spell_hit(player.current_spell.spell_id)

func _on_weapon_changed(_weapon: WeaponData) -> void:
	_register_all_slots()
