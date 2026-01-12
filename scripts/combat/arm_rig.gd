class_name ArmRig extends Node2D
## 单条手臂的渲染和 IK 解算
## 手臂由上臂、前臂、手三部分组成
## 武器作为手的子节点
## 【优化】改进武器与手的绑定关系，确保握柄正确对齐

signal hand_position_changed(position: Vector2)

## 手臂配置
@export_group("Arm Configuration")
@export var is_left_arm: bool = false           ## 是否为左臂
@export var upper_arm_length: float = 18.0      ## 上臂长度
@export var forearm_length: float = 16.0        ## 前臂长度
@export var arm_color: Color = Color(0.9, 0.75, 0.6)
@export var arm_width: float = 6.0
@export var hand_size: float = 8.0              ## 手的大小

@export_group("Shoulder Position")
@export var shoulder_offset: Vector2 = Vector2(12, 0)  ## 肩膀相对于躯干的偏移

@export_group("IK Settings")
@export var ik_smoothing: float = 15.0
@export var elbow_bend_factor: float = 1.0      ## 肘部弯曲方向 (正=向外弯)

## 【新增】武器显示增强参数
@export_group("Weapon Display Enhancement")
@export var weapon_scale_on_swing: float = 1.1  ## 挥舞时武器缩放倍数
@export var weapon_glow_intensity: float = 0.0  ## 武器发光强度（0-1）
@export var weapon_trail_enabled: bool = true   ## 是否启用武器拖尾

## 内部状态
var current_hand_pos: Vector2 = Vector2.ZERO    ## 当前手的位置
var target_hand_pos: Vector2 = Vector2.ZERO     ## 目标手的位置
var current_elbow_pos: Vector2 = Vector2.ZERO   ## 当前肘的位置
var current_hand_rotation: float = 0.0          ## 手的旋转
var target_hand_rotation: float = 0.0           ## 目标手旋转

## 【新增】武器绑定参数
var weapon_grip_offset: Vector2 = Vector2.ZERO  ## 握柄偏移（从武器中心到握柄）
var weapon_base_rotation: float = -PI / 2       ## 武器基础旋转

## 绘制节点
var upper_arm_line: Line2D = null
var forearm_line: Line2D = null
var hand_node: Node2D = null
var hand_sprite: Sprite2D = null
var weapon_sprite: Sprite2D = null

## 【新增】武器拖尾
var weapon_trail_points: Array[Vector2] = []
var weapon_trail_max_points: int = 8
var weapon_trail_line: Line2D = null

## 【新增】上一帧的武器位置，用于计算速度
var last_weapon_pos: Vector2 = Vector2.ZERO
var weapon_velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
	_create_arm_visuals()
	_initialize_positions()

func _create_arm_visuals() -> void:
	## 创建上臂
	upper_arm_line = Line2D.new()
	upper_arm_line.name = "UpperArm"
	upper_arm_line.width = arm_width
	upper_arm_line.default_color = arm_color
	upper_arm_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	upper_arm_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	upper_arm_line.add_point(Vector2.ZERO)
	upper_arm_line.add_point(Vector2.ZERO)
	upper_arm_line.z_index = -2
	add_child(upper_arm_line)
	
	## 创建前臂
	forearm_line = Line2D.new()
	forearm_line.name = "Forearm"
	forearm_line.width = arm_width
	forearm_line.default_color = arm_color
	forearm_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	forearm_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	forearm_line.add_point(Vector2.ZERO)
	forearm_line.add_point(Vector2.ZERO)
	forearm_line.z_index = -1
	add_child(forearm_line)
	
	## 创建手节点（武器的父节点）
	hand_node = Node2D.new()
	hand_node.name = "Hand"
	hand_node.z_index = 0
	add_child(hand_node)
	
	## 创建手的视觉
	hand_sprite = Sprite2D.new()
	hand_sprite.name = "HandSprite"
	hand_sprite.texture = _create_hand_texture()
	hand_node.add_child(hand_sprite)
	
	## 创建武器 Sprite（初始隐藏）
	weapon_sprite = Sprite2D.new()
	weapon_sprite.name = "WeaponSprite"
	weapon_sprite.visible = false
	weapon_sprite.z_index = 1
	hand_node.add_child(weapon_sprite)
	
	## 【新增】创建武器拖尾
	if weapon_trail_enabled:
		weapon_trail_line = Line2D.new()
		weapon_trail_line.name = "WeaponTrail"
		weapon_trail_line.width = 3.0
		weapon_trail_line.default_color = Color(1, 1, 1, 0.3)
		weapon_trail_line.z_index = -3
		add_child(weapon_trail_line)

