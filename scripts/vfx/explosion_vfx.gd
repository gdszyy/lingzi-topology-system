class_name ExplosionVFX
extends Node2D
## 爆炸特效
## 展示范围能量释放的视觉效果

signal effect_finished

@export var phase: CarrierConfigData.Phase = CarrierConfigData.Phase.PLASMA
@export var explosion_radius: float = 100.0
@export var damage_falloff: float = 0.5

var _colors: Dictionary = {}
var _duration: float = 0.8

# 视觉组件
var core_flash: Polygon2D
var shockwave_ring: Polygon2D
var debris_particles: GPUParticles2D
var smoke_particles: GPUParticles2D
var secondary_flashes: Node2D
var ground_scorch: Polygon2D

func _ready() -> void:
	pass

func initialize(p_phase: CarrierConfigData.Phase, p_radius: float = 100.0, p_falloff: float = 0.5) -> void:
	phase = p_phase
	explosion_radius = p_radius
	damage_falloff = p_falloff
	_colors = VFXManager.PHASE_COLORS.get(phase, VFXManager.PHASE_COLORS[CarrierConfigData.Phase.PLASMA])
	_setup_visuals()
	_play_explosion_sequence()

func _setup_visuals() -> void:
	# 核心闪光
	core_flash = _create_core_flash()
	add_child(core_flash)
	
	# 冲击波环
	shockwave_ring = _create_shockwave_ring()
	add_child(shockwave_ring)
	
	# 碎片/火星粒子
	debris_particles = _create_debris_particles()
	add_child(debris_particles)
	
	# 烟雾粒子
	smoke_particles = _create_smoke_particles()
	add_child(smoke_particles)
	
	# 次级闪光
	secondary_flashes = _create_secondary_flashes()
	add_child(secondary_flashes)
	
	# 地面焦痕
	ground_scorch = _create_ground_scorch()
	add_child(ground_scorch)

func _create_core_flash() -> Polygon2D:
	var flash = Polygon2D.new()
	var points: PackedVector2Array = []
	var segments = 20
	var radius = explosion_radius * 0.3
	
	for i in range(segments):
		var angle = i * TAU / segments
		var r = radius * (0.8 + randf() * 0.4)
		points.append(Vector2(cos(angle), sin(angle)) * r)
	
	flash.polygon = points
	flash.color = _colors.secondary
	flash.scale = Vector2.ZERO
	return flash

func _create_shockwave_ring() -> Polygon2D:
	var ring = Polygon2D.new()
	var points: PackedVector2Array = []
	var segments = 48
	var radius = 10.0
	
	# 创建环形（外圈和内圈）
	for i in range(segments + 1):
		var angle = i * TAU / segments
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	
	ring.polygon = points
	ring.color = _colors.primary
	ring.color.a = 0.8
	ring.scale = Vector2.ZERO
	return ring

func _create_debris_particles() -> GPUParticles2D:
	var particles = GPUParticles2D.new()
	particles.amount = 60
	particles.lifetime = 0.6
	particles.one_shot = true
	particles.explosiveness = 1.0
	
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, -1, 0)
	material.spread = 180.0
	material.initial_velocity_min = explosion_radius * 2.0
	material.initial_velocity_max = explosion_radius * 4.0
	material.gravity = Vector3(0, 500, 0)
	material.scale_min = 0.2
	material.scale_max = 0.6
	
	# 根据相态设置粒子颜色
	match phase:
		CarrierConfigData.Phase.PLASMA:
			material.color = _colors.secondary  # 火星
		CarrierConfigData.Phase.SOLID:
			material.color = _colors.primary  # 碎石
		CarrierConfigData.Phase.LIQUID:
			material.color = _colors.primary  # 液滴
	
	particles.process_material = material
	return particles

