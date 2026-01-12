class_name ChainSystem
extends Node
## 链式效果系统
## 统一管理所有链式效果的创建、执行和视觉表现

signal chain_started(source: Node, chain_data: ChainActionData)
signal chain_jumped(from_target: Node, to_target: Node, jump_index: int, damage: float)
signal chain_ended(final_target: Node, total_jumps: int, total_damage: float)
signal chain_status_applied(target: Node, status_type: int)
signal chain_forked(from_target: Node, fork_targets: Array[Node], fork_index: int)

var active_chains: Array[ChainInstance] = []

class ChainInstance:
	var data: ChainActionData
	var current_target: Node
	var hit_targets: Array[Node] = []
	var jump_count: int = 0
	var total_damage: float = 0.0
	var delay_timer: float = 0.0
	var is_waiting: bool = false
	var source_position: Vector2
	var is_fork: bool = false  # 标记是否为分叉链
	var parent_chain: ChainInstance = null  # 父链引用（用于分叉）

	func _init(chain_data: ChainActionData, first_target: Node, source_pos: Vector2):
		data = chain_data
		current_target = first_target
		hit_targets.append(first_target)
		source_position = source_pos

func _process(delta: float) -> void:
	_update_all_chains(delta)

func _update_all_chains(delta: float) -> void:
	var to_remove: Array[int] = []

	for i in range(active_chains.size()):
		var chain = active_chains[i]

		if chain.is_waiting:
			chain.delay_timer -= delta
			if chain.delay_timer <= 0:
				chain.is_waiting = false
				_process_next_jump(chain)

		if chain.jump_count >= chain.data.chain_count or chain.current_target == null:
			chain_ended.emit(chain.current_target, chain.jump_count, chain.total_damage)
			to_remove.append(i)

	for i in range(to_remove.size() - 1, -1, -1):
		active_chains.remove_at(to_remove[i])

## 启动链式效果（统一入口）
func start_chain(first_target: Node, chain_data: ChainActionData, source_position: Vector2) -> void:
	print("[ChainSystem] start_chain 被调用！目标=%s, 类型=%s, 链接数=%d" % [
		first_target.name if first_target else "null",
		chain_data.get_type_name(),
		chain_data.chain_count
	])
	
	if first_target == null or not is_instance_valid(first_target):
		print("[ChainSystem] 目标无效，取消链式效果")
		return

	var chain = ChainInstance.new(chain_data, first_target, source_position)
	active_chains.append(chain)

	chain_started.emit(first_target, chain_data)

	# 播放初始视觉效果（从来源到第一个目标）
	_play_chain_visual_segment(source_position, first_target.global_position, chain_data)

	# 对第一个目标造成伤害
	_apply_chain_damage(chain, first_target)

	# 如果链条次数大于1，设置延迟等待下一次跳跃
	if chain_data.chain_count > 1:
		chain.is_waiting = true
		chain.delay_timer = chain_data.chain_delay
	else:
		# 只有一次跳跃，直接结束
		chain.jump_count = chain_data.chain_count

func _process_next_jump(chain: ChainInstance) -> void:
	if chain.current_target == null or not is_instance_valid(chain.current_target):
		return

	# 检查是否触发分叉
	if chain.data.fork_chance > 0 and randf() < chain.data.fork_chance:
		_process_fork(chain)

	# 根据目标选择策略查找下一个目标
	var next_target = _find_next_chain_target(chain)

	if next_target == null:
		# 找不到下一个目标，结束该链
		chain.jump_count = chain.data.chain_count
		return

	var from_target = chain.current_target
	chain.current_target = next_target
	chain.hit_targets.append(next_target)
	chain.jump_count += 1

	# 播放链式视觉效果
	_play_chain_visual_segment(from_target.global_position, next_target.global_position, chain.data)

	# 造成伤害
	_apply_chain_damage(chain, next_target)

	var damage = chain.data.chain_damage * pow(chain.data.chain_damage_decay, chain.jump_count)
	chain_jumped.emit(from_target, next_target, chain.jump_count, damage)

	# 继续下一次跳跃
	if chain.jump_count < chain.data.chain_count:
		chain.is_waiting = true
		chain.delay_timer = chain.data.chain_delay

