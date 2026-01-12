class_name PhaseProjectileVFX
extends Node2D
## 相态弹体视觉特效
## 根据灵子相态动态生成对应的视觉效果

signal effect_finished

@export var phase: CarrierConfigData.Phase = CarrierConfigData.Phase.SOLID
@export var size_scale: float = 1.0
@export var velocity: Vector2 = Vector2.ZERO

# 视觉组件
var core_visual: Node2D           # 核心视觉
var glow_visual: Node2D           # 光晕
var trail_particles: GPUParticles2D  # 拖尾粒子
var ambient_particles: GPUParticles2D # 环境粒子

# 相态特有组件
var phase_specific_nodes: Array[Node] = []

# 动画参数
var _time: float = 0.0
var _pulse_speed: float = 3.0
var _rotation_speed: float = 2.0

# 颜色配置
var _colors: Dictionary = {}

func _ready() -> void:
	_setup_visuals()

func initialize(p_phase: CarrierConfigData.Phase, p_size: float = 1.0, p_velocity: Vector2 = Vector2.ZERO) -> void:
	phase = p_phase
	size_scale = p_size
	velocity = p_velocity
	_setup_visuals()

func _setup_visuals() -> void:
	# 清理旧的视觉组件
	_clear_visuals()
	
	# 获取相态颜色
	_colors = VFXManager.PHASE_COLORS.get(phase, VFXManager.PHASE_COLORS[CarrierConfigData.Phase.SOLID])
	
	# 根据相态创建不同的视觉效果
	match phase:
		CarrierConfigData.Phase.SOLID:
			_setup_solid_visuals()
		CarrierConfigData.Phase.LIQUID:
			_setup_liquid_visuals()
		CarrierConfigData.Phase.PLASMA:
			_setup_plasma_visuals()

func _clear_visuals() -> void:
	for node in phase_specific_nodes:
		if is_instance_valid(node):
			node.queue_free()
	phase_specific_nodes.clear()
	
	if core_visual:
		core_visual.queue_free()
		core_visual = null
	if glow_visual:
		glow_visual.queue_free()
		glow_visual = null
	if trail_particles:
		trail_particles.queue_free()
		trail_particles = null
	if ambient_particles:
		ambient_particles.queue_free()
		ambient_particles = null

## ========== 固态相态视觉 ==========
func _setup_solid_visuals() -> void:
	# 核心：棱角分明的几何晶体
	core_visual = _create_crystal_shape()
	add_child(core_visual)
	
	# 光晕：微弱的能量光晕
	glow_visual = _create_glow(24.0 * size_scale, _colors.glow)
	add_child(glow_visual)
	
	# 拖尾：几何碎片
	trail_particles = _create_solid_trail()
	add_child(trail_particles)
	
	# 能量脉冲线条
	var energy_lines = _create_energy_circuit_lines()
	add_child(energy_lines)
	phase_specific_nodes.append(energy_lines)

func _create_crystal_shape() -> Polygon2D:
	var crystal = Polygon2D.new()
	var base_size = 12.0 * size_scale
	
	# 六边形晶体形状
	var points: PackedVector2Array = []
	for i in range(6):
		var angle = i * PI / 3.0 - PI / 6.0
		var radius = base_size * (1.0 if i % 2 == 0 else 0.7)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	
	crystal.polygon = points
	crystal.color = _colors.primary
	return crystal

func _create_solid_trail() -> GPUParticles2D:
	var particles = GPUParticles2D.new()
	particles.amount = 20
	particles.lifetime = 0.4
	particles.explosiveness = 0.0
	particles.randomness = 0.3
	
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(-1, 0, 0)
	material.spread = 15.0
	material.initial_velocity_min = 50.0
	material.initial_velocity_max = 100.0
	material.gravity = Vector3(0, 50, 0)
	material.scale_min = 0.3 * size_scale
	material.scale_max = 0.6 * size_scale
	material.color = _colors.trail
	
	particles.process_material = material
	particles.emitting = true
	return particles

func _create_energy_circuit_lines() -> Line2D:
	var line = Line2D.new()
	line.width = 1.5 * size_scale
	line.default_color = _colors.secondary
	line.default_color.a = 0.6
	
	# 创建电路般的线条
	var points: PackedVector2Array = []
	var base_size = 8.0 * size_scale
	points.append(Vector2(-base_size, 0))
	points.append(Vector2(-base_size * 0.5, -base_size * 0.3))
	points.append(Vector2(base_size * 0.5, -base_size * 0.3))
	points.append(Vector2(base_size, 0))
	line.points = points
	
	return line

