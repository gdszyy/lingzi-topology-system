# status_effect_manager.gd
# 状态效果运行时管理器 - 基于灵子相变理论的状态效果处理
class_name StatusEffectManager
extends Node

## 信号
signal status_applied(target: Node, status_data: ApplyStatusActionData)
signal status_removed(target: Node, status_type: ApplyStatusActionData.StatusType)
signal status_ticked(target: Node, status_type: ApplyStatusActionData.StatusType, damage: float)
signal phase_counter_triggered(target: Node, attacker_phase: ApplyStatusActionData.SpiritonPhase, target_phase: ApplyStatusActionData.SpiritonPhase)

## 活跃状态效果 {target_node_id: {status_type: StatusInstance}}
var active_effects: Dictionary = {}

## 状态效果实例
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

## 更新所有状态效果
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
			
			# 检查是否过期
			if instance.remaining_duration <= 0:
				effects_to_remove.append(status_type)
				continue
			
			# 处理周期性效果
			instance.tick_timer += delta
			if instance.tick_timer >= instance.data.tick_interval:
				instance.tick_timer = 0.0
				_apply_tick_effect(instance)
		
		# 移除过期效果
		for status_type in effects_to_remove:
			_remove_effect(target_node, status_type)
	
	# 清理无效目标
	for target_id in to_remove:
		active_effects.erase(target_id)

## 应用状态效果
func apply_status(target: Node, status_data: ApplyStatusActionData) -> void:
	if target == null or not is_instance_valid(target):
		return
	
	var target_id = target.get_instance_id()
	
	if not active_effects.has(target_id):
		active_effects[target_id] = {}
	
	var target_effects = active_effects[target_id]
	var status_type = status_data.status_type
	
	# 检查相态克制
	var target_phase = _get_target_dominant_phase(target)
	if status_data.is_counter_phase(target_phase):
		phase_counter_triggered.emit(target, status_data.spiriton_phase, target_phase)
	
	# 已存在相同状态
	if target_effects.has(status_type):
		var existing: StatusInstance = target_effects[status_type]
		
		# 刷新持续时间
		if status_data.refresh_on_apply:
			existing.remaining_duration = status_data.duration
		
		# 叠加层数
		if existing.stacks < status_data.stack_limit:
			existing.stacks += 1
	else:
		# 新增状态
		var instance = StatusInstance.new(status_data, target)
		target_effects[status_type] = instance
		_apply_initial_effect(instance)
	
	status_applied.emit(target, status_data)

## 移除状态效果
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

## 应用初始效果（状态刚施加时）
func _apply_initial_effect(instance: StatusInstance) -> void:
	var target = instance.target
	var data = instance.data
	
	match data.status_type:
		ApplyStatusActionData.StatusType.CRYO_CRYSTAL:
			# 冷脆化：立即冻结 + 降低防御
			if target.has_method("set_frozen"):
				target.set_frozen(true)
			if target.has_method("modify_defense"):
				target.modify_defense(-data.effect_value * 0.5)  # 降低50%防御
		
		ApplyStatusActionData.StatusType.STRUCTURE_LOCK:
			# 结构锁：禁止移动
			if target.has_method("set_movement_locked"):
				target.set_movement_locked(true)
		
		ApplyStatusActionData.StatusType.PHASE_DISRUPTION:
			# 相位紊乱：降低命中和闪避
			if target.has_method("modify_accuracy"):
				target.modify_accuracy(-data.effect_value * 0.3)
			if target.has_method("modify_evasion"):
				target.modify_evasion(-data.effect_value * 0.3)
		
		ApplyStatusActionData.StatusType.RESONANCE_MARK:
			# 共振标记：增加受到的伤害
			if target.has_method("modify_damage_taken"):
				target.modify_damage_taken(data.effect_value * 0.25)
		
		ApplyStatusActionData.StatusType.SPIRITON_SURGE:
			# 灵潮：增加伤害输出
			if target.has_method("modify_damage_output"):
				target.modify_damage_output(data.effect_value * 0.2)
		
		ApplyStatusActionData.StatusType.PHASE_SHIFT:
			# 相移：增加移动速度
			if target.has_method("modify_move_speed"):
				target.modify_move_speed(data.effect_value * 0.3)
		
		ApplyStatusActionData.StatusType.SOLID_SHELL:
			# 固壳：添加护盾
			if target.has_method("add_shield"):
				target.add_shield(data.effect_value * 10)

