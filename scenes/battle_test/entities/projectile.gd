# projectile.gd
# 子弹/法术实体 - 根据 SpellCoreData 执行行为
extends Area2D
class_name Projectile

## 信号
signal hit_enemy(enemy: Node2D, damage: float)
signal projectile_died(projectile: Projectile)
signal fission_triggered(position: Vector2, spell_data: SpellCoreData, count: int)

## 法术数据
var spell_data: SpellCoreData
var carrier: CarrierConfigData

## 运行时状态
var velocity: Vector2 = Vector2.ZERO
var lifetime_remaining: float = 0.0
var piercing_remaining: int = 0
var target: Node2D = null  # 追踪目标

## 规则执行状态
var rule_timers: Array[float] = []  # 每条规则的计时器
var rule_triggered: Array[bool] = []  # 规则是否已触发（用于 trigger_once）

## 视觉组件
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

## 颜色映射（按相态）
const PHASE_COLORS = {
	CarrierConfigData.Phase.SOLID: Color(0.8, 0.4, 0.2),      # 橙色 - 固态
	CarrierConfigData.Phase.LIQUID: Color(0.2, 0.6, 0.9),     # 蓝色 - 液态
	CarrierConfigData.Phase.PLASMA: Color(0.9, 0.2, 0.9)      # 紫色 - 等离子态
}

func _ready():
	# 连接碰撞信号
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

## 初始化子弹
func initialize(data: SpellCoreData, direction: Vector2, start_pos: Vector2) -> void:
	spell_data = data
	carrier = data.carrier
	
	# 设置位置
	global_position = start_pos
	
	# 设置速度
	velocity = direction.normalized() * carrier.velocity
	
	# 设置生命周期
	lifetime_remaining = carrier.lifetime
	piercing_remaining = carrier.piercing
	
	# 初始化规则状态
	rule_timers.clear()
	rule_triggered.clear()
	for rule in spell_data.topology_rules:
		rule_timers.append(0.0)
		rule_triggered.append(false)
	
	# 设置视觉
	_setup_visuals()

## 设置视觉效果
func _setup_visuals() -> void:
	if carrier == null:
		return
	
	# 设置颜色
	var color = PHASE_COLORS.get(carrier.phase, Color.WHITE)
	modulate = color
	
	# 设置大小
	var base_scale = carrier.size * 0.5
	scale = Vector2(base_scale, base_scale)
	
	# 设置朝向
	rotation = velocity.angle()

func _physics_process(delta: float) -> void:
	if carrier == null:
		return
	
	# 更新生命周期
	lifetime_remaining -= delta
	if lifetime_remaining <= 0:
		_trigger_death_rules()
		_die()
		return
	
	# 追踪逻辑
	if carrier.homing_strength > 0 and target != null and is_instance_valid(target):
		var to_target = (target.global_position - global_position).normalized()
		var current_dir = velocity.normalized()
		var new_dir = current_dir.lerp(to_target, carrier.homing_strength * delta * 5.0)
		velocity = new_dir * carrier.velocity
	
	# 移动
	position += velocity * delta
	rotation = velocity.angle()
	
	# 更新规则计时器
	_update_rule_timers(delta)
	
	# 检查边界
	_check_bounds()

## 更新规则计时器
func _update_rule_timers(delta: float) -> void:
	for i in range(spell_data.topology_rules.size()):
		var rule = spell_data.topology_rules[i]
		if not rule.enabled:
			continue
		
		rule_timers[i] += delta
		
		# 检查定时触发器
		if rule.trigger is OnTimerTrigger:
			var timer_trigger = rule.trigger as OnTimerTrigger
			if rule_timers[i] >= timer_trigger.delay:
				if not rule_triggered[i] or not rule.trigger.trigger_once:
					_execute_rule(rule, i)
					rule_timers[i] = 0.0
					if rule.trigger.trigger_once:
						rule_triggered[i] = true

## 执行规则
func _execute_rule(rule: TopologyRuleData, rule_index: int) -> void:
	for action in rule.actions:
		_execute_action(action)

