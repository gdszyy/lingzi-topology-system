class_name ShieldActionData
extends ActionData

enum ShieldType {
	PERSONAL,
	AREA,
	PROJECTILE
}

@export var shield_type: ShieldType = ShieldType.PERSONAL
@export var shield_amount: float = 50.0
@export var shield_duration: float = 5.0
@export var shield_radius: float = 80.0
@export var shield_regen: float = 0.0
@export var damage_reduction: float = 0.0
@export var on_break_explode: bool = false
@export var break_explosion_damage: float = 30.0

func _init():
	action_type = ActionType.SHIELD

func get_type_name() -> String:
	match shield_type:
		ShieldType.PERSONAL:
			return "个人护盾"
		ShieldType.AREA:
			return "范围护盾"
		ShieldType.PROJECTILE:
			return "弹幕护盾"
	return "护盾"

func clone_deep() -> ActionData:
	var copy = ShieldActionData.new()
	copy.action_type = action_type
	copy.shield_type = shield_type
	copy.shield_amount = shield_amount
	copy.shield_duration = shield_duration
	copy.shield_radius = shield_radius
	copy.shield_regen = shield_regen
	copy.damage_reduction = damage_reduction
	copy.on_break_explode = on_break_explode
	copy.break_explosion_damage = break_explosion_damage
	return copy

func to_dict() -> Dictionary:
	var base = super.to_dict()
	base["shield_type"] = shield_type
	base["shield_amount"] = shield_amount
	base["shield_duration"] = shield_duration
	base["shield_radius"] = shield_radius
	base["shield_regen"] = shield_regen
	base["damage_reduction"] = damage_reduction
	base["on_break_explode"] = on_break_explode
	base["break_explosion_damage"] = break_explosion_damage
	return base

static func from_dict(data: Dictionary) -> ShieldActionData:
	var action = ShieldActionData.new()
	action.shield_type = data.get("shield_type", ShieldType.PERSONAL)
	action.shield_amount = data.get("shield_amount", 50.0)
	action.shield_duration = data.get("shield_duration", 5.0)
	action.shield_radius = data.get("shield_radius", 80.0)
	action.shield_regen = data.get("shield_regen", 0.0)
	action.damage_reduction = data.get("damage_reduction", 0.0)
	action.on_break_explode = data.get("on_break_explode", false)
	action.break_explosion_damage = data.get("break_explosion_damage", 30.0)
	return action
