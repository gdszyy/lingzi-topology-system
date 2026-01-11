# enemy.gd
# 测试用敌人实体
extends Area2D
class_name Enemy

## 信号
signal enemy_died(enemy: Enemy)
signal damage_taken(amount: float)

## 属性
@export var max_health: float = 100.0
@export var move_speed: float = 0.0
@export var move_pattern: MovePattern = MovePattern.STATIC

## 移动模式
enum MovePattern {
	STATIC,      # 静止
	HORIZONTAL,  # 水平移动
	VERTICAL,    # 垂直移动
	CIRCULAR,    # 圆周移动
	RANDOM       # 随机移动
}

## 运行时状态
var current_health: float
var status_effects: Dictionary = {}  # {status_type: {duration, value}}
var move_time: float = 0.0
var start_position: Vector2
var move_direction: Vector2 = Vector2.RIGHT

## 视觉组件
@onready var health_bar: ProgressBar = $HealthBar
@onready var sprite: Polygon2D = $Visual

## 颜色
const NORMAL_COLOR = Color(0.8, 0.2, 0.2)
const DAMAGED_COLOR = Color(1.0, 0.5, 0.5)

func _ready():
	add_to_group("enemies")
	current_health = max_health
	start_position = global_position
	_update_health_bar()
	
	# 设置随机移动方向
	if move_pattern == MovePattern.RANDOM:
		move_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()

func _physics_process(delta: float) -> void:
	# 更新移动
	_update_movement(delta)
	
	# 更新状态效果
	_update_status_effects(delta)

## 更新移动
func _update_movement(delta: float) -> void:
	if move_speed <= 0:
		return
	
	move_time += delta
	
	match move_pattern:
		MovePattern.HORIZONTAL:
			position.x = start_position.x + sin(move_time * 2.0) * 100.0
		
		MovePattern.VERTICAL:
			position.y = start_position.y + sin(move_time * 2.0) * 100.0
		
		MovePattern.CIRCULAR:
			position.x = start_position.x + cos(move_time * 1.5) * 80.0
			position.y = start_position.y + sin(move_time * 1.5) * 80.0
		
		MovePattern.RANDOM:
			position += move_direction * move_speed * delta
			# 边界反弹
			var viewport = get_viewport_rect()
			if position.x < 50 or position.x > viewport.size.x - 50:
				move_direction.x *= -1
			if position.y < 50 or position.y > viewport.size.y - 50:
				move_direction.y *= -1
			# 随机改变方向
			if randf() < 0.01:
				move_direction = move_direction.rotated(randf_range(-0.5, 0.5))

## 受到伤害
func take_damage(amount: float, damage_type: int = 0) -> void:
	# 应用状态效果修正
	var final_damage = amount
	
	# 燃烧增伤
	if status_effects.has(ApplyStatusActionData.StatusType.BURNING):
		final_damage *= 1.2
	
	# 冰冻减伤
	if status_effects.has(ApplyStatusActionData.StatusType.FROZEN):
		final_damage *= 0.8
	
	current_health -= final_damage
	damage_taken.emit(final_damage)
	
	# 闪烁效果
	_flash_damage()
	
	# 更新血条
	_update_health_bar()
	
	# 死亡检查
	if current_health <= 0:
		_die()

## 应用状态效果
func apply_status(status_type: int, duration: float, value: float) -> void:
	status_effects[status_type] = {
		"duration": duration,
		"value": value
	}
	_update_status_visual()

## 更新状态效果
func _update_status_effects(delta: float) -> void:
	var to_remove = []
	
	for status_type in status_effects:
		var effect = status_effects[status_type]
		effect.duration -= delta
		
		# 持续伤害效果
		if status_type == ApplyStatusActionData.StatusType.BURNING:
			take_damage(effect.value * delta, 0)
		elif status_type == ApplyStatusActionData.StatusType.POISONED:
			take_damage(effect.value * delta * 0.5, 0)
		
		# 减速效果
		if status_type == ApplyStatusActionData.StatusType.SLOWED:
			# 已在移动中处理
			pass
		
		if effect.duration <= 0:
			to_remove.append(status_type)
	
	for status_type in to_remove:
		status_effects.erase(status_type)
	
	if to_remove.size() > 0:
		_update_status_visual()

## 更新状态视觉
func _update_status_visual() -> void:
	var color = NORMAL_COLOR
	
	if status_effects.has(ApplyStatusActionData.StatusType.BURNING):
		color = Color(1.0, 0.5, 0.0)  # 橙色
	elif status_effects.has(ApplyStatusActionData.StatusType.FROZEN):
		color = Color(0.5, 0.8, 1.0)  # 冰蓝色
	elif status_effects.has(ApplyStatusActionData.StatusType.POISONED):
		color = Color(0.5, 0.8, 0.2)  # 绿色
	elif status_effects.has(ApplyStatusActionData.StatusType.SLOWED):
		color = Color(0.6, 0.6, 0.8)  # 灰蓝色
	
	if sprite:
		sprite.color = color

## 闪烁伤害效果
func _flash_damage() -> void:
	if sprite:
		sprite.color = DAMAGED_COLOR
		var tween = create_tween()
		tween.tween_property(sprite, "color", NORMAL_COLOR, 0.2)

## 更新血条
func _update_health_bar() -> void:
	if health_bar:
		health_bar.value = (current_health / max_health) * 100.0

## 死亡
func _die() -> void:
	enemy_died.emit(self)
	queue_free()

## 重置
func reset() -> void:
	current_health = max_health
	status_effects.clear()
	position = start_position
	move_time = 0.0
	_update_health_bar()
	_update_status_visual()

## 获取当前生命值百分比
func get_health_percent() -> float:
	return current_health / max_health
