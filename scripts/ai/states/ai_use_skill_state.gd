extends State
class_name AIUseSkillState

## AI使用技能状态
## 执行特殊技能，如法术、召唤、治疗等

enum SkillPhase {
	PREPARE,    # 准备阶段
	CAST,       # 施放阶段
	RECOVERY    # 恢复阶段
}

var ai: EnemyAIController

var current_phase: SkillPhase = SkillPhase.PREPARE
var phase_timer: float = 0.0
var current_skill: AISkillRule = null

# 技能时间配置
var prepare_time: float = 0.3
var cast_time: float = 0.5
var recovery_time: float = 0.2

func initialize(_owner: Node) -> void:
	super.initialize(_owner)
	ai = _owner as EnemyAIController

func enter(_params: Dictionary = {}) -> void:
	current_phase = SkillPhase.PREPARE
	phase_timer = 0.0
	
	# 选择要使用的技能
	current_skill = _select_skill()
	
	if current_skill == null:
		# 没有可用技能，返回追击
		transition_to("AIChase")
		return
	
	# 停止移动
	ai.stop_movement()
	ai.is_casting = true
	
	# 面向目标
	if ai.current_target != null:
		ai.facing_direction = (ai.current_target.global_position - ai.global_position).normalized()

func exit() -> void:
	ai.is_casting = false
	phase_timer = 0.0
	current_skill = null

func physics_update(delta: float) -> void:
	phase_timer += delta
	
	# 处理当前阶段
	match current_phase:
		SkillPhase.PREPARE:
			_process_prepare(delta)
		SkillPhase.CAST:
			_process_cast(delta)
		SkillPhase.RECOVERY:
			_process_recovery(delta)

## 选择要使用的技能
func _select_skill() -> AISkillRule:
	if ai.behavior_profile == null:
		return null
	
	if not ai.behavior_profile.skill_usage_enabled:
		return null
	
	# 构建上下文
	var context = _build_context()
	
	# 找到优先级最高的可用技能
	var best_skill: AISkillRule = null
	var best_priority: float = -1.0
	
	for rule in ai.behavior_profile.skill_usage_rules:
		if rule.can_use(context) and rule.priority > best_priority:
			best_priority = rule.priority
			best_skill = rule
	
	return best_skill

## 构建上下文
func _build_context() -> Dictionary:
	var context = {
		"health_percent": ai.get_health_percent(),
		"current_energy": ai.energy_system.current_energy if ai.energy_system else 0.0,
		"enemy_count": get_tree().get_nodes_in_group("players").size(),
		"ally_count": get_tree().get_nodes_in_group("enemies").size() - 1
	}
	
	if ai.current_target != null:
		context["distance_to_target"] = ai.get_distance_to_target()
		context["target_is_casting"] = ai.current_target.get("is_casting") if ai.current_target.get("is_casting") != null else false
		context["target_is_attacking"] = ai.current_target.get("is_attacking") if ai.current_target.get("is_attacking") != null else false
		
		if ai.current_target.has_method("get_health_percent"):
			context["target_health_percent"] = ai.current_target.get_health_percent()
	
	return context

## 处理准备阶段
func _process_prepare(_delta: float) -> void:
	if phase_timer >= prepare_time:
		current_phase = SkillPhase.CAST
		phase_timer = 0.0

## 处理施放阶段
func _process_cast(_delta: float) -> void:
	# 在施放阶段执行技能效果
	if phase_timer < 0.01:  # 只在进入时执行一次
		_execute_skill()
	
	if phase_timer >= cast_time:
		current_phase = SkillPhase.RECOVERY
		phase_timer = 0.0

## 处理恢复阶段
func _process_recovery(_delta: float) -> void:
	if phase_timer >= recovery_time:
		_finish_skill()

## 执行技能
func _execute_skill() -> void:
	if current_skill == null:
		return
	
	# 使用技能
	if ai.use_skill(current_skill):
		print("[AI技能] %s 使用了 %s" % [ai.name, current_skill.skill_name])

## 完成技能
func _finish_skill() -> void:
	ai.is_casting = false
	
	# 根据战局决定下一个状态
	if ai.current_target == null:
		transition_to("AIIdle")
	elif ai.should_flee():
		transition_to("AIFlee")
	else:
		transition_to("AIChase")
