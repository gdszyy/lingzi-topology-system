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
	
	active_projectiles.append(projectile)
	projectile_spawned.emit(projectile)
	
	return projectile

## 处理裂变
func _on_fission_triggered(pos: Vector2, child_spell: SpellCoreData, count: int) -> void:
	stats.fissions_triggered += 1
	
	# 如果没有子法术数据，使用简化版本
	var spell_to_use = child_spell if child_spell != null else _create_simple_fission_spell()
	
	# 生成裂变子弹
	var angle_step = 360.0 / count
	for i in range(count):
		var angle = deg_to_rad(i * angle_step)
		var direction = Vector2(cos(angle), sin(angle))
		
		var projectile = projectile_scene.instantiate() as Projectile
		get_tree().current_scene.add_child(projectile)
		projectile.initialize(spell_to_use, direction, pos)
		
		projectile.hit_enemy.connect(_on_projectile_hit)
		projectile.projectile_died.connect(_on_projectile_died)
		projectile.fission_triggered.connect(_on_fission_triggered)
		
		active_projectiles.append(projectile)

## 创建简单裂变法术
func _create_simple_fission_spell() -> SpellCoreData:
	var spell = SpellCoreData.new()
	spell.spell_name = "裂变碎片"
	
	spell.carrier = CarrierConfigData.new()
	spell.carrier.velocity = 300.0
	spell.carrier.lifetime = 1.5
	spell.carrier.mass = 0.5
	spell.carrier.size = 0.5
	
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
func _on_projectile_hit(enemy: Node2D, damage: float) -> void:
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
