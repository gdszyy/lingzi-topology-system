class_name ShieldSystem
extends Node

signal shield_created(target: Node, shield_instance: ShieldInstance)
signal shield_damaged(target: Node, damage: float, remaining: float)
signal shield_broken(target: Node, overkill_damage: float)
signal shield_expired(target: Node)
signal shield_reflected(target: Node, projectile: Node)

var active_shields: Dictionary = {}

class ShieldInstance:
	var data: ShieldActionData
	var current_amount: float
	var remaining_duration: float
	var target: Node
	var shield_node: Node2D
	var shield_vfx: ShieldVFX  # VFX组件
	var reflect_count: int = 0

	func _init(shield_data: ShieldActionData, target_node: Node):
		data = shield_data
		current_amount = shield_data.shield_amount
		remaining_duration = shield_data.shield_duration
		target = target_node

func _process(delta: float) -> void:
	_update_all_shields(delta)

func _update_all_shields(delta: float) -> void:
	var to_remove: Array = []

	for target_id in active_shields:
		var instance: ShieldInstance = active_shields[target_id]
		var target = instance.target

		if target == null or not is_instance_valid(target):
			to_remove.append(target_id)
			continue

		instance.remaining_duration -= delta

		if instance.remaining_duration <= 0:
			_expire_shield(target)
			to_remove.append(target_id)
			continue

		_update_shield_visual(instance)

	for target_id in to_remove:
		active_shields.erase(target_id)

func create_shield(target: Node, shield_data: ShieldActionData) -> void:
	if target == null or not is_instance_valid(target):
		return

	var target_id = target.get_instance_id()

	if active_shields.has(target_id):
		var existing: ShieldInstance = active_shields[target_id]

		var max_shield = shield_data.shield_amount * 1.5
		existing.current_amount = minf(existing.current_amount + shield_data.shield_amount * 0.5, max_shield)

		existing.remaining_duration = maxf(existing.remaining_duration, shield_data.shield_duration)
		
		# 刷新VFX
		if existing.shield_vfx and is_instance_valid(existing.shield_vfx):
			existing.shield_vfx.refresh(existing.current_amount, existing.remaining_duration)

		return

	var instance = ShieldInstance.new(shield_data, target)
	instance.shield_node = _create_shield_visual(target, shield_data)
	
	# 创建护盾VFX
	instance.shield_vfx = _create_shield_vfx(target, shield_data)
	
	active_shields[target_id] = instance

	shield_created.emit(target, instance)

## 创建护盾VFX
func _create_shield_vfx(target: Node, shield_data: ShieldActionData) -> ShieldVFX:
	var radius = 30.0 if shield_data.shield_type == ShieldActionData.ShieldType.PERSONAL else shield_data.shield_radius
	
	var shield_vfx = VFXFactory.create_shield_vfx(
		shield_data.shield_type,
		shield_data.shield_amount,
		shield_data.shield_duration,
		radius,
		target
	)
	
	if shield_vfx:
		get_tree().current_scene.add_child(shield_vfx)
	
	return shield_vfx

func damage_shield(target: Node, damage: float) -> float:
	var target_id = target.get_instance_id()

	if not active_shields.has(target_id):
		return damage

	var instance: ShieldInstance = active_shields[target_id]

	var absorbed = minf(damage, instance.current_amount)
	instance.current_amount -= absorbed
	var remaining_damage = damage - absorbed

	shield_damaged.emit(target, absorbed, instance.current_amount)
	
	# 更新VFX受击效果
	if instance.shield_vfx and is_instance_valid(instance.shield_vfx):
		instance.shield_vfx.on_hit(absorbed)

	if instance.current_amount <= 0:
		_break_shield(target, remaining_damage)
		active_shields.erase(target_id)

	return remaining_damage

func try_reflect_projectile(target: Node, projectile: Node) -> bool:
	var target_id = target.get_instance_id()

	if not active_shields.has(target_id):
		return false

	var instance: ShieldInstance = active_shields[target_id]

	if instance.data.shield_type != ShieldActionData.ShieldType.PROJECTILE:
		return false

	if instance.reflect_count >= 3:
		return false

	instance.reflect_count += 1
	_reflect_projectile(projectile, target)
	shield_reflected.emit(target, projectile)
	
	# 播放反弹VFX
	if instance.shield_vfx and is_instance_valid(instance.shield_vfx):
		instance.shield_vfx.on_reflect()

	return true

func _reflect_projectile(projectile: Node, reflector: Node) -> void:
	if not is_instance_valid(projectile):
		return

	if projectile.has_method("reverse_direction"):
		projectile.reverse_direction()
	elif projectile is CharacterBody2D or projectile is RigidBody2D:
		projectile.velocity = -projectile.velocity

	if projectile.has_method("set_owner_faction"):
		projectile.set_owner_faction("player")

	if projectile.has_method("add_damage_multiplier"):
		projectile.add_damage_multiplier(0.5)

