class_name PlayerVisuals extends Node2D
## 玩家视觉系统
## 管理角色的视觉渲染，包括躯干、头部、手臂和武器
## 【重构】消除与 BodyAnimationController 的冗余动画逻辑
## 【重构】修复初始化顺序，通过显式注入替代隐式节点遍历
## 【重构】统一纹理缓存，避免重复生成

@onready var legs_pivot: Node2D = $LegsPivot
@onready var legs_sprite: Sprite2D = $LegsPivot/LegsSprite
@onready var torso_pivot: Node2D = $TorsoPivot
@onready var torso_sprite: Sprite2D = $TorsoPivot/TorsoSprite
@onready var head_sprite: Sprite2D = $TorsoPivot/HeadSprite
@onready var weapon_rig: Node2D = $TorsoPivot/WeaponRig
@onready var weapon_physics: WeaponPhysics = $TorsoPivot/WeaponRig/WeaponPhysics

## 手臂装配
var left_arm: ArmRig = null
var right_arm: ArmRig = null

## 战斗动画控制器
var combat_animator: CombatAnimator = null

## 全身骨骼动画控制器
var body_animation_controller: BodyAnimationController = null

var player: PlayerController = null

## 【优化】纹理缓存 — 避免重复生成相同的纹理
static var _texture_cache: Dictionary = {}

func _ready() -> void:
	player = get_parent() as PlayerController
	_setup_default_visuals()
	_create_arm_rigs()
	_setup_combat_animator()
	_setup_body_animation_controller()
	_connect_player_signals()
	_initialize_weapon_appearance()
	_setup_weapon_physics()

func _create_arm_rigs() -> void:
	## 创建左臂
	left_arm = ArmRig.new()
	left_arm.name = "LeftArmRig"
	left_arm.is_left_arm = true
	left_arm.shoulder_offset = Vector2(12, 0)
	left_arm.arm_color = Color(0.9, 0.75, 0.6)
	torso_pivot.add_child(left_arm)

	## 创建右臂
	right_arm = ArmRig.new()
	right_arm.name = "RightArmRig"
	right_arm.is_left_arm = false
	right_arm.shoulder_offset = Vector2(12, 0)
	right_arm.arm_color = Color(0.9, 0.75, 0.6)
	torso_pivot.add_child(right_arm)

func _setup_combat_animator() -> void:
	combat_animator = CombatAnimator.new()
	combat_animator.name = "CombatAnimator"
	add_child(combat_animator)
	combat_animator.initialize(left_arm, right_arm, weapon_physics)

	## 连接信号
	combat_animator.animation_finished.connect(_on_attack_animation_finished)
	combat_animator.hit_frame_reached.connect(_on_hit_frame_reached)
	combat_animator.animation_started.connect(_on_attack_animation_started)

func _setup_body_animation_controller() -> void:
	body_animation_controller = BodyAnimationController.new()
	body_animation_controller.name = "BodyAnimationController"
	add_child(body_animation_controller)

	## 设置双向引用
	if combat_animator != null:
		body_animation_controller.set_combat_animator(combat_animator)
		combat_animator.set_body_animation_controller(body_animation_controller)

	## 初始化控制器
	body_animation_controller.initialize(
		player,
		left_arm,
		right_arm,
		torso_pivot,
		head_sprite,
		legs_pivot
	)

	body_animation_controller.animation_state_changed.connect(_on_body_animation_state_changed)

func _setup_weapon_physics() -> void:
	if weapon_physics != null:
		## 【重构】显式注入 CombatAnimator 和武器质量回调
		weapon_physics.initialize(
			combat_animator,
			Callable(self, "_get_current_weapon_mass")
		)
		weapon_physics.weapon_settled.connect(_on_weapon_settled)
		weapon_physics.weapon_position_changed.connect(_on_weapon_position_changed)

## 【新增】武器质量回调，供 WeaponPhysics 使用
func _get_current_weapon_mass() -> float:
	if player != null and player.current_weapon != null:
		return player.current_weapon.weight
	return 1.0

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
	if combat_animator != null:
		combat_animator.set_weapon(weapon)

func _on_weapon_settled() -> void:
	if player != null and player.has_signal("weapon_settled"):
		player.emit_signal("weapon_settled")

func _on_weapon_position_changed(_pos: Vector2, _rot: float) -> void:
	pass

