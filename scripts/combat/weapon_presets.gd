class_name WeaponPresets
## 武器预设工厂类
## 提供各种预配置的武器数据，包含武器惯性和攻击回正参数

static func create_greatsword() -> WeaponData:
	var weapon = WeaponData.new()
	weapon.weapon_name = "大刀"
	weapon.weapon_type = WeaponData.WeaponType.GREATSWORD
	weapon.grip_type = WeaponData.GripType.TWO_HANDED
	weapon.description = "沉重的双手大刀，挥砍威力巨大"

	weapon.weight = 5.0
	weapon.inertia_factor = 0.8
	weapon.attack_impulse = 200.0
	weapon.swing_arc = 120.0
	weapon.weapon_length = 60.0

	weapon.base_damage = 30.0
	weapon.attack_range = 80.0
	weapon.knockback_force = 150.0
	
	## 启用正反手交替攻击
	weapon.alternate_attacks = true

	## 正向横斩（从右向左）
	var slash1 = AttackData.new()
	slash1.attack_name = "横斩"
	slash1.attack_type = AttackData.AttackType.SLASH
	slash1.attack_direction = AttackData.AttackDirection.FORWARD
	slash1.damage_multiplier = 1.0
	slash1.windup_time = 0.3
	slash1.active_time = 0.15
	slash1.recovery_time = 0.4
	slash1.can_combo = true
	slash1.swing_start_angle = -60.0
	slash1.swing_end_angle = 60.0
	slash1.windup_start_position = Vector2(30, -15)
	slash1.windup_start_rotation = -60.0
	slash1.requires_repositioning = true
	slash1.preferred_next_direction = AttackData.AttackDirection.REVERSE
	slash1.impulse_multiplier = 1.0

	## 反向回斩（从左向右）
	var slash2 = AttackData.new()
	slash2.attack_name = "回斩"
	slash2.attack_type = AttackData.AttackType.SLASH
	slash2.attack_direction = AttackData.AttackDirection.REVERSE
	slash2.damage_multiplier = 1.2
	slash2.windup_time = 0.25
	slash2.active_time = 0.15
	slash2.recovery_time = 0.35
	slash2.can_combo = true
	slash2.swing_start_angle = 60.0
	slash2.swing_end_angle = -60.0
	slash2.windup_start_position = Vector2(30, 15)
	slash2.windup_start_rotation = 60.0
	slash2.requires_repositioning = true
	slash2.preferred_next_direction = AttackData.AttackDirection.FORWARD
	slash2.impulse_multiplier = 1.2

	weapon.primary_attacks.append(slash1)
	weapon.primary_attacks.append(slash2)
	
	## 设置正反向攻击数组
	weapon.forward_attacks.append(slash1)
	weapon.reverse_attacks.append(slash2)

	## 重劈（同时按或右键）
	var smash = AttackData.new()
	smash.attack_name = "重劈"
	smash.attack_type = AttackData.AttackType.SMASH
	smash.attack_direction = AttackData.AttackDirection.OVERHEAD
	smash.damage_multiplier = 2.5
	smash.windup_time = 0.5
	smash.active_time = 0.2
	smash.recovery_time = 0.6
	smash.can_combo = false
	smash.swing_start_angle = -90.0
	smash.swing_end_angle = 0.0
	smash.windup_start_position = Vector2(15, -25)
	smash.windup_start_rotation = -90.0
	smash.requires_repositioning = true
	smash.impulse_multiplier = 2.0
	smash.knockback_multiplier = 2.0

	weapon.secondary_attacks.append(smash)
	weapon.combo_attacks.append(smash)

	return weapon