## ========== 液态相态视觉 ==========
func _setup_liquid_visuals() -> void:
	# 核心：液滴形态
	core_visual = _create_droplet_shape()
	add_child(core_visual)
	
	# 光晕：冷色光晕
	glow_visual = _create_glow(28.0 * size_scale, _colors.glow)
	add_child(glow_visual)
	
	# 拖尾：液态轨迹
	trail_particles = _create_liquid_trail()
	add_child(trail_particles)
	
	# 内部漩涡效果
	var vortex = _create_inner_vortex()
	add_child(vortex)
	phase_specific_nodes.append(vortex)
	
	# 气泡粒子
	ambient_particles = _create_bubble_particles()
	add_child(ambient_particles)

func _create_droplet_shape() -> Polygon2D:
	var droplet = Polygon2D.new()
	var base_size = 10.0 * size_scale
	
	# 液滴形状
	var points: PackedVector2Array = []
	var segments = 16
	for i in range(segments):
		var t = float(i) / segments * TAU
		var r = base_size * (1.0 + 0.3 * cos(2 * t))
		points.append(Vector2(cos(t), sin(t)) * r)
	
	droplet.polygon = points
	droplet.color = _colors.primary
	return droplet

func _create_liquid_trail() -> GPUParticles2D:
	var particles = GPUParticles2D.new()
	particles.amount = 30
	particles.lifetime = 0.6
	particles.explosiveness = 0.0
	particles.randomness = 0.4
	
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(-1, 0, 0)
	material.spread = 20.0
	material.initial_velocity_min = 30.0
	material.initial_velocity_max = 60.0
	material.gravity = Vector3(0, 30, 0)
	material.scale_min = 0.4 * size_scale
	material.scale_max = 0.8 * size_scale
	material.color = _colors.trail
	
	particles.process_material = material
	particles.emitting = true
	return particles

func _create_inner_vortex() -> Polygon2D:
	var vortex = Polygon2D.new()
	var base_size = 6.0 * size_scale
	
	# 螺旋形状
	var points: PackedVector2Array = []
	for i in range(12):
		var angle = i * PI / 6.0
		var radius = base_size * (0.3 + 0.7 * float(i) / 12.0)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	
	vortex.polygon = points
	vortex.color = _colors.secondary
	vortex.color.a = 0.5
	return vortex

func _create_bubble_particles() -> GPUParticles2D:
	var particles = GPUParticles2D.new()
	particles.amount = 8
	particles.lifetime = 0.8
	particles.explosiveness = 0.0
	particles.randomness = 0.5
	
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, -1, 0)
	material.spread = 45.0
	material.initial_velocity_min = 20.0
	material.initial_velocity_max = 40.0
	material.gravity = Vector3(0, -20, 0)
	material.scale_min = 0.2 * size_scale
	material.scale_max = 0.4 * size_scale
	material.color = _colors.secondary
	
	particles.process_material = material
	particles.emitting = true
	return particles

## ========== 等离子态相态视觉 ==========
func _setup_plasma_visuals() -> void:
	# 核心：不稳定能量球
	core_visual = _create_plasma_core()
	add_child(core_visual)
	
	# 强烈光晕
	glow_visual = _create_glow(36.0 * size_scale, _colors.glow)
	add_child(glow_visual)
	
	# 炽热拖尾
	trail_particles = _create_plasma_trail()
	add_child(trail_particles)
	
	# 电弧效果
	var arcs = _create_electric_arcs()
	add_child(arcs)
	phase_specific_nodes.append(arcs)
	
	# 火星粒子
	ambient_particles = _create_spark_particles()
	add_child(ambient_particles)

func _create_plasma_core() -> Node2D:
	var container = Node2D.new()
	
	# 外层火焰
	var outer = Polygon2D.new()
	var base_size = 14.0 * size_scale
	var points: PackedVector2Array = []
	for i in range(12):
		var angle = i * PI / 6.0
		var radius = base_size * (0.8 + randf() * 0.4)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	outer.polygon = points
	outer.color = _colors.primary
	container.add_child(outer)
	
	# 内核（过曝）
	var inner = Polygon2D.new()
	var inner_points: PackedVector2Array = []
	for i in range(8):
		var angle = i * PI / 4.0
		var radius = base_size * 0.4
		inner_points.append(Vector2(cos(angle), sin(angle)) * radius)
	inner.polygon = inner_points
	inner.color = _colors.secondary
	container.add_child(inner)
	
	return container

