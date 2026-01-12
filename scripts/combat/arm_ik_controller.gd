class_name ArmIKController extends Node2D
## 手臂 IK 控制器
## 使用 Two-Bone IK 算法让手臂跟随武器握点
## 支持左右手臂的独立控制

signal arm_updated(arm_name: String, shoulder_pos: Vector2, elbow_pos: Vector2, hand_pos: Vector2)

## 手臂配置
@export_group("Arm Configuration")
@export var upper_arm_length: float = 18.0  ## 上臂长度（肩到肘）
@export var forearm_length: float = 16.0    ## 前臂长度（肘到手）
@export var arm_color: Color = Color(0.9, 0.75, 0.6)  ## 手臂颜色（肤色）
@export var arm_width: float = 6.0          ## 手臂宽度

@export_group("Shoulder Positions")
@export var left_shoulder_offset: Vector2 = Vector2(-12, 0)   ## 左肩相对于躯干的偏移
@export var right_shoulder_offset: Vector2 = Vector2(12, 0)   ## 右肩相对于躯干的偏移

@export_group("IK Settings")
@export var ik_smoothing: float = 15.0      ## IK 平滑系数
@export var elbow_bend_direction: float = 1.0  ## 肘部弯曲方向 (1=向外, -1=向内)
@export var min_reach_ratio: float = 0.1    ## 最小伸展比例
@export var max_reach_ratio: float = 0.98   ## 最大伸展比例（避免完全伸直）

## 内部状态
var left_elbow_pos: Vector2 = Vector2.ZERO
var right_elbow_pos: Vector2 = Vector2.ZERO
var left_hand_pos: Vector2 = Vector2.ZERO
var right_hand_pos: Vector2 = Vector2.ZERO

## 目标位置（由武器系统设置）
var left_hand_target: Vector2 = Vector2.ZERO
var right_hand_target: Vector2 = Vector2.ZERO

## 引用
var weapon_physics: WeaponPhysics = null
var player_visuals: Node2D = null

## 绘制节点
var left_upper_arm: Line2D = null
var left_forearm: Line2D = null
var left_hand_sprite: Sprite2D = null
var right_upper_arm: Line2D = null
var right_forearm: Line2D = null
var right_hand_sprite: Sprite2D = null

func _ready() -> void:
	_create_arm_visuals()
	_find_references()
	
	## 初始化手部位置到默认位置
	left_hand_target = left_shoulder_offset + Vector2(-10, 15)
	right_hand_target = right_shoulder_offset + Vector2(20, 0)

func _find_references() -> void:
	## 查找 WeaponPhysics 节点
	## 节点层级: Player/Visuals/TorsoPivot/ArmIKController
	## WeaponPhysics 在: Player/Visuals/TorsoPivot/WeaponRig/WeaponPhysics
	var torso_pivot = get_parent()
	if torso_pivot:
		var weapon_rig = torso_pivot.get_node_or_null("WeaponRig")
		if weapon_rig:
			weapon_physics = weapon_rig.get_node_or_null("WeaponPhysics") as WeaponPhysics
		
		player_visuals = torso_pivot.get_parent()

func _create_arm_visuals() -> void:
	## 创建左臂视觉元素
	left_upper_arm = _create_arm_segment("LeftUpperArm")
	left_forearm = _create_arm_segment("LeftForearm")
	left_hand_sprite = _create_hand_sprite("LeftHand")
	
	## 创建右臂视觉元素
	right_upper_arm = _create_arm_segment("RightUpperArm")
	right_forearm = _create_arm_segment("RightForearm")
	right_hand_sprite = _create_hand_sprite("RightHand")
	
	## 设置绘制顺序（手臂在武器后面）
	left_upper_arm.z_index = -2
	left_forearm.z_index = -1
	left_hand_sprite.z_index = 0
	right_upper_arm.z_index = -2
	right_forearm.z_index = -1
	right_hand_sprite.z_index = 0

func _create_arm_segment(segment_name: String) -> Line2D:
	var line = Line2D.new()
	line.name = segment_name
	line.width = arm_width
	line.default_color = arm_color
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.add_point(Vector2.ZERO)
	line.add_point(Vector2.ZERO)
	add_child(line)
	return line

