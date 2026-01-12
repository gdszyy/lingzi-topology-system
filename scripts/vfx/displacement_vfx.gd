class_name DisplacementVFX
extends Node2D
## 位移特效
## 展示击退、吸引、传送等位移效果

signal effect_finished

@export var displacement_type: DisplacementActionData.DisplacementType = DisplacementActionData.DisplacementType.KNOCKBACK
@export var from_position: Vector2 = Vector2.ZERO
@export var to_position: Vector2 = Vector2.ZERO
@export var displacement_force: float = 300.0

var _colors: Dictionary = {
	"primary": Color(0.9, 0.7, 0.3, 0.8),
	"secondary": Color(1.0, 0.9, 0.5, 1.0),
	"glow": Color(0.95, 0.8, 0.4, 0.5),
}

# 视觉组件
var force_indicator: Node2D
var motion_trail: Node2D
var impact_effect: Node2D

func _ready() -> void:
	pass

func initialize(p_type: DisplacementActionData.DisplacementType, p_from: Vector2, p_to: Vector2, p_force: float = 300.0) -> void:
	displacement_type = p_type
	from_position = p_from
	to_position = p_to
	displacement_force = p_force
	
	global_position = from_position
	
	_setup_visuals()
	_play_displacement_effect()

func _setup_visuals() -> void:
	match displacement_type:
		DisplacementActionData.DisplacementType.KNOCKBACK:
			_setup_knockback_visuals()
		DisplacementActionData.DisplacementType.PULL:
			_setup_pull_visuals()
		DisplacementActionData.DisplacementType.TELEPORT:
			_setup_teleport_visuals()
		DisplacementActionData.DisplacementType.LAUNCH:
			_setup_launch_visuals()
		DisplacementActionData.DisplacementType.DASH:
			_setup_dash_visuals()

## ========== 击退效果 ==========
func _setup_knockback_visuals() -> void:
	var direction = (to_position - from_position).normalized()
	
	# 力场波纹
	force_indicator = _create_force_wave(direction)
	add_child(force_indicator)
	
	# 运动轨迹
	motion_trail = _create_motion_blur(from_position, to_position)
	add_child(motion_trail)

func _create_force_wave(direction: Vector2) -> Node2D:
	var container = Node2D.new()
	
	# 冲击波弧
	for i in range(3):
		var wave = Polygon2D.new()
		var points: PackedVector2Array = []
		var arc_radius = 20.0 + i * 15.0
		var arc_angle = PI / 3.0
		var segments = 12
		
		for j in range(segments + 1):
			var angle = -arc_angle / 2.0 + j * arc_angle / segments
			points.append(Vector2(cos(angle), sin(angle)) * arc_radius)
		
		wave.polygon = points
		wave.color = _colors.primary
		wave.color.a = 0.6 - i * 0.15
		wave.rotation = direction.angle()
		wave.name = "Wave" + str(i)
		container.add_child(wave)
	
	return container

func _create_motion_blur(from_pos: Vector2, to_pos: Vector2) -> Node2D:
	var container = Node2D.new()
	
	var direction = to_pos - from_pos
	var distance = direction.length()
	
	# 运动模糊线条
	for i in range(5):
		var line = Line2D.new()
		line.width = 3.0 - i * 0.4
		line.default_color = _colors.glow
		line.default_color.a = 0.5 - i * 0.08
		
		var offset = direction.normalized().rotated(PI / 2.0) * (i - 2) * 4.0
		line.points = PackedVector2Array([
			from_pos + offset - global_position,
			to_pos + offset - global_position
		])
		line.name = "BlurLine" + str(i)
		container.add_child(line)
	
	container.modulate.a = 0.0
	return container

## ========== 吸引效果 ==========
func _setup_pull_visuals() -> void:
	var direction = (from_position - to_position).normalized()
	
	# 吸引漩涡
	force_indicator = _create_vortex()
	force_indicator.global_position = to_position
	add_child(force_indicator)
	
	# 能量连线
	motion_trail = _create_pull_lines(from_position, to_position)
	add_child(motion_trail)

