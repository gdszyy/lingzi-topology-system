class_name PerceptionSystem extends Area2D

## AI感知系统
## 负责探测和追踪目标（玩家、敌人等）
## 支持视野范围、视线检测、记忆系统

signal target_detected(target: Node2D)
signal target_lost(target: Node2D)
signal target_entered_range(target: Node2D, range_type: RangeType)
signal target_exited_range(target: Node2D, range_type: RangeType)
signal threat_level_changed(new_level: float)

enum RangeType {
	PERCEPTION,   # 感知范围
	ATTACK,       # 攻击范围
	MELEE,        # 近战范围
	ALERT         # 警戒范围
}

## 感知配置
@export var perception_radius: float = 500.0:
	set(value):
		perception_radius = value
		_update_collision_shape()

@export var attack_radius: float = 150.0
@export var melee_radius: float = 50.0
@export var alert_radius: float = 200.0

@export var peripheral_vision_angle: float = 120.0  # 周边视野角度
@export var line_of_sight_required: bool = true
@export var memory_duration: float = 5.0

## 目标过滤
@export var target_groups: Array[String] = ["players"]
@export var ignore_groups: Array[String] = []

## 当前状态
var current_target: Node2D = null
var known_targets: Dictionary = {}  # target -> {last_seen_time, last_position, threat_level}
var threat_level: float = 0.0

## 内部引用
var owner_node: Node2D = null
var raycast: RayCast2D = null

func _ready() -> void:
	owner_node = get_parent()
	
	# 设置碰撞形状
	_setup_collision_shape()
	
	# 设置射线检测
	_setup_raycast()
	
	# 连接信号
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

func _physics_process(delta: float) -> void:
	_update_known_targets(delta)
	_update_current_target()
	_update_threat_level()
	_check_line_of_sight()

## 设置碰撞形状
func _setup_collision_shape() -> void:
	var shape = get_node_or_null("CollisionShape2D")
	if shape == null:
		shape = CollisionShape2D.new()
		shape.name = "CollisionShape2D"
		add_child(shape)
	
	var circle = CircleShape2D.new()
	circle.radius = perception_radius
	shape.shape = circle

func _update_collision_shape() -> void:
	var shape = get_node_or_null("CollisionShape2D")
	if shape and shape.shape is CircleShape2D:
		shape.shape.radius = perception_radius

## 设置射线检测
func _setup_raycast() -> void:
	raycast = get_node_or_null("RayCast2D")
	if raycast == null:
		raycast = RayCast2D.new()
		raycast.name = "RayCast2D"
		raycast.enabled = true
		add_child(raycast)

## 更新已知目标列表
func _update_known_targets(delta: float) -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	var targets_to_remove: Array[Node2D] = []
	
	for target in known_targets.keys():
		if not is_instance_valid(target):
			targets_to_remove.append(target)
			continue
		
		var info = known_targets[target]
		var time_since_seen = current_time - info.last_seen_time
		
		# 如果超过记忆时间，移除目标
		if time_since_seen > memory_duration:
			targets_to_remove.append(target)
			if target == current_target:
				target_lost.emit(target)
	
	for target in targets_to_remove:
		known_targets.erase(target)

## 更新当前目标
func _update_current_target() -> void:
	if known_targets.is_empty():
		if current_target != null:
			var old_target = current_target
			current_target = null
			target_lost.emit(old_target)
		return
	
	# 选择威胁度最高的目标
	var best_target: Node2D = null
	var best_threat: float = -1.0
	
	for target in known_targets.keys():
		var info = known_targets[target]
		if info.threat_level > best_threat:
			best_threat = info.threat_level
			best_target = target
	
	if best_target != current_target:
		var old_target = current_target
		current_target = best_target
		if old_target != null:
			target_lost.emit(old_target)
		if current_target != null:
			target_detected.emit(current_target)

## 更新威胁等级
func _update_threat_level() -> void:
	var new_threat = 0.0
	
	for target in known_targets.keys():
		var info = known_targets[target]
		new_threat += info.threat_level
	
	if not is_equal_approx(new_threat, threat_level):
		threat_level = new_threat
		threat_level_changed.emit(threat_level)

## 检查视线
func _check_line_of_sight() -> void:
	if not line_of_sight_required or raycast == null:
		return
	
	for target in known_targets.keys():
		if not is_instance_valid(target):
			continue
		
		var direction = (target.global_position - global_position).normalized()
		raycast.target_position = direction * perception_radius
		raycast.force_raycast_update()
		
		var has_los = not raycast.is_colliding() or raycast.get_collider() == target
		known_targets[target].has_line_of_sight = has_los

