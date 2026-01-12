class_name DisplacementSystem
extends Node

signal displacement_started(target: Node, displacement_data: DisplacementActionData)
signal displacement_ended(target: Node)
signal displacement_collision(target: Node, collider: Node, damage: float)
signal target_stunned(target: Node, duration: float)

var active_displacements: Dictionary = {}

class DisplacementInstance:
	var data: DisplacementActionData
	var target: Node
	var start_position: Vector2
	var direction: Vector2
	var elapsed_time: float = 0.0
	var velocity: Vector2 = Vector2.ZERO
	var has_collided: bool = false

	func _init(disp_data: DisplacementActionData, target_node: Node, dir: Vector2):
		data = disp_data
		target = target_node
		start_position = target_node.global_position
		direction = dir.normalized()

func _physics_process(delta: float) -> void:
	_update_all_displacements(delta)

func _update_all_displacements(delta: float) -> void:
	var to_remove: Array = []

	for target_id in active_displacements:
		var instance: DisplacementInstance = active_displacements[target_id]
		var target = instance.target

		if target == null or not is_instance_valid(target):
			to_remove.append(target_id)
			continue

		instance.elapsed_time += delta

		if instance.elapsed_time >= instance.data.displacement_duration:
			_end_displacement(target, instance)
			to_remove.append(target_id)
			continue

		_apply_displacement(instance, delta)

	for target_id in to_remove:
		active_displacements.erase(target_id)

func apply_displacement(target: Node, displacement_data: DisplacementActionData, source_position: Vector2) -> void:
	if target == null or not is_instance_valid(target):
		return

	var target_id = target.get_instance_id()

	if active_displacements.has(target_id):
		return

	var direction = _calculate_displacement_direction(target, displacement_data, source_position)

	var instance = DisplacementInstance.new(displacement_data, target, direction)

	match displacement_data.displacement_type:
		DisplacementActionData.DisplacementType.KNOCKBACK:
			instance.velocity = direction * displacement_data.displacement_force
		DisplacementActionData.DisplacementType.PULL:
			instance.velocity = -direction * displacement_data.displacement_force
		DisplacementActionData.DisplacementType.TELEPORT:
			_teleport_target(target, displacement_data, source_position)
			_apply_stun_if_needed(target, displacement_data)
			return
		DisplacementActionData.DisplacementType.LAUNCH:
			instance.velocity = Vector2(direction.x * displacement_data.displacement_force * 0.3,
			                            -displacement_data.displacement_force)

	active_displacements[target_id] = instance

	if target.has_method("set_movement_disabled"):
		target.set_movement_disabled(true)

	displacement_started.emit(target, displacement_data)

func _calculate_displacement_direction(target: Node, displacement_data: DisplacementActionData, source_position: Vector2) -> Vector2:
	match displacement_data.displacement_type:
		DisplacementActionData.DisplacementType.KNOCKBACK:
			return (target.global_position - source_position).normalized()
		DisplacementActionData.DisplacementType.PULL:
			return (source_position - target.global_position).normalized()
		DisplacementActionData.DisplacementType.TELEPORT:
			return Vector2.ZERO
		DisplacementActionData.DisplacementType.LAUNCH:
			var horizontal = (target.global_position - source_position).normalized()
			return horizontal

	return Vector2.RIGHT

func _apply_displacement(instance: DisplacementInstance, delta: float) -> void:
	var target = instance.target
	var data = instance.data

	match data.displacement_type:
		DisplacementActionData.DisplacementType.KNOCKBACK, DisplacementActionData.DisplacementType.PULL:
			var progress = instance.elapsed_time / data.displacement_duration
			var deceleration = 1.0 - progress
			var current_velocity = instance.velocity * deceleration

			var new_position = target.global_position + current_velocity * delta

			if _check_collision(target, new_position) and not instance.has_collided:
				instance.has_collided = true
				_handle_collision(instance)
			else:
				target.global_position = new_position

		DisplacementActionData.DisplacementType.LAUNCH:
			var gravity = 800.0
			instance.velocity.y += gravity * delta

			var new_position = target.global_position + instance.velocity * delta

			if new_position.y >= instance.start_position.y:
				new_position.y = instance.start_position.y
				instance.elapsed_time = data.displacement_duration

				if data.damage_on_collision > 0:
					_apply_landing_damage(target, data.damage_on_collision)

			target.global_position = new_position

func _teleport_target(target: Node, displacement_data: DisplacementActionData, source_position: Vector2) -> void:
	var teleport_distance = displacement_data.displacement_force * 0.5
	var direction = (target.global_position - source_position).normalized()

	var teleport_position = target.global_position + direction * teleport_distance

	if not _is_position_valid(teleport_position):
		teleport_position = _find_nearest_valid_position(target.global_position, teleport_position)

	_play_teleport_effect(target.global_position, teleport_position)

	target.global_position = teleport_position

func _check_collision(target: Node, new_position: Vector2) -> bool:
	var space_state = target.get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(target.global_position, new_position)
	query.exclude = [target]
	query.collision_mask = 1

	var result = space_state.intersect_ray(query)
	return not result.is_empty()

func _handle_collision(instance: DisplacementInstance) -> void:
	var target = instance.target
	var data = instance.data

	instance.velocity = Vector2.ZERO

	if data.damage_on_collision > 0 and target.has_method("take_damage"):
		target.take_damage(data.damage_on_collision)
		displacement_collision.emit(target, null, data.damage_on_collision)

func _apply_landing_damage(target: Node, damage: float) -> void:
	if target.has_method("take_damage"):
		target.take_damage(damage)
		displacement_collision.emit(target, null, damage)

func _end_displacement(target: Node, instance: DisplacementInstance) -> void:
	if target.has_method("set_movement_disabled"):
		target.set_movement_disabled(false)

	_apply_stun_if_needed(target, instance.data)

	displacement_ended.emit(target)

func _apply_stun_if_needed(target: Node, displacement_data: DisplacementActionData) -> void:
	if displacement_data.stun_after_displacement > 0:
		if target.has_method("apply_stun"):
			target.apply_stun(displacement_data.stun_after_displacement)
		target_stunned.emit(target, displacement_data.stun_after_displacement)

func _is_position_valid(position: Vector2) -> bool:
	return true

func _find_nearest_valid_position(from: Vector2, to: Vector2) -> Vector2:
	return from.lerp(to, 0.5)

func _play_teleport_effect(from: Vector2, to: Vector2) -> void:
	pass

func is_being_displaced(target: Node) -> bool:
	return active_displacements.has(target.get_instance_id())

func interrupt_displacement(target: Node) -> void:
	var target_id = target.get_instance_id()
	if active_displacements.has(target_id):
		var instance: DisplacementInstance = active_displacements[target_id]

		if target.has_method("set_movement_disabled"):
			target.set_movement_disabled(false)

		active_displacements.erase(target_id)
		displacement_ended.emit(target)