static func create_dual_blade() -> WeaponData:
	var weapon = WeaponData.new()
	weapon.weapon_name = "双刃剑"
	weapon.weapon_type = WeaponData.WeaponType.DUAL_BLADE
	weapon.grip_type = WeaponData.GripType.TWO_HANDED
	weapon.description = "双刃长剑，可挥砍可刺击"

	weapon.weight = 3.0
	weapon.inertia_factor = 0.5
	weapon.attack_impulse = 120.0
	weapon.swing_arc = 90.0
	weapon.weapon_length = 50.0

	weapon.base_damage = 20.0
	weapon.attack_range = 60.0
	weapon.knockback_force = 80.0
	
	weapon.alternate_attacks = true

	## 正向斜斩
	var slash1 = AttackData.new()
	slash1.attack_name = "斜斩"
	slash1.attack_type = AttackData.AttackType.SLASH
	slash1.attack_direction = AttackData.AttackDirection.FORWARD
	slash1.damage_multiplier = 1.0
	slash1.windup_time = 0.15
	slash1.active_time = 0.1
	slash1.recovery_time = 0.25
	slash1.can_combo = true
	slash1.swing_start_angle = -45.0
	slash1.swing_end_angle = 45.0
	slash1.windup_start_position = Vector2(25, -10)
	slash1.windup_start_rotation = -45.0
	slash1.requires_repositioning = true
	slash1.preferred_next_direction = AttackData.AttackDirection.REVERSE

	## 反向反斩
	var slash2 = AttackData.new()
	slash2.attack_name = "反斩"
	slash2.attack_type = AttackData.AttackType.SLASH
	slash2.attack_direction = AttackData.AttackDirection.REVERSE
	slash2.damage_multiplier = 1.1
	slash2.windup_time = 0.12
	slash2.active_time = 0.1
	slash2.recovery_time = 0.2
	slash2.can_combo = true
	slash2.swing_start_angle = 45.0
	slash2.swing_end_angle = -45.0
	slash2.windup_start_position = Vector2(25, 10)
	slash2.windup_start_rotation = 45.0
	slash2.requires_repositioning = true
	slash2.preferred_next_direction = AttackData.AttackDirection.FORWARD

	weapon.primary_attacks.append(slash1)
	weapon.primary_attacks.append(slash2)
	weapon.forward_attacks.append(slash1)
	weapon.reverse_attacks.append(slash2)

	## 短刺
	var thrust = AttackData.new()
	thrust.attack_name = "短刺"
	thrust.attack_type = AttackData.AttackType.THRUST
	thrust.attack_direction = AttackData.AttackDirection.THRUST_FORWARD
	thrust.damage_multiplier = 1.3
	thrust.windup_time = 0.2
	thrust.active_time = 0.08
	thrust.recovery_time = 0.3
	thrust.can_combo = true
	thrust.swing_start_angle = 0.0
	thrust.swing_end_angle = 0.0
	thrust.windup_start_position = Vector2(15, 0)
	thrust.windup_start_rotation = 0.0
	thrust.requires_repositioning = true
	thrust.impulse_multiplier = 1.5

	weapon.secondary_attacks.append(thrust)

	return weapon

