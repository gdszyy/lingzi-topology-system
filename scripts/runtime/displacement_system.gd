# displacement_system.gd
# 位移系统运行时逻辑 - 基于灵子场的动量传递机制
# 
# 灵子物理学基础：
# - 灵子场可以传递动量和能量
# - 击退/吸引是灵子场的斥力/引力效应
# - 传送是波态灵子的空间折叠
# - 击飞是垂直方向的动量注入
class_name DisplacementSystem
extends Node

## 信号
signal displacement_started(target: Node, displacement_data: DisplacementActionData)
signal displacement_ended(target: Node)
signal displacement_collision(target: Node, collider: Node, damage: float)
signal target_stunned(target: Node, duration: float)

## 活跃位移效果 {target_node_id: DisplacementInstance}
var active_displacements: Dictionary = {}

## 位移实例
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

## 更新所有位移效果
func _update_all_displacements(delta: float) -> void:
	var to_remove: Array = []
	
	for target_id in active_displacements:
		var instance: DisplacementInstance = active_displacements[target_id]
		var target = instance.target
		
		if target == null or not is_instance_valid(target):
			to_remove.append(target_id)
			continue
		
		# 更新位移
		instance.elapsed_time += delta
		
		# 检查是否结束
		if instance.elapsed_time >= instance.data.displacement_duration:
			_end_displacement(target, instance)
			to_remove.append(target_id)
			continue
		
		# 应用位移
		_apply_displacement(instance, delta)
	
	# 清理结束的位移
	for target_id in to_remove:
		active_displacements.erase(target_id)

## 应用位移效果
func apply_displacement(target: Node, displacement_data: DisplacementActionData, source_position: Vector2) -> void:
	if target == null or not is_instance_valid(target):
		return
	
	var target_id = target.get_instance_id()
	
	# 如果已在位移中，不叠加
	if active_displacements.has(target_id):
		return
	
	# 计算位移方向
	var direction = _calculate_displacement_direction(target, displacement_data, source_position)
	
	# 创建位移实例
	var instance = DisplacementInstance.new(displacement_data, target, direction)
	
	# 计算初始速度
	match displacement_data.displacement_type:
		DisplacementActionData.DisplacementType.KNOCKBACK:
			instance.velocity = direction * displacement_data.displacement_force
		DisplacementActionData.DisplacementType.PULL:
			instance.velocity = -direction * displacement_data.displacement_force
		DisplacementActionData.DisplacementType.TELEPORT:
			# 传送是瞬时的
			_teleport_target(target, displacement_data, source_position)
			_apply_stun_if_needed(target, displacement_data)
			return
		DisplacementActionData.DisplacementType.LAUNCH:
			# 击飞：向上的抛物线运动
			instance.velocity = Vector2(direction.x * displacement_data.displacement_force * 0.3, 
			                            -displacement_data.displacement_force)
	
	active_displacements[target_id] = instance
	
	# 禁用目标的正常移动
	if target.has_method("set_movement_disabled"):
		target.set_movement_disabled(true)
	
	displacement_started.emit(target, displacement_data)

## 计算位移方向
func _calculate_displacement_direction(target: Node, displacement_data: DisplacementActionData, source_position: Vector2) -> Vector2:
	match displacement_data.displacement_type:
		DisplacementActionData.DisplacementType.KNOCKBACK:
			# 击退：从来源指向目标
			return (target.global_position - source_position).normalized()
		DisplacementActionData.DisplacementType.PULL:
			# 吸引：从目标指向来源
			return (source_position - target.global_position).normalized()
		DisplacementActionData.DisplacementType.TELEPORT:
			# 传送：方向不重要
			return Vector2.ZERO
		DisplacementActionData.DisplacementType.LAUNCH:
			# 击飞：主要是向上，略带水平方向
			var horizontal = (target.global_position - source_position).normalized()
			return horizontal
	
	return Vector2.RIGHT

