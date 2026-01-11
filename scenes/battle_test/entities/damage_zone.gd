# damage_zone.gd
# 持续伤害区域 - 在区域内持续造成伤害
extends Area2D
class_name DamageZone

## 信号
signal zone_hit(enemy: Node2D, damage: float)
signal zone_expired(zone: DamageZone)

## 配置
var damage_per_tick: float = 10.0
var tick_interval: float = 0.5
var radius: float = 80.0
var duration: float = 5.0
var damage_type: int = 0
var slow_amount: float = 0.0  # 减速效果 (0-1)

## 视觉组件
@onready var visual: Polygon2D = $Visual
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

## 运行时
var time_elapsed: float = 0.0
var tick_timer: float = 0.0
var enemies_in_zone: Array[Node2D] = []

func _ready():
	# 设置碰撞形状
	var shape = CircleShape2D.new()
	shape.radius = radius
	collision_shape.shape = shape
	
	# 连接信号
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	
	# 设置视觉效果
	_setup_visual()

func _process(delta: float) -> void:
	time_elapsed += delta
	tick_timer += delta
	
	# 定时造成伤害
	if tick_timer >= tick_interval:
		_deal_tick_damage()
		tick_timer = 0.0
	
	# 更新视觉效果
	_update_visual(delta)
	
	# 检查持续时间
	if time_elapsed >= duration:
		zone_expired.emit(self)
		queue_free()

## 初始化区域
func initialize(pos: Vector2, dmg: float, rad: float, dur: float, interval: float = 0.5, dmg_type: int = 0, slow: float = 0.0) -> void:
	global_position = pos
	damage_per_tick = dmg
	radius = rad
	duration = dur
	tick_interval = interval
	damage_type = dmg_type
	slow_amount = slow
	
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
		Color(1.0, 0.3, 0.0, 0.4),  # 火焰 - 橙红色
		Color(0.3, 0.6, 1.0, 0.4),  # 冰霜 - 蓝色
		Color(0.6, 0.2, 0.8, 0.4),  # 闪电 - 紫色
		Color(0.3, 0.8, 0.2, 0.4)   # 毒素 - 绿色
	]
	visual.color = colors[damage_type % colors.size()]

## 更新视觉效果
func _update_visual(_delta: float) -> void:
	if visual == null:
		return
	
	# 脉动效果
	var pulse = sin(time_elapsed * 3.0) * 0.1 + 0.9
	visual.scale = Vector2(pulse, pulse)
	
	# 临近结束时淡出
	if time_elapsed > duration - 1.0:
		var fade = (duration - time_elapsed) / 1.0
		visual.modulate.a = fade

## 造成 tick 伤害
func _deal_tick_damage() -> void:
	# 清理无效引用
	enemies_in_zone = enemies_in_zone.filter(func(e): return is_instance_valid(e))
	
	for enemy in enemies_in_zone:
		if enemy.has_method("take_damage"):
			enemy.take_damage(damage_per_tick, damage_type)
			zone_hit.emit(enemy, damage_per_tick)
		
		# 应用减速效果
		if slow_amount > 0 and enemy.has_method("apply_status"):
			enemy.apply_status(ApplyStatusActionData.StatusType.SLOWED, tick_interval + 0.1, slow_amount)

## 进入区域
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies"):
		if not enemies_in_zone.has(body):
			enemies_in_zone.append(body)

func _on_body_exited(body: Node2D) -> void:
	enemies_in_zone.erase(body)

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemies"):
		if not enemies_in_zone.has(area):
			enemies_in_zone.append(area)

func _on_area_exited(area: Area2D) -> void:
	enemies_in_zone.erase(area)
