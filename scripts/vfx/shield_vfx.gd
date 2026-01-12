class_name ShieldVFX
extends Node2D
## 护盾特效
## 展示能量屏障的视觉效果，包含流动蜂巢格能量盾

signal effect_finished
signal shield_hit(damage: float)
signal shield_broken

@export var shield_type: ShieldActionData.ShieldType = ShieldActionData.ShieldType.PERSONAL
@export var shield_amount: float = 50.0
@export var shield_duration: float = 5.0
@export var shield_radius: float = 80.0

var _current_shield: float = 0.0
var _max_shield: float = 0.0
var _time_remaining: float = 0.0
var _is_active: bool = false
var _target: Node2D = null
var _time: float = 0.0

# 视觉组件
var shield_shell: Node2D
var energy_flow: Node2D
var hit_effect: Node2D
var ambient_particles: GPUParticles2D
var honeycomb_cells: Array[Polygon2D] = []

# 颜色配置（护盾使用能量蓝色调）
var _colors: Dictionary = {
	"primary": Color(0.3, 0.7, 1.0, 0.6),
	"secondary": Color(0.6, 0.9, 1.0, 0.8),
	"glow": Color(0.4, 0.8, 1.0, 0.4),
	"honeycomb": Color(0.2, 0.8, 1.0, 0.5),
	"honeycomb_active": Color(0.5, 1.0, 1.0, 0.8),
}

func _ready() -> void:
	pass

func initialize(p_type: ShieldActionData.ShieldType, p_amount: float = 50.0, p_duration: float = 5.0, p_radius: float = 80.0, target: Node2D = null) -> void:
	shield_type = p_type
	shield_amount = p_amount
	_max_shield = p_amount
	_current_shield = p_amount
	shield_duration = p_duration
	shield_radius = p_radius
	_time_remaining = shield_duration
	_target = target
	
	_setup_visuals()
	_play_spawn_animation()
	_is_active = true

func _setup_visuals() -> void:
	match shield_type:
		ShieldActionData.ShieldType.PERSONAL:
			_setup_personal_shield()
		ShieldActionData.ShieldType.AREA:
			_setup_area_shield()
		ShieldActionData.ShieldType.PROJECTILE:
			_setup_projectile_shield()

## ========== 个人护盾（流动蜂巢格） ==========
func _setup_personal_shield() -> void:
	# 护盾外壳 - 蜂巢格结构
	shield_shell = _create_honeycomb_shell(35.0)
	add_child(shield_shell)
	
	# 能量流动线
	energy_flow = _create_energy_flow_network()
	add_child(energy_flow)
	
	# 外圈光环
	var outer_glow = _create_outer_glow_ring(40.0)
	add_child(outer_glow)
	
	# 环境粒子
	ambient_particles = _create_shield_particles(40.0)
	add_child(ambient_particles)

func _create_honeycomb_shell(radius: float) -> Node2D:
	var container = Node2D.new()
	honeycomb_cells.clear()
	
	# 创建蜂巢格网络
	# 中心六边形
	var center_hex = _create_hexagon(radius * 0.35)
	center_hex.color = _colors.honeycomb
	center_hex.name = "CenterHex"
	container.add_child(center_hex)
	honeycomb_cells.append(center_hex)
	
	# 第一环：6个六边形
	var ring1_count = 6
	for i in range(ring1_count):
		var hex = _create_hexagon(radius * 0.3)
		var angle = i * TAU / ring1_count
		hex.position = Vector2(cos(angle), sin(angle)) * radius * 0.55
		hex.color = _colors.honeycomb
		hex.name = "Ring1Hex" + str(i)
		container.add_child(hex)
		honeycomb_cells.append(hex)
	
	# 第二环：12个六边形
	var ring2_count = 12
	for i in range(ring2_count):
		var hex = _create_hexagon(radius * 0.25)
		var angle = i * TAU / ring2_count + PI / 12.0
		hex.position = Vector2(cos(angle), sin(angle)) * radius * 0.85
		hex.color = _colors.honeycomb
		hex.color.a = 0.4
		hex.name = "Ring2Hex" + str(i)
		container.add_child(hex)
		honeycomb_cells.append(hex)
	
	return container

func _create_hexagon(size: float) -> Polygon2D:
	var hex = Polygon2D.new()
	var points: PackedVector2Array = []
	
	for i in range(6):
		var angle = i * PI / 3.0 - PI / 6.0
		points.append(Vector2(cos(angle), sin(angle)) * size)
	
	hex.polygon = points
	return hex

