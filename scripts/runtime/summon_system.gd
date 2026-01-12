# summon_system.gd
# 召唤系统运行时逻辑 - 基于灵子凝聚的实体构造机制
# 
# 灵子物理学基础：
# - 召唤物是固态灵子凝聚形成的临时实体
# - 召唤物具有独立的灵子核心（逻辑核）
# - 召唤物消亡时灵子会释放回环境
class_name SummonSystem
extends Node

## 信号
signal summon_created(summon: Node, summon_data: SummonActionData)
signal summon_attacked(summon: Node, target: Node, damage: float)
signal summon_died(summon: Node, death_position: Vector2)
signal summon_expired(summon: Node)

## 活跃召唤物 {summon_node_id: SummonInstance}
var active_summons: Dictionary = {}

## 召唤物实例
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

## 更新所有召唤物
func _update_all_summons(delta: float) -> void:
	var to_remove: Array = []
	
	for summon_id in active_summons:
		var instance: SummonInstance = active_summons[summon_id]
		var summon = instance.summon_node
		
		if summon == null or not is_instance_valid(summon):
			to_remove.append(summon_id)
			continue
		
		# 更新持续时间
		instance.remaining_duration -= delta
		
		# 检查是否过期
		if instance.remaining_duration <= 0:
			_expire_summon(instance)
			to_remove.append(summon_id)
			continue
		
		# 更新召唤物行为
		_update_summon_behavior(instance, delta)
	
	# 清理过期召唤物
	for summon_id in to_remove:
		active_summons.erase(summon_id)

## 创建召唤物
func create_summon(summon_data: SummonActionData, spawn_position: Vector2, owner: Node) -> Array[Node2D]:
	var created_summons: Array[Node2D] = []
	
	for i in range(summon_data.summon_count):
		# 计算生成位置
		var offset = _calculate_spawn_offset(i, summon_data.summon_count, summon_data.summon_type)
		var position = spawn_position + offset
		
		# 创建召唤物节点
		var summon_node = _create_summon_node(summon_data, position)
		
		# 创建召唤物实例
		var instance = SummonInstance.new(summon_data, owner)
		instance.summon_node = summon_node
		
		active_summons[summon_node.get_instance_id()] = instance
		created_summons.append(summon_node)
		
		summon_created.emit(summon_node, summon_data)
	
	return created_summons

## 计算生成位置偏移
func _calculate_spawn_offset(index: int, total: int, summon_type: SummonActionData.SummonType) -> Vector2:
	match summon_type:
		SummonActionData.SummonType.ORBITER:
			# 环绕体：均匀分布在圆周上
			var angle = index * TAU / total
			return Vector2(cos(angle), sin(angle)) * 50.0
		
		SummonActionData.SummonType.BARRIER:
			# 屏障：排成一排
			var spacing = 40.0
			var start_offset = -(total - 1) * spacing / 2
			return Vector2(start_offset + index * spacing, 0)
		
		_:
			# 其他类型：随机偏移
			var angle = randf() * TAU
			var distance = randf_range(30.0, 60.0)
			return Vector2(cos(angle), sin(angle)) * distance

## 创建召唤物节点
func _create_summon_node(summon_data: SummonActionData, position: Vector2) -> Node2D:
	var summon = Area2D.new()
	summon.name = "Summon_" + SummonActionData.SummonType.keys()[summon_data.summon_type]
	summon.global_position = position
	summon.add_to_group("summons")
	summon.add_to_group("player_summons")
	
	# 创建碰撞形状
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 15.0
	collision.shape = shape
	summon.add_child(collision)
	
	# 创建视觉效果
	var visual = _create_summon_visual(summon_data)
	summon.add_child(visual)
	
	# 添加到场景
	get_tree().current_scene.add_child(summon)
	
	return summon