static func create_spear() -> WeaponData:
	var weapon = WeaponData.new()
	weapon.weapon_name = "长矛"
	weapon.weapon_type = WeaponData.WeaponType.SPEAR
	weapon.grip_type = WeaponData.GripType.TWO_HANDED
	weapon.description = "长柄武器，擅长刺击和舞枪"

	weapon.weight = 4.0
	weapon.inertia_factor = 0.6
	weapon.attack_impulse = 180.0
	weapon.swing_arc = 60.0
	weapon.weapon_length = 80.0

	weapon.base_damage = 22.0
	weapon.attack_range = 100.0
	weapon.knockback_force = 100.0

	## 直刺
	var thrust1 = AttackData.new()
	thrust1.attack_name = "直刺"
	thrust1.attack_type = AttackData.AttackType.THRUST
	thrust1.attack_direction = AttackData.AttackDirection.THRUST_FORWARD
	thrust1.damage_multiplier = 1.0
	thrust1.windup_time = 0.2
	thrust1.active_time = 0.1
	thrust1.recovery_time = 0.25
	thrust1.can_combo = true
	thrust1.swing_start_angle = 0.0
	thrust1.swing_end_angle = 0.0
	thrust1.windup_start_position = Vector2(10, 0)
	thrust1.windup_start_rotation = 0.0
	thrust1.requires_repositioning = true
	thrust1.impulse_multiplier = 1.2

	## 连刺
	var thrust2 = AttackData.new()
	thrust2.attack_name = "连刺"
	thrust2.attack_type = AttackData.AttackType.THRUST
	thrust2.attack_direction = AttackData.AttackDirection.THRUST_FORWARD
	thrust2.damage_multiplier = 0.8
	thrust2.windup_time = 0.1
	thrust2.active_time = 0.08
	thrust2.recovery_time = 0.15
	thrust2.can_combo = true
	thrust2.swing_start_angle = 0.0
	thrust2.swing_end_angle = 0.0
	thrust2.windup_start_position = Vector2(10, 0)
	thrust2.windup_start_rotation = 0.0
	thrust2.requires_repositioning = false  ## 连刺不需要回正
	thrust2.impulse_multiplier = 0.8

	## 重刺
	var thrust3 = AttackData.new()
	thrust3.attack_name = "重刺"
	thrust3.attack_type = AttackData.AttackType.THRUST
	thrust3.attack_direction = AttackData.AttackDirection.THRUST_FORWARD
	thrust3.damage_multiplier = 1.5
	thrust3.windup_time = 0.25
	thrust3.active_time = 0.12
	thrust3.recovery_time = 0.35
	thrust3.can_combo = false
	thrust3.swing_start_angle = 0.0
	thrust3.swing_end_angle = 0.0
	thrust3.windup_start_position = Vector2(5, 0)
	thrust3.windup_start_rotation = 0.0
	thrust3.requires_repositioning = true
	thrust3.impulse_multiplier = 1.8

	weapon.primary_attacks.append(thrust1)
	weapon.primary_attacks.append(thrust2)
	weapon.primary_attacks.append(thrust3)
	weapon.forward_attacks.append(thrust1)

	## 舞枪
	var spin = AttackData.new()
	spin.attack_name = "舞枪"
	spin.attack_type = AttackData.AttackType.SPIN
	spin.attack_direction = AttackData.AttackDirection.FORWARD
	spin.damage_multiplier = 0.6
	spin.windup_time = 0.3
	spin.active_time = 0.4
	spin.recovery_time = 0.5
	spin.can_combo = false
	spin.swing_start_angle = 0.0
	spin.swing_end_angle = 360.0
	spin.windup_start_position = Vector2(15, 0)
	spin.windup_start_rotation = 0.0
	spin.requires_repositioning = true
	spin.impulse_multiplier = 0.5
	spin.knockback_multiplier = 1.5

	weapon.secondary_attacks.append(spin)

	return weapon

static func create_dagger() -> WeaponData:
	var weapon = WeaponData.new()
	weapon.weapon_name = "匕首"
	weapon.weapon_type = WeaponData.WeaponType.DAGGER
	weapon.grip_type = WeaponData.GripType.ONE_HANDED
	weapon.description = "轻便的短刃，攻击迅速"

	weapon.weight = 0.5
	weapon.inertia_factor = 0.2
	weapon.attack_impulse = 50.0
	weapon.swing_arc = 45.0
	weapon.weapon_length = 25.0

	weapon.base_damage = 8.0
	weapon.attack_range = 30.0
	weapon.knockback_force = 30.0

	## 快斩
	var slash = AttackData.new()
	slash.attack_name = "快斩"
	slash.attack_type = AttackData.AttackType.SLASH
	slash.attack_direction = AttackData.AttackDirection.FORWARD
	slash.damage_multiplier = 1.0
	slash.windup_time = 0.05
	slash.active_time = 0.05
	slash.recovery_time = 0.1
	slash.can_combo = true
	slash.swing_start_angle = -30.0
	slash.swing_end_angle = 30.0
	slash.windup_start_position = Vector2(18, -5)
	slash.windup_start_rotation = -30.0
	slash.requires_repositioning = false  ## 轻武器不需要回正

	weapon.primary_attacks.append(slash)

	## 背刺
	var backstab = AttackData.new()
	backstab.attack_name = "背刺"
	backstab.attack_type = AttackData.AttackType.THRUST
	backstab.attack_direction = AttackData.AttackDirection.THRUST_FORWARD
	backstab.damage_multiplier = 2.0
	backstab.critical_chance = 0.3
	backstab.critical_multiplier = 2.0
	backstab.windup_time = 0.15
	backstab.active_time = 0.05
	backstab.recovery_time = 0.2
	backstab.can_combo = false
	backstab.swing_start_angle = 0.0
	backstab.swing_end_angle = 0.0
	backstab.windup_start_position = Vector2(12, 0)
	backstab.windup_start_rotation = 0.0
	backstab.requires_repositioning = true
	backstab.impulse_multiplier = 1.5

	weapon.secondary_attacks.append(backstab)

	return weapon

