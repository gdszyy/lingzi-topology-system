class_name ArmRig extends Node2D
## 单条手臂的渲染和 IK 解算
## 手臂由上臂、前臂、手三部分组成
## 武器作为手的子节点
## 【优化重构】修复握柄对齐计算、消除冗余纹理生成、优化拖尾性能

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

## 武器显示增强参数
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

## 武器绑定参数
var weapon_grip_offset: Vector2 = Vector2.ZERO  ## 握柄偏移（从武器中心到握柄）
var weapon_base_rotation: float = -PI / 2       ## 武器基础旋转

## 绘制节点
var upper_arm_line: Line2D = null
var forearm_line: Line2D = null
var hand_node: Node2D = null
var hand_sprite: Sprite2D = null
var weapon_sprite: Sprite2D = null

## 武器拖尾 — 使用 Ring Buffer 替代 Array.pop_front()
var weapon_trail_line: Line2D = null
var _trail_buffer: PackedVector2Array = PackedVector2Array()
var _trail_write_index: int = 0
var _trail_count: int = 0
const TRAIL_MAX_POINTS: int = 8
const TRAIL_MIN_SPEED: float = 50.0

## 上一帧的武器位置，用于计算速度
var last_weapon_pos: Vector2 = Vector2.ZERO
var weapon_velocity: Vector2 = Vector2.ZERO

## 【新增】缓存的肩膀位置，避免每帧重复计算
var _cached_shoulder: Vector2 = Vector2.ZERO
var _shoulder_dirty: bool = true

## 【新增】手部纹理缓存（静态共享，避免每个 ArmRig 实例都生成一份）
static var _hand_texture_cache: Dictionary = {}  # key: "size_color" -> ImageTexture

func _ready() -> void:
	_trail_buffer.resize(TRAIL_MAX_POINTS)
	_create_arm_visuals()
	_initialize_positions()

func _create_arm_visuals() -> void:
	## 创建上臂
	upper_arm_line = _create_line2d("UpperArm", arm_width, arm_color, -2)
	add_child(upper_arm_line)

	## 创建前臂
	forearm_line = _create_line2d("Forearm", arm_width, arm_color, -1)
	add_child(forearm_line)

	## 创建手节点（武器的父节点）
	hand_node = Node2D.new()
	hand_node.name = "Hand"
	hand_node.z_index = 0
	add_child(hand_node)

	## 创建手的视觉
	hand_sprite = Sprite2D.new()
	hand_sprite.name = "HandSprite"
	hand_sprite.texture = _get_or_create_hand_texture()
	hand_node.add_child(hand_sprite)

	## 创建武器 Sprite（初始隐藏）
	weapon_sprite = Sprite2D.new()
	weapon_sprite.name = "WeaponSprite"
	weapon_sprite.visible = false
	weapon_sprite.z_index = 1
	hand_node.add_child(weapon_sprite)

	## 创建武器拖尾
	if weapon_trail_enabled:
		weapon_trail_line = Line2D.new()
		weapon_trail_line.name = "WeaponTrail"
		weapon_trail_line.width = 3.0
		weapon_trail_line.default_color = Color(1, 1, 1, 0.3)
		weapon_trail_line.z_index = -3
		add_child(weapon_trail_line)

## 工厂方法：创建 Line2D 节点，消除重复代码
func _create_line2d(node_name: String, width: float, color: Color, z: int) -> Line2D:
	var line = Line2D.new()
	line.name = node_name
	line.width = width
	line.default_color = color
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.add_point(Vector2.ZERO)
	line.add_point(Vector2.ZERO)
	line.z_index = z
	return line

## 【优化】使用静态缓存避免重复生成手部纹理
func _get_or_create_hand_texture() -> ImageTexture:
	var cache_key = "%d_%s" % [int(hand_size), arm_color.to_html()]
	if _hand_texture_cache.has(cache_key):
		return _hand_texture_cache[cache_key]

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

	var tex = ImageTexture.create_from_image(image)
	_hand_texture_cache[cache_key] = tex
	return tex