## 创建召唤物视觉效果
func _create_summon_visual(summon_data: SummonActionData) -> Node2D:
	var visual = Polygon2D.new()
	visual.name = "Visual"
	
	# 根据召唤物类型设置形状和颜色
	var color: Color
	var points: PackedVector2Array
	
	match summon_data.summon_type:
		SummonActionData.SummonType.TURRET:
			color = Color(0.8, 0.6, 0.2)  # 金色
			points = _create_square_points(12.0)
		
		SummonActionData.SummonType.MINION:
			color = Color(0.4, 0.8, 0.4)  # 绿色
			points = _create_circle_points(10.0, 8)
		
		SummonActionData.SummonType.ORBITER:
			color = Color(0.6, 0.6, 1.0)  # 淡蓝色
			points = _create_circle_points(8.0, 6)
		
		SummonActionData.SummonType.DECOY:
			color = Color(1.0, 0.8, 0.4)  # 橙黄色
			points = _create_circle_points(15.0, 12)
		
		SummonActionData.SummonType.BARRIER:
			color = Color(0.4, 0.4, 0.8)  # 深蓝色
			points = _create_rectangle_points(8.0, 25.0)
		
		SummonActionData.SummonType.TOTEM:
			color = Color(0.8, 0.4, 0.8)  # 紫色
			points = _create_triangle_points(12.0)
	
	visual.polygon = points
	visual.color = color
	
	return visual

## 创建圆形点
func _create_circle_points(radius: float, segments: int) -> PackedVector2Array:
	var points: PackedVector2Array = []
	for i in range(segments):
		var angle = i * TAU / segments
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points

## 创建方形点
func _create_square_points(size: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-size, -size),
		Vector2(size, -size),
		Vector2(size, size),
		Vector2(-size, size)
	])

## 创建矩形点
func _create_rectangle_points(width: float, height: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-width, -height),
		Vector2(width, -height),
		Vector2(width, height),
		Vector2(-width, height)
	])

## 创建三角形点
func _create_triangle_points(size: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0, -size),
		Vector2(size * 0.866, size * 0.5),
		Vector2(-size * 0.866, size * 0.5)
	])

## 更新召唤物行为
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

## 炮塔行为：固定位置，自动攻击
func _update_turret_behavior(instance: SummonInstance, delta: float) -> void:
	var summon = instance.summon_node
	var data = instance.data
	
	# 更新攻击计时器
	instance.attack_timer += delta
	
	if instance.attack_timer >= data.summon_attack_interval:
		instance.attack_timer = 0.0
		
		# 查找目标
		var target = _find_nearest_enemy(summon.global_position, data.summon_attack_range)
		
		if target != null:
			_perform_attack(instance, target)

## 仆从行为：追踪敌人，近战攻击
func _update_minion_behavior(instance: SummonInstance, delta: float) -> void:
	var summon = instance.summon_node
	var data = instance.data
	
	# 查找或更新目标
	if instance.current_target == null or not is_instance_valid(instance.current_target):
		instance.current_target = _find_nearest_enemy(summon.global_position, data.summon_attack_range * 2)
	
	if instance.current_target != null:
		# 移动向目标
		var direction = (instance.current_target.global_position - summon.global_position).normalized()
		summon.global_position += direction * data.summon_move_speed * delta
		
		# 检查是否在攻击范围内
		var distance = summon.global_position.distance_to(instance.current_target.global_position)
		if distance <= 30.0:  # 近战范围
			instance.attack_timer += delta
			if instance.attack_timer >= data.summon_attack_interval:
				instance.attack_timer = 0.0
				_perform_attack(instance, instance.current_target)

## 环绕体行为：围绕主人旋转
func _update_orbiter_behavior(instance: SummonInstance, delta: float) -> void:
	var summon = instance.summon_node
	var data = instance.data
	var owner = instance.owner
	
	if owner == null or not is_instance_valid(owner):
		return
	
	# 计算环绕位置
	var elapsed = data.summon_duration - instance.remaining_duration
	var angle = elapsed * data.orbit_speed
	var offset = Vector2(cos(angle), sin(angle)) * data.orbit_radius
	
	summon.global_position = owner.global_position + offset
	
	# 检查是否碰到敌人
	var nearby_enemy = _find_nearest_enemy(summon.global_position, 20.0)
	if nearby_enemy != null:
		instance.attack_timer += delta
		if instance.attack_timer >= 0.5:  # 碰撞伤害间隔
			instance.attack_timer = 0.0
			_perform_attack(instance, nearby_enemy)

