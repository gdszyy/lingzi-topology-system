class_name PlayerVisuals extends Node2D
## 玩家视觉系统
## 管理角色的视觉渲染，包括躯干、头部、手臂和武器
## 【修复】移除冗余的武器挥舞逻辑，统一由 CombatAnimator 驱动
## 【新增】集成 BodyAnimationController 实现移动和飞行时的全身骨骼动画

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

## 【新增】全身骨骼动画控制器
var body_animation_controller: BodyAnimationController = null

var player: PlayerController = null

var is_walking: bool = false
var walk_cycle: float = 0.0
var walk_speed: float = 10.0

func _ready() -> void:
	player = get_parent() as PlayerController
	_setup_default_visuals()
	_create_arm_rigs()
	_setup_combat_animator()
	_setup_body_animation_controller()  ## 【新增】
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
	combat_animator.animation_started.connect(_on_attack_animation_started)  ## 【新增】

## 【新增】设置全身骨骼动画控制器
func _setup_body_animation_controller() -> void:
	body_animation_controller = BodyAnimationController.new()
	body_animation_controller.name = "BodyAnimationController"
	add_child(body_animation_controller)
	
	## 【修复】先设置 CombatAnimator 引用，避免循环引用
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
	
	## 连接状态变化信号（可选，用于调试或其他用途）
	body_animation_controller.animation_state_changed.connect(_on_body_animation_state_changed)

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
	if combat_animator != null:
		combat_animator.set_weapon(weapon)

func _on_weapon_settled() -> void:
	if player != null and player.has_signal("weapon_settled"):
		player.emit_signal("weapon_settled")

func _on_weapon_position_changed(_pos: Vector2, _rot: float) -> void:
	pass

## 【新增】攻击动画开始时的回调
func _on_attack_animation_started(_attack: AttackData) -> void:
	## 通知 BodyAnimationController 攻击动画开始
	if body_animation_controller != null:
		body_animation_controller.on_combat_animation_started()

func _on_attack_animation_finished(_attack: AttackData) -> void:
	## 【修复】动画结束后重置武器物理状态
	if weapon_physics != null:
		weapon_physics.set_to_rest()
	
	## 【新增】通知 BodyAnimationController 攻击动画结束
	if body_animation_controller != null:
		body_animation_controller.on_combat_animation_finished()

func _on_hit_frame_reached(_attack: AttackData) -> void:
	## 可以在这里触发命中检测
	pass

## 【新增】全身动画状态变化回调
func _on_body_animation_state_changed(state: BodyAnimationController.AnimationState) -> void:
	## 可以在这里添加状态变化时的特效或音效
	pass

func _process(delta: float) -> void:
	_update_walk_animation(delta)
	_update_legs_animation(delta)  ## 【新增】增强的腿部动画

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
	
	## 【修改】简化躯干动画，主要动画由 BodyAnimationController 处理
	## 这里只保留基础的躯干位置更新，避免与 BodyAnimationController 冲突
	
	var speed = player.velocity.length()
	is_walking = speed > 10
	
	## 躯干的主要动画效果现在由 BodyAnimationController 处理
	## 这里只做基础的重置
	if not is_walking and not player.is_flying:
		## 待机时平滑回到默认位置
		torso_pivot.position.y = lerp(torso_pivot.position.y, 0.0, delta * 10)

