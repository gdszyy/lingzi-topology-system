# spell_caster.gd
# 法术发射器 - 负责发射法术并管理子弹
extends Node2D
class_name SpellCaster

## 信号
signal spell_cast(spell: SpellCoreData)
signal projectile_spawned(projectile: Projectile)

## 配置
@export var auto_fire: bool = false
@export var fire_rate: float = 1.0  # 每秒发射次数
@export var aim_at_nearest: bool = true

## 当前法术
var current_spell: SpellCoreData = null

## 子弹场景
var projectile_scene: PackedScene

## 运行时
var fire_cooldown: float = 0.0
var projectile_pool: Array[Projectile] = []
var active_projectiles: Array[Projectile] = []

## 统计
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

## 设置当前法术
func set_spell(spell: SpellCoreData) -> void:
	current_spell = spell
	reset_stats()

## 发射法术
func fire(target_position: Vector2 = Vector2.ZERO) -> void:
	if current_spell == null:
		return
	
	# 计算方向
	var direction: Vector2
	if target_position != Vector2.ZERO:
		direction = (target_position - global_position).normalized()
	elif aim_at_nearest:
		var nearest = _find_nearest_enemy()
		if nearest != null:
			direction = (nearest.global_position - global_position).normalized()
		else:
			direction = Vector2.RIGHT
	else:
		direction = Vector2.RIGHT
	
	# 创建子弹
	var projectile = _spawn_projectile(current_spell, direction)
	
	# 设置追踪目标
	if current_spell.carrier != null and current_spell.carrier.homing_strength > 0:
		var nearest = _find_nearest_enemy()
		if nearest != null:
			projectile.set_target(nearest)
	
	stats.total_shots += 1
	spell_cast.emit(current_spell)

## 生成子弹
func _spawn_projectile(spell: SpellCoreData, direction: Vector2) -> Projectile:
	var projectile = projectile_scene.instantiate() as Projectile
	get_tree().current_scene.add_child(projectile)
	
	projectile.initialize(spell, direction, global_position)
	
	# 连接信号
	projectile.hit_enemy.connect(_on_projectile_hit)
	projectile.projectile_died.connect(_on_projectile_died)
	projectile.fission_triggered.connect(_on_fission_triggered)
	projectile.explosion_requested.connect(_on_explosion_requested)
	projectile.damage_zone_requested.connect(_on_damage_zone_requested)
	
	active_projectiles.append(projectile)
	projectile_spawned.emit(projectile)
	
	return projectile

## 处理裂变
func _on_fission_triggered(pos: Vector2, child_spell: SpellCoreData, count: int, spread_angle: float = 360.0, parent_direction: Vector2 = Vector2.RIGHT, direction_mode: int = 0) -> void:
	stats.fissions_triggered += 1
	var mode_names = ["INHERIT_PARENT", "FIXED_WORLD", "TOWARD_NEAREST", "RANDOM"]
	print("[裂变触发] 位置: %s, 数量: %d, 扩散角度: %.1f°, 方向模式: %s" % [pos, count, spread_angle, mode_names[direction_mode]])
	
	# 如果没有子法术数据，使用简化版本
	var spell_to_use: SpellCoreData
	if child_spell != null and child_spell.carrier != null:
		spell_to_use = child_spell
		print("  使用子法术: %s" % child_spell.spell_name)
	else:
		spell_to_use = _create_simple_fission_spell()
		print("  使用默认裂变碑片（原子法术无效或无载体）")
	
	# 验证法术数据
	if spell_to_use.carrier == null:
		print("  [错误] 法术没有载体配置!")
		return
	
	print("  子弹属性: 速度=%.1f, 生命=%.1fs, 大小=%.2f" % [
		spell_to_use.carrier.velocity,
		spell_to_use.carrier.lifetime,
		spell_to_use.carrier.size
	])
	
	# 确定基准方向
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
	
	# 生成裂变子弹
	var angle_step = spread_angle / maxf(count - 1, 1) if count > 1 else 0.0
	var start_angle = -spread_angle / 2.0 if spread_angle < 360.0 else 0.0
	
	var spawned_count = 0
	for i in range(count):
		var angle_offset: float
		if spread_angle >= 360.0:
			# 全周分布
			angle_offset = deg_to_rad(i * (360.0 / count))
		else:
			# 扇形分布
			angle_offset = deg_to_rad(start_angle + i * angle_step)
		
		# 以基准方向为中心进行扩散
		var final_angle = base_angle + angle_offset
		var direction = Vector2(cos(final_angle), sin(final_angle))
		
		# 使用 call_deferred 避免在物理查询期间创建节点
		call_deferred("_spawn_fission_projectile", spell_to_use, direction, pos)
		spawned_count += 1
	
	print("  请求生成 %d 个裂变子弹" % spawned_count)

