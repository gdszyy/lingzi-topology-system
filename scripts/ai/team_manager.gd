class_name TeamManager extends Node

## 团队管理器
## 负责管理一组修士AI，协调战术，共享情报

# 信号
signal team_target_changed(new_target: Node2D)
signal tactical_state_changed(old_state: String, new_state: String)

enum TacticalState {
	IDLE,       # 待命
	SEARCH,     # 搜索
	ENGAGE,     # 交战
	FOCUS_FIRE, # 集火
	RETREAT     # 撤退
}

@export var team_id: int = 0
@export var current_tactical_state: TacticalState = TacticalState.IDLE

var members: Array[MonkAIController] = []
var known_enemies: Array[Node2D] = []
var primary_target: Node2D = null

func _ready() -> void:
	# 自动寻找场景中属于本团队的成员
	_refresh_members()
	
	# 定时更新战术
	var timer = Timer.new()
	timer.wait_time = 2.0
	timer.autostart = true
	timer.timeout.connect(_update_tactics)
	add_child(timer)

func _refresh_members() -> void:
	members.clear()
	var all_monks = get_tree().get_nodes_in_group("monks")
	for monk in all_monks:
		if monk is MonkAIController and monk.team_id == team_id:
			members.append(monk)
			monk.team_manager = self

func register_member(monk: MonkAIController) -> void:
	if not members.has(monk):
		members.append(monk)
		monk.team_manager = self

func unregister_member(monk: MonkAIController) -> void:
	members.erase(monk)

## 报告发现敌人
func report_enemy(enemy: Node2D) -> void:
	if not known_enemies.has(enemy):
		known_enemies.append(enemy)
		_update_primary_target()

## 更新团队战术
func _update_tactics() -> void:
	# 清理已失效的敌人
	known_enemies = known_enemies.filter(func(e): return is_instance_valid(e))
	
	if known_enemies.is_empty():
		current_tactical_state = TacticalState.SEARCH
		primary_target = null
	else:
		# 简单的战术逻辑：如果敌人较多，尝试集火
		if known_enemies.size() > 0:
			current_tactical_state = TacticalState.FOCUS_FIRE
			_update_primary_target()
		else:
			current_tactical_state = TacticalState.ENGAGE
	
	# 向成员分发指令
	_broadcast_tactics()

func _update_primary_target() -> void:
	if known_enemies.is_empty():
		primary_target = null
		return
	
	# 选择生命值最低的敌人作为集火目标
	var best_target = null
	var min_health = INF
	
	for enemy in known_enemies:
		var health = 1.0
		if enemy.has_method("get_health_percent"):
			health = enemy.get_health_percent()
		
		if health < min_health:
			min_health = health
			best_target = enemy
	
	if primary_target != best_target:
		primary_target = best_target
		team_target_changed.emit(primary_target)

func _broadcast_tactics() -> void:
	for member in members:
		if not is_instance_valid(member):
			continue
		
		# 根据团队战术调整成员行为
		match current_tactical_state:
			TacticalState.FOCUS_FIRE:
				if primary_target != null:
					member.current_target = primary_target
			TacticalState.RETREAT:
				# 可以在这里触发成员的逃跑状态
				pass
