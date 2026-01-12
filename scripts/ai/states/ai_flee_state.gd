extends State
class_name AIFleeState

## AI逃跑状态
## 当生命值过低或其他条件满足时，敌人尝试远离玩家
## 支持寻找掩体和召唤援军

var ai: EnemyAIController

var flee_timer: float = 0.0
var max_flee_time: float = 10.0  # 最大逃跑时间
var safe_distance: float = 500.0  # 安全距离
var zigzag_timer: float = 0.0
var zigzag_direction: int = 1

func initialize(_owner: Node) -> void:
	super.initialize(_owner)
	ai = _owner as EnemyAIController

func enter(_params: Dictionary = {}) -> void:
	flee_timer = 0.0
	zigzag_timer = 0.0
	zigzag_direction = 1 if randf() > 0.5 else -1
	
	# 设置安全距离
	if ai.behavior_profile != null:
		safe_distance = ai.behavior_profile.max_chase_distance * 0.8

func exit() -> void:
	flee_timer = 0.0

func physics_update(delta: float) -> void:
	flee_timer += delta
	zigzag_timer += delta
	
	# 检查是否已经安全
	if _is_safe():
		transition_to("AIIdle")
		return
	
	# 检查逃跑时间限制
	if flee_timer > max_flee_time:
		# 逃跑失败，被迫战斗
		if ai.current_target != null:
			transition_to("AIChase")
		else:
			transition_to("AIIdle")
		return
	
	# 检查生命值是否恢复
	if ai.get_health_percent() > ai.behavior_profile.flee_health_threshold * 1.5 if ai.behavior_profile else 0.3:
		# 生命值恢复，重新战斗
		if ai.current_target != null:
			transition_to("AIChase")
		else:
			transition_to("AIIdle")
		return
	
	# 执行逃跑移动
	_flee_movement(delta)
	
	# 更新之字形方向
	if zigzag_timer > 0.5:
		zigzag_timer = 0.0
		zigzag_direction *= -1

## 检查是否安全
func _is_safe() -> bool:
	if ai.current_target == null:
		return true
	
	var distance = ai.get_distance_to_target()
	return distance >= safe_distance

## 逃跑移动
func _flee_movement(delta: float) -> void:
	if ai.current_target == null:
		# 没有目标，随机方向逃跑
		var random_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		ai.move_to(ai.global_position + random_direction * 100, delta)
		return
	
	# 计算逃跑方向（远离目标）
	var flee_direction = (ai.global_position - ai.current_target.global_position).normalized()
	
	# 添加之字形移动
	var perpendicular = flee_direction.rotated(PI / 2)
	var zigzag_offset = perpendicular * zigzag_direction * 0.3
	var final_direction = (flee_direction + zigzag_offset).normalized()
	
	# 计算目标位置
	var flee_target = ai.global_position + final_direction * 200
	
	# 执行逃跑
	ai.flee_from(ai.current_target, delta)
