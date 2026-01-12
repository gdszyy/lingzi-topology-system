class_name PhaseProjectileVFX
extends Node2D
## 相态弹体视觉特效
## 根据灵子相态、速度、嵌套层级等属性动态生成对应的视觉效果
## 嵌套效果：核心更亮更饱和、颜色渐变叠加、拖尾更丰富

signal effect_finished

@export var phase: CarrierConfigData.Phase = CarrierConfigData.Phase.SOLID
@export var size_scale: float = 1.0
@export var velocity: Vector2 = Vector2.ZERO

# 法术数据和嵌套层级
var spell_data: SpellCoreData = null
var nesting_level: int = 0

# 嵌套颜色链（从外到内的子法术颜色）
var _nested_colors: Array[Color] = []

# 视觉组件
var core_layers: Array[Node2D] = []      # 多层核心（渐变效果）
var nested_glow: Node2D = null           # 嵌套光晕（颜色叠加）
var energy_trail: Line2D = null          # 能量拖尾（平滑曲线）
var inner_trail: Line2D = null           # 内层拖尾（嵌套时显示）
var ambient_particles: GPUParticles2D = null # 环境粒子

# 相态特有组件
var phase_specific_nodes: Array[Node] = []

# 特殊效果组件
var chain_arcs: Node2D = null      # 链接电弧
var shield_overlay: Node2D = null  # 护盾覆层

# 拖尾历史位置
var _trail_points: Array[Vector2] = []
const BASE_TRAIL_POINTS = 10
const TRAIL_POINT_DISTANCE = 8.0

# 动画参数
var _time: float = 0.0
var _pulse_speed: float = 2.5
var _rotation_speed: float = 1.5
var _arc_timer: float = 0.0
var _arc_interval: float = 0.15

# 颜色配置（多层渐变）
var _color_outer: Color = Color.WHITE
var _color_middle: Color = Color.WHITE
var _color_inner: Color = Color.WHITE
var _color_core: Color = Color.WHITE
var _color_trail: Color = Color.WHITE
var _status_color: Color = Color.TRANSPARENT

# 嵌套增强参数（基于嵌套层级计算）
var _nesting_brightness: float = 1.0    # 亮度增强 (1.0 - 1.3)
var _nesting_saturation: float = 1.0    # 饱和度增强 (1.0 - 1.2)
var _trail_length_bonus: int = 0        # 拖尾长度加成 (0 - 4)

# 特殊效果标志
var _has_chain_effect: bool = false
var _has_shield_effect: bool = false
var _chain_type: int = 0

# 嵌套上限
const MAX_NESTING_VISUAL_LEVEL = 4  # 视觉效果最多响应4层嵌套

func _ready() -> void:
	_setup_visuals()

## 标准初始化（兼容旧版）
func initialize(p_phase: CarrierConfigData.Phase, p_size: float = 1.0, p_velocity: Vector2 = Vector2.ZERO) -> void:
	phase = p_phase
	size_scale = p_size
	velocity = p_velocity
	_calculate_nesting_params()
	_setup_colors()
	_setup_visuals()

## 增强初始化（支持完整法术数据）
func initialize_enhanced(p_spell_data: SpellCoreData, p_nesting_level: int = 0, p_velocity: Vector2 = Vector2.ZERO) -> void:
	spell_data = p_spell_data
	nesting_level = p_nesting_level
	velocity = p_velocity
	
	if spell_data and spell_data.carrier:
		phase = spell_data.carrier.phase
		size_scale = spell_data.carrier.size
	
	# 分析法术数据，提取特殊效果和嵌套颜色链
	_analyze_spell_effects()
	_collect_nested_colors()
	_calculate_nesting_params()
	_setup_colors()
	_setup_visuals()

## 计算嵌套增强参数
func _calculate_nesting_params() -> void:
	var effective_level = mini(nesting_level, MAX_NESTING_VISUAL_LEVEL)
	
	# 亮度：每层增加 7.5%，最多增加 30%
	_nesting_brightness = 1.0 + effective_level * 0.075
	
	# 饱和度：每层增加 5%，最多增加 20%
	_nesting_saturation = 1.0 + effective_level * 0.05
	
	# 拖尾长度：每层增加 1 个点，最多增加 4 个点
	_trail_length_bonus = effective_level

