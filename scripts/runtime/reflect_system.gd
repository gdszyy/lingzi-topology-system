class_name ReflectSystem
extends Node

signal reflect_activated(target: Node, reflect_data: ReflectActionData)
signal projectile_reflected(target: Node, projectile: Node, damage_bonus: float)
signal damage_reflected(target: Node, source: Node, reflected_damage: float)
signal reflect_expired(target: Node)
signal reflect_depleted(target: Node)

var active_reflects: Dictionary = {}

class ReflectInstance:
	var data: ReflectActionData
	var remaining_duration: float
	var remaining_reflects: int
	var target: Node
	var reflect_visual: Node2D

	func _init(reflect_data: ReflectActionData, target_node: Node):
		data = reflect_data
		remaining_duration = reflect_data.reflect_duration
		remaining_reflects = reflect_data.max_reflects
		target = target_node

func _process(delta: float) -> void:
	_update_all_reflects(delta)

func _update_all_reflects(delta: float) -> void:
	var to_remove: Array = []

	for target_id in active_reflects:
		var instance: ReflectInstance = active_reflects[target_id]
		var target = instance.target

		if target == null or not is_instance_valid(target):
			to_remove.append(target_id)
			continue

		instance.remaining_duration -= delta

		if instance.remaining_duration <= 0:
			_expire_reflect(target)
			to_remove.append(target_id)
			continue

		_update_reflect_visual(instance)

	for target_id in to_remove:
		active_reflects.erase(target_id)

func activate_reflect(target: Node, reflect_data: ReflectActionData) -> void:
	if target == null or not is_instance_valid(target):
		return

	var target_id = target.get_instance_id()

	if active_reflects.has(target_id):
		var existing: ReflectInstance = active_reflects[target_id]
		existing.remaining_duration = maxf(existing.remaining_duration, reflect_data.reflect_duration)
		existing.remaining_reflects = maxi(existing.remaining_reflects, reflect_data.max_reflects)
		return

	var instance = ReflectInstance.new(reflect_data, target)
	instance.reflect_visual = _create_reflect_visual(target, reflect_data)
	active_reflects[target_id] = instance

	reflect_activated.emit(target, reflect_data)

func try_reflect_projectile(target: Node, projectile: Node) -> bool:
	var target_id = target.get_instance_id()

	if not active_reflects.has(target_id):
		return false

	var instance: ReflectInstance = active_reflects[target_id]

	if instance.data.reflect_type != ReflectActionData.ReflectType.PROJECTILE and \
	   instance.data.reflect_type != ReflectActionData.ReflectType.BOTH:
		return false

	if instance.remaining_reflects <= 0:
		return false

	instance.remaining_reflects -= 1
	var damage_bonus = instance.data.reflect_damage_ratio
	_reflect_projectile(projectile, target, damage_bonus)

	projectile_reflected.emit(target, projectile, damage_bonus)

	if instance.remaining_reflects <= 0:
		reflect_depleted.emit(target)
		_expire_reflect(target)
		active_reflects.erase(target_id)

	return true

func try_reflect_damage(target: Node, source: Node, damage: float) -> float:
	var target_id = target.get_instance_id()

	if not active_reflects.has(target_id):
		return 0.0

	var instance: ReflectInstance = active_reflects[target_id]

	if instance.data.reflect_type != ReflectActionData.ReflectType.DAMAGE and \
	   instance.data.reflect_type != ReflectActionData.ReflectType.BOTH:
		return 0.0

	if instance.remaining_reflects <= 0:
		return 0.0

	var reflected_damage = damage * instance.data.reflect_damage_ratio

	if source != null and is_instance_valid(source) and source.has_method("take_damage"):
		source.take_damage(reflected_damage)

	instance.remaining_reflects -= 1
	damage_reflected.emit(target, source, reflected_damage)

	if instance.remaining_reflects <= 0:
		reflect_depleted.emit(target)
		_expire_reflect(target)
		active_reflects.erase(target_id)

	return reflected_damage

