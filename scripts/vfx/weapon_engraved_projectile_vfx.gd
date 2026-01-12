class_name WeaponEngravedProjectileVFX
extends Node2D
## 武器刻录法术投掷物视觉特效
## 专为武器刻录触发的法术设计，具有独特的"武器附魔"风格
## 复用 PhaseProjectileVFX 的渐变色、嵌套增强等设计逻辑

signal effect_finished

@export var phase: CarrierConfigData.Phase = CarrierConfigData.Phase.SOLID
@export var size_scale: float = 1.0
@export var velocity: Vector2 = Vector2.ZERO

# 武器刻录特有属性
var weapon_type: int = 0  # WeaponData.WeaponType
var trigger_type: int = 0  # TriggerData.TriggerType
var is_critical: bool = false  # 是否暴击触发

# 法术数据和嵌套层级（复用）
var spell_data: SpellCoreData = null
var nesting_level: int = 0

# 嵌套颜色链
var _nested_colors: Array[Color] = []

# 视觉组件
var blade_core: Node2D = null         # 刀刃形核心
var enchant_aura: Node2D = null       # 附魔光环
var weapon_trail: Line2D = null       # 武器轨迹拖尾
var inner_trail: Line2D = null        # 内层拖尾
var rune_particles: GPUParticles2D = null  # 符文粒子
var impact_sparks: Node2D = null      # 冲击火花

# 特殊效果组件
var chain_arcs: Node2D = null
var shield_overlay: Node2D = null

# 拖尾历史
var _trail_points: Array[Vector2] = []
const BASE_TRAIL_POINTS = 12
const TRAIL_POINT_DISTANCE = 6.0

# 动画参数
var _time: float = 0.0
var _pulse_speed: float = 3.0
var _rotation_speed: float = 2.0
var _arc_timer: float = 0.0
var _arc_interval: float = 0.12

# 颜色配置
var _color_outer: Color = Color.WHITE
var _color_middle: Color = Color.WHITE
var _color_inner: Color = Color.WHITE
var _color_core: Color = Color.WHITE
var _color_trail: Color = Color.WHITE
var _color_weapon_accent: Color = Color.WHITE  # 武器强调色
var _status_color: Color = Color.TRANSPARENT

# 嵌套增强参数
var _nesting_brightness: float = 1.0
var _nesting_saturation: float = 1.0
var _trail_length_bonus: int = 0

# 特殊效果标志
var _has_chain_effect: bool = false
var _has_shield_effect: bool = false
var _chain_type: int = 0

const MAX_NESTING_VISUAL_LEVEL = 4

func _ready() -> void:
	_setup_visuals()

## 标准初始化
func initialize(p_phase: CarrierConfigData.Phase, p_size: float = 1.0, p_velocity: Vector2 = Vector2.ZERO) -> void:
	phase = p_phase
	size_scale = p_size
	velocity = p_velocity
	_calculate_nesting_params()
	_setup_colors()
	_setup_visuals()

## 武器刻录增强初始化
func initialize_weapon_engraved(
	p_spell_data: SpellCoreData,
	p_weapon_type: int,
	p_trigger_type: int,
	p_nesting_level: int = 0,
	p_velocity: Vector2 = Vector2.ZERO,
	p_is_critical: bool = false
) -> void:
	spell_data = p_spell_data
	weapon_type = p_weapon_type
	trigger_type = p_trigger_type
	nesting_level = p_nesting_level
	velocity = p_velocity
	is_critical = p_is_critical
	
	if spell_data and spell_data.carrier:
		phase = spell_data.carrier.phase
		size_scale = spell_data.carrier.size
	
	_analyze_spell_effects()
	_collect_nested_colors()
	_calculate_nesting_params()
	_setup_colors()
	_setup_visuals()