func _initialize_positions() -> void:
	_shoulder_dirty = true
	var shoulder = _get_shoulder()
	var sign_x = -1.0 if is_left_arm else 1.0
	target_hand_pos = shoulder + Vector2(5 * sign_x, 18)
	current_hand_pos = target_hand_pos
	target_hand_rotation = 0.0
	current_hand_rotation = 0.0
	_update_ik()

func _process(delta: float) -> void:
	## 平滑移动手到目标位置
	var lerp_weight = minf(ik_smoothing * delta, 1.0)  # 【修复】防止 lerp 权重超过 1.0
	current_hand_pos = current_hand_pos.lerp(target_hand_pos, lerp_weight)
	current_hand_rotation = lerp(current_hand_rotation, target_hand_rotation, lerp_weight)

	_update_ik()
	_update_visuals()

	## 更新武器拖尾
	if weapon_trail_enabled and weapon_sprite and weapon_sprite.visible:
		_update_weapon_trail(delta)

## 【优化】缓存肩膀位置，避免每帧重复计算
func _get_shoulder() -> Vector2:
	if _shoulder_dirty:
		var sign_x = -1.0 if is_left_arm else 1.0
		_cached_shoulder = Vector2(shoulder_offset.x * sign_x, shoulder_offset.y)
		_shoulder_dirty = false
	return _cached_shoulder