func _create_energy_flow_network() -> Node2D:
	var container = Node2D.new()
	
	# 从中心向外的能量线
	for i in range(6):
		var line = Line2D.new()
		line.width = 2.0
		line.default_color = _colors.secondary
		line.default_color.a = 0.6
		
		var angle = i * PI / 3.0
		var start = Vector2(cos(angle), sin(angle)) * 8.0
		var end = Vector2(cos(angle), sin(angle)) * 32.0
		
		line.points = PackedVector2Array([start, end])
		line.name = "FlowLine" + str(i)
		container.add_child(line)
	
	# 环形连接线
	var ring_line = Line2D.new()
	ring_line.width = 1.5
	ring_line.default_color = _colors.secondary
	ring_line.default_color.a = 0.4
	
	var ring_points: PackedVector2Array = []
	for i in range(25):
		var angle = i * TAU / 24
		ring_points.append(Vector2(cos(angle), sin(angle)) * 20.0)
	ring_line.points = ring_points
	ring_line.name = "RingLine"
	container.add_child(ring_line)
	
	return container

func _create_outer_glow_ring(radius: float) -> Polygon2D:
	var ring = Polygon2D.new()
	var points: PackedVector2Array = []
	var segments = 32
	
	for i in range(segments + 1):
		var angle = i * TAU / segments
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	
	ring.polygon = points
	ring.color = _colors.glow
	ring.color.a = 0.2
	ring.name = "OuterGlow"
	return ring

func _create_shield_particles(radius: float) -> GPUParticles2D:
	var particles = GPUParticles2D.new()
	particles.amount = 25
	particles.lifetime = 1.2
	particles.explosiveness = 0.0
	
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, 0, 0)
	material.spread = 180.0
	material.initial_velocity_min = 5.0
	material.initial_velocity_max = 15.0
	material.gravity = Vector3(0, 0, 0)
	material.scale_min = 0.15
	material.scale_max = 0.35
	material.color = _colors.honeycomb_active
	
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE_SURFACE
	material.emission_sphere_radius = radius
	
	particles.process_material = material
	particles.emitting = true
	return particles

## ========== 范围护盾 ==========
func _setup_area_shield() -> void:
	# 大型穹顶护盾
	shield_shell = _create_dome_shield()
	add_child(shield_shell)
	
	# 地面法阵
	var ground_circle = _create_ground_circle()
	add_child(ground_circle)
	
	# 蜂巢格覆层
	var honeycomb_overlay = _create_dome_honeycomb()
	add_child(honeycomb_overlay)
	
	# 环境粒子
	ambient_particles = _create_shield_particles(shield_radius)
	add_child(ambient_particles)

func _create_dome_shield() -> Node2D:
	var container = Node2D.new()
	
	# 穹顶轮廓
	var dome = Polygon2D.new()
	var points: PackedVector2Array = []
	var segments = 48
	
	for i in range(segments + 1):
		var angle = i * TAU / segments
		points.append(Vector2(cos(angle), sin(angle)) * shield_radius)
	
	dome.polygon = points
	dome.color = _colors.primary
	dome.color.a = 0.25
	container.add_child(dome)
	
	# 能量网格线
	for i in range(8):
		var line = Line2D.new()
		line.width = 1.5
		line.default_color = _colors.secondary
		line.default_color.a = 0.4
		
		var angle = i * PI / 4.0
		var points_line: PackedVector2Array = []
		points_line.append(Vector2.ZERO)
		points_line.append(Vector2(cos(angle), sin(angle)) * shield_radius)
		line.points = points_line
		container.add_child(line)
	
	return container

func _create_dome_honeycomb() -> Node2D:
	var container = Node2D.new()
	honeycomb_cells.clear()
	
	# 在穹顶上分布蜂巢格
	var hex_size = shield_radius * 0.15
	var rings = 3
	
	for ring in range(rings):
		var ring_radius = shield_radius * (0.3 + ring * 0.25)
		var hex_count = 6 + ring * 6
		
		for i in range(hex_count):
			var hex = _create_hexagon(hex_size * (1.0 - ring * 0.1))
			var angle = i * TAU / hex_count + ring * PI / hex_count
			hex.position = Vector2(cos(angle), sin(angle)) * ring_radius
			hex.color = _colors.honeycomb
			hex.color.a = 0.3 - ring * 0.05
			hex.name = "DomeHex_" + str(ring) + "_" + str(i)
			container.add_child(hex)
			honeycomb_cells.append(hex)
	
	return container

