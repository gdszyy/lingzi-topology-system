class_name ExplosionVFX
extends Node2D
## 爆炸特效
## 展示范围能量释放的视觉效果
## 采用多层渐变结构，流畅的能量扩散动画

signal effect_finished

@export var phase: CarrierConfigData.Phase = CarrierConfigData.Phase.PLASMA
@export var explosion_radius: float = 100.0
@export var damage_falloff: float = 0.5

var _duration: float = 0.8
var _time: float = 0.0

# 渐变色配置
var _color_outer: Color = Color.WHITE
var _color_middle: Color = Color.WHITE
var _color_inner: Color = Color.WHITE
var _color_core: Color = Color.WHITE

# 视觉组件 - 多层结构
var energy_layers: Array[Node2D] = []     # 多层能量扩散环
var core_glow: Node2D = null              # 核心光球
var shockwave_rings: Array[Node2D] = []   # 多层冲击波
var energy_tendrils: Node2D = null        # 能量触须/射线
var ambient_sparks: GPUParticles2D = null # 环境火花
var residual_glow: Node2D = null          # 残留光晕

func _ready() -> void:
	pass

func initialize(p_phase: CarrierConfigData.Phase, p_radius: float = 100.0, p_falloff: float = 0.5) -> void:
	phase = p_phase
	explosion_radius = p_radius
	damage_falloff = p_falloff
	
	_setup_colors()
	_setup_visuals()
	_play_explosion_sequence()

## 设置渐变颜色
func _setup_colors() -> void:
	match phase:
		CarrierConfigData.Phase.SOLID:
			# 琥珀金色系爆炸 - 岩石崩裂感
			_color_outer = Color(0.95, 0.6, 0.2, 0.1)
			_color_middle = Color(0.9, 0.5, 0.15, 0.35)
			_color_inner = Color(1.0, 0.7, 0.3, 0.6)
			_color_core = Color(1.0, 0.95, 0.85, 1.0)
		
		CarrierConfigData.Phase.LIQUID:
			# 青蓝色系爆炸 - 水花迸溅感
			_color_outer = Color(0.2, 0.7, 0.95, 0.1)
			_color_middle = Color(0.15, 0.6, 0.9, 0.35)
			_color_inner = Color(0.3, 0.8, 1.0, 0.6)
			_color_core = Color(0.9, 0.97, 1.0, 1.0)
		
		CarrierConfigData.Phase.PLASMA:
			# 紫红色系爆炸 - 高能释放感
			_color_outer = Color(0.9, 0.2, 0.7, 0.1)
			_color_middle = Color(0.85, 0.15, 0.6, 0.35)
			_color_inner = Color(1.0, 0.4, 0.8, 0.6)
			_color_core = Color(1.0, 0.95, 0.98, 1.0)

func _setup_visuals() -> void:
	# 1. 核心光球（多层渐变）
	core_glow = _create_core_glow()
	add_child(core_glow)
	
	# 2. 多层能量扩散环
	for i in range(3):
		var layer = _create_energy_layer(i)
		add_child(layer)
		energy_layers.append(layer)
	
	# 3. 多层冲击波环
	for i in range(2):
		var ring = _create_shockwave_ring(i)
		add_child(ring)
		shockwave_rings.append(ring)
	
	# 4. 能量触须/射线
	energy_tendrils = _create_energy_tendrils()
	add_child(energy_tendrils)
	
	# 5. 环境火花（稀疏）
	ambient_sparks = _create_ambient_sparks()
	add_child(ambient_sparks)
	
	# 6. 残留光晕
	residual_glow = _create_residual_glow()
	add_child(residual_glow)

## 创建核心光球（多层渐变结构）
func _create_core_glow() -> Node2D:
	var container = Node2D.new()
	var base_radius = explosion_radius * 0.25
	
	# 外层光晕
	var outer = _create_smooth_circle(base_radius * 2.0, 24, _color_outer)
	container.add_child(outer)
	
	# 中层能量
	var middle = _create_smooth_circle(base_radius * 1.4, 20, _color_middle)
	container.add_child(middle)
	
	# 内层核心
	var inner = _create_smooth_circle(base_radius * 0.9, 16, _color_inner)
	container.add_child(inner)
	
	# 最内核心（过曝）
	var core = _create_smooth_circle(base_radius * 0.5, 12, _color_core)
	container.add_child(core)
	
	container.scale = Vector2.ZERO
	return container

