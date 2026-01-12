class_name ActionExecutor extends Node

## 动作执行器
## 负责执行各种战斗动作，支持新的能量系统

signal damage_dealt(target: Node2D, damage: float, source: String)
signal heal_applied(target: Node2D, amount: float)
signal energy_restored(target: Node2D, amount: float)
signal cap_restored(target: Node2D, amount: float)
signal status_applied(target: Node2D, status: String, duration: float)
signal projectile_spawned(projectile: Node2D)
signal area_effect_created(area: Node2D)

var player: PlayerController = null

var projectile_scene: PackedScene
var damage_zone_scene: PackedScene
var explosion_scene: PackedScene

var effect_multiplier: float = 1.0

# 当前法术的相态（用于VFX）
var current_phase: CarrierConfigData.Phase = CarrierConfigData.Phase.PLASMA

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
	
	# 获取当前相态（如果有载体信息）
	var carrier = context.get("carrier", null) as CarrierConfigData
	if carrier:
		current_phase = carrier.phase

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
	elif action is EnergyRestoreActionData:
		_execute_energy_restore_action(action as EnergyRestoreActionData, context)
	elif action is CultivationActionData:
		_execute_cultivation_action(action as CultivationActionData, context)
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

	# 伤害类型修正（可以根据目标的能量系统状态进行调整）
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
		
		# 播放命中特效
		_spawn_impact_vfx(target.global_position, action.damage_type)

## 生成命中特效
func _spawn_impact_vfx(pos: Vector2, damage_type: int = 0) -> void:
	var phase = _damage_type_to_phase(damage_type)
	var impact_vfx = VFXFactory.create_impact_vfx(phase, 1.0)
	if impact_vfx:
		VFXFactory.spawn_at(impact_vfx, pos, get_tree().current_scene)

## 将伤害类型映射到相态
func _damage_type_to_phase(dmg_type: int) -> CarrierConfigData.Phase:
	match dmg_type:
		CarrierConfigData.DamageType.ENTROPY_BURST:
			return CarrierConfigData.Phase.PLASMA
		CarrierConfigData.DamageType.CRYO_SHATTER:
			return CarrierConfigData.Phase.LIQUID
		CarrierConfigData.DamageType.KINETIC_IMPACT:
			return CarrierConfigData.Phase.SOLID
		_:
			return current_phase

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
		
		# 播放状态效果特效
		_spawn_status_vfx(target, action.status_type, duration, action.effect_value)

## 生成状态效果特效
func _spawn_status_vfx(target: Node2D, status_type: ApplyStatusActionData.StatusType, duration: float, value: float) -> void:
	var status_vfx = VFXFactory.create_status_effect_vfx(status_type, duration, value, target)
	if status_vfx:
		get_tree().current_scene.add_child(status_vfx)

func _execute_displacement_action(action: DisplacementActionData, context: Dictionary) -> void:
	var target = context.get("target", null) as Node2D
	var direction = context.get("direction", Vector2.RIGHT)
	var force = action.force * effect_multiplier
	var position = context.get("position", Vector2.ZERO)

	if target != null and target.has_method("apply_knockback"):
		var knockback_dir = (target.global_position - player.global_position).normalized()
		target.apply_knockback(knockback_dir * force)
		
		# 播放位移特效
		var from_pos = target.global_position
		var to_pos = from_pos + knockback_dir * force * 0.1  # 估算目标位置
		_spawn_displacement_vfx(action.displacement_type, from_pos, to_pos, force)

	if action.apply_to_self and player != null:
		var self_dir = direction.normalized()
		player.apply_impulse(self_dir * force * 0.5)
		
		# 播放自身位移特效
		var from_pos = player.global_position
		var to_pos = from_pos + self_dir * force * 0.05
		_spawn_displacement_vfx(DisplacementActionData.DisplacementType.DASH, from_pos, to_pos, force * 0.5)

## 生成位移特效
func _spawn_displacement_vfx(displacement_type: DisplacementActionData.DisplacementType, from_pos: Vector2, to_pos: Vector2, force: float) -> void:
	var displacement_vfx = VFXFactory.create_displacement_vfx(displacement_type, from_pos, to_pos, force)
	if displacement_vfx:
		get_tree().current_scene.add_child(displacement_vfx)

func _execute_shield_action(action: ShieldActionData, _context: Dictionary) -> void:
	if player == null:
		return

	var shield_value = action.shield_amount * effect_multiplier
	var duration = action.shield_duration

	if player.has_method("apply_shield"):
		player.apply_shield(shield_value, duration)
	
	# 播放护盾特效
	_spawn_shield_vfx(action.shield_type, shield_value, duration, player)

## 生成护盾特效
func _spawn_shield_vfx(shield_type: ShieldActionData.ShieldType, amount: float, duration: float, target: Node2D) -> void:
	var shield_vfx = VFXFactory.create_shield_vfx(shield_type, amount, duration, 80.0, target)
	if shield_vfx:
		get_tree().current_scene.add_child(shield_vfx)

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
	# 注意：伤害区域的VFX已在damage_zone.gd中集成