## 处理物体进入感知范围
func _on_body_entered(body: Node2D) -> void:
	if _is_valid_target(body):
		_add_target(body)

func _on_body_exited(body: Node2D) -> void:
	if body in known_targets:
		_update_target_range(body)

func _on_area_entered(area: Area2D) -> void:
	var parent = area.get_parent()
	if parent is Node2D and _is_valid_target(parent):
		_add_target(parent)

func _on_area_exited(area: Area2D) -> void:
	var parent = area.get_parent()
	if parent in known_targets:
		_update_target_range(parent)

## 检查是否为有效目标
func _is_valid_target(node: Node2D) -> bool:
	if node == owner_node:
		return false
	
	# 检查忽略组
	for group in ignore_groups:
		if node.is_in_group(group):
			return false
	
	# 检查目标组
	for group in target_groups:
		if node.is_in_group(group):
			return true
	
	return false

## 添加目标
func _add_target(target: Node2D) -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	
	if target not in known_targets:
		known_targets[target] = {
			"last_seen_time": current_time,
			"last_position": target.global_position,
			"threat_level": _calculate_threat_level(target),
			"has_line_of_sight": true,
			"range_type": _get_current_range_type(target)
		}
		target_entered_range.emit(target, RangeType.PERCEPTION)
	else:
		known_targets[target].last_seen_time = current_time
		known_targets[target].last_position = target.global_position

## 更新目标范围状态
func _update_target_range(target: Node2D) -> void:
	if target not in known_targets:
		return
	
	var old_range = known_targets[target].range_type
	var new_range = _get_current_range_type(target)
	
	if old_range != new_range:
		known_targets[target].range_type = new_range
		if new_range == RangeType.PERCEPTION:
			target_exited_range.emit(target, old_range)
		else:
			target_entered_range.emit(target, new_range)

## 获取当前范围类型
func _get_current_range_type(target: Node2D) -> RangeType:
	var distance = global_position.distance_to(target.global_position)
	
	if distance <= melee_radius:
		return RangeType.MELEE
	elif distance <= attack_radius:
		return RangeType.ATTACK
	elif distance <= alert_radius:
		return RangeType.ALERT
	else:
		return RangeType.PERCEPTION

## 计算威胁等级
func _calculate_threat_level(target: Node2D) -> float:
	var threat = 1.0
	var distance = global_position.distance_to(target.global_position)
	
	# 距离越近威胁越高
	threat += (1.0 - distance / perception_radius) * 2.0
	
	# 如果目标正在攻击，威胁更高
	if target.has_method("is_attacking") and target.is_attacking:
		threat += 1.5
	
	# 如果目标生命值低，威胁降低（更容易击杀）
	if target.has_method("get_health_percent"):
		var health_percent = target.get_health_percent()
		threat *= (0.5 + health_percent * 0.5)
	
	return threat

## 获取当前目标
func get_current_target() -> Node2D:
	return current_target

## 获取目标距离
func get_distance_to_target() -> float:
	if current_target == null:
		return INF
	return global_position.distance_to(current_target.global_position)

## 获取目标方向
func get_direction_to_target() -> Vector2:
	if current_target == null:
		return Vector2.ZERO
	return (current_target.global_position - global_position).normalized()

## 检查目标是否在攻击范围内
func is_target_in_attack_range() -> bool:
	return get_distance_to_target() <= attack_radius

## 检查目标是否在近战范围内
func is_target_in_melee_range() -> bool:
	return get_distance_to_target() <= melee_radius

## 检查是否有视线
func has_line_of_sight_to_target() -> bool:
	if current_target == null:
		return false
	if current_target not in known_targets:
		return false
	return known_targets[current_target].get("has_line_of_sight", true)

## 获取目标最后已知位置
func get_last_known_position() -> Vector2:
	if current_target != null and current_target in known_targets:
		return known_targets[current_target].last_position
	return Vector2.ZERO

## 强制更新目标位置
func update_target_position(target: Node2D) -> void:
	if target in known_targets:
		known_targets[target].last_seen_time = Time.get_ticks_msec() / 1000.0
		known_targets[target].last_position = target.global_position

## 清除所有目标
func clear_targets() -> void:
	for target in known_targets.keys():
		target_lost.emit(target)
	known_targets.clear()
	current_target = null
	threat_level = 0.0

## 手动添加目标（用于警报系统）
func alert_to_target(target: Node2D) -> void:
	if _is_valid_target(target):
		_add_target(target)