## 收集嵌套颜色链（递归获取子法术颜色）
func _collect_nested_colors() -> void:
	_nested_colors.clear()
	
	if spell_data == null:
		return
	
	_collect_colors_recursive(spell_data, 0)

func _collect_colors_recursive(data: SpellCoreData, depth: int) -> void:
	if depth >= MAX_NESTING_VISUAL_LEVEL or data == null:
		return
	
	for rule in data.topology_rules:
		for action in rule.actions:
			if action is FissionActionData:
				var fission = action as FissionActionData
				if fission.child_spell_data and fission.child_spell_data is SpellCoreData:
					var child_spell = fission.child_spell_data as SpellCoreData
					if child_spell.carrier:
						var child_phase = child_spell.carrier.phase
						var child_colors = VFXManager.PHASE_GRADIENT_COLORS.get(
							child_phase,
							VFXManager.PHASE_GRADIENT_COLORS[CarrierConfigData.Phase.SOLID]
						)
						_nested_colors.append(child_colors.inner)
						# 递归收集更深层的颜色
						_collect_colors_recursive(child_spell, depth + 1)

## 设置渐变颜色（考虑嵌套增强）
func _setup_colors() -> void:
	# 基于相态的基础色调
	match phase:
		CarrierConfigData.Phase.SOLID:
			_color_outer = Color(0.95, 0.6, 0.2, 0.15)
			_color_middle = Color(0.9, 0.5, 0.15, 0.4)
			_color_inner = Color(1.0, 0.7, 0.3, 0.7)
			_color_core = Color(1.0, 0.95, 0.8, 1.0)
			_color_trail = Color(0.95, 0.6, 0.2, 0.6)
		
		CarrierConfigData.Phase.LIQUID:
			_color_outer = Color(0.2, 0.7, 0.95, 0.15)
			_color_middle = Color(0.15, 0.6, 0.9, 0.4)
			_color_inner = Color(0.3, 0.8, 1.0, 0.7)
			_color_core = Color(0.85, 0.95, 1.0, 1.0)
			_color_trail = Color(0.2, 0.7, 0.95, 0.6)
		
		CarrierConfigData.Phase.PLASMA:
			_color_outer = Color(0.9, 0.2, 0.7, 0.15)
			_color_middle = Color(0.85, 0.15, 0.6, 0.4)
			_color_inner = Color(1.0, 0.4, 0.8, 0.7)
			_color_core = Color(1.0, 0.9, 0.95, 1.0)
			_color_trail = Color(0.9, 0.3, 0.7, 0.6)
	
	# 应用嵌套增强：提高亮度和饱和度
	if nesting_level > 0:
		_color_inner = _enhance_color(_color_inner)
		_color_core = _enhance_color(_color_core)
		_color_trail = _enhance_color(_color_trail)
	
	# 如果有状态效果，混合状态颜色
	if _status_color != Color.TRANSPARENT:
		_color_middle = _color_middle.lerp(_status_color, 0.3)
		_color_trail = _color_trail.lerp(_status_color, 0.25)

## 增强颜色（提高亮度和饱和度）
func _enhance_color(color: Color) -> Color:
	var h = color.h
	var s = minf(color.s * _nesting_saturation, 1.0)
	var v = minf(color.v * _nesting_brightness, 1.0)
	var enhanced = Color.from_hsv(h, s, v, color.a)
	return enhanced

## 分析法术效果
func _analyze_spell_effects() -> void:
	if spell_data == null:
		return
	
	for rule in spell_data.topology_rules:
		for action in rule.actions:
			if action is ApplyStatusActionData:
				var status_action = action as ApplyStatusActionData
				var status_colors = VFXManager.SPIRITON_PHASE_COLORS.get(
					status_action.spiriton_phase, 
					VFXManager.SPIRITON_PHASE_COLORS[ApplyStatusActionData.SpiritonPhase.PLASMA]
				)
				_status_color = status_colors.secondary
			
			if action is ChainActionData:
				_has_chain_effect = true
				_chain_type = (action as ChainActionData).chain_type
			
			if action is ShieldActionData:
				var shield_action = action as ShieldActionData
				if shield_action.shield_type == ShieldActionData.ShieldType.PROJECTILE:
					_has_shield_effect = true