## 执行动作
func _execute_action(action: ActionData) -> void:
	if action is DamageActionData:
		# 伤害动作在碰撞时处理
		pass
	
	elif action is FissionActionData:
		var fission = action as FissionActionData
		_execute_fission(fission)
	
	elif action is AreaEffectActionData:
		var area = action as AreaEffectActionData
		_execute_area_effect(area)
	
	elif action is ApplyStatusActionData:
		# 状态效果在碰撞时处理
		pass

## 执行裂变
func _execute_fission(fission: FissionActionData) -> void:
	fission_triggered.emit(global_position, fission.child_spell_data, fission.spawn_count)
	
	# 如果裂变后销毁
	if fission.destroy_parent:
		_die()

## 执行范围效果
func _execute_area_effect(area: AreaEffectActionData) -> void:
	# 查找范围内的敌人
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	
	var shape = CircleShape2D.new()
	shape.radius = area.radius
	query.shape = shape
	query.transform = Transform2D(0, global_position)
	query.collision_mask = 2  # 敌人层
	
	var results = space_state.intersect_shape(query)
	for result in results:
		var collider = result.collider
		if collider.has_method("take_damage"):
			collider.take_damage(area.damage_value, area.damage_type)
			hit_enemy.emit(collider, area.damage_value)

## 碰撞处理
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies"):
		_handle_enemy_collision(body)

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemies"):
		_handle_enemy_collision(area)

## 处理敌人碰撞
func _handle_enemy_collision(enemy: Node2D) -> void:
	# 检查接触触发器
	for i in range(spell_data.topology_rules.size()):
		var rule = spell_data.topology_rules[i]
		if not rule.enabled:
			continue
		
		if rule.trigger.trigger_type == TriggerData.TriggerType.ON_CONTACT:
			if not rule_triggered[i] or not rule.trigger.trigger_once:
				_execute_contact_rule(rule, enemy)
				if rule.trigger.trigger_once:
					rule_triggered[i] = true
	
	# 计算总伤害
	var total_damage = _calculate_damage()
	
	# 应用伤害
	if enemy.has_method("take_damage"):
		enemy.take_damage(total_damage, 0)
	
	hit_enemy.emit(enemy, total_damage)
	
	# 穿透处理
	if piercing_remaining > 0:
		piercing_remaining -= 1
	else:
		_die()

## 执行接触规则
func _execute_contact_rule(rule: TopologyRuleData, enemy: Node2D) -> void:
	for action in rule.actions:
		if action is FissionActionData:
			_execute_fission(action as FissionActionData)
		elif action is AreaEffectActionData:
			_execute_area_effect(action as AreaEffectActionData)
		elif action is ApplyStatusActionData:
			var status = action as ApplyStatusActionData
			if enemy.has_method("apply_status"):
				enemy.apply_status(status.status_type, status.duration, status.effect_value)

## 计算伤害
func _calculate_damage() -> float:
	var total = 0.0
	
	for rule in spell_data.topology_rules:
		if rule.trigger.trigger_type == TriggerData.TriggerType.ON_CONTACT:
			for action in rule.actions:
				if action is DamageActionData:
					var dmg = action as DamageActionData
					total += dmg.damage_value * dmg.damage_multiplier
	
	# 应用质量加成
	total *= (1.0 + carrier.mass * 0.1)
	
	return total

## 触发死亡规则
func _trigger_death_rules() -> void:
	for i in range(spell_data.topology_rules.size()):
		var rule = spell_data.topology_rules[i]
		if rule.trigger.trigger_type == TriggerData.TriggerType.ON_DEATH:
			_execute_rule(rule, i)

## 检查边界
func _check_bounds() -> void:
	var viewport_rect = get_viewport_rect()
	var margin = 100
	if position.x < -margin or position.x > viewport_rect.size.x + margin or \
	   position.y < -margin or position.y > viewport_rect.size.y + margin:
		_die()

## 死亡
func _die() -> void:
	projectile_died.emit(self)
	# 使用 call_deferred 避免在物理查询期间修改状态
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	call_deferred("queue_free")

## 设置追踪目标
func set_target(new_target: Node2D) -> void:
	target = new_target
