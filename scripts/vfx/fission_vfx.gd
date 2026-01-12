class_name FissionVFX
extends Node2D
## 裂变特效
## 展示灵子分裂时的蓄力和爆发效果

signal effect_finished
signal fission_burst  # 爆发瞬间信号，用于同步生成子弹

@export var phase: CarrierConfigData.Phase = CarrierConfigData.Phase.SOLID
@export var spawn_count: int = 3
@export var spread_angle: float = 360.0
@export var effect_scale: float = 1.0

var _colors: Dictionary = {}
var _charge_duration: float = 0.3
var _burst_duration: float = 0.2

# 视觉组件
var charge_ring: Polygon2D
var charge_particles: GPUParticles2D
var burst_flash: Polygon2D
var direction_indicators: Node2D

func _ready() -> void:
	pass

func initialize(p_phase: CarrierConfigData.Phase, p_count: int = 3, p_spread: float = 360.0, p_scale: float = 1.0) -> void:
	phase = p_phase
	spawn_count = p_count
	spread_angle = p_spread
	effect_scale = p_scale
	_colors = VFXManager.PHASE_COLORS.get(phase, VFXManager.PHASE_COLORS[CarrierConfigData.Phase.SOLID])
	_setup_visuals()
	_play_fission_sequence()

func _setup_visuals() -> void:
	# 蓄力环
	charge_ring = _create_charge_ring()
	add_child(charge_ring)
	
	# 蓄力粒子
	charge_particles = _create_charge_particles()
	add_child(charge_particles)
	
	# 爆发闪光
	burst_flash = _create_burst_flash()
	burst_flash.visible = false
	add_child(burst_flash)
	
	# 方向指示器
	direction_indicators = _create_direction_indicators()
	direction_indicators.visible = false
	add_child(direction_indicators)

func _create_charge_ring() -> Polygon2D:
	var ring = Polygon2D.new()
	var points: PackedVector2Array = []
	var segments = 32
	var radius = 20.0 * effect_scale
	
	for i in range(segments + 1):
		var angle = i * TAU / segments
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	
	ring.polygon = points
	ring.color = _colors.secondary
	ring.color.a = 0.0
	ring.scale = Vector2.ONE * 2.0
	return ring

func _create_charge_particles() -> GPUParticles2D:
	var particles = GPUParticles2D.new()
	particles.amount = 30
	particles.lifetime = 0.4
	particles.explosiveness = 0.0
	
	var material = ParticleProcessMaterial.new()
	# 向内聚集的粒子
	material.direction = Vector3(0, 0, 0)
	material.spread = 180.0
	material.initial_velocity_min = -100.0 * effect_scale
	material.initial_velocity_max = -50.0 * effect_scale
	material.gravity = Vector3(0, 0, 0)
	material.scale_min = 0.2 * effect_scale
	material.scale_max = 0.5 * effect_scale
	material.color = _colors.primary
	
	# 设置发射形状为圆环
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 40.0 * effect_scale
	
	particles.process_material = material
	particles.emitting = true
	return particles

func _create_burst_flash() -> Polygon2D:
	var flash = Polygon2D.new()
	var points: PackedVector2Array = []
	var segments = 16
	var radius = 30.0 * effect_scale
	
	for i in range(segments):
		var angle = i * TAU / segments
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	
	flash.polygon = points
	flash.color = _colors.secondary
	return flash

func _create_direction_indicators() -> Node2D:
	var container = Node2D.new()
	
	var start_angle = -spread_angle / 2.0
	var angle_step = spread_angle / max(spawn_count - 1, 1) if spawn_count > 1 else 0.0
	
	for i in range(spawn_count):
		var indicator = _create_single_indicator()
		var angle = deg_to_rad(start_angle + angle_step * i) if spawn_count > 1 else 0.0
		indicator.rotation = angle
		container.add_child(indicator)
	
	return container

func _create_single_indicator() -> Node2D:
	var indicator = Node2D.new()
	
	# 箭头形状
	var arrow = Polygon2D.new()
	var arrow_length = 25.0 * effect_scale
	var arrow_width = 6.0 * effect_scale
	
	arrow.polygon = PackedVector2Array([
		Vector2(0, 0),
		Vector2(arrow_length * 0.7, -arrow_width * 0.5),
		Vector2(arrow_length, 0),
		Vector2(arrow_length * 0.7, arrow_width * 0.5),
	])
	arrow.color = _colors.primary
	arrow.color.a = 0.8
	
	indicator.add_child(arrow)
	return indicator

func _play_fission_sequence() -> void:
	var tween = create_tween()
	
	# 阶段1：蓄力（收缩 + 聚集）
	tween.tween_property(charge_ring, "scale", Vector2.ONE * 0.5, _charge_duration).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(charge_ring, "color:a", 0.8, _charge_duration)
	
	# 阶段2：爆发
	tween.tween_callback(_trigger_burst)
	
	# 阶段3：扩散
	tween.tween_property(burst_flash, "scale", Vector2.ONE * 3.0, _burst_duration).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(burst_flash, "modulate:a", 0.0, _burst_duration)
	
	# 方向指示器动画
	tween.parallel().tween_callback(func(): direction_indicators.visible = true)
	tween.parallel().tween_property(direction_indicators, "scale", Vector2.ONE * 1.5, _burst_duration).from(Vector2.ONE * 0.5).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(direction_indicators, "modulate:a", 0.0, _burst_duration * 1.5).from(1.0)
	
	# 结束
	tween.tween_callback(_finish_effect).set_delay(0.1)

func _trigger_burst() -> void:
	# 停止蓄力粒子
	charge_particles.emitting = false
	
	# 显示爆发闪光
	burst_flash.visible = true
	burst_flash.scale = Vector2.ONE * 0.5
	burst_flash.modulate.a = 1.0
	
	# 隐藏蓄力环
	charge_ring.visible = false
	
	# 创建爆发粒子
	var burst_particles = _create_burst_particles()
	add_child(burst_particles)
	
	# 发出爆发信号
	fission_burst.emit()

func _create_burst_particles() -> GPUParticles2D:
	var particles = GPUParticles2D.new()
	particles.amount = 40
	particles.lifetime = 0.3
	particles.one_shot = true
	particles.explosiveness = 1.0
	
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, 0, 0)
	material.spread = 180.0
	material.initial_velocity_min = 200.0 * effect_scale
	material.initial_velocity_max = 400.0 * effect_scale
	material.gravity = Vector3(0, 0, 0)
	material.scale_min = 0.2 * effect_scale
	material.scale_max = 0.5 * effect_scale
	material.color = _colors.secondary
	
	particles.process_material = material
	particles.emitting = true
	return particles

func _finish_effect() -> void:
	effect_finished.emit()
	queue_free()
