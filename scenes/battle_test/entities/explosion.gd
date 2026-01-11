# explosion.gd
# 爆炸实体 - 瞬间范围伤害效果
extends Area2D
class_name Explosion

## 信号
signal explosion_hit(enemy: Node2D, damage: float)
signal explosion_finished(explosion: Explosion)

## 配置
var damage: float = 50.0
var radius: float = 100.0
var damage_falloff: float = 0.5  # 边缘伤害衰减
var damage_type: int = 0
var duration: float = 0.3  # 视觉效果持续时间

## 视觉组件
@onready var visual: Polygon2D = $Visual
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

## 运行时
var time_elapsed: float = 0.0
var has_dealt_damage: bool = false

func _ready():
	# 设置碰撞形状
	var shape = CircleShape2D.new()
	shape.radius = radius
	collision_shape.shape = shape
	
	# 设置视觉效果
	_setup_visual()

func _process(delta: float) -> void:
	time_elapsed += delta
	
	# 在第一帧造成伤害
	if not has_dealt_damage:
		_deal_damage()
		has_dealt_damage = true
	
	# 更新视觉效果（淡出）
	_update_visual(delta)
	
	# 结束
	if time_elapsed >= duration:
		explosion_finished.emit(self)
		queue_free()

## 初始化爆炸
func initialize(pos: Vector2, dmg: float, rad: float, falloff: float = 0.5, dmg_type: int = 0) -> void:
	global_position = pos
	damage = dmg
	radius = rad
	damage_falloff = falloff
	damage_type = dmg_type
	
	# 更新碰撞形状
	if collision_shape and collision_shape.shape:
		(collision_shape.shape as CircleShape2D).radius = radius

## 设置视觉效果
func _setup_visual() -> void:
	if visual == null:
		return
	
	# 创建圆形多边形
	var points = PackedVector2Array()
	var segments = 32
	for i in range(segments):
		var angle = i * TAU / segments
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	visual.polygon = points
	
	# 设置颜色（根据伤害类型）
	var colors = [
		Color(1.0, 0.5, 0.0, 0.8),  # 火焰 - 橙色
		Color(0.5, 0.8, 1.0, 0.8),  # 冰霜 - 蓝色
		Color(0.8, 0.2, 0.8, 0.8),  # 闪电 - 紫色
		Color(0.5, 0.8, 0.2, 0.8)   # 毒素 - 绿色
	]
	visual.color = colors[damage_type % colors.size()]

## 更新视觉效果
func _update_visual(_delta: float) -> void:
	if visual == null:
		return
	
	# 淡出效果
	var progress = time_elapsed / duration
	visual.modulate.a = 1.0 - progress
	
	# 扩张效果
	var scale_factor = 1.0 + progress * 0.3
	visual.scale = Vector2(scale_factor, scale_factor)

## 造成伤害
func _deal_damage() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		
		var distance = global_position.distance_to(enemy.global_position)
		if distance <= radius:
			# 计算距离衰减
			var distance_ratio = distance / radius
			var damage_multiplier = 1.0 - (distance_ratio * damage_falloff)
			var final_damage = damage * damage_multiplier
			
			if enemy.has_method("take_damage"):
				enemy.take_damage(final_damage, damage_type)
				explosion_hit.emit(enemy, final_damage)