func _create_hand_sprite(hand_name: String) -> Sprite2D:
	var sprite = Sprite2D.new()
	sprite.name = hand_name
	sprite.texture = _create_hand_texture()
	add_child(sprite)
	return sprite

func _create_hand_texture() -> ImageTexture:
	## 创建一个圆形手部纹理
	var size = int(arm_width * 1.5)
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

func _process(delta: float) -> void:
	_update_hand_targets()
	_solve_ik(delta)
	_update_arm_visuals()

func _update_hand_targets() -> void:
	if weapon_physics == null:
		return
	
	## 获取武器的当前旋转
	var weapon_rotation = weapon_physics.rotation
	
	## 获取武器握点位置（从武器数据或使用默认值）
	var main_grip = Vector2(15, 0)  ## 主手握点（靠近武器中心）
	var off_grip = Vector2(5, 0)    ## 副手握点（靠近武器根部）
	
	## 尝试从玩家控制器获取武器数据
	if weapon_physics.player != null and weapon_physics.player is PlayerController:
		var player_controller = weapon_physics.player as PlayerController
		if player_controller.current_weapon != null:
			main_grip = player_controller.current_weapon.grip_point_main
			off_grip = player_controller.current_weapon.grip_point_off
			
			## 如果握点未设置，使用基于武器长度的默认值
			if main_grip == Vector2.ZERO:
				main_grip = Vector2(player_controller.current_weapon.weapon_length * 0.3, 0)
			if off_grip == Vector2.ZERO:
				off_grip = Vector2(player_controller.current_weapon.weapon_length * 0.1, 0)
	
	## 将握点从武器本地坐标转换到 TorsoPivot 本地坐标
	## WeaponPhysics 节点在 WeaponRig 下，WeaponRig 在 TorsoPivot 下
	var weapon_rig = weapon_physics.get_parent()
	if weapon_rig:
		var weapon_rig_pos = weapon_rig.position
		
		## 旋转握点
		var rotated_main_grip = main_grip.rotated(weapon_rotation)
		var rotated_off_grip = off_grip.rotated(weapon_rotation)
		
		## 转换到 TorsoPivot 坐标系
		right_hand_target = weapon_rig_pos + rotated_main_grip
		left_hand_target = weapon_rig_pos + rotated_off_grip

func _solve_ik(delta: float) -> void:
	## 解算左臂 IK
	var left_shoulder = left_shoulder_offset
	left_hand_pos = left_hand_pos.lerp(left_hand_target, ik_smoothing * delta)
	left_elbow_pos = _solve_two_bone_ik(left_shoulder, left_hand_pos, upper_arm_length, forearm_length, -elbow_bend_direction)
	
	## 解算右臂 IK
	var right_shoulder = right_shoulder_offset
	right_hand_pos = right_hand_pos.lerp(right_hand_target, ik_smoothing * delta)
	right_elbow_pos = _solve_two_bone_ik(right_shoulder, right_hand_pos, upper_arm_length, forearm_length, elbow_bend_direction)
	
	## 发送更新信号
	arm_updated.emit("left", left_shoulder, left_elbow_pos, left_hand_pos)
	arm_updated.emit("right", right_shoulder, right_elbow_pos, right_hand_pos)

func _solve_two_bone_ik(shoulder: Vector2, hand: Vector2, upper_len: float, lower_len: float, bend_dir: float) -> Vector2:
	## Two-Bone IK 解算
	## 返回肘部位置
	
	var to_hand = hand - shoulder
	var distance = to_hand.length()
	var total_length = upper_len + lower_len
	
	## 限制距离在可达范围内
	var min_distance = abs(upper_len - lower_len) * min_reach_ratio
	var max_distance = total_length * max_reach_ratio
	distance = clamp(distance, min_distance, max_distance)
	
	## 如果距离为0，返回默认肘部位置
	if distance < 0.001:
		return shoulder + Vector2(upper_len * bend_dir, 0)
	
	## 使用余弦定理计算肘部角度
	## a = upper_len, b = distance, c = lower_len
	## cos(A) = (b² + a² - c²) / (2ab)
	var cos_angle = (distance * distance + upper_len * upper_len - lower_len * lower_len) / (2.0 * distance * upper_len)
	cos_angle = clamp(cos_angle, -1.0, 1.0)
	var angle = acos(cos_angle)
	
	## 计算从肩到手的方向
	var direction = to_hand.normalized()
	
	## 计算肘部位置
	## 肘部在肩到手连线上旋转 angle 角度的位置
	var elbow_direction = direction.rotated(angle * bend_dir)
	var elbow = shoulder + elbow_direction * upper_len
	
	return elbow

