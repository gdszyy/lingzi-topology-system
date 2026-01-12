extends State
class_name MonkChaseState

## 修士追击状态
## 负责接近目标，并根据行为配置保持合适的战斗距离

var monk: MonkAIController

func initialize(_owner: Node) -> void:
	super.initialize(_owner)
	monk = _owner as MonkAIController

func enter(_params: Dictionary = {}) -> void:
	print("[修士AI] %s 开始追击目标" % monk.name)

func physics_update(delta: float) -> void:
	var target = monk.current_target
	
	# 如果没有目标，尝试从团队获取
	if target == null and monk.team_manager != null:
		target = monk.team_manager.primary_target
		monk.current_target = target
	
	if target == null or not is_instance_valid(target):
		transition_to("MonkIdle")
		return
	
	var dist = monk.global_position.distance_to(target.global_position)
	var optimal_dist = monk.behavior_profile.engagement_distance
	
	if dist > optimal_dist + 20:
		# 太远，靠近
		monk.move_to(target.global_position)
	elif dist < monk.behavior_profile.min_engagement_distance:
		# 太近，后退
		var flee_dir = (monk.global_position - target.global_position).normalized()
		monk.velocity = flee_dir * monk.behavior_profile.move_speed
	else:
		# 距离合适，准备攻击或使用技能
		monk.stop_movement()
		
		# 检查是否可以使用技能/法术
		if _can_use_spells():
			transition_to("MonkUseSpell")
		else:
			# 基础攻击
			_perform_basic_attack()

func _can_use_spells() -> bool:
	# 检查能量和冷却逻辑
	return monk.energy_system.current_energy > 20.0

func _perform_basic_attack() -> void:
	# 这里可以调用基础攻击逻辑
	pass
