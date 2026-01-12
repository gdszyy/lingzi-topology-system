class_name ChainVFX
extends Node2D
## 链式特效
## 展示在多个目标间跳跃的能量链效果

signal effect_finished
signal chain_hit(target: Node2D, damage: float)

@export var chain_type: ChainActionData.ChainType = ChainActionData.ChainType.LIGHTNING
@export var chain_count: int = 3
@export var chain_damage: float = 30.0
@export var chain_delay: float = 0.1

var _colors: Dictionary = {}
var _chain_targets: Array[Node2D] = []
var _current_chain_index: int = 0
var _is_active: bool = false

# 视觉组件
var chain_lines: Array[Line2D] = []
var impact_effects: Array[Node2D] = []

var _pending_start: bool = false

func _ready() -> void:
	# 如果在进入场景树前已调用 initialize，则在此启动链式序列
	if _pending_start:
		_pending_start = false
		_start_chain_sequence()

func initialize(p_type: ChainActionData.ChainType, targets: Array[Node2D], p_damage: float = 30.0, p_delay: float = 0.1) -> void:
	chain_type = p_type
	_chain_targets = targets
	chain_count = targets.size()
	chain_damage = p_damage
	chain_delay = p_delay
	
	_colors = VFXManager.CHAIN_TYPE_COLORS.get(chain_type, VFXManager.CHAIN_TYPE_COLORS[ChainActionData.ChainType.LIGHTNING])
	
	_is_active = true
	
	# 检查是否已在场景树中，如果不在则延迟启动
	if is_inside_tree():
		_start_chain_sequence()
	else:
		_pending_start = true

func _start_chain_sequence() -> void:
	if _chain_targets.size() < 2:
		_finish_effect()
		return
	
	_animate_next_chain()

func _animate_next_chain() -> void:
	if _current_chain_index >= _chain_targets.size() - 1:
		# 所有链完成，等待一段时间后清理
		var cleanup_timer = get_tree().create_timer(0.5)
		cleanup_timer.timeout.connect(_finish_effect)
		return
	
	var from_target = _chain_targets[_current_chain_index]
	var to_target = _chain_targets[_current_chain_index + 1]
	
	if not is_instance_valid(from_target) or not is_instance_valid(to_target):
		_current_chain_index += 1
		_animate_next_chain()
		return
	
	# 创建链效果
	var chain_line = _create_chain_line(from_target.global_position, to_target.global_position)
	add_child(chain_line)
	chain_lines.append(chain_line)
	
	# 创建命中效果
	var impact = _create_impact_effect(to_target.global_position)
	add_child(impact)
	impact_effects.append(impact)
	
	# 发出命中信号
	chain_hit.emit(to_target, chain_damage)
	
	# 播放链动画
	_animate_chain_line(chain_line)
	
	# 延迟后继续下一条链
	_current_chain_index += 1
	var delay_timer = get_tree().create_timer(chain_delay)
	delay_timer.timeout.connect(_animate_next_chain)

func _create_chain_line(from_pos: Vector2, to_pos: Vector2) -> Line2D:
	var line = Line2D.new()
	line.width = 4.0
	line.default_color = _colors.primary
	
	# 根据链类型创建不同的路径
	match chain_type:
		ChainActionData.ChainType.LIGHTNING:
			line.points = _create_lightning_path(from_pos, to_pos)
		ChainActionData.ChainType.FIRE:
			line.points = _create_fire_path(from_pos, to_pos)
		ChainActionData.ChainType.ICE:
			line.points = _create_ice_path(from_pos, to_pos)
		ChainActionData.ChainType.VOID:
			line.points = _create_void_path(from_pos, to_pos)
	
	# 添加发光效果
	var glow_line = line.duplicate() as Line2D
	glow_line.width = 8.0
	glow_line.default_color = _colors.glow
	glow_line.default_color.a = 0.4
	line.add_child(glow_line)
	glow_line.position = Vector2.ZERO
	
	line.modulate.a = 0.0
	return line

