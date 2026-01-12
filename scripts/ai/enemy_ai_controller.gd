class_name EnemyAIController extends CharacterBody2D

## 敌人AI控制器
## 作为敌人的"大脑"，管理状态机、感知系统和战斗行为
## 深度集成二维体素肢体战斗系统

# 信号
signal enemy_died(enemy: EnemyAIController)
signal damage_taken(amount: float, source: Node2D)
signal attack_started(attack_data: Dictionary)
signal attack_hit(target: Node2D, damage: float, part_type: int)
signal state_changed(old_state: String, new_state: String)
signal target_acquired(target: Node2D)
signal target_lost(target: Node2D)
signal body_part_damaged(part: BodyPartData, damage: float)
signal body_part_destroyed(part: BodyPartData)

# 节点引用
@onready var state_machine: StateMachine = $StateMachine
@onready var perception: PerceptionSystem = $Perception
@onready var target_selector: TargetSelector = $TargetSelector
@onready var visuals: Node2D = $Visuals
@onready var hitbox: Area2D = $Hitbox
@onready var health_bar: ProgressBar = $HealthBar

# 配置
@export var behavior_profile: AIBehaviorProfile
@export var energy_system: EnergySystemData
@export var weapon_data: WeaponData

# 二维体素战斗系统
@export var use_voxel_system: bool = true
var body_parts: Array[BodyPartData] = []

# 移动状态
var current_velocity: Vector2 = Vector2.ZERO
var facing_direction: Vector2 = Vector2.RIGHT
var target_position: Vector2 = Vector2.ZERO
var movement_penalty: float = 1.0

# 战斗状态
var current_target: Node2D = null
var is_attacking: bool = false
var is_casting: bool = false
var can_attack: bool = true
var attack_cooldown_timer: float = 0.0
var last_attack_time: float = 0.0

# 状态效果修饰符
var defense_modifier: float = 0.0
var accuracy_modifier: float = 0.0
var evasion_modifier: float = 0.0
var damage_taken_modifier: float = 1.0
var damage_output_modifier: float = 1.0
var speed_modifier: float = 1.0
var is_frozen: bool = false
var is_movement_locked: bool = false
var current_shield: float = 0.0

# 技能系统
var skill_cooldowns: Dictionary = {}

# 统计
var stats = {
	"total_damage_dealt": 0.0,
	"total_damage_taken": 0.0,
	"total_hits": 0,
	"attacks_performed": 0,
	"skills_used": 0,
	"body_parts_destroyed": 0
}

func _ready() -> void:
	# 初始化行为配置
	if behavior_profile == null:
		behavior_profile = AIBehaviorProfile.create_melee_aggressive()
	
	# 初始化能量系统
	if energy_system == null:
		energy_system = EnergySystemData.create_enemy_default(100.0)
	
	# 连接能量系统信号
	energy_system.energy_cap_changed.connect(_on_energy_cap_changed)
	energy_system.depleted.connect(_on_energy_depleted)
	
	# 初始化二维体素系统
	if use_voxel_system:
		_initialize_body_parts()
	
	# 初始化感知系统
	_setup_perception()
	
	# 初始化目标选择器
	_setup_target_selector()
	
	# 初始化状态机
	if state_machine != null:
		state_machine.initialize(self)
		state_machine.state_changed.connect(_on_state_changed)
	
	# 初始化武器
	if weapon_data == null:
		weapon_data = WeaponData.create_unarmed()
	
	# 更新UI
	_update_health_bar()
	
	# 添加到敌人组
	add_to_group("enemies")

func _physics_process(delta: float) -> void:
	# 更新状态机
	if state_machine != null:
		state_machine.physics_update(delta)
	
	# 更新攻击冷却
	_update_attack_cooldown(delta)
	
	# 更新技能冷却
	_update_skill_cooldowns(delta)
	
	# 应用移动
	move_and_slide()

func _process(delta: float) -> void:
	# 更新状态机
	if state_machine != null:
		state_machine.frame_update(delta)
	
	# 更新能量系统
	if energy_system != null:
		energy_system.absorb_from_environment(delta)
	
	# 更新朝向
	_update_facing_direction()

