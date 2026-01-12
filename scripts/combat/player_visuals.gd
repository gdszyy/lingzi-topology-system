class_name PlayerVisuals extends Node2D

@onready var legs_pivot: Node2D = $LegsPivot
@onready var legs_sprite: Sprite2D = $LegsPivot/LegsSprite
@onready var torso_pivot: Node2D = $TorsoPivot
@onready var torso_sprite: Sprite2D = $TorsoPivot/TorsoSprite
@onready var head_sprite: Sprite2D = $TorsoPivot/HeadSprite
@onready var weapon_rig: Node2D = $TorsoPivot/WeaponRig
@onready var weapon_physics: WeaponPhysics = $TorsoPivot/WeaponRig/WeaponPhysics
@onready var main_hand_weapon: Sprite2D = $TorsoPivot/WeaponRig/WeaponPhysics/MainHandWeapon
@onready var off_hand_weapon: Sprite2D = $TorsoPivot/WeaponRig/WeaponPhysics/OffHandWeapon

var player: PlayerController = null

var is_walking: bool = false
var walk_cycle: float = 0.0
var walk_speed: float = 10.0

## 武器挥舞状态（现在由 WeaponPhysics 驱动）
var is_swinging: bool = false
var swing_progress: float = 0.0
var swing_start_angle: float = 0.0
var swing_end_angle: float = 0.0
var swing_duration: float = 0.0
var swing_curve: Curve = null

func _ready() -> void:
	player = get_parent() as PlayerController
	_setup_default_visuals()
	_connect_player_signals()
	_initialize_weapon_appearance()
	_setup_weapon_physics()

func _setup_weapon_physics() -> void:
	if weapon_physics != null:
		weapon_physics.weapon_settled.connect(_on_weapon_settled)
		weapon_physics.weapon_position_changed.connect(_on_weapon_position_changed)

func _connect_player_signals() -> void:
	if player != null:
		player.weapon_changed.connect(_on_weapon_changed)

func _initialize_weapon_appearance() -> void:
	if player != null and player.current_weapon != null:
		update_weapon_appearance(player.current_weapon)

func _on_weapon_changed(weapon: WeaponData) -> void:
	update_weapon_appearance(weapon)
	if weapon_physics != null:
		weapon_physics.update_physics_from_weapon(weapon)

func _on_weapon_settled() -> void:
	## 武器稳定后的回调，可用于通知状态机
	if player != null and player.has_signal("weapon_settled"):
		player.emit_signal("weapon_settled")

func _on_weapon_position_changed(_pos: Vector2, _rot: float) -> void:
	## 武器位置变化时的回调，可用于更新特效等
	pass

func _process(delta: float) -> void:
	_update_walk_animation(delta)
	_update_weapon_swing_physics(delta)

func _setup_default_visuals() -> void:
	_create_placeholder_sprites()

func _create_placeholder_sprites() -> void:
	if legs_sprite != null:
		var legs_texture = _create_ellipse_texture(20, 30, Color(0.6, 0.4, 0.2))
		legs_sprite.texture = legs_texture

	if torso_sprite != null:
		var torso_texture = _create_circle_texture(24, Color(0.3, 0.5, 0.8))
		torso_sprite.texture = torso_texture

	if head_sprite != null:
		var head_texture = _create_circle_texture(16, Color(0.9, 0.75, 0.6))
		head_sprite.texture = head_texture

	if main_hand_weapon != null:
		var weapon_texture = _create_rect_texture(8, 40, Color(0.7, 0.7, 0.7))
		main_hand_weapon.texture = weapon_texture

func _create_circle_texture(radius: int, color: Color) -> ImageTexture:
	var size = radius * 2
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center = Vector2(radius, radius)

	for x in range(size):
		for y in range(size):
			var pos = Vector2(x, y)
			if pos.distance_to(center) <= radius:
				image.set_pixel(x, y, color)
			else:
				image.set_pixel(x, y, Color(0, 0, 0, 0))

	return ImageTexture.create_from_image(image)

func _create_ellipse_texture(width: int, height: int, color: Color) -> ImageTexture:
	var image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	var center = Vector2(width / 2.0, height / 2.0)
	var a = width / 2.0
	var b = height / 2.0

	for x in range(width):
		for y in range(height):
			var dx = (x - center.x) / a
			var dy = (y - center.y) / b
			if dx * dx + dy * dy <= 1:
				image.set_pixel(x, y, color)
			else:
				image.set_pixel(x, y, Color(0, 0, 0, 0))

	return ImageTexture.create_from_image(image)

func _create_rect_texture(width: int, height: int, color: Color) -> ImageTexture:
	var image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)

