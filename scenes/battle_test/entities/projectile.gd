extends Area2D
class_name Projectile

signal hit_enemy(enemy: Node2D, damage: float)
signal projectile_died(projectile: Projectile)
signal fission_triggered(position: Vector2, spell_data: SpellCoreData, count: int, spread_angle: float, parent_direction: Vector2, direction_mode: int)
signal explosion_requested(position: Vector2, damage: float, radius: float, falloff: float, damage_type: int)
signal damage_zone_requested(position: Vector2, damage: float, radius: float, duration: float, interval: float, damage_type: int, slow: float)

var spell_data: SpellCoreData
var carrier: CarrierConfigData

var velocity: Vector2 = Vector2.ZERO
var lifetime_remaining: float = 0.0
var piercing_remaining: int = 0
var target: Node2D = null
var homing_delay_timer: float = 0.0
var time_alive: float = 0.0

var rule_timers: Array[float] = []
var rule_triggered: Array[bool] = []

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var visual_circle: Polygon2D = $VisualCircle
@onready var trail: Line2D = $Trail

const PHASE_COLORS = {
	CarrierConfigData.Phase.SOLID: Color(0.8, 0.4, 0.2),
	CarrierConfigData.Phase.LIQUID: Color(0.2, 0.6, 0.9),
	CarrierConfigData.Phase.PLASMA: Color(0.9, 0.2, 0.9)
}

func _ready():
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func initialize(data: SpellCoreData, direction: Vector2, start_pos: Vector2) -> void:
	spell_data = data
	carrier = data.carrier

	global_position = start_pos

	var effective_velocity = carrier.get_effective_velocity()
	velocity = direction.normalized() * effective_velocity

	lifetime_remaining = carrier.get_effective_lifetime()
	piercing_remaining = carrier.piercing

	var type_names = ["Projectile", "Mine", "SlowOrb"]
	print("[子弹] 类型=%s, 速度=%.1f, 寿命=%.1fs" % [type_names[carrier.carrier_type], effective_velocity, lifetime_remaining])

	rule_timers.clear()
	rule_triggered.clear()
	for rule in spell_data.topology_rules:
		rule_timers.append(0.0)
		rule_triggered.append(false)

	_setup_visuals()

func _setup_visuals() -> void:
	if carrier == null:
		print("[子弹] 警告: carrier 为 null，无法设置视觉效果")
		return

	var color = PHASE_COLORS.get(carrier.phase, Color.WHITE)
	modulate = color

	if visual_circle != null:
		visual_circle.color = color
		visual_circle.visible = true

	if trail != null:
		trail.default_color = Color(color.r, color.g, color.b, 0.5)

	var base_scale = maxf(carrier.size, 0.5)
	scale = Vector2(base_scale, base_scale)

	rotation = velocity.angle()

	visible = true
	modulate.a = 1.0

	print("[子弹] 视觉设置: 颜色=%s, 缩放=%.2f, 位置=%s" % [color, base_scale, global_position])

func _physics_process(delta: float) -> void:
	if carrier == null:
		return

	lifetime_remaining -= delta
	if lifetime_remaining <= 0:
		_trigger_death_rules()
		_die()
		return

	time_alive += delta

	_update_homing(delta)

	position += velocity * delta
	rotation = velocity.angle()

	_update_rule_timers(delta)

	_check_bounds()

func _update_rule_timers(delta: float) -> void:
	for i in range(spell_data.topology_rules.size()):
		var rule = spell_data.topology_rules[i]
		if not rule.enabled:
			continue

		rule_timers[i] += delta

		if rule.trigger is OnTimerTrigger:
			var timer_trigger = rule.trigger as OnTimerTrigger
			if rule_timers[i] >= timer_trigger.delay:
				if not rule_triggered[i] or not rule.trigger.trigger_once:
					_execute_rule(rule, i)
					rule_timers[i] = 0.0
					if rule.trigger.trigger_once:
						rule_triggered[i] = true

		elif rule.trigger is OnProximityTrigger:
			var prox_trigger = rule.trigger as OnProximityTrigger
			if not rule_triggered[i] or not rule.trigger.trigger_once:
				if _check_proximity_trigger(prox_trigger):
					_execute_rule(rule, i)
					if rule.trigger.trigger_once:
						rule_triggered[i] = true

func _check_proximity_trigger(trigger: OnProximityTrigger) -> bool:
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist = global_position.distance_to(enemy.global_position)
		if dist <= trigger.detection_radius:
			return true
	return false

func _execute_rule(rule: TopologyRuleData, _rule_index: int) -> void:
	for action in rule.actions:
		_execute_action(action)

func _execute_action(action: ActionData) -> void:
	if action is DamageActionData:
		pass

	elif action is FissionActionData:
		var fission = action as FissionActionData
		_execute_fission(fission)

	elif action is AreaEffectActionData:
		var area = action as AreaEffectActionData
		_execute_area_effect(area)

	elif action is ApplyStatusActionData:
		pass

	elif action is SpawnExplosionActionData:
		var explosion = action as SpawnExplosionActionData
		_execute_spawn_explosion(explosion)

	elif action is SpawnDamageZoneActionData:
		var zone = action as SpawnDamageZoneActionData
		_execute_spawn_damage_zone(zone)

