class_name ActionExecutor extends Node

## 动作执行器（重构版）
## 采用处理器注册表模式替代 if-elif 链，支持新的能量系统
## 接入 SpatialGrid 进行高效索敌，接入 EventBus 进行解耦通信

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

var effect_multiplier: float = 1.0

# 当前法术的相态（用于VFX）
var current_phase: CarrierConfigData.Phase = CarrierConfigData.Phase.PLASMA

## 动作处理器注册表: { ActionType -> Callable }
## 使用注册表模式替代冗长的 if-elif 链，符合开闭原则
var _action_handlers: Dictionary = {}

func _ready() -> void:
	projectile_scene = load("res://scenes/battle_test/entities/projectile.tscn")
	damage_zone_scene = load("res://scenes/battle_test/entities/damage_zone.tscn")
	_register_default_handlers()

## 注册所有默认动作处理器
func _register_default_handlers() -> void:
	register_handler(ActionData.ActionType.DAMAGE, _execute_damage_action)
	register_handler(ActionData.ActionType.APPLY_STATUS, _execute_status_action)
	register_handler(ActionData.ActionType.DISPLACEMENT, _execute_displacement_action)
	register_handler(ActionData.ActionType.SHIELD, _execute_shield_action)
	register_handler(ActionData.ActionType.SPAWN_DAMAGE_ZONE, _execute_spawn_zone_action)
	register_handler(ActionData.ActionType.SPAWN_EXPLOSION, _execute_explosion_action)
	register_handler(ActionData.ActionType.CHAIN, _execute_chain_action)
	register_handler(ActionData.ActionType.FISSION, _execute_fission_action)
	register_handler(ActionData.ActionType.AREA_EFFECT, _execute_area_effect_action)
	register_handler(ActionData.ActionType.SUMMON, _execute_summon_action)
	register_handler(ActionData.ActionType.ENERGY_RESTORE, _execute_energy_restore_action)
	register_handler(ActionData.ActionType.CULTIVATION, _execute_cultivation_action)

## 注册自定义动作处理器（扩展点）
## action_type: ActionData.ActionType 枚举值
## handler: 处理函数，签名为 func(action: ActionData, context: Dictionary) -> void
func register_handler(action_type: int, handler: Callable) -> void:
	_action_handlers[action_type] = handler

## 注销动作处理器
func unregister_handler(action_type: int) -> void:
	_action_handlers.erase(action_type)

func initialize(_player: PlayerController) -> void:
	player = _player

## 执行动作（重构后的统一入口）
func execute_action(action: ActionData, context: Dictionary) -> void:
	if action == null:
		push_warning("[ActionExecutor] 动作为 null，跳过执行")
		return

	# 计算效果倍率
	var slot_level = context.get("slot_level", 1)
	effect_multiplier = 1.0 + (slot_level - 1) * 0.1
	
	# 应用武器特质效果修正
	var total_effect_modifier = context.get("total_effect_modifier", 1.0)
	effect_multiplier *= total_effect_modifier
	
	# 应用肢体效率修正
	var part_efficiency = context.get("effect_multiplier", 1.0)
	effect_multiplier *= part_efficiency
	
	# 获取当前相态（如果有载体信息）
	var carrier = context.get("carrier", null) as CarrierConfigData
	if carrier:
		current_phase = carrier.phase

	# 通过注册表查找并执行处理器
	if _action_handlers.has(action.action_type):
		_action_handlers[action.action_type].call(action, context)
	else:
		_execute_generic_action(action, context)
	
	# 通过 EventBus 发布动作执行事件（如果可用）
	_publish_action_event(action, context)

## 通过 EventBus 发布动作执行事件
func _publish_action_event(action: ActionData, context: Dictionary) -> void:
	if EventBus.instance == null:
		return
	EventBus.instance.publish(EventBus.EVENT_EXECUTE_ACTION, {
		"action_type": action.action_type,
		"context": context,
		"effect_multiplier": effect_multiplier
	})

# ============================================================
# 索敌方法（优先使用 SpatialGrid，回退到线性搜索）
# ============================================================

func _get_nearby_enemies(position: Vector2, radius: float) -> Array[Node2D]:
	# 优先使用 SpatialGrid 进行高效查询
	if SpatialGrid.instance != null:
		return SpatialGrid.instance.find_in_radius(position, radius, "enemies")
	
	# 回退到线性搜索
	var enemies: Array[Node2D] = []
	var all_enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in all_enemies:
		if not is_instance_valid(enemy):
			continue
		if position.distance_to(enemy.global_position) <= radius:
			enemies.append(enemy)
	return enemies

