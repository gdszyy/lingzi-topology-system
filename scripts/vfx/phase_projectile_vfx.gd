class_name PhaseProjectileVFX
extends Node2D
## 相态弹体视觉特效
## 根据灵子相态、速度、嵌套层级等属性动态生成对应的视觉效果

signal effect_finished

@export var phase: CarrierConfigData.Phase = CarrierConfigData.Phase.SOLID
@export var size_scale: float = 1.0
@export var velocity: Vector2 = Vector2.ZERO

# 新增：法术数据和嵌套层级
var spell_data: SpellCoreData = null
var nesting_level: int = 0

# 视觉组件
var core_layers: Array[Node2D] = []      # 多层核心（渐变效果）
var energy_aura: Node2D = null           # 能量光环
var inner_core: Node2D = null            # 内核（嵌套时显示）
var energy_trail: Line2D = null          # 能量拖尾（平滑曲线）
var ambient_particles: GPUParticles2D = null # 环境粒子（稀疏的能量火花）

# 相态特有组件
var phase_specific_nodes: Array[Node] = []

# 特殊效果组件
var chain_arcs: Node2D = null      # 链接电弧
var shield_overlay: Node2D = null  # 护盾覆层

# 拖尾历史位置
var _trail_points: Array[Vector2] = []
const MAX_TRAIL_POINTS = 12
const TRAIL_POINT_DISTANCE = 8.0

# 动画参数
var _time: float = 0.0
var _pulse_speed: float = 2.5
var _rotation_speed: float = 1.5
var _arc_timer: float = 0.0
var _arc_interval: float = 0.15
var _last_position: Vector2 = Vector2.ZERO

# 颜色配置（多层渐变）
var _color_outer: Color = Color.WHITE
var _color_middle: Color = Color.WHITE
var _color_inner: Color = Color.WHITE
var _color_core: Color = Color.WHITE
var _color_trail: Color = Color.WHITE
var _status_color: Color = Color.TRANSPARENT
var _inner_color: Color = Color.TRANSPARENT

# 特殊效果标志
var _has_chain_effect: bool = false
var _has_shield_effect: bool = false
var _chain_type: int = 0

func _ready() -> void:
	_setup_visuals()

## 标准初始化（兼容旧版）
func initialize(p_phase: CarrierConfigData.Phase, p_size: float = 1.0, p_velocity: Vector2 = Vector2.ZERO) -> void:
	phase = p_phase
	size_scale = p_size
	velocity = p_velocity
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
	
	# 分析法术数据，提取特殊效果信息
	_analyze_spell_effects()
	_setup_colors()
	_setup_visuals()

## 设置渐变颜色
func _setup_colors() -> void:
	# 基于相态的基础色调
	match phase:
		CarrierConfigData.Phase.SOLID:
			# 琥珀色/金色系 - 坚硬、稳定
			_color_outer = Color(0.95, 0.6, 0.2, 0.15)      # 外层光晕：淡金色
			_color_middle = Color(0.9, 0.5, 0.15, 0.4)     # 中层：橙金色
			_color_inner = Color(1.0, 0.7, 0.3, 0.7)       # 内层：亮金色
			_color_core = Color(1.0, 0.95, 0.8, 1.0)       # 核心：近白金色
			_color_trail = Color(0.95, 0.6, 0.2, 0.6)      # 拖尾：金色
		
		CarrierConfigData.Phase.LIQUID:
			# 青蓝色系 - 流动、冷冽
			_color_outer = Color(0.2, 0.7, 0.95, 0.15)      # 外层光晕：淡青色
			_color_middle = Color(0.15, 0.6, 0.9, 0.4)     # 中层：天蓝色
			_color_inner = Color(0.3, 0.8, 1.0, 0.7)       # 内层：亮青色
			_color_core = Color(0.85, 0.95, 1.0, 1.0)      # 核心：近白青色
			_color_trail = Color(0.2, 0.7, 0.95, 0.6)      # 拖尾：青色
		
		CarrierConfigData.Phase.PLASMA:
			# 紫红色系 - 高能、不稳定
			_color_outer = Color(0.9, 0.2, 0.7, 0.15)       # 外层光晕：淡紫红
			_color_middle = Color(0.85, 0.15, 0.6, 0.4)    # 中层：品红色
			_color_inner = Color(1.0, 0.4, 0.8, 0.7)       # 内层：亮粉紫
			_color_core = Color(1.0, 0.9, 0.95, 1.0)       # 核心：近白粉色
			_color_trail = Color(0.9, 0.3, 0.7, 0.6)       # 拖尾：紫红色
	
	# 如果有状态效果，混合状态颜色到中层和拖尾
	if _status_color != Color.TRANSPARENT:
		_color_middle = _color_middle.lerp(_status_color, 0.3)
		_color_trail = _color_trail.lerp(_status_color, 0.25)

