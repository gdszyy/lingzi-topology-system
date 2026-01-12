# reflect_system.gd
# 反弹系统运行时逻辑 - 基于固态灵子的能量反射机制
# 
# 灵子物理学基础：
# - 固态灵子具有强相互作用力
# - 反弹本质是灵子场的弹性碰撞
# - 反弹可以将投射物、伤害反射回敌人
class_name ReflectSystem
extends Node

## 信号
signal reflect_activated(target: Node, reflect_data: ReflectActionData)
signal projectile_reflected(target: Node, projectile: Node, damage_bonus: float)
signal damage_reflected(target: Node, source: Node, reflected_damage: float)
signal reflect_expired(target: Node)
signal reflect_depleted(target: Node)  # 反弹次数用尽

## 活跃反弹效果 {target_node_id: ReflectInstance}
var active_reflects: Dictionary = {}

## 反弹实例
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

## 更新所有反弹效果
func _update_all_reflects(delta: float) -> void:
	var to_remove: Array = []
	
	for target_id in active_reflects:
		var instance: ReflectInstance = active_reflects[target_id]
		var target = instance.target
		
		if target == null or not is_instance_valid(target):
			to_remove.append(target_id)
			continue
		
		# 更新持续时间
		instance.remaining_duration -= delta
		
		# 检查是否过期
		if instance.remaining_duration <= 0:
			_expire_reflect(target)
			to_remove.append(target_id)
			continue
		
		# 更新视觉效果
		_update_reflect_visual(instance)
	
	# 清理过期效果
	for target_id in to_remove:
		active_reflects.erase(target_id)

## 激活反弹效果
func activate_reflect(target: Node, reflect_data: ReflectActionData) -> void:
	if target == null or not is_instance_valid(target):
		return
	
	var target_id = target.get_instance_id()
	
	# 如果已有反弹效果，刷新
	if active_reflects.has(target_id):
		var existing: ReflectInstance = active_reflects[target_id]
		existing.remaining_duration = maxf(existing.remaining_duration, reflect_data.reflect_duration)
		existing.remaining_reflects = maxi(existing.remaining_reflects, reflect_data.max_reflects)
		return
	
	# 创建新反弹效果
	var instance = ReflectInstance.new(reflect_data, target)
	instance.reflect_visual = _create_reflect_visual(target, reflect_data)
	active_reflects[target_id] = instance
	
	reflect_activated.emit(target, reflect_data)

## 尝试反弹投射物
func try_reflect_projectile(target: Node, projectile: Node) -> bool:
	var target_id = target.get_instance_id()
	
	if not active_reflects.has(target_id):
		return false
	
	var instance: ReflectInstance = active_reflects[target_id]
	
	# 检查反弹类型（PROJECTILE 或 BOTH 可以反弹投射物）
	if instance.data.reflect_type != ReflectActionData.ReflectType.PROJECTILE and \
	   instance.data.reflect_type != ReflectActionData.ReflectType.BOTH:
		return false
	
	# 检查剩余反弹次数
	if instance.remaining_reflects <= 0:
		return false
	
	# 执行反弹
	instance.remaining_reflects -= 1
	var damage_bonus = instance.data.reflect_damage_ratio
	_reflect_projectile(projectile, target, damage_bonus)
	
	projectile_reflected.emit(target, projectile, damage_bonus)
	
	# 检查是否用尽
	if instance.remaining_reflects <= 0:
		reflect_depleted.emit(target)
		_expire_reflect(target)
		active_reflects.erase(target_id)
	
	return true

## 尝试反弹伤害
func try_reflect_damage(target: Node, source: Node, damage: float) -> float:
	var target_id = target.get_instance_id()
	
	if not active_reflects.has(target_id):
		return 0.0
	
	var instance: ReflectInstance = active_reflects[target_id]
	
	# 检查反弹类型（DAMAGE 或 BOTH 可以反弹伤害）
	if instance.data.reflect_type != ReflectActionData.ReflectType.DAMAGE and \
	   instance.data.reflect_type != ReflectActionData.ReflectType.BOTH:
		return 0.0
	
	# 检查剩余反弹次数
	if instance.remaining_reflects <= 0:
		return 0.0
	
	# 计算反弹伤害
	var reflected_damage = damage * instance.data.reflect_damage_ratio
	
	# 对来源造成反弹伤害
	if source != null and is_instance_valid(source) and source.has_method("take_damage"):
		source.take_damage(reflected_damage)
	
	instance.remaining_reflects -= 1
	damage_reflected.emit(target, source, reflected_damage)
	
	# 检查是否用尽
	if instance.remaining_reflects <= 0:
		reflect_depleted.emit(target)
		_expire_reflect(target)
		active_reflects.erase(target_id)
	
	return reflected_damage