func _create_ground_circle() -> Polygon2D:
	var circle = Polygon2D.new()
	var points: PackedVector2Array = []
	var segments = 32
	
	for i in range(segments + 1):
		var angle = i * TAU / segments
		points.append(Vector2(cos(angle), sin(angle)) * shield_radius)
	
	circle.polygon = points
	circle.color = _colors.glow
	circle.color.a = 0.15
	return circle

## ========== 弹幕护盾（投掷物护盾） ==========
func _setup_projectile_shield() -> void:
	# 紧凑的旋转蜂巢护盾
	shield_shell = _create_compact_honeycomb_shield()
	add_child(shield_shell)
	
	# 能量轨道
	energy_flow = _create_orbit_energy()
	add_child(energy_flow)

func _create_compact_honeycomb_shield() -> Node2D:
	var container = Node2D.new()
	honeycomb_cells.clear()
	
	# 小型蜂巢格环绕
	var hex_count = 6
	var ring_radius = shield_radius * 0.7
	var hex_size = shield_radius * 0.4
	
	for i in range(hex_count):
		var hex = _create_hexagon(hex_size)
		var angle = i * TAU / hex_count
		hex.position = Vector2(cos(angle), sin(angle)) * ring_radius
		hex.color = _colors.honeycomb
		hex.name = "CompactHex" + str(i)
		container.add_child(hex)
		honeycomb_cells.append(hex)
	
	# 中心小六边形
	var center = _create_hexagon(hex_size * 0.6)
	center.color = _colors.honeycomb_active
	center.color.a = 0.6
	center.name = "CenterCompact"
	container.add_child(center)
	honeycomb_cells.append(center)
	
	return container

func _create_orbit_energy() -> Node2D:
	var container = Node2D.new()
	
	# 轨道环
	var orbit = Polygon2D.new()
	var points: PackedVector2Array = []
	var segments = 32
	var radius = shield_radius * 0.7
	
	for i in range(segments + 1):
		var angle = i * TAU / segments
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	
	orbit.polygon = points
	orbit.color = _colors.glow
	orbit.color.a = 0.25
	container.add_child(orbit)
	
	# 能量点
	for i in range(3):
		var dot = Polygon2D.new()
		var dot_points: PackedVector2Array = []
		for j in range(8):
			var angle = j * TAU / 8
			dot_points.append(Vector2(cos(angle), sin(angle)) * 3.0)
		dot.polygon = dot_points
		dot.color = _colors.honeycomb_active
		dot.name = "EnergyDot" + str(i)
		container.add_child(dot)
	
	return container

