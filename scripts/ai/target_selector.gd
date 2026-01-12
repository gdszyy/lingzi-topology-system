class_name TargetSelector extends Node

## AI目标选择器
## 负责根据战术规则选择攻击目标和目标肢体
## 实现战术性的肢体目标选择

signal target_selected(target: Node2D, part_type: int)
signal targeting_strategy_changed(strategy: String)

## 目标选择模式
enum SelectionMode {
	NEAREST,           # 最近目标
	LOWEST_HEALTH,     # 生命值最低
	HIGHEST_THREAT,    # 威胁度最高
	RANDOM,            # 随机
	PRIORITY_BASED     # 基于优先级规则
}

@export var selection_mode: SelectionMode = SelectionMode.PRIORITY_BASED
@export var use_body_part_targeting: bool = true
@export var targeting_priorities: Array[AITargetingPriority] = []

## 内部状态
var owner_node: Node2D = null
var perception_system: PerceptionSystem = null
var current_target: Node2D = null
var current_target_part: int = -1  # -1 表示不针对特定肢体

func _ready() -> void:
	owner_node = get_parent()
	
	# 查找感知系统
	perception_system = owner_node.get_node_or_null("Perception")

## 选择最佳攻击目标
func select_target() -> Node2D:
	if perception_system == null:
		return null
	
	var targets = perception_system.known_targets.keys()
	if targets.is_empty():
		return null
	
	match selection_mode:
		SelectionMode.NEAREST:
			current_target = _select_nearest(targets)
		SelectionMode.LOWEST_HEALTH:
			current_target = _select_lowest_health(targets)
		SelectionMode.HIGHEST_THREAT:
			current_target = _select_highest_threat(targets)
		SelectionMode.RANDOM:
			current_target = _select_random(targets)
		SelectionMode.PRIORITY_BASED:
			current_target = _select_by_priority(targets)
	
	return current_target

## 选择目标肢体
func select_body_part(target: Node2D) -> int:
	if not use_body_part_targeting:
		return -1
	
	if target == null:
		return -1
	
	# 检查目标是否有肢体系统
	if not target.has_method("get_body_parts"):
		return -1
	
	var body_parts = target.get_body_parts()
	if body_parts.is_empty():
		return -1
	
	# 构建战局上下文
	var context = _build_targeting_context(target)
	
	# 计算每个肢体的优先级分数
	var best_part_type: int = -1
	var best_score: float = -1.0
	
	for priority in targeting_priorities:
		# 检查条件
		if not priority.check_conditions(context):
			continue
		
		# 查找对应的肢体
		var part = _find_body_part(body_parts, priority.part_type)
		if part == null or not part.is_functional:
			continue
		
		# 更新上下文中的肢体信息
		var part_context = context.duplicate()
		part_context["part_health_percent"] = part.get_health_percent()
		part_context["part_has_spell"] = part.get_engraved_spells().size() > 0
		
		# 计算分数
		var score = priority.calculate_score(part_context)
		
		if score > best_score:
			best_score = score
			best_part_type = priority.part_type
	
	# 如果没有找到合适的肢体，默认攻击躯干
	if best_part_type < 0:
		best_part_type = BodyPartData.PartType.TORSO
	
	current_target_part = best_part_type
	target_selected.emit(target, best_part_type)
	
	return best_part_type

## 构建战局上下文
func _build_targeting_context(target: Node2D) -> Dictionary:
	var context = {}
	
	# AI自身状态
	if owner_node.has_method("get_health_percent"):
		context["ai_health_percent"] = owner_node.get_health_percent()
	else:
		context["ai_health_percent"] = 1.0
	
	# 距离
	context["distance"] = owner_node.global_position.distance_to(target.global_position)
	
	# 视线
	if perception_system != null:
		context["has_line_of_sight"] = perception_system.has_line_of_sight_to_target()
	else:
		context["has_line_of_sight"] = true
	
	# 目标状态
	if target.has_method("is_casting") or target.get("is_casting") != null:
		context["player_is_casting"] = target.is_casting if target.has_method("is_casting") else target.get("is_casting")
	else:
		context["player_is_casting"] = false
	
	if target.has_method("is_attacking") or target.get("is_attacking") != null:
		context["player_is_attacking"] = target.is_attacking if target.has_method("is_attacking") else target.get("is_attacking")
	else:
		context["player_is_attacking"] = false
	
	if target.has_method("is_flying") or target.get("is_flying") != null:
		context["player_is_flying"] = target.is_flying if target.has_method("is_flying") else target.get("is_flying")
	else:
		context["player_is_flying"] = false
	
	# 检查移动状态
	if target.has_method("get") and target.get("velocity") != null:
		context["player_is_moving"] = target.velocity.length_squared() > 100
	elif target.has_method("get_velocity"):
		context["player_is_moving"] = target.get_velocity().length_squared() > 100
	else:
		context["player_is_moving"] = false
	
	return context

