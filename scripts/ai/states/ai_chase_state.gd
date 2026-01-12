extends State
class_name AIChaseState

## AI追击状态
## 敌人向目标移动，试图进入最佳攻击距离
## 支持横向移动和战术站位

var ai: EnemyAIController

var chase_timer: float = 0.0
var max_chase_time: float = 30.0  # 最大追击时间
var strafe_timer: float = 0.0
var strafe_direction: int = 1  # 1 = 右, -1 = 左
var last_target_position: Vector2 = Vector2.ZERO

func initialize(_owner: Node) -> void:
	super.initialize(_owner)
	ai = _owner as EnemyAIController

func enter(_params: Dictionary = {}) -> void:
	chase_timer = 0.0
	strafe_timer = 0.0
	strafe_direction = 1 if randf() > 0.5 else -1
	
	if ai.current_target != null:
		last_target_position = ai.current_target.global_position

func exit() -> void:
	chase_timer = 0.0

func physics_update(delta: float) -> void:
	chase_timer += delta
	strafe_timer += delta
	
	# 检查是否丢失目标
	if ai.current_target == null:
		# 尝试移动到最后已知位置
		if ai.global_position.distance_to(last_target_position) > 30:
			ai.move_to(last_target_position, delta)
		else:
			# 到达最后已知位置，返回空闲
			transition_to("AIIdle")
		return
	
	# 更新最后已知位置
	last_target_position = ai.current_target.global_position
	
	# 检查是否应该逃跑
	if ai.should_flee():
		transition_to("AIFlee")
		return
	
	# 检查追击距离限制
	var distance_from_start = ai.global_position.distance_to(ai.target_position)
	if ai.behavior_profile != null and distance_from_start > ai.behavior_profile.max_chase_distance:
		transition_to("AIIdle")
		return
	
	# 检查追击时间限制
	if chase_timer > max_chase_time:
		transition_to("AIIdle")
		return
	
	# 获取到目标的距离
	var distance = ai.get_distance_to_target()
	var optimal_distance = ai.behavior_profile.get_optimal_attack_distance() if ai.behavior_profile else 100.0
	var attack_range = ai.behavior_profile.attack_range if ai.behavior_profile else 100.0
	
	# 检查是否在攻击范围内
	if distance <= attack_range and ai.can_attack:
		transition_to("AIAttack")
		return
	
	# 检查是否应该使用技能
	if _should_use_skill():
		transition_to("AIUseSkill")
		return
	
	# 移动到最佳攻击距离
	ai.move_to_engagement_distance(ai.current_target, delta)
	
	# 更新横向移动方向
	if strafe_timer > ai.behavior_profile.strafe_frequency if ai.behavior_profile else 2.0:
		strafe_timer = 0.0
		strafe_direction *= -1

## 检查是否应该使用技能
func _should_use_skill() -> bool:
	if ai.behavior_profile == null:
		return false
	
	if not ai.behavior_profile.skill_usage_enabled:
		return false
	
	# 构建上下文
	var context = {
		"health_percent": ai.get_health_percent(),
		"current_energy": ai.energy_system.current_energy if ai.energy_system else 0.0,
		"distance_to_target": ai.get_distance_to_target(),
		"enemy_count": get_tree().get_nodes_in_group("players").size(),
		"ally_count": get_tree().get_nodes_in_group("enemies").size() - 1
	}
	
	if ai.current_target != null:
		context["target_is_casting"] = ai.current_target.get("is_casting") if ai.current_target.get("is_casting") != null else false
		context["target_is_attacking"] = ai.current_target.get("is_attacking") if ai.current_target.get("is_attacking") != null else false
	
	# 检查每个技能规则
	for rule in ai.behavior_profile.skill_usage_rules:
		if rule.can_use(context):
			return true
	
	return false
