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
	if player.has_signal("health_changed"):
		player.health_changed.connect(_on_health_changed)

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
		"position": player.global_position if player != null else Vector2.ZERO
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
	if player != null and player.current_weapon != null:
		var can_use_weapon = _can_use_weapon()
		if can_use_weapon:
			for slot in player.current_weapon.engraving_slots:
				if not slot.can_trigger():
					continue

				if slot.engraved_spell == null:
					continue

				var proficiency = proficiency_manager.get_proficiency_value(slot.engraved_spell.spell_id)

				var started = slot.start_trigger(trigger_type, context, proficiency)

				if started:
					if not slot.spell_triggered.is_connected(_on_slot_spell_triggered):
						slot.spell_triggered.connect(_on_slot_spell_triggered.bind(slot, context))

## 检查是否可以使用武器（需要至少一只手臂功能正常）
func _can_use_weapon() -> bool:
	var right_arm = get_body_part(BodyPartData.PartType.RIGHT_ARM)
	var left_arm = get_body_part(BodyPartData.PartType.LEFT_ARM)
	
	# 双手武器需要两只手臂
	if player.current_weapon != null and player.current_weapon.is_two_handed:
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
	if rule == null or not rule.enabled:
		return

	var full_context = context.duplicate()
	full_context["slot"] = slot
	full_context["slot_level"] = slot.slot_level
	full_context["is_engraved"] = true
	
	# 应用肢体效率修正到效果
	var part_efficiency = context.get("part_efficiency", 1.0)
	full_context["effect_multiplier"] = part_efficiency

	for action in rule.actions:
		if action != null:
			action_executor.execute_action(action, full_context)
			action_executed.emit(action, full_context)

## 对特定肢体造成伤害（二维体素战斗系统核心方法）
## 返回传递到核心的伤害值
func damage_body_part(part_type: BodyPartData.PartType, damage: float) -> float:
	var part = get_body_part(part_type)
	if part == null:
		return damage  # 如果找不到肢体，全部伤害传递到核心
	
	var actual_damage = part.take_damage(damage)
	var core_damage = actual_damage * part.core_damage_ratio
	
	# 记录统计
	var part_key = BodyPartData.PartType.keys()[part_type]
	if not body_part_stats.damage_by_part.has(part_key):
		body_part_stats.damage_by_part[part_key] = 0.0
	body_part_stats.damage_by_part[part_key] += actual_damage
	
	return core_damage

## 治疗特定肢体
func heal_body_part(part_type: BodyPartData.PartType, amount: float) -> float:
	var part = get_body_part(part_type)
	if part == null:
		return 0.0
	
	return part.heal(amount)

## 完全修复所有肢体
func restore_all_body_parts() -> void:
	for part in body_parts:
		part.fully_restore()
	
	# 重新注册所有槽位
	_register_all_slots()

## 肢体受伤回调
func _on_body_part_damage_taken(damage: float, remaining_health: float, part: BodyPartData) -> void:
	body_part_damaged.emit(part, damage, remaining_health)

## 肢体被摧毁回调
func _on_body_part_destroyed(part: BodyPartData) -> void:
	body_part_stats.total_parts_destroyed += 1
	
	# 统计失效的法术数量
	var disabled_spell_count = 0
	for slot in part.engraving_slots:
		if slot.engraved_spell != null:
			disabled_spell_count += 1
	
	body_part_stats.total_spells_disabled += disabled_spell_count
	
	# 重新注册槽位（排除已摧毁肢体的槽位）
	_register_all_slots()
	
	body_part_destroyed.emit(part)
	spells_disabled.emit(part, disabled_spell_count)
	
	print("[二维体素] %s 被摧毁，%d 个法术失效" % [part.part_name, disabled_spell_count])

## 肢体恢复回调
func _on_body_part_restored(part: BodyPartData) -> void:
	body_part_stats.total_parts_restored += 1
	
	# 统计恢复的法术数量
	var enabled_spell_count = 0
	for slot in part.engraving_slots:
		if slot.engraved_spell != null:
			enabled_spell_count += 1
	
	# 重新注册槽位
	_register_all_slots()
	
	body_part_restored.emit(part)
	spells_enabled.emit(part, enabled_spell_count)
	
	print("[二维体素] %s 已恢复，%d 个法术重新生效" % [part.part_name, enabled_spell_count])