func _get_nearby_allies(position: Vector2, radius: float) -> Array[Node2D]:
	# 优先使用 SpatialGrid 进行高效查询
	if SpatialGrid.instance != null:
		return SpatialGrid.instance.find_in_radius(position, radius, "allies")
	
	# 回退到线性搜索
	var allies: Array[Node2D] = []
	var all_allies = get_tree().get_nodes_in_group("allies")
	for ally in all_allies:
		if not is_instance_valid(ally):
			continue
		if position.distance_to(ally.global_position) <= radius:
			allies.append(ally)
	return allies

func _find_nearest_enemy(position: Vector2, max_radius: float = 0.0) -> Node2D:
	# 优先使用 SpatialGrid 进行高效查询
	if SpatialGrid.instance != null:
		return SpatialGrid.instance.find_nearest(position, "enemies", max_radius)
	
	# 回退到线性搜索
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var nearest_dist = INF
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist = position.distance_to(enemy.global_position)
		if dist < nearest_dist and (max_radius <= 0 or dist <= max_radius):
			nearest_dist = dist
			nearest = enemy
	return nearest

# ============================================================
# 动作处理器实现
# ============================================================

func _execute_damage_action(action: ActionData, context: Dictionary) -> void:
	var dmg_action = action as DamageActionData
	if dmg_action == null:
		return
	
	var target = context.get("target", null) as Node2D
	var damage = dmg_action.damage_value * effect_multiplier

	if target == null:
		var enemies = _get_nearby_enemies(context.get("position", Vector2.ZERO), 100.0)
		for enemy in enemies:
			_apply_damage_to_target(enemy, damage, dmg_action)
	else:
		_apply_damage_to_target(target, damage, dmg_action)

func _apply_damage_to_target(target: Node2D, damage: float, action: DamageActionData) -> void:
	if target == null or not is_instance_valid(target):
		return

	var final_damage = damage

	# 伤害类型修正（使用数据驱动的修正表替代硬编码的 match）
	var type_modifier = _get_damage_type_modifier(action.damage_type)
	final_damage *= type_modifier

	if target.has_method("take_damage"):
		target.take_damage(final_damage)
		damage_dealt.emit(target, final_damage, "engraving")
		
		# 播放命中特效
		_spawn_impact_vfx(target.global_position, action.damage_type)

## 获取伤害类型修正系数（数据驱动，便于扩展和平衡调整）
static var DAMAGE_TYPE_MODIFIERS: Dictionary = {
	CarrierConfigData.DamageType.KINETIC_IMPACT: 1.0,
	CarrierConfigData.DamageType.ENTROPY_BURST: 1.0,
	CarrierConfigData.DamageType.CRYO_SHATTER: 1.0,
	CarrierConfigData.DamageType.VOID_EROSION: 1.0,
}

func _get_damage_type_modifier(damage_type: int) -> float:
	return DAMAGE_TYPE_MODIFIERS.get(damage_type, 1.0)

## 生成命中特效
func _spawn_impact_vfx(pos: Vector2, damage_type: int = 0) -> void:
	var phase = _damage_type_to_phase(damage_type)
	var impact_vfx = VFXFactory.create_impact_vfx(phase, 1.0)
	if impact_vfx:
		VFXFactory.spawn_at(impact_vfx, pos, get_tree().current_scene)

## 将伤害类型映射到相态（数据驱动）
static var DAMAGE_TYPE_TO_PHASE: Dictionary = {
	CarrierConfigData.DamageType.ENTROPY_BURST: CarrierConfigData.Phase.PLASMA,
	CarrierConfigData.DamageType.CRYO_SHATTER: CarrierConfigData.Phase.LIQUID,
	CarrierConfigData.DamageType.KINETIC_IMPACT: CarrierConfigData.Phase.SOLID,
}

func _damage_type_to_phase(dmg_type: int) -> CarrierConfigData.Phase:
	return DAMAGE_TYPE_TO_PHASE.get(dmg_type, current_phase)