## 诱饵行为：吸引敌人注意
func _update_decoy_behavior(instance: SummonInstance, delta: float) -> void:
	var summon = instance.summon_node
	var data = instance.data
	
	# 诱饵不主动攻击，只是吸引敌人
	# 可以通过设置敌人的目标优先级来实现
	# 这里简化处理：让诱饵闪烁以表示其存在
	var visual = summon.get_node_or_null("Visual")
	if visual != null:
		var flash = sin(Time.get_ticks_msec() * 0.005) * 0.3 + 0.7
		visual.modulate.a = flash

## 屏障行为：阻挡投射物
func _update_barrier_behavior(instance: SummonInstance, delta: float) -> void:
	# 屏障是被动的，通过碰撞检测阻挡投射物
	# 这里可以添加视觉效果更新
	pass

## 图腾行为：持续释放效果
func _update_totem_behavior(instance: SummonInstance, delta: float) -> void:
	var summon = instance.summon_node
	var data = instance.data
	
	# 周期性释放效果
	instance.attack_timer += delta
	
	if instance.attack_timer >= data.summon_attack_interval:
		instance.attack_timer = 0.0
		
		# 对范围内的敌人造成效果
		var enemies = _find_enemies_in_range(summon.global_position, data.totem_effect_radius)
		for enemy in enemies:
			_perform_attack(instance, enemy)

## 执行攻击
func _perform_attack(instance: SummonInstance, target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	
	var damage = instance.data.summon_damage
	
	if target.has_method("take_damage"):
		target.take_damage(damage)
		summon_attacked.emit(instance.summon_node, target, damage)

## 召唤物受到伤害
func damage_summon(summon: Node, damage: float) -> void:
	var summon_id = summon.get_instance_id()
	
	if not active_summons.has(summon_id):
		return
	
	var instance: SummonInstance = active_summons[summon_id]
	instance.current_health -= damage
	
	if instance.current_health <= 0:
		_kill_summon(instance)
		active_summons.erase(summon_id)

## 召唤物死亡
func _kill_summon(instance: SummonInstance) -> void:
	var summon = instance.summon_node
	var death_position = summon.global_position
	
	# 播放死亡特效
	_play_death_effect(death_position)
	
	# 移除召唤物
	summon.queue_free()
	
	summon_died.emit(summon, death_position)

## 召唤物过期
func _expire_summon(instance: SummonInstance) -> void:
	var summon = instance.summon_node
	
	# 播放消散特效
	_play_expire_effect(summon.global_position)
	
	# 移除召唤物
	summon.queue_free()
	
	summon_expired.emit(summon)

## 播放死亡特效
func _play_death_effect(position: Vector2) -> void:
	# TODO: 实现死亡粒子效果
	pass

## 播放消散特效
func _play_expire_effect(position: Vector2) -> void:
	# TODO: 实现消散粒子效果
	pass

## 查找最近的敌人
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

## 查找范围内的敌人
func _find_enemies_in_range(position: Vector2, radius: float) -> Array:
	var enemies: Array = []
	
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			if enemy.global_position.distance_to(position) <= radius:
				enemies.append(enemy)
	
	return enemies

## 获取活跃召唤物数量
func get_active_summon_count() -> int:
	return active_summons.size()

## 获取指定主人的召唤物
func get_summons_by_owner(owner: Node) -> Array[Node2D]:
	var summons: Array[Node2D] = []
	
	for summon_id in active_summons:
		var instance: SummonInstance = active_summons[summon_id]
		if instance.owner == owner:
			summons.append(instance.summon_node)
	
	return summons

## 移除指定主人的所有召唤物
func remove_summons_by_owner(owner: Node) -> void:
	var to_remove: Array = []
	
	for summon_id in active_summons:
		var instance: SummonInstance = active_summons[summon_id]
		if instance.owner == owner:
			_expire_summon(instance)
			to_remove.append(summon_id)
	
	for summon_id in to_remove:
		active_summons.erase(summon_id)
