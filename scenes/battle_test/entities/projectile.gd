# projectile.gd
# 子弹/法术实体 - 根据 SpellCoreData 执行行为
extends Area2D
class_name Projectile

## 信号
signal hit_enemy(enemy: Node2D, damage: float)
signal projectile_died(projectile: Projectile)
signal fission_triggered(position: Vector2, spell_data: SpellCoreData, count: int, spread_angle: float)
signal explosion_requested(position: Vector2, damage: float, radius: float, falloff: float, damage_type: int)
signal damage_zone_requested(position: Vector2, damage: float, radius: float, duration: float, interval: float, damage_type: int, slow: float)

## 法术数据
var spell_data: SpellCoreData
var carrier: CarrierConfigData

## 运行时状态
var velocity: Vector2 = Vector2.ZERO
var lifetime_remaining: float = 0.0
var piercing_remaining: int = 0
var target: Node2D = null  # 追踪目标
var homing_delay_timer: float = 0.0  # 追踪延迟计时器
var time_alive: float = 0.0  # 存活时间

## 规则执行状态
var rule_timers: Array[float] = []  # 每条规则的计时器
var rule_triggered: Array[bool] = []  # 规则是否已触发（用于 trigger_once）

## 视觉组件
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var visual_circle: Polygon2D = $VisualCircle
@onready var trail: Line2D = $Trail

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
	
	# 设置速度（使用有效速度，支持地雷/慢速球类型）
	var effective_velocity = carrier.get_effective_velocity()
	velocity = direction.normalized() * effective_velocity
	
	# 设置生命周期（使用有效寿命，地雷类型寿命翻倍）
	lifetime_remaining = carrier.get_effective_lifetime()
	piercing_remaining = carrier.piercing
	
	# 输出载体类型信息
	var type_names = ["Projectile", "Mine", "SlowOrb"]
	print("[子弹] 类型=%s, 速度=%.1f, 寿命=%.1fs" % [type_names[carrier.carrier_type], effective_velocity, lifetime_remaining])
	
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
		print("[子弹] 警告: carrier 为 null，无法设置视觉效果")
		return
	
	# 设置颜色
	var color = PHASE_COLORS.get(carrier.phase, Color.WHITE)
	modulate = color
	
	# 直接设置VisualCircle的颜色（确保可见）
	if visual_circle != null:
		visual_circle.color = color
		visual_circle.visible = true
	
	# 设置拖尾颜色
	if trail != null:
		trail.default_color = Color(color.r, color.g, color.b, 0.5)
	
	# 设置大小 - 确保最小可见
	var base_scale = maxf(carrier.size, 0.5)  # 最小 0.5 保证可见
	scale = Vector2(base_scale, base_scale)
	
	# 设置朝向
	rotation = velocity.angle()
	
	# 确保可见
	visible = true
	modulate.a = 1.0
	
	print("[子弹] 视觉设置: 颜色=%s, 缩放=%.2f, 位置=%s" % [color, base_scale, global_position])

func _physics_process(delta: float) -> void:
	if carrier == null:
		return
	
	# 更新生命周期
	lifetime_remaining -= delta
	if lifetime_remaining <= 0:
		_trigger_death_rules()
		_die()
		return
	
	# 更新存活时间
	time_alive += delta
	
	# 追踪逻辑
	_update_homing(delta)
	
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
		
		# 检查接近触发器
		elif rule.trigger is OnProximityTrigger:
			var prox_trigger = rule.trigger as OnProximityTrigger
			if not rule_triggered[i] or not rule.trigger.trigger_once:
				if _check_proximity_trigger(prox_trigger):
					_execute_rule(rule, i)
					if rule.trigger.trigger_once:
						rule_triggered[i] = true

## 检查接近触发条件
func _check_proximity_trigger(trigger: OnProximityTrigger) -> bool:
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist = global_position.distance_to(enemy.global_position)
		if dist <= trigger.detection_radius:
			return true
	return false

## 执行规则
func _execute_rule(rule: TopologyRuleData, _rule_index: int) -> void:
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
	
	elif action is SpawnExplosionActionData:
		var explosion = action as SpawnExplosionActionData
		_execute_spawn_explosion(explosion)
	
	elif action is SpawnDamageZoneActionData:
		var zone = action as SpawnDamageZoneActionData
		_execute_spawn_damage_zone(zone)

## 执行裂变
func _execute_fission(fission: FissionActionData) -> void:
	print("[子弹] 执行裂变: 数量=%d, 角度=%.1f°" % [fission.spawn_count, fission.spread_angle])
	fission_triggered.emit(global_position, fission.child_spell_data, fission.spawn_count, fission.spread_angle)
	
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

## 更新追踪逻辑
func _update_homing(delta: float) -> void:
	# 检查是否有追踪能力
	if carrier.homing_strength <= 0:
		return
	
	# 检查追踪延迟
	if time_alive < carrier.homing_delay:
		return
	
	# 如果没有目标或目标无效，尝试寻找新目标
	if target == null or not is_instance_valid(target):
		target = _find_nearest_enemy()
		if target == null:
			return
	
	# 检查目标是否在追踪范围内
	var distance_to_target = global_position.distance_to(target.global_position)
	if distance_to_target > carrier.homing_range:
		# 目标超出范围，尝试寻找更近的目标
		var new_target = _find_nearest_enemy()
		if new_target != null:
			var new_distance = global_position.distance_to(new_target.global_position)
			if new_distance <= carrier.homing_range:
				target = new_target
				distance_to_target = new_distance
			else:
				return  # 没有范围内的目标
		else:
			return
	
	# 计算追踪方向
	var to_target = (target.global_position - global_position).normalized()
	var current_dir = velocity.normalized()
	
	# 使用转向速率和追踪强度计算实际转向
	var turn_amount = carrier.homing_turn_rate * carrier.homing_strength * delta
	var new_dir = current_dir.lerp(to_target, clampf(turn_amount, 0.0, 1.0))
	velocity = new_dir.normalized() * carrier.velocity

## 寻找最近的敌人
func _find_nearest_enemy() -> Node2D:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var nearest_dist = INF
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist = global_position.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy
	
	return nearest

## 执行生成爆炸
func _execute_spawn_explosion(explosion: SpawnExplosionActionData) -> void:
	print("[子弹] 生成爆炸: 伤害=%.1f, 半径=%.1f" % [explosion.explosion_damage, explosion.explosion_radius])
	explosion_requested.emit(
		global_position,
		explosion.explosion_damage,
		explosion.explosion_radius,
		explosion.damage_falloff,
		explosion.explosion_damage_type
	)

## 执行生成持续伤害区域
func _execute_spawn_damage_zone(zone: SpawnDamageZoneActionData) -> void:
	print("[子弹] 生成伤害区域: 伤害=%.1f, 半径=%.1f, 持续=%.1fs" % [zone.zone_damage, zone.zone_radius, zone.zone_duration])
	damage_zone_requested.emit(
		global_position,
		zone.zone_damage,
		zone.zone_radius,
		zone.zone_duration,
		zone.tick_interval,
		zone.zone_damage_type,
		zone.slow_amount
	)
