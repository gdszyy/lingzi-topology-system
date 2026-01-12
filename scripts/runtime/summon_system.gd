class_name SummonSystem
extends Node

signal summon_created(summon: Node, summon_data: SummonActionData)
signal summon_attacked(summon: Node, target: Node, damage: float)
signal summon_died(summon: Node, death_position: Vector2)
signal summon_expired(summon: Node)

var active_summons: Dictionary = {}

class SummonInstance:
	var data: SummonActionData
	var summon_node: Node2D
	var owner: Node
	var remaining_duration: float
	var current_health: float
	var attack_timer: float = 0.0
	var current_target: Node = null

	func _init(summon_data: SummonActionData, owner_node: Node):
		data = summon_data
		owner = owner_node
		remaining_duration = summon_data.summon_duration
		current_health = summon_data.summon_health

func _process(delta: float) -> void:
	_update_all_summons(delta)

func _update_all_summons(delta: float) -> void:
	var to_remove: Array = []

	for summon_id in active_summons:
		var instance: SummonInstance = active_summons[summon_id]
		var summon = instance.summon_node

		if summon == null or not is_instance_valid(summon):
			to_remove.append(summon_id)
			continue

		instance.remaining_duration -= delta

		if instance.remaining_duration <= 0:
			_expire_summon(instance)
			to_remove.append(summon_id)
			continue

		_update_summon_behavior(instance, delta)

	for summon_id in to_remove:
		active_summons.erase(summon_id)

func create_summon(summon_data: SummonActionData, spawn_position: Vector2, owner: Node) -> Array[Node2D]:
	var created_summons: Array[Node2D] = []

	for i in range(summon_data.summon_count):
		var offset = _calculate_spawn_offset(i, summon_data.summon_count, summon_data.summon_type)
		var position = spawn_position + offset

		var summon_node = _create_summon_node(summon_data, position)

		var instance = SummonInstance.new(summon_data, owner)
		instance.summon_node = summon_node

		active_summons[summon_node.get_instance_id()] = instance
		created_summons.append(summon_node)

		summon_created.emit(summon_node, summon_data)

	return created_summons

func _calculate_spawn_offset(index: int, total: int, summon_type: SummonActionData.SummonType) -> Vector2:
	match summon_type:
		SummonActionData.SummonType.ORBITER:
			var angle = index * TAU / total
			return Vector2(cos(angle), sin(angle)) * 50.0

		SummonActionData.SummonType.BARRIER:
			var spacing = 40.0
			var start_offset = -(total - 1) * spacing / 2
			return Vector2(start_offset + index * spacing, 0)

		_:
			var angle = randf() * TAU
			var distance = randf_range(30.0, 60.0)
			return Vector2(cos(angle), sin(angle)) * distance

func _create_summon_node(summon_data: SummonActionData, position: Vector2) -> Node2D:
	var summon = Area2D.new()
	summon.name = "Summon_" + SummonActionData.SummonType.keys()[summon_data.summon_type]
	summon.global_position = position
	summon.add_to_group("summons")
	summon.add_to_group("player_summons")

	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 15.0
	collision.shape = shape
	summon.add_child(collision)

	var visual = _create_summon_visual(summon_data)
	summon.add_child(visual)

	get_tree().current_scene.add_child(summon)

	return summon

func _create_summon_visual(summon_data: SummonActionData) -> Node2D:
	var visual = Polygon2D.new()
	visual.name = "Visual"

	var color: Color
	var points: PackedVector2Array

	match summon_data.summon_type:
		SummonActionData.SummonType.TURRET:
			color = Color(0.8, 0.6, 0.2)
			points = _create_square_points(12.0)

		SummonActionData.SummonType.MINION:
			color = Color(0.4, 0.8, 0.4)
			points = _create_circle_points(10.0, 8)

		SummonActionData.SummonType.ORBITER:
			color = Color(0.6, 0.6, 1.0)
			points = _create_circle_points(8.0, 6)

		SummonActionData.SummonType.DECOY:
			color = Color(1.0, 0.8, 0.4)
			points = _create_circle_points(15.0, 12)

		SummonActionData.SummonType.BARRIER:
			color = Color(0.4, 0.4, 0.8)
			points = _create_rectangle_points(8.0, 25.0)

		SummonActionData.SummonType.TOTEM:
			color = Color(0.8, 0.4, 0.8)
			points = _create_triangle_points(12.0)

	visual.polygon = points
	visual.color = color

	return visual

func _create_circle_points(radius: float, segments: int) -> PackedVector2Array:
	var points: PackedVector2Array = []
	for i in range(segments):
		var angle = i * TAU / segments
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points

func _create_square_points(size: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-size, -size),
		Vector2(size, -size),
		Vector2(size, size),
		Vector2(-size, size)
	])

func _create_rectangle_points(width: float, height: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-width, -height),
		Vector2(width, -height),
		Vector2(width, height),
		Vector2(-width, height)
	])

func _create_triangle_points(size: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0, -size),
		Vector2(size * 0.866, size * 0.5),
		Vector2(-size * 0.866, size * 0.5)
	])

