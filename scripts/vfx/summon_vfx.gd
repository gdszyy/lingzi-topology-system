class_name SummonVFX
extends Node2D
## 召唤特效
## 展示召唤物生成的视觉效果

signal effect_finished
signal summon_ready  # 召唤物构筑完成信号

@export var summon_type: SummonActionData.SummonType = SummonActionData.SummonType.TURRET
@export var summon_count: int = 1

var _colors: Dictionary = {
	"primary": Color(0.6, 0.4, 0.9, 0.8),
	"secondary": Color(0.8, 0.6, 1.0, 1.0),
	"glow": Color(0.7, 0.5, 1.0, 0.5),
}

# 视觉组件
var magic_circle: Node2D
var construct_particles: GPUParticles2D
var summon_silhouette: Node2D
var energy_beams: Node2D

func _ready() -> void:
	pass

func initialize(p_type: SummonActionData.SummonType, p_count: int = 1) -> void:
	summon_type = p_type
	summon_count = p_count
	
	_setup_visuals()
	_play_summon_sequence()

func _setup_visuals() -> void:
	# 召唤法阵
	magic_circle = _create_magic_circle()
	add_child(magic_circle)
	
	# 构筑粒子
	construct_particles = _create_construct_particles()
	add_child(construct_particles)
	
	# 能量光束
	energy_beams = _create_energy_beams()
	add_child(energy_beams)
	
	# 召唤物轮廓（根据类型）
	summon_silhouette = _create_summon_silhouette()
	add_child(summon_silhouette)

func _create_magic_circle() -> Node2D:
	var container = Node2D.new()
	
	# 外圈
	var outer_ring = _create_ring(50.0, 48)
	outer_ring.color = _colors.primary
	outer_ring.name = "OuterRing"
	container.add_child(outer_ring)
	
	# 中圈
	var middle_ring = _create_ring(35.0, 32)
	middle_ring.color = _colors.secondary
	middle_ring.color.a = 0.6
	middle_ring.name = "MiddleRing"
	container.add_child(middle_ring)
	
	# 内圈
	var inner_ring = _create_ring(20.0, 24)
	inner_ring.color = _colors.glow
	inner_ring.name = "InnerRing"
	container.add_child(inner_ring)
	
	# 符文
	for i in range(8):
		var rune = _create_rune()
		var angle = i * TAU / 8.0
		rune.position = Vector2(cos(angle), sin(angle)) * 42.0
		rune.rotation = angle + PI / 2.0
		rune.name = "Rune" + str(i)
		container.add_child(rune)
	
	# 连接线
	for i in range(6):
		var line = Line2D.new()
		line.width = 1.5
		line.default_color = _colors.secondary
		line.default_color.a = 0.5
		
		var angle1 = i * TAU / 6.0
		var angle2 = (i + 2) * TAU / 6.0
		
		line.points = PackedVector2Array([
			Vector2(cos(angle1), sin(angle1)) * 35.0,
			Vector2(cos(angle2), sin(angle2)) * 35.0
		])
		container.add_child(line)
	
	container.scale = Vector2.ZERO
	container.modulate.a = 0.0
	return container

func _create_ring(radius: float, segments: int) -> Polygon2D:
	var ring = Polygon2D.new()
	var points: PackedVector2Array = []
	
	for i in range(segments + 1):
		var angle = i * TAU / segments
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	
	ring.polygon = points
	return ring

func _create_rune() -> Polygon2D:
	var rune = Polygon2D.new()
	var size = 6.0
	
	# 简单的符文形状
	rune.polygon = PackedVector2Array([
		Vector2(0, -size),
		Vector2(size * 0.6, -size * 0.3),
		Vector2(size * 0.6, size * 0.3),
		Vector2(0, size),
		Vector2(-size * 0.6, size * 0.3),
		Vector2(-size * 0.6, -size * 0.3),
	])
	rune.color = _colors.secondary
	return rune

func _create_construct_particles() -> GPUParticles2D:
	var particles = GPUParticles2D.new()
	particles.amount = 50
	particles.lifetime = 1.0
	particles.explosiveness = 0.0
	
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, -1, 0)
	material.spread = 30.0
	material.initial_velocity_min = 30.0
	material.initial_velocity_max = 60.0
	material.gravity = Vector3(0, -50, 0)
	material.scale_min = 0.2
	material.scale_max = 0.5
	material.color = _colors.secondary
	
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 40.0
	
	particles.process_material = material
	particles.emitting = false
	return particles

func _create_energy_beams() -> Node2D:
	var container = Node2D.new()
	
	# 从法阵向上的能量光束
	for i in range(4):
		var beam = Polygon2D.new()
		var width = 3.0
		var height = 60.0
		
		beam.polygon = PackedVector2Array([
			Vector2(-width, 0),
			Vector2(width, 0),
			Vector2(width * 0.3, -height),
			Vector2(-width * 0.3, -height),
		])
		beam.color = _colors.glow
		
		var angle = i * TAU / 4.0
		beam.position = Vector2(cos(angle), sin(angle)) * 25.0
		beam.name = "Beam" + str(i)
		beam.modulate.a = 0.0
		container.add_child(beam)
	
	return container