func _execute_status_action(action: ActionData, context: Dictionary) -> void:
	var status_action = action as ApplyStatusActionData
	if status_action == null:
		return
	
	var target = context.get("target", null) as Node2D
	var duration = status_action.duration * effect_multiplier

	if target == null and status_action.apply_to_self:
		target = player

	if target == null:
		return

	# 获取 RuntimeSystemsManager 并应用状态效果
	var runtime_manager = get_tree().get_first_node_in_group("runtime_systems_manager")
	if runtime_manager != null and runtime_manager.has_method("apply_status"):
		runtime_manager.apply_status(target, status_action)
		status_applied.emit(target, status_action.get_status_name(), duration)
		_spawn_status_vfx(target, status_action.status_type, duration, status_action.effect_value)
	elif target.has_method("apply_status"):
		target.apply_status(status_action.status_type, duration, status_action.effect_value)
		status_applied.emit(target, status_action.get_status_name(), duration)
		_spawn_status_vfx(target, status_action.status_type, duration, status_action.effect_value)

## 生成状态效果特效
func _spawn_status_vfx(target: Node2D, status_type: ApplyStatusActionData.StatusType, duration: float, value: float) -> void:
	var status_vfx = VFXFactory.create_status_effect_vfx(status_type, duration, value, target)
	if status_vfx:
		get_tree().current_scene.add_child(status_vfx)

func _execute_displacement_action(action: ActionData, context: Dictionary) -> void:
	var disp_action = action as DisplacementActionData
	if disp_action == null:
		return
	
	var target = context.get("target", null) as Node2D
	var direction = context.get("direction", Vector2.RIGHT)
	var force = disp_action.displacement_force * effect_multiplier

	if target != null and target.has_method("apply_knockback") and player != null:
		var knockback_dir = (target.global_position - player.global_position).normalized()
		target.apply_knockback(knockback_dir * force)
		
		var from_pos = target.global_position
		var to_pos = from_pos + knockback_dir * force * 0.1
		_spawn_displacement_vfx(disp_action.displacement_type, from_pos, to_pos, force)

	if disp_action.apply_to_self and player != null:
		var self_dir = direction.normalized()
		player.apply_impulse(self_dir * force * 0.5)
		
		var from_pos = player.global_position
		var to_pos = from_pos + self_dir * force * 0.05
		_spawn_displacement_vfx(DisplacementActionData.DisplacementType.DASH, from_pos, to_pos, force * 0.5)

## 生成位移特效
func _spawn_displacement_vfx(displacement_type: DisplacementActionData.DisplacementType, from_pos: Vector2, to_pos: Vector2, force: float) -> void:
	var displacement_vfx = VFXFactory.create_displacement_vfx(displacement_type, from_pos, to_pos, force)
	if displacement_vfx:
		get_tree().current_scene.add_child(displacement_vfx)

func _execute_shield_action(action: ActionData, _context: Dictionary) -> void:
	var shield_action = action as ShieldActionData
	if shield_action == null or player == null:
		return

	var shield_value = shield_action.shield_amount * effect_multiplier
	var duration = shield_action.shield_duration

	if player.has_method("apply_shield"):
		player.apply_shield(shield_value, duration)
	
	_spawn_shield_vfx(shield_action.shield_type, shield_value, duration, player)

## 生成护盾特效
func _spawn_shield_vfx(shield_type: ShieldActionData.ShieldType, amount: float, duration: float, target: Node2D) -> void:
	var shield_vfx = VFXFactory.create_shield_vfx(shield_type, amount, duration, 80.0, target)
	if shield_vfx:
		get_tree().current_scene.add_child(shield_vfx)

func _execute_spawn_zone_action(action: ActionData, context: Dictionary) -> void:
	var zone_action = action as SpawnDamageZoneActionData
	if zone_action == null or damage_zone_scene == null:
		return

	var position = context.get("position", Vector2.ZERO)
	var target_pos = context.get("target_position", position)

	# 优先使用对象池
	var zone: Node = null
	if ObjectPool.instance != null:
		zone = ObjectPool.instance.acquire("res://scenes/battle_test/entities/damage_zone.tscn")
	
	if zone == null:
		zone = damage_zone_scene.instantiate()
	
	if zone == null:
		return

	get_tree().current_scene.add_child(zone)
	zone.global_position = target_pos

	if zone.has_method("setup"):
		zone.setup(
			zone_action.zone_damage * effect_multiplier,
			zone_action.tick_interval,
			zone_action.zone_duration,
			zone_action.zone_radius * effect_multiplier
		)

	area_effect_created.emit(zone)

