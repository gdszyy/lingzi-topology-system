# weapon_presets.gd
# 预设武器工厂 - 创建各种预设武器
class_name WeaponPresets

## 创建大刀（双手砍刀）
static func create_greatsword() -> WeaponData:
	var weapon = WeaponData.new()
	weapon.weapon_name = "大刀"
	weapon.weapon_type = WeaponData.WeaponType.GREATSWORD
	weapon.grip_type = WeaponData.GripType.TWO_HANDED
	weapon.description = "沉重的双手大刀，挥砍威力巨大"
	
	# 物理属性
	weapon.weight = 5.0
	weapon.inertia_factor = 0.8
	weapon.attack_impulse = 200.0
	weapon.swing_arc = 120.0
	
	# 战斗属性
	weapon.base_damage = 30.0
	weapon.attack_range = 80.0
	weapon.knockback_force = 150.0
	
	# 创建攻击动作
	# 左键：横斩
	var slash1 = AttackData.new()
	slash1.attack_name = "横斩"
	slash1.attack_type = AttackData.AttackType.SLASH
	slash1.damage_multiplier = 1.0
	slash1.windup_time = 0.3
	slash1.active_time = 0.15
	slash1.recovery_time = 0.4
	slash1.can_combo = true
	slash1.swing_start_angle = -60.0
	slash1.swing_end_angle = 60.0
	slash1.impulse_multiplier = 1.0
	
	var slash2 = AttackData.new()
	slash2.attack_name = "回斩"
	slash2.attack_type = AttackData.AttackType.SLASH
	slash2.damage_multiplier = 1.2
	slash2.windup_time = 0.25
	slash2.active_time = 0.15
	slash2.recovery_time = 0.35
	slash2.can_combo = true
	slash2.swing_start_angle = 60.0
	slash2.swing_end_angle = -60.0
	slash2.impulse_multiplier = 1.2
	
	weapon.primary_attacks = [slash1, slash2]
	
	# 右键：重劈
	var smash = AttackData.new()
	smash.attack_name = "重劈"
	smash.attack_type = AttackData.AttackType.SMASH
	smash.damage_multiplier = 2.5
	smash.windup_time = 0.5
	smash.active_time = 0.2
	smash.recovery_time = 0.6
	smash.can_combo = false
	smash.swing_start_angle = -90.0
	smash.swing_end_angle = 0.0
	smash.impulse_multiplier = 2.0
	smash.knockback_multiplier = 2.0
	
	weapon.secondary_attacks = [smash]
	
	return weapon

## 创建双刃剑
static func create_dual_blade() -> WeaponData:
	var weapon = WeaponData.new()
	weapon.weapon_name = "双刃剑"
	weapon.weapon_type = WeaponData.WeaponType.DUAL_BLADE
	weapon.grip_type = WeaponData.GripType.TWO_HANDED
	weapon.description = "双刃长剑，可挥砍可刺击"
	
	# 物理属性
	weapon.weight = 3.0
	weapon.inertia_factor = 0.5
	weapon.attack_impulse = 120.0
	weapon.swing_arc = 90.0
	
	# 战斗属性
	weapon.base_damage = 20.0
	weapon.attack_range = 60.0
	weapon.knockback_force = 80.0
	
	# 左键：挥砍
	var slash1 = AttackData.new()
	slash1.attack_name = "斜斩"
	slash1.attack_type = AttackData.AttackType.SLASH
	slash1.damage_multiplier = 1.0
	slash1.windup_time = 0.15
	slash1.active_time = 0.1
	slash1.recovery_time = 0.25
	slash1.can_combo = true
	slash1.swing_start_angle = -45.0
	slash1.swing_end_angle = 45.0
	
	var slash2 = AttackData.new()
	slash2.attack_name = "反斩"
	slash2.attack_type = AttackData.AttackType.SLASH
	slash2.damage_multiplier = 1.1
	slash2.windup_time = 0.12
	slash2.active_time = 0.1
	slash2.recovery_time = 0.2
	slash2.can_combo = true
	slash2.swing_start_angle = 45.0
	slash2.swing_end_angle = -45.0
	
	weapon.primary_attacks = [slash1, slash2]
	
	# 右键：短刺
	var thrust = AttackData.new()
	thrust.attack_name = "短刺"
	thrust.attack_type = AttackData.AttackType.THRUST
	thrust.damage_multiplier = 1.3
	thrust.windup_time = 0.2
	thrust.active_time = 0.08
	thrust.recovery_time = 0.3
	thrust.can_combo = true
	thrust.swing_start_angle = 0.0
	thrust.swing_end_angle = 0.0
	thrust.impulse_multiplier = 1.5
	
	weapon.secondary_attacks = [thrust]
	
	return weapon