## 计算嵌套增强参数
func _calculate_nesting_params() -> void:
	var effective_level = mini(nesting_level, MAX_NESTING_VISUAL_LEVEL)
	_nesting_brightness = 1.0 + effective_level * 0.075
	_nesting_saturation = 1.0 + effective_level * 0.05
	_trail_length_bonus = effective_level
	
	# 暴击时额外增强
	if is_critical:
		_nesting_brightness *= 1.15
		_nesting_saturation *= 1.1

## 收集嵌套颜色链
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
						_collect_colors_recursive(child_spell, depth + 1)

## 设置颜色（武器刻录专用配色）
func _setup_colors() -> void:
	# 基于相态的基础色调（与普通投掷物相同）
	match phase:
		CarrierConfigData.Phase.SOLID:
			_color_outer = Color(0.95, 0.6, 0.2, 0.12)
			_color_middle = Color(0.9, 0.5, 0.15, 0.35)
			_color_inner = Color(1.0, 0.7, 0.3, 0.65)
			_color_core = Color(1.0, 0.95, 0.8, 1.0)
			_color_trail = Color(0.95, 0.6, 0.2, 0.55)
		
		CarrierConfigData.Phase.LIQUID:
			_color_outer = Color(0.2, 0.7, 0.95, 0.12)
			_color_middle = Color(0.15, 0.6, 0.9, 0.35)
			_color_inner = Color(0.3, 0.8, 1.0, 0.65)
			_color_core = Color(0.85, 0.95, 1.0, 1.0)
			_color_trail = Color(0.2, 0.7, 0.95, 0.55)
		
		CarrierConfigData.Phase.PLASMA:
			_color_outer = Color(0.9, 0.2, 0.7, 0.12)
			_color_middle = Color(0.85, 0.15, 0.6, 0.35)
			_color_inner = Color(1.0, 0.4, 0.8, 0.65)
			_color_core = Color(1.0, 0.9, 0.95, 1.0)
			_color_trail = Color(0.9, 0.3, 0.7, 0.55)
	
	# 武器强调色（根据武器类型）
	_color_weapon_accent = _get_weapon_accent_color()
	
	# 混合武器强调色到中层
	_color_middle = _color_middle.lerp(_color_weapon_accent, 0.25)
	
	# 应用嵌套增强
	if nesting_level > 0:
		_color_inner = _enhance_color(_color_inner)
		_color_core = _enhance_color(_color_core)
		_color_trail = _enhance_color(_color_trail)
	
	# 状态效果混合
	if _status_color != Color.TRANSPARENT:
		_color_middle = _color_middle.lerp(_status_color, 0.3)
		_color_trail = _color_trail.lerp(_status_color, 0.25)

## 获取武器强调色
func _get_weapon_accent_color() -> Color:
	# 根据武器类型返回不同的金属质感强调色
	match weapon_type:
		0:  # UNARMED - 无武器，使用拳头的力量感
			return Color(0.9, 0.85, 0.7, 0.6)  # 淡金色
		1:  # SWORD - 银白剑光
			return Color(0.85, 0.9, 1.0, 0.6)
		2:  # GREATSWORD - 厚重钢铁
			return Color(0.7, 0.75, 0.85, 0.6)
		3:  # DAGGER - 锐利银光
			return Color(0.9, 0.95, 1.0, 0.7)
		4:  # SPEAR - 青铜枪尖
			return Color(0.8, 0.7, 0.5, 0.6)
		5:  # DUAL_BLADE - 双刃交错
			return Color(0.85, 0.85, 0.95, 0.65)
		6:  # STAFF - 魔法紫光
			return Color(0.7, 0.5, 0.9, 0.6)
		_:
			return Color(0.8, 0.8, 0.85, 0.6)

## 增强颜色
func _enhance_color(color: Color) -> Color:
	var h = color.h
	var s = minf(color.s * _nesting_saturation, 1.0)
	var v = minf(color.v * _nesting_brightness, 1.0)
	return Color.from_hsv(h, s, v, color.a)

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
	
	# 刀刃形核心（武器刻录特有）
	_setup_blade_core()
	
	# 附魔光环
	_setup_enchant_aura()
	
	# 嵌套光晕
	if _nested_colors.size() > 0:
		_setup_nested_glow()
	
	# 武器轨迹拖尾
	_setup_weapon_trail()
	
	# 符文粒子
	_setup_rune_particles()
	
	# 特殊效果
	if _has_chain_effect:
		_setup_chain_arcs()
	
	if _has_shield_effect:
		_setup_shield_overlay()

