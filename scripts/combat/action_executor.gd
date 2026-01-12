class_name ActionExecutor extends Node

signal damage_dealt(target: Node2D, damage: float, source: String)
signal heal_applied(target: Node2D, amount: float)
signal status_applied(target: Node2D, status: String, duration: float)
signal projectile_spawned(projectile: Node2D)
signal area_effect_created(area: Node2D)

var player: PlayerController = null

var projectile_scene: PackedScene
var damage_zone_scene: PackedScene
var explosion_scene: PackedScene

var effect_multiplier: float = 1.0

func _ready() -> void:
	projectile_scene = load("res://scenes/battle_test/entities/projectile.tscn")
	damage_zone_scene = load("res://scenes/battle_test/entities/damage_zone.tscn")

func initialize(_player: PlayerController) -> void:
	player = _player

func execute_action(action: ActionData, context: Dictionary) -> void:
	if action == null:
		return

	var slot_level = context.get("slot_level", 1)
	effect_multiplier = 1.0 + (slot_level - 1) * 0.1

	if action is DamageActionData:
		_execute_damage_action(action as DamageActionData, context)
	elif action is ApplyStatusActionData:
		_execute_status_action(action as ApplyStatusActionData, context)
	elif action is DisplacementActionData:
		_execute_displacement_action(action as DisplacementActionData, context)
	elif action is ShieldActionData:
		_execute_shield_action(action as ShieldActionData, context)
	elif action is SpawnDamageZoneActionData:
		_execute_spawn_zone_action(action as SpawnDamageZoneActionData, context)
	elif action is SpawnExplosionActionData:
		_execute_explosion_action(action as SpawnExplosionActionData, context)
	elif action is ChainActionData:
		_execute_chain_action(action as ChainActionData, context)
	elif action is FissionActionData:
		_execute_fission_action(action as FissionActionData, context)
	elif action is AreaEffectActionData:
		_execute_area_effect_action(action as AreaEffectActionData, context)
	elif action is SummonActionData:
		_execute_summon_action(action as SummonActionData, context)
	else:
		_execute_generic_action(action, context)

func _execute_damage_action(action: DamageActionData, context: Dictionary) -> void:
	var target = context.get("target", null) as Node2D
	var damage = action.damage_value * effect_multiplier

	if target == null:
		var enemies = _get_nearby_enemies(context.get("position", Vector2.ZERO), 100.0)
		for enemy in enemies:
			_apply_damage_to_target(enemy, damage, action)
	else:
		_apply_damage_to_target(target, damage, action)

func _apply_damage_to_target(target: Node2D, damage: float, action: DamageActionData) -> void:
	if target == null:
		return

	var final_damage = damage

	match action.damage_type:
		CarrierConfigData.DamageType.ENTROPY_BURST:
			final_damage *= 1.0
		CarrierConfigData.DamageType.CRYO_SHATTER:
			final_damage *= 1.0
		CarrierConfigData.DamageType.VOID_EROSION:
			final_damage *= 1.0
		CarrierConfigData.DamageType.KINETIC_IMPACT:
			final_damage *= 1.0

	if target.has_method("take_damage"):
		target.take_damage(final_damage)
		damage_dealt.emit(target, final_damage, "engraving")

func _execute_status_action(action: ApplyStatusActionData, context: Dictionary) -> void:
	var target = context.get("target", null) as Node2D
	var duration = action.duration * effect_multiplier

	if target == null and action.apply_to_self:
		target = player

	if target == null:
		return

	if target.has_method("apply_status"):
		target.apply_status(action.status_type, duration, action.effect_value)
		status_applied.emit(target, action.get_status_name(), duration)

func _execute_displacement_action(action: DisplacementActionData, context: Dictionary) -> void:
	var target = context.get("target", null) as Node2D
	var direction = context.get("direction", Vector2.RIGHT)
	var force = action.force * effect_multiplier

	if target != null and target.has_method("apply_knockback"):
		var knockback_dir = (target.global_position - player.global_position).normalized()
		target.apply_knockback(knockback_dir * force)

	if action.apply_to_self and player != null:
		var self_dir = direction.normalized()
		player.apply_impulse(self_dir * force * 0.5)

func _execute_shield_action(action: ShieldActionData, context: Dictionary) -> void:
	if player == null:
		return

	var shield_value = action.shield_amount * effect_multiplier
	var duration = action.shield_duration

	if player.has_method("apply_shield"):
		player.apply_shield(shield_value, duration)