func _on_attack_animation_started(_attack: AttackData) -> void:
	if body_animation_controller != null:
		body_animation_controller.on_combat_animation_started()

func _on_attack_animation_finished(_attack: AttackData) -> void:
	if weapon_physics != null:
		weapon_physics.set_to_rest()
	if body_animation_controller != null:
		body_animation_controller.on_combat_animation_finished()

func _on_hit_frame_reached(_attack: AttackData) -> void:
	pass

func _on_body_animation_state_changed(_state: BodyAnimationController.AnimationState) -> void:
	pass

## 【重构】_process 只保留腿部动画，躯干动画完全由 BodyAnimationController 处理
## 消除原来 _update_walk_animation 与 BodyAnimationController 的冲突
func _process(delta: float) -> void:
	_update_legs_animation(delta)

func _setup_default_visuals() -> void:
	_create_placeholder_sprites()

func _create_placeholder_sprites() -> void:
	if legs_sprite != null:
		legs_sprite.texture = _get_or_create_ellipse_texture(20, 30, Color(0.6, 0.4, 0.2))
	if torso_sprite != null:
		torso_sprite.texture = _get_or_create_circle_texture(24, Color(0.3, 0.5, 0.8))
	if head_sprite != null:
		head_sprite.texture = _get_or_create_circle_texture(16, Color(0.9, 0.75, 0.6))

## 【优化】使用缓存的纹理生成方法
func _get_or_create_circle_texture(radius: int, color: Color) -> ImageTexture:
	var key = "circle_%d_%s" % [radius, color.to_html()]
	if _texture_cache.has(key):
		return _texture_cache[key]

	var size = radius * 2
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center = Vector2(radius, radius)

	for x in range(size):
		for y in range(size):
			if Vector2(x, y).distance_to(center) <= radius:
				image.set_pixel(x, y, color)
			else:
				image.set_pixel(x, y, Color(0, 0, 0, 0))

	var tex = ImageTexture.create_from_image(image)
	_texture_cache[key] = tex
	return tex

func _get_or_create_ellipse_texture(width: int, height: int, color: Color) -> ImageTexture:
	var key = "ellipse_%d_%d_%s" % [width, height, color.to_html()]
	if _texture_cache.has(key):
		return _texture_cache[key]

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

	var tex = ImageTexture.create_from_image(image)
	_texture_cache[key] = tex
	return tex

func _get_or_create_rect_texture(width: int, height: int, color: Color) -> ImageTexture:
	var key = "rect_%d_%d_%s" % [width, height, color.to_html()]
	if _texture_cache.has(key):
		return _texture_cache[key]

	var image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(color)
	var tex = ImageTexture.create_from_image(image)
	_texture_cache[key] = tex
	return tex

## 腿部动画 — 这是 PlayerVisuals 唯一负责的动画
func _update_legs_animation(delta: float) -> void:
	if player == null:
		return

	var speed = player.velocity.length()
	var is_moving = speed > 10

	if player.is_flying:
		## 飞行时腿部收起
		var target_scale = Vector2(0.8, 0.7)
		legs_pivot.scale = legs_pivot.scale.lerp(target_scale, delta * 8)

		var velocity_dir = player.velocity.normalized() if speed > 10 else Vector2.ZERO
		var face_dir = player.current_facing_direction
		var relative_velocity = velocity_dir.rotated(-face_dir.angle())

		var leg_offset = Vector2(0, 5 + relative_velocity.y * 3)
		legs_pivot.position = legs_pivot.position.lerp(leg_offset, delta * 5)
	elif is_moving:
		## 移动时腿部动画
		var walk_speed_factor = speed / 300.0
		var leg_stretch = 1.0 + sin(Time.get_ticks_msec() * 0.02 * walk_speed_factor) * 0.08 * walk_speed_factor
		legs_pivot.scale.y = lerpf(legs_pivot.scale.y, leg_stretch, delta * 15)
		legs_pivot.scale.x = lerpf(legs_pivot.scale.x, 1.0, delta * 10)
		legs_pivot.position = legs_pivot.position.lerp(Vector2.ZERO, delta * 10)
	else:
		## 待机时腿部恢复默认
		legs_pivot.scale = legs_pivot.scale.lerp(Vector2.ONE, delta * 10)
		legs_pivot.position = legs_pivot.position.lerp(Vector2.ZERO, delta * 10)

## ==================== 公开接口 ====================

