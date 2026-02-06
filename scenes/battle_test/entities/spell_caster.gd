extends Node2D
class_name SpellCaster

## 法术施放器（优化版）
## 改进：嵌套深度传递给裂变子弹、对象池支持、减少冗余日志
## 将 _find_nearest_enemy 统一为使用 SpatialGrid 的版本

signal spell_cast(spell: SpellCoreData)
signal projectile_spawned(projectile: Projectile)

@export var auto_fire: bool = false
@export var fire_rate: float = 1.0
@export var aim_at_nearest: bool = true

var current_spell: SpellCoreData = null

var projectile_scene: PackedScene

var fire_cooldown: float = 0.0
var active_projectiles: Array[Projectile] = []

var stats = {
	"total_shots": 0,
	"total_hits": 0,
	"total_damage": 0.0,
	"fissions_triggered": 0
}

func _ready():
	projectile_scene = preload("res://scenes/battle_test/entities/projectile.tscn")

func _process(delta: float) -> void:
	if auto_fire and current_spell != null:
		fire_cooldown -= delta
		if fire_cooldown <= 0:
			fire()
			fire_cooldown = 1.0 / fire_rate

func set_spell(spell: SpellCoreData) -> void:
	current_spell = spell
	reset_stats()

func fire(target_position: Vector2 = Vector2.ZERO) -> void:
	if current_spell == null:
		return

	var direction: Vector2
	if target_position != Vector2.ZERO:
		direction = (target_position - global_position).normalized()
	elif aim_at_nearest:
		var nearest = _find_nearest_enemy(global_position)
		if nearest != null:
			direction = (nearest.global_position - global_position).normalized()
		else:
			direction = Vector2.RIGHT
	else:
		direction = Vector2.RIGHT

	var projectile = _spawn_projectile(current_spell, direction, 0)

	if current_spell.carrier != null and current_spell.carrier.homing_strength > 0:
		var nearest = _find_nearest_enemy(global_position)
		if nearest != null:
			projectile.set_target(nearest)

	stats.total_shots += 1
	spell_cast.emit(current_spell)

## 生成投射物（支持嵌套层级）
func _spawn_projectile(spell: SpellCoreData, direction: Vector2, nesting_level: int = 0) -> Projectile:
	# 优先使用对象池
	var projectile: Projectile = null
	if ObjectPool.instance != null:
		var pooled = ObjectPool.instance.acquire("res://scenes/battle_test/entities/projectile.tscn")
		if pooled is Projectile:
			projectile = pooled as Projectile
	
	if projectile == null:
		projectile = projectile_scene.instantiate() as Projectile
	
	get_tree().current_scene.add_child(projectile)

	projectile.initialize_with_nesting(spell, direction, global_position, nesting_level)

	projectile.hit_enemy.connect(_on_projectile_hit)
	projectile.projectile_died.connect(_on_projectile_died)
	projectile.fission_triggered.connect(_on_fission_triggered)
	projectile.explosion_requested.connect(_on_explosion_requested)
	projectile.damage_zone_requested.connect(_on_damage_zone_requested)

	active_projectiles.append(projectile)
	projectile_spawned.emit(projectile)

	return projectile

func _on_fission_triggered(pos: Vector2, child_spell: SpellCoreData, count: int, spread_angle: float = 360.0, parent_direction: Vector2 = Vector2.RIGHT, direction_mode: int = 0) -> void:
	stats.fissions_triggered += 1

	var spell_to_use: SpellCoreData
	if child_spell != null and child_spell.carrier != null:
		spell_to_use = child_spell
	else:
		spell_to_use = _create_simple_fission_spell()

	if spell_to_use.carrier == null:
		push_warning("[SpellCaster] 裂变法术没有载体配置!")
		return
	
	# 计算裂变子弹的嵌套层级（从触发裂变的投射物继承+1）
	# 注意：这里通过信号传递，无法直接获取父投射物的嵌套层级
	# 但 Projectile._execute_fission 已经有嵌套深度检查
	var child_nesting_level = 1  # 默认为1级嵌套
	
	# 播放裂变特效
	var phase = spell_to_use.carrier.phase if spell_to_use.carrier else CarrierConfigData.Phase.PLASMA
	var fission_vfx = VFXFactory.create_fission_vfx(phase, count, spread_angle, 1.0)
	if fission_vfx:
		VFXFactory.spawn_at(fission_vfx, pos, get_tree().current_scene)

	var base_direction: Vector2
	match direction_mode:
		FissionActionData.DirectionMode.INHERIT_PARENT:
			base_direction = parent_direction
		FissionActionData.DirectionMode.FIXED_WORLD:
			base_direction = Vector2.RIGHT
		FissionActionData.DirectionMode.TOWARD_NEAREST:
			var nearest = _find_nearest_enemy(pos)
			if nearest != null:
				base_direction = (nearest.global_position - pos).normalized()
			else:
				base_direction = parent_direction
		FissionActionData.DirectionMode.RANDOM:
			base_direction = Vector2.RIGHT.rotated(randf() * TAU)
		_:
			base_direction = parent_direction

	var base_angle = base_direction.angle()

	var angle_step = spread_angle / maxf(count - 1, 1) if count > 1 else 0.0
	var start_angle = -spread_angle / 2.0 if spread_angle < 360.0 else 0.0

	for i in range(count):
		var angle_offset: float
		if spread_angle >= 360.0:
			angle_offset = deg_to_rad(i * (360.0 / count))
		else:
			angle_offset = deg_to_rad(start_angle + i * angle_step)

		var final_angle = base_angle + angle_offset
		var direction = Vector2(cos(final_angle), sin(final_angle))

		call_deferred("_spawn_fission_projectile", spell_to_use, direction, pos, child_nesting_level)

