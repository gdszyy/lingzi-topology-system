# damage_action_data.gd
# 伤害动作数据 - 对目标造成伤害
class_name DamageActionData
extends ActionData

@export var damage_value: float = 10.0
@export var damage_type: CarrierConfigData.DamageType = CarrierConfigData.DamageType.KINETIC_IMPACT
@export var use_carrier_kinetic: bool = true  # 是否使用载体动能计算伤害
@export var damage_multiplier: float = 1.0    # 伤害倍率

func _init():
	action_type = ActionType.DAMAGE

func duplicate_deep() -> ActionData:
	var copy = DamageActionData.new()
	copy.action_type = action_type
	copy.damage_value = damage_value
	copy.damage_type = damage_type
	copy.use_carrier_kinetic = use_carrier_kinetic
	copy.damage_multiplier = damage_multiplier
	return copy

func to_dict() -> Dictionary:
	var base = super.to_dict()
	base["damage_value"] = damage_value
	base["damage_type"] = damage_type
	base["use_carrier_kinetic"] = use_carrier_kinetic
	base["damage_multiplier"] = damage_multiplier
	return base

static func from_dict(data: Dictionary) -> DamageActionData:
	var action = DamageActionData.new()
	action.damage_value = data.get("damage_value", 10.0)
	action.damage_type = data.get("damage_type", CarrierConfigData.DamageType.KINETIC_IMPACT)
	action.use_carrier_kinetic = data.get("use_carrier_kinetic", true)
	action.damage_multiplier = data.get("damage_multiplier", 1.0)
	return action
