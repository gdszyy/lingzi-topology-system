class_name CultivationActionData
extends ActionData

## 修炼动作
## 消耗当前能量来恢复能量上限（相当于治疗）

enum CultivationType {
	INSTANT,      # 瞬间修复
	OVER_TIME,    # 持续修复
	BOOST         # 临时提升修炼效率
}

## 修炼类型
@export var cultivation_type: CultivationType = CultivationType.INSTANT

## 恢复的能量上限值
@export var cap_restore_value: float = 15.0

## 能量消耗倍率（相对于恢复值）
@export var energy_cost_multiplier: float = 5.0

## 持续时间（仅对 OVER_TIME 和 BOOST 类型有效）
@export var duration: float = 5.0

## 效率提升倍率（仅对 BOOST 类型有效）
@export var efficiency_boost: float = 2.0

## 是否对自身生效
@export var apply_to_self: bool = true

## 是否对友军生效
@export var apply_to_allies: bool = false

## 效果范围（对友军生效时使用）
@export var effect_radius: float = 100.0

func _init():
	action_type = 12  # ActionType.CULTIVATION

func get_type_name() -> String:
	match cultivation_type:
		CultivationType.INSTANT:
			return "瞬间修复"
		CultivationType.OVER_TIME:
			return "持续修复"
		CultivationType.BOOST:
			return "修炼增效"
	return "修炼"

func get_energy_cost() -> float:
	return cap_restore_value * energy_cost_multiplier

func clone_deep() -> ActionData:
	var copy = CultivationActionData.new()
	copy.action_type = action_type
	copy.cultivation_type = cultivation_type
	copy.cap_restore_value = cap_restore_value
	copy.energy_cost_multiplier = energy_cost_multiplier
	copy.duration = duration
	copy.efficiency_boost = efficiency_boost
	copy.apply_to_self = apply_to_self
	copy.apply_to_allies = apply_to_allies
	copy.effect_radius = effect_radius
	return copy

func to_dict() -> Dictionary:
	var base = super.to_dict()
	base["cultivation_type"] = cultivation_type
	base["cap_restore_value"] = cap_restore_value
	base["energy_cost_multiplier"] = energy_cost_multiplier
	base["duration"] = duration
	base["efficiency_boost"] = efficiency_boost
	base["apply_to_self"] = apply_to_self
	base["apply_to_allies"] = apply_to_allies
	base["effect_radius"] = effect_radius
	return base

static func from_dict(data: Dictionary) -> CultivationActionData:
	var action = CultivationActionData.new()
	action.cultivation_type = data.get("cultivation_type", CultivationType.INSTANT)
	action.cap_restore_value = data.get("cap_restore_value", 15.0)
	action.energy_cost_multiplier = data.get("energy_cost_multiplier", 5.0)
	action.duration = data.get("duration", 5.0)
	action.efficiency_boost = data.get("efficiency_boost", 2.0)
	action.apply_to_self = data.get("apply_to_self", true)
	action.apply_to_allies = data.get("apply_to_allies", false)
	action.effect_radius = data.get("effect_radius", 100.0)
	return action