func _clear_visuals() -> void:
	if blade_core:
		blade_core.queue_free()
		blade_core = null
	if enchant_aura:
		enchant_aura.queue_free()
		enchant_aura = null
	if weapon_trail:
		weapon_trail.queue_free()
		weapon_trail = null
	if inner_trail:
		inner_trail.queue_free()
		inner_trail = null
	if rune_particles:
		rune_particles.queue_free()
		rune_particles = null
	if impact_sparks:
		impact_sparks.queue_free()
		impact_sparks = null
	if chain_arcs:
		chain_arcs.queue_free()
		chain_arcs = null
	if shield_overlay:
		shield_overlay.queue_free()
		shield_overlay = null

## ========== 刀刃形核心（武器刻录特有） ==========
func _setup_blade_core() -> void:
	blade_core = Node2D.new()
	var base_size = 10.0 * size_scale
	
	# 外层光晕（椭圆形，模拟刀刃轨迹）
	var outer_glow = _create_blade_shape(base_size * 2.5, base_size * 1.2, _color_outer)
	blade_core.add_child(outer_glow)
	
	# 中层刀刃能量
	var middle_blade = _create_blade_shape(base_size * 1.8, base_size * 0.8, _color_middle)
	blade_core.add_child(middle_blade)
	
	# 内层刀刃核心
	var inner_blade = _create_blade_shape(base_size * 1.2, base_size * 0.5, _color_inner)
	blade_core.add_child(inner_blade)
	
	# 最内核心（刀尖高光）
	var core_tip = _create_blade_tip(base_size * 0.8, _color_core)
	blade_core.add_child(core_tip)
	
	# 武器强调线（金属质感）
	var accent_line = _create_accent_line(base_size * 1.5)
	blade_core.add_child(accent_line)
	
	add_child(blade_core)

## 创建刀刃形状（菱形/梭形）
func _create_blade_shape(length: float, width: float, color: Color) -> Polygon2D:
	var shape = Polygon2D.new()
	var points: PackedVector2Array = []
	
	# 菱形/梭形：前尖后钝
	points.append(Vector2(length * 0.6, 0))           # 前端尖点
	points.append(Vector2(0, width * 0.5))            # 上侧
	points.append(Vector2(-length * 0.4, 0))          # 后端
	points.append(Vector2(0, -width * 0.5))           # 下侧
	
	shape.polygon = points
	shape.color = color
	return shape

## 创建刀尖高光
func _create_blade_tip(size: float, color: Color) -> Polygon2D:
	var tip = Polygon2D.new()
	var points: PackedVector2Array = []
	
	# 三角形尖端
	points.append(Vector2(size * 0.5, 0))
	points.append(Vector2(-size * 0.2, size * 0.2))
	points.append(Vector2(-size * 0.2, -size * 0.2))
	
	tip.polygon = points
	tip.color = color
	return tip

## 创建武器强调线
func _create_accent_line(length: float) -> Line2D:
	var line = Line2D.new()
	line.width = 1.5 * size_scale
	line.default_color = _color_weapon_accent
	line.points = PackedVector2Array([
		Vector2(-length * 0.3, 0),
		Vector2(length * 0.5, 0)
	])
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.antialiased = true
	return line

## ========== 附魔光环 ==========
func _setup_enchant_aura() -> void:
	enchant_aura = Node2D.new()
	var base_size = 12.0 * size_scale
	
	# 旋转的符文环
	var rune_ring = _create_rune_ring(base_size)
	enchant_aura.add_child(rune_ring)
	
	# 外层能量场
	var energy_field = _create_smooth_polygon(base_size * 1.8, 12, _color_outer)
	energy_field.color.a = 0.1
	enchant_aura.add_child(energy_field)
	
	add_child(enchant_aura)