func _execute_fission(fission: FissionActionData) -> void:
	print("[子弹] 执行裂变: 数量=%d, 角度=%.1f°, 方向模式=%d" % [fission.spawn_count, fission.spread_angle, fission.direction_mode])
	var parent_direction = velocity.normalized() if velocity.length() > 0 else Vector2.RIGHT
	fission_triggered.emit(global_position, fission.child_spell_data, fission.spawn_count, fission.spread_angle, parent_direction, fission.direction_mode)

	if fission.destroy_parent:
		_die()

func _execute_area_effect(area: AreaEffectActionData) -> void:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()

	var shape = CircleShape2D.new()
	shape.radius = area.radius
	query.shape = shape
	query.transform = Transform2D(0, global_position)
	query.collision_mask = 2

	var results = space_state.intersect_shape(query)
	for result in results:
		var collider = result.collider
		if collider.has_method("take_damage"):
			collider.take_damage(area.damage_value, area.damage_type)
			hit_enemy.emit(collider, area.damage_value)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies"):
		_handle_enemy_collision(body)

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemies"):
		_handle_enemy_collision(area)

func _handle_enemy_collision(enemy: Node2D) -> void:
	for i in range(spell_data.topology_rules.size()):
		var rule = spell_data.topology_rules[i]
		if not rule.enabled:
			continue

		if rule.trigger.trigger_type == TriggerData.TriggerType.ON_CONTACT:
			if not rule_triggered[i] or not rule.trigger.trigger_once:
				_execute_contact_rule(rule, enemy)
				if rule.trigger.trigger_once:
					rule_triggered[i] = true

	var total_damage = _calculate_damage()

	if enemy.has_method("take_damage"):
		enemy.take_damage(total_damage, 0)

	hit_enemy.emit(enemy, total_damage)

	if piercing_remaining > 0:
		piercing_remaining -= 1
	else:
		call_deferred("_trigger_death_rules")
		_die()

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

func _calculate_damage() -> float:
	var total = 0.0
	var contact_rules_found = 0
	var damage_actions_found = 0

	for rule in spell_data.topology_rules:
		if rule.trigger.trigger_type == TriggerData.TriggerType.ON_CONTACT:
			contact_rules_found += 1
			for action in rule.actions:
				if action is DamageActionData:
					damage_actions_found += 1
					var dmg = action as DamageActionData
					var action_damage = dmg.damage_value * dmg.damage_multiplier
					total += action_damage

	var mass_multiplier = 1.0 + carrier.mass * 0.1
	total *= mass_multiplier

	if total <= 0:
		var base_dmg = carrier.base_damage if carrier.base_damage > 0 else 10.0
		total = base_dmg * mass_multiplier
		print("[保底伤害] 使用载体基础伤害: %.1f" % total)

	return total

func _trigger_death_rules() -> void:
	for i in range(spell_data.topology_rules.size()):
		var rule = spell_data.topology_rules[i]
		if rule.trigger.trigger_type == TriggerData.TriggerType.ON_DEATH:
			_execute_rule(rule, i)

func _check_bounds() -> void:
	var viewport_rect = get_viewport_rect()
	var margin = 100
	if position.x < -margin or position.x > viewport_rect.size.x + margin or \
	   position.y < -margin or position.y > viewport_rect.size.y + margin:
		_trigger_death_rules()
		_die()

func _die() -> void:
	projectile_died.emit(self)
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	call_deferred("queue_free")

func set_target(new_target: Node2D) -> void:
	target = new_target

func _update_homing(delta: float) -> void:
	if carrier.homing_strength <= 0:
		return

	if time_alive < carrier.homing_delay:
		return

	if target == null or not is_instance_valid(target):
		target = _find_nearest_enemy()
		if target == null:
			return

	var distance_to_target = global_position.distance_to(target.global_position)
	if distance_to_target > carrier.homing_range:
		var new_target = _find_nearest_enemy()
		if new_target != null:
			var new_distance = global_position.distance_to(new_target.global_position)
			if new_distance <= carrier.homing_range:
				target = new_target
				distance_to_target = new_distance
			else:
				return
		else:
			return

	var to_target = (target.global_position - global_position).normalized()
	var current_dir = velocity.normalized()

	var turn_amount = carrier.homing_turn_rate * carrier.homing_strength * delta
	var new_dir = current_dir.lerp(to_target, clampf(turn_amount, 0.0, 1.0))
	velocity = new_dir.normalized() * carrier.velocity

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

func _execute_spawn_explosion(explosion: SpawnExplosionActionData) -> void:
	print("[子弹] 生成爆炸: 伤害=%.1f, 半径=%.1f" % [explosion.explosion_damage, explosion.explosion_radius])
	explosion_requested.emit(
		global_position,
		explosion.explosion_damage,
		explosion.explosion_radius,
		explosion.damage_falloff,
		explosion.explosion_damage_type
	)

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
