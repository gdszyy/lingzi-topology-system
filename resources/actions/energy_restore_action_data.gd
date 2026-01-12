class_name EnergyRestoreActionData
extends ActionData

## 能量恢复动作
## 用于恢复目标的当前能量

enum RestoreType {
	INSTANT,      # 瞬间恢复
	OVER_TIME,    # 持续恢复
	PERCENTAGE    # 百分比恢复
}

## 恢复类型
@export var restore_type: RestoreType = RestoreType.INSTANT

## 恢复数值（瞬间恢复的能量值，或每秒恢复值）
@export var restore_value: float = 20.0

## 持续时间（仅对 OVER_TIME 类型有效）
@export var duration: float = 5.0

## 百分比值（仅对 PERCENTAGE 类型有效，0.0-1.0）
@export var percentage: float = 0.2

## 是否对自身生效
@export var apply_to_self: bool = true

## 是否对友军生效
@export var apply_to_allies: bool = false

## 效果范围（对友军生效时使用）
@export var effect_radius: float = 100.0

func _init():
	action_type = 11  # ActionType.ENERGY_RESTORE

func get_type_name() -> String:
	match restore_type:
		RestoreType.INSTANT:
			return "瞬间能量恢复"
		RestoreType.OVER_TIME:
			return "持续能量恢复"
		RestoreType.PERCENTAGE:
			return "百分比能量恢复"
	return "能量恢复"

func clone_deep() -> ActionData:
	var copy = EnergyRestoreActionData.new()
	copy.action_type = action_type
	copy.restore_type = restore_type
	copy.restore_value = restore_value
	copy.duration = duration
	copy.percentage = percentage
	copy.apply_to_self = apply_to_self
	copy.apply_to_allies = apply_to_allies
	copy.effect_radius = effect_radius
	return copy

func to_dict() -> Dictionary:
	var base = super.to_dict()
	base["restore_type"] = restore_type
	base["restore_value"] = restore_value
	base["duration"] = duration
	base["percentage"] = percentage
	base["apply_to_self"] = apply_to_self
	base["apply_to_allies"] = apply_to_allies
	base["effect_radius"] = effect_radius
	return base

static func from_dict(data: Dictionary) -> EnergyRestoreActionData:
	var action = EnergyRestoreActionData.new()
	action.restore_type = data.get("restore_type", RestoreType.INSTANT)
	action.restore_value = data.get("restore_value", 20.0)
	action.duration = data.get("duration", 5.0)
	action.percentage = data.get("percentage", 0.2)
	action.apply_to_self = data.get("apply_to_self", true)
	action.apply_to_allies = data.get("apply_to_allies", false)
	action.effect_radius = data.get("effect_radius", 100.0)
	return action
