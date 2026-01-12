class_name ShieldVFX
extends Node2D
## 护盾特效
## 展示能量屏障的视觉效果

signal effect_finished
signal shield_hit(damage: float)
signal shield_broken

@export var shield_type: ShieldActionData.ShieldType = ShieldActionData.ShieldType.PERSONAL
@export var shield_amount: float = 50.0
@export var shield_duration: float = 5.0
@export var shield_radius: float = 80.0

var _current_shield: float = 0.0
var _max_shield: float = 0.0
var _time_remaining: float = 0.0
var _is_active: bool = false
var _target: Node2D = null

# 视觉组件
var shield_shell: Node2D
var energy_flow: Node2D
var hit_effect: Node2D
var ambient_particles: GPUParticles2D

# 颜色配置（护盾使用固态相态颜色）
var _colors: Dictionary = {
	"primary": Color(0.3, 0.7, 1.0, 0.6),
	"secondary": Color(0.6, 0.9, 1.0, 0.8),
	"glow": Color(0.4, 0.8, 1.0, 0.4),
}

func _ready() -> void:
	pass

func initialize(p_type: ShieldActionData.ShieldType, p_amount: float = 50.0, p_duration: float = 5.0, p_radius: float = 80.0, target: Node2D = null) -> void:
	shield_type = p_type
	shield_amount = p_amount
	_max_shield = p_amount
	_current_shield = p_amount
	shield_duration = p_duration
	shield_radius = p_radius
	_time_remaining = shield_duration
	_target = target
	
	_setup_visuals()
	_play_spawn_animation()
	_is_active = true

func _setup_visuals() -> void:
	match shield_type:
		ShieldActionData.ShieldType.PERSONAL:
			_setup_personal_shield()
		ShieldActionData.ShieldType.AREA:
			_setup_area_shield()
		ShieldActionData.ShieldType.PROJECTILE:
			_setup_projectile_shield()

## ========== 个人护盾 ==========
func _setup_personal_shield() -> void:
	# 护盾外壳
	shield_shell = _create_hexagonal_shell(30.0)
	add_child(shield_shell)
	
	# 能量流动
	energy_flow = _create_energy_flow_lines()
	add_child(energy_flow)
	
	# 环境粒子
	ambient_particles = _create_shield_particles(35.0)
	add_child(ambient_particles)

func _create_hexagonal_shell(radius: float) -> Node2D:
	var container = Node2D.new()
	
	# 六边形网格护盾
	var hex_count = 12
	for i in range(hex_count):
		var hex = Polygon2D.new()
		var points: PackedVector2Array = []
		var hex_size = radius * 0.4
		
		for j in range(6):
			var angle = j * PI / 3.0
			points.append(Vector2(cos(angle), sin(angle)) * hex_size)
		
		hex.polygon = points
		hex.color = _colors.primary
		
		# 环形排列
		var pos_angle = i * TAU / hex_count
		hex.position = Vector2(cos(pos_angle), sin(pos_angle)) * radius * 0.7
		hex.name = "HexCell" + str(i)
		container.add_child(hex)
	
	# 中心六边形
	var center_hex = Polygon2D.new()
	var center_points: PackedVector2Array = []
	for j in range(6):
		var angle = j * PI / 3.0
		center_points.append(Vector2(cos(angle), sin(angle)) * radius * 0.35)
	center_hex.polygon = center_points
	center_hex.color = _colors.secondary
	center_hex.color.a = 0.4
	center_hex.name = "CenterHex"
	container.add_child(center_hex)
	
	return container

func _create_energy_flow_lines() -> Node2D:
	var container = Node2D.new()
	
	# 能量流动线条
	for i in range(6):
		var line = Line2D.new()
		line.width = 2.0
		line.default_color = _colors.secondary
		
		var angle = i * PI / 3.0
		var start = Vector2(cos(angle), sin(angle)) * 10.0
		var end = Vector2(cos(angle), sin(angle)) * 28.0
		
		line.points = PackedVector2Array([start, end])
		line.name = "FlowLine" + str(i)
		container.add_child(line)
	
	return container