func _create_smoke_particles() -> GPUParticles2D:
	var particles = GPUParticles2D.new()
	particles.amount = 25
	particles.lifetime = 1.2
	particles.one_shot = true
	particles.explosiveness = 0.8
	
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, -1, 0)
	material.spread = 60.0
	material.initial_velocity_min = 30.0
	material.initial_velocity_max = 80.0
	material.gravity = Vector3(0, -50, 0)
	material.scale_min = 1.0
	material.scale_max = 2.5
	
	# 烟雾颜色
	var smoke_color = Color(0.3, 0.3, 0.3, 0.6)
	match phase:
		CarrierConfigData.Phase.PLASMA:
			smoke_color = Color(0.2, 0.2, 0.2, 0.5)
		CarrierConfigData.Phase.LIQUID:
			smoke_color = Color(0.4, 0.5, 0.6, 0.4)
	material.color = smoke_color
	
	particles.process_material = material
	return particles

func _create_secondary_flashes() -> Node2D:
	var container = Node2D.new()
	
	# 创建多个次级闪光点
	for i in range(5):
		var flash = Polygon2D.new()
		var points: PackedVector2Array = []
		var segments = 8
		var radius = explosion_radius * 0.15 * randf_range(0.5, 1.0)
		
		for j in range(segments):
			var angle = j * TAU / segments
			points.append(Vector2(cos(angle), sin(angle)) * radius)
		
		flash.polygon = points
		flash.color = _colors.secondary
		flash.color.a = 0.8
		
		# 随机位置
		var dist = explosion_radius * randf_range(0.2, 0.6)
		var angle = randf() * TAU
		flash.position = Vector2(cos(angle), sin(angle)) * dist
		flash.scale = Vector2.ZERO
		flash.name = "SecondaryFlash" + str(i)
		
		container.add_child(flash)
	
	return container

func _create_ground_scorch() -> Polygon2D:
	var scorch = Polygon2D.new()
	var points: PackedVector2Array = []
	var segments = 16
	var radius = explosion_radius * 0.8
	
	for i in range(segments):
		var angle = i * TAU / segments
		var r = radius * (0.7 + randf() * 0.3)
		points.append(Vector2(cos(angle), sin(angle)) * r)
	
	scorch.polygon = points
	scorch.color = Color(0.1, 0.1, 0.1, 0.0)
	return scorch

func _play_explosion_sequence() -> void:
	var tween = create_tween()
	
	# 阶段1：核心闪光爆发
	tween.tween_property(core_flash, "scale", Vector2.ONE * 2.0, 0.08).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(core_flash, "modulate:a", 1.0, 0.05).from(0.0)
	
	# 阶段2：冲击波扩散
	var shockwave_scale = explosion_radius / 10.0
	tween.tween_property(shockwave_ring, "scale", Vector2.ONE * shockwave_scale, 0.25).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(shockwave_ring, "modulate:a", 0.0, 0.25).from(0.8)
	
	# 核心闪光消退
	tween.parallel().tween_property(core_flash, "scale", Vector2.ONE * 3.0, 0.2)
	tween.parallel().tween_property(core_flash, "modulate:a", 0.0, 0.15).set_delay(0.05)
	
	# 阶段3：次级闪光
	tween.parallel().tween_callback(_trigger_secondary_flashes).set_delay(0.05)
	
	# 阶段4：粒子发射
	tween.parallel().tween_callback(func(): debris_particles.emitting = true)
	tween.parallel().tween_callback(func(): smoke_particles.emitting = true).set_delay(0.1)
	
	# 阶段5：地面焦痕
	tween.parallel().tween_property(ground_scorch, "color:a", 0.5, 0.1).set_delay(0.1)
	tween.tween_property(ground_scorch, "color:a", 0.0, 0.6).set_delay(0.2)
	
	# 结束
	tween.tween_callback(_finish_effect).set_delay(0.5)

func _trigger_secondary_flashes() -> void:
	for i in range(secondary_flashes.get_child_count()):
		var flash = secondary_flashes.get_child(i)
		var delay = randf() * 0.1
		
		var flash_tween = create_tween()
		flash_tween.tween_property(flash, "scale", Vector2.ONE, 0.05).set_delay(delay).set_ease(Tween.EASE_OUT)
		flash_tween.tween_property(flash, "scale", Vector2.ZERO, 0.1).set_ease(Tween.EASE_IN)

func _finish_effect() -> void:
	effect_finished.emit()
	queue_free()