## 初始化肢体系统
func _initialize_body_parts() -> void:
	body_parts.clear()
	
	# 躯干（核心）
	var torso = BodyPartData.new()
	torso.initialize(BodyPartData.PartType.TORSO, 0, 0.0)
	torso.max_health = energy_system.max_energy_cap * 0.4
	torso.current_health = torso.max_health
	torso.core_damage_ratio = 0.5
	torso.is_vital = true
	torso.destroyed.connect(_on_body_part_destroyed)
	torso.damage_taken.connect(_on_body_part_damage_taken.bind(torso))
	body_parts.append(torso)
	
	# 头部
	var head = BodyPartData.new()
	head.initialize(BodyPartData.PartType.HEAD, 0, 0.0)
	head.max_health = energy_system.max_energy_cap * 0.2
	head.current_health = head.max_health
	head.core_damage_ratio = 0.8
	head.is_vital = true
	head.destroyed.connect(_on_body_part_destroyed)
	head.damage_taken.connect(_on_body_part_damage_taken.bind(head))
	body_parts.append(head)
	
	# 左臂
	var left_arm = BodyPartData.new()
	left_arm.initialize(BodyPartData.PartType.LEFT_ARM, 0, 0.0)
	left_arm.max_health = energy_system.max_energy_cap * 0.15
	left_arm.current_health = left_arm.max_health
	left_arm.core_damage_ratio = 0.2
	left_arm.destroyed.connect(_on_body_part_destroyed)
	left_arm.damage_taken.connect(_on_body_part_damage_taken.bind(left_arm))
	body_parts.append(left_arm)
	
	# 右臂
	var right_arm = BodyPartData.new()
	right_arm.initialize(BodyPartData.PartType.RIGHT_ARM, 0, 0.0)
	right_arm.max_health = energy_system.max_energy_cap * 0.15
	right_arm.current_health = right_arm.max_health
	right_arm.core_damage_ratio = 0.2
	right_arm.destroyed.connect(_on_body_part_destroyed)
	right_arm.damage_taken.connect(_on_body_part_damage_taken.bind(right_arm))
	body_parts.append(right_arm)
	
	# 腿部
	var legs = BodyPartData.new()
	legs.initialize(BodyPartData.PartType.LEGS, 0, 0.0)
	legs.max_health = energy_system.max_energy_cap * 0.1
	legs.current_health = legs.max_health
	legs.core_damage_ratio = 0.3
	legs.destroyed.connect(_on_body_part_destroyed)
	legs.damage_taken.connect(_on_body_part_damage_taken.bind(legs))
	body_parts.append(legs)

## 设置感知系统
func _setup_perception() -> void:
	if perception == null:
		return
	
	perception.perception_radius = behavior_profile.perception_radius
	perception.attack_radius = behavior_profile.attack_range
	perception.line_of_sight_required = behavior_profile.line_of_sight_required
	perception.memory_duration = behavior_profile.memory_duration
	
	perception.target_detected.connect(_on_target_detected)
	perception.target_lost.connect(_on_target_lost)

## 设置目标选择器
func _setup_target_selector() -> void:
	if target_selector == null:
		return
	
	target_selector.use_body_part_targeting = behavior_profile.use_body_part_targeting
	
	if behavior_profile.targeting_priorities.size() > 0:
		target_selector.set_targeting_priorities(behavior_profile.targeting_priorities)
	else:
		target_selector.setup_default_priorities()

## 更新攻击冷却
func _update_attack_cooldown(delta: float) -> void:
	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta
		if attack_cooldown_timer <= 0:
			can_attack = true

## 更新技能冷却
func _update_skill_cooldowns(delta: float) -> void:
	if behavior_profile == null:
		return
	
	for rule in behavior_profile.skill_usage_rules:
		rule.update_cooldown(delta)

## 更新朝向
func _update_facing_direction() -> void:
	if current_target != null:
		facing_direction = (current_target.global_position - global_position).normalized()
	elif velocity.length_squared() > 1:
		facing_direction = velocity.normalized()
	
	# 更新视觉朝向
	if visuals != null:
		visuals.rotation = facing_direction.angle()

