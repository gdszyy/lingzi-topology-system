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
var core_visual: Node2D           # 核心视觉
var inner_core: Node2D            # 内核（嵌套时显示）
var glow_visual: Node2D           # 光晕
var trail_particles: GPUParticles2D  # 拖尾粒子
var ambient_particles: GPUParticles2D # 环境粒子

# 相态特有组件
var phase_specific_nodes: Array[Node] = []

# 特殊效果组件
var chain_arcs: Node2D = null      # 链接电弧
var shield_overlay: Node2D = null  # 护盾覆层

# 动画参数
var _time: float = 0.0
var _pulse_speed: float = 3.0
var _rotation_speed: float = 2.0
var _arc_timer: float = 0.0
var _arc_interval: float = 0.15

# 颜色配置
var _colors: Dictionary = {}
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
	_setup_visuals()

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
	
	if core_visual:
		core_visual.queue_free()
		core_visual = null
	if inner_core:
		inner_core.queue_free()
		inner_core = null
	if glow_visual:
		glow_visual.queue_free()
		glow_visual = null
	if trail_particles:
		trail_particles.queue_free()
		trail_particles = null
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
	# 将速度映射到 0-1 范围，假设最大速度为 1000
	return clampf(speed / 1000.0, 0.0, 1.0)

## ========== 固态相态视觉 ==========
func _setup_solid_visuals() -> void:
	var vel_factor = _get_velocity_factor()
	
	# 核心：棱角分明的几何晶体，速度越快越尖锐
	core_visual = _create_crystal_shape(vel_factor)
	add_child(core_visual)
	
	# 嵌套内核
	if nesting_level > 0 or _inner_color != Color.TRANSPARENT:
		inner_core = _create_nested_inner_core_solid()
		add_child(inner_core)
	
	# 光晕：微弱的能量光晕
	var glow_color = _status_color if _status_color != Color.TRANSPARENT else _colors.glow
	glow_visual = _create_glow(24.0 * size_scale, glow_color)
	add_child(glow_visual)
	
	# 拖尾：几何碎片，速度越快碎片越多
	trail_particles = _create_solid_trail(vel_factor)
	add_child(trail_particles)
	
	# 能量脉冲线条
	var energy_lines = _create_energy_circuit_lines()
	add_child(energy_lines)
	phase_specific_nodes.append(energy_lines)

func _create_crystal_shape(vel_factor: float) -> Polygon2D:
	var crystal = Polygon2D.new()
	var base_size = 12.0 * size_scale
	
	# 根据速度调整形状：速度越快，形状越趋向于拉长的尖锥形
	var points: PackedVector2Array = []
	var vertex_count = 6
	
	for i in range(vertex_count):
		var angle = i * TAU / vertex_count - PI / 2.0  # 从顶部开始
		var radius = base_size
		
		# 速度影响：前端拉长，后端收缩
		if i == 0:  # 前端顶点
			radius = base_size * (1.0 + vel_factor * 0.8)
		elif i == vertex_count / 2:  # 后端顶点
			radius = base_size * (0.7 - vel_factor * 0.2)
		else:
			# 侧面顶点，速度越快越窄
			radius = base_size * (1.0 if i % 2 == 0 else 0.7) * (1.0 - vel_factor * 0.3)
		
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	
	crystal.polygon = points
	crystal.color = _colors.primary
	return crystal

func _create_nested_inner_core_solid() -> Node2D:
	var container = Node2D.new()
	var layers = mini(nesting_level + 1, 3)  # 最多3层
	
	for layer in range(layers):
		var inner = Polygon2D.new()
		var layer_size = 6.0 * size_scale * (1.0 - layer * 0.25)
		
		var points: PackedVector2Array = []
		for i in range(6):
			var angle = i * PI / 3.0 + layer * PI / 6.0  # 每层旋转一点
			var radius = layer_size * (1.0 if i % 2 == 0 else 0.6)
			points.append(Vector2(cos(angle), sin(angle)) * radius)
		
		inner.polygon = points
		
		# 使用内核颜色或渐变到白色
		if _inner_color != Color.TRANSPARENT:
			inner.color = _inner_color.lerp(Color.WHITE, layer * 0.3)
		else:
			inner.color = _colors.secondary.lerp(Color.WHITE, layer * 0.3)
		
		inner.color.a = 0.8 - layer * 0.2
		container.add_child(inner)
	
	return container

