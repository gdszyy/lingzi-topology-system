class_name WeaponTraitPresets

## 武器特质预设配置
## 定义每种武器类型的默认特质修正
## 武器作为"特质"的象征，而非直接伤害来源

## 获取指定武器类型的特质修正器
static func get_modifier_for_type(weapon_type: WeaponData.WeaponType) -> WeaponTraitModifier:
	match weapon_type:
		WeaponData.WeaponType.UNARMED:
			return _create_unarmed_modifier()
		WeaponData.WeaponType.SWORD:
			return _create_sword_modifier()
		WeaponData.WeaponType.GREATSWORD:
			return _create_greatsword_modifier()
		WeaponData.WeaponType.DUAL_BLADE:
			return _create_dual_blade_modifier()
		WeaponData.WeaponType.SPEAR:
			return _create_spear_modifier()
		WeaponData.WeaponType.DAGGER:
			return _create_dagger_modifier()
		WeaponData.WeaponType.STAFF:
			return _create_staff_modifier()
	return WeaponTraitModifier.new()

## 获取武器类型的特质名称
static func get_trait_name(weapon_type: WeaponData.WeaponType) -> String:
	match weapon_type:
		WeaponData.WeaponType.UNARMED:
			return "本源"
		WeaponData.WeaponType.SWORD:
			return "锐意"
		WeaponData.WeaponType.GREATSWORD:
			return "厚重"
		WeaponData.WeaponType.DUAL_BLADE:
			return "疾风"
		WeaponData.WeaponType.SPEAR:
			return "穿透"
		WeaponData.WeaponType.DAGGER:
			return "隐秘"
		WeaponData.WeaponType.STAFF:
			return "引导"
	return "未知"

## 获取武器类型的特质描述
static func get_trait_description(weapon_type: WeaponData.WeaponType) -> String:
	match weapon_type:
		WeaponData.WeaponType.UNARMED:
			return "回归本我，以身为器，无需外物"
		WeaponData.WeaponType.SWORD:
			return "锋芒毕露，直指核心，一击必中"
		WeaponData.WeaponType.GREATSWORD:
			return "势大力沉，蓄势待发，一击定乾坤"
		WeaponData.WeaponType.DUAL_BLADE:
			return "双生共舞，连绵不绝，以速制敌"
		WeaponData.WeaponType.SPEAR:
			return "一往无前，势如破竹，贯穿万物"
		WeaponData.WeaponType.DAGGER:
			return "伺机而动，一击致命，无声无息"
		WeaponData.WeaponType.STAFF:
			return "沟通天地，引导灵力，法术增幅"
	return ""

## ==================== 徒手 ====================
## 特质：本源 - 回归本我，以身为器
## 特点：无法在武器上篆刻，但肢体篆刻效果增强
static func _create_unarmed_modifier() -> WeaponTraitModifier:
	var mod = WeaponTraitModifier.new()
	mod.trait_name = "本源"
	mod.trait_description = "回归本我，以身为器，无需外物"
	
	# 徒手无法在武器上篆刻
	mod.capacity_multiplier = 0.0
	mod.slot_count_modifier = -99  # 确保无槽位
	
	# 基础修正（不适用，因为无法篆刻）
	mod.windup_multiplier = 1.0
	mod.cost_multiplier = 1.0
	mod.effect_multiplier = 1.0
	mod.cooldown_multiplier = 1.0
	
	return mod

## ==================== 剑 ====================
## 特质：锐意 - 锋芒毕露，直指核心
## 特点：平衡型，命中触发加成，伤害类法术增强
static func _create_sword_modifier() -> WeaponTraitModifier:
	var mod = WeaponTraitModifier.new()
	mod.trait_name = "锐意"
	mod.trait_description = "锋芒毕露，直指核心，一击必中"
	
	# 基础修正 - 平衡
	mod.windup_multiplier = 1.0
	mod.cost_multiplier = 1.0
	mod.effect_multiplier = 1.1      # 轻微效果加成
	mod.cooldown_multiplier = 1.0
	
	# 触发器亲和 - 命中类触发器加成
	mod.trigger_affinity = {
		TriggerData.TriggerType.ON_WEAPON_HIT: 1.3,      # 武器命中 +30%
		TriggerData.TriggerType.ON_CRITICAL_HIT: 1.5,    # 暴击 +50%
		TriggerData.TriggerType.ON_DEAL_DAMAGE: 1.2,     # 造成伤害 +20%
	}
	
	# 动作亲和 - 伤害类动作加成
	mod.action_affinity = {
		ActionData.ActionType.DAMAGE: 1.2,               # 伤害 +20%
		ActionData.ActionType.CHAIN: 1.1,                # 链式 +10%
	}
	
	# 特殊规则
	mod.can_cast_while_attacking = true
	mod.can_cast_while_moving = true
	mod.requires_weapon_hit = false
	mod.first_cast_bonus = 0.15      # 首击加成15%
	mod.chain_cast_bonus = 0.0
	
	# 容量
	mod.capacity_multiplier = 0.8    # 容量略低
	mod.slot_count_modifier = 0
	
	return mod