func _create_lightning_path(from_pos: Vector2, to_pos: Vector2) -> PackedVector2Array:
	var points: PackedVector2Array = []
	var direction = to_pos - from_pos
	var distance = direction.length()
	var segments = int(distance / 20.0) + 2
	
	points.append(from_pos)
	
	for i in range(1, segments):
		var t = float(i) / segments
		var base_pos = from_pos.lerp(to_pos, t)
		
		# Z字形偏移
		var perpendicular = direction.normalized().rotated(PI / 2.0)
		var offset = perpendicular * randf_range(-15.0, 15.0)
		
		points.append(base_pos + offset)
	
	points.append(to_pos)
	return points

func _create_fire_path(from_pos: Vector2, to_pos: Vector2) -> PackedVector2Array:
	var points: PackedVector2Array = []
	var direction = to_pos - from_pos
	var distance = direction.length()
	var segments = int(distance / 15.0) + 2
	
	points.append(from_pos)
	
	for i in range(1, segments):
		var t = float(i) / segments
		var base_pos = from_pos.lerp(to_pos, t)
		
		# 波浪形偏移
		var perpendicular = direction.normalized().rotated(PI / 2.0)
		var offset = perpendicular * sin(t * PI * 4) * 10.0
		
		points.append(base_pos + offset)
	
	points.append(to_pos)
	return points

func _create_ice_path(from_pos: Vector2, to_pos: Vector2) -> PackedVector2Array:
	var points: PackedVector2Array = []
	var direction = to_pos - from_pos
	var distance = direction.length()
	var segments = int(distance / 25.0) + 2
	
	points.append(from_pos)
	
	for i in range(1, segments):
		var t = float(i) / segments
		var base_pos = from_pos.lerp(to_pos, t)
		
		# 锯齿形偏移
		var perpendicular = direction.normalized().rotated(PI / 2.0)
		var offset = perpendicular * (10.0 if i % 2 == 0 else -10.0)
		
		points.append(base_pos + offset)
	
	points.append(to_pos)
	return points

func _create_void_path(from_pos: Vector2, to_pos: Vector2) -> PackedVector2Array:
	var points: PackedVector2Array = []
	var direction = to_pos - from_pos
	var distance = direction.length()
	var segments = int(distance / 10.0) + 2
	
	points.append(from_pos)
	
	for i in range(1, segments):
		var t = float(i) / segments
		var base_pos = from_pos.lerp(to_pos, t)
		
		# 螺旋形偏移
		var perpendicular = direction.normalized().rotated(PI / 2.0)
		var offset = perpendicular * sin(t * PI * 6) * (1.0 - t) * 12.0
		
		points.append(base_pos + offset)
	
	points.append(to_pos)
	return points

func _create_impact_effect(pos: Vector2) -> Node2D:
	var container = Node2D.new()
	container.global_position = pos
	
	# 命中闪光
	var flash = Polygon2D.new()
	var points: PackedVector2Array = []
	var segments = 12
	var radius = 15.0
	
	for i in range(segments):
		var angle = i * TAU / segments
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	
	flash.polygon = points
	flash.color = _colors.secondary
	flash.scale = Vector2.ZERO
	container.add_child(flash)
	
	# 命中粒子
	var particles = GPUParticles2D.new()
	particles.amount = 15
	particles.lifetime = 0.3
	particles.one_shot = true
	particles.explosiveness = 1.0
	
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, 0, 0)
	material.spread = 180.0
	material.initial_velocity_min = 50.0
	material.initial_velocity_max = 100.0
	material.gravity = Vector3(0, 100, 0)
	material.scale_min = 0.2
	material.scale_max = 0.4
	material.color = _colors.primary
	
	particles.process_material = material
	particles.emitting = true
	container.add_child(particles)
	
	# 闪光动画
	var tween = create_tween()
	tween.tween_property(flash, "scale", Vector2.ONE, 0.1).set_ease(Tween.EASE_OUT)
	tween.tween_property(flash, "scale", Vector2.ZERO, 0.15).set_ease(Tween.EASE_IN)
	
	return container

func _animate_chain_line(line: Line2D) -> void:
	var tween = create_tween()
	
	# 快速出现
	tween.tween_property(line, "modulate:a", 1.0, 0.05)
	
	# 闪烁
	tween.tween_property(line, "modulate:a", 0.5, 0.05)
	tween.tween_property(line, "modulate:a", 1.0, 0.05)
	
	# 渐隐
	tween.tween_property(line, "modulate:a", 0.0, 0.3)

func _finish_effect() -> void:
	_is_active = false
	effect_finished.emit()
	queue_free()