func _create_solid_trail(vel_factor: float) -> GPUParticles2D:
	var particles = GPUParticles2D.new()
	# 速度越快，粒子越多
	particles.amount = int(20 + vel_factor * 30)
	particles.lifetime = 0.4 + vel_factor * 0.2
	particles.explosiveness = 0.0
	particles.randomness = 0.3
	
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(-1, 0, 0)
	material.spread = 15.0 + vel_factor * 10.0
	material.initial_velocity_min = 50.0 + vel_factor * 50.0
	material.initial_velocity_max = 100.0 + vel_factor * 100.0
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
	var vel_factor = _get_velocity_factor()
	
	# 核心：液滴形态，速度越快越拉长
	core_visual = _create_droplet_shape(vel_factor)
	add_child(core_visual)
	
	# 嵌套内核：内部漩涡
	if nesting_level > 0 or _inner_color != Color.TRANSPARENT:
		inner_core = _create_nested_inner_core_liquid()
		add_child(inner_core)
	
	# 光晕：冷色光晕
	var glow_color = _status_color if _status_color != Color.TRANSPARENT else _colors.glow
	glow_visual = _create_glow(28.0 * size_scale, glow_color)
	add_child(glow_visual)
	
	# 拖尾：液态轨迹
	trail_particles = _create_liquid_trail(vel_factor)
	add_child(trail_particles)
	
	# 内部漩涡效果（基础版）
	var vortex = _create_inner_vortex()
	add_child(vortex)
	phase_specific_nodes.append(vortex)
	
	# 气泡粒子
	ambient_particles = _create_bubble_particles()
	add_child(ambient_particles)

func _create_droplet_shape(vel_factor: float) -> Polygon2D:
	var droplet = Polygon2D.new()
	var base_size = 10.0 * size_scale
	
	# 液滴形状，速度越快越拉长
	var points: PackedVector2Array = []
	var segments = 16
	
	for i in range(segments):
		var t = float(i) / segments * TAU
		# 基础液滴形状 + 速度拉伸
		var stretch_x = 1.0 + vel_factor * 0.6  # 水平拉伸
		var stretch_y = 1.0 - vel_factor * 0.2  # 垂直压缩
		var r = base_size * (1.0 + 0.3 * cos(2 * t))
		points.append(Vector2(cos(t) * stretch_x, sin(t) * stretch_y) * r)
	
	droplet.polygon = points
	droplet.color = _colors.primary
	return droplet

func _create_nested_inner_core_liquid() -> Node2D:
	var container = Node2D.new()
	var layers = mini(nesting_level + 1, 3)
	
	for layer in range(layers):
		var vortex = Polygon2D.new()
		var layer_size = 5.0 * size_scale * (1.0 - layer * 0.2)
		
		# 螺旋形状
		var points: PackedVector2Array = []
		for i in range(12):
			var angle = i * PI / 6.0 + layer * PI / 4.0
			var radius = layer_size * (0.4 + 0.6 * float(i) / 12.0)
			points.append(Vector2(cos(angle), sin(angle)) * radius)
		
		vortex.polygon = points
		
		if _inner_color != Color.TRANSPARENT:
			vortex.color = _inner_color.lerp(_colors.secondary, layer * 0.3)
		else:
			vortex.color = _colors.secondary.lerp(Color.WHITE, layer * 0.2)
		
		vortex.color.a = 0.7 - layer * 0.15
		container.add_child(vortex)
	
	return container

func _create_liquid_trail(vel_factor: float) -> GPUParticles2D:
	var particles = GPUParticles2D.new()
	particles.amount = int(30 + vel_factor * 20)
	particles.lifetime = 0.6 + vel_factor * 0.3
	particles.explosiveness = 0.0
	particles.randomness = 0.4
	
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(-1, 0, 0)
	material.spread = 20.0 + vel_factor * 15.0
	material.initial_velocity_min = 30.0 + vel_factor * 40.0
	material.initial_velocity_max = 60.0 + vel_factor * 60.0
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
	var vel_factor = _get_velocity_factor()
	
	# 核心：不稳定能量球，速度越快越不稳定
	core_visual = _create_plasma_core(vel_factor)
	add_child(core_visual)
	
	# 嵌套内核：多层能量核心
	if nesting_level > 0 or _inner_color != Color.TRANSPARENT:
		inner_core = _create_nested_inner_core_plasma()
		add_child(inner_core)
	
	# 强烈光晕
	var glow_color = _status_color if _status_color != Color.TRANSPARENT else _colors.glow
	glow_visual = _create_glow(36.0 * size_scale, glow_color)
	add_child(glow_visual)
	
	# 炽热拖尾
	trail_particles = _create_plasma_trail(vel_factor)
	add_child(trail_particles)
	
	# 电弧效果，嵌套越多电弧越多
	var arcs = _create_electric_arcs()
	add_child(arcs)
	phase_specific_nodes.append(arcs)
	
	# 火星粒子
	ambient_particles = _create_spark_particles()
	add_child(ambient_particles)