## ==================== 大剑 ====================
## 特质：厚重 - 势大力沉，蓄势待发
## 特点：高前摇高收益，攻击结束触发加成，范围效果增强
static func _create_greatsword_modifier() -> WeaponTraitModifier:
	var mod = WeaponTraitModifier.new()
	mod.trait_name = "厚重"
	mod.trait_description = "势大力沉，蓄势待发，一击定乾坤"
	
	# 基础修正 - 高前摇高收益
	mod.windup_multiplier = 1.5      # 前摇增加50%
	mod.cost_multiplier = 1.3        # 消耗增加30%
	mod.effect_multiplier = 1.5      # 效果增加50%
	mod.cooldown_multiplier = 1.2    # 冷却增加20%
	
	# 触发器亲和 - 攻击结束和重击触发加成
	mod.trigger_affinity = {
		TriggerData.TriggerType.ON_ATTACK_END: 1.5,      # 攻击结束 +50%
		TriggerData.TriggerType.ON_COMBO_HIT: 1.3,       # 连击 +30%
		TriggerData.TriggerType.ON_ATTACK_START: 0.7,    # 攻击开始 -30%（不适合快速触发）
	}
	
	# 动作亲和 - 范围和爆炸效果加成
	mod.action_affinity = {
		ActionData.ActionType.AREA_EFFECT: 1.4,          # 范围效果 +40%
		ActionData.ActionType.SPAWN_EXPLOSION: 1.5,      # 爆炸 +50%
		ActionData.ActionType.SPAWN_DAMAGE_ZONE: 1.3,    # 伤害区域 +30%
		ActionData.ActionType.DISPLACEMENT: 1.2,         # 位移 +20%
	}
	
	# 特殊规则
	mod.can_cast_while_attacking = false  # 攻击中无法触发
	mod.can_cast_while_moving = false     # 移动中无法触发
	mod.requires_weapon_hit = false
	mod.chain_cast_bonus = -0.1           # 连续触发惩罚（需要蓄力）
	mod.first_cast_bonus = 0.0
	
	# 容量 - 大剑容量高
	mod.capacity_multiplier = 1.2
	mod.slot_count_modifier = 1
	
	return mod

## ==================== 双刃 ====================
## 特质：疾风 - 双生共舞，连绵不绝
## 特点：低前摇低单次效果，连续触发加成，攻击开始触发加成
static func _create_dual_blade_modifier() -> WeaponTraitModifier:
	var mod = WeaponTraitModifier.new()
	mod.trait_name = "疾风"
	mod.trait_description = "双生共舞，连绵不绝，以速制敌"
	
	# 基础修正 - 快速低耗
	mod.windup_multiplier = 0.6      # 前摇减少40%
	mod.cost_multiplier = 0.7        # 消耗减少30%
	mod.effect_multiplier = 0.7      # 效果减少30%
	mod.cooldown_multiplier = 0.5    # 冷却减少50%
	
	# 触发器亲和 - 攻击开始和连击触发加成
	mod.trigger_affinity = {
		TriggerData.TriggerType.ON_ATTACK_START: 1.4,    # 攻击开始 +40%
		TriggerData.TriggerType.ON_ATTACK_ACTIVE: 1.3,   # 攻击判定 +30%
		TriggerData.TriggerType.ON_COMBO_HIT: 1.5,       # 连击 +50%
		TriggerData.TriggerType.ON_ATTACK_END: 0.6,      # 攻击结束 -40%
	}
	
	# 动作亲和 - 状态效果和链式加成
	mod.action_affinity = {
		ActionData.ActionType.APPLY_STATUS: 1.3,         # 状态效果 +30%
		ActionData.ActionType.CHAIN: 1.4,                # 链式 +40%
		ActionData.ActionType.DAMAGE: 0.8,               # 单次伤害 -20%
	}
	
	# 特殊规则
	mod.can_cast_while_attacking = true
	mod.can_cast_while_moving = true
	mod.requires_weapon_hit = false
	mod.chain_cast_bonus = 0.2        # 连续触发加成20%
	mod.first_cast_bonus = 0.0
	
	# 容量 - 双刃容量中等
	mod.capacity_multiplier = 0.8
	mod.slot_count_modifier = 0
	
	return mod