func _update_ik() -> void:
	## Two-Bone IK 解算
	var sign_x = -1.0 if is_left_arm else 1.0
	var shoulder = _get_shoulder()

	current_elbow_pos = _solve_two_bone_ik(
		shoulder,
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
	var shoulder = _get_shoulder()

	## 更新上臂
	if upper_arm_line:
		upper_arm_line.set_point_position(0, shoulder)
		upper_arm_line.set_point_position(1, current_elbow_pos)

	## 更新前臂
	if forearm_line:
		forearm_line.set_point_position(0, current_elbow_pos)
		forearm_line.set_point_position(1, current_hand_pos)

	## 【关键修复】更新手节点位置和旋转
	if hand_node:
		hand_node.position = current_hand_pos
		hand_node.rotation = current_hand_rotation

		## 确保武器精灵的位置与握柄对齐
		if weapon_sprite and weapon_sprite.visible:
			_update_weapon_alignment()

	hand_position_changed.emit(current_hand_pos)

## 【关键修复】武器握柄对齐 — 修复双重旋转 bug
## 原实现中 weapon_sprite.rotation 和 hand_node.rotation 叠加导致偏移
## 修复方案：weapon_sprite 的旋转是相对于 hand_node 的局部旋转
func _update_weapon_alignment() -> void:
	if weapon_sprite == null:
		return

	## 武器精灵是 hand_node 的子节点，hand_node 已经有了 current_hand_rotation
	## 所以 weapon_sprite 只需要设置 weapon_base_rotation 即可
	## 不需要再加上 hand_node.rotation（那是父节点自动继承的）
	weapon_sprite.rotation = weapon_base_rotation

	## 握柄偏移需要在武器的局部坐标系中旋转
	## weapon_grip_offset 是从武器中心到握柄的向量
	## 我们需要将武器移动使握柄对齐到手部原点
	var grip_rotated = weapon_grip_offset.rotated(weapon_base_rotation)
	weapon_sprite.position = -grip_rotated

## 【优化】使用 Ring Buffer 替代 Array.pop_front() 避免 O(n) 移动
func _update_weapon_trail(delta: float) -> void:
	if weapon_sprite == null or weapon_trail_line == null:
		return

	var weapon_global_pos = weapon_sprite.global_position

	## 计算武器速度
	weapon_velocity = (weapon_global_pos - last_weapon_pos) / maxf(delta, 0.001)
	last_weapon_pos = weapon_global_pos

	## 只在武器移动速度足够快时添加拖尾点
	if weapon_velocity.length() > TRAIL_MIN_SPEED:
		_trail_buffer[_trail_write_index] = weapon_global_pos
		_trail_write_index = (_trail_write_index + 1) % TRAIL_MAX_POINTS
		_trail_count = mini(_trail_count + 1, TRAIL_MAX_POINTS)
		weapon_trail_line.default_color.a = 0.3  # 重置透明度

	## 更新拖尾线
	weapon_trail_line.clear_points()
	if _trail_count > 0:
		## 从最旧的点开始读取
		var start_index = (_trail_write_index - _trail_count + TRAIL_MAX_POINTS) % TRAIL_MAX_POINTS
		for i in range(_trail_count):
			var idx = (start_index + i) % TRAIL_MAX_POINTS
			weapon_trail_line.add_point(_trail_buffer[idx] - global_position)

		## 拖尾逐渐消失
		weapon_trail_line.default_color.a = maxf(0.0, weapon_trail_line.default_color.a - 0.15 * delta)
	else:
		weapon_trail_line.default_color.a = 0.0

## 设置手的目标位置
func set_hand_target(target: Vector2, hand_rotation: float = 0.0) -> void:
	## 【修复】限制手部最大位移半径，防止"飞出去"
	var shoulder = _get_shoulder()
	var to_target = target - shoulder
	var max_reach = (upper_arm_length + forearm_length) * 0.95  ## 留一点余量防止完全伸直

	if to_target.length() > max_reach:
		target_hand_pos = shoulder + to_target.normalized() * max_reach
	else:
		target_hand_pos = target

	target_hand_rotation = hand_rotation

## 立即设置手的位置（跳过插值）
func snap_hand_to(target: Vector2, hand_rotation: float = 0.0) -> void:
	target_hand_pos = target
	current_hand_pos = target
	target_hand_rotation = hand_rotation
	current_hand_rotation = hand_rotation
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

		## 保存握柄偏移用于位置计算
		weapon_grip_offset = grip_offset
		weapon_base_rotation = weapon_rotation

		weapon_sprite.visible = texture != null

		## 初始化武器显示效果
		weapon_sprite.scale = Vector2.ONE
		weapon_sprite.modulate = Color.WHITE

		## 立即更新武器位置确保握柄对齐
		if weapon_sprite.visible:
			_update_weapon_alignment()

## 隐藏武器
func hide_weapon() -> void:
	if weapon_sprite:
		weapon_sprite.visible = false

## 显示武器
func show_weapon() -> void:
	if weapon_sprite:
		weapon_sprite.visible = true

## 【修复】设置武器旋转 — 原实现为空 pass，现在正确实现
## 注意：这里设置的是武器的基础旋转，不是手的旋转
func set_weapon_rotation(new_rotation: float) -> void:
	weapon_base_rotation = new_rotation
	if weapon_sprite and weapon_sprite.visible:
		_update_weapon_alignment()

## 设置武器缩放（用于挥舞时的视觉增强）
func set_weapon_scale(scale_factor: float) -> void:
	if weapon_sprite:
		weapon_sprite.scale = Vector2(scale_factor, scale_factor)

## 设置武器发光
func set_weapon_glow(intensity: float) -> void:
	if weapon_sprite:
		var glow_color = Color.WHITE.lerp(Color.YELLOW, intensity * 0.5)
		weapon_sprite.modulate = glow_color.lerp(Color.WHITE, 1.0 - intensity)
		weapon_sprite.self_modulate = Color(1.0 + intensity * 0.3, 1.0 + intensity * 0.3, 1.0 + intensity * 0.2, 1.0)

## 播放武器挥舞动画
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
	_shoulder_dirty = true  # 标记需要刷新
	if upper_arm_line:
		upper_arm_line.default_color = color
	if forearm_line:
		forearm_line.default_color = color
	if hand_sprite:
		hand_sprite.texture = _get_or_create_hand_texture()

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
	return _get_shoulder()

## 获取肘部位置
func get_elbow_position() -> Vector2:
	return current_elbow_pos

## 获取武器速度
func get_weapon_velocity() -> Vector2:
	return weapon_velocity

## 清除武器拖尾
func clear_weapon_trail() -> void:
	_trail_count = 0
	_trail_write_index = 0
	if weapon_trail_line:
		weapon_trail_line.clear_points()

## 获取武器握柄偏移
func get_weapon_grip_offset() -> Vector2:
	return weapon_grip_offset

## 获取武器基础旋转
func get_weapon_base_rotation() -> float:
	return weapon_base_rotation
