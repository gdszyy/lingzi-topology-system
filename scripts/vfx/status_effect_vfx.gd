class_name StatusEffectVFX
extends Node2D
## 状态效果特效
## 展示各种状态效果的视觉表现

signal effect_finished

@export var status_type: ApplyStatusActionData.StatusType = ApplyStatusActionData.StatusType.ENTROPY_BURN
@export var duration: float = 3.0
@export var effect_value: float = 5.0

var _colors: Dictionary = {}
var _time_remaining: float = 0.0
var _tick_timer: float = 0.0
var _is_active: bool = false
var _target: Node2D = null

# 视觉组件
var main_effect: Node2D
var ambient_particles: GPUParticles2D
var overlay_effect: Node2D

func _ready() -> void:
	pass

func initialize(p_status_type: ApplyStatusActionData.StatusType, p_duration: float = 3.0, p_value: float = 5.0, target: Node2D = null) -> void:
	status_type = p_status_type
	duration = p_duration
	effect_value = p_value
	_time_remaining = duration
	_target = target
	
	# 获取对应相态的颜色
	var spiriton_phase = _get_spiriton_phase_from_status()
	_colors = VFXManager.SPIRITON_PHASE_COLORS.get(spiriton_phase, VFXManager.SPIRITON_PHASE_COLORS[ApplyStatusActionData.SpiritonPhase.PLASMA])
	
	_setup_visuals()
	_is_active = true

func _get_spiriton_phase_from_status() -> ApplyStatusActionData.SpiritonPhase:
	match status_type:
		ApplyStatusActionData.StatusType.ENTROPY_BURN:
			return ApplyStatusActionData.SpiritonPhase.PLASMA
		ApplyStatusActionData.StatusType.CRYO_CRYSTAL:
			return ApplyStatusActionData.SpiritonPhase.FLUID
		ApplyStatusActionData.StatusType.STRUCTURE_LOCK:
			return ApplyStatusActionData.SpiritonPhase.SOLID
		ApplyStatusActionData.StatusType.SPIRITON_EROSION:
			return ApplyStatusActionData.SpiritonPhase.GAS
		ApplyStatusActionData.StatusType.PHASE_DISRUPTION, ApplyStatusActionData.StatusType.RESONANCE_MARK:
			return ApplyStatusActionData.SpiritonPhase.WAVE
		ApplyStatusActionData.StatusType.SPIRITON_SURGE:
			return ApplyStatusActionData.SpiritonPhase.PLASMA
		ApplyStatusActionData.StatusType.PHASE_SHIFT:
			return ApplyStatusActionData.SpiritonPhase.WAVE
		ApplyStatusActionData.StatusType.SOLID_SHELL:
			return ApplyStatusActionData.SpiritonPhase.SOLID
	return ApplyStatusActionData.SpiritonPhase.PLASMA

func _setup_visuals() -> void:
	match status_type:
		ApplyStatusActionData.StatusType.ENTROPY_BURN:
			_setup_entropy_burn()
		ApplyStatusActionData.StatusType.CRYO_CRYSTAL:
			_setup_cryo_crystal()
		ApplyStatusActionData.StatusType.STRUCTURE_LOCK:
			_setup_structure_lock()
		ApplyStatusActionData.StatusType.SPIRITON_EROSION:
			_setup_spiriton_erosion()
		ApplyStatusActionData.StatusType.PHASE_DISRUPTION:
			_setup_phase_disruption()
		ApplyStatusActionData.StatusType.RESONANCE_MARK:
			_setup_resonance_mark()
		ApplyStatusActionData.StatusType.SPIRITON_SURGE:
			_setup_spiriton_surge()
		ApplyStatusActionData.StatusType.PHASE_SHIFT:
			_setup_phase_shift()
		ApplyStatusActionData.StatusType.SOLID_SHELL:
			_setup_solid_shell()

## ========== 熵燃 (等离子态火焰) ==========
func _setup_entropy_burn() -> void:
	main_effect = Node2D.new()
	add_child(main_effect)
	
	# 火焰粒子
	ambient_particles = _create_fire_particles()
	main_effect.add_child(ambient_particles)
	
	# 烧灼纹理覆盖
	overlay_effect = _create_burn_overlay()
	main_effect.add_child(overlay_effect)
	
	ambient_particles.emitting = true

