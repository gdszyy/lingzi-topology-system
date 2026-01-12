class_name ImpactVFX
extends Node2D
## 命中特效
## 根据灵子相态显示不同的命中效果

signal effect_finished

@export var phase: CarrierConfigData.Phase = CarrierConfigData.Phase.SOLID
@export var impact_scale: float = 1.0

var _colors: Dictionary = {}
var _duration: float = 0.5

func _ready() -> void:
	_setup_impact()
	_play_impact_animation()

func initialize(p_phase: CarrierConfigData.Phase, p_scale: float = 1.0) -> void:
	phase = p_phase
	impact_scale = p_scale
	_setup_impact()
	_play_impact_animation()

func _setup_impact() -> void:
	_colors = VFXManager.PHASE_COLORS.get(phase, VFXManager.PHASE_COLORS[CarrierConfigData.Phase.SOLID])
	
	match phase:
		CarrierConfigData.Phase.SOLID:
			_setup_solid_impact()
		CarrierConfigData.Phase.LIQUID:
			_setup_liquid_impact()
		CarrierConfigData.Phase.PLASMA:
			_setup_plasma_impact()

## ========== 固态命中效果 ==========
func _setup_solid_impact() -> void:
	_duration = 0.6
	
	# 冲击波环
	var shockwave = _create_shockwave_ring()
	add_child(shockwave)
	
	# 碎片粒子
	var debris = _create_debris_particles()
	add_child(debris)
	
	# 撞击闪光
	var flash = _create_impact_flash()
	add_child(flash)

func _create_shockwave_ring() -> Polygon2D:
	var ring = Polygon2D.new()
	ring.name = "ShockwaveRing"
	
	var points: PackedVector2Array = []
	var segments = 32
	var radius = 5.0 * impact_scale
	
	for i in range(segments + 1):
		var angle = i * TAU / segments
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	
	ring.polygon = points
	ring.color = _colors.secondary
	ring.color.a = 0.8
	return ring

func _create_debris_particles() -> GPUParticles2D:
	var particles = GPUParticles2D.new()
	particles.name = "DebrisParticles"
	particles.amount = 25
	particles.lifetime = 0.5
	particles.one_shot = true
	particles.explosiveness = 1.0
	
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, 0, 0)
	material.spread = 180.0
	material.initial_velocity_min = 150.0 * impact_scale
	material.initial_velocity_max = 300.0 * impact_scale
	material.gravity = Vector3(0, 400, 0)
	material.scale_min = 0.3 * impact_scale
	material.scale_max = 0.8 * impact_scale
	material.color = _colors.primary
	
	particles.process_material = material
	particles.emitting = true
	return particles

func _create_impact_flash() -> Polygon2D:
	var flash = Polygon2D.new()
	flash.name = "ImpactFlash"
	
	var points: PackedVector2Array = []
	var segments = 16
	var radius = 20.0 * impact_scale
	
	for i in range(segments):
		var angle = i * TAU / segments
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	
	flash.polygon = points
	flash.color = _colors.secondary
	return flash

## ========== 液态命中效果 ==========
func _setup_liquid_impact() -> void:
	_duration = 0.7
	
	# 液体飞溅
	var splash = _create_splash_particles()
	add_child(splash)
	
	# 水波纹
	var ripples = _create_ripple_effect()
	add_child(ripples)
	
	# 冰晶效果（如果是冷冻相关）
	var frost = _create_frost_overlay()
	add_child(frost)

func _create_splash_particles() -> GPUParticles2D:
	var particles = GPUParticles2D.new()
	particles.name = "SplashParticles"
	particles.amount = 35
	particles.lifetime = 0.6
	particles.one_shot = true
	particles.explosiveness = 1.0
	
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, -1, 0)
	material.spread = 120.0
	material.initial_velocity_min = 100.0 * impact_scale
	material.initial_velocity_max = 200.0 * impact_scale
	material.gravity = Vector3(0, 300, 0)
	material.scale_min = 0.4 * impact_scale
	material.scale_max = 1.0 * impact_scale
	material.color = _colors.primary
	
	particles.process_material = material
	particles.emitting = true
	return particles

