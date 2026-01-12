class_name WeaponData extends Resource

enum WeaponType {
	UNARMED,
	SWORD,
	GREATSWORD,
	DUAL_BLADE,
	SPEAR,
	DAGGER,
	STAFF
}

enum GripType {
	ONE_HANDED,
	TWO_HANDED,
	DUAL_WIELD
}

@export_group("Basic Info")
@export var weapon_name: String = "未命名武器"
@export var weapon_type: WeaponType = WeaponType.UNARMED
@export var grip_type: GripType = GripType.ONE_HANDED
@export var description: String = ""

@export_group("Visuals")
@export var weapon_texture: Texture2D
@export var weapon_offset: Vector2 = Vector2.ZERO
@export var weapon_scale: Vector2 = Vector2.ONE
@export var grip_point_main: Vector2 = Vector2.ZERO
@export var grip_point_off: Vector2 = Vector2.ZERO
@export var weapon_length: float = 40.0  ## 武器长度，用于计算惯性

@export_group("Physics")
@export var weight: float = 1.0
@export_range(0.0, 1.0) var inertia_factor: float = 0.5
@export var attack_impulse: float = 100.0
@export var swing_arc: float = 90.0

@export_group("Combat Stats")
@export var base_damage: float = 10.0
@export var attack_range: float = 50.0
@export var knockback_force: float = 50.0

@export_group("Attack Actions")
@export var primary_attacks: Array[AttackData] = []
@export var secondary_attacks: Array[AttackData] = []
@export var combo_attacks: Array[AttackData] = []

@export_group("Two-Handed Specific")
@export var forward_attacks: Array[AttackData] = []   ## 正向攻击（从右向左）
@export var reverse_attacks: Array[AttackData] = []   ## 反向攻击（从左向右）
@export var alternate_attacks: bool = true            ## 是否自动交替正反手攻击

@export_group("Engraving")
@export var engraving_slots: Array[EngravingSlot] = []
@export var max_engraving_capacity: float = 100.0

## 运行时状态
var last_attack_direction: int = 0  ## 0=正向, 1=反向

func get_turn_speed_modifier() -> float:
	## 武器重量影响转身速度
	## 重武器转身更慢
	return 1.0 / (1.0 + weight * 0.1)

func get_move_speed_modifier() -> float:
	## 武器重量影响移动速度
	return 1.0 / (1.0 + weight * 0.05)

func get_acceleration_modifier() -> float:
	## 武器重量影响加速度
	return 1.0 / (1.0 + weight * 0.08)

func get_attack_impulse() -> float:
	## 攻击冲量与武器重量成正比
	return attack_impulse * (1.0 + weight * 0.2)

func is_two_handed() -> bool:
	return grip_type == GripType.TWO_HANDED

func is_dual_wield() -> bool:
	return grip_type == GripType.DUAL_WIELD

## 获取指定输入类型的攻击数据
func get_attacks_for_input(input_type: int) -> Array[AttackData]:
	match input_type:
		0:  ## PRIMARY - 左键
			return _get_primary_attacks()
		1:  ## SECONDARY - 右键
			return _get_secondary_attacks()
		2:  ## COMBO - 同时按
			return _get_combo_attacks()
		_:
			return _get_primary_attacks()

## 获取主攻击（左键）
func _get_primary_attacks() -> Array[AttackData]:
	## 对于双手武器，根据上一次攻击方向选择正向或反向攻击
	if is_two_handed() and alternate_attacks:
		if forward_attacks.size() > 0 and reverse_attacks.size() > 0:
			if last_attack_direction == 0:
				return forward_attacks
			else:
				return reverse_attacks
	
	return primary_attacks

## 获取副攻击（右键）
func _get_secondary_attacks() -> Array[AttackData]:
	## 对于双手武器，右键可以强制使用反向攻击
	if is_two_handed() and reverse_attacks.size() > 0:
		return reverse_attacks
	
	return secondary_attacks

## 获取组合攻击（同时按）
func _get_combo_attacks() -> Array[AttackData]:
	return combo_attacks

## 根据武器当前状态选择最优攻击
func get_optimal_attack_for_weapon_state(weapon_rotation: float, input_type: int) -> AttackData:
	var attacks = get_attacks_for_input(input_type)
	if attacks.size() == 0:
		return null
	
	## 对于双手武器，根据武器当前角度选择最合适的攻击方向
	if is_two_handed():
		var best_attack: AttackData = null
		var best_score: float = -1.0
		
		## 检查正向攻击
		for attack in forward_attacks:
			var score = _calculate_attack_suitability(attack, weapon_rotation)
			if score > best_score:
				best_score = score
				best_attack = attack
		
		## 检查反向攻击
		for attack in reverse_attacks:
			var score = _calculate_attack_suitability(attack, weapon_rotation)
			if score > best_score:
				best_score = score
				best_attack = attack
		
		if best_attack != null:
			## 更新上一次攻击方向
			if best_attack in forward_attacks:
				last_attack_direction = 0
			else:
				last_attack_direction = 1
			return best_attack
	
	## 默认返回第一个攻击
	return attacks[0] if attacks.size() > 0 else null

