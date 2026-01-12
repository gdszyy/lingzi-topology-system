# player_visuals.gd
# 玩家视觉组件 - 管理角色的视觉表现
class_name PlayerVisuals extends Node2D

## 节点引用
@onready var legs_pivot: Node2D = $LegsPivot
@onready var legs_sprite: Sprite2D = $LegsPivot/LegsSprite
@onready var torso_pivot: Node2D = $TorsoPivot
@onready var torso_sprite: Sprite2D = $TorsoPivot/TorsoSprite
@onready var head_sprite: Sprite2D = $TorsoPivot/HeadSprite
@onready var weapon_rig: Node2D = $TorsoPivot/WeaponRig
@onready var main_hand_weapon: Sprite2D = $TorsoPivot/WeaponRig/MainHandWeapon
@onready var off_hand_weapon: Sprite2D = $TorsoPivot/WeaponRig/OffHandWeapon

## 玩家控制器引用
var player: PlayerController = null

## 动画状态
var is_walking: bool = false
var walk_cycle: float = 0.0
var walk_speed: float = 10.0

## 武器挥动状态
var is_swinging: bool = false
var swing_progress: float = 0.0
var swing_start_angle: float = 0.0
var swing_end_angle: float = 0.0
var swing_duration: float = 0.0

func _ready() -> void:
	player = get_parent() as PlayerController
	_setup_default_visuals()

func _process(delta: float) -> void:
	_update_walk_animation(delta)
	_update_weapon_swing(delta)

## 设置默认视觉效果
func _setup_default_visuals() -> void:
	# 创建简单的占位图形
	_create_placeholder_sprites()

## 创建占位精灵
func _create_placeholder_sprites() -> void:
	# 腿部 - 椭圆形
	if legs_sprite != null:
		var legs_texture = _create_ellipse_texture(20, 30, Color(0.6, 0.4, 0.2))
		legs_sprite.texture = legs_texture
	
	# 躯干 - 圆形
	if torso_sprite != null:
		var torso_texture = _create_circle_texture(24, Color(0.3, 0.5, 0.8))
		torso_sprite.texture = torso_texture
	
	# 头部 - 小圆形
	if head_sprite != null:
		var head_texture = _create_circle_texture(16, Color(0.9, 0.75, 0.6))
		head_sprite.texture = head_texture
	
	# 武器 - 矩形
	if main_hand_weapon != null:
		var weapon_texture = _create_rect_texture(8, 40, Color(0.7, 0.7, 0.7))
		main_hand_weapon.texture = weapon_texture

## 创建圆形纹理
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

## 创建椭圆形纹理
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

## 创建矩形纹理
func _create_rect_texture(width: int, height: int, color: Color) -> ImageTexture:
	var image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)

## 更新行走动画
func _update_walk_animation(delta: float) -> void:
	if player == null:
		return
	
	var speed = player.velocity.length()
	is_walking = speed > 10
	
	if is_walking:
		walk_cycle += delta * walk_speed * (speed / 300.0)
		
		# 简单的上下摆动
		var bob = sin(walk_cycle) * 2
		torso_pivot.position.y = bob
		
		# 腿部摆动
		var leg_swing = sin(walk_cycle) * 0.1
		legs_pivot.scale.y = 1.0 + leg_swing * 0.1
	else:
		# 平滑回到原位
		torso_pivot.position.y = lerp(torso_pivot.position.y, 0.0, delta * 10)
		legs_pivot.scale.y = lerp(legs_pivot.scale.y, 1.0, delta * 10)

## 更新武器挥动
func _update_weapon_swing(delta: float) -> void:
	if not is_swinging:
		return
	
	swing_progress += delta / swing_duration
	
	if swing_progress >= 1.0:
		is_swinging = false
		swing_progress = 1.0
	
	# 计算当前角度
	var current_angle = lerp(swing_start_angle, swing_end_angle, swing_progress)
	weapon_rig.rotation = deg_to_rad(current_angle)

## 开始武器挥动
func start_weapon_swing(start_angle: float, end_angle: float, duration: float) -> void:
	is_swinging = true
	swing_progress = 0.0
	swing_start_angle = start_angle
	swing_end_angle = end_angle
	swing_duration = duration

## 重置武器位置
func reset_weapon_position() -> void:
	is_swinging = false
	weapon_rig.rotation = 0

## 更新武器外观
func update_weapon_appearance(weapon: WeaponData) -> void:
	if weapon == null:
		main_hand_weapon.visible = false
		off_hand_weapon.visible = false
		return
	
	# 更新主手武器
	if weapon.weapon_texture != null:
		main_hand_weapon.texture = weapon.weapon_texture
	else:
		# 根据武器类型创建默认外观
		var weapon_texture = _create_weapon_texture_for_type(weapon.weapon_type)
		main_hand_weapon.texture = weapon_texture
	
	main_hand_weapon.offset = weapon.weapon_offset
	main_hand_weapon.scale = weapon.weapon_scale
	main_hand_weapon.visible = weapon.weapon_type != WeaponData.WeaponType.UNARMED
	
	# 双手武器隐藏副手
	off_hand_weapon.visible = weapon.is_dual_wield()

## 根据武器类型创建纹理
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

## 播放受击效果
func play_hit_effect() -> void:
	# 闪烁效果
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.RED, 0.05)
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)

## 播放攻击效果
func play_attack_effect(attack: AttackData) -> void:
	if attack == null:
		return
	
	# 开始武器挥动
	start_weapon_swing(
		attack.swing_start_angle,
		attack.swing_end_angle,
		attack.windup_time + attack.active_time
	)