func _create_ripple_effect() -> Node2D:
	var container = Node2D.new()
	container.name = "RippleContainer"
	
	for i in range(3):
		var ripple = Polygon2D.new()
		var points: PackedVector2Array = []
		var segments = 24
		var radius = 10.0 * impact_scale
		
		for j in range(segments + 1):
			var angle = j * TAU / segments
			points.append(Vector2(cos(angle), sin(angle)) * radius)
		
		ripple.polygon = points
		ripple.color = _colors.secondary
		ripple.color.a = 0.6 - i * 0.15
		ripple.name = "Ripple" + str(i)
		container.add_child(ripple)
	
	return container

func _create_frost_overlay() -> Polygon2D:
	var frost = Polygon2D.new()
	frost.name = "FrostOverlay"
	
	# 不规则冰晶形状
	var points: PackedVector2Array = []
	var base_size = 15.0 * impact_scale
	
	for i in range(8):
		var angle = i * PI / 4.0 + randf_range(-0.2, 0.2)
		var radius = base_size * (0.6 + randf() * 0.4)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	
	frost.polygon = points
	frost.color = _colors.secondary
	frost.color.a = 0.4
	return frost

## ========== 等离子态命中效果 ==========
func _setup_plasma_impact() -> void:
	_duration = 0.8
	
	# 能量爆发
	var burst = _create_energy_burst()
	add_child(burst)
	
	# 火花粒子
	var sparks = _create_spark_burst()
	add_child(sparks)
	
	# 热浪扭曲效果（用视觉模拟）
	var heatwave = _create_heatwave_visual()
	add_child(heatwave)
	
	# 焦痕
	var scorch = _create_scorch_mark()
	add_child(scorch)

func _create_energy_burst() -> Polygon2D:
	var burst = Polygon2D.new()
	burst.name = "EnergyBurst"
	
	var points: PackedVector2Array = []
	var segments = 16
	var radius = 25.0 * impact_scale
	
	for i in range(segments):
		var angle = i * TAU / segments
		var r = radius * (0.7 + 0.3 * randf())
		points.append(Vector2(cos(angle), sin(angle)) * r)
	
	burst.polygon = points
	burst.color = _colors.secondary
	return burst

func _create_spark_burst() -> GPUParticles2D:
	var particles = GPUParticles2D.new()
	particles.name = "SparkBurst"
	particles.amount = 50
	particles.lifetime = 0.4
	particles.one_shot = true
	particles.explosiveness = 1.0
	
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, 0, 0)
	material.spread = 180.0
	material.initial_velocity_min = 200.0 * impact_scale
	material.initial_velocity_max = 400.0 * impact_scale
	material.gravity = Vector3(0, 200, 0)
	material.scale_min = 0.1 * impact_scale
	material.scale_max = 0.4 * impact_scale
	material.color = _colors.secondary
	
	particles.process_material = material
	particles.emitting = true
	return particles

func _create_heatwave_visual() -> Node2D:
	var container = Node2D.new()
	container.name = "HeatwaveContainer"
	
	# 用多个半透明环模拟热浪
	for i in range(4):
		var wave = Polygon2D.new()
		var points: PackedVector2Array = []
		var segments = 20
		var radius = (15.0 + i * 8.0) * impact_scale
		
		for j in range(segments + 1):
			var angle = j * TAU / segments
			points.append(Vector2(cos(angle), sin(angle)) * radius)
		
		wave.polygon = points
		wave.color = _colors.glow
		wave.color.a = 0.2 - i * 0.04
		wave.name = "HeatWave" + str(i)
		container.add_child(wave)
	
	return container

func _create_scorch_mark() -> Polygon2D:
	var scorch = Polygon2D.new()
	scorch.name = "ScorchMark"
	
	var points: PackedVector2Array = []
	var base_size = 12.0 * impact_scale
	
	for i in range(10):
		var angle = i * TAU / 10.0 + randf_range(-0.3, 0.3)
		var radius = base_size * (0.5 + randf() * 0.5)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	
	scorch.polygon = points
	scorch.color = Color(0.1, 0.1, 0.1, 0.6)
	return scorch

