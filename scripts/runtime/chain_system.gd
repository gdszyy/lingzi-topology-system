# chain_system.gd
# 链式系统运行时逻辑 - 基于灵子场的能量传导机制
# 
# 灵子物理学基础：
# - 灵子可以在目标间形成导能通道
# - 链式传导是灵子的级联跃迁
# - 不同相态的链式有不同的附加效果：
#   - 等离子链（闪电）：高速传导，附带眩晕
#   - 等离子链（火焰）：传导时点燃目标
#   - 液态链（冰霜）：传导时结晶目标
#   - 波态链（虚空）：传导时标记目标
class_name ChainSystem
extends Node

## 信号
signal chain_started(source: Node, chain_data: ChainActionData)
signal chain_jumped(from_target: Node, to_target: Node, jump_index: int, damage: float)
signal chain_ended(final_target: Node, total_jumps: int, total_damage: float)
signal chain_status_applied(target: Node, status_type: int)

## 活跃链式效果
var active_chains: Array[ChainInstance] = []

## 链式实例
class ChainInstance:
	var data: ChainActionData
	var current_target: Node
	var hit_targets: Array[Node] = []
	var jump_count: int = 0
	var total_damage: float = 0.0
	var delay_timer: float = 0.0
	var is_waiting: bool = false
	var source_position: Vector2
	
	func _init(chain_data: ChainActionData, first_target: Node, source_pos: Vector2):
		data = chain_data
		current_target = first_target
		hit_targets.append(first_target)
		source_position = source_pos

func _process(delta: float) -> void:
	_update_all_chains(delta)

## 更新所有链式效果
func _update_all_chains(delta: float) -> void:
	var to_remove: Array[int] = []
	
	for i in range(active_chains.size()):
		var chain = active_chains[i]
		
		if chain.is_waiting:
			chain.delay_timer -= delta
			if chain.delay_timer <= 0:
				chain.is_waiting = false
				_process_next_jump(chain)
		
		# 检查是否结束
		if chain.jump_count >= chain.data.chain_count or chain.current_target == null:
			chain_ended.emit(chain.current_target, chain.jump_count, chain.total_damage)
			to_remove.append(i)
	
	# 从后往前移除，避免索引问题
	for i in range(to_remove.size() - 1, -1, -1):
		active_chains.remove_at(to_remove[i])

## 启动链式效果
func start_chain(first_target: Node, chain_data: ChainActionData, source_position: Vector2) -> void:
	if first_target == null or not is_instance_valid(first_target):
		return
	
	# 创建链式实例
	var chain = ChainInstance.new(chain_data, first_target, source_position)
	active_chains.append(chain)
	
	chain_started.emit(first_target, chain_data)
	
	# 对第一个目标造成伤害
	_apply_chain_damage(chain, first_target)
	
	# 开始跳跃
	chain.is_waiting = true
	chain.delay_timer = chain_data.chain_delay

## 处理下一次跳跃
func _process_next_jump(chain: ChainInstance) -> void:
	if chain.current_target == null or not is_instance_valid(chain.current_target):
		return
	
	# 查找下一个目标
	var next_target = _find_next_chain_target(chain)
	
	if next_target == null:
		# 没有可跳跃的目标，链式结束
		return
	
	var from_target = chain.current_target
	chain.current_target = next_target
	chain.hit_targets.append(next_target)
	chain.jump_count += 1
	
	# 播放链式视觉效果
	_play_chain_visual(from_target.global_position, next_target.global_position, chain.data)
	
	# 对新目标造成伤害
	_apply_chain_damage(chain, next_target)
	
	chain_jumped.emit(from_target, next_target, chain.jump_count, chain.data.chain_damage * pow(chain.data.chain_damage_decay, chain.jump_count))
	
	# 继续跳跃
	if chain.jump_count < chain.data.chain_count:
		chain.is_waiting = true
		chain.delay_timer = chain.data.chain_delay