func _create_shield_particles(radius: float) -> GPUParticles2D:
	var particles = GPUParticles2D.new()
	particles.amount = 20
	particles.lifetime = 1.0
	particles.explosiveness = 0.0
	
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, 0, 0)
	material.spread = 180.0
	material.initial_velocity_min = 5.0
	material.initial_velocity_max = 15.0
	material.gravity = Vector3(0, 0, 0)
	material.scale_min = 0.2
	material.scale_max = 0.4
	material.color = _colors.glow
	
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE_SURFACE
	material.emission_sphere_radius = radius
	
	particles.process_material = material
	particles.emitting = true
	return particles

## ========== 范围护盾 ==========
func _setup_area_shield() -> void:
	# 大型穹顶护盾
	shield_shell = _create_dome_shield()
	add_child(shield_shell)
	
	# 地面法阵
	var ground_circle = _create_ground_circle()
	add_child(ground_circle)
	
	# 环境粒子
	ambient_particles = _create_shield_particles(shield_radius)
	add_child(ambient_particles)

func _create_dome_shield() -> Node2D:
	var container = Node2D.new()
	
	# 穹顶轮廓
	var dome = Polygon2D.new()
	var points: PackedVector2Array = []
	var segments = 48
	
	for i in range(segments + 1):
		var angle = i * TAU / segments
		points.append(Vector2(cos(angle), sin(angle)) * shield_radius)
	
	dome.polygon = points
	dome.color = _colors.primary
	dome.color.a = 0.3
	container.add_child(dome)
	
	# 能量网格线
	for i in range(8):
		var line = Line2D.new()
		line.width = 1.5
		line.default_color = _colors.secondary
		line.default_color.a = 0.5
		
		var angle = i * PI / 4.0
		var points_line: PackedVector2Array = []
		points_line.append(Vector2.ZERO)
		points_line.append(Vector2(cos(angle), sin(angle)) * shield_radius)
		line.points = points_line
		container.add_child(line)
	
	# 同心圆
	for i in range(3):
		var ring = Polygon2D.new()
		var ring_points: PackedVector2Array = []
		var ring_radius = shield_radius * (0.33 + i * 0.33)
		
		for j in range(segments + 1):
			var angle = j * TAU / segments
			ring_points.append(Vector2(cos(angle), sin(angle)) * ring_radius)
		
		ring.polygon = ring_points
		ring.color = _colors.secondary
		ring.color.a = 0.2
		container.add_child(ring)
	
	return container

func _create_ground_circle() -> Polygon2D:
	var circle = Polygon2D.new()
	var points: PackedVector2Array = []
	var segments = 32
	
	for i in range(segments + 1):
		var angle = i * TAU / segments
		points.append(Vector2(cos(angle), sin(angle)) * shield_radius)
	
	circle.polygon = points
	circle.color = _colors.glow
	circle.color.a = 0.2
	return circle

## ========== 弹幕护盾 ==========
func _setup_projectile_shield() -> void:
	# 旋转护盾片
	shield_shell = _create_rotating_shields()
	add_child(shield_shell)
	
	# 轨道线
	energy_flow = _create_orbit_lines()
	add_child(energy_flow)

func _create_rotating_shields() -> Node2D:
	var container = Node2D.new()
	
	# 3个旋转的护盾片
	for i in range(3):
		var shield_piece = Polygon2D.new()
		
		# 弧形护盾片
		var points: PackedVector2Array = []
		var inner_radius = 25.0
		var outer_radius = 35.0
		var arc_angle = PI / 3.0
		var segments = 12
		
		# 外弧
		for j in range(segments + 1):
			var angle = -arc_angle / 2.0 + j * arc_angle / segments
			points.append(Vector2(cos(angle), sin(angle)) * outer_radius)
		
		# 内弧（反向）
		for j in range(segments, -1, -1):
			var angle = -arc_angle / 2.0 + j * arc_angle / segments
			points.append(Vector2(cos(angle), sin(angle)) * inner_radius)
		
		shield_piece.polygon = points
		shield_piece.color = _colors.primary
		shield_piece.rotation = i * TAU / 3.0
		shield_piece.name = "ShieldPiece" + str(i)
		container.add_child(shield_piece)
	
	return container