func _create_hand_texture() -> ImageTexture:
	var size = int(hand_size)
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center = Vector2(size / 2.0, size / 2.0)
	var radius = size / 2.0
	
	for x in range(size):
		for y in range(size):
			var pos = Vector2(x, y)
			if pos.distance_to(center) <= radius:
				image.set_pixel(x, y, arm_color)
			else:
				image.set_pixel(x, y, Color(0, 0, 0, 0))
	
	return ImageTexture.create_from_image(image)

func _initialize_positions() -> void:
	## 计算初始手位置（放松状态）
	var sign_x = -1.0 if is_left_arm else 1.0
	var actual_shoulder = Vector2(shoulder_offset.x * sign_x, shoulder_offset.y)
	target_hand_pos = actual_shoulder + Vector2(5 * sign_x, 18)
	current_hand_pos = target_hand_pos
	target_hand_rotation = 0.0
	current_hand_rotation = 0.0
	_update_ik()

func _process(delta: float) -> void:
	## 平滑移动手到目标位置
	current_hand_pos = current_hand_pos.lerp(target_hand_pos, ik_smoothing * delta)
	current_hand_rotation = lerp(current_hand_rotation, target_hand_rotation, ik_smoothing * delta)
	
	_update_ik()
	_update_visuals()
	
	## 【新增】更新武器拖尾
	if weapon_trail_enabled and weapon_sprite and weapon_sprite.visible:
		_update_weapon_trail(delta)

func _update_ik() -> void:
	## Two-Bone IK 解算
	var sign_x = -1.0 if is_left_arm else 1.0
	var actual_shoulder = Vector2(shoulder_offset.x * sign_x, shoulder_offset.y)
	
	current_elbow_pos = _solve_two_bone_ik(
		actual_shoulder,
		current_hand_pos,
		upper_arm_length,
		forearm_length,
		elbow_bend_factor * sign_x
	)

func _solve_two_bone_ik(shoulder: Vector2, hand: Vector2, upper_len: float, lower_len: float, bend_dir: float) -> Vector2:
	var to_hand = hand - shoulder
	var distance = to_hand.length()
	var total_length = upper_len + lower_len
	
	## 限制距离
	var min_distance = abs(upper_len - lower_len) * 0.1
	var max_distance = total_length * 0.98
	distance = clamp(distance, min_distance, max_distance)
	
	if distance < 0.001:
		return shoulder + Vector2(upper_len * bend_dir, 0)
	
	## 余弦定理
	var cos_angle = (distance * distance + upper_len * upper_len - lower_len * lower_len) / (2.0 * distance * upper_len)
	cos_angle = clamp(cos_angle, -1.0, 1.0)
	var angle = acos(cos_angle)
	
	var direction = to_hand.normalized()
	var elbow_direction = direction.rotated(angle * sign(bend_dir))
	
	return shoulder + elbow_direction * upper_len

func _update_visuals() -> void:
	var sign_x = -1.0 if is_left_arm else 1.0
	var actual_shoulder = Vector2(shoulder_offset.x * sign_x, shoulder_offset.y)
	
	## 更新上臂
	if upper_arm_line:
		upper_arm_line.set_point_position(0, actual_shoulder)
		upper_arm_line.set_point_position(1, current_elbow_pos)
	
	## 更新前臂
	if forearm_line:
		forearm_line.set_point_position(0, current_elbow_pos)
		forearm_line.set_point_position(1, current_hand_pos)
	
	## 【修复】更新手节点位置和旋转
	if hand_node:
		hand_node.position = current_hand_pos
		hand_node.rotation = current_hand_rotation
		
		## 【关键修复】确保武器精灵的位置与握柄对齐
		if weapon_sprite and weapon_sprite.visible:
			_update_weapon_position_and_rotation()
	
	hand_position_changed.emit(current_hand_pos)