func _create_plasma_trail() -> GPUParticles2D:
	var particles = GPUParticles2D.new()
	particles.amount = 40
	particles.lifetime = 0.5
	particles.explosiveness = 0.0
	particles.randomness = 0.5
	
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(-1, 0, 0)
	material.spread = 30.0
	material.initial_velocity_min = 80.0
	material.initial_velocity_max = 150.0
	material.gravity = Vector3(0, -30, 0)
	material.scale_min = 0.3 * size_scale
	material.scale_max = 0.7 * size_scale
	material.color = _colors.trail
	
	particles.process_material = material
	particles.emitting = true
	return particles

func _create_electric_arcs() -> Node2D:
	var container = Node2D.new()
	
	for i in range(3):
		var arc = Line2D.new()
		arc.width = 2.0 * size_scale
		arc.default_color = _colors.secondary
		
		var points: PackedVector2Array = []
		var start_angle = randf() * TAU
		var arc_length = 15.0 * size_scale
		
		points.append(Vector2.ZERO)
		for j in range(4):
			var offset = Vector2(
				cos(start_angle) * arc_length * (j + 1) / 4.0 + randf_range(-5, 5),
				sin(start_angle) * arc_length * (j + 1) / 4.0 + randf_range(-5, 5)
			)
			points.append(offset)
		
		arc.points = points
		container.add_child(arc)
	
	return container

func _create_spark_particles() -> GPUParticles2D:
	var particles = GPUParticles2D.new()
	particles.amount = 15
	particles.lifetime = 0.3
	particles.explosiveness = 0.2
	particles.randomness = 0.6
	
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, 0, 0)
	material.spread = 180.0
	material.initial_velocity_min = 100.0
	material.initial_velocity_max = 200.0
	material.gravity = Vector3(0, 100, 0)
	material.scale_min = 0.1 * size_scale
	material.scale_max = 0.3 * size_scale
	material.color = _colors.secondary
	
	particles.process_material = material
	particles.emitting = true
	return particles

## ========== 通用方法 ==========
func _create_glow(radius: float, color: Color) -> Polygon2D:
	var glow = Polygon2D.new()
	var points: PackedVector2Array = []
	var segments = 24
	
	for i in range(segments):
		var angle = i * TAU / segments
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	
	glow.polygon = points
	glow.color = color
	glow.color.a *= 0.3
	return glow

func _process(delta: float) -> void:
	_time += delta
	_animate_visuals(delta)

func _animate_visuals(delta: float) -> void:
	# 脉动效果
	var pulse = 1.0 + 0.1 * sin(_time * _pulse_speed)
	
	if core_visual:
		core_visual.scale = Vector2.ONE * pulse
	
	if glow_visual:
		glow_visual.scale = Vector2.ONE * (pulse * 1.1)
		glow_visual.modulate.a = 0.3 + 0.1 * sin(_time * _pulse_speed * 2)
	
	# 相态特有动画
	match phase:
		CarrierConfigData.Phase.SOLID:
			_animate_solid(delta)
		CarrierConfigData.Phase.LIQUID:
			_animate_liquid(delta)
		CarrierConfigData.Phase.PLASMA:
			_animate_plasma(delta)

func _animate_solid(delta: float) -> void:
	# 缓慢旋转
	if core_visual:
		core_visual.rotation += delta * _rotation_speed * 0.3

func _animate_liquid(delta: float) -> void:
	# 内部漩涡旋转
	for node in phase_specific_nodes:
		if node is Polygon2D:
			node.rotation += delta * _rotation_speed

func _animate_plasma(delta: float) -> void:
	# 电弧闪烁和重新生成
	for node in phase_specific_nodes:
		if node.get_child_count() > 0:
			for arc in node.get_children():
				if arc is Line2D:
					arc.modulate.a = 0.5 + 0.5 * randf()
	
	# 核心抖动
	if core_visual:
		core_visual.position = Vector2(randf_range(-2, 2), randf_range(-2, 2)) * size_scale

## 更新速度向量（用于调整拖尾方向等）
func update_velocity(new_velocity: Vector2) -> void:
	velocity = new_velocity
	
	# 更新拖尾粒子方向
	if trail_particles and trail_particles.process_material:
		var material = trail_particles.process_material as ParticleProcessMaterial
		if material and velocity.length() > 0:
			var dir = -velocity.normalized()
			material.direction = Vector3(dir.x, dir.y, 0)

## 停止特效
func stop() -> void:
	if trail_particles:
		trail_particles.emitting = false
	if ambient_particles:
		ambient_particles.emitting = false
	
	# 淡出
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)
	tween.tween_callback(func(): effect_finished.emit())
