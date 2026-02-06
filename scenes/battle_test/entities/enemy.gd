extends Area2D
class_name Enemy

## 敌人单位
## 集成了新的能量系统和二维体素战斗系统
## 支持肢体目标伤害和法术失效机制

signal enemy_died(enemy: Enemy)
signal damage_taken(amount: float)
signal energy_cap_changed(current_cap: float, max_cap: float)
signal body_part_damaged(part: BodyPartData, damage: float)
signal body_part_destroyed(part: BodyPartData)

## 能量系统配置
@export var energy_system: EnergySystemData

## 是否启用二维体素战斗系统
@export var use_voxel_system: bool = true

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

## 二维体素战斗系统：敌人肢体
var body_parts: Array[BodyPartData] = []

## 移动速度惩罚（受肢体损伤影响）
var movement_penalty: float = 1.0

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
	
	# 初始化二维体素系统
	if use_voxel_system:
		_initialize_body_parts()
	
	start_position = global_position
	_update_health_bar()

	if move_pattern == MovePattern.RANDOM:
		move_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()

	zigzag_offset = randf() * TAU

## 初始化敌人肢体（简化版，只有核心部位）
func _initialize_body_parts() -> void:
	body_parts.clear()
	
	# 敌人使用简化的肢体系统
	var torso = BodyPartData.new()
	torso.initialize(BodyPartData.PartType.TORSO, 0, 0.0)
	torso.max_health = energy_system.max_energy_cap * 0.4
	torso.current_health = torso.max_health
	torso.core_damage_ratio = 0.5
	torso.is_vital = true
	torso.destroyed.connect(_on_body_part_destroyed)
	torso.damage_taken.connect(_on_body_part_damage_taken.bind(torso))
	body_parts.append(torso)
	
	var head = BodyPartData.new()
	head.initialize(BodyPartData.PartType.HEAD, 0, 0.0)
	head.max_health = energy_system.max_energy_cap * 0.2
	head.current_health = head.max_health
	head.core_damage_ratio = 0.8  # 头部伤害传递更多
	head.is_vital = true
	head.destroyed.connect(_on_body_part_destroyed)
	head.damage_taken.connect(_on_body_part_damage_taken.bind(head))
	body_parts.append(head)
	
	var left_arm = BodyPartData.new()
	left_arm.initialize(BodyPartData.PartType.LEFT_ARM, 0, 0.0)
	left_arm.max_health = energy_system.max_energy_cap * 0.15
	left_arm.current_health = left_arm.max_health
	left_arm.core_damage_ratio = 0.2
	left_arm.destroyed.connect(_on_body_part_destroyed)
	left_arm.damage_taken.connect(_on_body_part_damage_taken.bind(left_arm))
	body_parts.append(left_arm)
	
	var right_arm = BodyPartData.new()
	right_arm.initialize(BodyPartData.PartType.RIGHT_ARM, 0, 0.0)
	right_arm.max_health = energy_system.max_energy_cap * 0.15
	right_arm.current_health = right_arm.max_health
	right_arm.core_damage_ratio = 0.2
	right_arm.destroyed.connect(_on_body_part_destroyed)
	right_arm.damage_taken.connect(_on_body_part_damage_taken.bind(right_arm))
	body_parts.append(right_arm)
	
	var legs = BodyPartData.new()
	legs.initialize(BodyPartData.PartType.LEGS, 0, 0.0)
	legs.max_health = energy_system.max_energy_cap * 0.1
	legs.current_health = legs.max_health
	legs.core_damage_ratio = 0.3
	legs.destroyed.connect(_on_body_part_destroyed)
	legs.damage_taken.connect(_on_body_part_damage_taken.bind(legs))
	body_parts.append(legs)

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
		
		# 重新初始化肢体系统
		if use_voxel_system:
			_initialize_body_parts()

func _update_movement(delta: float) -> void:
	if move_speed <= 0:
		return

	move_time += delta

	var actual_speed = move_speed * movement_penalty
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

