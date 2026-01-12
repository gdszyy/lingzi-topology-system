extends Area2D
class_name Enemy

## 敌人单位
## 集成了新的能量系统，替代传统的血量系统

signal enemy_died(enemy: Enemy)
signal damage_taken(amount: float)
signal energy_cap_changed(current_cap: float, max_cap: float)

## 能量系统配置
@export var energy_system: EnergySystemData

## 移动速度
@export var move_speed: float = 0.0
@export var move_pattern: MovePattern = MovePattern.STATIC

## 兼容旧代码的属性（映射到能量系统）
var max_health: float:
	get:
		return energy_system.max_energy_cap if energy_system else 100.0
	set(value):
		if energy_system:
			energy_system.max_energy_cap = value
			energy_system.current_energy_cap = value

var current_health: float:
	get:
		return energy_system.current_energy_cap if energy_system else 0.0

enum MovePattern {
	STATIC,
	HORIZONTAL,
	VERTICAL,
	CIRCULAR,
	RANDOM,
	APPROACH,
	APPROACH_ZIGZAG
}

var status_effects: Dictionary = {}
var status_vfx_instances: Dictionary = {}  # 存储状态效果VFX实例
var move_time: float = 0.0
var start_position: Vector2
var move_direction: Vector2 = Vector2.RIGHT
var target_position: Vector2 = Vector2.ZERO
var zigzag_offset: float = 0.0

@onready var health_bar: ProgressBar = $HealthBar
@onready var sprite: Polygon2D = $Visual

const NORMAL_COLOR = Color(0.8, 0.2, 0.2)
const DAMAGED_COLOR = Color(1.0, 0.5, 0.5)

func _ready():
	add_to_group("enemies")
	
	# 初始化能量系统
	if energy_system == null:
		energy_system = EnergySystemData.create_enemy_default(100.0)
	
	# 连接能量系统信号
	energy_system.energy_cap_changed.connect(_on_energy_cap_changed)
	energy_system.depleted.connect(_on_energy_depleted)
	
	start_position = global_position
	_update_health_bar()

	if move_pattern == MovePattern.RANDOM:
		move_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()

	zigzag_offset = randf() * TAU

func _physics_process(delta: float) -> void:
	_update_movement(delta)
	_update_status_effects(delta)
	
	# 能量系统更新（被动吸收）
	if energy_system:
		energy_system.absorb_from_environment(delta)

func set_target_position(pos: Vector2) -> void:
	target_position = pos

## 设置能量上限（用于初始化）
func set_max_energy_cap(value: float) -> void:
	if energy_system:
		energy_system.max_energy_cap = value
		energy_system.current_energy_cap = value
		energy_system.current_energy = value * 0.5
		_update_health_bar()

func _update_movement(delta: float) -> void:
	if move_speed <= 0:
		return

	move_time += delta

	var actual_speed = move_speed
	if status_effects.has(ApplyStatusActionData.StatusType.STRUCTURE_LOCK):
		actual_speed *= 0.5

	if status_effects.has(ApplyStatusActionData.StatusType.CRYO_CRYSTAL):
		return

	match move_pattern:
		MovePattern.HORIZONTAL:
			position.x = start_position.x + sin(move_time * 2.0) * 100.0

		MovePattern.VERTICAL:
			position.y = start_position.y + sin(move_time * 2.0) * 100.0

		MovePattern.CIRCULAR:
			position.x = start_position.x + cos(move_time * 1.5) * 80.0
			position.y = start_position.y + sin(move_time * 1.5) * 80.0

		MovePattern.RANDOM:
			position += move_direction * actual_speed * delta
			var viewport = get_viewport_rect()
			if position.x < 50 or position.x > viewport.size.x - 50:
				move_direction.x *= -1
			if position.y < 50 or position.y > viewport.size.y - 50:
				move_direction.y *= -1
			if randf() < 0.01:
				move_direction = move_direction.rotated(randf_range(-0.5, 0.5))

		MovePattern.APPROACH:
			var direction = (target_position - global_position).normalized()
			global_position += direction * actual_speed * delta

		MovePattern.APPROACH_ZIGZAG:
			var direction = (target_position - global_position).normalized()
			var perpendicular = Vector2(-direction.y, direction.x)
			var zigzag = sin(move_time * 3.0 + zigzag_offset) * 0.5
			var final_direction = (direction + perpendicular * zigzag).normalized()
			global_position += final_direction * actual_speed * delta

## 承受伤害（新能量系统）
func take_damage(amount: float, _damage_type: int = 0) -> void:
	var final_damage = amount

	# 状态效果修正
	if status_effects.has(ApplyStatusActionData.StatusType.ENTROPY_BURN):
		final_damage *= 1.2

	if status_effects.has(ApplyStatusActionData.StatusType.CRYO_CRYSTAL):
		final_damage *= 0.8

	# 通过能量系统处理伤害
	if energy_system:
		energy_system.take_damage(final_damage)
	
	damage_taken.emit(final_damage)
	_flash_damage()