## 更新血条
func _update_health_bar() -> void:
	if health_bar != null and energy_system != null:
		health_bar.value = energy_system.get_cap_percent() * 100.0

# ==================== 移动API ====================

## 移动到目标位置
func move_to(target: Vector2, delta: float) -> void:
	if is_frozen or is_movement_locked:
		velocity = Vector2.ZERO
		return
		
	var direction = (target - global_position).normalized()
	var speed = behavior_profile.move_speed * movement_penalty * speed_modifier
	velocity = direction * speed

## 移动到目标附近的最佳距离
func move_to_engagement_distance(target: Node2D, delta: float) -> void:
	if target == null or is_frozen or is_movement_locked:
		velocity = Vector2.ZERO
		return
	
	var distance = global_position.distance_to(target.global_position)
	var optimal_distance = behavior_profile.get_optimal_attack_distance()
	
	var direction: Vector2
	if distance > optimal_distance + 20:
		# 太远，靠近
		direction = (target.global_position - global_position).normalized()
	elif distance < behavior_profile.min_engagement_distance:
		# 太近，后退
		direction = (global_position - target.global_position).normalized()
	else:
		# 在最佳距离，横向移动
		if behavior_profile.strafe_enabled:
			var perpendicular = (target.global_position - global_position).normalized().rotated(PI / 2)
			direction = perpendicular * sin(Time.get_ticks_msec() / 1000.0 * behavior_profile.strafe_frequency)
		else:
			direction = Vector2.ZERO
	
	var speed = behavior_profile.move_speed * movement_penalty * speed_modifier
	velocity = direction * speed

## 逃离目标
func flee_from(target: Node2D, delta: float) -> void:
	if target == null:
		return
	
	var direction = (global_position - target.global_position).normalized()
	var speed = behavior_profile.move_speed * movement_penalty * 1.2  # 逃跑时稍快
	velocity = direction * speed

## 停止移动
func stop_movement() -> void:
	velocity = Vector2.ZERO

# ==================== 战斗API ====================

## 执行攻击
func perform_attack() -> void:
	if not can_attack or current_target == null:
		return
	
	is_attacking = true
	can_attack = false
	attack_cooldown_timer = behavior_profile.get_attack_cooldown()
	
	# 选择目标肢体
	var target_part = -1
	if target_selector != null and behavior_profile.use_body_part_targeting:
		target_part = target_selector.select_body_part(current_target)
	
	# 获取攻击数据
	var attack = _get_attack_data()
	
	# 发送攻击开始信号
	attack_started.emit(attack)
	
	# 执行伤害
	_apply_attack_damage(current_target, attack, target_part)
	
	stats.attacks_performed += 1
	last_attack_time = Time.get_ticks_msec() / 1000.0

## 获取攻击数据
func _get_attack_data() -> Dictionary:
	var base_damage = 10.0
	var attack_range = behavior_profile.attack_range
	
	if weapon_data != null:
		base_damage = weapon_data.base_damage
		attack_range = weapon_data.attack_range
	
	# 应用伤害输出修饰符
	base_damage *= damage_output_modifier
	
	return {
		"damage": base_damage,
		"range": attack_range,
		"knockback": 50.0
	}

## 应用攻击伤害
func _apply_attack_damage(target: Node2D, attack: Dictionary, part_type: int) -> void:
	if target == null or is_frozen:
		is_attacking = false
		return
	
	var damage = attack.damage
	
	# 应用命中率修饰符（简单模拟）
	if randf() < -accuracy_modifier:
		# 命中率降低
		if randf() < 0.5:
			is_attacking = false
			return
	
	# 检查距离
	var distance = global_position.distance_to(target.global_position)
	if distance > attack.range:
		is_attacking = false
		return
	
	# 对目标造成伤害
	if target.has_method("take_damage"):
		if part_type >= 0:
			# 针对特定肢体
			target.take_damage(damage, self, part_type)
		else:
			# 随机肢体或整体
			if target.has_method("take_damage_random_part"):
				target.take_damage_random_part(damage, self)
			else:
				target.take_damage(damage, self)
		
		stats.total_damage_dealt += damage
		stats.total_hits += 1
		attack_hit.emit(target, damage, part_type)
	
	# 应用击退
	if target.has_method("apply_knockback"):
		var knockback_dir = (target.global_position - global_position).normalized()
		target.apply_knockback(knockback_dir * attack.knockback)
	
	is_attacking = false

