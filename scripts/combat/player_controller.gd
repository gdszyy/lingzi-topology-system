# player_controller.gd
# 玩家控制器 - 角色的核心控制脚本
class_name PlayerController extends CharacterBody2D

## 信号
signal health_changed(current: float, max_health: float)
signal weapon_changed(weapon: WeaponData)
signal state_changed(state_name: String)
signal attack_started(attack: AttackData)
signal attack_hit(target: Node2D, damage: float)
signal spell_cast(spell: SpellCoreData)

## 节点引用
@onready var state_machine: StateMachine = $StateMachine
@onready var input_buffer: InputBuffer = $InputBuffer
@onready var weapon_manager: Node = $WeaponManager
@onready var visuals: Node2D = $Visuals
@onready var legs_pivot: Node2D = $Visuals/LegsPivot
@onready var torso_pivot: Node2D = $Visuals/TorsoPivot
@onready var weapon_rig: Node2D = $Visuals/TorsoPivot/WeaponRig
@onready var hitbox: Area2D = $Hitbox
@onready var animation_player: AnimationPlayer = $AnimationPlayer

## 配置资源
@export var movement_config: MovementConfig

## 状态
var is_flying: bool = false
var is_attacking: bool = false
var is_casting: bool = false
var can_move: bool = true
var can_rotate: bool = true

## 当前武器
var current_weapon: WeaponData = null

## 当前法术
var current_spell: SpellCoreData = null

## 生命值
var max_health: float = 100.0
var current_health: float = 100.0

## 输入状态
var input_direction: Vector2 = Vector2.ZERO
var mouse_position: Vector2 = Vector2.ZERO
var target_angle: float = 0.0

## 物理状态
var current_velocity: Vector2 = Vector2.ZERO
var current_facing_direction: Vector2 = Vector2.RIGHT

## 统计
var stats = {
	"total_damage_dealt": 0.0,
	"total_hits": 0,
	"spells_cast": 0
}

func _ready() -> void:
	# 创建默认移动配置
	if movement_config == null:
		movement_config = MovementConfig.create_default()
	
	# 初始化状态机
	if state_machine != null:
		state_machine.initialize(self)
		state_machine.state_changed.connect(_on_state_changed)
	
	# 初始化默认武器（徒手）
	if current_weapon == null:
		current_weapon = WeaponData.create_unarmed()
	
	# 添加到玩家组
	add_to_group("players")

func _input(event: InputEvent) -> void:
	# 更新鼠标位置
	if event is InputEventMouseMotion:
		mouse_position = get_global_mouse_position()
	
	# 将输入传递给输入缓存
	if input_buffer != null:
		input_buffer.process_input_event(event, mouse_position, input_direction)
	
	# 将输入传递给状态机
	if state_machine != null:
		state_machine.handle_input(event)

func _process(delta: float) -> void:
	# 更新输入方向
	_update_input_direction()
	
	# 更新目标角度（鼠标位置）
	_update_target_angle()
	
	# 状态机帧更新
	if state_machine != null:
		state_machine.frame_update(delta)

func _physics_process(delta: float) -> void:
	# 状态机物理更新
	if state_machine != null:
		state_machine.physics_update(delta)
	
	# 应用移动
	_apply_movement(delta)
	
	# 应用旋转
	_apply_rotation(delta)
	
	# 更新腿部朝向
	_update_legs_rotation()
	
	# 执行移动
	move_and_slide()

## 更新输入方向
func _update_input_direction() -> void:
	input_direction = Vector2.ZERO
	
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		input_direction.x += 1
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		input_direction.x -= 1
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		input_direction.y += 1
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		input_direction.y -= 1
	
	if input_direction.length() > 1:
		input_direction = input_direction.normalized()
	
	# 检测飞行输入
	is_flying = Input.is_key_pressed(KEY_SPACE)

## 更新目标角度
func _update_target_angle() -> void:
	var direction_to_mouse = mouse_position - global_position
	if direction_to_mouse.length_squared() > 1:
		target_angle = direction_to_mouse.angle()