func _create_vortex() -> Node2D:
	var container = Node2D.new()
	
	# 螺旋线
	for i in range(3):
		var spiral = Line2D.new()
		spiral.width = 2.0
		spiral.default_color = _colors.primary
		
		var points: PackedVector2Array = []
		var start_angle = i * TAU / 3.0
		
		for j in range(20):
			var t = float(j) / 20.0
			var angle = start_angle + t * TAU * 2.0
			var radius = 30.0 * (1.0 - t)
			points.append(Vector2(cos(angle), sin(angle)) * radius)
		
		spiral.points = points
		spiral.name = "Spiral" + str(i)
		container.add_child(spiral)
	
	return container

func _create_pull_lines(from_pos: Vector2, to_pos: Vector2) -> Node2D:
	var container = Node2D.new()
	
	# 多条吸引线
	for i in range(4):
		var line = Line2D.new()
		line.width = 2.0
		line.default_color = _colors.secondary
		line.default_color.a = 0.6
		
		var offset_angle = (i - 1.5) * 0.3
		var offset_from = from_pos + Vector2(cos(offset_angle), sin(offset_angle)) * 10.0
		
		line.points = PackedVector2Array([
			offset_from - global_position,
			to_pos - global_position
		])
		line.name = "PullLine" + str(i)
		container.add_child(line)
	
	container.modulate.a = 0.0
	return container

## ========== 传送效果 ==========
func _setup_teleport_visuals() -> void:
	# 起点残影
	force_indicator = _create_teleport_afterimage()
	add_child(force_indicator)
	
	# 终点闪现
	impact_effect = _create_teleport_arrival()
	impact_effect.global_position = to_position
	add_child(impact_effect)

func _create_teleport_afterimage() -> Node2D:
	var container = Node2D.new()
	
	# 残影轮廓
	var silhouette = Polygon2D.new()
	silhouette.polygon = PackedVector2Array([
		Vector2(-10, 15),
		Vector2(10, 15),
		Vector2(8, 0),
		Vector2(10, -15),
		Vector2(0, -20),
		Vector2(-10, -15),
		Vector2(-8, 0),
	])
	silhouette.color = _colors.glow
	container.add_child(silhouette)
	
	# 消散粒子
	var particles = GPUParticles2D.new()
	particles.amount = 30
	particles.lifetime = 0.5
	particles.one_shot = true
	particles.explosiveness = 1.0
	
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, 0, 0)
	material.spread = 180.0
	material.initial_velocity_min = 30.0
	material.initial_velocity_max = 60.0
	material.gravity = Vector3(0, 0, 0)
	material.scale_min = 0.2
	material.scale_max = 0.5
	material.color = _colors.secondary
	
	particles.process_material = material
	container.add_child(particles)
	
	return container

func _create_teleport_arrival() -> Node2D:
	var container = Node2D.new()
	
	# 闪现光环
	var flash = Polygon2D.new()
	var points: PackedVector2Array = []
	var segments = 24
	var radius = 25.0
	
	for i in range(segments):
		var angle = i * TAU / segments
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	
	flash.polygon = points
	flash.color = _colors.secondary
	flash.scale = Vector2.ZERO
	container.add_child(flash)
	
	# 到达粒子
	var particles = GPUParticles2D.new()
	particles.amount = 25
	particles.lifetime = 0.4
	particles.one_shot = true
	particles.explosiveness = 1.0
	
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, 0, 0)
	material.spread = 180.0
	material.initial_velocity_min = 50.0
	material.initial_velocity_max = 100.0
	material.gravity = Vector3(0, 50, 0)
	material.scale_min = 0.2
	material.scale_max = 0.4
	material.color = _colors.primary
	
	particles.process_material = material
	container.add_child(particles)
	
	container.modulate.a = 0.0
	return container

## ========== 击飞效果 ==========
func _setup_launch_visuals() -> void:
	# 向上的能量喷发
	force_indicator = _create_launch_geyser()
	add_child(force_indicator)
	
	# 上升轨迹
	motion_trail = _create_launch_trail()
	add_child(motion_trail)