## ==================== 长枪 ====================
## 特质：穿透 - 一往无前，势如破竹
## 特点：中等前摇，穿透和位移效果增强，冲刺触发加成
static func _create_spear_modifier() -> WeaponTraitModifier:
	var mod = WeaponTraitModifier.new()
	mod.trait_name = "穿透"
	mod.trait_description = "一往无前，势如破竹，贯穿万物"
	
	# 基础修正 - 中等偏高
	mod.windup_multiplier = 1.2      # 前摇增加20%
	mod.cost_multiplier = 1.1        # 消耗增加10%
	mod.effect_multiplier = 1.3      # 效果增加30%
	mod.cooldown_multiplier = 1.0
	
	# 触发器亲和 - 冲刺和移动触发加成
	mod.trigger_affinity = {
		TriggerData.TriggerType.ON_DASH: 1.6,            # 冲刺 +60%
		TriggerData.TriggerType.ON_MOVE_START: 1.2,      # 移动开始 +20%
		TriggerData.TriggerType.ON_WEAPON_HIT: 1.3,      # 武器命中 +30%
		TriggerData.TriggerType.ON_ATTACK_ACTIVE: 1.4,   # 攻击判定 +40%
	}
	
	# 动作亲和 - 位移和穿透效果加成
	mod.action_affinity = {
		ActionData.ActionType.DISPLACEMENT: 1.5,         # 位移 +50%
		ActionData.ActionType.DAMAGE: 1.2,               # 伤害 +20%
		ActionData.ActionType.CHAIN: 1.3,                # 链式（穿透感） +30%
		ActionData.ActionType.AREA_EFFECT: 0.7,          # 范围效果 -30%
	}
	
	# 特殊规则
	mod.can_cast_while_attacking = true
	mod.can_cast_while_moving = true
	mod.requires_weapon_hit = false
	mod.first_cast_bonus = 0.25       # 首击加成25%（突刺）
	mod.chain_cast_bonus = 0.0
	
	# 容量
	mod.capacity_multiplier = 1.2
	mod.slot_count_modifier = 1
	
	return mod

## ==================== 匕首 ====================
## 特质：隐秘 - 伺机而动，一击致命
## 特点：极低前摇，暴击和闪避触发加成，单体伤害增强
static func _create_dagger_modifier() -> WeaponTraitModifier:
	var mod = WeaponTraitModifier.new()
	mod.trait_name = "隐秘"
	mod.trait_description = "伺机而动，一击致命，无声无息"
	
	# 基础修正 - 极快但效果一般
	mod.windup_multiplier = 0.4      # 前摇减少60%
	mod.cost_multiplier = 0.6        # 消耗减少40%
	mod.effect_multiplier = 0.9      # 效果略微减少
	mod.cooldown_multiplier = 0.7    # 冷却减少30%
	
	# 触发器亲和 - 暴击和闪避触发加成
	mod.trigger_affinity = {
		TriggerData.TriggerType.ON_CRITICAL_HIT: 2.0,    # 暴击 +100%
		TriggerData.TriggerType.ON_DODGE_SUCCESS: 1.5,   # 闪避成功 +50%
		TriggerData.TriggerType.ON_KILL_ENEMY: 1.8,      # 击杀 +80%
		TriggerData.TriggerType.ON_ATTACK_START: 1.2,    # 攻击开始 +20%
		TriggerData.TriggerType.ON_COMBO_HIT: 0.5,       # 连击 -50%（不适合正面连击）
	}
	
	# 动作亲和 - 单体伤害和状态效果加成
	mod.action_affinity = {
		ActionData.ActionType.DAMAGE: 1.4,               # 单体伤害 +40%
		ActionData.ActionType.APPLY_STATUS: 1.5,         # 状态效果（毒等） +50%
		ActionData.ActionType.AREA_EFFECT: 0.4,          # 范围效果 -60%
		ActionData.ActionType.SPAWN_EXPLOSION: 0.5,      # 爆炸 -50%
	}
	
	# 特殊规则
	mod.can_cast_while_attacking = true
	mod.can_cast_while_moving = true
	mod.requires_weapon_hit = true    # 必须命中才能触发
	mod.first_cast_bonus = 0.5        # 首击加成50%（暗杀）
	mod.chain_cast_bonus = 0.0
	
	# 容量 - 匕首容量低
	mod.capacity_multiplier = 0.5
	mod.slot_count_modifier = -1
	
	return mod