## 处理链式分叉
func _process_fork(chain: ChainInstance) -> void:
	var fork_targets: Array[Node] = []
	var current_pos = chain.current_target.global_position
	var search_range = chain.data.chain_range
	
	# 查找分叉目标（排除已击中的和当前目标）
	var candidates = _get_target_candidates(current_pos, search_range, chain.hit_targets, chain.data.chain_can_return)
	
	# 根据分叉数量选择目标
	var fork_count = mini(chain.data.fork_count, candidates.size())
	for i in range(fork_count):
		if i < candidates.size():
			var fork_target = candidates[i].target
			fork_targets.append(fork_target)
			
			# 创建分叉链实例
			var fork_chain_data = chain.data.clone_deep() as ChainActionData
			fork_chain_data.chain_count = maxi(1, chain.data.chain_count - chain.jump_count - 1)
			fork_chain_data.fork_chance = 0.0  # 分叉链不再分叉
			
			var fork_chain = ChainInstance.new(fork_chain_data, fork_target, current_pos)
			fork_chain.is_fork = true
			fork_chain.parent_chain = chain
			fork_chain.hit_targets = chain.hit_targets.duplicate()
			fork_chain.hit_targets.append(fork_target)
			
			active_chains.append(fork_chain)
			
			# 播放分叉视觉效果
			_play_chain_visual_segment(current_pos, fork_target.global_position, chain.data)
			
			# 对分叉目标造成伤害（衰减后的伤害）
			_apply_chain_damage(fork_chain, fork_target)
	
	if fork_targets.size() > 0:
		chain_forked.emit(chain.current_target, fork_targets, chain.jump_count)

## 根据目标选择策略查找下一个链式目标
func _find_next_chain_target(chain: ChainInstance) -> Node:
	var current_pos = chain.current_target.global_position
	var search_range = chain.data.chain_range

	var candidates = _get_target_candidates(current_pos, search_range, chain.hit_targets, chain.data.chain_can_return)

	if candidates.is_empty():
		return null

	# 根据目标选择策略排序
	match chain.data.target_selection:
		ChainActionData.TargetSelection.NEAREST:
			candidates.sort_custom(func(a, b): return a.distance < b.distance)
		
		ChainActionData.TargetSelection.RANDOM:
			candidates.shuffle()
		
		ChainActionData.TargetSelection.LOWEST_HEALTH:
			candidates.sort_custom(func(a, b): 
				var health_a = _get_target_health(a.target)
				var health_b = _get_target_health(b.target)
				return health_a < health_b
			)
		
		ChainActionData.TargetSelection.HIGHEST_HEALTH:
			candidates.sort_custom(func(a, b): 
				var health_a = _get_target_health(a.target)
				var health_b = _get_target_health(b.target)
				return health_a > health_b
			)

	return candidates[0].target

## 获取目标候选列表
func _get_target_candidates(current_pos: Vector2, search_range: float, exclude: Array[Node], can_return: bool) -> Array:
	var candidates: Array = []
	var all_enemies = get_tree().get_nodes_in_group("enemies")

	for enemy in all_enemies:
		if not is_instance_valid(enemy):
			continue

		# 排除当前目标，防止原地跳跃
		if enemy == exclude[-1]:
			continue

		# 检查是否可以返回已击中的目标
		if not can_return and enemy in exclude:
			continue

		var dist = enemy.global_position.distance_to(current_pos)
		# 允许距离非常近的目标
		if dist <= search_range:
			candidates.append({"target": enemy, "distance": dist})

	return candidates

## 获取目标的生命值
func _get_target_health(target: Node) -> float:
	if target.has_method("get_health"):
		return target.get_health()
	elif "health" in target:
		return target.health
	elif "current_health" in target:
		return target.current_health
	return 0.0