func _update_arm_visuals() -> void:
	## 更新左臂
	if left_upper_arm:
		left_upper_arm.set_point_position(0, left_shoulder_offset)
		left_upper_arm.set_point_position(1, left_elbow_pos)
	
	if left_forearm:
		left_forearm.set_point_position(0, left_elbow_pos)
		left_forearm.set_point_position(1, left_hand_pos)
	
	if left_hand_sprite:
		left_hand_sprite.position = left_hand_pos
	
	## 更新右臂
	if right_upper_arm:
		right_upper_arm.set_point_position(0, right_shoulder_offset)
		right_upper_arm.set_point_position(1, right_elbow_pos)
	
	if right_forearm:
		right_forearm.set_point_position(0, right_elbow_pos)
		right_forearm.set_point_position(1, right_hand_pos)
	
	if right_hand_sprite:
		right_hand_sprite.position = right_hand_pos

## 设置手臂颜色
func set_arm_color(color: Color) -> void:
	arm_color = color
	
	if left_upper_arm:
		left_upper_arm.default_color = color
	if left_forearm:
		left_forearm.default_color = color
	if right_upper_arm:
		right_upper_arm.default_color = color
	if right_forearm:
		right_forearm.default_color = color
	
	## 重新创建手部纹理
	if left_hand_sprite:
		left_hand_sprite.texture = _create_hand_texture()
	if right_hand_sprite:
		right_hand_sprite.texture = _create_hand_texture()

## 设置手臂宽度
func set_arm_width(width: float) -> void:
	arm_width = width
	
	if left_upper_arm:
		left_upper_arm.width = width
	if left_forearm:
		left_forearm.width = width
	if right_upper_arm:
		right_upper_arm.width = width
	if right_forearm:
		right_forearm.width = width
	
	## 重新创建手部纹理
	if left_hand_sprite:
		left_hand_sprite.texture = _create_hand_texture()
	if right_hand_sprite:
		right_hand_sprite.texture = _create_hand_texture()

## 手动设置手部目标位置（用于特殊动画）
func set_hand_target(hand: String, target: Vector2) -> void:
	if hand == "left":
		left_hand_target = target
	elif hand == "right":
		right_hand_target = target

## 获取手部当前位置
func get_hand_position(hand: String) -> Vector2:
	if hand == "left":
		return left_hand_pos
	elif hand == "right":
		return right_hand_pos
	return Vector2.ZERO

## 获取肘部当前位置
func get_elbow_position(hand: String) -> Vector2:
	if hand == "left":
		return left_elbow_pos
	elif hand == "right":
		return right_elbow_pos
	return Vector2.ZERO

## 设置手臂可见性
func set_arm_visible(visible_flag: bool) -> void:
	if left_upper_arm:
		left_upper_arm.visible = visible_flag
	if left_forearm:
		left_forearm.visible = visible_flag
	if left_hand_sprite:
		left_hand_sprite.visible = visible_flag
	if right_upper_arm:
		right_upper_arm.visible = visible_flag
	if right_forearm:
		right_forearm.visible = visible_flag
	if right_hand_sprite:
		right_hand_sprite.visible = visible_flag

## 根据武器类型调整手臂配置
func configure_for_weapon(weapon: WeaponData) -> void:
	if weapon == null:
		## 无武器时，手臂放松在身体两侧
		left_hand_target = left_shoulder_offset + Vector2(-5, 20)
		right_hand_target = right_shoulder_offset + Vector2(5, 20)
		return
	
	match weapon.grip_type:
		WeaponData.GripType.ONE_HANDED:
			## 单手武器：只有右手握武器，左手放松
			left_hand_target = left_shoulder_offset + Vector2(-5, 15)
		WeaponData.GripType.TWO_HANDED:
			## 双手武器：两只手都握武器
			pass  ## 由 _update_hand_targets 处理
		WeaponData.GripType.DUAL_WIELD:
			## 双持武器：两只手各握一把
			pass  ## 需要额外处理副手武器位置