## 创建能量扩散层
func _create_energy_layer(layer_index: int) -> Node2D:
	var container = Node2D.new()
	
	# 根据层级调整参数
	var layer_alpha = 0.5 - layer_index * 0.15
	var layer_segments = 32 - layer_index * 4
	
	# 外环
	var outer_ring = _create_ring(10.0, 8.0, layer_segments, _color_middle)
	outer_ring.color.a = layer_alpha
	container.add_child(outer_ring)
	
	# 内环光晕
	var inner_glow = _create_smooth_circle(6.0, layer_segments, _color_inner)
	inner_glow.color.a = layer_alpha * 0.6
	container.add_child(inner_glow)
	
	container.scale = Vector2.ZERO
	container.modulate.a = 0.0
	return container

## 创建冲击波环
func _create_shockwave_ring(ring_index: int) -> Node2D:
	var container = Node2D.new()
	
	var ring_width = 4.0 - ring_index * 1.0
	var ring_alpha = 0.7 - ring_index * 0.2
	
	# 主环
	var main_ring = _create_ring(12.0, 12.0 - ring_width, 48, _color_inner)
	main_ring.color.a = ring_alpha
	container.add_child(main_ring)
	
	# 外发光
	var outer_glow = _create_ring(14.0, 10.0, 48, _color_outer)
	outer_glow.color.a = ring_alpha * 0.4
	container.add_child(outer_glow)
	
	container.scale = Vector2.ZERO
	return container

## 创建能量触须/射线
func _create_energy_tendrils() -> Node2D:
	var container = Node2D.new()
	
	var tendril_count = 8 + randi() % 5  # 8-12条
	for i in range(tendril_count):
		var tendril = Line2D.new()
		tendril.width = 3.0
		tendril.width_curve = _create_tendril_width_curve()
		tendril.default_color = _color_inner
		tendril.gradient = _create_tendril_gradient()
		tendril.joint_mode = Line2D.LINE_JOINT_ROUND
		tendril.begin_cap_mode = Line2D.LINE_CAP_ROUND
		tendril.end_cap_mode = Line2D.LINE_CAP_ROUND
		tendril.antialiased = true
		
		# 生成弯曲的能量线路径
		var angle = i * TAU / tendril_count + randf_range(-0.2, 0.2)
		var length = explosion_radius * randf_range(0.6, 1.0)
		tendril.points = _generate_tendril_path(angle, length)
		tendril.name = "Tendril" + str(i)
		
		container.add_child(tendril)
	
	container.modulate.a = 0.0
	return container

func _create_tendril_width_curve() -> Curve:
	var curve = Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(0.2, 0.8))
	curve.add_point(Vector2(0.5, 0.5))
	curve.add_point(Vector2(0.8, 0.25))
	curve.add_point(Vector2(1.0, 0.1))
	return curve

func _create_tendril_gradient() -> Gradient:
	var gradient = Gradient.new()
	gradient.set_color(0, Color(_color_core.r, _color_core.g, _color_core.b, 0.9))
	gradient.add_point(0.3, Color(_color_inner.r, _color_inner.g, _color_inner.b, 0.7))
	gradient.add_point(0.6, Color(_color_middle.r, _color_middle.g, _color_middle.b, 0.4))
	gradient.set_color(1, Color(_color_outer.r, _color_outer.g, _color_outer.b, 0.0))
	return gradient

func _generate_tendril_path(base_angle: float, length: float) -> PackedVector2Array:
	var points: PackedVector2Array = []
	var segments = 6
	
	points.append(Vector2.ZERO)
	
	var current_angle = base_angle
	for i in range(1, segments + 1):
		var t = float(i) / segments
		var dist = length * t
		
		# 添加一些弯曲
		current_angle += randf_range(-0.15, 0.15)
		var pos = Vector2(cos(current_angle), sin(current_angle)) * dist
		
		# 添加横向偏移
		var perpendicular = Vector2(-sin(current_angle), cos(current_angle))
		pos += perpendicular * randf_range(-8, 8) * (1.0 - t)
		
		points.append(pos)
	
	return points

## 创建环境火花
func _create_ambient_sparks() -> GPUParticles2D:
	var particles = GPUParticles2D.new()
	particles.amount = 20
	particles.lifetime = 0.5
	particles.one_shot = true
	particles.explosiveness = 0.9
	
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, 0, 0)
	material.spread = 180.0
	material.initial_velocity_min = explosion_radius * 1.5
	material.initial_velocity_max = explosion_radius * 3.0
	material.gravity = Vector3(0, 200, 0)
	material.scale_min = 0.15
	material.scale_max = 0.35
	material.color = _color_inner
	
	particles.process_material = material
	return particles

## 创建残留光晕
func _create_residual_glow() -> Node2D:
	var container = Node2D.new()
	
	# 大范围淡光
	var glow = _create_smooth_circle(explosion_radius * 0.6, 24, _color_outer)
	glow.color.a = 0.0
	container.add_child(glow)
	
	return container

