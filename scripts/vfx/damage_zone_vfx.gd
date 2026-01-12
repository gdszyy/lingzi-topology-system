class_name DamageZoneVFX
extends Node2D
## 伤害区域特效
## 展示持续性领域控制的视觉效果

signal effect_finished

@export var phase: CarrierConfigData.Phase = CarrierConfigData.Phase.PLASMA
@export var zone_radius: float = 80.0
@export var zone_duration: float = 5.0
@export var tick_interval: float = 0.5

var _colors: Dictionary = {}
var _time_remaining: float = 0.0
var _tick_timer: float = 0.0
var _is_active: bool = false

# 视觉组件
var zone_boundary: Polygon2D
var zone_fill: Polygon2D
var ambient_particles: GPUParticles2D
var tick_particles: GPUParticles2D
var energy_pulses: Node2D
var ground_effect: Polygon2D

func _ready() -> void:
	pass

func initialize(p_phase: CarrierConfigData.Phase, p_radius: float = 80.0, p_duration: float = 5.0, p_interval: float = 0.5) -> void:
	phase = p_phase
	zone_radius = p_radius
	zone_duration = p_duration
	tick_interval = p_interval
	_time_remaining = zone_duration
	_colors = VFXManager.PHASE_COLORS.get(phase, VFXManager.PHASE_COLORS[CarrierConfigData.Phase.PLASMA])
	_setup_visuals()
	_play_spawn_animation()

func _setup_visuals() -> void:
	# 地面效果（最底层）
	ground_effect = _create_ground_effect()
	add_child(ground_effect)
	
	# 区域填充
	zone_fill = _create_zone_fill()
	add_child(zone_fill)
	
	# 区域边界
	zone_boundary = _create_zone_boundary()
	add_child(zone_boundary)
	
	# 环境粒子
	ambient_particles = _create_ambient_particles()
	add_child(ambient_particles)
	
	# 伤害tick粒子
	tick_particles = _create_tick_particles()
	add_child(tick_particles)
	
	# 能量脉冲
	energy_pulses = _create_energy_pulses()
	add_child(energy_pulses)

func _create_ground_effect() -> Polygon2D:
	var ground = Polygon2D.new()
	var points: PackedVector2Array = []
	var segments = 32
	
	for i in range(segments):
		var angle = i * TAU / segments
		var r = zone_radius * (0.9 + randf() * 0.1)
		points.append(Vector2(cos(angle), sin(angle)) * r)
	
	ground.polygon = points
	
	# 根据相态设置地面效果颜色
	match phase:
		CarrierConfigData.Phase.PLASMA:
			ground.color = Color(0.3, 0.1, 0.0, 0.4)  # 焦黑
		CarrierConfigData.Phase.LIQUID:
			ground.color = Color(0.1, 0.2, 0.3, 0.5)  # 湿润深色
		CarrierConfigData.Phase.SOLID:
			ground.color = Color(0.2, 0.15, 0.1, 0.4)  # 泥土色
	
	ground.scale = Vector2.ZERO
	return ground

func _create_zone_fill() -> Polygon2D:
	var fill = Polygon2D.new()
	var points: PackedVector2Array = []
	var segments = 32
	
	for i in range(segments):
		var angle = i * TAU / segments
		points.append(Vector2(cos(angle), sin(angle)) * zone_radius)
	
	fill.polygon = points
	fill.color = _colors.primary
	fill.color.a = 0.2
	fill.scale = Vector2.ZERO
	return fill

func _create_zone_boundary() -> Polygon2D:
	var boundary = Polygon2D.new()
	var points: PackedVector2Array = []
	var segments = 48
	
	# 创建环形边界
	for i in range(segments + 1):
		var angle = i * TAU / segments
		points.append(Vector2(cos(angle), sin(angle)) * zone_radius)
	
	boundary.polygon = points
	boundary.color = _colors.secondary
	boundary.color.a = 0.8
	boundary.scale = Vector2.ZERO
	return boundary

func _create_ambient_particles() -> GPUParticles2D:
	var particles = GPUParticles2D.new()
	particles.amount = 40
	particles.lifetime = 1.5
	particles.explosiveness = 0.0
	
	var material = ParticleProcessMaterial.new()
	
	# 根据相态设置粒子行为
	match phase:
		CarrierConfigData.Phase.PLASMA:
			# 上升的火星和热浪
			material.direction = Vector3(0, -1, 0)
			material.spread = 30.0
			material.initial_velocity_min = 30.0
			material.initial_velocity_max = 80.0
			material.gravity = Vector3(0, -20, 0)
		CarrierConfigData.Phase.LIQUID:
			# 冒泡和寒气
			material.direction = Vector3(0, -1, 0)
			material.spread = 45.0
			material.initial_velocity_min = 10.0
			material.initial_velocity_max = 30.0
			material.gravity = Vector3(0, -10, 0)
		CarrierConfigData.Phase.SOLID:
			# 漂浮的碎屑
			material.direction = Vector3(0, -1, 0)
			material.spread = 60.0
			material.initial_velocity_min = 5.0
			material.initial_velocity_max = 20.0
			material.gravity = Vector3(0, 10, 0)
	
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = zone_radius * 0.8
	material.scale_min = 0.2
	material.scale_max = 0.5
	material.color = _colors.trail
	
	particles.process_material = material
	particles.emitting = false
	return particles