func start_weapon_repositioning(_target_position: Vector2, target_rotation: float) -> void:
	if weapon_physics != null:
		weapon_physics.set_target(Vector2.ZERO, target_rotation)

func is_weapon_settled() -> bool:
	if weapon_physics != null:
		return weapon_physics.get_is_settled()
	return true

func get_weapon_settle_time() -> float:
	if weapon_physics != null:
		return weapon_physics.estimate_settle_time()
	return 0.0

func reset_weapon_position() -> void:
	if weapon_physics != null:
		weapon_physics.snap_to_rest()
	else:
		weapon_rig.rotation = 0

func get_weapon_physics() -> WeaponPhysics:
	return weapon_physics

func update_weapon_appearance(weapon: WeaponData) -> void:
	if weapon == null or weapon.weapon_type == WeaponData.WeaponType.UNARMED:
		if right_arm:
			right_arm.hide_weapon()
		if left_arm:
			left_arm.hide_weapon()
		return

	## 创建武器纹理
	var weapon_texture: Texture2D
	if weapon.weapon_texture != null:
		weapon_texture = weapon.weapon_texture
	else:
		weapon_texture = _create_weapon_texture_for_type(weapon.weapon_type, weapon.weapon_length)

	## 计算握柄偏移
	var grip_offset = weapon.grip_point_main
	if grip_offset == Vector2.ZERO:
		grip_offset = Vector2(0, weapon.weapon_length * 0.3)

	## 设置右手武器
	if right_arm:
		right_arm.set_weapon(weapon_texture, grip_offset, -PI/2)
		right_arm.show_weapon()

	## 双持时设置左手武器
	if weapon.is_dual_wield() and left_arm:
		left_arm.set_weapon(weapon_texture, grip_offset, -PI/2)
		left_arm.show_weapon()
	elif left_arm:
		left_arm.hide_weapon()

	## 更新武器物理参数
	if weapon_physics != null:
		weapon_physics.update_physics_from_weapon(weapon)

## 【优化】使用查找表替代 match 链
static var _weapon_visual_config: Dictionary = {
	# weapon_type: [width, color, length_override (-1 = use weapon_length)]
	WeaponData.WeaponType.GREATSWORD: [12, Color(0.6, 0.6, 0.7), -1],
	WeaponData.WeaponType.DUAL_BLADE: [8, Color(0.7, 0.7, 0.8), -1],
	WeaponData.WeaponType.SPEAR: [6, Color(0.5, 0.4, 0.3), -1],
	WeaponData.WeaponType.DAGGER: [6, Color(0.8, 0.8, 0.8), 25],
	WeaponData.WeaponType.STAFF: [8, Color(0.4, 0.3, 0.2), -1],
	WeaponData.WeaponType.SWORD: [8, Color(0.7, 0.7, 0.7), -1],
}

func _create_weapon_texture_for_type(weapon_type: int, weapon_length: float = 40.0) -> ImageTexture:
	var config = _weapon_visual_config.get(weapon_type, [8, Color(0.7, 0.7, 0.7), -1])
	var width: int = config[0]
	var color: Color = config[1]
	var length_override: int = config[2]
	var length: int = length_override if length_override > 0 else int(weapon_length)

	return _get_or_create_rect_texture(width, length, color)

func play_hit_effect() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.RED, 0.05)
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)

func play_attack_effect(attack: AttackData) -> void:
	if attack == null:
		return
	if combat_animator != null:
		combat_animator.play_attack(attack)

func apply_weapon_impulse(_impulse: Vector2) -> void:
	pass

func apply_weapon_angular_impulse(angular_impulse: float) -> void:
	if weapon_physics != null:
		weapon_physics.apply_angular_impulse(angular_impulse)

func get_left_arm() -> ArmRig:
	return left_arm

func get_right_arm() -> ArmRig:
	return right_arm

func get_combat_animator() -> CombatAnimator:
	return combat_animator

func get_body_animation_controller() -> BodyAnimationController:
	return body_animation_controller

func set_arms_visible(visible_flag: bool) -> void:
	if left_arm:
		left_arm.set_arm_visible(visible_flag)
	if right_arm:
		right_arm.set_arm_visible(visible_flag)

func set_arms_color(color: Color) -> void:
	if left_arm:
		left_arm.set_arm_color(color)
	if right_arm:
		right_arm.set_arm_color(color)