## 查找最近的敌人
func _find_nearest_enemy(from_pos: Vector2) -> Node2D:
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

## 延迟生成裂变子弹
func _spawn_fission_projectile(spell: SpellCoreData, direction: Vector2, pos: Vector2) -> void:
	var projectile = projectile_scene.instantiate() as Projectile
	if projectile == null:
		print("  [错误] 无法实例化子弹场景!")
		return
	
	# 先添加到场景树，让@onready变量生效
	get_tree().current_scene.add_child(projectile)
	
	# 等待一帧确保_ready()已执行
	await get_tree().process_frame
	
	# 再初始化
	projectile.initialize(spell, direction, pos)
	
	# 连接所有信号
	projectile.hit_enemy.connect(_on_projectile_hit)
	projectile.projectile_died.connect(_on_projectile_died)
	projectile.fission_triggered.connect(_on_fission_triggered)
	projectile.explosion_requested.connect(_on_explosion_requested)
	projectile.damage_zone_requested.connect(_on_damage_zone_requested)
	
	active_projectiles.append(projectile)
	print("  [裂变] 子弹已生成于 %s, 方向 %s" % [pos, direction])

## 创建简单裂变法术
func _create_simple_fission_spell() -> SpellCoreData:
	var spell = SpellCoreData.new()
	spell.spell_name = "裂变碎片"
	
	spell.carrier = CarrierConfigData.new()
	spell.carrier.velocity = 350.0
	spell.carrier.lifetime = 3.0  # 增加生命时间
	spell.carrier.mass = 0.5
	spell.carrier.size = 1.0  # 增大尺寸确保可见
	spell.carrier.phase = randi() % 3  # 随机相态以便有不同颜色
	
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

## 子弹命中
func _on_projectile_hit(_enemy: Node2D, damage: float) -> void:
	stats.total_hits += 1
	stats.total_damage += damage

## 子弹死亡
func _on_projectile_died(projectile: Projectile) -> void:
	active_projectiles.erase(projectile)

## 查找最近敌人
func _find_nearest_enemy() -> Node2D:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var nearest_dist = INF
	
	for enemy in enemies:
		var dist = global_position.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy
	
	return nearest

## 重置统计
func reset_stats() -> void:
	stats.total_shots = 0
	stats.total_hits = 0
	stats.total_damage = 0.0
	stats.fissions_triggered = 0

## 获取统计
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

## 清除所有子弹
func clear_projectiles() -> void:
	for projectile in active_projectiles:
		if is_instance_valid(projectile):
			projectile.queue_free()
	active_projectiles.clear()

## 处理爆炸请求
func _on_explosion_requested(pos: Vector2, damage: float, radius: float, falloff: float, damage_type: int) -> void:
	print("[爆炸请求] 位置: %s, 伤害: %.1f, 半径: %.1f" % [pos, damage, radius])
	
	var explosion_scene = preload("res://scenes/battle_test/entities/explosion.tscn")
	var explosion = explosion_scene.instantiate() as Explosion
	get_tree().current_scene.add_child(explosion)
	explosion.initialize(pos, damage, radius, falloff, damage_type)
	
	# 连接信号统计伤害
	explosion.explosion_hit.connect(_on_explosion_hit)

## 处理伤害区域请求
func _on_damage_zone_requested(pos: Vector2, damage: float, radius: float, duration: float, interval: float, damage_type: int, slow: float) -> void:
	print("[伤害区域请求] 位置: %s, 伤害: %.1f, 半径: %.1f, 持续: %.1fs" % [pos, damage, radius, duration])
	
	var zone_scene = preload("res://scenes/battle_test/entities/damage_zone.tscn")
	var zone = zone_scene.instantiate() as DamageZone
	get_tree().current_scene.add_child(zone)
	zone.initialize(pos, damage, radius, duration, interval, damage_type, slow)
	
	# 连接信号统计伤害
	zone.zone_hit.connect(_on_zone_hit)

## 爆炸命中
func _on_explosion_hit(_enemy: Node2D, damage: float) -> void:
	stats.total_hits += 1
	stats.total_damage += damage

## 伤害区域命中
func _on_zone_hit(_enemy: Node2D, damage: float) -> void:
	stats.total_hits += 1
	stats.total_damage += damage