## 分析法术效果
func _analyze_spell_effects() -> void:
	if spell_data == null:
		return
	
	for rule in spell_data.topology_rules:
		for action in rule.actions:
			# 检查状态效果
			if action is ApplyStatusActionData:
				var status_action = action as ApplyStatusActionData
				var status_colors = VFXManager.SPIRITON_PHASE_COLORS.get(
					status_action.spiriton_phase, 
					VFXManager.SPIRITON_PHASE_COLORS[ApplyStatusActionData.SpiritonPhase.PLASMA]
				)
				_status_color = status_colors.secondary
			
			# 检查链接效果
			if action is ChainActionData:
				_has_chain_effect = true
				_chain_type = (action as ChainActionData).chain_type
			
			# 检查护盾效果
			if action is ShieldActionData:
				var shield_action = action as ShieldActionData
				if shield_action.shield_type == ShieldActionData.ShieldType.PROJECTILE:
					_has_shield_effect = true
			
			# 检查裂变效果，获取子法术颜色
			if action is FissionActionData:
				var fission = action as FissionActionData
				if fission.child_spell_data and fission.child_spell_data is SpellCoreData:
					var child_spell = fission.child_spell_data as SpellCoreData
					if child_spell.carrier:
						var child_colors = VFXManager.PHASE_COLORS.get(
							child_spell.carrier.phase,
							VFXManager.PHASE_COLORS[CarrierConfigData.Phase.SOLID]
						)
						_inner_color = child_colors.primary

func _setup_visuals() -> void:
	# 清理旧的视觉组件
	_clear_visuals()
	
	# 初始化拖尾
	_trail_points.clear()
	_last_position = global_position
	
	# 根据相态创建不同的视觉效果
	match phase:
		CarrierConfigData.Phase.SOLID:
			_setup_solid_visuals()
		CarrierConfigData.Phase.LIQUID:
			_setup_liquid_visuals()
		CarrierConfigData.Phase.PLASMA:
			_setup_plasma_visuals()
	
	# 设置能量拖尾（所有相态通用）
	_setup_energy_trail()
	
	# 设置特殊效果
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
	
	if energy_aura:
		energy_aura.queue_free()
		energy_aura = null
	if inner_core:
		inner_core.queue_free()
		inner_core = null
	if energy_trail:
		energy_trail.queue_free()
		energy_trail = null
	if ambient_particles:
		ambient_particles.queue_free()
		ambient_particles = null
	if chain_arcs:
		chain_arcs.queue_free()
		chain_arcs = null
	if shield_overlay:
		shield_overlay.queue_free()
		shield_overlay = null

## 计算速度因子（用于形状变形）
func _get_velocity_factor() -> float:
	var speed = velocity.length()
	return clampf(speed / 800.0, 0.0, 1.0)

## ========== 能量拖尾（通用） ==========
func _setup_energy_trail() -> void:
	# 主拖尾线
	energy_trail = Line2D.new()
	energy_trail.width = 6.0 * size_scale
	energy_trail.width_curve = _create_trail_width_curve()
	energy_trail.default_color = _color_trail
	energy_trail.gradient = _create_trail_gradient()
	energy_trail.joint_mode = Line2D.LINE_JOINT_ROUND
	energy_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	energy_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	energy_trail.antialiased = true
	
	# 拖尾需要添加到父节点以保持世界坐标
	add_child(energy_trail)
	energy_trail.top_level = true  # 使用全局坐标