## 应用移动
func _apply_movement(delta: float) -> void:
	if not can_move:
		# 即使不能移动，也要应用摩擦力
		var friction = movement_config.friction_ground if not is_flying else movement_config.friction_flight
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		return
	
	# 获取当前物理参数
	var max_speed: float
	var acceleration: float
	var friction: float
	
	if is_flying:
		max_speed = movement_config.max_speed_flight
		acceleration = movement_config.acceleration_flight
		friction = movement_config.friction_flight
	else:
		max_speed = movement_config.max_speed_ground
		acceleration = movement_config.acceleration_ground
		friction = movement_config.friction_ground
	
	# 应用武器重量修正
	if current_weapon != null:
		max_speed *= current_weapon.get_move_speed_modifier()
		acceleration *= current_weapon.get_acceleration_modifier()
	
	# 应用方向速度修正
	if input_direction.length_squared() > 0.01:
		var directional_modifier = movement_config.get_directional_speed_modifier(
			current_facing_direction, input_direction
		)
		max_speed *= directional_modifier
	
	# 计算目标速度
	var target_velocity = input_direction * max_speed
	
	# 应用加速度或摩擦力
	if input_direction.length_squared() > 0.01:
		velocity = velocity.move_toward(target_velocity, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

## 应用旋转
func _apply_rotation(delta: float) -> void:
	if not can_rotate:
		return
	
	# 获取当前角速度
	var is_standing = velocity.length_squared() < 100
	var turn_speed = movement_config.get_turn_speed(
		is_standing, current_facing_direction, input_direction
	)
	
	# 应用武器重量修正
	if current_weapon != null:
		turn_speed *= current_weapon.get_turn_speed_modifier()
	
	# 平滑旋转躯干
	var current_angle = torso_pivot.rotation
	torso_pivot.rotation = rotate_toward(current_angle, target_angle, turn_speed * delta)
	
	# 更新朝向向量
	current_facing_direction = Vector2.from_angle(torso_pivot.rotation)

## 更新腿部旋转（跟随移动方向）
func _update_legs_rotation() -> void:
	if velocity.length_squared() > 100:
		var target_legs_angle = velocity.angle()
		legs_pivot.rotation = lerp_angle(legs_pivot.rotation, target_legs_angle, 0.2)

## 辅助函数：角度平滑旋转
func rotate_toward(from: float, to: float, max_delta: float) -> float:
	var diff = angle_difference(from, to)
	if abs(diff) <= max_delta:
		return to
	return from + sign(diff) * max_delta

## 施加攻击冲量
func apply_attack_impulse(direction: Vector2, strength: float) -> void:
	velocity += direction * strength

## 检查是否可以攻击（角度检查）
func can_attack_at_angle() -> bool:
	return movement_config.is_angle_valid_for_attack(torso_pivot.rotation, target_angle)

## 检查是否可以施法（角度检查）
func can_cast_at_angle() -> bool:
	return movement_config.is_angle_valid_for_spell(torso_pivot.rotation, target_angle)

## 获取当前朝向角度
func get_facing_angle() -> float:
	return torso_pivot.rotation

## 获取目标角度
func get_target_angle() -> float:
	return target_angle

## 设置武器
func set_weapon(weapon: WeaponData) -> void:
	current_weapon = weapon
	weapon_changed.emit(weapon)

## 设置法术
func set_spell(spell: SpellCoreData) -> void:
	current_spell = spell

## 受到伤害
func take_damage(damage: float) -> void:
	current_health = max(0, current_health - damage)
	health_changed.emit(current_health, max_health)
	
	if current_health <= 0:
		_on_death()

## 死亡处理
func _on_death() -> void:
	# TODO: 实现死亡逻辑
	pass

## 状态改变回调
func _on_state_changed(_old_state: State, new_state: State) -> void:
	state_changed.emit(new_state.name if new_state else "")

## 获取统计数据
func get_stats() -> Dictionary:
	return stats.duplicate()

## 重置统计
func reset_stats() -> void:
	stats.total_damage_dealt = 0.0
	stats.total_hits = 0
	stats.spells_cast = 0