func _break_shield(target: Node, overkill_damage: float) -> void:
	var target_id = target.get_instance_id()

	if not active_shields.has(target_id):
		return

	var instance: ShieldInstance = active_shields[target_id]

	if instance.shield_node != null and is_instance_valid(instance.shield_node):
		_play_break_effect(instance.shield_node.global_position)
		instance.shield_node.queue_free()
	
	# 播放护盾破碎VFX
	if instance.shield_vfx and is_instance_valid(instance.shield_vfx):
		instance.shield_vfx.on_break()

	if instance.data.on_break_explode:
		_trigger_break_explosion(target, instance.data)

	shield_broken.emit(target, overkill_damage)

func _expire_shield(target: Node) -> void:
	var target_id = target.get_instance_id()

	if not active_shields.has(target_id):
		return

	var instance: ShieldInstance = active_shields[target_id]

	if instance.shield_node != null and is_instance_valid(instance.shield_node):
		instance.shield_node.queue_free()
	
	# 停止护盾VFX
	if instance.shield_vfx and is_instance_valid(instance.shield_vfx):
		instance.shield_vfx.stop()

	shield_expired.emit(target)

func _trigger_break_explosion(target: Node, shield_data: ShieldActionData) -> void:
	var explosion_pos = target.global_position
	var explosion_radius = shield_data.shield_radius if shield_data.shield_radius > 0 else 100.0
	var explosion_damage = shield_data.break_explosion_damage

	var enemies = _find_enemies_in_range(explosion_pos, explosion_radius)
	for enemy in enemies:
		if enemy != target and enemy.has_method("take_damage"):
			enemy.take_damage(explosion_damage)

	_play_explosion_effect(explosion_pos, explosion_radius)

func _create_shield_visual(target: Node, shield_data: ShieldActionData) -> Node2D:
	var shield_visual = Node2D.new()
	shield_visual.name = "ShieldVisual"

	var shield_shape = Polygon2D.new()
	shield_shape.name = "ShieldShape"

	var shield_color: Color
	match shield_data.shield_type:
		ShieldActionData.ShieldType.PERSONAL:
			shield_color = Color(0.2, 0.6, 1.0, 0.4)
		ShieldActionData.ShieldType.AREA:
			shield_color = Color(0.2, 1.0, 0.6, 0.3)
		ShieldActionData.ShieldType.PROJECTILE:
			shield_color = Color(1.0, 0.8, 0.2, 0.4)

	shield_shape.color = shield_color

	var radius = 30.0 if shield_data.shield_type == ShieldActionData.ShieldType.PERSONAL else shield_data.shield_radius
	var points: PackedVector2Array = []
	var segments = 32
	for i in range(segments):
		var angle = i * TAU / segments
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	shield_shape.polygon = points

	shield_visual.add_child(shield_shape)
	
	# 隐藏原有视觉效果，使用VFX代替
	shield_visual.visible = false
	
	target.add_child(shield_visual)

	return shield_visual

func _update_shield_visual(instance: ShieldInstance) -> void:
	# 原有视觉效果已禁用，由VFX接管
	pass

func _play_break_effect(position: Vector2) -> void:
	# 播放护盾破碎爆炸特效
	var explosion_vfx = VFXFactory.create_explosion_vfx(CarrierConfigData.Phase.PLASMA, 50.0, 0.5)
	if explosion_vfx:
		VFXFactory.spawn_at(explosion_vfx, position, get_tree().current_scene)

func _play_explosion_effect(position: Vector2, radius: float) -> void:
	# 播放护盾破碎后的爆炸特效
	var explosion_vfx = VFXFactory.create_explosion_vfx(CarrierConfigData.Phase.PLASMA, radius, 0.3)
	if explosion_vfx:
		VFXFactory.spawn_at(explosion_vfx, position, get_tree().current_scene)

func _find_enemies_in_range(position: Vector2, radius: float) -> Array:
	var enemies: Array = []
	var all_enemies = get_tree().get_nodes_in_group("enemies")

	for enemy in all_enemies:
		if is_instance_valid(enemy) and enemy.global_position.distance_to(position) <= radius:
			enemies.append(enemy)

	return enemies

func has_shield(target: Node) -> bool:
	return active_shields.has(target.get_instance_id())

func get_shield_amount(target: Node) -> float:
	var target_id = target.get_instance_id()
	if not active_shields.has(target_id):
		return 0.0
	return active_shields[target_id].current_amount

func remove_shield(target: Node) -> void:
	var target_id = target.get_instance_id()
	if active_shields.has(target_id):
		_expire_shield(target)
		active_shields.erase(target_id)