func _update_summon_behavior(instance: SummonInstance, delta: float) -> void:
	var summon = instance.summon_node
	var data = instance.data

	match data.summon_type:
		SummonActionData.SummonType.TURRET:
			_update_turret_behavior(instance, delta)

		SummonActionData.SummonType.MINION:
			_update_minion_behavior(instance, delta)

		SummonActionData.SummonType.ORBITER:
			_update_orbiter_behavior(instance, delta)

		SummonActionData.SummonType.DECOY:
			_update_decoy_behavior(instance, delta)

		SummonActionData.SummonType.BARRIER:
			_update_barrier_behavior(instance, delta)

		SummonActionData.SummonType.TOTEM:
			_update_totem_behavior(instance, delta)

func _update_turret_behavior(instance: SummonInstance, delta: float) -> void:
	var summon = instance.summon_node
	var data = instance.data

	instance.attack_timer += delta

	if instance.attack_timer >= data.summon_attack_interval:
		instance.attack_timer = 0.0

		var target = _find_nearest_enemy(summon.global_position, data.summon_attack_range)

		if target != null:
			_perform_attack(instance, target)

func _update_minion_behavior(instance: SummonInstance, delta: float) -> void:
	var summon = instance.summon_node
	var data = instance.data

	if instance.current_target == null or not is_instance_valid(instance.current_target):
		instance.current_target = _find_nearest_enemy(summon.global_position, data.summon_attack_range * 2)

	if instance.current_target != null:
		var direction = (instance.current_target.global_position - summon.global_position).normalized()
		summon.global_position += direction * data.summon_move_speed * delta

		var distance = summon.global_position.distance_to(instance.current_target.global_position)
		if distance <= 30.0:
			instance.attack_timer += delta
			if instance.attack_timer >= data.summon_attack_interval:
				instance.attack_timer = 0.0
				_perform_attack(instance, instance.current_target)

func _update_orbiter_behavior(instance: SummonInstance, delta: float) -> void:
	var summon = instance.summon_node
	var data = instance.data
	var owner = instance.owner

	if owner == null or not is_instance_valid(owner):
		return

	var elapsed = data.summon_duration - instance.remaining_duration
	var angle = elapsed * data.orbit_speed
	var offset = Vector2(cos(angle), sin(angle)) * data.orbit_radius

	summon.global_position = owner.global_position + offset

	var nearby_enemy = _find_nearest_enemy(summon.global_position, 20.0)
	if nearby_enemy != null:
		instance.attack_timer += delta
		if instance.attack_timer >= 0.5:
			instance.attack_timer = 0.0
			_perform_attack(instance, nearby_enemy)

func _update_decoy_behavior(instance: SummonInstance, delta: float) -> void:
	var summon = instance.summon_node
	var data = instance.data

	var visual = summon.get_node_or_null("Visual")
	if visual != null:
		var flash = sin(Time.get_ticks_msec() * 0.005) * 0.3 + 0.7
		visual.modulate.a = flash

func _update_barrier_behavior(instance: SummonInstance, delta: float) -> void:
	pass

func _update_totem_behavior(instance: SummonInstance, delta: float) -> void:
	var summon = instance.summon_node
	var data = instance.data

	instance.attack_timer += delta

	if instance.attack_timer >= data.summon_attack_interval:
		instance.attack_timer = 0.0

		var enemies = _find_enemies_in_range(summon.global_position, data.totem_effect_radius)
		for enemy in enemies:
			_perform_attack(instance, enemy)

func _perform_attack(instance: SummonInstance, target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return

	var damage = instance.data.summon_damage

	if target.has_method("take_damage"):
		target.take_damage(damage)
		summon_attacked.emit(instance.summon_node, target, damage)

func damage_summon(summon: Node, damage: float) -> void:
	var summon_id = summon.get_instance_id()

	if not active_summons.has(summon_id):
		return

	var instance: SummonInstance = active_summons[summon_id]
	instance.current_health -= damage

	if instance.current_health <= 0:
		_kill_summon(instance)
		active_summons.erase(summon_id)

func _kill_summon(instance: SummonInstance) -> void:
	var summon = instance.summon_node
	var death_position = summon.global_position

	_play_death_effect(death_position)

	summon.queue_free()

	summon_died.emit(summon, death_position)

func _expire_summon(instance: SummonInstance) -> void:
	var summon = instance.summon_node

	_play_expire_effect(summon.global_position)

	summon.queue_free()

	summon_expired.emit(summon)

func _play_death_effect(position: Vector2) -> void:
	pass

func _play_expire_effect(position: Vector2) -> void:
	pass

func _find_nearest_enemy(position: Vector2, max_range: float) -> Node:
	var nearest: Node = null
	var nearest_dist = max_range

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			var dist = enemy.global_position.distance_to(position)
			if dist < nearest_dist:
				nearest = enemy
				nearest_dist = dist

	return nearest

func _find_enemies_in_range(position: Vector2, radius: float) -> Array:
	var enemies: Array = []

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			if enemy.global_position.distance_to(position) <= radius:
				enemies.append(enemy)

	return enemies

func get_active_summon_count() -> int:
	return active_summons.size()

func get_summons_by_owner(owner: Node) -> Array[Node2D]:
	var summons: Array[Node2D] = []

	for summon_id in active_summons:
		var instance: SummonInstance = active_summons[summon_id]
		if instance.owner == owner:
			summons.append(instance.summon_node)

	return summons

func remove_summons_by_owner(owner: Node) -> void:
	var to_remove: Array = []

	for summon_id in active_summons:
		var instance: SummonInstance = active_summons[summon_id]
		if instance.owner == owner:
			_expire_summon(instance)
			to_remove.append(summon_id)

	for summon_id in to_remove:
		active_summons.erase(summon_id)