func _setup_visuals() -> void:
	_clear_visuals()
	_trail_points.clear()
	
	# 根据相态创建视觉效果
	match phase:
		CarrierConfigData.Phase.SOLID:
			_setup_solid_visuals()
		CarrierConfigData.Phase.LIQUID:
			_setup_liquid_visuals()
		CarrierConfigData.Phase.PLASMA:
			_setup_plasma_visuals()
	
	# 嵌套光晕（如果有嵌套颜色）
	if _nested_colors.size() > 0:
		_setup_nested_glow()
	
	# 能量拖尾
	_setup_energy_trail()
	
	# 特殊效果
	if _has_chain_effect:
		_setup_chain_arcs()
	
	if _has_shield_effect:
		_setup_shield_overlay()

func _clear_visuals() -> void:
	for node in phase_specific_nodes:
		if is_instance_valid(node):
			node.queue_free()
	phase_specific_nodes.clear()
	
	for layer in core_layers:
		if is_instance_valid(layer):
			layer.queue_free()
	core_layers.clear()
	
	if nested_glow:
		nested_glow.queue_free()
		nested_glow = null
	if energy_trail:
		energy_trail.queue_free()
		energy_trail = null
	if inner_trail:
		inner_trail.queue_free()
		inner_trail = null
	if ambient_particles:
		ambient_particles.queue_free()
		ambient_particles = null
	if chain_arcs:
		chain_arcs.queue_free()
		chain_arcs = null
	if shield_overlay:
		shield_overlay.queue_free()
		shield_overlay = null

## ========== 嵌套光晕（颜色叠加而非同心环） ==========
func _setup_nested_glow() -> void:
	nested_glow = Node2D.new()
	var base_size = 8.0 * size_scale
	
	# 将嵌套颜色混合成一个渐变光晕，而不是多个同心环
	var blended_color = _blend_nested_colors()
	
	# 单层柔和光晕，颜色为混合后的嵌套色
	var glow = _create_smooth_polygon(base_size * 1.2, 12, blended_color)
	glow.color.a = 0.25 + mini(nesting_level, 3) * 0.05  # 嵌套越深略微更明显
	nested_glow.add_child(glow)
	
	add_child(nested_glow)

## 混合嵌套颜色（加权平均，越深的层级权重越低）
func _blend_nested_colors() -> Color:
	if _nested_colors.is_empty():
		return _color_inner
	
	var result = Color(0, 0, 0, 0)
	var total_weight = 0.0
	
	for i in range(_nested_colors.size()):
		var weight = 1.0 / (i + 1)  # 第一层权重1.0，第二层0.5，第三层0.33...
		result.r += _nested_colors[i].r * weight
		result.g += _nested_colors[i].g * weight
		result.b += _nested_colors[i].b * weight
		total_weight += weight
	
	if total_weight > 0:
		result.r /= total_weight
		result.g /= total_weight
		result.b /= total_weight
	
	result.a = 0.6
	return result

## ========== 能量拖尾 ==========
func _setup_energy_trail() -> void:
	# 主拖尾
	energy_trail = Line2D.new()
	energy_trail.width = 6.0 * size_scale
	energy_trail.width_curve = _create_trail_width_curve()
	energy_trail.default_color = _color_trail
	energy_trail.gradient = _create_trail_gradient()
	energy_trail.joint_mode = Line2D.LINE_JOINT_ROUND
	energy_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	energy_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	energy_trail.antialiased = true
	add_child(energy_trail)
	energy_trail.top_level = true
	
	# 嵌套时添加内层拖尾（更细、颜色不同）
	if _nested_colors.size() > 0:
		inner_trail = Line2D.new()
		inner_trail.width = 3.0 * size_scale
		inner_trail.width_curve = _create_trail_width_curve()
		inner_trail.default_color = _blend_nested_colors()
		inner_trail.gradient = _create_inner_trail_gradient()
		inner_trail.joint_mode = Line2D.LINE_JOINT_ROUND
		inner_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
		inner_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
		inner_trail.antialiased = true
		add_child(inner_trail)
		inner_trail.top_level = true