func _create_fire_particles() -> GPUParticles2D:
	var particles = GPUParticles2D.new()
	particles.amount = 30
	particles.lifetime = 0.6
	particles.explosiveness = 0.0
	
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, -1, 0)
	material.spread = 30.0
	material.initial_velocity_min = 40.0
	material.initial_velocity_max = 80.0
	material.gravity = Vector3(0, -100, 0)
	material.scale_min = 0.3
	material.scale_max = 0.8
	material.color = _colors.primary
	
	# 从身体周围发射
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 15.0
	
	particles.process_material = material
	return particles

func _create_burn_overlay() -> Node2D:
	var container = Node2D.new()
	
	# 动态烧灼纹理
	for i in range(5):
		var burn_mark = Polygon2D.new()
		var points: PackedVector2Array = []
		var segments = 6
		var radius = randf_range(3.0, 8.0)
		
		for j in range(segments):
			var angle = j * TAU / segments + randf_range(-0.3, 0.3)
			points.append(Vector2(cos(angle), sin(angle)) * radius)
		
		burn_mark.polygon = points
		burn_mark.color = Color(0.1, 0.0, 0.0, 0.6)
		burn_mark.position = Vector2(randf_range(-12, 12), randf_range(-15, 10))
		container.add_child(burn_mark)
	
	return container

## ========== 冷脆化 (液态冰晶) ==========
func _setup_cryo_crystal() -> void:
	main_effect = Node2D.new()
	add_child(main_effect)
	
	# 冰晶覆盖
	overlay_effect = _create_ice_crystal_overlay()
	main_effect.add_child(overlay_effect)
	
	# 寒气粒子
	ambient_particles = _create_frost_particles()
	main_effect.add_child(ambient_particles)
	
	ambient_particles.emitting = true
	_play_freeze_animation()

func _create_ice_crystal_overlay() -> Node2D:
	var container = Node2D.new()
	
	# 冰晶形状
	for i in range(8):
		var crystal = Polygon2D.new()
		var points: PackedVector2Array = []
		
		# 六边形冰晶
		var size = randf_range(5.0, 12.0)
		for j in range(6):
			var angle = j * PI / 3.0
			points.append(Vector2(cos(angle), sin(angle)) * size)
		
		crystal.polygon = points
		crystal.color = _colors.secondary
		crystal.color.a = 0.6
		crystal.position = Vector2(randf_range(-15, 15), randf_range(-20, 15))
		crystal.rotation = randf() * TAU
		crystal.scale = Vector2.ZERO
		crystal.name = "Crystal" + str(i)
		container.add_child(crystal)
	
	return container

func _create_frost_particles() -> GPUParticles2D:
	var particles = GPUParticles2D.new()
	particles.amount = 20
	particles.lifetime = 1.0
	particles.explosiveness = 0.0
	
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, 1, 0)
	material.spread = 60.0
	material.initial_velocity_min = 10.0
	material.initial_velocity_max = 30.0
	material.gravity = Vector3(0, 20, 0)
	material.scale_min = 0.2
	material.scale_max = 0.4
	material.color = _colors.trail
	
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 20.0
	
	particles.process_material = material
	return particles

func _play_freeze_animation() -> void:
	if overlay_effect == null:
		return
	
	for i in range(overlay_effect.get_child_count()):
		var crystal = overlay_effect.get_child(i)
		var delay = randf() * 0.3
		
		var tween = create_tween()
		tween.tween_property(crystal, "scale", Vector2.ONE, 0.2).set_delay(delay).set_ease(Tween.EASE_OUT)

## ========== 结构锁 (固态束缚) ==========
func _setup_structure_lock() -> void:
	main_effect = Node2D.new()
	add_child(main_effect)
	
	# 能量法阵
	var magic_circle = _create_lock_magic_circle()
	main_effect.add_child(magic_circle)
	
	# 能量锁链
	overlay_effect = _create_energy_chains()
	main_effect.add_child(overlay_effect)
	
	_play_lock_animation()

func _create_lock_magic_circle() -> Node2D:
	var container = Node2D.new()
	container.position.y = 20  # 脚下
	
	# 外圈
	var outer_ring = Polygon2D.new()
	var points: PackedVector2Array = []
	var segments = 32
	var radius = 25.0
	
	for i in range(segments + 1):
		var angle = i * TAU / segments
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	
	outer_ring.polygon = points
	outer_ring.color = _colors.secondary
	outer_ring.color.a = 0.7
	outer_ring.name = "OuterRing"
	container.add_child(outer_ring)
	
	# 内部符文
	for i in range(6):
		var rune = Polygon2D.new()
		var rune_points: PackedVector2Array = []
		var rune_size = 5.0
		
		# 简单的符文形状
		rune_points.append(Vector2(0, -rune_size))
		rune_points.append(Vector2(rune_size * 0.5, 0))
		rune_points.append(Vector2(0, rune_size))
		rune_points.append(Vector2(-rune_size * 0.5, 0))
		
		rune.polygon = rune_points
		rune.color = _colors.primary
		
		var angle = i * TAU / 6.0
		rune.position = Vector2(cos(angle), sin(angle)) * radius * 0.6
		rune.rotation = angle
		container.add_child(rune)
	
	return container