func _execute_explosion_action(action: ActionData, context: Dictionary) -> void:
	var exp_action = action as SpawnExplosionActionData
	if exp_action == null:
		return
	
	var position = context.get("target_position", context.get("position", Vector2.ZERO))
	var radius = exp_action.explosion_radius * effect_multiplier
	var damage = exp_action.explosion_damage * effect_multiplier
	
	# 播放爆炸特效
	var phase = _damage_type_to_phase(exp_action.explosion_damage_type)
	var explosion_vfx = VFXFactory.create_explosion_vfx(phase, radius, exp_action.damage_falloff)
	if explosion_vfx:
		VFXFactory.spawn_at(explosion_vfx, position, get_tree().current_scene)

	var enemies = _get_nearby_enemies(position, radius)

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist = position.distance_to(enemy.global_position)
		var falloff = 1.0 - (dist / radius) * exp_action.damage_falloff
		var final_damage = damage * maxf(0.1, falloff)

		if enemy.has_method("take_damage"):
			enemy.take_damage(final_damage)
			damage_dealt.emit(enemy, final_damage, "explosion")

		if enemy.has_method("apply_knockback"):
			var dir = (enemy.global_position - position).normalized()
			enemy.apply_knockback(dir * exp_action.knockback_force * falloff)

## 执行链式动作（委托给 ChainSystem 统一处理）
func _execute_chain_action(action: ActionData, context: Dictionary) -> void:
	var chain_action = action as ChainActionData
	if chain_action == null:
		return
	
	var start_target = context.get("target", null) as Node2D
	if start_target == null:
		# 尝试自动寻找最近的敌人作为链式起点
		var position = context.get("position", Vector2.ZERO)
		start_target = _find_nearest_enemy(position, chain_action.chain_range)
		if start_target == null:
			return
	
	var source_position = context.get("position", Vector2.ZERO)
	
	# 如果有效果倍率，创建修改后的链式数据
	var chain_data = chain_action
	if not is_equal_approx(effect_multiplier, 1.0):
		chain_data = chain_action.clone_deep() as ChainActionData
		chain_data.chain_damage *= effect_multiplier
	
	# 获取 RuntimeSystemsManager 中的 ChainSystem
	var runtime_manager = get_tree().get_first_node_in_group("runtime_systems_manager")
	if runtime_manager != null and runtime_manager.has_method("start_chain"):
		runtime_manager.start_chain(start_target, chain_data, source_position)
		damage_dealt.emit(start_target, chain_data.chain_damage, "chain")
	else:
		var chain_system = get_tree().get_first_node_in_group("chain_system")
		if chain_system != null:
			chain_system.start_chain(start_target, chain_data, source_position)
			damage_dealt.emit(start_target, chain_data.chain_damage, "chain")
		else:
			push_warning("[ActionExecutor] 无法找到 ChainSystem，链式效果未执行")

func _execute_fission_action(action: ActionData, context: Dictionary) -> void:
	var fission_action = action as FissionActionData
	if fission_action == null or projectile_scene == null:
		return
	
	if fission_action.child_spell_data == null:
		push_warning("[ActionExecutor] 裂变动作缺少子法术数据")
		return

	var position = context.get("position", Vector2.ZERO)
	var base_direction = context.get("direction", Vector2.RIGHT)
	
	# 播放裂变特效
	var fission_vfx = VFXFactory.create_fission_vfx(current_phase, fission_action.spawn_count, fission_action.spread_angle, 1.0)
	if fission_vfx:
		VFXFactory.spawn_at(fission_vfx, position, get_tree().current_scene)

	var spawn_count = fission_action.spawn_count
	for i in range(spawn_count):
		var angle_offset = (i - spawn_count / 2.0) * deg_to_rad(fission_action.spread_angle / maxf(1.0, spawn_count - 1.0))
		var direction = base_direction.rotated(angle_offset)

		# 优先使用对象池
		var projectile: Node = null
		if ObjectPool.instance != null:
			projectile = ObjectPool.instance.acquire("res://scenes/battle_test/entities/projectile.tscn")
		
		if projectile == null:
			projectile = projectile_scene.instantiate()
		
		if projectile == null:
			continue

		get_tree().current_scene.add_child(projectile)

		if projectile.has_method("initialize"):
			projectile.initialize(fission_action.child_spell_data, direction, position)

		projectile_spawned.emit(projectile)