func _create_launch_geyser() -> Node2D:
	var container = Node2D.new()
	
	# 喷发柱
	var geyser = Polygon2D.new()
	geyser.polygon = PackedVector2Array([
		Vector2(-15, 0),
		Vector2(15, 0),
		Vector2(8, -40),
		Vector2(3, -60),
		Vector2(-3, -60),
		Vector2(-8, -40),
	])
	geyser.color = _colors.primary
	geyser.color.a = 0.7
	container.add_child(geyser)
	
	# 喷发粒子
	var particles = GPUParticles2D.new()
	particles.amount = 40
	particles.lifetime = 0.5
	particles.one_shot = true
	particles.explosiveness = 0.8
	
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, -1, 0)
	material.spread = 20.0
	material.initial_velocity_min = 150.0
	material.initial_velocity_max = 250.0
	material.gravity = Vector3(0, 200, 0)
	material.scale_min = 0.3
	material.scale_max = 0.6
	material.color = _colors.secondary
	
	particles.process_material = material
	container.add_child(particles)
	
	return container

func _create_launch_trail() -> Node2D:
	var container = Node2D.new()
	
	# 上升的能量线
	for i in range(3):
		var line = Line2D.new()
		line.width = 2.0
		line.default_color = _colors.glow
		
		var x_offset = (i - 1) * 8.0
		line.points = PackedVector2Array([
			Vector2(x_offset, 0),
			Vector2(x_offset, -80)
		])
		container.add_child(line)
	
	container.modulate.a = 0.0
	return container

## ========== 冲刺效果 ==========
func _setup_dash_visuals() -> void:
	var direction = (to_position - from_position).normalized()
	
	# 冲刺残影
	force_indicator = _create_dash_afterimages(from_position, to_position)
	add_child(force_indicator)
	
	# 速度线
	motion_trail = _create_speed_lines(direction)
	add_child(motion_trail)

func _create_dash_afterimages(from_pos: Vector2, to_pos: Vector2) -> Node2D:
	var container = Node2D.new()
	
	var direction = to_pos - from_pos
	var distance = direction.length()
	var afterimage_count = int(distance / 30.0) + 1
	
	for i in range(afterimage_count):
		var t = float(i) / afterimage_count
		var pos = from_pos.lerp(to_pos, t)
		
		var afterimage = Polygon2D.new()
		afterimage.polygon = PackedVector2Array([
			Vector2(-8, 12),
			Vector2(8, 12),
			Vector2(6, 0),
			Vector2(8, -12),
			Vector2(0, -15),
			Vector2(-8, -12),
			Vector2(-6, 0),
		])
		afterimage.color = _colors.glow
		afterimage.color.a = 0.3 * (1.0 - t)
		afterimage.global_position = pos
		afterimage.name = "Afterimage" + str(i)
		container.add_child(afterimage)
	
	return container

func _create_speed_lines(direction: Vector2) -> Node2D:
	var container = Node2D.new()
	
	for i in range(8):
		var line = Line2D.new()
		line.width = 2.0
		line.default_color = _colors.secondary
		line.default_color.a = 0.4
		
		var perpendicular = direction.rotated(PI / 2.0)
		var offset = perpendicular * (i - 3.5) * 6.0
		var length = randf_range(20.0, 40.0)
		
		line.points = PackedVector2Array([
			offset,
			offset - direction * length
		])
		container.add_child(line)
	
	container.modulate.a = 0.0
	return container

## ========== 动画播放 ==========
func _play_displacement_effect() -> void:
	match displacement_type:
		DisplacementActionData.DisplacementType.KNOCKBACK:
			_play_knockback_animation()
		DisplacementActionData.DisplacementType.PULL:
			_play_pull_animation()
		DisplacementActionData.DisplacementType.TELEPORT:
			_play_teleport_animation()
		DisplacementActionData.DisplacementType.LAUNCH:
			_play_launch_animation()
		DisplacementActionData.DisplacementType.DASH:
			_play_dash_animation()

