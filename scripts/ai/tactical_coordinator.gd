class_name TacticalCoordinator extends Node

## 战术协调器
## 协调多个敌人AI的行为，实现团队战术
## 包括包围、协同攻击、掩护等战术

signal tactic_started(tactic_name: String)
signal tactic_completed(tactic_name: String)
signal formation_changed(formation_type: int)

enum FormationType {
	NONE,           # 无阵型
	SURROUND,       # 包围
	LINE,           # 一字排开
	WEDGE,          # 楔形
	PINCER,         # 钳形攻击
	SUPPORT         # 支援阵型（远程在后）
}

enum TacticType {
	NONE,
	FOCUS_FIRE,     # 集火攻击
	FLANK,          # 侧翼包抄
	RETREAT,        # 战术撤退
	PROTECT_HEALER, # 保护治疗者
	BAIT_AND_SWITCH # 诱敌战术
}

# 配置
@export var coordination_enabled: bool = true
@export var formation_update_interval: float = 0.5
@export var max_coordination_distance: float = 800.0

# 状态
var active_enemies: Array[EnemyAIController] = []
var current_formation: FormationType = FormationType.NONE
var current_tactic: TacticType = TacticType.NONE
var primary_target: Node2D = null
var formation_positions: Dictionary = {}  # enemy -> target_position

# 内部
var _formation_timer: float = 0.0
var _tactic_timer: float = 0.0

func _ready() -> void:
	# 定期更新敌人列表
	_update_enemy_list()

func _process(delta: float) -> void:
	if not coordination_enabled:
		return
	
	_formation_timer += delta
	if _formation_timer >= formation_update_interval:
		_formation_timer = 0.0
		_update_coordination()

## 更新敌人列表
func _update_enemy_list() -> void:
	active_enemies.clear()
	for node in get_tree().get_nodes_in_group("enemies"):
		if node is EnemyAIController and is_instance_valid(node):
			active_enemies.append(node)

## 更新协调
func _update_coordination() -> void:
	_update_enemy_list()
	
	if active_enemies.is_empty():
		return
	
	# 确定主要目标
	_update_primary_target()
	
	if primary_target == null:
		return
	
	# 根据敌人组成选择战术
	_select_tactic()
	
	# 更新阵型
	_update_formation()
	
	# 分配阵型位置
	_assign_formation_positions()

## 更新主要目标
func _update_primary_target() -> void:
	# 找到玩家作为主要目标
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		primary_target = players[0]
	else:
		# 找任意一个敌人的目标
		for enemy in active_enemies:
			if enemy.current_target != null:
				primary_target = enemy.current_target
				break

## 选择战术
func _select_tactic() -> void:
	if active_enemies.size() < 2:
		current_tactic = TacticType.NONE
		return
	
	# 分析敌人组成
	var melee_count = 0
	var ranged_count = 0
	var healer_count = 0
	var low_health_count = 0
	
	for enemy in active_enemies:
		if enemy.behavior_profile == null:
			continue
		
		match enemy.behavior_profile.archetype:
			AIBehaviorProfile.AIArchetype.MELEE_AGGRESSIVE, AIBehaviorProfile.AIArchetype.ASSASSIN:
				melee_count += 1
			AIBehaviorProfile.AIArchetype.RANGED_SNIPER, AIBehaviorProfile.AIArchetype.RANGED_MOBILE:
				ranged_count += 1
			AIBehaviorProfile.AIArchetype.SUPPORT_HEALER:
				healer_count += 1
		
		if enemy.get_health_percent() < 0.3:
			low_health_count += 1
	
	# 根据组成选择战术
	if healer_count > 0:
		current_tactic = TacticType.PROTECT_HEALER
	elif low_health_count > active_enemies.size() / 2:
		current_tactic = TacticType.RETREAT
	elif melee_count >= 2 and ranged_count >= 1:
		current_tactic = TacticType.FLANK
	elif active_enemies.size() >= 3:
		current_tactic = TacticType.FOCUS_FIRE
	else:
		current_tactic = TacticType.NONE