## 统一的索敌方法（优先使用 SpatialGrid）
func _find_nearest_enemy(from_pos: Vector2) -> Node2D:
	if SpatialGrid.instance != null:
		return SpatialGrid.instance.find_nearest(from_pos, "enemies")
	
	# 回退到线性搜索
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var nearest_dist = INF

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist = from_pos.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy

	return nearest

## 生成裂变子弹（支持嵌套层级传递）
func _spawn_fission_projectile(spell: SpellCoreData, direction: Vector2, pos: Vector2, nesting_level: int = 0) -> void:
	# 优先使用对象池
	var projectile: Projectile = null
	if ObjectPool.instance != null:
		var pooled = ObjectPool.instance.acquire("res://scenes/battle_test/entities/projectile.tscn")
		if pooled is Projectile:
			projectile = pooled as Projectile
	
	if projectile == null:
		projectile = projectile_scene.instantiate() as Projectile
	
	if projectile == null:
		push_warning("[SpellCaster] 无法实例化裂变子弹")
		return

	get_tree().current_scene.add_child(projectile)

	await get_tree().process_frame

	projectile.initialize_with_nesting(spell, direction, pos, nesting_level)

	projectile.hit_enemy.connect(_on_projectile_hit)
	projectile.projectile_died.connect(_on_projectile_died)
	projectile.fission_triggered.connect(_on_fission_triggered)
	projectile.explosion_requested.connect(_on_explosion_requested)
	projectile.damage_zone_requested.connect(_on_damage_zone_requested)

	active_projectiles.append(projectile)

func _create_simple_fission_spell() -> SpellCoreData:
	var spell = SpellCoreData.new()
	spell.spell_name = "裂变碎片"

	spell.carrier = CarrierConfigData.new()
	spell.carrier.velocity = 350.0
	spell.carrier.lifetime = 3.0
	spell.carrier.mass = 0.5
	spell.carrier.size = 1.0
	spell.carrier.phase = SpellFactory._pick_random(SpellFactory.CARRIER_PHASES) if SpellFactory != null else randi() % 3

	var rule = TopologyRuleData.new()
	rule.trigger = TriggerData.new()
	rule.trigger.trigger_type = TriggerData.TriggerType.ON_CONTACT

	var damage = DamageActionData.new()
	damage.damage_value = 5.0
	var actions: Array[ActionData] = [damage]
	rule.actions = actions

	var rules: Array[TopologyRuleData] = [rule]
	spell.topology_rules = rules

	return spell

func _on_projectile_hit(_enemy: Node2D, damage: float) -> void:
	stats.total_hits += 1
	stats.total_damage += damage

func _on_projectile_died(projectile: Projectile) -> void:
	active_projectiles.erase(projectile)

func reset_stats() -> void:
	stats.total_shots = 0
	stats.total_hits = 0
	stats.total_damage = 0.0
	stats.fissions_triggered = 0

func get_stats() -> Dictionary:
	var hit_rate = 0.0
	if stats.total_shots > 0:
		hit_rate = float(stats.total_hits) / float(stats.total_shots) * 100.0

	return {
		"total_shots": stats.total_shots,
		"total_hits": stats.total_hits,
		"total_damage": stats.total_damage,
		"hit_rate": hit_rate,
		"fissions_triggered": stats.fissions_triggered,
		"active_projectiles": active_projectiles.size()
	}

func clear_projectiles() -> void:
	for projectile in active_projectiles:
		if is_instance_valid(projectile):
			projectile.queue_free()
	active_projectiles.clear()

func _on_explosion_requested(pos: Vector2, damage: float, radius: float, falloff: float, damage_type: int) -> void:
	call_deferred("_spawn_explosion", pos, damage, radius, falloff, damage_type)

func _spawn_explosion(pos: Vector2, damage: float, radius: float, falloff: float, damage_type: int) -> void:
	var explosion_scene_res = preload("res://scenes/battle_test/entities/explosion.tscn")
	var explosion = explosion_scene_res.instantiate() as Explosion
	get_tree().current_scene.add_child(explosion)
	explosion.initialize(pos, damage, radius, falloff, damage_type)

	explosion.explosion_hit.connect(_on_explosion_hit)

func _on_damage_zone_requested(pos: Vector2, damage: float, radius: float, duration: float, interval: float, damage_type: int, slow: float) -> void:
	call_deferred("_spawn_damage_zone", pos, damage, radius, duration, interval, damage_type, slow)

func _spawn_damage_zone(pos: Vector2, damage: float, radius: float, duration: float, interval: float, damage_type: int, slow: float) -> void:
	var zone_scene = preload("res://scenes/battle_test/entities/damage_zone.tscn")
	var zone = zone_scene.instantiate() as DamageZone
	get_tree().current_scene.add_child(zone)
	zone.initialize(pos, damage, radius, duration, interval, damage_type, slow)

	zone.zone_hit.connect(_on_zone_hit)

func _on_explosion_hit(_enemy: Node2D, damage: float) -> void:
	stats.total_hits += 1
	stats.total_damage += damage

func _on_zone_hit(_enemy: Node2D, damage: float) -> void:
	stats.total_hits += 1
	stats.total_damage += damage
