class_name WeaponTraitModifier extends Resource

## 武器特质修正器
## 定义特定武器类型对篆刻法术的规则调整
## 武器不再是直接伤害来源，而是"特质"的象征

## 基础修正值（乘数形式，1.0 = 无修正）
@export_group("基础修正")
@export var windup_multiplier: float = 1.0        ## 前摇时间乘数
@export var cost_multiplier: float = 1.0          ## 能量消耗乘数
@export var effect_multiplier: float = 1.0        ## 效果强度乘数
@export var cooldown_multiplier: float = 1.0      ## 冷却时间乘数

## 触发器亲和度（对特定触发器的额外修正）
## 键: TriggerData.TriggerType (int), 值: 乘数 (float)
@export_group("触发器亲和")
@export var trigger_affinity: Dictionary = {}

## 动作类型亲和度（对特定动作类型的额外修正）
## 键: ActionData.ActionType (int), 值: 乘数 (float)
@export_group("动作亲和")
@export var action_affinity: Dictionary = {}

## 特殊规则
@export_group("特殊规则")
@export var can_cast_while_attacking: bool = false    ## 是否可在攻击中触发
@export var can_cast_while_moving: bool = true        ## 是否可在移动中触发
@export var requires_weapon_hit: bool = false         ## 是否必须武器命中才能触发
@export var chain_cast_bonus: float = 0.0             ## 连续触发加成（每次叠加）
@export var first_cast_bonus: float = 0.0             ## 首次触发加成

## 容量修正
@export_group("容量修正")
@export var capacity_multiplier: float = 1.0          ## 篆刻容量乘数
@export var slot_count_modifier: int = 0              ## 槽位数量修正

## 特质描述
@export_group("描述")
@export var trait_name: String = ""                   ## 特质名称
@export var trait_description: String = ""            ## 特质描述

## 获取对特定触发器的最终前摇乘数
func get_windup_for_trigger(trigger_type: int) -> float:
	var base = windup_multiplier
	if trigger_affinity.has(trigger_type):
		base *= trigger_affinity[trigger_type]
	return base

## 获取对特定动作的最终效果乘数
func get_effect_for_action(action_type: int) -> float:
	var base = effect_multiplier
	if action_affinity.has(action_type):
		base *= action_affinity[action_type]
	return base

## 获取对特定触发器的最终消耗乘数
func get_cost_for_trigger(trigger_type: int) -> float:
	var base = cost_multiplier
	if trigger_affinity.has(trigger_type):
		# 触发器亲和度高的，消耗略微降低
		var affinity = trigger_affinity[trigger_type]
		if affinity > 1.0:
			# 亲和度1.5时，消耗变为0.75倍
			base *= (2.0 - affinity * 0.5)
	return max(0.1, base)  # 最低10%消耗

## 获取对特定触发器的最终冷却乘数
func get_cooldown_for_trigger(trigger_type: int) -> float:
	var base = cooldown_multiplier
	if trigger_affinity.has(trigger_type):
		# 亲和度高的触发器，冷却略微降低
		var affinity = trigger_affinity[trigger_type]
		if affinity > 1.0:
			base *= (2.0 - affinity * 0.3)
	return max(0.2, base)  # 最低20%冷却

## 计算连续触发的累计加成
func get_chain_bonus(consecutive_count: int) -> float:
	if consecutive_count <= 0:
		return first_cast_bonus
	return chain_cast_bonus * consecutive_count

## 检查是否可以在当前状态下触发
func can_trigger_in_state(is_attacking: bool, is_moving: bool) -> bool:
	if is_attacking and not can_cast_while_attacking:
		return false
	if is_moving and not can_cast_while_moving:
		return false
	return true

## 检查触发器类型是否满足武器命中要求
func check_weapon_hit_requirement(trigger_type: int) -> bool:
	if not requires_weapon_hit:
		return true
	
	# 这些触发器类型满足"武器命中"要求
	var hit_triggers = [
		TriggerData.TriggerType.ON_WEAPON_HIT,
		TriggerData.TriggerType.ON_CRITICAL_HIT,
		TriggerData.TriggerType.ON_COMBO_HIT,
		TriggerData.TriggerType.ON_DEAL_DAMAGE,
	]
	
	return trigger_type in hit_triggers

## 获取触发器亲和度
func get_trigger_affinity(trigger_type: int) -> float:
	return trigger_affinity.get(trigger_type, 1.0)

## 获取动作亲和度
func get_action_affinity(action_type: int) -> float:
	return action_affinity.get(action_type, 1.0)

