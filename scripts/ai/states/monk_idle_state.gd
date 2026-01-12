extends State
class_name MonkIdleState

var monk: MonkAIController

func initialize(_owner: Node) -> void:
	super.initialize(_owner)
	monk = _owner as MonkAIController

func enter(_params: Dictionary = {}) -> void:
	monk.stop_movement()

func physics_update(_delta: float) -> void:
	# 检查是否有目标
	if monk.current_target != null:
		transition_to("MonkChase")
		return
	
	# 检查是否需要修炼
	if monk.get_health_percent() < monk.behavior_profile.cultivation_threshold:
		transition_to("MonkCultivate")
		return
	
	# 扫描周围敌人 (简化处理)
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if monk.global_position.distance_to(enemy.global_position) < monk.behavior_profile.perception_radius:
			monk.current_target = enemy
			if monk.team_manager != null:
				monk.team_manager.report_enemy(enemy)
			transition_to("MonkChase")
			break