func _create_summon_silhouette() -> Node2D:
	var container = Node2D.new()
	
	match summon_type:
		SummonActionData.SummonType.TURRET:
			container.add_child(_create_turret_silhouette())
		SummonActionData.SummonType.MINION:
			container.add_child(_create_minion_silhouette())
		SummonActionData.SummonType.ORBITER:
			container.add_child(_create_orbiter_silhouette())
		SummonActionData.SummonType.TOTEM:
			container.add_child(_create_totem_silhouette())
		_:
			container.add_child(_create_generic_silhouette())
	
	container.modulate.a = 0.0
	container.position.y = -20  # 在法阵上方
	return container

func _create_turret_silhouette() -> Polygon2D:
	var turret = Polygon2D.new()
	
	# 炮塔形状
	turret.polygon = PackedVector2Array([
		Vector2(-12, 10),
		Vector2(12, 10),
		Vector2(10, 0),
		Vector2(15, -5),
		Vector2(15, -10),
		Vector2(5, -10),
		Vector2(5, -5),
		Vector2(-5, -5),
		Vector2(-5, -10),
		Vector2(-15, -10),
		Vector2(-15, -5),
		Vector2(-10, 0),
	])
	turret.color = _colors.secondary
	turret.color.a = 0.7
	return turret

func _create_minion_silhouette() -> Polygon2D:
	var minion = Polygon2D.new()
	
	# 仆从形状（人形）
	minion.polygon = PackedVector2Array([
		Vector2(0, -20),
		Vector2(5, -15),
		Vector2(5, -10),
		Vector2(10, -5),
		Vector2(10, 0),
		Vector2(5, 0),
		Vector2(5, 10),
		Vector2(8, 15),
		Vector2(5, 15),
		Vector2(0, 10),
		Vector2(-5, 15),
		Vector2(-8, 15),
		Vector2(-5, 10),
		Vector2(-5, 0),
		Vector2(-10, 0),
		Vector2(-10, -5),
		Vector2(-5, -10),
		Vector2(-5, -15),
	])
	minion.color = _colors.secondary
	minion.color.a = 0.7
	return minion

func _create_orbiter_silhouette() -> Polygon2D:
	var orbiter = Polygon2D.new()
	
	# 环绕体形状（球形）
	var points: PackedVector2Array = []
	var segments = 16
	var radius = 10.0
	
	for i in range(segments):
		var angle = i * TAU / segments
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	
	orbiter.polygon = points
	orbiter.color = _colors.secondary
	orbiter.color.a = 0.7
	return orbiter

func _create_totem_silhouette() -> Polygon2D:
	var totem = Polygon2D.new()
	
	# 图腾形状
	totem.polygon = PackedVector2Array([
		Vector2(-8, 15),
		Vector2(8, 15),
		Vector2(6, 5),
		Vector2(10, 0),
		Vector2(6, -5),
		Vector2(8, -15),
		Vector2(4, -20),
		Vector2(0, -25),
		Vector2(-4, -20),
		Vector2(-8, -15),
		Vector2(-6, -5),
		Vector2(-10, 0),
		Vector2(-6, 5),
	])
	totem.color = _colors.secondary
	totem.color.a = 0.7
	return totem

func _create_generic_silhouette() -> Polygon2D:
	var generic = Polygon2D.new()
	
	var points: PackedVector2Array = []
	var segments = 8
	var radius = 15.0
	
	for i in range(segments):
		var angle = i * TAU / segments
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	
	generic.polygon = points
	generic.color = _colors.secondary
	generic.color.a = 0.7
	return generic

func _play_summon_sequence() -> void:
	var tween = create_tween()
	
	# 阶段1：法阵展开
	tween.tween_property(magic_circle, "scale", Vector2.ONE, 0.4).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(magic_circle, "modulate:a", 1.0, 0.4)
	
	# 法阵旋转
	tween.parallel().tween_callback(_start_circle_rotation)
	
	# 阶段2：能量汇聚
	tween.tween_callback(func(): construct_particles.emitting = true).set_delay(0.2)
	
	# 能量光束
	for i in range(energy_beams.get_child_count()):
		var beam = energy_beams.get_child(i)
		tween.parallel().tween_property(beam, "modulate:a", 0.8, 0.3).set_delay(0.1 * i)
	
	# 阶段3：召唤物显现
	tween.tween_property(summon_silhouette, "modulate:a", 1.0, 0.5).set_delay(0.3)
	tween.parallel().tween_property(summon_silhouette, "scale", Vector2.ONE, 0.5).from(Vector2.ONE * 0.5).set_ease(Tween.EASE_OUT)
	
	# 发出召唤完成信号
	tween.tween_callback(func(): summon_ready.emit())
	
	# 阶段4：特效消散
	tween.tween_property(magic_circle, "modulate:a", 0.0, 0.3).set_delay(0.2)
	tween.parallel().tween_property(energy_beams, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_property(summon_silhouette, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): construct_particles.emitting = false)
	
	# 结束
	tween.tween_callback(_finish_effect).set_delay(0.5)

func _start_circle_rotation() -> void:
	var rotation_tween = create_tween()
	rotation_tween.set_loops()
	rotation_tween.tween_property(magic_circle, "rotation", TAU, 3.0).from(0.0)

func _finish_effect() -> void:
	effect_finished.emit()
	queue_free()