## 判断是否对某触发器有亲和
func has_trigger_affinity(trigger_type: int) -> bool:
	return trigger_affinity.has(trigger_type) and trigger_affinity[trigger_type] > 1.0

## 判断是否对某动作有亲和
func has_action_affinity(action_type: int) -> bool:
	return action_affinity.has(action_type) and action_affinity[action_type] > 1.0

## 获取所有高亲和度触发器
func get_high_affinity_triggers() -> Array[int]:
	var result: Array[int] = []
	for trigger_type in trigger_affinity.keys():
		if trigger_affinity[trigger_type] > 1.0:
			result.append(trigger_type)
	return result

## 获取所有高亲和度动作
func get_high_affinity_actions() -> Array[int]:
	var result: Array[int] = []
	for action_type in action_affinity.keys():
		if action_affinity[action_type] > 1.0:
			result.append(action_type)
	return result

## 克隆
func clone_deep() -> WeaponTraitModifier:
	var copy = WeaponTraitModifier.new()
	copy.windup_multiplier = windup_multiplier
	copy.cost_multiplier = cost_multiplier
	copy.effect_multiplier = effect_multiplier
	copy.cooldown_multiplier = cooldown_multiplier
	copy.trigger_affinity = trigger_affinity.duplicate()
	copy.action_affinity = action_affinity.duplicate()
	copy.can_cast_while_attacking = can_cast_while_attacking
	copy.can_cast_while_moving = can_cast_while_moving
	copy.requires_weapon_hit = requires_weapon_hit
	copy.chain_cast_bonus = chain_cast_bonus
	copy.first_cast_bonus = first_cast_bonus
	copy.capacity_multiplier = capacity_multiplier
	copy.slot_count_modifier = slot_count_modifier
	copy.trait_name = trait_name
	copy.trait_description = trait_description
	return copy

## 序列化
func to_dict() -> Dictionary:
	return {
		"windup_multiplier": windup_multiplier,
		"cost_multiplier": cost_multiplier,
		"effect_multiplier": effect_multiplier,
		"cooldown_multiplier": cooldown_multiplier,
		"trigger_affinity": trigger_affinity,
		"action_affinity": action_affinity,
		"can_cast_while_attacking": can_cast_while_attacking,
		"can_cast_while_moving": can_cast_while_moving,
		"requires_weapon_hit": requires_weapon_hit,
		"chain_cast_bonus": chain_cast_bonus,
		"first_cast_bonus": first_cast_bonus,
		"capacity_multiplier": capacity_multiplier,
		"slot_count_modifier": slot_count_modifier,
		"trait_name": trait_name,
		"trait_description": trait_description,
	}

## 反序列化
static func from_dict(data: Dictionary) -> WeaponTraitModifier:
	var modifier = WeaponTraitModifier.new()
	modifier.windup_multiplier = data.get("windup_multiplier", 1.0)
	modifier.cost_multiplier = data.get("cost_multiplier", 1.0)
	modifier.effect_multiplier = data.get("effect_multiplier", 1.0)
	modifier.cooldown_multiplier = data.get("cooldown_multiplier", 1.0)
	modifier.trigger_affinity = data.get("trigger_affinity", {})
	modifier.action_affinity = data.get("action_affinity", {})
	modifier.can_cast_while_attacking = data.get("can_cast_while_attacking", false)
	modifier.can_cast_while_moving = data.get("can_cast_while_moving", true)
	modifier.requires_weapon_hit = data.get("requires_weapon_hit", false)
	modifier.chain_cast_bonus = data.get("chain_cast_bonus", 0.0)
	modifier.first_cast_bonus = data.get("first_cast_bonus", 0.0)
	modifier.capacity_multiplier = data.get("capacity_multiplier", 1.0)
	modifier.slot_count_modifier = data.get("slot_count_modifier", 0)
	modifier.trait_name = data.get("trait_name", "")
	modifier.trait_description = data.get("trait_description", "")
	return modifier

## 获取摘要信息
func get_summary() -> String:
	var parts: Array[String] = []
	
	if windup_multiplier != 1.0:
		parts.append("前摇×%.0f%%" % (windup_multiplier * 100))
	if cost_multiplier != 1.0:
		parts.append("消耗×%.0f%%" % (cost_multiplier * 100))
	if effect_multiplier != 1.0:
		parts.append("效果×%.0f%%" % (effect_multiplier * 100))
	if cooldown_multiplier != 1.0:
		parts.append("冷却×%.0f%%" % (cooldown_multiplier * 100))
	
	if parts.is_empty():
		return "无修正"
	
	return ", ".join(parts)