func _apply_chain_damage(chain: ChainInstance, target: Node) -> void:
	var damage = chain.data.chain_damage * pow(chain.data.chain_damage_decay, chain.jump_count)
	print("[ChainSystem] 对目标 %s 造成链式伤害: %.1f (跳跃次数=%d)" % [target.name, damage, chain.jump_count])

	if target.has_method("take_damage"):
		target.take_damage(damage)
		chain.total_damage += damage
		print("[ChainSystem] 伤害已应用，总伤害=%.1f" % chain.total_damage)
	else:
		print("[ChainSystem] 警告：目标 %s 没有 take_damage 方法！" % target.name)

	_apply_chain_status(chain, target)

func _apply_chain_status(chain: ChainInstance, target: Node) -> void:
	var status_type = chain.data.apply_status_type
	var status_duration = chain.data.apply_status_duration

	if status_type < 0 or status_duration <= 0:
		return

	match chain.data.chain_type:
		ChainActionData.ChainType.LIGHTNING:
			if target.has_method("apply_stun"):
				target.apply_stun(status_duration * 0.3)

		ChainActionData.ChainType.FIRE:
			_apply_status_to_target(target, ApplyStatusActionData.StatusType.ENTROPY_BURN, status_duration)

		ChainActionData.ChainType.ICE:
			_apply_status_to_target(target, ApplyStatusActionData.StatusType.CRYO_CRYSTAL, status_duration)

		ChainActionData.ChainType.VOID:
			_apply_status_to_target(target, ApplyStatusActionData.StatusType.RESONANCE_MARK, status_duration)

	chain_status_applied.emit(target, status_type)

func _apply_status_to_target(target: Node, status_type: ApplyStatusActionData.StatusType, duration: float) -> void:
	var status_manager = get_tree().get_first_node_in_group("status_effect_manager")

	if status_manager != null and status_manager.has_method("apply_status"):
		var status_data = ApplyStatusActionData.new()
		status_data.status_type = status_type
		status_data.duration = duration
		# 确保同步相态
		status_data._sync_phase_from_status()
		status_manager.apply_status(target, status_data)
	elif target.has_method("apply_status"):
		# 回退方案：如果目标自己实现了 apply_status
		target.apply_status(status_type, duration)

## 播放单段链式视觉效果
func _play_chain_visual_segment(from_pos: Vector2, to_pos: Vector2, chain_data: ChainActionData) -> void:
	print("[ChainSystem] 播放链式视觉效果: 从 %s 到 %s" % [from_pos, to_pos])
	var chain_line = Line2D.new()
	chain_line.name = "ChainSegment"
	chain_line.width = chain_data.chain_visual_width
	chain_line.z_index = 100 # 确保在上方显示
	
	# 获取链类型颜色
	var colors = VFXManager.CHAIN_TYPE_COLORS.get(
		chain_data.chain_type,
		VFXManager.CHAIN_TYPE_COLORS[ChainActionData.ChainType.LIGHTNING]
	)
	chain_line.default_color = colors.primary
	
	# 使用全局坐标
	chain_line.global_position = Vector2.ZERO
	chain_line.points = _create_chain_path(from_pos, to_pos, chain_data.chain_type)
	
	# 添加发光效果
	var glow_line = Line2D.new()
	glow_line.width = chain_data.chain_visual_width * 2.5
	glow_line.default_color = colors.glow
	glow_line.default_color.a = 0.4
	glow_line.points = chain_line.points
	chain_line.add_child(glow_line)
	
	var scene_root = get_tree().current_scene
	if scene_root:
		scene_root.add_child(chain_line)
	
	# 创建撞击效果
	_create_impact_effect(to_pos, colors)

	# 动画效果
	var tween = create_tween()
	chain_line.modulate.a = 0.0
	tween.tween_property(chain_line, "modulate:a", 1.0, 0.05)
	tween.tween_property(chain_line, "modulate:a", 0.5, 0.05)
	tween.tween_property(chain_line, "modulate:a", 1.0, 0.05)
	tween.tween_property(chain_line, "modulate:a", 0.0, 0.3)
	tween.tween_callback(chain_line.queue_free)

