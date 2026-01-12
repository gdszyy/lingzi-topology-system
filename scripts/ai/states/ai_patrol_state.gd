extends State
class_name AIPatrolState

## AI巡逻状态
## 敌人在预设路径点之间移动
## 或在区域内随机移动

enum PatrolMode {
	WAYPOINTS,    # 路径点巡逻
	RANDOM_AREA,  # 区域内随机移动
	CIRCULAR      # 圆形巡逻
}

var ai: EnemyAIController

@export var patrol_mode: PatrolMode = PatrolMode.RANDOM_AREA
@export var waypoints: Array[Vector2] = []
@export var patrol_radius: float = 200.0
@export var wait_time_at_waypoint: float = 1.0

var current_waypoint_index: int = 0
var patrol_target: Vector2 = Vector2.ZERO
var start_position: Vector2 = Vector2.ZERO
var wait_timer: float = 0.0
var is_waiting: bool = false
var patrol_angle: float = 0.0  # 用于圆形巡逻

func initialize(_owner: Node) -> void:
	super.initialize(_owner)
	ai = _owner as EnemyAIController

func enter(_params: Dictionary = {}) -> void:
	start_position = ai.global_position
	wait_timer = 0.0
	is_waiting = false
	
	# 设置初始巡逻目标
	_set_next_patrol_target()

func exit() -> void:
	wait_timer = 0.0
	is_waiting = false

func physics_update(delta: float) -> void:
	# 检查是否发现目标
	if ai.current_target != null:
		transition_to("AIChase")
		return
	
	# 如果正在等待
	if is_waiting:
		wait_timer -= delta
		if wait_timer <= 0:
			is_waiting = false
			_set_next_patrol_target()
		return
	
	# 移动到巡逻目标
	var distance = ai.global_position.distance_to(patrol_target)
	
	if distance < 20.0:
		# 到达目标点
		ai.stop_movement()
		is_waiting = true
		wait_timer = wait_time_at_waypoint
	else:
		# 继续移动
		ai.move_to(patrol_target, delta)

## 设置下一个巡逻目标
func _set_next_patrol_target() -> void:
	match patrol_mode:
		PatrolMode.WAYPOINTS:
			_set_waypoint_target()
		PatrolMode.RANDOM_AREA:
			_set_random_target()
		PatrolMode.CIRCULAR:
			_set_circular_target()

## 设置路径点目标
func _set_waypoint_target() -> void:
	if waypoints.is_empty():
		# 如果没有路径点，切换到随机模式
		patrol_mode = PatrolMode.RANDOM_AREA
		_set_random_target()
		return
	
	current_waypoint_index = (current_waypoint_index + 1) % waypoints.size()
	patrol_target = waypoints[current_waypoint_index]

## 设置随机目标
func _set_random_target() -> void:
	var random_offset = Vector2(
		randf_range(-patrol_radius, patrol_radius),
		randf_range(-patrol_radius, patrol_radius)
	)
	patrol_target = start_position + random_offset

## 设置圆形巡逻目标
func _set_circular_target() -> void:
	patrol_angle += PI / 4  # 每次移动45度
	if patrol_angle >= TAU:
		patrol_angle -= TAU
	
	patrol_target = start_position + Vector2(
		cos(patrol_angle) * patrol_radius,
		sin(patrol_angle) * patrol_radius
	)

## 添加路径点
func add_waypoint(point: Vector2) -> void:
	waypoints.append(point)

## 清除路径点
func clear_waypoints() -> void:
	waypoints.clear()
	current_waypoint_index = 0

## 设置巡逻半径
func set_patrol_radius(radius: float) -> void:
	patrol_radius = radius
