class_name PlayerController extends CharacterBody2D

## 玩家控制器
## 集成了新的能量系统，替代传统的血量系统

signal energy_cap_changed(current_cap: float, max_cap: float)  # 替代 health_changed
signal current_energy_changed(current: float, cap: float)
signal weapon_changed(weapon: WeaponData)
signal state_changed(state_name: String)
signal attack_started(attack: AttackData)
signal attack_ended(attack: AttackData)
signal attack_hit(target: Node2D, damage: float)
signal took_damage(damage: float, source: Node2D)
signal spell_cast(spell: SpellCoreData)
signal spell_hit(target: Node2D, damage: float)
signal weapon_settled  ## 武器物理系统稳定信号

@onready var state_machine: StateMachine = $StateMachine
@onready var input_buffer: InputBuffer = $InputBuffer
@onready var weapon_manager: Node = $WeaponManager
@onready var engraving_manager: EngravingManager = $EngravingManager
@onready var visuals: Node2D = $Visuals
@onready var legs_pivot: Node2D = $Visuals/LegsPivot
@onready var torso_pivot: Node2D = $Visuals/TorsoPivot
@onready var weapon_rig: Node2D = $Visuals/TorsoPivot/WeaponRig
@onready var hitbox: Area2D = $Hitbox
@onready var animation_player: AnimationPlayer = $AnimationPlayer

@export var movement_config: MovementConfig

## 能量系统（替代传统血量系统）
@export var energy_system: EnergySystemData

var is_flying: bool = false
var was_flying: bool = false
var is_attacking: bool = false
var is_casting: bool = false
var can_move: bool = true
var can_rotate: bool = true

var current_weapon: WeaponData = null

var current_spell: SpellCoreData = null

## 护盾系统（保留，与能量系统协同）
var current_shield: float = 0.0
var shield_duration: float = 0.0

var input_direction: Vector2 = Vector2.ZERO
var mouse_position: Vector2 = Vector2.ZERO
var target_angle: float = 0.0

var current_velocity: Vector2 = Vector2.ZERO
var current_facing_direction: Vector2 = Vector2.RIGHT

var stats = {
	"total_damage_dealt": 0.0,
	"total_hits": 0,
	"spells_cast": 0,
	"engravings_triggered": 0,
	"energy_absorbed": 0.0,
	"energy_cap_recovered": 0.0
}

func _ready() -> void:
	if movement_config == null:
		movement_config = MovementConfig.create_default()

	# 初始化能量系统
	if energy_system == null:
		energy_system = EnergySystemData.create_default()
	
	# 连接能量系统信号
	energy_system.energy_cap_changed.connect(_on_energy_cap_changed)
	energy_system.current_energy_changed.connect(_on_current_energy_changed)
	energy_system.depleted.connect(_on_depleted)

	if state_machine != null:
		state_machine.initialize(self)
		state_machine.state_changed.connect(_on_state_changed)

	if current_weapon == null:
		current_weapon = WeaponData.create_unarmed()

	_initialize_engraving_manager()

	add_to_group("players")
	add_to_group("allies")

func _initialize_engraving_manager() -> void:
	if engraving_manager == null:
		engraving_manager = EngravingManager.new()
		engraving_manager.name = "EngravingManager"
		add_child(engraving_manager)

	engraving_manager.initialize(self)

	engraving_manager.engraving_triggered.connect(_on_engraving_triggered)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse_position = get_global_mouse_position()

	if input_buffer != null:
		input_buffer.process_input_event(event, mouse_position, input_direction)

	if state_machine != null:
		state_machine.handle_input(event)

func _process(delta: float) -> void:
	_update_input_direction()

	_update_target_angle()

	_update_shield(delta)
	
	# 能量系统更新（被动吸收和自动修复）
	_update_energy_system(delta)

	if state_machine != null:
		state_machine.frame_update(delta)

func _physics_process(delta: float) -> void:
	if state_machine != null:
		state_machine.physics_update(delta)

	_apply_movement(delta)

	_apply_rotation(delta)

	_update_legs_rotation()

	move_and_slide()

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

	was_flying = is_flying

	is_flying = Input.is_key_pressed(KEY_SPACE)

func _update_target_angle() -> void:
	var direction_to_mouse = mouse_position - global_position
	if direction_to_mouse.length_squared() > 1:
		target_angle = direction_to_mouse.angle()

func _update_shield(delta: float) -> void:
	if shield_duration > 0:
		shield_duration -= delta
		if shield_duration <= 0:
			current_shield = 0

## 更新能量系统
func _update_energy_system(delta: float) -> void:
	if energy_system == null:
		return
	
	# 被动吸收环境能量
	var absorbed = energy_system.absorb_from_environment(delta)
	stats.energy_absorbed += absorbed
	
	# 自动修复能量上限（如果启用）
	if energy_system.auto_cultivation:
		var recovered = energy_system.cultivate(delta, 0.5)
		stats.energy_cap_recovered += recovered

