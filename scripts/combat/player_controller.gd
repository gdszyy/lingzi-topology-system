class_name PlayerController extends CharacterBody2D

## 玩家控制器
## 集成了新的能量系统和二维体素战斗系统
## 支持肢体目标伤害和法术失效机制

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

## 二维体素战斗系统信号
signal body_part_damaged(part: BodyPartData, damage: float)
signal body_part_destroyed(part: BodyPartData)
signal body_part_restored(part: BodyPartData)
signal vital_part_destroyed(part: BodyPartData)  # 关键部位被摧毁（导致死亡）

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
var is_attacking_while_moving: bool = false  ## 【优化】攻击移动状态标记
var is_casting: bool = false
var can_move: bool = true
var can_rotate: bool = true

var current_weapon: WeaponData = null
var current_attack: AttackData = null  ## 当前执行的攻击
var current_attack_phase: String = ""  ## 当前攻击阶段："windup", "active", "recovery"

var current_spell: SpellCoreData = null

## 护盾系统（保留，与能量系统协同）
var current_shield: float = 0.0
var shield_duration: float = 0.0

# 状态效果修饰符
var defense_modifier: float = 0.0
var accuracy_modifier: float = 0.0
var evasion_modifier: float = 0.0
var damage_taken_modifier: float = 1.0
var damage_output_modifier: float = 1.0
var speed_modifier: float = 1.0
var is_frozen: bool = false
var is_movement_locked: bool = false

var input_direction: Vector2 = Vector2.ZERO
var mouse_position: Vector2 = Vector2.ZERO
var target_angle: float = 0.0

var current_velocity: Vector2 = Vector2.ZERO
var current_facing_direction: Vector2 = Vector2.RIGHT

## 二维体素战斗系统：肢体损伤对移动的影响
var movement_penalty: float = 1.0  # 移动速度惩罚倍率
var can_fly_override: bool = true  # 是否可以飞行