## 反射投射物
func _reflect_projectile(projectile: Node, reflector: Node, damage_bonus: float) -> void:
	if not is_instance_valid(projectile):
		return
	
	# 计算反射方向（朝向最近的敌人或原方向反转）
	var new_direction = _calculate_reflect_direction(projectile, reflector)
	
	# 设置新方向
	if projectile.has_method("set_direction"):
		projectile.set_direction(new_direction)
	elif projectile.has_property("velocity"):
		var speed = projectile.velocity.length()
		projectile.velocity = new_direction * speed
	
	# 改变投射物所属阵营
	if projectile.has_method("set_owner_faction"):
		var reflector_faction = "player" if reflector.is_in_group("players") else "enemy"
		projectile.set_owner_faction(reflector_faction)
	
	# 增加反射伤害加成
	if projectile.has_method("add_damage_multiplier"):
		projectile.add_damage_multiplier(damage_bonus)
	elif projectile.has_property("damage"):
		projectile.damage *= (1.0 + damage_bonus)
	
	# 播放反射特效
	_play_reflect_effect(reflector.global_position)

## 计算反射方向
func _calculate_reflect_direction(projectile: Node, reflector: Node) -> Vector2:
	# 尝试找到最近的敌人作为新目标
	var reflector_faction = "player" if reflector.is_in_group("players") else "enemy"
	var target_group = "enemies" if reflector_faction == "player" else "players"
	
	var nearest_target = _find_nearest_in_group(reflector.global_position, target_group, 500.0)
	
	if nearest_target != null:
		return (nearest_target.global_position - reflector.global_position).normalized()
	
	# 没有目标，反转原方向
	if projectile.has_property("velocity"):
		return -projectile.velocity.normalized()
	
	return Vector2.RIGHT

## 查找最近的目标
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

## 反弹效果过期
func _expire_reflect(target: Node) -> void:
	var target_id = target.get_instance_id()
	
	if not active_reflects.has(target_id):
		return
	
	var instance: ReflectInstance = active_reflects[target_id]
	
	# 移除视觉效果
	if instance.reflect_visual != null and is_instance_valid(instance.reflect_visual):
		instance.reflect_visual.queue_free()
	
	reflect_expired.emit(target)

## 创建反弹视觉效果
func _create_reflect_visual(target: Node, reflect_data: ReflectActionData) -> Node2D:
	var reflect_visual = Node2D.new()
	reflect_visual.name = "ReflectVisual"
	
	# 创建反弹光环
	var reflect_ring = Polygon2D.new()
	reflect_ring.name = "ReflectRing"
	
	# 根据反弹类型设置颜色
	var ring_color: Color
	match reflect_data.reflect_type:
		ReflectActionData.ReflectType.PROJECTILE:
			ring_color = Color(1.0, 0.8, 0.2, 0.5)  # 金色
		ReflectActionData.ReflectType.DAMAGE:
			ring_color = Color(1.0, 0.3, 0.3, 0.5)  # 红色
		ReflectActionData.ReflectType.BOTH:
			ring_color = Color(0.8, 0.2, 1.0, 0.5)  # 紫色
	
	reflect_ring.color = ring_color
	
	# 生成环形多边形
	var inner_radius = 25.0
	var outer_radius = 35.0
	var points: PackedVector2Array = []
	var segments = 32
	
	# 外圈
	for i in range(segments + 1):
		var angle = i * TAU / segments
		points.append(Vector2(cos(angle), sin(angle)) * outer_radius)
	
	# 内圈（反向）
	for i in range(segments, -1, -1):
		var angle = i * TAU / segments
		points.append(Vector2(cos(angle), sin(angle)) * inner_radius)
	
	reflect_ring.polygon = points
	
	reflect_visual.add_child(reflect_ring)
	target.add_child(reflect_visual)
	
	return reflect_visual

## 更新反弹视觉效果
func _update_reflect_visual(instance: ReflectInstance) -> void:
	if instance.reflect_visual == null or not is_instance_valid(instance.reflect_visual):
		return
	
	# 旋转光环
	instance.reflect_visual.rotation += 0.02
	
	# 根据剩余次数调整透明度
	var reflect_ring = instance.reflect_visual.get_node_or_null("ReflectRing")
	if reflect_ring != null:
		var ratio = float(instance.remaining_reflects) / float(instance.data.max_reflects)
		reflect_ring.color.a = 0.3 + ratio * 0.4

## 播放反射特效
func _play_reflect_effect(position: Vector2) -> void:
	# TODO: 实现反射粒子效果
	pass

## 检查目标是否有反弹效果
func has_reflect(target: Node) -> bool:
	return active_reflects.has(target.get_instance_id())

## 获取剩余反弹次数
func get_remaining_reflects(target: Node) -> int:
	var target_id = target.get_instance_id()
	if not active_reflects.has(target_id):
		return 0
	return active_reflects[target_id].remaining_reflects

## 移除反弹效果
func remove_reflect(target: Node) -> void:
	var target_id = target.get_instance_id()
	if active_reflects.has(target_id):
		_expire_reflect(target)
		active_reflects.erase(target_id)