func _create_energy_chains() -> Node2D:
	var container = Node2D.new()
	
	# 创建4条锁链
	for i in range(4):
		var chain = Line2D.new()
		chain.width = 3.0
		chain.default_color = _colors.secondary
		
		var start_angle = i * PI / 2.0
		var start_pos = Vector2(cos(start_angle), sin(start_angle)) * 25.0
		start_pos.y += 20  # 从法阵位置开始
		
		var end_pos = Vector2(cos(start_angle) * 5.0, -10.0 + i * 5.0)
		
		# 锁链路径
		var points: PackedVector2Array = []
		points.append(start_pos)
		points.append((start_pos + end_pos) * 0.5 + Vector2(randf_range(-5, 5), randf_range(-5, 5)))
		points.append(end_pos)
		
		chain.points = points
		chain.name = "Chain" + str(i)
		container.add_child(chain)
	
	return container

func _play_lock_animation() -> void:
	# 法阵旋转
	if main_effect.get_child_count() > 0:
		var magic_circle = main_effect.get_child(0)
		var tween = create_tween()
		tween.set_loops()
		tween.tween_property(magic_circle, "rotation", TAU, 4.0).from(0.0)

## ========== 灵蚀 (气态腐蚀) ==========
func _setup_spiriton_erosion() -> void:
	main_effect = Node2D.new()
	add_child(main_effect)
	
	# 毒雾粒子
	ambient_particles = _create_poison_fog()
	main_effect.add_child(ambient_particles)
	
	# 腐蚀斑点
	overlay_effect = _create_erosion_spots()
	main_effect.add_child(overlay_effect)
	
	ambient_particles.emitting = true

func _create_poison_fog() -> GPUParticles2D:
	var particles = GPUParticles2D.new()
	particles.amount = 25
	particles.lifetime = 1.2
	particles.explosiveness = 0.0
	
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, 0, 0)
	material.spread = 180.0
	material.initial_velocity_min = 5.0
	material.initial_velocity_max = 15.0
	material.gravity = Vector3(0, -5, 0)
	material.scale_min = 0.8
	material.scale_max = 1.5
	material.color = _colors.primary
	material.color.a = 0.4
	
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 20.0
	
	particles.process_material = material
	return particles

func _create_erosion_spots() -> Node2D:
	var container = Node2D.new()
	
	for i in range(6):
		var spot = Polygon2D.new()
		var points: PackedVector2Array = []
		var segments = 8
		var radius = randf_range(2.0, 5.0)
		
		for j in range(segments):
			var angle = j * TAU / segments
			points.append(Vector2(cos(angle), sin(angle)) * radius)
		
		spot.polygon = points
		spot.color = Color(0.2, 0.3, 0.1, 0.7)
		spot.position = Vector2(randf_range(-12, 12), randf_range(-15, 10))
		container.add_child(spot)
	
	return container

## ========== 相位紊乱 (波态干扰) ==========
func _setup_phase_disruption() -> void:
	main_effect = Node2D.new()
	add_child(main_effect)
	
	# 故障效果覆盖
	overlay_effect = _create_glitch_overlay()
	main_effect.add_child(overlay_effect)
	
	_start_glitch_animation()

func _create_glitch_overlay() -> Node2D:
	var container = Node2D.new()
	
	# 扫描线
	for i in range(5):
		var line = Polygon2D.new()
		line.polygon = PackedVector2Array([
			Vector2(-20, 0),
			Vector2(20, 0),
			Vector2(20, 2),
			Vector2(-20, 2)
		])
		line.color = _colors.secondary
		line.color.a = 0.3
		line.position.y = -20 + i * 10
		line.name = "ScanLine" + str(i)
		container.add_child(line)
	
	# 像素化块
	for i in range(3):
		var block = Polygon2D.new()
		var size = randf_range(5.0, 10.0)
		block.polygon = PackedVector2Array([
			Vector2(0, 0),
			Vector2(size, 0),
			Vector2(size, size),
			Vector2(0, size)
		])
		block.color = _colors.primary
		block.color.a = 0.5
		block.position = Vector2(randf_range(-15, 15), randf_range(-20, 15))
		block.name = "GlitchBlock" + str(i)
		container.add_child(block)
	
	return container