## 应用位移
func _apply_displacement(instance: DisplacementInstance, delta: float) -> void:
	var target = instance.target
	var data = instance.data
	
	match data.displacement_type:
		DisplacementActionData.DisplacementType.KNOCKBACK, DisplacementActionData.DisplacementType.PULL:
			# 线性位移，带减速
			var progress = instance.elapsed_time / data.displacement_duration
			var deceleration = 1.0 - progress  # 线性减速
			var current_velocity = instance.velocity * deceleration
			
			# 移动目标
			var new_position = target.global_position + current_velocity * delta
			
			# 碰撞检测
			if _check_collision(target, new_position) and not instance.has_collided:
				instance.has_collided = true
				_handle_collision(instance)
			else:
				target.global_position = new_position
		
		DisplacementActionData.DisplacementType.LAUNCH:
			# 抛物线运动
			var gravity = 800.0  # 重力加速度
			instance.velocity.y += gravity * delta
			
			var new_position = target.global_position + instance.velocity * delta
			
			# 检查是否落地
			if new_position.y >= instance.start_position.y:
				new_position.y = instance.start_position.y
				instance.elapsed_time = data.displacement_duration  # 强制结束
				
				# 落地伤害
				if data.damage_on_collision > 0:
					_apply_landing_damage(target, data.damage_on_collision)
			
			target.global_position = new_position

## 传送目标
func _teleport_target(target: Node, displacement_data: DisplacementActionData, source_position: Vector2) -> void:
	var teleport_distance = displacement_data.displacement_force * 0.5  # 力度转换为距离
	var direction = (target.global_position - source_position).normalized()
	
	# 计算传送目标位置
	var teleport_position = target.global_position + direction * teleport_distance
	
	# 检查目标位置是否有效
	if not _is_position_valid(teleport_position):
		# 尝试找到最近的有效位置
		teleport_position = _find_nearest_valid_position(target.global_position, teleport_position)
	
	# 播放传送特效
	_play_teleport_effect(target.global_position, teleport_position)
	
	# 执行传送
	target.global_position = teleport_position

## 检查碰撞
func _check_collision(target: Node, new_position: Vector2) -> bool:
	# 简化的碰撞检测：检查是否有障碍物
	var space_state = target.get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(target.global_position, new_position)
	query.exclude = [target]
	query.collision_mask = 1  # 假设障碍物在第1层
	
	var result = space_state.intersect_ray(query)
	return not result.is_empty()

## 处理碰撞
func _handle_collision(instance: DisplacementInstance) -> void:
	var target = instance.target
	var data = instance.data
	
	# 停止位移
	instance.velocity = Vector2.ZERO
	
	# 碰撞伤害
	if data.damage_on_collision > 0 and target.has_method("take_damage"):
		target.take_damage(data.damage_on_collision)
		displacement_collision.emit(target, null, data.damage_on_collision)

## 应用落地伤害
func _apply_landing_damage(target: Node, damage: float) -> void:
	if target.has_method("take_damage"):
		target.take_damage(damage)
		displacement_collision.emit(target, null, damage)

## 结束位移
func _end_displacement(target: Node, instance: DisplacementInstance) -> void:
	# 恢复目标的正常移动
	if target.has_method("set_movement_disabled"):
		target.set_movement_disabled(false)
	
	# 应用位移后眩晕
	_apply_stun_if_needed(target, instance.data)
	
	displacement_ended.emit(target)

## 应用眩晕效果
func _apply_stun_if_needed(target: Node, displacement_data: DisplacementActionData) -> void:
	if displacement_data.stun_after_displacement > 0:
		if target.has_method("apply_stun"):
			target.apply_stun(displacement_data.stun_after_displacement)
		target_stunned.emit(target, displacement_data.stun_after_displacement)

## 检查位置是否有效
func _is_position_valid(position: Vector2) -> bool:
	# TODO: 实现更完善的位置有效性检查
	return true

## 查找最近的有效位置
func _find_nearest_valid_position(from: Vector2, to: Vector2) -> Vector2:
	# 简化实现：返回中点
	return from.lerp(to, 0.5)

## 播放传送特效
func _play_teleport_effect(from: Vector2, to: Vector2) -> void:
	# TODO: 实现传送粒子效果
	pass

## 检查目标是否正在位移中
func is_being_displaced(target: Node) -> bool:
	return active_displacements.has(target.get_instance_id())

## 中断位移
func interrupt_displacement(target: Node) -> void:
	var target_id = target.get_instance_id()
	if active_displacements.has(target_id):
		var instance: DisplacementInstance = active_displacements[target_id]
		
		# 恢复目标的正常移动
		if target.has_method("set_movement_disabled"):
			target.set_movement_disabled(false)
		
		active_displacements.erase(target_id)
		displacement_ended.emit(target)