## ========== 动画播放 ==========
func _play_impact_animation() -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	
	match phase:
		CarrierConfigData.Phase.SOLID:
			_animate_solid_impact(tween)
		CarrierConfigData.Phase.LIQUID:
			_animate_liquid_impact(tween)
		CarrierConfigData.Phase.PLASMA:
			_animate_plasma_impact(tween)
	
	tween.set_parallel(false)
	tween.tween_callback(_finish_effect).set_delay(_duration)

func _animate_solid_impact(tween: Tween) -> void:
	var ring = get_node_or_null("ShockwaveRing")
	var flash = get_node_or_null("ImpactFlash")
	
	if ring:
		ring.scale = Vector2.ZERO
		tween.tween_property(ring, "scale", Vector2.ONE * 3.0, 0.3).set_ease(Tween.EASE_OUT)
		tween.tween_property(ring, "modulate:a", 0.0, 0.3)
	
	if flash:
		flash.scale = Vector2.ONE * 1.5
		flash.modulate.a = 1.0
		tween.tween_property(flash, "scale", Vector2.ZERO, 0.15).set_ease(Tween.EASE_IN)
		tween.tween_property(flash, "modulate:a", 0.0, 0.15)

func _animate_liquid_impact(tween: Tween) -> void:
	var ripple_container = get_node_or_null("RippleContainer")
	var frost = get_node_or_null("FrostOverlay")
	
	if ripple_container:
		for i in range(ripple_container.get_child_count()):
			var ripple = ripple_container.get_child(i)
			ripple.scale = Vector2.ZERO
			tween.tween_property(ripple, "scale", Vector2.ONE * (2.0 + i * 0.5), 0.4 + i * 0.1).set_delay(i * 0.1).set_ease(Tween.EASE_OUT)
			tween.tween_property(ripple, "modulate:a", 0.0, 0.3).set_delay(0.3 + i * 0.1)
	
	if frost:
		frost.scale = Vector2.ZERO
		frost.modulate.a = 0.0
		tween.tween_property(frost, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_OUT)
		tween.tween_property(frost, "modulate:a", 0.4, 0.2)
		tween.tween_property(frost, "modulate:a", 0.0, 0.4).set_delay(0.3)

func _animate_plasma_impact(tween: Tween) -> void:
	var burst = get_node_or_null("EnergyBurst")
	var heatwave = get_node_or_null("HeatwaveContainer")
	var scorch = get_node_or_null("ScorchMark")
	
	if burst:
		burst.scale = Vector2.ZERO
		burst.modulate.a = 1.0
		tween.tween_property(burst, "scale", Vector2.ONE * 2.0, 0.15).set_ease(Tween.EASE_OUT)
		tween.tween_property(burst, "modulate:a", 0.0, 0.2).set_delay(0.1)
	
	if heatwave:
		for i in range(heatwave.get_child_count()):
			var wave = heatwave.get_child(i)
			wave.scale = Vector2.ONE * 0.5
			tween.tween_property(wave, "scale", Vector2.ONE * (1.5 + i * 0.3), 0.5).set_delay(i * 0.05).set_ease(Tween.EASE_OUT)
			tween.tween_property(wave, "modulate:a", 0.0, 0.4).set_delay(0.2 + i * 0.05)
	
	if scorch:
		scorch.scale = Vector2.ZERO
		scorch.modulate.a = 0.0
		tween.tween_property(scorch, "scale", Vector2.ONE, 0.1).set_ease(Tween.EASE_OUT)
		tween.tween_property(scorch, "modulate:a", 0.6, 0.1)
		tween.tween_property(scorch, "modulate:a", 0.0, 0.5).set_delay(0.3)

func _finish_effect() -> void:
	effect_finished.emit()
	queue_free()
