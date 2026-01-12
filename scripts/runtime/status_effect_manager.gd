class_name StatusEffectManager
extends Node

signal status_applied(target: Node, status_data: ApplyStatusActionData)
signal status_removed(target: Node, status_type: ApplyStatusActionData.StatusType)
signal status_ticked(target: Node, status_type: ApplyStatusActionData.StatusType, damage: float)
signal phase_counter_triggered(target: Node, attacker_phase: ApplyStatusActionData.SpiritonPhase, target_phase: ApplyStatusActionData.SpiritonPhase)

var active_effects: Dictionary = {}

class StatusInstance:
	var data: ApplyStatusActionData
	var remaining_duration: float
	var stacks: int = 1
	var tick_timer: float = 0.0
	var target: Node

	func _init(status_data: ApplyStatusActionData, target_node: Node):
		data = status_data
		remaining_duration = status_data.duration
		target = target_node

func _process(delta: float) -> void:
	_update_all_effects(delta)

func _update_all_effects(delta: float) -> void:
	var to_remove: Array = []

	for target_id in active_effects:
		var target_effects = active_effects[target_id]
		var target_node = instance_from_id(target_id) if target_id is int else null

		if target_node == null or not is_instance_valid(target_node):
			to_remove.append(target_id)
			continue

		var effects_to_remove: Array = []

		for status_type in target_effects:
			var instance: StatusInstance = target_effects[status_type]
			instance.remaining_duration -= delta

			if instance.remaining_duration <= 0:
				effects_to_remove.append(status_type)
				continue

			instance.tick_timer += delta
			if instance.tick_timer >= instance.data.tick_interval:
				instance.tick_timer = 0.0
				_apply_tick_effect(instance)

		for status_type in effects_to_remove:
			_remove_effect(target_node, status_type)

	for target_id in to_remove:
		active_effects.erase(target_id)

func apply_status(target: Node, status_data: ApplyStatusActionData) -> void:
	if target == null or not is_instance_valid(target):
		return

	var target_id = target.get_instance_id()

	if not active_effects.has(target_id):
		active_effects[target_id] = {}

	var target_effects = active_effects[target_id]
	var status_type = status_data.status_type

	var target_phase = _get_target_dominant_phase(target)
	if status_data.is_counter_phase(target_phase):
		phase_counter_triggered.emit(target, status_data.spiriton_phase, target_phase)

	if target_effects.has(status_type):
		var existing: StatusInstance = target_effects[status_type]

		if status_data.refresh_on_apply:
			existing.remaining_duration = status_data.duration

		if existing.stacks < status_data.stack_limit:
			existing.stacks += 1
	else:
		var instance = StatusInstance.new(status_data, target)
		target_effects[status_type] = instance
		_apply_initial_effect(instance)

	status_applied.emit(target, status_data)

func _remove_effect(target: Node, status_type: ApplyStatusActionData.StatusType) -> void:
	var target_id = target.get_instance_id()

	if not active_effects.has(target_id):
		return

	var target_effects = active_effects[target_id]

	if target_effects.has(status_type):
		var instance: StatusInstance = target_effects[status_type]
		_remove_effect_modifiers(instance)
		target_effects.erase(status_type)
		status_removed.emit(target, status_type)

func _apply_initial_effect(instance: StatusInstance) -> void:
	var target = instance.target
	var data = instance.data

	match data.status_type:
		ApplyStatusActionData.StatusType.CRYO_CRYSTAL:
			if target.has_method("set_frozen"):
				target.set_frozen(true)
			if target.has_method("modify_defense"):
				target.modify_defense(-data.effect_value * 0.5)

		ApplyStatusActionData.StatusType.STRUCTURE_LOCK:
			if target.has_method("set_movement_locked"):
				target.set_movement_locked(true)

		ApplyStatusActionData.StatusType.PHASE_DISRUPTION:
			if target.has_method("modify_accuracy"):
				target.modify_accuracy(-data.effect_value * 0.3)
			if target.has_method("modify_evasion"):
				target.modify_evasion(-data.effect_value * 0.3)

		ApplyStatusActionData.StatusType.RESONANCE_MARK:
			if target.has_method("modify_damage_taken"):
				target.modify_damage_taken(data.effect_value * 0.25)

		ApplyStatusActionData.StatusType.SPIRITON_SURGE:
			if target.has_method("modify_damage_output"):
				target.modify_damage_output(data.effect_value * 0.2)

		ApplyStatusActionData.StatusType.PHASE_SHIFT:
			if target.has_method("modify_move_speed"):
				target.modify_move_speed(data.effect_value * 0.3)

		ApplyStatusActionData.StatusType.SOLID_SHELL:
			if target.has_method("add_shield"):
				target.add_shield(data.effect_value * 10)

func _apply_tick_effect(instance: StatusInstance) -> void:
	var target = instance.target
	var data = instance.data
	var stacks = instance.stacks

	var target_phase = _get_target_dominant_phase(target)
	var effective_value = data.calculate_effective_value(target_phase) * stacks

	match data.status_type:
		ApplyStatusActionData.StatusType.ENTROPY_BURN:
			if target.has_method("take_damage"):
				target.take_damage(effective_value)
				status_ticked.emit(target, data.status_type, effective_value)

		ApplyStatusActionData.StatusType.SPIRITON_EROSION:
			if target.has_method("take_damage"):
				target.take_damage(effective_value * 0.6)
				status_ticked.emit(target, data.status_type, effective_value * 0.6)

		ApplyStatusActionData.StatusType.CRYO_CRYSTAL:
			pass