func _start_glitch_animation() -> void:
	if overlay_effect == null:
		return
	
	# 扫描线动画
	for child in overlay_effect.get_children():
		if child.name.begins_with("ScanLine"):
			var tween = create_tween()
			tween.set_loops()
			tween.tween_property(child, "position:y", 25.0, 0.5).from(-25.0)
		elif child.name.begins_with("GlitchBlock"):
			_animate_glitch_block(child)

func _animate_glitch_block(block: Node2D) -> void:
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(block, "modulate:a", 0.0, 0.1)
	tween.tween_property(block, "modulate:a", 1.0, 0.1)
	tween.tween_callback(func(): 
		block.position = Vector2(randf_range(-15, 15), randf_range(-20, 15))
	).set_delay(randf_range(0.1, 0.3))

## ========== 共振标记 (波态锁定) ==========
func _setup_resonance_mark() -> void:
	main_effect = Node2D.new()
	add_child(main_effect)
	
	# 准星标记
	overlay_effect = _create_resonance_crosshair()
	main_effect.add_child(overlay_effect)
	
	_play_resonance_animation()

func _create_resonance_crosshair() -> Node2D:
	var container = Node2D.new()
	
	# 外圈
	var outer = Polygon2D.new()
	var points: PackedVector2Array = []
	var segments = 32
	var radius = 20.0
	
	for i in range(segments + 1):
		var angle = i * TAU / segments
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	
	outer.polygon = points
	outer.color = _colors.primary
	outer.color.a = 0.6
	container.add_child(outer)
	
	# 十字准星
	for i in range(4):
		var line = Polygon2D.new()
		line.polygon = PackedVector2Array([
			Vector2(-1.5, 8),
			Vector2(1.5, 8),
			Vector2(1.5, 18),
			Vector2(-1.5, 18)
		])
		line.color = _colors.secondary
		line.rotation = i * PI / 2.0
		container.add_child(line)
	
	# 中心点
	var center = Polygon2D.new()
	var center_points: PackedVector2Array = []
	for i in range(8):
		var angle = i * TAU / 8.0
		center_points.append(Vector2(cos(angle), sin(angle)) * 3.0)
	center.polygon = center_points
	center.color = _colors.secondary
	container.add_child(center)
	
	return container

func _play_resonance_animation() -> void:
	if overlay_effect == null:
		return
	
	var tween = create_tween()
	tween.set_loops()
	
	# 旋转和脉动
	tween.tween_property(overlay_effect, "rotation", TAU, 2.0).from(0.0)
	tween.parallel().tween_property(overlay_effect, "scale", Vector2.ONE * 1.1, 0.5).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(overlay_effect, "scale", Vector2.ONE * 0.9, 0.5).set_delay(0.5).set_ease(Tween.EASE_IN_OUT)

## ========== 灵潮 (等离子态增益) ==========
func _setup_spiriton_surge() -> void:
	main_effect = Node2D.new()
	add_child(main_effect)
	
	# 能量光环
	overlay_effect = _create_surge_aura()
	main_effect.add_child(overlay_effect)
	
	# 能量粒子
	ambient_particles = _create_surge_particles()
	main_effect.add_child(ambient_particles)
	
	ambient_particles.emitting = true
	_play_surge_animation()

func _create_surge_aura() -> Node2D:
	var container = Node2D.new()
	
	# 多层光环
	for i in range(3):
		var aura = Polygon2D.new()
		var points: PackedVector2Array = []
		var segments = 24
		var radius = 25.0 + i * 8.0
		
		for j in range(segments + 1):
			var angle = j * TAU / segments
			points.append(Vector2(cos(angle), sin(angle)) * radius)
		
		aura.polygon = points
		aura.color = _colors.glow
		aura.color.a = 0.3 - i * 0.08
		aura.name = "Aura" + str(i)
		container.add_child(aura)
	
	return container

func _create_surge_particles() -> GPUParticles2D:
	var particles = GPUParticles2D.new()
	particles.amount = 20
	particles.lifetime = 0.8
	particles.explosiveness = 0.0
	
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, -1, 0)
	material.spread = 45.0
	material.initial_velocity_min = 50.0
	material.initial_velocity_max = 100.0
	material.gravity = Vector3(0, -50, 0)
	material.scale_min = 0.2
	material.scale_max = 0.5
	material.color = _colors.secondary
	
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 15.0
	
	particles.process_material = material
	return particles