func _create_trail_width_curve() -> Curve:
	var curve = Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(0.3, 0.85))
	curve.add_point(Vector2(0.6, 0.6))
	curve.add_point(Vector2(0.85, 0.35))
	curve.add_point(Vector2(1.0, 0.15))
	return curve

func _create_trail_gradient() -> Gradient:
	var gradient = Gradient.new()
	gradient.set_color(0, Color(_color_inner.r, _color_inner.g, _color_inner.b, 0.8))
	gradient.add_point(0.3, Color(_color_middle.r, _color_middle.g, _color_middle.b, 0.6))
	gradient.add_point(0.6, Color(_color_trail.r, _color_trail.g, _color_trail.b, 0.4))
	gradient.set_color(1, Color(_color_outer.r, _color_outer.g, _color_outer.b, 0.0))
	return gradient

func _create_inner_trail_gradient() -> Gradient:
	var gradient = Gradient.new()
	var blended = _blend_nested_colors()
	gradient.set_color(0, Color(blended.r, blended.g, blended.b, 0.7))
	gradient.add_point(0.4, Color(blended.r, blended.g, blended.b, 0.4))
	gradient.set_color(1, Color(blended.r, blended.g, blended.b, 0.0))
	return gradient

## ========== 固态相态视觉 ==========
func _setup_solid_visuals() -> void:
	var base_size = 10.0 * size_scale
	
	# 外层光晕
	var outer_aura = _create_smooth_polygon(base_size * 2.2, 8, _color_outer)
	add_child(outer_aura)
	core_layers.append(outer_aura)
	
	# 中层能量体
	var middle_layer = _create_faceted_shape(base_size * 1.4, _color_middle)
	add_child(middle_layer)
	core_layers.append(middle_layer)
	
	# 内层核心
	var inner_layer = _create_smooth_polygon(base_size * 0.9, 6, _color_inner)
	add_child(inner_layer)
	core_layers.append(inner_layer)
	
	# 最内核心（嵌套时更亮）
	var core = _create_smooth_polygon(base_size * 0.5, 6, _color_core)
	add_child(core)
	core_layers.append(core)
	
	# 能量线条
	var energy_lines = _create_rotating_energy_lines(base_size * 1.6)
	add_child(energy_lines)
	phase_specific_nodes.append(energy_lines)
	
	# 火花粒子
	ambient_particles = _create_sparse_sparks(_color_inner)
	add_child(ambient_particles)

func _create_faceted_shape(size: float, color: Color) -> Polygon2D:
	var shape = Polygon2D.new()
	var points: PackedVector2Array = []
	
	for i in range(8):
		var angle = i * TAU / 8.0 - PI / 8.0
		var radius = size * (1.0 if i % 2 == 0 else 0.85)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	
	shape.polygon = points
	shape.color = color
	return shape

func _create_rotating_energy_lines(radius: float) -> Node2D:
	var container = Node2D.new()
	
	# 嵌套时增加能量线数量（3-5条）
	var line_count = 3 + mini(nesting_level, 2)
	
	for i in range(line_count):
		var line = Line2D.new()
		line.width = 1.5 * size_scale
		line.default_color = _color_inner
		line.default_color.a = 0.5
		
		var angle = i * TAU / line_count
		var start = Vector2(cos(angle), sin(angle)) * radius * 0.3
		var end = Vector2(cos(angle), sin(angle)) * radius
		line.points = PackedVector2Array([start, end])
		container.add_child(line)
	
	return container

## ========== 液态相态视觉 ==========
func _setup_liquid_visuals() -> void:
	var base_size = 10.0 * size_scale
	
	var outer_aura = _create_smooth_polygon(base_size * 2.4, 16, _color_outer)
	add_child(outer_aura)
	core_layers.append(outer_aura)
	
	var middle_layer = _create_fluid_shape(base_size * 1.5, _color_middle)
	add_child(middle_layer)
	core_layers.append(middle_layer)
	
	var inner_layer = _create_smooth_polygon(base_size * 0.95, 12, _color_inner)
	add_child(inner_layer)
	core_layers.append(inner_layer)
	
	var core = _create_smooth_polygon(base_size * 0.5, 8, _color_core)
	add_child(core)
	core_layers.append(core)
	
	var vortex = _create_vortex_lines(base_size * 1.2)
	add_child(vortex)
	phase_specific_nodes.append(vortex)
	
	ambient_particles = _create_bubble_particles()
	add_child(ambient_particles)