func _calculate_attack_suitability(attack: AttackData, current_weapon_rotation: float) -> float:
	## 计算攻击与当前武器位置的适合度（0-1）
	var target_rotation = attack.get_reposition_target_rotation()
	var angle_diff = abs(angle_difference(current_weapon_rotation, target_rotation))
	
	## 角度差越小，适合度越高
	return 1.0 - clamp(rad_to_deg(angle_diff) / 180.0, 0.0, 1.0)

## 切换攻击方向（用于连击系统）
func toggle_attack_direction() -> void:
	last_attack_direction = 1 - last_attack_direction

## 重置攻击方向
func reset_attack_direction() -> void:
	last_attack_direction = 0

func initialize_engraving_slots(slot_count: int = 2) -> void:
	engraving_slots.clear()

	var capacity = max_engraving_capacity
	match weapon_type:
		WeaponType.UNARMED:
			slot_count = 0
			capacity = 0
		WeaponType.DAGGER:
			slot_count = 1
			capacity = 50.0
		WeaponType.SWORD, WeaponType.DUAL_BLADE:
			slot_count = 2
			capacity = 80.0
		WeaponType.GREATSWORD, WeaponType.SPEAR:
			slot_count = 3
			capacity = 120.0
		WeaponType.STAFF:
			slot_count = 4
			capacity = 150.0

	for i in range(slot_count):
		var slot = EngravingSlot.new()
		slot.initialize(
			"%s_slot_%d" % [weapon_name.to_lower().replace(" ", "_"), i],
			"%s刻录槽%d" % [weapon_name, i + 1],
			capacity / slot_count
		)
		slot.allowed_triggers.assign([
			TriggerData.TriggerType.ON_WEAPON_HIT,
			TriggerData.TriggerType.ON_ATTACK_START,
			TriggerData.TriggerType.ON_ATTACK_ACTIVE,
			TriggerData.TriggerType.ON_ATTACK_END,
			TriggerData.TriggerType.ON_COMBO_HIT,
			TriggerData.TriggerType.ON_CRITICAL_HIT,
			TriggerData.TriggerType.ON_DEAL_DAMAGE,
			TriggerData.TriggerType.ON_KILL_ENEMY
		])
		engraving_slots.append(slot)

func get_engraved_spells() -> Array[SpellCoreData]:
	var spells: Array[SpellCoreData] = []
	for slot in engraving_slots:
		if slot.engraved_spell != null:
			spells.append(slot.engraved_spell)
	return spells

func get_triggerable_rules(trigger_type: int) -> Array[TopologyRuleData]:
	var rules: Array[TopologyRuleData] = []
	for slot in engraving_slots:
		var slot_rules = slot.trigger(trigger_type)
		rules.append_array(slot_rules)
	return rules

func update_engraving_cooldowns(delta: float) -> void:
	for slot in engraving_slots:
		slot.update_cooldown(delta)

func engrave_spell_to_slot(slot_index: int, spell: SpellCoreData) -> bool:
	if slot_index < 0 or slot_index >= engraving_slots.size():
		return false
	return engraving_slots[slot_index].engrave_spell(spell)

func remove_spell_from_slot(slot_index: int) -> SpellCoreData:
	if slot_index < 0 or slot_index >= engraving_slots.size():
		return null
	return engraving_slots[slot_index].remove_spell()

func get_engraving_slot_count() -> int:
	return engraving_slots.size()

func get_used_engraving_capacity() -> float:
	var used = 0.0
	for slot in engraving_slots:
		if slot.engraved_spell != null:
			used += slot.engraved_spell.calculate_total_instability()
	return used

static func create_unarmed() -> WeaponData:
	var weapon = WeaponData.new()
	weapon.weapon_name = "徒手"
	weapon.weapon_type = WeaponType.UNARMED
	weapon.grip_type = GripType.ONE_HANDED
	weapon.weight = 0.0
	weapon.base_damage = 5.0
	weapon.attack_range = 30.0
	weapon.max_engraving_capacity = 0.0

	var punch = AttackData.new()
	punch.attack_name = "拳击"
	punch.damage_multiplier = 1.0
	punch.windup_time = 0.1
	punch.active_time = 0.1
	punch.recovery_time = 0.2
	punch.can_combo = true
	weapon.primary_attacks.append(punch)

	return weapon