func _create_tick_particles() -> GPUParticles2D:
	var particles = GPUParticles2D.new()
	particles.amount = 20
	particles.lifetime = 0.3
	particles.one_shot = true
	particles.explosiveness = 1.0
	
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, -1, 0)
	material.spread = 180.0
	material.initial_velocity_min = 50.0
	material.initial_velocity_max = 100.0
	material.gravity = Vector3(0, 100, 0)
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = zone_radius * 0.5
	material.scale_min = 0.3
	material.scale_max = 0.6
	material.color = _colors.secondary
	
	particles.process_material = material
	return particles

func _create_energy_pulses() -> Node2D:
	var container = Node2D.new()
	
	# 创建多个脉冲环
	for i in range(3):
		var pulse = Polygon2D.new()
		var points: PackedVector2Array = []
		var segments = 32
		var radius = zone_radius * 0.3
		
		for j in range(segments + 1):
			var angle = j * TAU / segments
			points.append(Vector2(cos(angle), sin(angle)) * radius)
		
		pulse.polygon = points
		pulse.color = _colors.glow
		pulse.color.a = 0.0
		pulse.name = "Pulse" + str(i)
		container.add_child(pulse)
	
	return container

func _play_spawn_animation() -> void:
	var tween = create_tween()
	
	# 地面效果展开
	tween.tween_property(ground_effect, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT)
	
	# 区域填充展开
	tween.parallel().tween_property(zone_fill, "scale", Vector2.ONE, 0.4).set_ease(Tween.EASE_OUT)
	
	# 边界展开
	tween.parallel().tween_property(zone_boundary, "scale", Vector2.ONE, 0.5).set_ease(Tween.EASE_OUT).set_delay(0.1)
	
	# 开始粒子
	tween.tween_callback(func(): 
		ambient_particles.emitting = true
		_is_active = true
	)
	
	# 开始脉冲动画
	tween.tween_callback(_start_pulse_animation)

func _start_pulse_animation() -> void:
	for i in range(energy_pulses.get_child_count()):
		_animate_single_pulse(i)

func _animate_single_pulse(index: int) -> void:
	var pulse = energy_pulses.get_child(index)
	if not is_instance_valid(pulse):
		return
	
	var delay = index * 0.5
	var pulse_tween = create_tween()
	pulse_tween.set_loops()
	
	# 脉冲从中心向外扩散
	pulse_tween.tween_property(pulse, "scale", Vector2.ONE * 3.0, 1.0).from(Vector2.ONE * 0.5).set_delay(delay).set_ease(Tween.EASE_OUT)
	pulse_tween.parallel().tween_property(pulse, "color:a", 0.0, 1.0).from(0.5).set_delay(delay)

func _process(delta: float) -> void:
	if not _is_active:
		return
	
	_time_remaining -= delta
	_tick_timer += delta
	
	# 伤害tick效果
	if _tick_timer >= tick_interval:
		_tick_timer = 0.0
		_play_tick_effect()
	
	# 边界闪烁
	_animate_boundary(delta)
	
	# 检查是否结束
	if _time_remaining <= 0:
		_play_despawn_animation()

func _play_tick_effect() -> void:
	tick_particles.emitting = true
	
	# 边界闪烁
	var flash_tween = create_tween()
	flash_tween.tween_property(zone_boundary, "color:a", 1.0, 0.05)
	flash_tween.tween_property(zone_boundary, "color:a", 0.6, 0.15)

func _animate_boundary(delta: float) -> void:
	# 边界呼吸效果
	var pulse = 1.0 + 0.05 * sin(Time.get_ticks_msec() * 0.003)
	zone_boundary.scale = Vector2.ONE * pulse

func _play_despawn_animation() -> void:
	_is_active = false
	ambient_particles.emitting = false
	
	var tween = create_tween()
	
	# 收缩消失
	tween.tween_property(zone_fill, "scale", Vector2.ZERO, 0.3).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(zone_boundary, "scale", Vector2.ZERO, 0.3).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(ground_effect, "color:a", 0.0, 0.5)
	tween.parallel().tween_property(energy_pulses, "modulate:a", 0.0, 0.3)
	
	tween.tween_callback(_finish_effect)

func stop() -> void:
	_time_remaining = 0.0

func _finish_effect() -> void:
	effect_finished.emit()
	queue_free()