## 使用技能
func use_skill(skill_rule: AISkillRule) -> bool:
	if skill_rule == null:
		return false
	
	# 构建上下文
	var context = _build_skill_context()
	
	# 检查是否可用
	if not skill_rule.can_use(context):
		return false
	
	# 消耗能量
	if not energy_system.consume_energy(skill_rule.energy_cost):
		return false
	
	# 使用技能
	skill_rule.use()
	stats.skills_used += 1
	
	# 如果有关联法术，执行法术
	if skill_rule.spell_data != null:
		_cast_spell(skill_rule.spell_data)
	
	return true

## 构建技能上下文
func _build_skill_context() -> Dictionary:
	var context = {
		"health_percent": get_health_percent(),
		"current_energy": energy_system.current_energy,
		"enemy_count": get_tree().get_nodes_in_group("players").size(),
		"ally_count": get_tree().get_nodes_in_group("enemies").size() - 1
	}
	
	if current_target != null:
		context["distance_to_target"] = global_position.distance_to(current_target.global_position)
		context["target_is_casting"] = current_target.get("is_casting") if current_target.get("is_casting") != null else false
		context["target_is_attacking"] = current_target.get("is_attacking") if current_target.get("is_attacking") != null else false
		
		if current_target.has_method("get_health_percent"):
			context["target_health_percent"] = current_target.get_health_percent()
		else:
			context["target_health_percent"] = 1.0
	
	return context

## 施放法术
func _cast_spell(spell: SpellCoreData) -> void:
	is_casting = true
	
	# 这里可以调用SpellFactory创建法术实例
	# 暂时简化处理
	
	is_casting = false

# ==================== 伤害处理 ====================

## 承受伤害
func take_damage(damage: float, source: Node2D = null, target_part_type: int = -1) -> void:
	var final_damage = damage * damage_taken_modifier
	
	# 护盾优先吸收
	if current_shield > 0:
		var shield_absorb = min(current_shield, final_damage)
		current_shield -= shield_absorb
		final_damage -= shield_absorb
	
	if final_damage <= 0:
		return

	# 二维体素战斗系统处理
	if use_voxel_system and body_parts.size() > 0:
		# 应用防御修饰符到肢体伤害
		var part_damage = final_damage * (1.0 / (1.0 + max(0, defense_modifier / 100.0)))
		var core_damage = _damage_body_part(target_part_type, part_damage)
		
		# 核心伤害传递到能量系统
		if energy_system != null and core_damage > 0:
			energy_system.take_damage(core_damage)
	else:
		# 传统伤害处理
		if energy_system != null:
			energy_system.take_damage(final_damage)
	
	stats.total_damage_taken += final_damage
	damage_taken.emit(final_damage, source)
	_update_health_bar()

# ==================== 状态效果 API ====================

func set_frozen(frozen: bool) -> void:
	is_frozen = frozen
	if is_frozen:
		stop_movement()

func set_movement_locked(locked: bool) -> void:
	is_movement_locked = locked
	if is_movement_locked:
		stop_movement()

func modify_defense(amount: float) -> void:
	defense_modifier += amount

func modify_accuracy(amount: float) -> void:
	accuracy_modifier += amount

func modify_evasion(amount: float) -> void:
	evasion_modifier += amount

func modify_damage_taken(amount: float) -> void:
	# amount 是增加的百分比，例如 0.25 表示增加 25% 受到伤害
	damage_taken_modifier += amount

func modify_damage_output(amount: float) -> void:
	damage_output_modifier += amount

func modify_move_speed(amount: float) -> void:
	speed_modifier += amount

func add_shield(amount: float) -> void:
	current_shield += amount