## 【新增】更新武器位置和旋转 - 确保握柄对齐
func _update_weapon_position_and_rotation() -> void:
	if weapon_sprite == null:
		return
	
	## 武器精灵的位置应该使其握柄点对齐到手部位置
	## 握柄偏移是从武器中心到握柄的距离
	## 我们需要将武器移动，使得握柄点正好在原点（手部位置）
	
	## 武器的旋转是 weapon_base_rotation + hand_node.rotation
	var total_rotation = weapon_base_rotation + hand_node.rotation
	
	## 握柄在武器坐标系中的位置
	var grip_in_weapon_coords = weapon_grip_offset
	
	## 将握柄位置从武器坐标系转换到手坐标系
	## 由于武器旋转了，握柄位置也需要旋转
	var grip_rotated = grip_in_weapon_coords.rotated(total_rotation)
	
	## 武器精灵的偏移应该是负的握柄位置，这样握柄就会对齐到手部
	weapon_sprite.offset = -grip_rotated
	weapon_sprite.rotation = total_rotation

## 【新增】更新武器拖尾
func _update_weapon_trail(delta: float) -> void:
	if weapon_sprite == null or weapon_trail_line == null:
		return
	
	var weapon_global_pos = weapon_sprite.global_position
	
	## 计算武器速度
	weapon_velocity = (weapon_global_pos - last_weapon_pos) / delta
	last_weapon_pos = weapon_global_pos
	
	## 只在武器移动速度足够快时添加拖尾点
	if weapon_velocity.length() > 50:
		weapon_trail_points.append(weapon_global_pos)
		
		## 限制拖尾点数
		if weapon_trail_points.size() > weapon_trail_max_points:
			weapon_trail_points.pop_front()
	
	## 更新拖尾线
	weapon_trail_line.clear_points()
	for point in weapon_trail_points:
		weapon_trail_line.add_point(point - global_position)
	
	## 拖尾逐渐消失
	if weapon_trail_points.size() > 0:
		var fade_rate = 0.15  ## 衰减速率
		weapon_trail_line.default_color.a = max(0, weapon_trail_line.default_color.a - fade_rate * delta)
	else:
		weapon_trail_line.default_color.a = 0.3

## 设置手的目标位置
func set_hand_target(target: Vector2, rotation: float = 0.0) -> void:
	## 【修复】限制手部最大位移半径，防止"飞出去"
	var sign_x = -1.0 if is_left_arm else 1.0
	var actual_shoulder = Vector2(shoulder_offset.x * sign_x, shoulder_offset.y)
	
	## 计算相对于肩部的向量
	var to_target = target - actual_shoulder
	var max_reach = (upper_arm_length + forearm_length) * 0.95 ## 留一点余量防止完全伸直
	
	if to_target.length() > max_reach:
		target_hand_pos = actual_shoulder + to_target.normalized() * max_reach
	else:
		target_hand_pos = target
		
	target_hand_rotation = rotation

## 立即设置手的位置（跳过插值）
func snap_hand_to(target: Vector2, rotation: float = 0.0) -> void:
	target_hand_pos = target
	current_hand_pos = target
	target_hand_rotation = rotation
	current_hand_rotation = rotation
	_update_ik()
	_update_visuals()

## 获取手的当前位置
func get_hand_position() -> Vector2:
	return current_hand_pos

## 获取手节点（用于附着武器）
func get_hand_node() -> Node2D:
	return hand_node

## 获取武器 Sprite
func get_weapon_sprite() -> Sprite2D:
	return weapon_sprite