func _remove_effect_modifiers(instance: StatusInstance) -> void:
	var target = instance.target
	var data = instance.data

	if not is_instance_valid(target):
		return

	match data.status_type:
		ApplyStatusActionData.StatusType.CRYO_CRYSTAL:
			if target.has_method("set_frozen"):
				target.set_frozen(false)
			if target.has_method("modify_defense"):
				target.modify_defense(data.effect_value * 0.5)

		ApplyStatusActionData.StatusType.STRUCTURE_LOCK:
			if target.has_method("set_movement_locked"):
				target.set_movement_locked(false)

		ApplyStatusActionData.StatusType.PHASE_DISRUPTION:
			if target.has_method("modify_accuracy"):
				target.modify_accuracy(data.effect_value * 0.3)
			if target.has_method("modify_evasion"):
				target.modify_evasion(data.effect_value * 0.3)

		ApplyStatusActionData.StatusType.RESONANCE_MARK:
			if target.has_method("modify_damage_taken"):
				target.modify_damage_taken(-data.effect_value * 0.25)

		ApplyStatusActionData.StatusType.SPIRITON_SURGE:
			if target.has_method("modify_damage_output"):
				target.modify_damage_output(-data.effect_value * 0.2)

		ApplyStatusActionData.StatusType.PHASE_SHIFT:
			if target.has_method("modify_move_speed"):
				target.modify_move_speed(-data.effect_value * 0.3)

func _get_target_dominant_phase(target: Node) -> ApplyStatusActionData.SpiritonPhase:
	var target_id = target.get_instance_id()

	if not active_effects.has(target_id):
		return ApplyStatusActionData.SpiritonPhase.WAVE

	var target_effects = active_effects[target_id]

	if target_effects.has(ApplyStatusActionData.StatusType.ENTROPY_BURN):
		return ApplyStatusActionData.SpiritonPhase.PLASMA
	if target_effects.has(ApplyStatusActionData.StatusType.CRYO_CRYSTAL):
		return ApplyStatusActionData.SpiritonPhase.FLUID
	if target_effects.has(ApplyStatusActionData.StatusType.STRUCTURE_LOCK) or \
	   target_effects.has(ApplyStatusActionData.StatusType.SOLID_SHELL):
		return ApplyStatusActionData.SpiritonPhase.SOLID
	if target_effects.has(ApplyStatusActionData.StatusType.SPIRITON_EROSION):
		return ApplyStatusActionData.SpiritonPhase.GAS

	return ApplyStatusActionData.SpiritonPhase.WAVE

func has_status(target: Node, status_type: ApplyStatusActionData.StatusType) -> bool:
	var target_id = target.get_instance_id()
	if not active_effects.has(target_id):
		return false
	return active_effects[target_id].has(status_type)

func get_status_stacks(target: Node, status_type: ApplyStatusActionData.StatusType) -> int:
	var target_id = target.get_instance_id()
	if not active_effects.has(target_id):
		return 0
	if not active_effects[target_id].has(status_type):
		return 0
	return active_effects[target_id][status_type].stacks

func cleanse_status(target: Node, status_type: ApplyStatusActionData.StatusType) -> bool:
	var target_id = target.get_instance_id()
	if not active_effects.has(target_id):
		return false
	if not active_effects[target_id].has(status_type):
		return false

	var instance: StatusInstance = active_effects[target_id][status_type]
	if not instance.data.cleansable:
		return false

	_remove_effect(target, status_type)
	return true

func cleanse_all_debuffs(target: Node) -> int:
	var target_id = target.get_instance_id()
	if not active_effects.has(target_id):
		return 0

	var cleansed_count = 0
	var to_cleanse: Array = []

	for status_type in active_effects[target_id]:
		var instance: StatusInstance = active_effects[target_id][status_type]
		if instance.data.get_status_category() == ApplyStatusActionData.StatusCategory.DEBUFF:
			if instance.data.cleansable:
				to_cleanse.append(status_type)

	for status_type in to_cleanse:
		_remove_effect(target, status_type)
		cleansed_count += 1

	return cleansed_count

func on_target_death(target: Node) -> void:
	var target_id = target.get_instance_id()
	if not active_effects.has(target_id):
		return

	var target_effects = active_effects[target_id]

	for status_type in target_effects:
		var instance: StatusInstance = target_effects[status_type]
		if instance.data.spread_on_death:
			_spread_status_to_nearby(target, instance.data)

	active_effects.erase(target_id)

func _spread_status_to_nearby(source: Node, status_data: ApplyStatusActionData) -> void:
	var nearby_enemies = _find_enemies_in_range(source.global_position, status_data.spread_radius)

	for enemy in nearby_enemies:
		if enemy != source:
			apply_status(enemy, status_data)

func _find_enemies_in_range(position: Vector2, radius: float) -> Array:
	var enemies: Array = []
	var all_enemies = get_tree().get_nodes_in_group("enemies")

	for enemy in all_enemies:
		if is_instance_valid(enemy) and enemy.global_position.distance_to(position) <= radius:
			enemies.append(enemy)

	return enemies