func _create_fluid_shape(size: float, color: Color) -> Polygon2D:
	var shape = Polygon2D.new()
	var points: PackedVector2Array = []
	var segments = 16
	
	for i in range(segments):
		var angle = i * TAU / segments
		var noise_offset = sin(angle * 3) * 0.15 + cos(angle * 5) * 0.1
		var radius = size * (1.0 + noise_offset)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	
	shape.polygon = points
	shape.color = color
	return shape

func _create_vortex_lines(radius: float) -> Node2D:
	var container = Node2D.new()
	
	# 嵌套时漩涡更复杂（2-3条）
	var vortex_count = 2 + mini(nesting_level, 1)
	
	for i in range(vortex_count):
		var line = Line2D.new()
		line.width = 1.5 * size_scale
		line.default_color = _color_inner
		line.default_color.a = 0.4
		
		var points: PackedVector2Array = []
		for j in range(8):
			var t = float(j) / 7.0
			var angle = t * PI + i * PI / vortex_count
			var r = radius * (0.2 + t * 0.6)
			points.append(Vector2(cos(angle), sin(angle)) * r)
		
		line.points = points
		container.add_child(line)
	
	return container

func _create_bubble_particles() -> GPUParticles2D:
	var particles = GPUParticles2D.new()
	particles.amount = 6
	particles.lifetime = 1.0
	particles.explosiveness = 0.0
	particles.randomness = 0.5
	
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, -1, 0)
	material.spread = 60.0
	material.initial_velocity_min = 10.0
	material.initial_velocity_max = 25.0
	material.gravity = Vector3(0, -15, 0)
	material.scale_min = 0.15 * size_scale
	material.scale_max = 0.3 * size_scale
	material.color = _color_inner
	
	particles.process_material = material
	particles.emitting = true
	return particles

## ========== 等离子态视觉 ==========
func _setup_plasma_visuals() -> void:
	var base_size = 10.0 * size_scale
	
	var outer_aura = _create_smooth_polygon(base_size * 2.8, 16, _color_outer)
	add_child(outer_aura)
	core_layers.append(outer_aura)
	
	var middle_layer = _create_plasma_shape(base_size * 1.6, _color_middle)
	add_child(middle_layer)
	core_layers.append(middle_layer)
	
	var inner_layer = _create_smooth_polygon(base_size * 1.0, 10, _color_inner)
	add_child(inner_layer)
	core_layers.append(inner_layer)
	
	var core = _create_smooth_polygon(base_size * 0.55, 8, _color_core)
	add_child(core)
	core_layers.append(core)
	
	# 电弧数量随嵌套增加（3-5条）
	var arcs = _create_plasma_arcs(base_size * 1.8)
	add_child(arcs)
	phase_specific_nodes.append(arcs)
	
	ambient_particles = _create_sparse_sparks(_color_inner)
	add_child(ambient_particles)

func _create_plasma_shape(size: float, color: Color) -> Polygon2D:
	var shape = Polygon2D.new()
	var points: PackedVector2Array = []
	var segments = 12
	
	for i in range(segments):
		var angle = i * TAU / segments
		var noise_offset = randf_range(-0.2, 0.2)
		var radius = size * (1.0 + noise_offset)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	
	shape.polygon = points
	shape.color = color
	return shape

func _create_plasma_arcs(radius: float) -> Node2D:
	var container = Node2D.new()
	
	# 嵌套增加电弧数量（3-5条）
	var arc_count = 3 + mini(nesting_level, 2)
	
	for i in range(arc_count):
		var arc = Line2D.new()
		arc.width = 2.0 * size_scale
		arc.default_color = _color_inner
		arc.default_color.a = 0.7
		
		var start_angle = randf() * TAU
		var arc_length = radius * randf_range(0.4, 0.8)
		
		var points: PackedVector2Array = []
		var segments = 4
		for j in range(segments + 1):
			var t = float(j) / segments
			var base_pos = Vector2(cos(start_angle), sin(start_angle)) * arc_length * t
			var offset = Vector2(randf_range(-4, 4), randf_range(-4, 4)) * size_scale * (1.0 - t)
			points.append(base_pos + offset)
		
		arc.points = points
		container.add_child(arc)
	
	return container