var stats = {
	"total_damage_dealt": 0.0,
	"total_hits": 0,
	"spells_cast": 0,
	"engravings_triggered": 0,
	"energy_absorbed": 0.0,
	"energy_cap_recovered": 0.0,
	"body_parts_destroyed": 0,
	"body_parts_restored": 0,
	"damage_taken_by_part": {}
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
	
	# 连接二维体素战斗系统信号
	engraving_manager.body_part_damaged.connect(_on_body_part_damaged)
	engraving_manager.body_part_destroyed.connect(_on_body_part_destroyed)
	engraving_manager.body_part_restored.connect(_on_body_part_restored)

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

	## 【优化】更新攻击移动状态
	is_attacking_while_moving = is_attacking and input_direction.length_squared() > 0.01

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

	# 检查是否可以飞行（腿部损伤会影响飞行能力）
	is_flying = Input.is_key_pressed(KEY_SPACE) and can_fly_override

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
	if not can_move or is_frozen or is_movement_locked:
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

	# 应用肢体损伤导致的移动惩罚
	max_speed *= movement_penalty * speed_modifier
	acceleration *= movement_penalty * speed_modifier
	
	## 【优化】攻击时移动速度惩罚（根据武器、攻击和阶段）
	if is_attacking:
		var attack_move_modifier = _get_attack_move_speed_modifier()
		var attack_accel_modifier = _get_attack_acceleration_modifier()
		max_speed *= attack_move_modifier
		acceleration *= attack_accel_modifier

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

## 承受伤害（二维体素战斗系统核心方法）
## 支持指定目标肢体
func take_damage(damage: float, source: Node2D = null, target_part_type: int = BodyPartData.PartType.TORSO) -> void:
	var actual_damage = damage * damage_taken_modifier

	# 护盾优先吸收伤害
	if current_shield > 0:
		var shield_absorb = min(current_shield, actual_damage)
		current_shield -= shield_absorb
		actual_damage -= shield_absorb

	# 剩余伤害由肢体系统处理
	if actual_damage > 0 and engraving_manager != null:
		# 应用防御修饰符
		var final_part_damage = actual_damage * (1.0 / (1.0 + max(0, defense_modifier / 100.0)))
		# 对目标肢体造成伤害，并获取传递到核心的伤害值
		var core_damage = engraving_manager.damage_body_part(target_part_type, final_part_damage)
		
		# 记录统计
		var part_key = BodyPartData.PartType.keys()[target_part_type]
		if not stats.damage_taken_by_part.has(part_key):
			stats.damage_taken_by_part[part_key] = 0.0
		stats.damage_taken_by_part[part_key] += actual_damage
		
		# 核心伤害传递到能量系统
		if core_damage > 0 and energy_system != null:
			energy_system.take_damage(core_damage)

	took_damage.emit(damage, source)

## 对随机肢体造成伤害（用于非定向攻击）
func take_damage_random_part(damage: float, source: Node2D = null) -> void:
	var functional_parts = engraving_manager.get_functional_body_parts()
	if functional_parts.is_empty():
		# 如果所有肢体都被摧毁，直接伤害核心
		if energy_system != null:
			energy_system.take_damage(damage)
		took_damage.emit(damage, source)
		return
	
	# 随机选择一个肢体
	var target_part = functional_parts[randi() % functional_parts.size()]
	take_damage(damage, source, target_part.part_type)

## 对多个肢体造成分散伤害（用于范围攻击）
func take_damage_spread(total_damage: float, source: Node2D = null) -> void:
	var functional_parts = engraving_manager.get_functional_body_parts()
	if functional_parts.is_empty():
		if energy_system != null:
			energy_system.take_damage(total_damage)
		took_damage.emit(total_damage, source)
		return
	
	# 将伤害分散到所有功能正常的肢体
	var damage_per_part = total_damage / functional_parts.size()
	for part in functional_parts:
		engraving_manager.damage_body_part(part.part_type, damage_per_part)
	
	took_damage.emit(total_damage, source)

## 治疗/恢复能量上限
func heal(amount: float) -> float:
	if energy_system == null:
		return 0.0
	return energy_system.restore_energy_cap(amount)

## 治疗特定肢体
func heal_body_part(part_type: int, amount: float) -> float:
	if engraving_manager == null:
		return 0.0
	return engraving_manager.heal_body_part(part_type, amount)

## 治疗所有肢体
func heal_all_body_parts(amount_per_part: float) -> void:
	if engraving_manager == null:
		return
	for part in engraving_manager.get_body_parts():
		part.heal(amount_per_part)

## 完全恢复所有肢体
func restore_all_body_parts() -> void:
	if engraving_manager != null:
		engraving_manager.restore_all_body_parts()
	_update_movement_penalties()

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
	print("[玩家死亡] 能量上限耗尽")
	# 可以在这里添加死亡处理逻辑

# ==================== 状态效果 API ====================

func set_frozen(frozen: bool) -> void:
	is_frozen = frozen
	if is_frozen:
		can_move = false
	else:
		can_move = true

func set_movement_locked(locked: bool) -> void:
	is_movement_locked = locked

func modify_defense(amount: float) -> void:
	defense_modifier += amount

func modify_accuracy(amount: float) -> void:
	accuracy_modifier += amount

func modify_evasion(amount: float) -> void:
	evasion_modifier += amount

func modify_damage_taken(amount: float) -> void:
	damage_taken_modifier += amount

func modify_damage_output(amount: float) -> void:
	damage_output_modifier += amount

func modify_move_speed(amount: float) -> void:
	speed_modifier += amount

func add_shield(amount: float) -> void:
	current_shield += amount

func apply_status(status_type: int, duration: float, effect_value: float = 0.0) -> void:
	var runtime_manager = get_tree().get_first_node_in_group("runtime_systems_manager")
	if runtime_manager != null:
		var status_data = ApplyStatusActionData.new()
		status_data.status_type = status_type
		status_data.duration = duration
		status_data.effect_value = effect_value
		status_data._sync_phase_from_status()
		runtime_manager.apply_status(self, status_data)

func _on_state_changed(_old_state: State, new_state: State) -> void:
	state_changed.emit(new_state.name if new_state else "")

func _on_engraving_triggered(trigger_type: int, spell: SpellCoreData, source: String) -> void:
	stats.engravings_triggered += 1
	print("[刻录触发] 类型: %d, 法术: %s, 来源: %s" % [trigger_type, spell.spell_name, source])

## 肢体受伤回调
func _on_body_part_damaged(part: BodyPartData, damage: float, _remaining_health: float) -> void:
	body_part_damaged.emit(part, damage)
	_update_movement_penalties()

## 肢体被摧毁回调
func _on_body_part_destroyed(part: BodyPartData) -> void:
	stats.body_parts_destroyed += 1
	body_part_destroyed.emit(part)
	
	# 检查是否为关键部位
	if part.is_vital:
		vital_part_destroyed.emit(part)
		_on_death()
		return
	
	# 更新移动惩罚
	_update_movement_penalties()
	
	print("[肢体摧毁] %s 被摧毁！" % part.part_name)

## 肢体恢复回调
func _on_body_part_restored(part: BodyPartData) -> void:
	stats.body_parts_restored += 1
	body_part_restored.emit(part)
	_update_movement_penalties()
	print("[肢体恢复] %s 已恢复！" % part.part_name)

## 更新肢体损伤导致的移动惩罚
func _update_movement_penalties() -> void:
	if engraving_manager == null:
		movement_penalty = 1.0
		can_fly_override = true
		return
	
	# 检查腿部状态
	var legs = engraving_manager.get_body_part(BodyPartData.PartType.LEGS)
	if legs == null or not legs.is_functional:
		movement_penalty = 0.3  # 腿部被摧毁，移动速度降低70%
		can_fly_override = false  # 无法飞行
	else:
		movement_penalty = legs.efficiency  # 根据腿部效率调整移动速度
		can_fly_override = legs.damage_state != BodyPartData.DamageState.CRIPPLED  # 残废状态无法飞行

## 能量上限变化回调
func _on_energy_cap_changed(current_cap: float, max_cap: float) -> void:
	energy_cap_changed.emit(current_cap, max_cap)

## 当前能量变化回调
func _on_current_energy_changed(current: float, cap: float) -> void:
	current_energy_changed.emit(current, cap)

func get_engraving_manager() -> EngravingManager:
	return engraving_manager

func get_body_parts() -> Array[BodyPartData]:
	if engraving_manager != null and engraving_manager.has_method("get_body_parts"):
		return engraving_manager.get_body_parts()
	return []

## 获取特定肢体
func get_body_part(part_type: int) -> BodyPartData:
	if engraving_manager != null and engraving_manager.has_method("get_body_part"):
		return engraving_manager.get_body_part(part_type)
	return null

## 获取肢体状态摘要
func get_body_parts_summary() -> String:
	if engraving_manager != null and engraving_manager.has_method("get_body_parts_summary"):
		return engraving_manager.get_body_parts_summary()
	return ""

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
	stats.body_parts_destroyed = 0
	stats.body_parts_restored = 0
	stats.damage_taken_by_part.clear()

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

## 检查是否可以使用武器（需要手臂功能正常）
func can_use_weapon() -> bool:
	if engraving_manager == null:
		return true
	
	var right_arm = engraving_manager.get_body_part(BodyPartData.PartType.RIGHT_ARM)
	var left_arm = engraving_manager.get_body_part(BodyPartData.PartType.LEFT_ARM)
	
	if current_weapon != null and current_weapon.is_two_handed():
		return (right_arm != null and right_arm.is_functional) and (left_arm != null and left_arm.is_functional)
	
	return (right_arm != null and right_arm.is_functional) or (left_arm != null and left_arm.is_functional)

## 检查是否可以施法（需要手部功能正常）
func can_cast_spell() -> bool:
	if engraving_manager == null:
		return true
	
	var right_hand = engraving_manager.get_body_part(BodyPartData.PartType.RIGHT_HAND)
	var left_hand = engraving_manager.get_body_part(BodyPartData.PartType.LEFT_HAND)
	
	return (right_hand != null and right_hand.is_functional) or (left_hand != null and left_hand.is_functional)

## 获取施法速度修正（受手部损伤影响）
func get_cast_speed_modifier() -> float:
	if engraving_manager == null:
		return 1.0
	
	var right_hand = engraving_manager.get_body_part(BodyPartData.PartType.RIGHT_HAND)
	var left_hand = engraving_manager.get_body_part(BodyPartData.PartType.LEFT_HAND)
	
	var total_efficiency = 0.0
	var count = 0
	
	if right_hand != null:
		total_efficiency += right_hand.efficiency
		count += 1
	if left_hand != null:
		total_efficiency += left_hand.efficiency
		count += 1
	
	if count == 0:
		return 0.5  # 没有手部，施法速度大幅降低
	
	return total_efficiency / count

## 获取攻击伤害修正（受手臂损伤影响）
func get_attack_damage_modifier() -> float:
	if engraving_manager == null:
		return 1.0
	
	var right_arm = engraving_manager.get_body_part(BodyPartData.PartType.RIGHT_ARM)
	
	if right_arm != null:
		return right_arm.efficiency
	
	return 0.5  # 右臂被摧毁，攻击伤害降低50%


## ==================== 攻击移动系统方法 ====================

## 获取当前攻击时的移动速度修正
func _get_attack_move_speed_modifier() -> float:
	# 如果没有攻击数据，使用配置默认值
	if current_attack == null:
		if current_weapon != null:
			return current_weapon.attack_move_speed_modifier
		return movement_config.default_attack_move_speed_modifier if movement_config != null else 0.6
	
	# 获取武器的默认值
	var weapon_default = movement_config.default_attack_move_speed_modifier if movement_config != null else 0.6
	if current_weapon != null:
		weapon_default = current_weapon.attack_move_speed_modifier
	
	# 根据攻击阶段获取修正值
	match current_attack_phase:
		"windup":
			return current_attack.get_windup_move_speed_modifier(weapon_default)
		"active":
			return current_attack.get_active_move_speed_modifier(weapon_default)
		"recovery":
			return current_attack.get_recovery_move_speed_modifier(weapon_default)
		_:
			return weapon_default

## 获取当前攻击时的加速度修正
func _get_attack_acceleration_modifier() -> float:
	# 加速度修正与速度修正保持一致的比例
	var speed_modifier = _get_attack_move_speed_modifier()
	
	# 如果有武器，使用武器的加速度修正
	if current_weapon != null:
		var base_accel_modifier = current_weapon.attack_acceleration_modifier
		# 根据速度修正调整加速度修正
		return base_accel_modifier
	
	# 否则使用配置默认值
	return movement_config.default_attack_acceleration_modifier if movement_config != null else 0.7

## 设置当前攻击和阶段（由攻击状态机调用）
func set_current_attack_phase(attack: AttackData, phase: String) -> void:
	current_attack = attack
	current_attack_phase = phase

## 清除当前攻击信息
func clear_current_attack() -> void:
	current_attack = null
	current_attack_phase = ""