func _play_knockback_animation() -> void:
	var tween = create_tween()
	
	# 力场波扩散
	if force_indicator:
		for i in range(force_indicator.get_child_count()):
			var wave = force_indicator.get_child(i)
			wave.scale = Vector2.ONE * 0.5
			tween.parallel().tween_property(wave, "scale", Vector2.ONE * (1.5 + i * 0.3), 0.2).set_delay(i * 0.05).set_ease(Tween.EASE_OUT)
			tween.parallel().tween_property(wave, "modulate:a", 0.0, 0.25).set_delay(i * 0.05 + 0.1)
	
	# 运动模糊
	if motion_trail:
		tween.parallel().tween_property(motion_trail, "modulate:a", 0.8, 0.1)
		tween.tween_property(motion_trail, "modulate:a", 0.0, 0.2)
	
	tween.tween_callback(_finish_effect)

func _play_pull_animation() -> void:
	var tween = create_tween()
	
	# 漩涡旋转
	if force_indicator:
		var rotation_tween = create_tween()
		rotation_tween.tween_property(force_indicator, "rotation", -TAU, 0.5)
		tween.parallel().tween_property(force_indicator, "scale", Vector2.ONE * 0.3, 0.5).from(Vector2.ONE).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(force_indicator, "modulate:a", 0.0, 0.5)
	
	# 吸引线
	if motion_trail:
		tween.parallel().tween_property(motion_trail, "modulate:a", 0.8, 0.1)
		tween.tween_property(motion_trail, "modulate:a", 0.0, 0.3)
	
	tween.tween_callback(_finish_effect)

func _play_teleport_animation() -> void:
	var tween = create_tween()
	
	# 起点消散
	if force_indicator:
		tween.tween_property(force_indicator, "modulate:a", 0.0, 0.2)
		tween.parallel().tween_property(force_indicator, "scale", Vector2.ONE * 1.5, 0.2)
		# 触发粒子
		for child in force_indicator.get_children():
			if child is GPUParticles2D:
				child.emitting = true
	
	# 终点闪现
	if impact_effect:
		tween.parallel().tween_property(impact_effect, "modulate:a", 1.0, 0.1).set_delay(0.1)
		for child in impact_effect.get_children():
			if child is Polygon2D:
				tween.parallel().tween_property(child, "scale", Vector2.ONE * 2.0, 0.15).set_delay(0.1).set_ease(Tween.EASE_OUT)
				tween.parallel().tween_property(child, "modulate:a", 0.0, 0.2).set_delay(0.15)
			elif child is GPUParticles2D:
				child.emitting = true
	
	tween.tween_callback(_finish_effect).set_delay(0.3)

func _play_launch_animation() -> void:
	var tween = create_tween()
	
	# 喷发效果
	if force_indicator:
		force_indicator.scale = Vector2(1.0, 0.0)
		tween.tween_property(force_indicator, "scale", Vector2.ONE, 0.15).set_ease(Tween.EASE_OUT)
		tween.tween_property(force_indicator, "modulate:a", 0.0, 0.3)
		# 触发粒子
		for child in force_indicator.get_children():
			if child is GPUParticles2D:
				child.emitting = true
	
	# 上升轨迹
	if motion_trail:
		tween.parallel().tween_property(motion_trail, "modulate:a", 0.6, 0.1)
		tween.tween_property(motion_trail, "modulate:a", 0.0, 0.3)
	
	tween.tween_callback(_finish_effect)

func _play_dash_animation() -> void:
	var tween = create_tween()
	
	# 残影淡出
	if force_indicator:
		for child in force_indicator.get_children():
			tween.parallel().tween_property(child, "modulate:a", 0.0, 0.3)
	
	# 速度线
	if motion_trail:
		tween.parallel().tween_property(motion_trail, "modulate:a", 0.6, 0.05)
		tween.tween_property(motion_trail, "modulate:a", 0.0, 0.2)
	
	tween.tween_callback(_finish_effect)

func _finish_effect() -> void:
	effect_finished.emit()
	queue_free()