func _create_plasma_core(vel_factor: float) -> Node2D:
	var container = Node2D.new()
	
	# 外层火焰，速度越快越向后拖拽
	var outer = Polygon2D.new()
	var base_size = 14.0 * size_scale
	var points: PackedVector2Array = []
	
	for i in range(12):
		var angle = i * PI / 6.0
		var radius = base_size * (0.8 + randf() * 0.4)
		
		# 速度影响：后方火焰拖拽
		if angle > PI / 2.0 and angle < 3.0 * PI / 2.0:
			radius *= (1.0 + vel_factor * 0.5)
		
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	
	outer.polygon = points
	outer.color = _colors.primary
	container.add_child(outer)
	
	# 内核（过曝），速度越快越亮
	var inner = Polygon2D.new()
	var inner_points: PackedVector2Array = []
	var inner_size = base_size * (0.4 + vel_factor * 0.1)
	
	for i in range(8):
		var angle = i * PI / 4.0
		inner_points.append(Vector2(cos(angle), sin(angle)) * inner_size)
	
	inner.polygon = inner_points
	inner.color = _colors.secondary.lerp(Color.WHITE, vel_factor * 0.3)
	container.add_child(inner)
	
	return container

func _create_nested_inner_core_plasma() -> Node2D:
	var container = Node2D.new()
	var layers = mini(nesting_level + 1, 3)
	
	for layer in range(layers):
		var core = Polygon2D.new()
		var layer_size = 4.0 * size_scale * (1.0 - layer * 0.15)
		
		var points: PackedVector2Array = []
		for i in range(8):
			var angle = i * PI / 4.0 + layer * PI / 8.0
			var radius = layer_size * (0.8 + randf() * 0.4)
			points.append(Vector2(cos(angle), sin(angle)) * radius)
		
		core.polygon = points
		
		if _inner_color != Color.TRANSPARENT:
			core.color = _inner_color.lerp(Color.WHITE, 0.3 + layer * 0.2)
		else:
			core.color = _colors.secondary.lerp(Color.WHITE, 0.5 + layer * 0.2)
		
		core.color.a = 0.9 - layer * 0.1
		container.add_child(core)
	
	return container

func _create_plasma_trail(vel_factor: float) -> GPUParticles2D:
	var particles = GPUParticles2D.new()
	particles.amount = int(40 + vel_factor * 40)
	particles.lifetime = 0.5 + vel_factor * 0.3
	particles.explosiveness = 0.0
	particles.randomness = 0.5
	
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(-1, 0, 0)
	material.spread = 30.0 + vel_factor * 20.0
	material.initial_velocity_min = 80.0 + vel_factor * 70.0
	material.initial_velocity_max = 150.0 + vel_factor * 100.0
	material.gravity = Vector3(0, -30, 0)
	material.scale_min = 0.3 * size_scale
	material.scale_max = 0.7 * size_scale
	material.color = _colors.trail
	
	particles.process_material = material
	particles.emitting = true
	return particles

func _create_electric_arcs() -> Node2D:
	var container = Node2D.new()
	
	# 嵌套越多，电弧越多
	var arc_count = 3 + nesting_level * 2
	
	for i in range(arc_count):
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
	particles.amount = 15 + nesting_level * 5
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

## ========== 特殊效果 ==========

## 设置链接电弧效果
func _setup_chain_arcs() -> void:
	chain_arcs = Node2D.new()
	chain_arcs.name = "ChainArcs"
	add_child(chain_arcs)
	
	# 初始创建几条电弧
	_regenerate_chain_arcs()

