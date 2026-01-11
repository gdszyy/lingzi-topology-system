# dummy_enemy.gd
# 沙包敌人 - 不会死亡、持续移动的测试目标
extends Area2D
class_name DummyEnemy

## 信号
signal damage_taken(amount: float)

## 属性
@export var move_speed: float = 100.0
@export var move_pattern: MovePattern = MovePattern.PATROL

## 移动模式
enum MovePattern {
	PATROL,           # 巡逻（来回移动）
	CIRCULAR,         # 圆周运动
	FIGURE_EIGHT,     # 8字形运动
	RANDOM_WALK,      # 随机游走
	ORBIT             # 围绕中心点轨道运动
}

## 运行时状态
var move_time: float = 0.0
var start_position: Vector2
var patrol_direction: int = 1
var random_target: Vector2
var orbit_center: Vector2
var orbit_radius: float = 150.0
var orbit_speed: float = 1.5

## 伤害统计
var total_damage_received: float = 0.0
var hit_count: int = 0
var last_hit_time: float = 0.0

## 视觉组件
@onready var sprite: Polygon2D = $Visual
@onready var damage_label: Label = $DamageLabel

## 颜色
const NORMAL_COLOR = Color(0.2, 0.6, 0.8)       # 蓝色（区别于普通敌人的红色）
const HIT_COLOR = Color(0.8, 0.8, 0.2)          # 黄色闪烁

func _ready():
	add_to_group("enemies")
	add_to_group("dummy_enemies")
	start_position = global_position
	orbit_center = start_position
	random_target = start_position
	_update_damage_display()

func _physics_process(delta: float) -> void:
	move_time += delta
	_update_movement(delta)

## 更新移动
func _update_movement(delta: float) -> void:
	if move_speed <= 0:
		return
	
	match move_pattern:
		MovePattern.PATROL:
			_move_patrol(delta)
		MovePattern.CIRCULAR:
			_move_circular(delta)
		MovePattern.FIGURE_EIGHT:
			_move_figure_eight(delta)
		MovePattern.RANDOM_WALK:
			_move_random_walk(delta)
		MovePattern.ORBIT:
			_move_orbit(delta)

## 巡逻移动
func _move_patrol(delta: float) -> void:
	var patrol_distance = 200.0
	position.x += patrol_direction * move_speed * delta
	
	if abs(position.x - start_position.x) > patrol_distance:
		patrol_direction *= -1

## 圆周运动
func _move_circular(delta: float) -> void:
	var radius = 100.0
	var angular_speed = move_speed / radius
	position.x = start_position.x + cos(move_time * angular_speed) * radius
	position.y = start_position.y + sin(move_time * angular_speed) * radius

## 8字形运动
func _move_figure_eight(delta: float) -> void:
	var scale_x = 120.0
	var scale_y = 60.0
	var t = move_time * move_speed * 0.01
	position.x = start_position.x + sin(t) * scale_x
	position.y = start_position.y + sin(t * 2) * scale_y

## 随机游走
func _move_random_walk(delta: float) -> void:
	var distance_to_target = position.distance_to(random_target)
	
	if distance_to_target < 10.0 or move_time > 3.0:
		# 选择新的随机目标
		var angle = randf() * TAU
		var distance = randf_range(100, 250)
		random_target = start_position + Vector2(cos(angle), sin(angle)) * distance
		move_time = 0.0
	
	var direction = (random_target - position).normalized()
	position += direction * move_speed * delta
	
	# 边界限制
	var max_distance = 300.0
	if position.distance_to(start_position) > max_distance:
		var to_center = (start_position - position).normalized()
		position += to_center * move_speed * delta * 2

## 轨道运动
func _move_orbit(delta: float) -> void:
	var angle = move_time * orbit_speed
	position.x = orbit_center.x + cos(angle) * orbit_radius
	position.y = orbit_center.y + sin(angle) * orbit_radius

## 设置轨道中心
func set_orbit_center(center: Vector2, radius: float = 150.0) -> void:
	orbit_center = center
	orbit_radius = radius

## 受到伤害（不会死亡）
func take_damage(amount: float, _damage_type: int = 0) -> void:
	total_damage_received += amount
	hit_count += 1
	last_hit_time = Time.get_unix_time_from_system()
	
	damage_taken.emit(amount)
	
	# 闪烁效果
	_flash_hit()
	
	# 更新伤害显示
	_update_damage_display()

## 闪烁效果
func _flash_hit() -> void:
	if sprite:
		sprite.color = HIT_COLOR
		var tween = create_tween()
		tween.tween_property(sprite, "color", NORMAL_COLOR, 0.15)

## 更新伤害显示
func _update_damage_display() -> void:
	if damage_label:
		damage_label.text = "伤害: %.0f\n命中: %d" % [total_damage_received, hit_count]

## 重置统计
func reset_stats() -> void:
	total_damage_received = 0.0
	hit_count = 0
	_update_damage_display()

## 获取统计信息
func get_stats() -> Dictionary:
	return {
		"total_damage": total_damage_received,
		"hit_count": hit_count,
		"avg_damage_per_hit": total_damage_received / hit_count if hit_count > 0 else 0.0,
		"position": global_position,
		"move_pattern": move_pattern
	}

## 应用状态效果（沙包不受状态影响，但记录）
func apply_status(_status_type: int, _duration: float, _value: float) -> void:
	# 沙包不受状态效果影响，仅记录
	pass
