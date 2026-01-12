class_name ChainSystem
extends Node

signal chain_started(source: Node, chain_data: ChainActionData)
signal chain_jumped(from_target: Node, to_target: Node, jump_index: int, damage: float)
signal chain_ended(final_target: Node, total_jumps: int, total_damage: float)
signal chain_status_applied(target: Node, status_type: int)

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

func start_chain(first_target: Node, chain_data: ChainActionData, source_position: Vector2) -> void:
	if first_target == null or not is_instance_valid(first_target):
		return

	var chain = ChainInstance.new(chain_data, first_target, source_position)
	active_chains.append(chain)

	chain_started.emit(first_target, chain_data)

	_apply_chain_damage(chain, first_target)

	chain.is_waiting = true
	chain.delay_timer = chain_data.chain_delay

func _process_next_jump(chain: ChainInstance) -> void:
	if chain.current_target == null or not is_instance_valid(chain.current_target):
		return

	var next_target = _find_next_chain_target(chain)

	if next_target == null:
		return

	var from_target = chain.current_target
	chain.current_target = next_target
	chain.hit_targets.append(next_target)
	chain.jump_count += 1

	_play_chain_visual(from_target.global_position, next_target.global_position, chain.data)

	_apply_chain_damage(chain, next_target)

	chain_jumped.emit(from_target, next_target, chain.jump_count, chain.data.chain_damage * pow(chain.data.chain_damage_decay, chain.jump_count))

	if chain.jump_count < chain.data.chain_count:
		chain.is_waiting = true
		chain.delay_timer = chain.data.chain_delay

func _find_next_chain_target(chain: ChainInstance) -> Node:
	var current_pos = chain.current_target.global_position
	var search_range = chain.data.chain_range

	var candidates: Array = []
	var all_enemies = get_tree().get_nodes_in_group("enemies")

	for enemy in all_enemies:
		if not is_instance_valid(enemy):
			continue

		if not chain.data.chain_can_return and enemy in chain.hit_targets:
			continue

		var dist = enemy.global_position.distance_to(current_pos)
		if dist <= search_range and dist > 0:
			candidates.append({"target": enemy, "distance": dist})

	if candidates.is_empty():
		return null

	candidates.sort_custom(func(a, b): return a.distance < b.distance)

	return candidates[0].target

func _apply_chain_damage(chain: ChainInstance, target: Node) -> void:
	var damage = chain.data.chain_damage * pow(chain.data.chain_damage_decay, chain.jump_count)

	if target.has_method("take_damage"):
		target.take_damage(damage)
		chain.total_damage += damage

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
		status_manager.apply_status(target, status_data)
	elif target.has_method("apply_status"):
		target.apply_status(status_type, duration)

func _play_chain_visual(from_pos: Vector2, to_pos: Vector2, chain_data: ChainActionData) -> void:
	var chain_line = Line2D.new()
	chain_line.name = "ChainLine"
	chain_line.width = 3.0
	chain_line.default_color = _get_chain_color(chain_data.chain_type)
	chain_line.add_point(from_pos)
	chain_line.add_point(to_pos)

	get_tree().current_scene.add_child(chain_line)

	var tween = create_tween()
	tween.tween_property(chain_line, "modulate:a", 0.0, 0.3)
	tween.tween_callback(chain_line.queue_free)

func _get_chain_color(chain_type: ChainActionData.ChainType) -> Color:
	match chain_type:
		ChainActionData.ChainType.LIGHTNING:
			return Color(0.8, 0.9, 1.0)
		ChainActionData.ChainType.FIRE:
			return Color(1.0, 0.5, 0.2)
		ChainActionData.ChainType.ICE:
			return Color(0.4, 0.8, 1.0)
		ChainActionData.ChainType.VOID:
			return Color(0.6, 0.2, 0.8)
	return Color.WHITE

func get_active_chain_count() -> int:
	return active_chains.size()

func interrupt_all_chains() -> void:
	for chain in active_chains:
		chain_ended.emit(chain.current_target, chain.jump_count, chain.total_damage)
	active_chains.clear()