## ==================== 法杖 ====================
## 特质：引导 - 沟通天地，引导灵力
## 特点：高前摇高效果，施法触发加成，所有法术效果增强
static func _create_staff_modifier() -> WeaponTraitModifier:
	var mod = WeaponTraitModifier.new()
	mod.trait_name = "引导"
	mod.trait_description = "沟通天地，引导灵力，法术增幅"
	
	# 基础修正 - 法术专精
	mod.windup_multiplier = 1.3      # 前摇增加30%
	mod.cost_multiplier = 0.8        # 消耗减少20%（法力亲和）
	mod.effect_multiplier = 1.6      # 效果增加60%
	mod.cooldown_multiplier = 0.9    # 冷却略微减少
	
	# 触发器亲和 - 施法和法术触发加成
	mod.trigger_affinity = {
		TriggerData.TriggerType.ON_SPELL_CAST: 1.8,      # 施法 +80%
		TriggerData.TriggerType.ON_SPELL_HIT: 1.5,       # 法术命中 +50%
		TriggerData.TriggerType.ON_TICK: 1.3,            # 周期 +30%
		TriggerData.TriggerType.ON_INTERVAL: 1.3,        # 间隔 +30%
		TriggerData.TriggerType.ON_WEAPON_HIT: 0.5,      # 武器命中 -50%
		TriggerData.TriggerType.ON_ATTACK_START: 0.6,    # 攻击开始 -40%
	}
	
	# 动作亲和 - 所有法术效果加成
	mod.action_affinity = {
		ActionData.ActionType.DAMAGE: 1.3,               # 伤害 +30%
		ActionData.ActionType.AREA_EFFECT: 1.5,          # 范围效果 +50%
		ActionData.ActionType.SPAWN_EXPLOSION: 1.4,      # 爆炸 +40%
		ActionData.ActionType.CHAIN: 1.5,                # 链式 +50%
		ActionData.ActionType.APPLY_STATUS: 1.4,         # 状态效果 +40%
		ActionData.ActionType.SUMMON: 1.6,               # 召唤 +60%
		ActionData.ActionType.SHIELD: 1.3,               # 护盾 +30%
		ActionData.ActionType.FISSION: 1.4,              # 裂变 +40%
		ActionData.ActionType.ENERGY_RESTORE: 1.2,       # 能量恢复 +20%
		ActionData.ActionType.CULTIVATION: 1.2,          # 修炼 +20%
	}
	
	# 特殊规则
	mod.can_cast_while_attacking = false
	mod.can_cast_while_moving = true
	mod.requires_weapon_hit = false
	mod.chain_cast_bonus = 0.1        # 连续施法加成
	mod.first_cast_bonus = 0.0
	
	# 容量 - 法杖容量最高
	mod.capacity_multiplier = 1.5
	mod.slot_count_modifier = 2
	
	return mod

## 获取所有武器类型的特质对比表
static func get_comparison_table() -> Array[Dictionary]:
	var table: Array[Dictionary] = []
	
	for weapon_type in WeaponData.WeaponType.values():
		var mod = get_modifier_for_type(weapon_type)
		table.append({
			"weapon_type": weapon_type,
			"trait_name": mod.trait_name,
			"windup": mod.windup_multiplier,
			"cost": mod.cost_multiplier,
			"effect": mod.effect_multiplier,
			"cooldown": mod.cooldown_multiplier,
			"capacity": mod.capacity_multiplier,
			"slot_modifier": mod.slot_count_modifier,
		})
	
	return table

## 打印特质对比表
static func print_comparison_table() -> void:
	print("=== 武器特质对比表 ===")
	print("%-10s | %-6s | %-6s | %-6s | %-6s | %-6s | %-6s | %-6s" % [
		"武器类型", "特质", "前摇", "消耗", "效果", "冷却", "容量", "槽位"
	])
	print("-".repeat(70))
	
	for data in get_comparison_table():
		var type_name = WeaponData.WeaponType.keys()[data.weapon_type]
		print("%-10s | %-6s | %5.0f%% | %5.0f%% | %5.0f%% | %5.0f%% | %5.0f%% | %+d" % [
			type_name,
			data.trait_name,
			data.windup * 100,
			data.cost * 100,
			data.effect * 100,
			data.cooldown * 100,
			data.capacity * 100,
			data.slot_modifier,
		])
