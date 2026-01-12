# action_executor.gd
# 效果执行器 - 执行刻录法术的各种效果
class_name ActionExecutor extends Node

## 信号
signal damage_dealt(target: Node2D, damage: float, source: String)
signal heal_applied(target: Node2D, amount: float)
signal status_applied(target: Node2D, status: String, duration: float)
signal projectile_spawned(projectile: Node2D)
signal area_effect_created(area: Node2D)

## 玩家控制器引用
var player: PlayerController = null

## 预加载场景
var projectile_scene: PackedScene
var damage_zone_scene: PackedScene
var explosion_scene: PackedScene

## 效果倍率（可被槽位等级影响）
var effect_multiplier: float = 1.0

func _ready() -> void:
	# 尝试加载场景
	projectile_scene = load("res://scenes/battle_test/entities/projectile.tscn")
	damage_zone_scene = load("res://scenes/battle_test/entities/damage_zone.tscn")
	# explosion_scene = load("res://scenes/battle_test/entities/explosion.tscn")

## 初始化执行器
func initialize(_player: PlayerController) -> void:
	player = _player

## 执行单个动作
func execute_action(action: ActionData, context: Dictionary) -> void:
	if action == null:
		return
	
	# 获取槽位等级倍率
	var slot_level = context.get("slot_level", 1)
	effect_multiplier = 1.0 + (slot_level - 1) * 0.1
	
	# 根据动作类型执行
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
		# 通用动作处理
		_execute_generic_action(action, context)

## 执行伤害动作
func _execute_damage_action(action: DamageActionData, context: Dictionary) -> void:
	var target = context.get("target", null) as Node2D
	var damage = action.damage_value * effect_multiplier
	
	# 如果没有指定目标，尝试对周围敌人造成伤害
	if target == null:
		var enemies = _get_nearby_enemies(context.get("position", Vector2.ZERO), 100.0)
		for enemy in enemies:
			_apply_damage_to_target(enemy, damage, action)
	else:
		_apply_damage_to_target(target, damage, action)

## 对目标应用伤害
func _apply_damage_to_target(target: Node2D, damage: float, action: DamageActionData) -> void:
	if target == null:
		return
	
	# 计算最终伤害
	var final_damage = damage
	
	# 应用伤害类型修正（使用CarrierConfigData.DamageType）
	match action.damage_type:
		CarrierConfigData.DamageType.ENTROPY_BURST:
			final_damage *= 1.0  # 可以添加元素克制
		CarrierConfigData.DamageType.CRYO_SHATTER:
			final_damage *= 1.0
		CarrierConfigData.DamageType.VOID_EROSION:
			final_damage *= 1.0
		CarrierConfigData.DamageType.KINETIC_IMPACT:
			final_damage *= 1.0
	
	# 应用伤害
	if target.has_method("take_damage"):
		target.take_damage(final_damage)
		damage_dealt.emit(target, final_damage, "engraving")

## 执行状态动作
func _execute_status_action(action: ApplyStatusActionData, context: Dictionary) -> void:
	var target = context.get("target", null) as Node2D
	var duration = action.duration * effect_multiplier
	
	# 如果没有目标，可能是自我增益
	if target == null and action.apply_to_self:
		target = player
	
	if target == null:
		return
	
	# 应用状态
	if target.has_method("apply_status"):
		target.apply_status(action.status_type, duration, action.effect_value)
		status_applied.emit(target, action.get_status_name(), duration)

## 执行位移动作
func _execute_displacement_action(action: DisplacementActionData, context: Dictionary) -> void:
	var target = context.get("target", null) as Node2D
	var direction = context.get("direction", Vector2.RIGHT)
	var force = action.force * effect_multiplier
	
	# 击退敌人
	if target != null and target.has_method("apply_knockback"):
		var knockback_dir = (target.global_position - player.global_position).normalized()
		target.apply_knockback(knockback_dir * force)
	
	# 自我位移（如冲刺）
	if action.apply_to_self and player != null:
		var self_dir = direction.normalized()
		player.apply_impulse(self_dir * force * 0.5)

## 执行护盾动作
func _execute_shield_action(action: ShieldActionData, context: Dictionary) -> void:
	if player == null:
		return
	
	var shield_value = action.shield_amount * effect_multiplier
	var duration = action.shield_duration

	# 应用护盾
	if player.has_method("apply_shield"):
		player.apply_shield(shield_value, duration)