## ========== 通用组件 ==========
func _create_smooth_polygon(radius: float, segments: int, color: Color) -> Polygon2D:
	var polygon = Polygon2D.new()
	var points: PackedVector2Array = []
	
	for i in range(segments):
		var angle = i * TAU / segments
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	
	polygon.polygon = points
	polygon.color = color
	return polygon

func _create_sparse_sparks(color: Color) -> GPUParticles2D:
	var particles = GPUParticles2D.new()
	particles.amount = 8  # 固定数量，不随嵌套增加
	particles.lifetime = 0.6
	particles.explosiveness = 0.0
	particles.randomness = 0.6
	
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, 0, 0)
	material.spread = 180.0
	material.initial_velocity_min = 20.0
	material.initial_velocity_max = 50.0
	material.gravity = Vector3(0, 0, 0)
	material.scale_min = 0.1 * size_scale
	material.scale_max = 0.25 * size_scale
	material.color = color
	
	particles.process_material = material
	particles.emitting = true
	return particles

## ========== 特殊效果 ==========
func _setup_chain_arcs() -> void:
	chain_arcs = Node2D.new()
	chain_arcs.name = "ChainArcs"
	add_child(chain_arcs)
	_regenerate_chain_arcs()

func _regenerate_chain_arcs() -> void:
	if chain_arcs == null:
		return
	
	for child in chain_arcs.get_children():
		child.queue_free()
	
	var chain_colors = VFXManager.CHAIN_TYPE_COLORS.get(
		_chain_type,
		VFXManager.CHAIN_TYPE_COLORS[ChainActionData.ChainType.LIGHTNING]
	)
	
	var arc_count = randi_range(2, 3)
	for i in range(arc_count):
		var arc = Line2D.new()
		arc.width = 1.5 * size_scale
		arc.default_color = chain_colors.primary
		arc.default_color.a = 0.8
		
		var points: PackedVector2Array = []
		var start_angle = randf() * TAU
		var arc_length = (12.0 + randf() * 8.0) * size_scale
		
		points.append(Vector2.ZERO)
		var segments = randi_range(3, 5)
		for j in range(segments):
			var progress = float(j + 1) / segments
			var base_pos = Vector2(cos(start_angle), sin(start_angle)) * arc_length * progress
			var offset = Vector2(randf_range(-3, 3), randf_range(-3, 3)) * size_scale
			points.append(base_pos + offset)
		
		arc.points = points
		chain_arcs.add_child(arc)

func _setup_shield_overlay() -> void:
	shield_overlay = Node2D.new()
	shield_overlay.name = "ShieldOverlay"
	add_child(shield_overlay)
	
	var shield_radius = 16.0 * size_scale
	var hex_count = 6
	
	for i in range(hex_count):
		var hex = Polygon2D.new()
		var hex_size = shield_radius * 0.35
		
		var points: PackedVector2Array = []
		for j in range(6):
			var angle = j * PI / 3.0
			points.append(Vector2(cos(angle), sin(angle)) * hex_size)
		
		hex.polygon = points
		hex.color = Color(0.3, 0.8, 1.0, 0.25)
		
		var pos_angle = i * TAU / hex_count
		hex.position = Vector2(cos(pos_angle), sin(pos_angle)) * shield_radius * 0.65
		hex.name = "HexCell" + str(i)
		shield_overlay.add_child(hex)
	
	var outer_ring = Polygon2D.new()
	var ring_points: PackedVector2Array = []
	for i in range(24):
		var angle = i * TAU / 24
		ring_points.append(Vector2(cos(angle), sin(angle)) * shield_radius)
	outer_ring.polygon = ring_points
	outer_ring.color = Color(0.4, 0.9, 1.0, 0.15)
	outer_ring.name = "OuterRing"
	shield_overlay.add_child(outer_ring)