## 承受伤害（二维体素战斗系统）
## 支持指定目标肢体
func take_damage(amount: float, _damage_type: int = 0, target_part_type: int = -1) -> void:
	var final_damage = amount

	# 状态效果修正
	if status_effects.has(ApplyStatusActionData.StatusType.ENTROPY_BURN):
		final_damage *= 1.2

	if status_effects.has(ApplyStatusActionData.StatusType.CRYO_CRYSTAL):
		final_damage *= 0.8

	# 二维体素战斗系统处理
	if use_voxel_system and body_parts.size() > 0:
		var core_damage = _damage_body_part(target_part_type, final_damage)
		
		# 核心伤害传递到能量系统
		if energy_system and core_damage > 0:
			energy_system.take_damage(core_damage)
	else:
		# 传统伤害处理
		if energy_system:
			energy_system.take_damage(final_damage)
	
	damage_taken.emit(final_damage)
	_flash_damage()

## 对特定肢体造成伤害
## 返回传递到核心的伤害值
func _damage_body_part(part_type: int, damage: float) -> float:
	var target_part: BodyPartData = null
	
	# 如果指定了肢体类型，尝试找到对应肢体
	if part_type >= 0:
		for part in body_parts:
			if part.part_type == part_type and part.is_functional:
				target_part = part
				break
	
	# 如果没有找到指定肢体或未指定，随机选择一个功能正常的肢体
	if target_part == null:
		var functional_parts: Array[BodyPartData] = []
		for part in body_parts:
			if part.is_functional:
				functional_parts.append(part)
		
		if functional_parts.is_empty():
			# 所有肢体都被摧毁，伤害直接作用于核心
			return damage
		
		target_part = functional_parts[randi() % functional_parts.size()]
	
	# 对肢体造成伤害
	var actual_damage = target_part.take_damage(damage)
	var core_damage = actual_damage * target_part.core_damage_ratio
	
	return core_damage

## 获取特定类型的肢体
func get_body_part(part_type: int) -> BodyPartData:
	for part in body_parts:
		if part.part_type == part_type:
			return part
	return null

## 获取所有功能正常的肢体
func get_functional_body_parts() -> Array[BodyPartData]:
	var functional: Array[BodyPartData] = []
	for part in body_parts:
		if part.is_functional:
			functional.append(part)
	return functional

## 肢体受伤回调
func _on_body_part_damage_taken(damage: float, _remaining_health: float, part: BodyPartData) -> void:
	body_part_damaged.emit(part, damage)

## 肢体被摧毁回调
func _on_body_part_destroyed(part: BodyPartData) -> void:
	body_part_destroyed.emit(part)
	
	# 检查是否为关键部位
	if part.is_vital:
		_die()
		return
	
	# 更新移动惩罚
	_update_movement_penalty()
	
	print("[敌人肢体摧毁] %s 的 %s 被摧毁" % [name, part.part_name])

## 更新移动惩罚
func _update_movement_penalty() -> void:
	var legs = get_body_part(BodyPartData.PartType.LEGS)
	if legs == null or not legs.is_functional:
		movement_penalty = 0.3
	else:
		movement_penalty = legs.efficiency

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
func _spawn_status_vfx(status_type: ApplyStatusActionData.StatusType, duration: float, value: float) -> void:
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

func is_dead() -> bool:
	if energy_system:
		return energy_system.is_depleted()
	return false

func reset() -> void:
	if energy_system:
		energy_system.reset()
	
	status_effects.clear()
	
	# 清理所有状态效果VFX
	for status_type in status_vfx_instances.keys():
		_remove_status_vfx(status_type)
	status_vfx_instances.clear()
	
	# 重置肢体系统
	if use_voxel_system:
		_initialize_body_parts()
	
	movement_penalty = 1.0
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

## 获取肢体状态摘要
func get_body_parts_summary() -> String:
	if not use_voxel_system or body_parts.is_empty():
		return "无肢体系统"
	
	var summary_lines = []
	for part in body_parts:
		summary_lines.append(part.get_status_summary())
	return "\n".join(summary_lines)