func _execute_explosion_action(action: SpawnExplosionActionData, context: Dictionary) -> void:
	var position = context.get("target_position", context.get("position", Vector2.ZERO))
	var radius = action.radius * effect_multiplier
	var damage = action.damage * effect_multiplier
	
	# 播放爆炸特效
	var phase = _damage_type_to_phase(action.damage_type)
	var explosion_vfx = VFXFactory.create_explosion_vfx(phase, radius, action.damage_falloff)
	if explosion_vfx:
		VFXFactory.spawn_at(explosion_vfx, position, get_tree().current_scene)

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
	
	# 播放链式特效
	if chain_targets.size() >= 2:
		_spawn_chain_vfx(action.chain_type, chain_targets, chain_damage)

## 生成链式特效
func _spawn_chain_vfx(chain_type: ChainActionData.ChainType, targets: Array[Node2D], damage: float) -> void:
	var chain_vfx = VFXFactory.create_chain_vfx(chain_type, targets, damage, 0.1)
	if chain_vfx:
		get_tree().current_scene.add_child(chain_vfx)

func _execute_fission_action(action: FissionActionData, context: Dictionary) -> void:
	if projectile_scene == null or action.child_spell_data == null:
		return

	var position = context.get("position", Vector2.ZERO)
	var base_direction = context.get("direction", Vector2.RIGHT)
	
	# 播放裂变特效
	var fission_vfx = VFXFactory.create_fission_vfx(current_phase, action.spawn_count, action.spread_angle, 1.0)
	if fission_vfx:
		VFXFactory.spawn_at(fission_vfx, position, get_tree().current_scene)

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
	var position = context.get("position", Vector2.ZERO)
	
	# 播放召唤特效
	var summon_vfx = VFXFactory.create_summon_vfx(action.summon_type, action.summon_count)
	if summon_vfx:
		VFXFactory.spawn_at(summon_vfx, position, get_tree().current_scene)
	
	# TODO: 实际召唤物生成逻辑

## 执行能量恢复动作
func _execute_energy_restore_action(action: EnergyRestoreActionData, context: Dictionary) -> void:
	var targets: Array[Node2D] = []
	var position = context.get("position", Vector2.ZERO)
	
	# 确定目标
	if action.apply_to_self and player != null:
		targets.append(player)
	
	if action.apply_to_allies:
		targets.append_array(_get_nearby_allies(position, action.effect_radius))
	
	var restore_value = action.restore_value * effect_multiplier
	
	for target in targets:
		if not target.has_method("get_energy_system"):
			continue
		
		var energy_system = target.get_energy_system()
		if energy_system == null:
			continue
		
		var restored: float = 0.0
		
		match action.restore_type:
			EnergyRestoreActionData.RestoreType.INSTANT:
				restored = energy_system.restore_energy(restore_value)
			EnergyRestoreActionData.RestoreType.PERCENTAGE:
				var amount = energy_system.current_energy_cap * action.percentage
				restored = energy_system.restore_energy(amount)
			EnergyRestoreActionData.RestoreType.OVER_TIME:
				# 持续恢复需要通过状态效果系统实现
				# 这里先实现瞬间恢复作为简化
				restored = energy_system.restore_energy(restore_value)
		
		if restored > 0:
			energy_restored.emit(target, restored)

## 执行修炼动作（恢复能量上限）
func _execute_cultivation_action(action: CultivationActionData, context: Dictionary) -> void:
	var targets: Array[Node2D] = []
	var position = context.get("position", Vector2.ZERO)
	
	# 确定目标
	if action.apply_to_self and player != null:
		targets.append(player)
	
	if action.apply_to_allies:
		targets.append_array(_get_nearby_allies(position, action.effect_radius))
	
	var cap_restore = action.cap_restore_value * effect_multiplier
	var energy_cost = action.get_energy_cost() * effect_multiplier
	
	for target in targets:
		if not target.has_method("get_energy_system"):
			continue
		
		var energy_system = target.get_energy_system()
		if energy_system == null:
			continue
		
		# 检查能量是否足够
		if energy_system.current_energy < energy_cost:
			continue
		
		var restored: float = 0.0
		
		match action.cultivation_type:
			CultivationActionData.CultivationType.INSTANT:
				# 消耗能量，恢复能量上限
				if energy_system.consume_energy(energy_cost):
					restored = energy_system.restore_energy_cap(cap_restore)
			CultivationActionData.CultivationType.OVER_TIME:
				# 持续修复需要通过状态效果系统实现
				# 这里先实现瞬间修复作为简化
				if energy_system.consume_energy(energy_cost):
					restored = energy_system.restore_energy_cap(cap_restore)
			CultivationActionData.CultivationType.BOOST:
				# 临时提升修炼效率（需要状态效果系统支持）
				# 暂时跳过
				pass
		
		if restored > 0:
			cap_restored.emit(target, restored)
			heal_applied.emit(target, restored)  # 兼容旧信号

func _execute_generic_action(action: ActionData, _context: Dictionary) -> void:
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