func _create_trail_width_curve() -> Curve:
	var curve = Curve.new()
	# 从粗到细的平滑过渡，但不是尖锐的尾巴
	curve.add_point(Vector2(0.0, 1.0))    # 起点：最粗
	curve.add_point(Vector2(0.3, 0.85))   # 保持较粗
	curve.add_point(Vector2(0.6, 0.6))    # 中段渐细
	curve.add_point(Vector2(0.85, 0.35))  # 尾段
	curve.add_point(Vector2(1.0, 0.15))   # 末端：较细但不尖锐
	return curve

func _create_trail_gradient() -> Gradient:
	var gradient = Gradient.new()
	# 从亮到暗的渐变
	gradient.set_color(0, Color(_color_inner.r, _color_inner.g, _color_inner.b, 0.8))
	gradient.add_point(0.3, Color(_color_middle.r, _color_middle.g, _color_middle.b, 0.6))
	gradient.add_point(0.6, Color(_color_trail.r, _color_trail.g, _color_trail.b, 0.4))
	gradient.set_color(1, Color(_color_outer.r, _color_outer.g, _color_outer.b, 0.0))
	return gradient

## ========== 固态相态视觉 ==========
func _setup_solid_visuals() -> void:
	var base_size = 10.0 * size_scale
	
	# 外层光晕（大而淡）
	var outer_aura = _create_smooth_polygon(base_size * 2.2, 8, _color_outer)
	add_child(outer_aura)
	core_layers.append(outer_aura)
	
	# 中层能量体（菱形/八边形）
	var middle_layer = _create_faceted_shape(base_size * 1.4, _color_middle)
	add_child(middle_layer)
	core_layers.append(middle_layer)
	
	# 内层核心（亮）
	var inner_layer = _create_smooth_polygon(base_size * 0.9, 6, _color_inner)
	add_child(inner_layer)
	core_layers.append(inner_layer)
	
	# 最内核心（过曝白）
	var core = _create_smooth_polygon(base_size * 0.5, 6, _color_core)
	add_child(core)
	core_layers.append(core)
	
	# 嵌套内核
	if nesting_level > 0 or _inner_color != Color.TRANSPARENT:
		inner_core = _create_nested_core(base_size * 0.6)
		add_child(inner_core)
	
	# 能量线条装饰
	var energy_lines = _create_rotating_energy_lines(base_size * 1.6)
	add_child(energy_lines)
	phase_specific_nodes.append(energy_lines)
	
	# 稀疏的能量火花
	ambient_particles = _create_sparse_sparks(_color_inner)
	add_child(ambient_particles)

func _create_faceted_shape(size: float, color: Color) -> Polygon2D:
	var shape = Polygon2D.new()
	var points: PackedVector2Array = []
	
	# 八边形，但交替长短边，形成晶体感
	for i in range(8):
		var angle = i * TAU / 8.0 - PI / 8.0
		var radius = size * (1.0 if i % 2 == 0 else 0.85)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	
	shape.polygon = points
	shape.color = color
	return shape

func _create_rotating_energy_lines(radius: float) -> Node2D:
	var container = Node2D.new()
	
	# 3条旋转的能量线
	for i in range(3):
		var line = Line2D.new()
		line.width = 1.5 * size_scale
		line.default_color = _color_inner
		line.default_color.a = 0.5
		
		var angle = i * TAU / 3.0
		var start = Vector2(cos(angle), sin(angle)) * radius * 0.3
		var end = Vector2(cos(angle), sin(angle)) * radius
		line.points = PackedVector2Array([start, end])
		container.add_child(line)
	
	return container