## 应用周期性效果（每tick触发）
func _apply_tick_effect(instance: StatusInstance) -> void:
	var target = instance.target
	var data = instance.data
	var stacks = instance.stacks
	
	# 计算实际效果值（考虑相态克制）
	var target_phase = _get_target_dominant_phase(target)
	var effective_value = data.calculate_effective_value(target_phase) * stacks
	
	match data.status_type:
		ApplyStatusActionData.StatusType.ENTROPY_BURN:
			# 熵燃：持续火焰伤害
			if target.has_method("take_damage"):
				target.take_damage(effective_value)
				status_ticked.emit(target, data.status_type, effective_value)
		
		ApplyStatusActionData.StatusType.SPIRITON_EROSION:
			# 灵蚀：持续伤害
			if target.has_method("take_damage"):
				target.take_damage(effective_value * 0.6)
				status_ticked.emit(target, data.status_type, effective_value * 0.6)
		
		ApplyStatusActionData.StatusType.CRYO_CRYSTAL:
			# 冷脆化：持续冻结检查（如果目标温度恢复则解冻）
			pass  # 冻结是持续状态，不需要每tick处理

## 移除效果修正（状态结束时）
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
				target.modify_defense(data.effect_value * 0.5)  # 恢复防御
		
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

## 获取目标的主导灵子相态
func _get_target_dominant_phase(target: Node) -> ApplyStatusActionData.SpiritonPhase:
	# 检查目标当前的状态效果，返回主导相态
	var target_id = target.get_instance_id()
	
	if not active_effects.has(target_id):
		return ApplyStatusActionData.SpiritonPhase.WAVE  # 默认波态
	
	var target_effects = active_effects[target_id]
	
	# 优先级：等离子 > 液态 > 固态 > 气态 > 波态
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

## 检查目标是否有指定状态
func has_status(target: Node, status_type: ApplyStatusActionData.StatusType) -> bool:
	var target_id = target.get_instance_id()
	if not active_effects.has(target_id):
		return false
	return active_effects[target_id].has(status_type)

## 获取状态层数
func get_status_stacks(target: Node, status_type: ApplyStatusActionData.StatusType) -> int:
	var target_id = target.get_instance_id()
	if not active_effects.has(target_id):
		return 0
	if not active_effects[target_id].has(status_type):
		return 0
	return active_effects[target_id][status_type].stacks

## 净化指定状态
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

## 净化所有可净化的负面状态
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

## 处理目标死亡时的状态传播
func on_target_death(target: Node) -> void:
	var target_id = target.get_instance_id()
	if not active_effects.has(target_id):
		return
	
	var target_effects = active_effects[target_id]
	
	for status_type in target_effects:
		var instance: StatusInstance = target_effects[status_type]
		if instance.data.spread_on_death:
			_spread_status_to_nearby(target, instance.data)
	
	# 清理该目标的所有状态
	active_effects.erase(target_id)

## 传播状态到附近敌人
func _spread_status_to_nearby(source: Node, status_data: ApplyStatusActionData) -> void:
	var nearby_enemies = _find_enemies_in_range(source.global_position, status_data.spread_radius)
	
	for enemy in nearby_enemies:
		if enemy != source:
			apply_status(enemy, status_data)

## 查找范围内的敌人
func _find_enemies_in_range(position: Vector2, radius: float) -> Array:
	var enemies: Array = []
	var all_enemies = get_tree().get_nodes_in_group("enemies")
	
	for enemy in all_enemies:
		if is_instance_valid(enemy) and enemy.global_position.distance_to(position) <= radius:
			enemies.append(enemy)
	
	return enemies