static func create_staff() -> WeaponData:
	var weapon = WeaponData.new()
	weapon.weapon_name = "法杖"
	weapon.weapon_type = WeaponData.WeaponType.STAFF
	weapon.grip_type = WeaponData.GripType.TWO_HANDED
	weapon.description = "施法用的法杖，近战能力有限"

	weapon.weight = 2.0
	weapon.inertia_factor = 0.3
	weapon.attack_impulse = 80.0
	weapon.swing_arc = 60.0
	weapon.weapon_length = 55.0

	weapon.base_damage = 10.0
	weapon.attack_range = 50.0
	weapon.knockback_force = 60.0

	## 敲击
	var strike = AttackData.new()
	strike.attack_name = "敲击"
	strike.attack_type = AttackData.AttackType.SMASH
	strike.attack_direction = AttackData.AttackDirection.OVERHEAD
	strike.damage_multiplier = 1.0
	strike.windup_time = 0.2
	strike.active_time = 0.1
	strike.recovery_time = 0.3
	strike.can_combo = true
	strike.swing_start_angle = -45.0
	strike.swing_end_angle = 45.0
	strike.windup_start_position = Vector2(15, -10)
	strike.windup_start_rotation = -45.0
	strike.requires_repositioning = true

	weapon.primary_attacks.append(strike)

	## 横扫
	var sweep = AttackData.new()
	sweep.attack_name = "横扫"
	sweep.attack_type = AttackData.AttackType.SWEEP
	sweep.attack_direction = AttackData.AttackDirection.FORWARD
	sweep.damage_multiplier = 0.8
	sweep.windup_time = 0.25
	sweep.active_time = 0.2
	sweep.recovery_time = 0.35
	sweep.can_combo = false
	sweep.swing_start_angle = -90.0
	sweep.swing_end_angle = 90.0
	sweep.windup_start_position = Vector2(10, -15)
	sweep.windup_start_rotation = -90.0
	sweep.requires_repositioning = true
	sweep.knockback_multiplier = 1.5

	weapon.secondary_attacks.append(sweep)

	return weapon

static func get_all_presets() -> Array[WeaponData]:
	return [
		WeaponData.create_unarmed(),
		create_greatsword(),
		create_dual_blade(),
		create_spear(),
		create_dagger(),
		create_staff()
	]

## 根据武器类型创建默认武器
static func create_weapon_by_type(weapon_type: WeaponData.WeaponType) -> WeaponData:
	match weapon_type:
		WeaponData.WeaponType.UNARMED:
			return WeaponData.create_unarmed()
		WeaponData.WeaponType.GREATSWORD:
			return create_greatsword()
		WeaponData.WeaponType.DUAL_BLADE:
			return create_dual_blade()
		WeaponData.WeaponType.SPEAR:
			return create_spear()
		WeaponData.WeaponType.DAGGER:
			return create_dagger()
		WeaponData.WeaponType.STAFF:
			return create_staff()
		_:
			return WeaponData.create_unarmed()

## 获取武器类型的显示名称
static func get_weapon_type_name(weapon_type: WeaponData.WeaponType) -> String:
	match weapon_type:
		WeaponData.WeaponType.UNARMED:
			return "徒手"
		WeaponData.WeaponType.SWORD:
			return "单手剑"
		WeaponData.WeaponType.GREATSWORD:
			return "大刀"
		WeaponData.WeaponType.DUAL_BLADE:
			return "双刃剑"
		WeaponData.WeaponType.SPEAR:
			return "长矛"
		WeaponData.WeaponType.DAGGER:
			return "匕首"
		WeaponData.WeaponType.STAFF:
			return "法杖"
		_:
			return "未知"