## ========== 液态相态视觉 ==========
func _setup_liquid_visuals() -> void:
	var base_size = 10.0 * size_scale
	
	# 外层水波光晕
	var outer_aura = _create_smooth_polygon(base_size * 2.4, 16, _color_outer)
	add_child(outer_aura)
	core_layers.append(outer_aura)
	
	# 中层流体
	var middle_layer = _create_fluid_shape(base_size * 1.5, _color_middle)
	add_child(middle_layer)
	core_layers.append(middle_layer)
	
	# 内层核心
	var inner_layer = _create_smooth_polygon(base_size * 0.95, 12, _color_inner)
	add_child(inner_layer)
	core_layers.append(inner_layer)
	
	# 最内核心
	var core = _create_smooth_polygon(base_size * 0.5, 8, _color_core)
	add_child(core)
	core_layers.append(core)
	
	# 嵌套内核
	if nesting_level > 0 or _inner_color != Color.TRANSPARENT:
		inner_core = _create_nested_core(base_size * 0.6)
		add_child(inner_core)
	
	# 内部漩涡
	var vortex = _create_vortex_lines(base_size * 1.2)
	add_child(vortex)
	phase_specific_nodes.append(vortex)
	
	# 气泡粒子
	ambient_particles = _create_bubble_particles()
	add_child(ambient_particles)

func _create_fluid_shape(size: float, color: Color) -> Polygon2D:
	var shape = Polygon2D.new()
	var points: PackedVector2Array = []
	
	# 不规则的流体形状
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
	
	# 螺旋线
	for i in range(2):
		var line = Line2D.new()
		line.width = 1.5 * size_scale
		line.default_color = _color_inner
		line.default_color.a = 0.4
		
		var points: PackedVector2Array = []
		for j in range(8):
			var t = float(j) / 7.0
			var angle = t * PI + i * PI
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

## ========== 等离子态相态视觉 ==========
func _setup_plasma_visuals() -> void:
	var base_size = 10.0 * size_scale
	
	# 外层能量场（大范围淡光）
	var outer_aura = _create_smooth_polygon(base_size * 2.8, 16, _color_outer)
	add_child(outer_aura)
	core_layers.append(outer_aura)
	
	# 中层等离子体
	var middle_layer = _create_plasma_shape(base_size * 1.6, _color_middle)
	add_child(middle_layer)
	core_layers.append(middle_layer)
	
	# 内层高能核心
	var inner_layer = _create_smooth_polygon(base_size * 1.0, 10, _color_inner)
	add_child(inner_layer)
	core_layers.append(inner_layer)
	
	# 最内核心（过曝）
	var core = _create_smooth_polygon(base_size * 0.55, 8, _color_core)
	add_child(core)
	core_layers.append(core)
	
	# 嵌套内核
	if nesting_level > 0 or _inner_color != Color.TRANSPARENT:
		inner_core = _create_nested_core(base_size * 0.65)
		add_child(inner_core)
	
	# 电弧效果
	var arcs = _create_plasma_arcs(base_size * 1.8)
	add_child(arcs)
	phase_specific_nodes.append(arcs)
	
	# 能量火花
	ambient_particles = _create_sparse_sparks(_color_inner)
	add_child(ambient_particles)

func _create_plasma_shape(size: float, color: Color) -> Polygon2D:
	var shape = Polygon2D.new()
	var points: PackedVector2Array = []
	
	# 不稳定的等离子形状
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
	
	# 3-4条短电弧
	var arc_count = 3 + nesting_level
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

func _create_nested_core(size: float) -> Node2D:
	var container = Node2D.new()
	var layers = mini(nesting_level + 1, 3)
	
	for layer in range(layers):
		var core_layer = Polygon2D.new()
		var layer_size = size * (1.0 - layer * 0.25)
		
		var points: PackedVector2Array = []
		var segments = 6
		for i in range(segments):
			var angle = i * TAU / segments + layer * PI / 6.0
			points.append(Vector2(cos(angle), sin(angle)) * layer_size)
		
		core_layer.polygon = points
		
		if _inner_color != Color.TRANSPARENT:
			core_layer.color = _inner_color.lerp(Color.WHITE, layer * 0.3)
		else:
			core_layer.color = _color_core.lerp(Color.WHITE, layer * 0.2)
		
		core_layer.color.a = 0.8 - layer * 0.2
		container.add_child(core_layer)
	
	return container