## 执行生成伤害区域动作
func _execute_spawn_zone_action(action: SpawnDamageZoneActionData, context: Dictionary) -> void:
	if damage_zone_scene == null:
		return
	
	var position = context.get("position", Vector2.ZERO)
	var target_pos = context.get("target_position", position)
	
	# 创建伤害区域
	var zone = damage_zone_scene.instantiate()
	if zone == null:
		return
	
	get_tree().current_scene.add_child(zone)
	zone.global_position = target_pos
	
	# 配置区域
	if zone.has_method("setup"):
		zone.setup(
			action.damage_per_tick * effect_multiplier,
			action.tick_interval,
			action.duration,
			action.radius * effect_multiplier
		)
	
	area_effect_created.emit(zone)

## 执行爆炸动作
func _execute_explosion_action(action: SpawnExplosionActionData, context: Dictionary) -> void:
	var position = context.get("target_position", context.get("position", Vector2.ZERO))
	var radius = action.radius * effect_multiplier
	var damage = action.damage * effect_multiplier
	
	# 获取范围内的敌人
	var enemies = _get_nearby_enemies(position, radius)
	
	# 对所有敌人造成伤害
	for enemy in enemies:
		var dist = position.distance_to(enemy.global_position)
		var falloff = 1.0 - (dist / radius) * action.damage_falloff
		var final_damage = damage * max(0.1, falloff)
		
		if enemy.has_method("take_damage"):
			enemy.take_damage(final_damage)
			damage_dealt.emit(enemy, final_damage, "explosion")
		
		# 击退
		if enemy.has_method("apply_knockback"):
			var dir = (enemy.global_position - position).normalized()
			enemy.apply_knockback(dir * action.knockback_force * falloff)

## 执行链式动作
func _execute_chain_action(action: ChainActionData, context: Dictionary) -> void:
	var start_target = context.get("target", null) as Node2D
	if start_target == null:
		return
	
	var chain_targets: Array[Node2D] = [start_target]
	var current_target = start_target
	var chain_damage = action.chain_damage * effect_multiplier
	
	# 链式传播
	for i in range(action.chain_count):
		var next_target = _find_chain_target(current_target, chain_targets, action.chain_range)
		if next_target == null:
			break
		
		chain_targets.append(next_target)
		
		# 对目标造成伤害
		if next_target.has_method("take_damage"):
			var damage = chain_damage * pow(action.chain_damage_decay, i)
			next_target.take_damage(damage)
			damage_dealt.emit(next_target, damage, "chain")
		
		current_target = next_target

## 执行裂变动作
func _execute_fission_action(action: FissionActionData, context: Dictionary) -> void:
	if projectile_scene == null or action.child_spell_data == null:
		return
	
	var position = context.get("position", Vector2.ZERO)
	var base_direction = context.get("direction", Vector2.RIGHT)
	
	# 生成子弹
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

## 执行区域效果动作
func _execute_area_effect_action(action: AreaEffectActionData, context: Dictionary) -> void:
	var position = context.get("position", Vector2.ZERO)
	var radius = action.radius * effect_multiplier
	
	# 获取范围内的目标
	var targets: Array[Node2D] = []
	
	if action.affect_enemies:
		targets.append_array(_get_nearby_enemies(position, radius))
	
	if action.affect_allies:
		targets.append_array(_get_nearby_allies(position, radius))
	
	# 对所有目标应用效果
	for target in targets:
		# 这里可以扩展更多效果类型
		pass

## 执行召唤动作
func _execute_summon_action(action: SummonActionData, context: Dictionary) -> void:
	# 召唤系统需要更复杂的实现
	# 这里只是占位
	pass

## 执行通用动作
func _execute_generic_action(action: ActionData, context: Dictionary) -> void:
	# 通用处理
	print("执行通用动作: %s" % action.get_type_name())

## 获取附近的敌人
func _get_nearby_enemies(position: Vector2, radius: float) -> Array[Node2D]:
	var enemies: Array[Node2D] = []
	var all_enemies = get_tree().get_nodes_in_group("enemies")
	
	for enemy in all_enemies:
		if not is_instance_valid(enemy):
			continue
		if position.distance_to(enemy.global_position) <= radius:
			enemies.append(enemy)
	
	return enemies

## 获取附近的友方单位
func _get_nearby_allies(position: Vector2, radius: float) -> Array[Node2D]:
	var allies: Array[Node2D] = []
	var all_allies = get_tree().get_nodes_in_group("allies")
	
	for ally in all_allies:
		if not is_instance_valid(ally):
			continue
		if position.distance_to(ally.global_position) <= radius:
			allies.append(ally)
	
	return allies

## 查找链式目标
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