func _execute_spawn_zone_action(action: SpawnDamageZoneActionData, context: Dictionary) -> void:
	if damage_zone_scene == null:
		return

	var position = context.get("position", Vector2.ZERO)
	var target_pos = context.get("target_position", position)

	var zone = damage_zone_scene.instantiate()
	if zone == null:
		return

	get_tree().current_scene.add_child(zone)
	zone.global_position = target_pos

	if zone.has_method("setup"):
		zone.setup(
			action.damage_per_tick * effect_multiplier,
			action.tick_interval,
			action.duration,
			action.radius * effect_multiplier
		)

	area_effect_created.emit(zone)

func _execute_explosion_action(action: SpawnExplosionActionData, context: Dictionary) -> void:
	var position = context.get("target_position", context.get("position", Vector2.ZERO))
	var radius = action.radius * effect_multiplier
	var damage = action.damage * effect_multiplier

	var enemies = _get_nearby_enemies(position, radius)

	for enemy in enemies:
		var dist = position.distance_to(enemy.global_position)
		var falloff = 1.0 - (dist / radius) * action.damage_falloff
		var final_damage = damage * max(0.1, falloff)

		if enemy.has_method("take_damage"):
			enemy.take_damage(final_damage)
			damage_dealt.emit(enemy, final_damage, "explosion")

		if enemy.has_method("apply_knockback"):
			var dir = (enemy.global_position - position).normalized()
			enemy.apply_knockback(dir * action.knockback_force * falloff)

func _execute_chain_action(action: ChainActionData, context: Dictionary) -> void:
	var start_target = context.get("target", null) as Node2D
	if start_target == null:
		return

	var chain_targets: Array[Node2D] = [start_target]
	var current_target = start_target
	var chain_damage = action.chain_damage * effect_multiplier

	for i in range(action.chain_count):
		var next_target = _find_chain_target(current_target, chain_targets, action.chain_range)
		if next_target == null:
			break

		chain_targets.append(next_target)

		if next_target.has_method("take_damage"):
			var damage = chain_damage * pow(action.chain_damage_decay, i)
			next_target.take_damage(damage)
			damage_dealt.emit(next_target, damage, "chain")

		current_target = next_target

func _execute_fission_action(action: FissionActionData, context: Dictionary) -> void:
	if projectile_scene == null or action.child_spell_data == null:
		return

	var position = context.get("position", Vector2.ZERO)
	var base_direction = context.get("direction", Vector2.RIGHT)

	for i in range(action.spawn_count):
		var angle_offset = (i - action.spawn_count / 2.0) * deg_to_rad(action.spread_angle / max(1, action.spawn_count - 1))
		var direction = base_direction.rotated(angle_offset)

		var projectile = projectile_scene.instantiate()
		if projectile == null:
			continue

		get_tree().current_scene.add_child(projectile)

		if projectile.has_method("initialize"):
			projectile.initialize(action.child_spell_data, direction, position)

		projectile_spawned.emit(projectile)

func _execute_area_effect_action(action: AreaEffectActionData, context: Dictionary) -> void:
	var position = context.get("position", Vector2.ZERO)
	var radius = action.radius * effect_multiplier

	var targets: Array[Node2D] = []

	if action.affect_enemies:
		targets.append_array(_get_nearby_enemies(position, radius))

	if action.affect_allies:
		targets.append_array(_get_nearby_allies(position, radius))

	for target in targets:
		pass

func _execute_summon_action(action: SummonActionData, context: Dictionary) -> void:
	pass

func _execute_generic_action(action: ActionData, context: Dictionary) -> void:
	print("执行通用动作: %s" % action.get_type_name())

func _get_nearby_enemies(position: Vector2, radius: float) -> Array[Node2D]:
	var enemies: Array[Node2D] = []
	var all_enemies = get_tree().get_nodes_in_group("enemies")

	for enemy in all_enemies:
		if not is_instance_valid(enemy):
			continue
		if position.distance_to(enemy.global_position) <= radius:
			enemies.append(enemy)

	return enemies

func _get_nearby_allies(position: Vector2, radius: float) -> Array[Node2D]:
	var allies: Array[Node2D] = []
	var all_allies = get_tree().get_nodes_in_group("allies")

	for ally in all_allies:
		if not is_instance_valid(ally):
			continue
		if position.distance_to(ally.global_position) <= radius:
			allies.append(ally)

	return allies

func _find_chain_target(from: Node2D, exclude: Array[Node2D], max_range: float) -> Node2D:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var nearest_dist = max_range

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy in exclude:
			continue

		var dist = from.global_position.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy

	return nearest