## 肢体生命值变化回调
func _on_body_part_health_changed(current: float, maximum: float, part: BodyPartData) -> void:
	# 可以在这里添加UI更新逻辑
	pass

func engrave_to_body_part(part_type: int, slot_index: int, spell: SpellCoreData) -> bool:
	var part = _get_body_part(part_type)
	if part == null:
		push_warning("未找到肢体部件: %d" % part_type)
		return false
	
	# 检查肢体是否功能正常
	if not part.is_functional:
		push_warning("肢体 %s 已被摧毁，无法篆刻法术" % part.part_name)
		return false

	if slot_index < 0 or slot_index >= part.engraving_slots.size():
		push_warning("槽位索引无效: %d" % slot_index)
		return false

	return part.engraving_slots[slot_index].engrave_spell(spell)

func engrave_to_weapon(slot_index: int, spell: SpellCoreData) -> bool:
	if player == null or player.current_weapon == null:
		push_warning("没有装备武器")
		return false

	return player.current_weapon.engrave_spell_to_slot(slot_index, spell)

func remove_from_body_part(part_type: int, slot_index: int) -> SpellCoreData:
	var part = _get_body_part(part_type)
	if part == null:
		return null

	if slot_index < 0 or slot_index >= part.engraving_slots.size():
		return null

	return part.engraving_slots[slot_index].remove_spell()

func remove_from_weapon(slot_index: int) -> SpellCoreData:
	if player == null or player.current_weapon == null:
		return null

	return player.current_weapon.remove_spell_from_slot(slot_index)

func _get_body_part(part_type: int) -> BodyPartData:
	for part in body_parts:
		if part.part_type == part_type:
			return part
	return null

func get_body_parts() -> Array[BodyPartData]:
	return body_parts

func get_body_part(part_type: int) -> BodyPartData:
	return _get_body_part(part_type)

## 获取所有功能正常的肢体
func get_functional_body_parts() -> Array[BodyPartData]:
	var functional_parts: Array[BodyPartData] = []
	for part in body_parts:
		if part.is_functional:
			functional_parts.append(part)
	return functional_parts

## 获取所有已摧毁的肢体
func get_destroyed_body_parts() -> Array[BodyPartData]:
	var destroyed_parts: Array[BodyPartData] = []
	for part in body_parts:
		if not part.is_functional:
			destroyed_parts.append(part)
	return destroyed_parts

func get_all_engraved_spells() -> Array[SpellCoreData]:
	var spells: Array[SpellCoreData] = []

	for part in body_parts:
		# 只返回功能正常的肢体上的法术
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
		"position": player.global_position
	}
	distribute_trigger(TriggerData.TriggerType.ON_ATTACK_START, current_context)

func _on_attack_hit(target: Node2D, damage: float) -> void:
	current_context = {
		"target": target,
		"damage": damage,
		"player": player,
		"position": player.global_position,
		"target_position": target.global_position if target != null else Vector2.ZERO
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
		"position": player.global_position
	}
	distribute_trigger(TriggerData.TriggerType.ON_ATTACK_END, current_context)

func _on_state_changed(state_name: String) -> void:
	current_context = {
		"state_name": state_name,
		"player": player,
		"position": player.global_position
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
		"position": player.global_position
	}
	distribute_trigger(TriggerData.TriggerType.ON_TAKE_DAMAGE, current_context)

func _on_health_changed(current: float, maximum: float) -> void:
	var ratio = current / maximum if maximum > 0 else 0

	current_context = {
		"current_health": current,
		"max_health": maximum,
		"health_ratio": ratio,
		"player": player,
		"position": player.global_position
	}

	if ratio < 0.3:
		distribute_trigger(TriggerData.TriggerType.ON_HEALTH_LOW, current_context)

func _on_spell_cast(spell: SpellCoreData) -> void:
	current_context = {
		"spell": spell,
		"player": player,
		"position": player.global_position
	}
	distribute_trigger(TriggerData.TriggerType.ON_SPELL_CAST, current_context)

func _on_spell_hit(target: Node2D, damage: float) -> void:
	current_context = {
		"target": target,
		"damage": damage,
		"player": player,
		"position": player.global_position
	}

	if player.current_spell != null:
		proficiency_manager.record_spell_hit(player.current_spell.spell_id)

func _on_weapon_changed(_weapon: WeaponData) -> void:
	_register_all_slots()