## 创建矛
static func create_spear() -> WeaponData:
	var weapon = WeaponData.new()
	weapon.weapon_name = "长矛"
	weapon.weapon_type = WeaponData.WeaponType.SPEAR
	weapon.grip_type = WeaponData.GripType.TWO_HANDED
	weapon.description = "长柄武器，擅长刺击和舞枪"
	
	# 物理属性
	weapon.weight = 4.0
	weapon.inertia_factor = 0.6
	weapon.attack_impulse = 180.0
	weapon.swing_arc = 60.0
	
	# 战斗属性
	weapon.base_damage = 22.0
	weapon.attack_range = 100.0  # 长距离
	weapon.knockback_force = 100.0
	
	# 左键：刺击
	var thrust1 = AttackData.new()
	thrust1.attack_name = "直刺"
	thrust1.attack_type = AttackData.AttackType.THRUST
	thrust1.damage_multiplier = 1.0
	thrust1.windup_time = 0.2
	thrust1.active_time = 0.1
	thrust1.recovery_time = 0.25
	thrust1.can_combo = true
	thrust1.impulse_multiplier = 1.2
	
	var thrust2 = AttackData.new()
	thrust2.attack_name = "连刺"
	thrust2.attack_type = AttackData.AttackType.THRUST
	thrust2.damage_multiplier = 0.8
	thrust2.windup_time = 0.1
	thrust2.active_time = 0.08
	thrust2.recovery_time = 0.15
	thrust2.can_combo = true
	thrust2.impulse_multiplier = 0.8
	
	var thrust3 = AttackData.new()
	thrust3.attack_name = "重刺"
	thrust3.attack_type = AttackData.AttackType.THRUST
	thrust3.damage_multiplier = 1.5
	thrust3.windup_time = 0.25
	thrust3.active_time = 0.12
	thrust3.recovery_time = 0.35
	thrust3.can_combo = false
	thrust3.impulse_multiplier = 1.8
	
	weapon.primary_attacks = [thrust1, thrust2, thrust3]
	
	# 右键：舞枪（旋转攻击）
	var spin = AttackData.new()
	spin.attack_name = "舞枪"
	spin.attack_type = AttackData.AttackType.SPIN
	spin.damage_multiplier = 0.6
	spin.windup_time = 0.3
	spin.active_time = 0.4  # 较长的判定时间
	spin.recovery_time = 0.5
	spin.can_combo = false
	spin.swing_start_angle = 0.0
	spin.swing_end_angle = 360.0
	spin.impulse_multiplier = 0.5
	spin.knockback_multiplier = 1.5
	
	weapon.secondary_attacks = [spin]
	
	return weapon

## 创建匕首（单手）
static func create_dagger() -> WeaponData:
	var weapon = WeaponData.new()
	weapon.weapon_name = "匕首"
	weapon.weapon_type = WeaponData.WeaponType.DAGGER
	weapon.grip_type = WeaponData.GripType.ONE_HANDED
	weapon.description = "轻便的短刃，攻击迅速"
	
	# 物理属性
	weapon.weight = 0.5
	weapon.inertia_factor = 0.2
	weapon.attack_impulse = 50.0
	weapon.swing_arc = 45.0
	
	# 战斗属性
	weapon.base_damage = 8.0
	weapon.attack_range = 30.0
	weapon.knockback_force = 30.0
	
	# 左键：快速斩击
	var slash = AttackData.new()
	slash.attack_name = "快斩"
	slash.attack_type = AttackData.AttackType.SLASH
	slash.damage_multiplier = 1.0
	slash.windup_time = 0.05
	slash.active_time = 0.05
	slash.recovery_time = 0.1
	slash.can_combo = true
	slash.swing_start_angle = -30.0
	slash.swing_end_angle = 30.0
	
	weapon.primary_attacks = [slash]
	
	# 右键：背刺
	var backstab = AttackData.new()
	backstab.attack_name = "背刺"
	backstab.attack_type = AttackData.AttackType.THRUST
	backstab.damage_multiplier = 2.0
	backstab.critical_chance = 0.3
	backstab.critical_multiplier = 2.0
	backstab.windup_time = 0.15
	backstab.active_time = 0.05
	backstab.recovery_time = 0.2
	backstab.can_combo = false
	backstab.impulse_multiplier = 1.5
	
	weapon.secondary_attacks = [backstab]
	
	return weapon

## 创建法杖
static func create_staff() -> WeaponData:
	var weapon = WeaponData.new()
	weapon.weapon_name = "法杖"
	weapon.weapon_type = WeaponData.WeaponType.STAFF
	weapon.grip_type = WeaponData.GripType.TWO_HANDED
	weapon.description = "施法用的法杖，近战能力有限"
	
	# 物理属性
	weapon.weight = 2.0
	weapon.inertia_factor = 0.3
	weapon.attack_impulse = 80.0
	weapon.swing_arc = 60.0
	
	# 战斗属性
	weapon.base_damage = 10.0
	weapon.attack_range = 50.0
	weapon.knockback_force = 60.0
	
	# 左键：敲击
	var strike = AttackData.new()
	strike.attack_name = "敲击"
	strike.attack_type = AttackData.AttackType.SMASH
	strike.damage_multiplier = 1.0
	strike.windup_time = 0.2
	strike.active_time = 0.1
	strike.recovery_time = 0.3
	strike.can_combo = true
	strike.swing_start_angle = -45.0
	strike.swing_end_angle = 45.0
	
	weapon.primary_attacks = [strike]
	
	# 右键：横扫
	var sweep = AttackData.new()
	sweep.attack_name = "横扫"
	sweep.attack_type = AttackData.AttackType.SWEEP
	sweep.damage_multiplier = 0.8
	sweep.windup_time = 0.25
	sweep.active_time = 0.2
	sweep.recovery_time = 0.35
	sweep.can_combo = false
	sweep.swing_start_angle = -90.0
	sweep.swing_end_angle = 90.0
	sweep.knockback_multiplier = 1.5
	
	weapon.secondary_attacks = [sweep]
	
	return weapon

## 获取所有预设武器
static func get_all_presets() -> Array[WeaponData]:
	return [
		WeaponData.create_unarmed(),
		create_greatsword(),
		create_dual_blade(),
		create_spear(),
		create_dagger(),
		create_staff()
	]
