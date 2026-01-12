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

	# 视觉闪烁效果
	var visual = summon.get_node_or_null("Visual")
	if visual != null:
		var flash = sin(Time.get_ticks_msec() * 0.005) * 0.3 + 0.7
		visual.modulate.a = flash
	
	# 仇恨吸引：让范围内敌人将目标设为诱饵
	var enemies = _find_enemies_in_range(summon.global_position, data.aggro_radius)
	for enemy in enemies:
		if enemy.has_method("set_target"):
			enemy.set_target(summon)
		elif enemy.has_method("set_aggro_target"):
			enemy.set_aggro_target(summon)
		elif "current_target" in enemy:
			enemy.current_target = summon

func _update_barrier_behavior(instance: SummonInstance, delta: float) -> void:
	var summon = instance.summon_node
	var data = instance.data
	
	# 屏障阻挡逻辑：检测并阻挡进入区域的敌方弹道
	var projectiles = get_tree().get_nodes_in_group("enemy_projectiles")
	for proj in projectiles:
		if not is_instance_valid(proj):
			continue
		
		# 检查弹道是否在屏障范围内
		var distance = proj.global_position.distance_to(summon.global_position)
		if distance < 35.0:  # 屏障的有效阻挡范围
			# 尝试反弹
			if proj.has_method("reflect"):
				var reflect_dir = (proj.global_position - summon.global_position).normalized()
				proj.reflect(reflect_dir)
			else:
				# 直接销毁弹道
				proj.queue_free()
			
			# 屏障受到伤害
			var proj_damage = 10.0  # 默认弹道伤害
			if "damage" in proj:
				proj_damage = proj.damage
			instance.current_health -= proj_damage * 0.5  # 屏障只受一半伤害
	
	# 屏障也可以阻挡敌人移动（推开效果）
	var enemies = _find_enemies_in_range(summon.global_position, 40.0)
	for enemy in enemies:
		if enemy.has_method("apply_knockback"):
			var push_dir = (enemy.global_position - summon.global_position).normalized()
			enemy.apply_knockback(push_dir * 50.0 * delta)

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
	# 死亡爆炸特效
	var death_vfx = _create_death_vfx(position)
	if death_vfx:
		get_tree().current_scene.add_child(death_vfx)

func _play_expire_effect(position: Vector2) -> void:
	# 过期消散特效
	var expire_vfx = _create_expire_vfx(position)
	if expire_vfx:
		get_tree().current_scene.add_child(expire_vfx)

func _create_death_vfx(position: Vector2) -> Node2D:
	var container = Node2D.new()
	container.global_position = position
	
	# 爆炸粒子
	var particles = GPUParticles2D.new()
	particles.amount = 20
	particles.lifetime = 0.5
	particles.one_shot = true
	particles.explosiveness = 1.0
	
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, -1, 0)
	material.spread = 180.0
	material.initial_velocity_min = 80.0
	material.initial_velocity_max = 150.0
	material.gravity = Vector3(0, 200, 0)
	material.scale_min = 0.3
	material.scale_max = 0.6
	material.color = Color(1.0, 0.4, 0.2, 1.0)  # 橙红色爆炸
	
	particles.process_material = material
	particles.emitting = true
	container.add_child(particles)
	
	# 自动清理
	var timer = get_tree().create_timer(1.0)
	timer.timeout.connect(func(): container.queue_free())
	
	return container

func _create_expire_vfx(position: Vector2) -> Node2D:
	var container = Node2D.new()
	container.global_position = position
	
	# 消散粒子（更柔和）
	var particles = GPUParticles2D.new()
	particles.amount = 15
	particles.lifetime = 0.8
	particles.one_shot = true
	particles.explosiveness = 0.8
	
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, -1, 0)
	material.spread = 60.0
	material.initial_velocity_min = 30.0
	material.initial_velocity_max = 60.0
	material.gravity = Vector3(0, -30, 0)  # 向上飘散
	material.scale_min = 0.2
	material.scale_max = 0.4
	material.color = Color(0.6, 0.8, 1.0, 0.8)  # 淡蓝色消散
	
	particles.process_material = material
	particles.emitting = true
	container.add_child(particles)
	
	# 自动清理
	var timer = get_tree().create_timer(1.5)
	timer.timeout.connect(func(): container.queue_free())
	
	return container

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