static func create_greatsword() -> WeaponData:
	var weapon = WeaponData.new()
	weapon.weapon_name = "大剑"
	weapon.weapon_type = WeaponType.GREATSWORD
	weapon.grip_type = GripType.TWO_HANDED
	weapon.weight = 8.0
	weapon.inertia_factor = 0.8
	weapon.base_damage = 25.0
	weapon.attack_range = 70.0
	weapon.attack_impulse = 150.0
	weapon.weapon_length = 60.0
	weapon.alternate_attacks = true
	
	## 正向挥砍（从右向左）
	var forward_slash = AttackData.create_default_slash()
	forward_slash.attack_name = "正手挥砍"
	forward_slash.damage_multiplier = 1.2
	forward_slash.windup_time = 0.3
	forward_slash.active_time = 0.2
	forward_slash.recovery_time = 0.4
	forward_slash.swing_start_angle = -75.0
	forward_slash.swing_end_angle = 75.0
	forward_slash.windup_start_position = Vector2(30, -15)
	forward_slash.windup_start_rotation = -75.0
	forward_slash.preferred_next_direction = AttackData.AttackDirection.REVERSE
	weapon.forward_attacks.append(forward_slash)
	weapon.primary_attacks.append(forward_slash)
	
	## 反向挥砍（从左向右）
	var reverse_slash = AttackData.create_default_reverse_slash()
	reverse_slash.attack_name = "反手挥砍"
	reverse_slash.damage_multiplier = 1.1
	reverse_slash.windup_time = 0.25
	reverse_slash.active_time = 0.2
	reverse_slash.recovery_time = 0.35
	reverse_slash.swing_start_angle = 75.0
	reverse_slash.swing_end_angle = -75.0
	reverse_slash.windup_start_position = Vector2(30, 15)
	reverse_slash.windup_start_rotation = 75.0
	reverse_slash.preferred_next_direction = AttackData.AttackDirection.FORWARD
	weapon.reverse_attacks.append(reverse_slash)
	weapon.secondary_attacks.append(reverse_slash)
	
	## 重击（同时按）
	var heavy_smash = AttackData.create_default_smash()
	heavy_smash.attack_name = "重劈"
	heavy_smash.damage_multiplier = 2.5
	heavy_smash.windup_time = 0.5
	heavy_smash.active_time = 0.25
	heavy_smash.recovery_time = 0.6
	weapon.combo_attacks.append(heavy_smash)
	
	return weapon

static func create_spear() -> WeaponData:
	var weapon = WeaponData.new()
	weapon.weapon_name = "长矛"
	weapon.weapon_type = WeaponType.SPEAR
	weapon.grip_type = GripType.TWO_HANDED
	weapon.weight = 5.0
	weapon.inertia_factor = 0.6
	weapon.base_damage = 18.0
	weapon.attack_range = 90.0
	weapon.attack_impulse = 120.0
	weapon.weapon_length = 80.0
	
	## 刺击（左键）
	var thrust = AttackData.create_spear_thrust()
	weapon.primary_attacks.append(thrust)
	weapon.forward_attacks.append(thrust)
	
	## 舞枪（右键）
	var sweep = AttackData.create_spear_sweep()
	weapon.secondary_attacks.append(sweep)
	
	## 连续刺击（同时按）
	var rapid_thrust = AttackData.create_spear_thrust()
	rapid_thrust.attack_name = "连刺"
	rapid_thrust.damage_multiplier = 0.8
	rapid_thrust.windup_time = 0.15
	rapid_thrust.active_time = 0.08
	rapid_thrust.recovery_time = 0.15
	rapid_thrust.can_combo = true
	rapid_thrust.combo_window = 0.4
	weapon.combo_attacks.append(rapid_thrust)
	
	return weapon

static func create_dual_blade() -> WeaponData:
	var weapon = WeaponData.new()
	weapon.weapon_name = "双刃剑"
	weapon.weapon_type = WeaponType.DUAL_BLADE
	weapon.grip_type = GripType.TWO_HANDED
	weapon.weight = 4.0
	weapon.inertia_factor = 0.4
	weapon.base_damage = 12.0
	weapon.attack_range = 50.0
	weapon.attack_impulse = 80.0
	weapon.weapon_length = 50.0
	weapon.alternate_attacks = true
	
	## 挥砍（左键）
	var slash = AttackData.create_default_slash()
	slash.attack_name = "挥砍"
	slash.windup_time = 0.12
	slash.active_time = 0.1
	slash.recovery_time = 0.18
	weapon.primary_attacks.append(slash)
	weapon.forward_attacks.append(slash)
	
	## 反手挥砍
	var reverse = AttackData.create_default_reverse_slash()
	reverse.attack_name = "反手挥砍"
	reverse.windup_time = 0.1
	reverse.active_time = 0.1
	reverse.recovery_time = 0.15
	weapon.reverse_attacks.append(reverse)
	
	## 短刺（右键）
	var thrust = AttackData.create_default_thrust()
	thrust.attack_name = "短刺"
	thrust.windup_time = 0.15
	thrust.active_time = 0.06
	thrust.recovery_time = 0.2
	weapon.secondary_attacks.append(thrust)
	
	return weapon