func _reflect_projectile(projectile: Node, reflector: Node, damage_bonus: float) -> void:
	if not is_instance_valid(projectile):
		return

	var new_direction = _calculate_reflect_direction(projectile, reflector)

	if projectile.has_method("set_direction"):
		projectile.set_direction(new_direction)
	elif projectile.has_property("velocity"):
		var speed = projectile.velocity.length()
		projectile.velocity = new_direction * speed

	if projectile.has_method("set_owner_faction"):
		var reflector_faction = "player" if reflector.is_in_group("players") else "enemy"
		projectile.set_owner_faction(reflector_faction)

	if projectile.has_method("add_damage_multiplier"):
		projectile.add_damage_multiplier(damage_bonus)
	elif projectile.has_property("damage"):
		projectile.damage *= (1.0 + damage_bonus)

	_play_reflect_effect(reflector.global_position)

func _calculate_reflect_direction(projectile: Node, reflector: Node) -> Vector2:
	var reflector_faction = "player" if reflector.is_in_group("players") else "enemy"
	var target_group = "enemies" if reflector_faction == "player" else "players"

	var nearest_target = _find_nearest_in_group(reflector.global_position, target_group, 500.0)

	if nearest_target != null:
		return (nearest_target.global_position - reflector.global_position).normalized()

	if projectile.has_property("velocity"):
		return -projectile.velocity.normalized()

	return Vector2.RIGHT

func _find_nearest_in_group(position: Vector2, group: String, max_range: float) -> Node:
	var nearest: Node = null
	var nearest_dist = max_range

	for node in get_tree().get_nodes_in_group(group):
		if is_instance_valid(node):
			var dist = node.global_position.distance_to(position)
			if dist < nearest_dist:
				nearest = node
				nearest_dist = dist

	return nearest

func _expire_reflect(target: Node) -> void:
	var target_id = target.get_instance_id()

	if not active_reflects.has(target_id):
		return

	var instance: ReflectInstance = active_reflects[target_id]

	if instance.reflect_visual != null and is_instance_valid(instance.reflect_visual):
		instance.reflect_visual.queue_free()

	reflect_expired.emit(target)

func _create_reflect_visual(target: Node, reflect_data: ReflectActionData) -> Node2D:
	var reflect_visual = Node2D.new()
	reflect_visual.name = "ReflectVisual"

	var reflect_ring = Polygon2D.new()
	reflect_ring.name = "ReflectRing"

	var ring_color: Color
	match reflect_data.reflect_type:
		ReflectActionData.ReflectType.PROJECTILE:
			ring_color = Color(1.0, 0.8, 0.2, 0.5)
		ReflectActionData.ReflectType.DAMAGE:
			ring_color = Color(1.0, 0.3, 0.3, 0.5)
		ReflectActionData.ReflectType.BOTH:
			ring_color = Color(0.8, 0.2, 1.0, 0.5)

	reflect_ring.color = ring_color

	var inner_radius = 25.0
	var outer_radius = 35.0
	var points: PackedVector2Array = []
	var segments = 32

	for i in range(segments + 1):
		var angle = i * TAU / segments
		points.append(Vector2(cos(angle), sin(angle)) * outer_radius)

	for i in range(segments, -1, -1):
		var angle = i * TAU / segments
		points.append(Vector2(cos(angle), sin(angle)) * inner_radius)

	reflect_ring.polygon = points

	reflect_visual.add_child(reflect_ring)
	target.add_child(reflect_visual)

	return reflect_visual

func _update_reflect_visual(instance: ReflectInstance) -> void:
	if instance.reflect_visual == null or not is_instance_valid(instance.reflect_visual):
		return

	instance.reflect_visual.rotation += 0.02

	var reflect_ring = instance.reflect_visual.get_node_or_null("ReflectRing")
	if reflect_ring != null:
		var ratio = float(instance.remaining_reflects) / float(instance.data.max_reflects)
		reflect_ring.color.a = 0.3 + ratio * 0.4

func _play_reflect_effect(position: Vector2) -> void:
	pass

func has_reflect(target: Node) -> bool:
	return active_reflects.has(target.get_instance_id())

func get_remaining_reflects(target: Node) -> int:
	var target_id = target.get_instance_id()
	if not active_reflects.has(target_id):
		return 0
	return active_reflects[target_id].remaining_reflects

func remove_reflect(target: Node) -> void:
	var target_id = target.get_instance_id()
	if active_reflects.has(target_id):
		_expire_reflect(target)
		active_reflects.erase(target_id)