## 查找下一个链式目标
func _find_next_chain_target(chain: ChainInstance) -> Node:
	var current_pos = chain.current_target.global_position
	var search_range = chain.data.chain_range
	
	# 获取范围内的所有敌人
	var candidates: Array = []
	var all_enemies = get_tree().get_nodes_in_group("enemies")
	
	for enemy in all_enemies:
		if not is_instance_valid(enemy):
			continue
		
		# 检查是否已被击中
		if not chain.data.chain_can_return and enemy in chain.hit_targets:
			continue
		
		# 检查距离
		var dist = enemy.global_position.distance_to(current_pos)
		if dist <= search_range and dist > 0:
			candidates.append({"target": enemy, "distance": dist})
	
	if candidates.is_empty():
		return null
	
	# 按距离排序，选择最近的
	candidates.sort_custom(func(a, b): return a.distance < b.distance)
	
	return candidates[0].target

## 应用链式伤害
func _apply_chain_damage(chain: ChainInstance, target: Node) -> void:
	# 计算衰减后的伤害
	var damage = chain.data.chain_damage * pow(chain.data.chain_damage_decay, chain.jump_count)
	
	# 造成伤害
	if target.has_method("take_damage"):
		target.take_damage(damage)
		chain.total_damage += damage
	
	# 应用附加状态效果
	_apply_chain_status(chain, target)

## 应用链式附加状态
func _apply_chain_status(chain: ChainInstance, target: Node) -> void:
	var status_type = chain.data.apply_status_type
	var status_duration = chain.data.apply_status_duration
	
	if status_type < 0 or status_duration <= 0:
		return
	
	# 根据链式类型应用不同状态
	match chain.data.chain_type:
		ChainActionData.ChainType.LIGHTNING:
			# 闪电链：短暂眩晕（使用冷脆化模拟）
			if target.has_method("apply_stun"):
				target.apply_stun(status_duration * 0.3)
		
		ChainActionData.ChainType.FIRE:
			# 火焰链：熵燃状态
			_apply_status_to_target(target, ApplyStatusActionData.StatusType.ENTROPY_BURN, status_duration)
		
		ChainActionData.ChainType.ICE:
			# 冰霜链：冷脆化状态
			_apply_status_to_target(target, ApplyStatusActionData.StatusType.CRYO_CRYSTAL, status_duration)
		
		ChainActionData.ChainType.VOID:
			# 虚空链：共振标记
			_apply_status_to_target(target, ApplyStatusActionData.StatusType.RESONANCE_MARK, status_duration)
	
	chain_status_applied.emit(target, status_type)

## 应用状态到目标
func _apply_status_to_target(target: Node, status_type: ApplyStatusActionData.StatusType, duration: float) -> void:
	# 查找状态效果管理器
	var status_manager = get_tree().get_first_node_in_group("status_effect_manager")
	
	if status_manager != null and status_manager.has_method("apply_status"):
		var status_data = ApplyStatusActionData.new()
		status_data.status_type = status_type
		status_data.duration = duration
		status_manager.apply_status(target, status_data)
	elif target.has_method("apply_status"):
		target.apply_status(status_type, duration)

## 播放链式视觉效果
func _play_chain_visual(from_pos: Vector2, to_pos: Vector2, chain_data: ChainActionData) -> void:
	# 创建链式线条
	var chain_line = Line2D.new()
	chain_line.name = "ChainLine"
	chain_line.width = 3.0
	chain_line.default_color = _get_chain_color(chain_data.chain_type)
	chain_line.add_point(from_pos)
	chain_line.add_point(to_pos)
	
	# 添加到场景
	get_tree().current_scene.add_child(chain_line)
	
	# 创建淡出动画
	var tween = create_tween()
	tween.tween_property(chain_line, "modulate:a", 0.0, 0.3)
	tween.tween_callback(chain_line.queue_free)

## 获取链式颜色
func _get_chain_color(chain_type: ChainActionData.ChainType) -> Color:
	match chain_type:
		ChainActionData.ChainType.LIGHTNING:
			return Color(0.8, 0.9, 1.0)  # 淡蓝白色
		ChainActionData.ChainType.FIRE:
			return Color(1.0, 0.5, 0.2)  # 橙红色
		ChainActionData.ChainType.ICE:
			return Color(0.4, 0.8, 1.0)  # 冰蓝色
		ChainActionData.ChainType.VOID:
			return Color(0.6, 0.2, 0.8)  # 紫色
	return Color.WHITE

## 获取活跃链式数量
func get_active_chain_count() -> int:
	return active_chains.size()

## 中断所有链式
func interrupt_all_chains() -> void:
	for chain in active_chains:
		chain_ended.emit(chain.current_target, chain.jump_count, chain.total_damage)
	active_chains.clear()