## ========== 动画更新 ==========
func _process(delta: float) -> void:
	_time += delta
	_update_trail()
	_animate_visuals(delta)
	_animate_special_effects(delta)

func _update_trail() -> void:
	if energy_trail == null:
		return
	
	var current_pos = global_position
	var max_points = BASE_TRAIL_POINTS + _trail_length_bonus
	
	if _trail_points.is_empty():
		_trail_points.append(current_pos)
	else:
		var last_point = _trail_points[0]
		if current_pos.distance_to(last_point) >= TRAIL_POINT_DISTANCE:
			_trail_points.insert(0, current_pos)
			
			while _trail_points.size() > max_points:
				_trail_points.pop_back()
	
	if _trail_points.size() >= 2:
		energy_trail.points = PackedVector2Array(_trail_points)
		if inner_trail:
			inner_trail.points = PackedVector2Array(_trail_points)
	else:
		energy_trail.points = PackedVector2Array()
		if inner_trail:
			inner_trail.points = PackedVector2Array()

func _animate_visuals(delta: float) -> void:
	var pulse = 1.0 + 0.08 * sin(_time * _pulse_speed)
	var pulse_fast = 1.0 + 0.05 * sin(_time * _pulse_speed * 2.0)
	
	for i in range(core_layers.size()):
		var layer = core_layers[i]
		if is_instance_valid(layer):
			var layer_pulse = pulse if i < 2 else pulse_fast
			layer.scale = Vector2.ONE * layer_pulse
	
	# 嵌套光晕脉动
	if nested_glow:
		nested_glow.scale = Vector2.ONE * (pulse * 1.05)
		nested_glow.rotation += delta * _rotation_speed * 0.3
	
	match phase:
		CarrierConfigData.Phase.SOLID:
			_animate_solid(delta)
		CarrierConfigData.Phase.LIQUID:
			_animate_liquid(delta)
		CarrierConfigData.Phase.PLASMA:
			_animate_plasma(delta)

func _animate_solid(delta: float) -> void:
	for node in phase_specific_nodes:
		if node is Node2D:
			node.rotation += delta * _rotation_speed

func _animate_liquid(delta: float) -> void:
	for node in phase_specific_nodes:
		if node is Node2D:
			node.rotation += delta * _rotation_speed * 1.5

func _animate_plasma(delta: float) -> void:
	if core_layers.size() > 1:
		var plasma_layer = core_layers[1]
		if is_instance_valid(plasma_layer) and plasma_layer is Polygon2D:
			var points = plasma_layer.polygon
			var new_points: PackedVector2Array = []
			var base_size = 16.0 * size_scale
			
			for i in range(points.size()):
				var angle = i * TAU / points.size()
				var noise_offset = randf_range(-0.15, 0.15)
				var radius = base_size * (1.0 + noise_offset)
				new_points.append(Vector2(cos(angle), sin(angle)) * radius)
			
			plasma_layer.polygon = new_points
	
	for node in phase_specific_nodes:
		if node is Node2D:
			for child in node.get_children():
				if child is Line2D:
					child.modulate.a = 0.4 + 0.4 * randf()

func _animate_special_effects(delta: float) -> void:
	if chain_arcs:
		_arc_timer += delta
		if _arc_timer >= _arc_interval:
			_arc_timer = 0.0
			_regenerate_chain_arcs()
		
		for arc in chain_arcs.get_children():
			if arc is Line2D:
				arc.modulate.a = 0.5 + 0.4 * randf()
	
	if shield_overlay:
		shield_overlay.rotation += delta * 0.4
		
		var hex_index = 0
		for child in shield_overlay.get_children():
			if child is Polygon2D and child.name.begins_with("HexCell"):
				var phase_offset = hex_index * TAU / 6.0
				var alpha = 0.15 + 0.12 * sin(_time * 2.5 + phase_offset)
				child.color.a = alpha
				hex_index += 1

func update_velocity(new_velocity: Vector2) -> void:
	velocity = new_velocity

func stop() -> void:
	if ambient_particles:
		ambient_particles.emitting = false
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)
	tween.tween_callback(func(): effect_finished.emit())