## 更新阵型
func _update_formation() -> void:
	var old_formation = current_formation
	
	# 根据战术和敌人数量选择阵型
	match current_tactic:
		TacticType.FOCUS_FIRE:
			current_formation = FormationType.SURROUND
		TacticType.FLANK:
			current_formation = FormationType.PINCER
		TacticType.PROTECT_HEALER:
			current_formation = FormationType.SUPPORT
		TacticType.RETREAT:
			current_formation = FormationType.LINE
		_:
			if active_enemies.size() >= 4:
				current_formation = FormationType.SURROUND
			else:
				current_formation = FormationType.NONE
	
	if current_formation != old_formation:
		formation_changed.emit(current_formation)

## 分配阵型位置
func _assign_formation_positions() -> void:
	if primary_target == null or active_enemies.is_empty():
		return
	
	formation_positions.clear()
	
	match current_formation:
		FormationType.SURROUND:
			_assign_surround_positions()
		FormationType.LINE:
			_assign_line_positions()
		FormationType.WEDGE:
			_assign_wedge_positions()
		FormationType.PINCER:
			_assign_pincer_positions()
		FormationType.SUPPORT:
			_assign_support_positions()

## 包围阵型
func _assign_surround_positions() -> void:
	var target_pos = primary_target.global_position
	var count = active_enemies.size()
	var base_distance = 150.0
	
	for i in range(count):
		var angle = (TAU / count) * i
		var distance = base_distance + randf_range(-20, 20)
		var pos = target_pos + Vector2(cos(angle), sin(angle)) * distance
		formation_positions[active_enemies[i]] = pos
		
		# 通知敌人目标位置
		_notify_enemy_position(active_enemies[i], pos)

## 一字阵型
func _assign_line_positions() -> void:
	var target_pos = primary_target.global_position
	var count = active_enemies.size()
	var spacing = 80.0
	var distance = 200.0
	
	# 计算撤退方向（远离目标）
	var avg_pos = Vector2.ZERO
	for enemy in active_enemies:
		avg_pos += enemy.global_position
	avg_pos /= count
	
	var retreat_dir = (avg_pos - target_pos).normalized()
	var line_center = target_pos + retreat_dir * distance
	var line_perpendicular = retreat_dir.rotated(PI / 2)
	
	for i in range(count):
		var offset = (i - count / 2.0) * spacing
		var pos = line_center + line_perpendicular * offset
		formation_positions[active_enemies[i]] = pos
		_notify_enemy_position(active_enemies[i], pos)

## 楔形阵型
func _assign_wedge_positions() -> void:
	var target_pos = primary_target.global_position
	var count = active_enemies.size()
	
	# 找到最强的敌人作为尖端
	var leader = _find_strongest_enemy()
	var leader_dir = (target_pos - leader.global_position).normalized()
	var leader_pos = target_pos - leader_dir * 100
	
	formation_positions[leader] = leader_pos
	_notify_enemy_position(leader, leader_pos)
	
	# 其他敌人排成V形
	var others = active_enemies.filter(func(e): return e != leader)
	var wing_angle = PI / 4
	var spacing = 60.0
	
	for i in range(others.size()):
		var side = 1 if i % 2 == 0 else -1
		var row = (i / 2) + 1
		var angle = leader_dir.angle() + side * wing_angle
		var pos = leader_pos - Vector2(cos(angle), sin(angle)) * spacing * row
		formation_positions[others[i]] = pos
		_notify_enemy_position(others[i], pos)

## 钳形阵型
func _assign_pincer_positions() -> void:
	var target_pos = primary_target.global_position
	var count = active_enemies.size()
	
	# 分成两组
	var left_group: Array[EnemyAIController] = []
	var right_group: Array[EnemyAIController] = []
	
	for i in range(count):
		if i % 2 == 0:
			left_group.append(active_enemies[i])
		else:
			right_group.append(active_enemies[i])
	
	var flank_angle = PI / 3
	var distance = 180.0
	
	# 左翼
	for i in range(left_group.size()):
		var angle = PI + flank_angle + i * 0.3
		var pos = target_pos + Vector2(cos(angle), sin(angle)) * distance
		formation_positions[left_group[i]] = pos
		_notify_enemy_position(left_group[i], pos)
	
	# 右翼
	for i in range(right_group.size()):
		var angle = PI - flank_angle - i * 0.3
		var pos = target_pos + Vector2(cos(angle), sin(angle)) * distance
		formation_positions[right_group[i]] = pos
		_notify_enemy_position(right_group[i], pos)