## 创建符文环
func _create_rune_ring(radius: float) -> Node2D:
	var container = Node2D.new()
	
	# 4-6个符文标记点
	var rune_count = 4 + mini(nesting_level, 2)
	for i in range(rune_count):
		var rune = Polygon2D.new()
		var rune_size = 2.5 * size_scale
		
		# 小菱形符文
		var points: PackedVector2Array = []
		points.append(Vector2(rune_size, 0))
		points.append(Vector2(0, rune_size * 0.6))
		points.append(Vector2(-rune_size, 0))
		points.append(Vector2(0, -rune_size * 0.6))
		
		rune.polygon = points
		rune.color = _color_weapon_accent
		rune.color.a = 0.6
		
		var angle = i * TAU / rune_count
		rune.position = Vector2(cos(angle), sin(angle)) * radius
		rune.rotation = angle
		container.add_child(rune)
	
	return container

## ========== 嵌套光晕 ==========
func _setup_nested_glow() -> void:
	var nested_glow = Node2D.new()
	var base_size = 8.0 * size_scale
	
	var blended_color = _blend_nested_colors()
	var glow = _create_smooth_polygon(base_size * 1.2, 12, blended_color)
	glow.color.a = 0.25 + mini(nesting_level, 3) * 0.05
	nested_glow.add_child(glow)
	
	add_child(nested_glow)

## 混合嵌套颜色
func _blend_nested_colors() -> Color:
	if _nested_colors.is_empty():
		return _color_inner
	
	var result = Color(0, 0, 0, 0)
	var total_weight = 0.0
	
	for i in range(_nested_colors.size()):
		var weight = 1.0 / (i + 1)
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

## ========== 武器轨迹拖尾 ==========
func _setup_weapon_trail() -> void:
	# 主拖尾（更锐利的刀刃轨迹）
	weapon_trail = Line2D.new()
	weapon_trail.width = 8.0 * size_scale
	weapon_trail.width_curve = _create_blade_trail_curve()
	weapon_trail.default_color = _color_trail
	weapon_trail.gradient = _create_trail_gradient()
	weapon_trail.joint_mode = Line2D.LINE_JOINT_BEVEL  # 斜角连接，更锐利
	weapon_trail.begin_cap_mode = Line2D.LINE_CAP_NONE
	weapon_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	weapon_trail.antialiased = true
	add_child(weapon_trail)
	weapon_trail.top_level = true
	
	# 嵌套内层拖尾
	if _nested_colors.size() > 0:
		inner_trail = Line2D.new()
		inner_trail.width = 4.0 * size_scale
		inner_trail.width_curve = _create_blade_trail_curve()
		inner_trail.default_color = _blend_nested_colors()
		inner_trail.gradient = _create_inner_trail_gradient()
		inner_trail.joint_mode = Line2D.LINE_JOINT_BEVEL
		inner_trail.begin_cap_mode = Line2D.LINE_CAP_NONE
		inner_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
		inner_trail.antialiased = true
		add_child(inner_trail)
		inner_trail.top_level = true

## 刀刃轨迹宽度曲线（更锐利的起点）
func _create_blade_trail_curve() -> Curve:
	var curve = Curve.new()
	curve.add_point(Vector2(0.0, 0.3))    # 起点较窄（刀尖）
	curve.add_point(Vector2(0.15, 1.0))   # 快速展开到最宽
	curve.add_point(Vector2(0.4, 0.8))
	curve.add_point(Vector2(0.7, 0.5))
	curve.add_point(Vector2(1.0, 0.1))    # 尾端收细
	return curve

func _create_trail_gradient() -> Gradient:
	var gradient = Gradient.new()
	gradient.set_color(0, Color(_color_core.r, _color_core.g, _color_core.b, 0.9))
	gradient.add_point(0.2, Color(_color_inner.r, _color_inner.g, _color_inner.b, 0.7))
	gradient.add_point(0.5, Color(_color_middle.r, _color_middle.g, _color_middle.b, 0.5))
	gradient.set_color(1, Color(_color_outer.r, _color_outer.g, _color_outer.b, 0.0))
	return gradient