## 【修复】设置武器纹理和握柄偏移
func set_weapon(texture: Texture2D, grip_offset: Vector2, weapon_rotation: float = -PI/2) -> void:
	if weapon_sprite:
		weapon_sprite.texture = texture
		
		## 【关键修复】保存握柄偏移用于位置计算
		weapon_grip_offset = grip_offset
		weapon_base_rotation = weapon_rotation
		
		weapon_sprite.visible = texture != null
		
		## 【新增】初始化武器显示效果
		weapon_sprite.scale = Vector2.ONE
		weapon_sprite.modulate = Color.WHITE
		
		## 立即更新武器位置确保握柄对齐
		if weapon_sprite.visible:
			_update_weapon_position_and_rotation()

## 隐藏武器
func hide_weapon() -> void:
	if weapon_sprite:
		weapon_sprite.visible = false

## 显示武器
func show_weapon() -> void:
	if weapon_sprite:
		weapon_sprite.visible = true

## 设置武器旋转（相对于手）
func set_weapon_rotation(rotation: float) -> void:
	if weapon_sprite:
		## 【修复】不直接设置rotation，而是通过 hand_node.rotation 控制
		## 这样可以确保握柄偏移的计算正确
		pass

## 【新增】设置武器缩放（用于挥舞时的视觉增强）
func set_weapon_scale(scale: float) -> void:
	if weapon_sprite:
		weapon_sprite.scale = Vector2(scale, scale)

## 【新增】设置武器发光
func set_weapon_glow(intensity: float) -> void:
	if weapon_sprite:
		## 通过调整modulate实现发光效果
		var glow_color = Color.WHITE.lerp(Color.YELLOW, intensity * 0.5)
		weapon_sprite.modulate = glow_color.lerp(Color.WHITE, 1.0 - intensity)
		weapon_sprite.self_modulate = Color(1.0 + intensity * 0.3, 1.0 + intensity * 0.3, 1.0 + intensity * 0.2, 1.0)

## 【新增】播放武器挥舞动画
func play_weapon_swing_effect(duration: float = 0.3) -> void:
	if weapon_sprite == null:
		return
	
	var tween = create_tween()
	
	## 缩放效果
	tween.tween_property(weapon_sprite, "scale", Vector2(weapon_scale_on_swing, weapon_scale_on_swing), duration * 0.3)
	tween.tween_property(weapon_sprite, "scale", Vector2.ONE, duration * 0.7)
	
	## 同时播放发光效果
	if weapon_glow_intensity > 0:
		var tween2 = create_tween()
		tween2.tween_property(self, "weapon_glow_intensity", weapon_glow_intensity, duration * 0.3)
		tween2.tween_property(self, "weapon_glow_intensity", 0.0, duration * 0.7)

## 设置手臂颜色
func set_arm_color(color: Color) -> void:
	arm_color = color
	if upper_arm_line:
		upper_arm_line.default_color = color
	if forearm_line:
		forearm_line.default_color = color
	if hand_sprite:
		hand_sprite.texture = _create_hand_texture()

## 设置手臂可见性
func set_arm_visible(visible_flag: bool) -> void:
	if upper_arm_line:
		upper_arm_line.visible = visible_flag
	if forearm_line:
		forearm_line.visible = visible_flag
	if hand_sprite:
		hand_sprite.visible = visible_flag

## 获取肩膀位置
func get_shoulder_position() -> Vector2:
	var sign_x = -1.0 if is_left_arm else 1.0
	return Vector2(shoulder_offset.x * sign_x, shoulder_offset.y)

## 获取肘部位置
func get_elbow_position() -> Vector2:
	return current_elbow_pos

## 【新增】获取武器速度
func get_weapon_velocity() -> Vector2:
	return weapon_velocity

## 【新增】清除武器拖尾
func clear_weapon_trail() -> void:
	weapon_trail_points.clear()
	if weapon_trail_line:
		weapon_trail_line.clear_points()

## 【新增】获取武器握柄偏移
func get_weapon_grip_offset() -> Vector2:
	return weapon_grip_offset

## 【新增】获取武器基础旋转
func get_weapon_base_rotation() -> float:
	return weapon_base_rotation