func apply_status(status_type: int, duration: float, value: float) -> void:
	var is_new_status = not status_effects.has(status_type)
	
	status_effects[status_type] = {
		"duration": duration,
		"value": value
	}
	_update_status_visual()
	
	# 如果是新状态，创建VFX
	if is_new_status:
		_spawn_status_vfx(status_type, duration, value)
	else:
		# 刷新现有VFX的持续时间
		_refresh_status_vfx(status_type, duration)

## 应用击退效果
func apply_knockback(knockback: Vector2) -> void:
	# 简单的击退实现
	global_position += knockback * 0.1

## 生成状态效果VFX
func _spawn_status_vfx(status_type: int, duration: float, value: float) -> void:
	# 先移除旧的VFX（如果有）
	_remove_status_vfx(status_type)
	
	# 创建新的状态效果VFX
	var status_vfx = VFXFactory.create_status_effect_vfx(status_type, duration, value, self)
	if status_vfx:
		get_tree().current_scene.add_child(status_vfx)
		status_vfx_instances[status_type] = status_vfx

## 刷新状态效果VFX持续时间
func _refresh_status_vfx(status_type: int, duration: float) -> void:
	if status_vfx_instances.has(status_type):
		var vfx = status_vfx_instances[status_type]
		if is_instance_valid(vfx) and vfx.has_method("refresh_duration"):
			vfx.refresh_duration(duration)

## 移除状态效果VFX
func _remove_status_vfx(status_type: int) -> void:
	if status_vfx_instances.has(status_type):
		var vfx = status_vfx_instances[status_type]
		if is_instance_valid(vfx):
			if vfx.has_method("stop"):
				vfx.stop()
			else:
				vfx.queue_free()
		status_vfx_instances.erase(status_type)

func _update_status_effects(delta: float) -> void:
	var to_remove = []

	for status_type in status_effects:
		var effect = status_effects[status_type]
		effect.duration -= delta

		if status_type == ApplyStatusActionData.StatusType.ENTROPY_BURN:
			take_damage(effect.value * delta, 0)
		elif status_type == ApplyStatusActionData.StatusType.SPIRITON_EROSION:
			take_damage(effect.value * delta * 0.5, 0)

		if effect.duration <= 0:
			to_remove.append(status_type)

	for status_type in to_remove:
		status_effects.erase(status_type)
		_remove_status_vfx(status_type)

	if to_remove.size() > 0:
		_update_status_visual()

func _update_status_visual() -> void:
	var color = NORMAL_COLOR

	if status_effects.has(ApplyStatusActionData.StatusType.ENTROPY_BURN):
		color = Color(1.0, 0.5, 0.0)
	elif status_effects.has(ApplyStatusActionData.StatusType.CRYO_CRYSTAL):
		color = Color(0.5, 0.8, 1.0)
	elif status_effects.has(ApplyStatusActionData.StatusType.SPIRITON_EROSION):
		color = Color(0.5, 0.8, 0.2)
	elif status_effects.has(ApplyStatusActionData.StatusType.STRUCTURE_LOCK):
		color = Color(0.6, 0.6, 0.8)

	if sprite:
		sprite.color = color

func _flash_damage() -> void:
	if sprite:
		sprite.color = DAMAGED_COLOR
		var tween = create_tween()
		tween.tween_property(sprite, "color", NORMAL_COLOR, 0.2)

func _update_health_bar() -> void:
	if health_bar and energy_system:
		health_bar.value = energy_system.get_cap_percent() * 100.0

## 能量上限变化回调
func _on_energy_cap_changed(current_cap: float, max_cap: float) -> void:
	_update_health_bar()
	energy_cap_changed.emit(current_cap, max_cap)

## 能量耗尽回调（死亡）
func _on_energy_depleted() -> void:
	_die()

func _die() -> void:
	# 清理所有状态效果VFX
	for status_type in status_vfx_instances.keys():
		_remove_status_vfx(status_type)
	
	enemy_died.emit(self)
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	call_deferred("queue_free")

func reset() -> void:
	if energy_system:
		energy_system.reset()
	
	status_effects.clear()
	
	# 清理所有状态效果VFX
	for status_type in status_vfx_instances.keys():
		_remove_status_vfx(status_type)
	status_vfx_instances.clear()
	
	position = start_position
	move_time = 0.0
	_update_health_bar()
	_update_status_visual()

func get_health_percent() -> float:
	if energy_system:
		return energy_system.get_cap_percent()
	return 0.0

func get_distance_to_target() -> float:
	return global_position.distance_to(target_position)

## 获取能量系统
func get_energy_system() -> EnergySystemData:
	return energy_system