## 支援阵型
func _assign_support_positions() -> void:
	var target_pos = primary_target.global_position
	
	# 分类敌人
	var front_line: Array[EnemyAIController] = []
	var back_line: Array[EnemyAIController] = []
	
	for enemy in active_enemies:
		if enemy.behavior_profile == null:
			front_line.append(enemy)
			continue
		
		match enemy.behavior_profile.archetype:
			AIBehaviorProfile.AIArchetype.RANGED_SNIPER, AIBehaviorProfile.AIArchetype.RANGED_MOBILE, AIBehaviorProfile.AIArchetype.SUPPORT_HEALER:
				back_line.append(enemy)
			_:
				front_line.append(enemy)
	
	# 前排包围目标
	var front_distance = 120.0
	for i in range(front_line.size()):
		var angle = (TAU / max(1, front_line.size())) * i
		var pos = target_pos + Vector2(cos(angle), sin(angle)) * front_distance
		formation_positions[front_line[i]] = pos
		_notify_enemy_position(front_line[i], pos)
	
	# 后排保持距离
	var back_distance = 280.0
	for i in range(back_line.size()):
		var angle = (TAU / max(1, back_line.size())) * i + PI / 4
		var pos = target_pos + Vector2(cos(angle), sin(angle)) * back_distance
		formation_positions[back_line[i]] = pos
		_notify_enemy_position(back_line[i], pos)

## 通知敌人目标位置
func _notify_enemy_position(enemy: EnemyAIController, pos: Vector2) -> void:
	if enemy.has_method("set_tactical_position"):
		enemy.set_tactical_position(pos)
	else:
		# 直接设置目标位置
		enemy.target_position = pos

## 找到最强的敌人
func _find_strongest_enemy() -> EnemyAIController:
	var strongest: EnemyAIController = null
	var highest_health = 0.0
	
	for enemy in active_enemies:
		var health = enemy.get_health_percent()
		if health > highest_health:
			highest_health = health
			strongest = enemy
	
	return strongest if strongest else active_enemies[0]

## 请求集火攻击
func request_focus_fire(target: Node2D) -> void:
	primary_target = target
	current_tactic = TacticType.FOCUS_FIRE
	
	for enemy in active_enemies:
		if enemy.has_method("set_priority_target"):
			enemy.set_priority_target(target)
		else:
			enemy.current_target = target
	
	tactic_started.emit("focus_fire")

## 请求撤退
func request_retreat() -> void:
	current_tactic = TacticType.RETREAT
	current_formation = FormationType.LINE
	
	for enemy in active_enemies:
		if enemy.has_method("request_retreat"):
			enemy.request_retreat()
	
	tactic_started.emit("retreat")

## 获取敌人的阵型位置
func get_formation_position(enemy: EnemyAIController) -> Vector2:
	return formation_positions.get(enemy, enemy.global_position)

## 检查敌人是否在阵型位置
func is_in_formation(enemy: EnemyAIController, tolerance: float = 30.0) -> bool:
	if not formation_positions.has(enemy):
		return true
	
	var target_pos = formation_positions[enemy]
	return enemy.global_position.distance_to(target_pos) <= tolerance

## 获取当前战术名称
func get_tactic_name() -> String:
	match current_tactic:
		TacticType.FOCUS_FIRE:
			return "集火攻击"
		TacticType.FLANK:
			return "侧翼包抄"
		TacticType.RETREAT:
			return "战术撤退"
		TacticType.PROTECT_HEALER:
			return "保护治疗者"
		TacticType.BAIT_AND_SWITCH:
			return "诱敌战术"
		_:
			return "无"

## 获取当前阵型名称
func get_formation_name() -> String:
	match current_formation:
		FormationType.SURROUND:
			return "包围"
		FormationType.LINE:
			return "一字"
		FormationType.WEDGE:
			return "楔形"
		FormationType.PINCER:
			return "钳形"
		FormationType.SUPPORT:
			return "支援"
		_:
			return "无"
