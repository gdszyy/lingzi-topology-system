extends State
class_name AIAttackState

## AI攻击状态
## 执行攻击动作，包括前摇、攻击、后摇阶段
## 支持连击系统和肢体目标选择

enum AttackPhase {
	WINDUP,     # 前摇
	ACTIVE,     # 攻击判定
	RECOVERY,   # 后摇
	COMBO_WINDOW # 连击窗口
}

var ai: EnemyAIController

var current_phase: AttackPhase = AttackPhase.WINDUP
var phase_timer: float = 0.0
var combo_count: int = 0
var target_part_type: int = -1

# 攻击时间配置
var windup_time: float = 0.2
var active_time: float = 0.1
var recovery_time: float = 0.3
var combo_window_time: float = 0.3

# 攻击数据
var current_attack_damage: float = 10.0
var current_attack_range: float = 100.0

func initialize(_owner: Node) -> void:
	super.initialize(_owner)
	ai = _owner as EnemyAIController

func enter(_params: Dictionary = {}) -> void:
	current_phase = AttackPhase.WINDUP
	phase_timer = 0.0
	combo_count = 0
	
	# 获取攻击数据
	_setup_attack_data()
	
	# 选择目标肢体
	if ai.target_selector != null and ai.behavior_profile.use_body_part_targeting:
		target_part_type = ai.target_selector.select_body_part(ai.current_target)
	else:
		target_part_type = -1
	
	# 停止移动
	ai.stop_movement()
	ai.is_attacking = true
	
	# 面向目标
	if ai.current_target != null:
		ai.facing_direction = (ai.current_target.global_position - ai.global_position).normalized()

func exit() -> void:
	ai.is_attacking = false
	phase_timer = 0.0
	combo_count = 0

func physics_update(delta: float) -> void:
	phase_timer += delta
	
	# 检查目标是否还存在
	if ai.current_target == null:
		transition_to("AIIdle")
		return
	
	# 检查目标是否还在范围内
	var distance = ai.get_distance_to_target()
	if distance > current_attack_range * 1.5:
		transition_to("AIChase")
		return
	
	# 处理当前阶段
	match current_phase:
		AttackPhase.WINDUP:
			_process_windup(delta)
		AttackPhase.ACTIVE:
			_process_active(delta)
		AttackPhase.RECOVERY:
			_process_recovery(delta)
		AttackPhase.COMBO_WINDOW:
			_process_combo_window(delta)

## 设置攻击数据
func _setup_attack_data() -> void:
	if ai.weapon_data != null:
		current_attack_damage = ai.weapon_data.base_damage
		current_attack_range = ai.weapon_data.attack_range
		
		# 获取攻击动作的时间配置
		var attacks = ai.weapon_data.get_attacks_for_input(0)
		if attacks.size() > 0:
			var attack = attacks[0]
			windup_time = attack.windup_time
			active_time = attack.active_time
			recovery_time = attack.recovery_time
			if attack.can_combo:
				combo_window_time = attack.combo_window
			else:
				combo_window_time = 0.0
	else:
		# 使用默认值
		current_attack_damage = 10.0
		current_attack_range = ai.behavior_profile.attack_range if ai.behavior_profile else 100.0
		windup_time = 0.2
		active_time = 0.1
		recovery_time = 0.3
		combo_window_time = 0.3

## 处理前摇阶段
func _process_windup(_delta: float) -> void:
	if phase_timer >= windup_time:
		# 进入攻击判定阶段
		current_phase = AttackPhase.ACTIVE
		phase_timer = 0.0
		
		# 发送攻击开始信号
		ai.attack_started.emit({
			"damage": current_attack_damage,
			"range": current_attack_range,
			"target_part": target_part_type
		})

## 处理攻击判定阶段
func _process_active(_delta: float) -> void:
	# 在攻击判定阶段执行伤害
	if phase_timer < 0.01:  # 只在进入时执行一次
		_execute_attack()
	
	if phase_timer >= active_time:
		# 进入后摇阶段
		current_phase = AttackPhase.RECOVERY
		phase_timer = 0.0

## 处理后摇阶段
func _process_recovery(_delta: float) -> void:
	if phase_timer >= recovery_time:
		# 检查是否可以连击
		if _should_combo():
			current_phase = AttackPhase.COMBO_WINDOW
			phase_timer = 0.0
		else:
			_finish_attack()

## 处理连击窗口
func _process_combo_window(_delta: float) -> void:
	if phase_timer >= combo_window_time:
		# 连击窗口结束
		_finish_attack()
		return
	
	# 检查是否执行连击
	if _should_execute_combo():
		combo_count += 1
		current_phase = AttackPhase.WINDUP
		phase_timer = 0.0
		
		# 重新选择目标肢体
		if ai.target_selector != null and ai.behavior_profile.use_body_part_targeting:
			target_part_type = ai.target_selector.select_body_part(ai.current_target)

## 执行攻击
func _execute_attack() -> void:
	if ai.current_target == null:
		return
	
	var distance = ai.get_distance_to_target()
	if distance > current_attack_range:
		return
	
	# 计算伤害
	var damage = current_attack_damage
	
	# 连击伤害加成
	if combo_count > 0:
		damage *= 1.0 + combo_count * 0.1
	
	# 对目标造成伤害
	if ai.current_target.has_method("take_damage"):
		if target_part_type >= 0:
			ai.current_target.take_damage(damage, ai, target_part_type)
		else:
			if ai.current_target.has_method("take_damage_random_part"):
				ai.current_target.take_damage_random_part(damage, ai)
			else:
				ai.current_target.take_damage(damage, ai)
		
		ai.stats.total_damage_dealt += damage
		ai.stats.total_hits += 1
		ai.attack_hit.emit(ai.current_target, damage, target_part_type)
	
	# 应用击退
	if ai.current_target.has_method("apply_knockback"):
		var knockback_dir = (ai.current_target.global_position - ai.global_position).normalized()
		ai.current_target.apply_knockback(knockback_dir * 50.0)
	
	ai.stats.attacks_performed += 1

## 检查是否应该连击
func _should_combo() -> bool:
	if ai.behavior_profile == null:
		return false
	
	# 检查连击次数限制
	if combo_count >= ai.behavior_profile.max_combo_length:
		return false
	
	# 检查目标是否还在范围内
	if ai.get_distance_to_target() > current_attack_range:
		return false
	
	# 根据连击概率决定
	return ai.behavior_profile.should_combo()

## 检查是否执行连击
func _should_execute_combo() -> bool:
	# 检查目标是否还存在且在范围内
	if ai.current_target == null:
		return false
	
	if ai.get_distance_to_target() > current_attack_range:
		return false
	
	# 根据攻击欲望决定
	var aggression = ai.behavior_profile.get_adjusted_aggression(
		ai.get_health_percent(),
		get_tree().get_nodes_in_group("enemies").size(),
		get_tree().get_nodes_in_group("players").size()
	) if ai.behavior_profile else 0.5
	
	return randf() < aggression

## 完成攻击
func _finish_attack() -> void:
	ai.is_attacking = false
	ai.can_attack = false
	ai.attack_cooldown_timer = ai.behavior_profile.get_attack_cooldown() if ai.behavior_profile else 2.0
	
	# 根据战局决定下一个状态
	if ai.current_target == null:
		transition_to("AIIdle")
	elif ai.should_flee():
		transition_to("AIFlee")
	elif ai.get_distance_to_target() > ai.behavior_profile.attack_range if ai.behavior_profile else 100.0:
		transition_to("AIChase")
	else:
		# 保持在攻击位置，等待冷却
		transition_to("AIChase")