func apply_status(status_type: int, duration: float, effect_value: float = 0.0) -> void:
	var runtime_manager = get_tree().get_first_node_in_group("runtime_systems_manager")
	if runtime_manager != null:
		var status_data = ApplyStatusActionData.new()
		status_data.status_type = status_type
		status_data.duration = duration
		status_data.effect_value = effect_value
		status_data._sync_phase_from_status()
		runtime_manager.apply_status(self, status_data)

## 对特定肢体造成伤害
func _damage_body_part(part_type: int, damage: float) -> float:
	var target_part: BodyPartData = null
	
	# 如果指定了肢体类型，尝试找到对应肢体
	if part_type >= 0:
		for part in body_parts:
			if part.part_type == part_type and part.is_functional:
				target_part = part
				break
	
	# 如果没有找到指定肢体或未指定，随机选择一个功能正常的肢体
	if target_part == null:
		var functional_parts: Array[BodyPartData] = []
		for part in body_parts:
			if part.is_functional:
				functional_parts.append(part)
		
		if functional_parts.is_empty():
			return damage
		
		target_part = functional_parts[randi() % functional_parts.size()]
	
	# 对肢体造成伤害
	var actual_damage = target_part.take_damage(damage)
	var core_damage = actual_damage * target_part.core_damage_ratio
	
	return core_damage

## 应用击退
func apply_knockback(knockback: Vector2) -> void:
	velocity += knockback

# ==================== 回调函数 ====================

func _on_energy_cap_changed(_current_cap: float, _max_cap: float) -> void:
	_update_health_bar()

func _on_energy_depleted() -> void:
	_die()

func _on_state_changed(old_state: State, new_state: State) -> void:
	var old_name = old_state.name if old_state else ""
	var new_name = new_state.name if new_state else ""
	state_changed.emit(old_name, new_name)

func _on_target_detected(target: Node2D) -> void:
	current_target = target
	target_acquired.emit(target)

func _on_target_lost(target: Node2D) -> void:
	if target == current_target:
		current_target = null
	target_lost.emit(target)

func _on_body_part_damage_taken(damage: float, _remaining_health: float, part: BodyPartData) -> void:
	body_part_damaged.emit(part, damage)
	_update_movement_penalty()

func _on_body_part_destroyed(part: BodyPartData) -> void:
	stats.body_parts_destroyed += 1
	body_part_destroyed.emit(part)
	
	# 检查是否为关键部位
	if part.is_vital:
		_die()
		return
	
	_update_movement_penalty()

## 更新移动惩罚
func _update_movement_penalty() -> void:
	var legs = get_body_part(BodyPartData.PartType.LEGS)
	if legs == null or not legs.is_functional:
		movement_penalty = 0.3
	else:
		movement_penalty = legs.efficiency

## 死亡处理
func _die() -> void:
	enemy_died.emit(self)
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	call_deferred("queue_free")

# ==================== 公共API ====================

## 获取生命值百分比
func get_health_percent() -> float:
	if energy_system != null:
		return energy_system.get_cap_percent()
	return 0.0

## 获取当前目标
func get_current_target() -> Node2D:
	return current_target

## 获取到目标的距离
func get_distance_to_target() -> float:
	if current_target == null:
		return INF
	return global_position.distance_to(current_target.global_position)

## 检查目标是否在攻击范围内
func is_target_in_range() -> bool:
	return get_distance_to_target() <= behavior_profile.attack_range

## 获取特定肢体
func get_body_part(part_type: int) -> BodyPartData:
	for part in body_parts:
		if part.part_type == part_type:
			return part
	return null

## 获取所有肢体
func get_body_parts() -> Array[BodyPartData]:
	return body_parts

## 获取功能正常的肢体
func get_functional_body_parts() -> Array[BodyPartData]:
	var functional: Array[BodyPartData] = []
	for part in body_parts:
		if part.is_functional:
			functional.append(part)
	return functional

## 检查是否应该逃跑
func should_flee() -> bool:
	return behavior_profile.should_flee(get_health_percent())

## 获取统计数据
func get_stats() -> Dictionary:
	return stats.duplicate()