## 辅助方法：创建平滑圆形
func _create_smooth_circle(radius: float, segments: int, color: Color) -> Polygon2D:
	var circle = Polygon2D.new()
	var points: PackedVector2Array = []
	
	for i in range(segments):
		var angle = i * TAU / segments
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	
	circle.polygon = points
	circle.color = color
	return circle

## 辅助方法：创建环形
func _create_ring(outer_radius: float, inner_radius: float, segments: int, color: Color) -> Polygon2D:
	var ring = Polygon2D.new()
	var points: PackedVector2Array = []
	
	# 外圈
	for i in range(segments + 1):
		var angle = i * TAU / segments
		points.append(Vector2(cos(angle), sin(angle)) * outer_radius)
	
	# 内圈（反向）
	for i in range(segments, -1, -1):
		var angle = i * TAU / segments
		points.append(Vector2(cos(angle), sin(angle)) * inner_radius)
	
	ring.polygon = points
	ring.color = color
	return ring

## 播放爆炸动画序列
func _play_explosion_sequence() -> void:
	var tween = create_tween()
	tween.set_parallel(false)
	
	# ===== 阶段1：核心闪光爆发 (0-0.1s) =====
	tween.tween_property(core_glow, "scale", Vector2.ONE, 0.06).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	
	# ===== 阶段2：能量触须射出 (0.05-0.2s) =====
	tween.parallel().tween_property(energy_tendrils, "modulate:a", 1.0, 0.08).set_delay(0.03)
	tween.parallel().tween_callback(_animate_tendrils).set_delay(0.03)
	
	# ===== 阶段3：能量层扩散 (0.08-0.35s) =====
	for i in range(energy_layers.size()):
		var layer = energy_layers[i]
		var delay = 0.06 + i * 0.04
		var target_scale = (explosion_radius / 10.0) * (0.7 + i * 0.2)
		var duration = 0.2 + i * 0.05
		
		tween.parallel().tween_property(layer, "scale", Vector2.ONE * target_scale, duration).set_delay(delay).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.parallel().tween_property(layer, "modulate:a", 1.0, 0.08).set_delay(delay)
		tween.parallel().tween_property(layer, "modulate:a", 0.0, duration * 0.7).set_delay(delay + duration * 0.3)
	
	# ===== 阶段4：冲击波扩散 (0.1-0.4s) =====
	for i in range(shockwave_rings.size()):
		var ring = shockwave_rings[i]
		var delay = 0.08 + i * 0.06
		var target_scale = explosion_radius / 12.0
		var duration = 0.25 - i * 0.03
		
		tween.parallel().tween_property(ring, "scale", Vector2.ONE * target_scale, duration).set_delay(delay).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CIRC)
		tween.parallel().tween_property(ring, "modulate:a", 0.0, duration).set_delay(delay)
	
	# ===== 阶段5：核心消退 (0.1-0.25s) =====
	tween.parallel().tween_property(core_glow, "scale", Vector2.ONE * 1.8, 0.15).set_delay(0.08).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(core_glow, "modulate:a", 0.0, 0.12).set_delay(0.1)
	
	# ===== 阶段6：能量触须消退 (0.15-0.35s) =====
	tween.parallel().tween_property(energy_tendrils, "modulate:a", 0.0, 0.2).set_delay(0.15)
	
	# ===== 阶段7：火花发射 (0.05s) =====
	tween.parallel().tween_callback(func(): ambient_sparks.emitting = true).set_delay(0.05)
	
	# ===== 阶段8：残留光晕 (0.2-0.8s) =====
	var residual_child = residual_glow.get_child(0) if residual_glow.get_child_count() > 0 else null
	if residual_child:
		tween.parallel().tween_property(residual_child, "color:a", 0.25, 0.15).set_delay(0.15)
		tween.parallel().tween_property(residual_child, "color:a", 0.0, 0.5).set_delay(0.35)
	
	# ===== 结束 =====
	tween.tween_callback(_finish_effect).set_delay(0.3)

## 动画能量触须延伸
func _animate_tendrils() -> void:
	for child in energy_tendrils.get_children():
		if child is Line2D:
			var tendril = child as Line2D
			var original_points = tendril.points.duplicate()
			
			# 从中心向外延伸动画
			var tween = create_tween()
			
			# 初始只显示起点
			tendril.points = PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
			
			# 逐步延伸
			for i in range(1, original_points.size()):
				var target_points = original_points.slice(0, i + 1)
				var delay = i * 0.02
				tween.tween_callback(func(): tendril.points = target_points).set_delay(0.02)

func _finish_effect() -> void:
	effect_finished.emit()
	queue_free()