func _create_orbit_lines() -> Node2D:
	var container = Node2D.new()
	
	# 轨道环
	var orbit = Polygon2D.new()
	var points: PackedVector2Array = []
	var segments = 48
	var radius = 30.0
	
	for i in range(segments + 1):
		var angle = i * TAU / segments
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	
	orbit.polygon = points
	orbit.color = _colors.glow
	orbit.color.a = 0.3
	container.add_child(orbit)
	
	return container

## ========== 动画 ==========
func _play_spawn_animation() -> void:
	var tween = create_tween()
	
	# 护盾展开
	if shield_shell:
		shield_shell.scale = Vector2.ZERO
		shield_shell.modulate.a = 0.0
		tween.tween_property(shield_shell, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(shield_shell, "modulate:a", 1.0, 0.3)
	
	# 能量流动显示
	if energy_flow:
		energy_flow.modulate.a = 0.0
		tween.parallel().tween_property(energy_flow, "modulate:a", 1.0, 0.4).set_delay(0.1)

func _process(delta: float) -> void:
	if not _is_active:
		return
	
	_time_remaining -= delta
	
	# 跟随目标
	if _target and is_instance_valid(_target):
		global_position = _target.global_position
	
	# 动画更新
	_update_animations(delta)
	
	# 检查是否结束
	if _time_remaining <= 0 or _current_shield <= 0:
		_play_break_animation()

func _update_animations(delta: float) -> void:
	# 弹幕护盾旋转
	if shield_type == ShieldActionData.ShieldType.PROJECTILE and shield_shell:
		shield_shell.rotation += delta * 2.0
	
	# 能量流动动画
	if energy_flow:
		for child in energy_flow.get_children():
			if child is Line2D:
				child.modulate.a = 0.3 + 0.2 * sin(Time.get_ticks_msec() * 0.005)
	
	# 护盾强度视觉反馈
	var shield_ratio = _current_shield / _max_shield
	if shield_shell:
		shield_shell.modulate.a = 0.5 + shield_ratio * 0.5

## 受击效果
func take_damage(damage: float) -> float:
	var absorbed = minf(damage, _current_shield)
	_current_shield -= absorbed
	
	_play_hit_effect()
	shield_hit.emit(absorbed)
	
	if _current_shield <= 0:
		shield_broken.emit()
	
	return damage - absorbed

func _play_hit_effect() -> void:
	# 受击闪烁
	var tween = create_tween()
	tween.tween_property(shield_shell, "modulate", Color(1.5, 1.5, 1.5, 1.0), 0.05)
	tween.tween_property(shield_shell, "modulate", Color.WHITE, 0.1)
	
	# 涟漪效果
	var ripple = Polygon2D.new()
	var points: PackedVector2Array = []
	var segments = 24
	var radius = 10.0
	
	for i in range(segments + 1):
		var angle = i * TAU / segments
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	
	ripple.polygon = points
	ripple.color = _colors.secondary
	add_child(ripple)
	
	var ripple_tween = create_tween()
	ripple_tween.tween_property(ripple, "scale", Vector2.ONE * 4.0, 0.2).set_ease(Tween.EASE_OUT)
	ripple_tween.parallel().tween_property(ripple, "modulate:a", 0.0, 0.2)
	ripple_tween.tween_callback(ripple.queue_free)

func _play_break_animation() -> void:
	_is_active = false
	
	if ambient_particles:
		ambient_particles.emitting = false
	
	var tween = create_tween()
	
	# 护盾碎裂
	if shield_shell:
		# 碎片飞散效果
		for child in shield_shell.get_children():
			if child is Polygon2D:
				var direction = child.position.normalized() if child.position.length() > 0 else Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
				var target_pos = child.position + direction * 50.0
				
				tween.parallel().tween_property(child, "position", target_pos, 0.3).set_ease(Tween.EASE_OUT)
				tween.parallel().tween_property(child, "modulate:a", 0.0, 0.3)
				tween.parallel().tween_property(child, "rotation", child.rotation + randf_range(-PI, PI), 0.3)
	
	tween.tween_callback(_finish_effect)

func stop() -> void:
	_current_shield = 0

func _finish_effect() -> void:
	effect_finished.emit()
	queue_free()