## 【新增】增强的腿部动画
func _update_legs_animation(delta: float) -> void:
	if player == null:
		return
	
	var speed = player.velocity.length()
	var is_moving = speed > 10
	
	if player.is_flying:
		## 飞行时腿部收起
		var target_scale = Vector2(0.8, 0.7)
		legs_pivot.scale = legs_pivot.scale.lerp(target_scale, delta * 8)
		
		## 飞行时腿部略微向后
		var velocity_dir = player.velocity.normalized() if speed > 10 else Vector2.ZERO
		var face_dir = player.current_facing_direction
		var relative_velocity = velocity_dir.rotated(-face_dir.angle())
		
		## 根据飞行方向调整腿部位置
		var leg_offset = Vector2(0, 5 + relative_velocity.y * 3)
		legs_pivot.position = legs_pivot.position.lerp(leg_offset, delta * 5)
	elif is_moving:
		## 移动时腿部动画
		walk_cycle += delta * walk_speed * (speed / 300.0)
		
		## 腿部伸缩模拟行走
		var leg_stretch = 1.0 + sin(walk_cycle * 2) * 0.08 * (speed / 300.0)
		legs_pivot.scale.y = lerp(legs_pivot.scale.y, leg_stretch, delta * 15)
		legs_pivot.scale.x = lerp(legs_pivot.scale.x, 1.0, delta * 10)
		
		## 腿部位置回到默认
		legs_pivot.position = legs_pivot.position.lerp(Vector2.ZERO, delta * 10)
	else:
		## 待机时腿部恢复默认
		legs_pivot.scale = legs_pivot.scale.lerp(Vector2.ONE, delta * 10)
		legs_pivot.position = legs_pivot.position.lerp(Vector2.ZERO, delta * 10)

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
	if weapon_physics != null:
		weapon_physics.snap_to_rest()
	else:
		weapon_rig.rotation = 0

## 获取武器物理节点
func get_weapon_physics() -> WeaponPhysics:
	return weapon_physics

func update_weapon_appearance(weapon: WeaponData) -> void:
	if weapon == null or weapon.weapon_type == WeaponData.WeaponType.UNARMED:
		## 徒手：隐藏武器
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
	
	## 计算握柄偏移（武器纹理的中心到握柄的距离）
	var grip_offset = Vector2(0, weapon.weapon_length * 0.4)
	
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

func _create_weapon_texture_for_type(weapon_type: int, weapon_length: float = 40.0) -> ImageTexture:
	## 创建武器纹理，刀尖向下（+Y），这样旋转 -90° 后刀尖向右
	var length = int(weapon_length)
	var width: int
	var color: Color
	
	match weapon_type:
		WeaponData.WeaponType.GREATSWORD:
			width = 12
			color = Color(0.6, 0.6, 0.7)
		WeaponData.WeaponType.DUAL_BLADE:
			width = 8
			color = Color(0.7, 0.7, 0.8)
		WeaponData.WeaponType.SPEAR:
			width = 6
			color = Color(0.5, 0.4, 0.3)
		WeaponData.WeaponType.DAGGER:
			width = 6
			length = 25
			color = Color(0.8, 0.8, 0.8)
		WeaponData.WeaponType.STAFF:
			width = 8
			color = Color(0.4, 0.3, 0.2)
		WeaponData.WeaponType.SWORD:
			width = 8
			color = Color(0.7, 0.7, 0.7)
		_:
			width = 8
			color = Color(0.7, 0.7, 0.7)
	
	return _create_rect_texture(width, length, color)

func play_hit_effect() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.RED, 0.05)
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)

## 【修复】简化攻击效果播放，完全由 CombatAnimator 驱动
func play_attack_effect(attack: AttackData) -> void:
	if attack == null:
		return
	
	## 使用战斗动画系统驱动攻击动画
	if combat_animator != null:
		combat_animator.play_attack(attack)

## 施加武器冲量（已禁用，保留接口兼容）
func apply_weapon_impulse(_impulse: Vector2) -> void:
	pass

## 施加武器角冲量
func apply_weapon_angular_impulse(angular_impulse: float) -> void:
	if weapon_physics != null:
		weapon_physics.apply_angular_impulse(angular_impulse)

## 获取左臂
func get_left_arm() -> ArmRig:
	return left_arm

## 获取右臂
func get_right_arm() -> ArmRig:
	return right_arm

## 获取战斗动画控制器
func get_combat_animator() -> CombatAnimator:
	return combat_animator

## 【新增】获取全身动画控制器
func get_body_animation_controller() -> BodyAnimationController:
	return body_animation_controller

## 设置手臂可见性
func set_arms_visible(visible_flag: bool) -> void:
	if left_arm:
		left_arm.set_arm_visible(visible_flag)
	if right_arm:
		right_arm.set_arm_visible(visible_flag)

## 设置手臂颜色
func set_arms_color(color: Color) -> void:
	if left_arm:
		left_arm.set_arm_color(color)
	if right_arm:
		right_arm.set_arm_color(color)