func _apply_movement(delta: float) -> void:
	if not can_move:
		var stop_friction = movement_config.friction_ground if not is_flying else movement_config.friction_flight
		velocity = velocity.move_toward(Vector2.ZERO, stop_friction * delta)
		return

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

	if current_weapon != null:
		max_speed *= current_weapon.get_move_speed_modifier()
		acceleration *= current_weapon.get_acceleration_modifier()

	if input_direction.length_squared() > 0.01:
		var directional_modifier = movement_config.get_directional_speed_modifier(
			current_facing_direction, input_direction
		)
		max_speed *= directional_modifier

	var target_velocity = input_direction * max_speed

	if input_direction.length_squared() > 0.01:
		velocity = velocity.move_toward(target_velocity, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

func _apply_rotation(delta: float) -> void:
	if not can_rotate:
		return

	var is_standing = velocity.length_squared() < 100
	var turn_speed = movement_config.get_turn_speed(
		is_standing, current_facing_direction, input_direction
	)

	if current_weapon != null:
		turn_speed *= current_weapon.get_turn_speed_modifier()

	var current_angle = torso_pivot.rotation
	torso_pivot.rotation = rotate_toward(current_angle, target_angle, turn_speed * delta)

	current_facing_direction = Vector2.from_angle(torso_pivot.rotation)

func _update_legs_rotation() -> void:
	if velocity.length_squared() > 100:
		var target_legs_angle = velocity.angle()
		legs_pivot.rotation = lerp_angle(legs_pivot.rotation, target_legs_angle, 0.2)

func rotate_toward(from: float, to: float, max_delta: float) -> float:
	var diff = angle_difference(from, to)
	if abs(diff) <= max_delta:
		return to
	return from + sign(diff) * max_delta

func apply_attack_impulse(direction: Vector2, strength: float) -> void:
	velocity += direction * strength

func apply_impulse(impulse: Vector2) -> void:
	velocity += impulse

func can_attack_at_angle() -> bool:
	return movement_config.is_angle_valid_for_attack(torso_pivot.rotation, target_angle)

func can_cast_at_angle() -> bool:
	return movement_config.is_angle_valid_for_spell(torso_pivot.rotation, target_angle)

func get_facing_angle() -> float:
	return torso_pivot.rotation

func get_target_angle() -> float:
	return target_angle

func set_weapon(weapon: WeaponData) -> void:
	current_weapon = weapon

	if current_weapon != null and current_weapon.engraving_slots.is_empty():
		current_weapon.initialize_engraving_slots()

	weapon_changed.emit(weapon)

func set_spell(spell: SpellCoreData) -> void:
	current_spell = spell

## 承受伤害（新能量系统）
func take_damage(damage: float, source: Node2D = null) -> void:
	var actual_damage = damage

	# 护盾优先吸收伤害
	if current_shield > 0:
		var shield_absorb = min(current_shield, actual_damage)
		current_shield -= shield_absorb
		actual_damage -= shield_absorb

	# 剩余伤害由能量系统处理
	if actual_damage > 0 and energy_system != null:
		energy_system.take_damage(actual_damage)

	took_damage.emit(damage, source)

## 治疗/恢复能量上限
func heal(amount: float) -> float:
	if energy_system == null:
		return 0.0
	return energy_system.restore_energy_cap(amount)

## 恢复当前能量
func restore_energy(amount: float) -> float:
	if energy_system == null:
		return 0.0
	return energy_system.restore_energy(amount)

## 消耗能量（用于施法）
func consume_energy(amount: float) -> bool:
	if energy_system == null:
		return false
	return energy_system.consume_energy(amount)

## 主动修炼（恢复能量上限）
func cultivate(delta: float, intensity: float = 1.0) -> float:
	if energy_system == null:
		return 0.0
	var recovered = energy_system.cultivate(delta, intensity)
	stats.energy_cap_recovered += recovered
	return recovered

func apply_shield(amount: float, duration: float) -> void:
	current_shield = max(current_shield, amount)
	shield_duration = max(shield_duration, duration)

## 能量上限耗尽（死亡）
func _on_depleted() -> void:
	_on_death()

func _on_death() -> void:
	pass

func _on_state_changed(_old_state: State, new_state: State) -> void:
	state_changed.emit(new_state.name if new_state else "")

func _on_engraving_triggered(trigger_type: int, spell: SpellCoreData, source: String) -> void:
	stats.engravings_triggered += 1
	print("[刻录触发] 类型: %d, 法术: %s, 来源: %s" % [trigger_type, spell.spell_name, source])

## 能量上限变化回调
func _on_energy_cap_changed(current_cap: float, max_cap: float) -> void:
	energy_cap_changed.emit(current_cap, max_cap)

## 当前能量变化回调
func _on_current_energy_changed(current: float, cap: float) -> void:
	current_energy_changed.emit(current, cap)

func get_engraving_manager() -> EngravingManager:
	return engraving_manager

func get_body_parts() -> Array[BodyPartData]:
	if engraving_manager != null:
		return engraving_manager.get_body_parts()
	return []

func engrave_to_body(part_type: int, slot_index: int, spell: SpellCoreData) -> bool:
	if engraving_manager != null:
		return engraving_manager.engrave_to_body_part(part_type, slot_index, spell)
	return false

func engrave_to_weapon(slot_index: int, spell: SpellCoreData) -> bool:
	if engraving_manager != null:
		return engraving_manager.engrave_to_weapon(slot_index, spell)
	return false

func get_stats() -> Dictionary:
	return stats.duplicate()

func reset_stats() -> void:
	stats.total_damage_dealt = 0.0
	stats.total_hits = 0
	stats.spells_cast = 0
	stats.engravings_triggered = 0
	stats.energy_absorbed = 0.0
	stats.energy_cap_recovered = 0.0

## 获取能量系统
func get_energy_system() -> EnergySystemData:
	return energy_system

## 获取当前能量上限（兼容旧代码）
func get_current_health() -> float:
	if energy_system:
		return energy_system.current_energy_cap
	return 0.0

## 获取最大能量上限（兼容旧代码）
func get_max_health() -> float:
	if energy_system:
		return energy_system.max_energy_cap
	return 0.0

## 获取能量上限百分比
func get_health_percent() -> float:
	if energy_system:
		return energy_system.get_cap_percent()
	return 0.0