func _play_surge_animation() -> void:
	if overlay_effect == null:
		return
	
	for i in range(overlay_effect.get_child_count()):
		var aura = overlay_effect.get_child(i)
		var tween = create_tween()
		tween.set_loops()
		
		var pulse_scale = 1.0 + (i + 1) * 0.05
		tween.tween_property(aura, "scale", Vector2.ONE * pulse_scale, 0.5 + i * 0.1).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(aura, "scale", Vector2.ONE, 0.5 + i * 0.1).set_ease(Tween.EASE_IN_OUT)

## ========== 相移 (波态加速) ==========
func _setup_phase_shift() -> void:
	main_effect = Node2D.new()
	add_child(main_effect)
	
	# 速度线
	overlay_effect = _create_speed_lines()
	main_effect.add_child(overlay_effect)
	
	# 残影粒子
	ambient_particles = _create_afterimage_particles()
	main_effect.add_child(ambient_particles)
	
	ambient_particles.emitting = true

func _create_speed_lines() -> Node2D:
	var container = Node2D.new()
	
	for i in range(6):
		var line = Line2D.new()
		line.width = 2.0
		line.default_color = _colors.secondary
		line.default_color.a = 0.5
		
		var y_offset = -15 + i * 6
		line.points = PackedVector2Array([
			Vector2(-30, y_offset),
			Vector2(-10, y_offset)
		])
		line.name = "SpeedLine" + str(i)
		container.add_child(line)
	
	return container

func _create_afterimage_particles() -> GPUParticles2D:
	var particles = GPUParticles2D.new()
	particles.amount = 15
	particles.lifetime = 0.4
	particles.explosiveness = 0.0
	
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(-1, 0, 0)
	material.spread = 15.0
	material.initial_velocity_min = 100.0
	material.initial_velocity_max = 150.0
	material.gravity = Vector3(0, 0, 0)
	material.scale_min = 0.5
	material.scale_max = 1.0
	material.color = _colors.trail
	
	particles.process_material = material
	return particles

## ========== 固壳 (固态护甲) ==========
func _setup_solid_shell() -> void:
	main_effect = Node2D.new()
	add_child(main_effect)
	
	# 护甲覆盖
	overlay_effect = _create_armor_overlay()
	main_effect.add_child(overlay_effect)
	
	_play_armor_animation()

func _create_armor_overlay() -> Node2D:
	var container = Node2D.new()
	
	# 护甲板块
	var armor_positions = [
		Vector2(0, -15),   # 头部
		Vector2(-12, 0),   # 左肩
		Vector2(12, 0),    # 右肩
		Vector2(0, 10),    # 胸部
	]
	
	for i in range(armor_positions.size()):
		var plate = Polygon2D.new()
		var size = 10.0 if i == 3 else 8.0
		
		# 六边形护甲板
		var points: PackedVector2Array = []
		for j in range(6):
			var angle = j * PI / 3.0
			points.append(Vector2(cos(angle), sin(angle)) * size)
		
		plate.polygon = points
		plate.color = _colors.secondary
		plate.color.a = 0.7
		plate.position = armor_positions[i]
		plate.scale = Vector2.ZERO
		plate.name = "ArmorPlate" + str(i)
		container.add_child(plate)
	
	return container

func _play_armor_animation() -> void:
	if overlay_effect == null:
		return
	
	for i in range(overlay_effect.get_child_count()):
		var plate = overlay_effect.get_child(i)
		var delay = i * 0.1
		
		var tween = create_tween()
		tween.tween_property(plate, "scale", Vector2.ONE, 0.2).set_delay(delay).set_ease(Tween.EASE_OUT)

## ========== 通用方法 ==========
func _process(delta: float) -> void:
	if not _is_active:
		return
	
	_time_remaining -= delta
	
	# 跟随目标
	if _target and is_instance_valid(_target):
		global_position = _target.global_position
	
	# 检查是否结束
	if _time_remaining <= 0:
		_play_end_animation()

func _play_end_animation() -> void:
	_is_active = false
	
	if ambient_particles:
		ambient_particles.emitting = false
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(_finish_effect)

func stop() -> void:
	_time_remaining = 0.0

func refresh(new_duration: float) -> void:
	_time_remaining = new_duration

func _finish_effect() -> void:
	effect_finished.emit()
	queue_free()