## 查找指定类型的肢体
func _find_body_part(body_parts: Array, part_type: int) -> BodyPartData:
	for part in body_parts:
		if part.part_type == part_type:
			return part
	return null

## 选择最近目标
func _select_nearest(targets: Array) -> Node2D:
	var nearest: Node2D = null
	var min_distance: float = INF
	
	for target in targets:
		if not is_instance_valid(target):
			continue
		var distance = owner_node.global_position.distance_to(target.global_position)
		if distance < min_distance:
			min_distance = distance
			nearest = target
	
	return nearest

## 选择生命值最低的目标
func _select_lowest_health(targets: Array) -> Node2D:
	var best: Node2D = null
	var lowest_health: float = INF
	
	for target in targets:
		if not is_instance_valid(target):
			continue
		
		var health = 1.0
		if target.has_method("get_health_percent"):
			health = target.get_health_percent()
		elif target.has_method("get_current_health") and target.has_method("get_max_health"):
			var max_h = target.get_max_health()
			if max_h > 0:
				health = target.get_current_health() / max_h
		
		if health < lowest_health:
			lowest_health = health
			best = target
	
	return best

## 选择威胁度最高的目标
func _select_highest_threat(targets: Array) -> Node2D:
	if perception_system == null:
		return _select_nearest(targets)
	
	var best: Node2D = null
	var highest_threat: float = -1.0
	
	for target in targets:
		if not is_instance_valid(target):
			continue
		
		if target in perception_system.known_targets:
			var threat = perception_system.known_targets[target].threat_level
			if threat > highest_threat:
				highest_threat = threat
				best = target
	
	return best

## 随机选择目标
func _select_random(targets: Array) -> Node2D:
	var valid_targets: Array[Node2D] = []
	for target in targets:
		if is_instance_valid(target):
			valid_targets.append(target)
	
	if valid_targets.is_empty():
		return null
	
	return valid_targets[randi() % valid_targets.size()]

## 基于优先级选择目标
func _select_by_priority(targets: Array) -> Node2D:
	# 默认使用威胁度最高的目标
	return _select_highest_threat(targets)

## 获取当前目标
func get_current_target() -> Node2D:
	return current_target

## 获取当前目标肢体类型
func get_current_target_part() -> int:
	return current_target_part

## 设置目标优先级规则
func set_targeting_priorities(priorities: Array[AITargetingPriority]) -> void:
	targeting_priorities = priorities

## 添加目标优先级规则
func add_targeting_priority(priority: AITargetingPriority) -> void:
	targeting_priorities.append(priority)

## 清除目标优先级规则
func clear_targeting_priorities() -> void:
	targeting_priorities.clear()

## 创建默认的肢体目标优先级
func setup_default_priorities() -> void:
	targeting_priorities.clear()
	
	# 躯干 - 默认目标
	var torso = AITargetingPriority.create_torso_priority()
	targeting_priorities.append(torso)
	
	# 头部 - 高伤害目标
	var head = AITargetingPriority.create_head_priority()
	targeting_priorities.append(head)
	
	# 手部 - 打断施法
	var hand = AITargetingPriority.create_hand_priority()
	targeting_priorities.append(hand)
	
	# 腿部 - 限制移动
	var legs = AITargetingPriority.create_legs_priority()
	targeting_priorities.append(legs)
	
	# 手臂 - 削弱攻击
	var arm = AITargetingPriority.create_arm_priority()
	targeting_priorities.append(arm)

## 获取目标肢体名称
func get_target_part_name() -> String:
	if current_target_part < 0:
		return "无"
	
	match current_target_part:
		BodyPartData.PartType.HEAD:
			return "头部"
		BodyPartData.PartType.TORSO:
			return "躯干"
		BodyPartData.PartType.LEFT_ARM:
			return "左臂"
		BodyPartData.PartType.RIGHT_ARM:
			return "右臂"
		BodyPartData.PartType.LEFT_HAND:
			return "左手"
		BodyPartData.PartType.RIGHT_HAND:
			return "右手"
		BodyPartData.PartType.LEGS:
			return "腿部"
		BodyPartData.PartType.LEFT_FOOT:
			return "左脚"
		BodyPartData.PartType.RIGHT_FOOT:
			return "右脚"
	
	return "未知"