## ========== 动画 ==========
func _play_spawn_animation() -> void:
	var tween = create_tween()
	
	# 护盾展开
	if shield_shell:
		shield_shell.scale = Vector2.ZERO
		shield_shell.modulate.a = 0.0
		tween.tween_property(shield_shell, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(shield_shell, "modulate:a", 1.0, 0.3)
	
	# 能量流动显示
	if energy_flow:
		energy_flow.modulate.a = 0.0
		tween.parallel().tween_property(energy_flow, "modulate:a", 1.0, 0.4).set_delay(0.1)

func _process(delta: float) -> void:
	if not _is_active:
		return
	
	_time += delta
	_time_remaining -= delta
	
	# 跟随目标
	if _target and is_instance_valid(_target):
		global_position = _target.global_position
	
	# 动画更新
	_update_animations(delta)
	_update_honeycomb_flow(delta)
	
	# 检查是否结束
	if _time_remaining <= 0 or _current_shield <= 0:
		_play_break_animation()

func _update_animations(delta: float) -> void:
	# 弹幕护盾旋转
	if shield_type == ShieldActionData.ShieldType.PROJECTILE and shield_shell:
		shield_shell.rotation += delta * 2.0
		
		# 更新能量点位置
		if energy_flow:
			for i in range(energy_flow.get_child_count()):
				var child = energy_flow.get_child(i)
				if child.name.begins_with("EnergyDot"):
					var dot_index = int(child.name.replace("EnergyDot", ""))
					var angle = _time * 3.0 + dot_index * TAU / 3.0
					var radius = shield_radius * 0.7
					child.position = Vector2(cos(angle), sin(angle)) * radius
	
	# 能量流动动画
	if energy_flow:
		for child in energy_flow.get_children():
			if child is Line2D:
				child.modulate.a = 0.3 + 0.2 * sin(_time * 4.0)
	
	# 护盾强度视觉反馈
	var shield_ratio = _current_shield / _max_shield
	if shield_shell:
		shield_shell.modulate.a = 0.5 + shield_ratio * 0.5

## 更新蜂巢格流动效果
func _update_honeycomb_flow(delta: float) -> void:
	var cell_count = honeycomb_cells.size()
	if cell_count == 0:
		return
	
	# 波浪式流动效果
	for i in range(cell_count):
		var cell = honeycomb_cells[i]
		if not is_instance_valid(cell):
			continue
		
		# 计算该格子的相位偏移
		var phase_offset = float(i) / cell_count * TAU
		
		# 基于时间的亮度波动
		var wave = sin(_time * 3.0 + phase_offset)
		var base_alpha = 0.3
		var wave_alpha = 0.25
		
		# 根据护盾类型调整效果
		match shield_type:
			ShieldActionData.ShieldType.PERSONAL:
				# 从中心向外扩散的波
				var dist_factor = cell.position.length() / 40.0
				wave = sin(_time * 4.0 - dist_factor * 2.0)
				base_alpha = 0.35
				wave_alpha = 0.3
			
			ShieldActionData.ShieldType.AREA:
				# 螺旋式流动
				var angle = atan2(cell.position.y, cell.position.x)
				wave = sin(_time * 2.5 + angle * 2.0)
				base_alpha = 0.25
				wave_alpha = 0.2
			
			ShieldActionData.ShieldType.PROJECTILE:
				# 快速脉冲
				wave = sin(_time * 6.0 + phase_offset)
				base_alpha = 0.4
				wave_alpha = 0.35
		
		# 应用颜色变化
		var target_alpha = base_alpha + wave_alpha * (wave * 0.5 + 0.5)
		cell.color.a = lerpf(cell.color.a, target_alpha, delta * 8.0)
		
		# 颜色在基础色和激活色之间渐变
		var color_blend = (wave * 0.5 + 0.5)
		cell.color = _colors.honeycomb.lerp(_colors.honeycomb_active, color_blend * 0.5)
		cell.color.a = target_alpha

## 受击效果
func take_damage(damage: float) -> float:
	var absorbed = minf(damage, _current_shield)
	_current_shield -= absorbed
	
	_play_hit_effect()
	shield_hit.emit(absorbed)
	
	if _current_shield <= 0:
		shield_broken.emit()
	
	return damage - absorbed

func _play_hit_effect() -> void:
	# 受击闪烁
	var tween = create_tween()
	tween.tween_property(shield_shell, "modulate", Color(1.5, 1.5, 1.5, 1.0), 0.05)
	tween.tween_property(shield_shell, "modulate", Color.WHITE, 0.1)
	
	# 蜂巢格闪烁
	for cell in honeycomb_cells:
		if is_instance_valid(cell):
			cell.color = _colors.honeycomb_active
			cell.color.a = 0.9
	
	# 涟漪效果
	var ripple = Polygon2D.new()
	var points: PackedVector2Array = []
	var segments = 24
	var radius = 10.0
	
	for i in range(segments + 1):
		var angle = i * TAU / segments
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	
	ripple.polygon = points
	ripple.color = _colors.honeycomb_active
	add_child(ripple)
	
	var ripple_tween = create_tween()
	ripple_tween.tween_property(ripple, "scale", Vector2.ONE * 4.0, 0.2).set_ease(Tween.EASE_OUT)
	ripple_tween.parallel().tween_property(ripple, "modulate:a", 0.0, 0.2)
	ripple_tween.tween_callback(ripple.queue_free)

func _play_break_animation() -> void:
	_is_active = false
	
	if ambient_particles:
		ambient_particles.emitting = false
	
	var tween = create_tween()
	
	# 蜂巢格碎裂飞散
	for cell in honeycomb_cells:
		if not is_instance_valid(cell):
			continue
		
		var direction = cell.position.normalized() if cell.position.length() > 0 else Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		var target_pos = cell.position + direction * 60.0
		
		tween.parallel().tween_property(cell, "position", target_pos, 0.4).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(cell, "modulate:a", 0.0, 0.4)
		tween.parallel().tween_property(cell, "rotation", cell.rotation + randf_range(-PI, PI), 0.4)
		tween.parallel().tween_property(cell, "scale", Vector2.ONE * 0.3, 0.4)
	
	# 护盾外壳淡出
	if shield_shell:
		tween.parallel().tween_property(shield_shell, "modulate:a", 0.0, 0.3)
	
	tween.tween_callback(_finish_effect)

func stop() -> void:
	_current_shield = 0

func _finish_effect() -> void:
	effect_finished.emit()
	queue_free()