## 重新生成链接电弧
func _regenerate_chain_arcs() -> void:
	if chain_arcs == null:
		return
	
	# 清除旧电弧
	for child in chain_arcs.get_children():
		child.queue_free()
	
	# 获取链接类型颜色
	var chain_colors = VFXManager.CHAIN_TYPE_COLORS.get(
		_chain_type,
		VFXManager.CHAIN_TYPE_COLORS[ChainActionData.ChainType.LIGHTNING]
	)
	
	# 创建2-3条随机电弧
	var arc_count = randi_range(2, 3)
	for i in range(arc_count):
		var arc = Line2D.new()
		arc.width = 1.5 * size_scale
		arc.default_color = chain_colors.primary
		arc.default_color.a = 0.8
		
		# 从中心向外的锯齿形电弧
		var points: PackedVector2Array = []
		var start_angle = randf() * TAU
		var arc_length = (15.0 + randf() * 10.0) * size_scale
		
		points.append(Vector2.ZERO)
		var segments = randi_range(3, 5)
		for j in range(segments):
			var progress = float(j + 1) / segments
			var base_pos = Vector2(cos(start_angle), sin(start_angle)) * arc_length * progress
			var offset = Vector2(randf_range(-4, 4), randf_range(-4, 4)) * size_scale
			points.append(base_pos + offset)
		
		arc.points = points
		chain_arcs.add_child(arc)

## 设置护盾覆层效果（流动蜂巢格）
func _setup_shield_overlay() -> void:
	shield_overlay = Node2D.new()
	shield_overlay.name = "ShieldOverlay"
	add_child(shield_overlay)
	
	# 创建蜂巢格护盾
	var shield_radius = 18.0 * size_scale
	var hex_count = 8
	
	for i in range(hex_count):
		var hex = Polygon2D.new()
		var hex_size = shield_radius * 0.35
		
		var points: PackedVector2Array = []
		for j in range(6):
			var angle = j * PI / 3.0
			points.append(Vector2(cos(angle), sin(angle)) * hex_size)
		
		hex.polygon = points
		hex.color = Color(0.3, 0.8, 1.0, 0.3)  # 能量盾蓝色
		
		# 环形排列
		var pos_angle = i * TAU / hex_count
		hex.position = Vector2(cos(pos_angle), sin(pos_angle)) * shield_radius * 0.65
		hex.name = "HexCell" + str(i)
		shield_overlay.add_child(hex)
	
	# 外圈光环
	var outer_ring = Polygon2D.new()
	var ring_points: PackedVector2Array = []
	for i in range(32):
		var angle = i * TAU / 32
		ring_points.append(Vector2(cos(angle), sin(angle)) * shield_radius)
	outer_ring.polygon = ring_points
	outer_ring.color = Color(0.4, 0.9, 1.0, 0.2)
	outer_ring.name = "OuterRing"
	shield_overlay.add_child(outer_ring)

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
	_animate_special_effects(delta)

func _animate_visuals(delta: float) -> void:
	# 脉动效果
	var pulse = 1.0 + 0.1 * sin(_time * _pulse_speed)
	
	if core_visual:
		core_visual.scale = Vector2.ONE * pulse
	
	if inner_core:
		inner_core.scale = Vector2.ONE * (pulse * 0.95)
	
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
	if inner_core:
		inner_core.rotation -= delta * _rotation_speed * 0.5

func _animate_liquid(delta: float) -> void:
	# 内部漩涡旋转
	for node in phase_specific_nodes:
		if node is Polygon2D:
			node.rotation += delta * _rotation_speed
	
	if inner_core:
		inner_core.rotation += delta * _rotation_speed * 1.5

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
	
	if inner_core:
		inner_core.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * size_scale

func _animate_special_effects(delta: float) -> void:
	# 链接电弧动画
	if chain_arcs:
		_arc_timer += delta
		if _arc_timer >= _arc_interval:
			_arc_timer = 0.0
			_regenerate_chain_arcs()
		
		# 电弧闪烁
		for arc in chain_arcs.get_children():
			if arc is Line2D:
				arc.modulate.a = 0.6 + 0.4 * randf()
	
	# 护盾流动动画
	if shield_overlay:
		# 蜂巢格旋转
		shield_overlay.rotation += delta * 0.5
		
		# 蜂巢格闪烁流动效果
		var hex_index = 0
		for child in shield_overlay.get_children():
			if child is Polygon2D and child.name.begins_with("HexCell"):
				var phase_offset = hex_index * TAU / 8.0
				var alpha = 0.2 + 0.15 * sin(_time * 3.0 + phase_offset)
				child.color.a = alpha
				hex_index += 1

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