## 根据链类型创建路径
func _create_chain_path(from_pos: Vector2, to_pos: Vector2, chain_type: ChainActionData.ChainType) -> PackedVector2Array:
	match chain_type:
		ChainActionData.ChainType.LIGHTNING:
			return _create_lightning_path(from_pos, to_pos)
		ChainActionData.ChainType.FIRE:
			return _create_fire_path(from_pos, to_pos)
		ChainActionData.ChainType.ICE:
			return _create_ice_path(from_pos, to_pos)
		ChainActionData.ChainType.VOID:
			return _create_void_path(from_pos, to_pos)
	return PackedVector2Array([from_pos, to_pos])

func _create_lightning_path(from_pos: Vector2, to_pos: Vector2) -> PackedVector2Array:
	var points: PackedVector2Array = []
	var direction = to_pos - from_pos
	var distance = direction.length()
	var segments = int(distance / 20.0) + 2
	
	points.append(from_pos)
	
	for i in range(1, segments):
		var t = float(i) / segments
		var base_pos = from_pos.lerp(to_pos, t)
		var perpendicular = direction.normalized().rotated(PI / 2.0)
		var offset = perpendicular * randf_range(-15.0, 15.0)
		points.append(base_pos + offset)
	
	points.append(to_pos)
	return points

func _create_fire_path(from_pos: Vector2, to_pos: Vector2) -> PackedVector2Array:
	var points: PackedVector2Array = []
	var direction = to_pos - from_pos
	var distance = direction.length()
	var segments = int(distance / 15.0) + 2
	
	points.append(from_pos)
	
	for i in range(1, segments):
		var t = float(i) / segments
		var base_pos = from_pos.lerp(to_pos, t)
		var perpendicular = direction.normalized().rotated(PI / 2.0)
		var offset = perpendicular * sin(t * PI * 4) * 10.0
		points.append(base_pos + offset)
	
	points.append(to_pos)
	return points

func _create_ice_path(from_pos: Vector2, to_pos: Vector2) -> PackedVector2Array:
	var points: PackedVector2Array = []
	var direction = to_pos - from_pos
	var distance = direction.length()
	var segments = int(distance / 25.0) + 2
	
	points.append(from_pos)
	
	for i in range(1, segments):
		var t = float(i) / segments
		var base_pos = from_pos.lerp(to_pos, t)
		var perpendicular = direction.normalized().rotated(PI / 2.0)
		var offset = perpendicular * (10.0 if i % 2 == 0 else -10.0)
		points.append(base_pos + offset)
	
	points.append(to_pos)
	return points

func _create_void_path(from_pos: Vector2, to_pos: Vector2) -> PackedVector2Array:
	var points: PackedVector2Array = []
	var direction = to_pos - from_pos
	var distance = direction.length()
	var segments = int(distance / 10.0) + 2
	
	points.append(from_pos)
	
	for i in range(1, segments):
		var t = float(i) / segments
		var base_pos = from_pos.lerp(to_pos, t)
		var perpendicular = direction.normalized().rotated(PI / 2.0)
		var offset = perpendicular * sin(t * PI * 6) * (1.0 - t) * 12.0
		points.append(base_pos + offset)
	
	points.append(to_pos)
	return points

## 创建撞击效果
func _create_impact_effect(pos: Vector2, colors: Dictionary) -> void:
	var container = Node2D.new()
	container.global_position = pos
	
	# 命中闪光
	var flash = Polygon2D.new()
	var points: PackedVector2Array = []
	var segments = 12
	var radius = 15.0
	
	for i in range(segments):
		var angle = i * TAU / segments
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	
	flash.polygon = points
	flash.color = colors.get("secondary", Color.WHITE)
	flash.scale = Vector2.ZERO
	container.add_child(flash)
	
	var scene_root = get_tree().current_scene
	if scene_root:
		scene_root.add_child(container)
	
	# 闪光动画
	var tween = create_tween()
	tween.tween_property(flash, "scale", Vector2.ONE, 0.1).set_ease(Tween.EASE_OUT)
	tween.tween_property(flash, "scale", Vector2.ZERO, 0.15).set_ease(Tween.EASE_IN)
	tween.tween_callback(container.queue_free)

func get_active_chain_count() -> int:
	return active_chains.size()

func interrupt_all_chains() -> void:
	for chain in active_chains:
		chain_ended.emit(chain.current_target, chain.jump_count, chain.total_damage)
	active_chains.clear()