func _create_sparse_sparks(color: Color) -> GPUParticles2D:
	var particles = GPUParticles2D.new()
	particles.amount = 8
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

## 设置链接电弧效果
func _setup_chain_arcs() -> void:
	chain_arcs = Node2D.new()
	chain_arcs.name = "ChainArcs"
	add_child(chain_arcs)
	_regenerate_chain_arcs()

## 重新生成链接电弧
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

## 设置护盾覆层效果
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
	
	# 检查是否需要添加新点
	if _trail_points.is_empty():
		_trail_points.append(current_pos)
	else:
		var last_point = _trail_points[0]
		if current_pos.distance_to(last_point) >= TRAIL_POINT_DISTANCE:
			_trail_points.insert(0, current_pos)
			
			# 限制点数
			while _trail_points.size() > MAX_TRAIL_POINTS:
				_trail_points.pop_back()
	
	# 更新拖尾线
	if _trail_points.size() >= 2:
		energy_trail.points = PackedVector2Array(_trail_points)
	else:
		energy_trail.points = PackedVector2Array()

func _animate_visuals(delta: float) -> void:
	var pulse = 1.0 + 0.08 * sin(_time * _pulse_speed)
	var pulse_fast = 1.0 + 0.05 * sin(_time * _pulse_speed * 2.0)
	
	# 核心层脉动
	for i in range(core_layers.size()):
		var layer = core_layers[i]
		if is_instance_valid(layer):
			var layer_pulse = pulse if i < 2 else pulse_fast
			layer.scale = Vector2.ONE * layer_pulse
	
	# 内核旋转
	if inner_core:
		inner_core.rotation += delta * _rotation_speed * 0.5
	
	# 相态特有动画
	match phase:
		CarrierConfigData.Phase.SOLID:
			_animate_solid(delta)
		CarrierConfigData.Phase.LIQUID:
			_animate_liquid(delta)
		CarrierConfigData.Phase.PLASMA:
			_animate_plasma(delta)

func _animate_solid(delta: float) -> void:
	# 能量线旋转
	for node in phase_specific_nodes:
		if node is Node2D:
			node.rotation += delta * _rotation_speed

func _animate_liquid(delta: float) -> void:
	# 漩涡旋转
	for node in phase_specific_nodes:
		if node is Node2D:
			node.rotation += delta * _rotation_speed * 1.5

func _animate_plasma(delta: float) -> void:
	# 等离子形状抖动
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
	
	# 电弧闪烁
	for node in phase_specific_nodes:
		if node is Node2D:
			for child in node.get_children():
				if child is Line2D:
					child.modulate.a = 0.4 + 0.4 * randf()

func _animate_special_effects(delta: float) -> void:
	# 链接电弧动画
	if chain_arcs:
		_arc_timer += delta
		if _arc_timer >= _arc_interval:
			_arc_timer = 0.0
			_regenerate_chain_arcs()
		
		for arc in chain_arcs.get_children():
			if arc is Line2D:
				arc.modulate.a = 0.5 + 0.4 * randf()
	
	# 护盾流动动画
	if shield_overlay:
		shield_overlay.rotation += delta * 0.4
		
		var hex_index = 0
		for child in shield_overlay.get_children():
			if child is Polygon2D and child.name.begins_with("HexCell"):
				var phase_offset = hex_index * TAU / 6.0
				var alpha = 0.15 + 0.12 * sin(_time * 2.5 + phase_offset)
				child.color.a = alpha
				hex_index += 1

## 更新速度向量
func update_velocity(new_velocity: Vector2) -> void:
	velocity = new_velocity

## 停止特效
func stop() -> void:
	if ambient_particles:
		ambient_particles.emitting = false
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)
	tween.tween_callback(func(): effect_finished.emit())