func _execute_area_effect_action(action: ActionData, context: Dictionary) -> void:
	var area_action = action as AreaEffectActionData
	if area_action == null:
		return
	
	var position = context.get("position", Vector2.ZERO)
	var radius = area_action.radius * effect_multiplier

	var targets: Array[Node2D] = []

	if area_action.affect_enemies:
		targets.append_array(_get_nearby_enemies(position, radius))

	if area_action.affect_allies:
		targets.append_array(_get_nearby_allies(position, radius))

	# 播放区域效果特效
	var area_vfx = VFXFactory.create_explosion_vfx(current_phase, radius, 0.5)
	if area_vfx:
		VFXFactory.spawn_at(area_vfx, position, get_tree().current_scene)
	
	for target in targets:
		if target == null or not is_instance_valid(target):
			continue
		
		var dist = position.distance_to(target.global_position)
		var falloff = 1.0 - (dist / radius) * 0.5
		var damage = area_action.damage_value * effect_multiplier * maxf(0.1, falloff)
		
		if target.has_method("take_damage"):
			target.take_damage(damage)
			damage_dealt.emit(target, damage, "area_effect")

func _execute_summon_action(action: ActionData, context: Dictionary) -> void:
	var summon_action = action as SummonActionData
	if summon_action == null:
		return
	
	var position = context.get("position", Vector2.ZERO)
	
	# 播放召唤特效
	var summon_vfx = VFXFactory.create_summon_vfx(summon_action.summon_type, summon_action.summon_count)
	if summon_vfx:
		VFXFactory.spawn_at(summon_vfx, position, get_tree().current_scene)
	
	# 实际创建召唤物
	var runtime_manager = get_tree().get_first_node_in_group("runtime_systems_manager")
	if runtime_manager and runtime_manager.has_method("create_summon"):
		runtime_manager.create_summon(summon_action, position, player)

## 执行能量恢复动作
func _execute_energy_restore_action(action: ActionData, context: Dictionary) -> void:
	var restore_action = action as EnergyRestoreActionData
	if restore_action == null:
		return
	
	var targets: Array[Node2D] = []
	var position = context.get("position", Vector2.ZERO)
	
	if restore_action.apply_to_self and player != null:
		targets.append(player)
	
	if restore_action.apply_to_allies:
		targets.append_array(_get_nearby_allies(position, restore_action.effect_radius))
	
	var restore_value = restore_action.restore_value * effect_multiplier
	
	for target in targets:
		if not target.has_method("get_energy_system"):
			continue
		
		var energy_system = target.get_energy_system()
		if energy_system == null:
			continue
		
		var restored: float = 0.0
		
		match restore_action.restore_type:
			EnergyRestoreActionData.RestoreType.INSTANT:
				restored = energy_system.restore_energy(restore_value)
			EnergyRestoreActionData.RestoreType.PERCENTAGE:
				var amount = energy_system.current_energy_cap * restore_action.percentage
				restored = energy_system.restore_energy(amount)
			EnergyRestoreActionData.RestoreType.OVER_TIME:
				restored = energy_system.restore_energy(restore_value)
		
		if restored > 0:
			energy_restored.emit(target, restored)

## 执行修炼动作（恢复能量上限）
func _execute_cultivation_action(action: ActionData, context: Dictionary) -> void:
	var cult_action = action as CultivationActionData
	if cult_action == null:
		return
	
	var targets: Array[Node2D] = []
	var position = context.get("position", Vector2.ZERO)
	
	if cult_action.apply_to_self and player != null:
		targets.append(player)
	
	if cult_action.apply_to_allies:
		targets.append_array(_get_nearby_allies(position, cult_action.effect_radius))
	
	var cap_restore = cult_action.cap_restore_value * effect_multiplier
	var energy_cost = cult_action.get_energy_cost() * effect_multiplier
	
	for target in targets:
		if not target.has_method("get_energy_system"):
			continue
		
		var energy_system = target.get_energy_system()
		if energy_system == null:
			continue
		
		if energy_system.current_energy < energy_cost:
			continue
		
		var restored: float = 0.0
		
		match cult_action.cultivation_type:
			CultivationActionData.CultivationType.INSTANT:
				if energy_system.consume_energy(energy_cost):
					restored = energy_system.restore_energy_cap(cap_restore)
			CultivationActionData.CultivationType.OVER_TIME:
				if energy_system.consume_energy(energy_cost):
					restored = energy_system.restore_energy_cap(cap_restore)
			CultivationActionData.CultivationType.BOOST:
				pass
		
		if restored > 0:
			cap_restored.emit(target, restored)
			heal_applied.emit(target, restored)

func _execute_generic_action(action: ActionData, _context: Dictionary) -> void:
	push_warning("[ActionExecutor] 未注册的动作类型: %s (%d)" % [action.get_type_name(), action.action_type])