func _create_inner_trail_gradient() -> Gradient:
	var gradient = Gradient.new()
	var blended = _blend_nested_colors()
	gradient.set_color(0, Color(blended.r, blended.g, blended.b, 0.7))
	gradient.add_point(0.4, Color(blended.r, blended.g, blended.b, 0.4))
	gradient.set_color(1, Color(blended.r, blended.g, blended.b, 0.0))
	return gradient

## ========== 符文粒子 ==========
func _setup_rune_particles() -> void:
	rune_particles = GPUParticles2D.new()
	rune_particles.amount = 6  # 固定数量
	rune_particles.lifetime = 0.5
	rune_particles.explosiveness = 0.0
	rune_particles.randomness = 0.4
	
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(-1, 0, 0)  # 向后发射
	material.spread = 30.0
	material.initial_velocity_min = 30.0
	material.initial_velocity_max = 60.0
	material.gravity = Vector3(0, 0, 0)
	material.scale_min = 0.15 * size_scale
	material.scale_max = 0.3 * size_scale
	material.color = _color_weapon_accent
	
	rune_particles.process_material = material
	rune_particles.emitting = true
	add_child(rune_particles)

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
	
	var shield_radius = 14.0 * size_scale
	var hex_count = 5
	
	for i in range(hex_count):
		var hex = Polygon2D.new()
		var hex_size = shield_radius * 0.3
		
		var points: PackedVector2Array = []
		for j in range(6):
			var angle = j * PI / 3.0
			points.append(Vector2(cos(angle), sin(angle)) * hex_size)
		
		hex.polygon = points
		hex.color = Color(0.3, 0.8, 1.0, 0.2)
		
		var pos_angle = i * TAU / hex_count
		hex.position = Vector2(cos(pos_angle), sin(pos_angle)) * shield_radius * 0.6
		hex.name = "HexCell" + str(i)
		shield_overlay.add_child(hex)

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

## ========== 动画更新 ==========
func _process(delta: float) -> void:
	_time += delta
	_update_trail()
	_animate_visuals(delta)
	_animate_special_effects(delta)

func _update_trail() -> void:
	if weapon_trail == null:
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
		weapon_trail.points = PackedVector2Array(_trail_points)
		if inner_trail:
			inner_trail.points = PackedVector2Array(_trail_points)
	else:
		weapon_trail.points = PackedVector2Array()
		if inner_trail:
			inner_trail.points = PackedVector2Array()

func _animate_visuals(delta: float) -> void:
	var pulse = 1.0 + 0.06 * sin(_time * _pulse_speed)
	var pulse_fast = 1.0 + 0.04 * sin(_time * _pulse_speed * 2.5)
	
	# 刀刃核心脉动
	if blade_core:
		blade_core.scale = Vector2.ONE * pulse_fast
		# 根据速度方向旋转刀刃
		if velocity.length_squared() > 1.0:
			blade_core.rotation = velocity.angle()
	
	# 附魔光环旋转
	if enchant_aura:
		enchant_aura.rotation += delta * _rotation_speed
		enchant_aura.scale = Vector2.ONE * pulse

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
		shield_overlay.rotation += delta * 0.5
		
		var hex_index = 0
		for child in shield_overlay.get_children():
			if child is Polygon2D and child.name.begins_with("HexCell"):
				var phase_offset = hex_index * TAU / 5.0
				var alpha = 0.12 + 0.1 * sin(_time * 2.5 + phase_offset)
				child.color.a = alpha
				hex_index += 1

func update_velocity(new_velocity: Vector2) -> void:
	velocity = new_velocity

func stop() -> void:
	if rune_particles:
		rune_particles.emitting = false
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)
	tween.tween_callback(func(): effect_finished.emit())