func _update_walk_animation(delta: float) -> void:
	if player == null:
		return

	var speed = player.velocity.length()
	is_walking = speed > 10

	if is_walking:
		walk_cycle += delta * walk_speed * (speed / 300.0)

		var bob = sin(walk_cycle) * 2
		torso_pivot.position.y = bob

		var leg_swing = sin(walk_cycle) * 0.1
		legs_pivot.scale.y = 1.0 + leg_swing * 0.1
	else:
		torso_pivot.position.y = lerp(torso_pivot.position.y, 0.0, delta * 10)
		legs_pivot.scale.y = lerp(legs_pivot.scale.y, 1.0, delta * 10)

## 使用物理系统驱动武器挥舞
func _update_weapon_swing_physics(delta: float) -> void:
	if not is_swinging or weapon_physics == null:
		return

	swing_progress += delta / swing_duration

	if swing_progress >= 1.0:
		is_swinging = false
		swing_progress = 1.0
		## 挥舞结束，让武器回到休息位置
		weapon_physics.set_to_rest()
		return

	## 计算当前目标角度
	var curve_value = swing_progress
	if swing_curve != null:
		curve_value = swing_curve.sample(swing_progress)
	
	var target_angle = lerp(swing_start_angle, swing_end_angle, curve_value)
	
	## 设置武器物理系统的目标旋转
	weapon_physics.set_target(Vector2.ZERO, deg_to_rad(target_angle))

## 开始武器挥舞（使用物理系统）
func start_weapon_swing(start_angle: float, end_angle: float, duration: float, curve: Curve = null) -> void:
	is_swinging = true
	swing_progress = 0.0
	swing_start_angle = start_angle
	swing_end_angle = end_angle
	swing_duration = max(0.01, duration)
	swing_curve = curve
	
	## 设置初始目标角度
	if weapon_physics != null:
		weapon_physics.set_target(Vector2.ZERO, deg_to_rad(start_angle))

## 开始攻击动作的武器回正阶段
func start_weapon_repositioning(_target_position: Vector2, target_rotation: float) -> void:
	if weapon_physics != null:
		weapon_physics.set_target(Vector2.ZERO, target_rotation)

## 检查武器是否已经回正到位
func is_weapon_settled() -> bool:
	if weapon_physics != null:
		return weapon_physics.get_is_settled()
	return true

## 获取武器回正的预估时间
func get_weapon_settle_time() -> float:
	if weapon_physics != null:
		return weapon_physics.estimate_settle_time()
	return 0.0

## 重置武器位置（立即跳转）
func reset_weapon_position() -> void:
	is_swinging = false
	if weapon_physics != null:
		weapon_physics.snap_to_rest()
	else:
		weapon_rig.rotation = 0

## 获取武器物理节点
func get_weapon_physics() -> WeaponPhysics:
	return weapon_physics

func update_weapon_appearance(weapon: WeaponData) -> void:
	if weapon == null:
		main_hand_weapon.visible = false
		off_hand_weapon.visible = false
		return

	if weapon.weapon_texture != null:
		main_hand_weapon.texture = weapon.weapon_texture
	else:
		var weapon_texture = _create_weapon_texture_for_type(weapon.weapon_type)
		main_hand_weapon.texture = weapon_texture

	main_hand_weapon.offset = weapon.weapon_offset
	main_hand_weapon.scale = weapon.weapon_scale
	main_hand_weapon.visible = weapon.weapon_type != WeaponData.WeaponType.UNARMED

	off_hand_weapon.visible = weapon.is_dual_wield()
	
	## 更新武器物理参数
	if weapon_physics != null:
		weapon_physics.update_physics_from_weapon(weapon)

func _create_weapon_texture_for_type(weapon_type: int) -> ImageTexture:
	match weapon_type:
		WeaponData.WeaponType.GREATSWORD:
			return _create_rect_texture(12, 60, Color(0.6, 0.6, 0.7))
		WeaponData.WeaponType.DUAL_BLADE:
			return _create_rect_texture(8, 50, Color(0.7, 0.7, 0.8))
		WeaponData.WeaponType.SPEAR:
			return _create_rect_texture(6, 80, Color(0.5, 0.4, 0.3))
		WeaponData.WeaponType.DAGGER:
			return _create_rect_texture(6, 25, Color(0.8, 0.8, 0.8))
		WeaponData.WeaponType.STAFF:
			return _create_rect_texture(8, 55, Color(0.4, 0.3, 0.2))
		_:
			return _create_rect_texture(8, 40, Color(0.7, 0.7, 0.7))

func play_hit_effect() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.RED, 0.05)
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)

func play_attack_effect(attack: AttackData) -> void:
	if attack == null:
		return

	start_weapon_swing(
		attack.swing_start_angle,
		attack.swing_end_angle,
		attack.windup_time + attack.active_time,
		attack.swing_curve
	)

## 施加武器冲量（已禁用，保留接口兼容）
func apply_weapon_impulse(_impulse: Vector2) -> void:
	## 武器物理现在只控制旋转，不控制位置
	pass

## 施加武器角冲量
func apply_weapon_angular_impulse(angular_impulse: float) -> void:
	if weapon_physics != null:
		weapon_physics.apply_angular_impulse(angular_impulse)
