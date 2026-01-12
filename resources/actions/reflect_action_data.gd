class_name ReflectActionData
extends ActionData

enum ReflectType {
	PROJECTILE,
	DAMAGE,
	BOTH
}

@export var reflect_type: ReflectType = ReflectType.PROJECTILE
@export var reflect_damage_ratio: float = 0.5
@export var reflect_projectile: bool = true
@export var reflect_angle: float = 180.0
@export var reflect_radius: float = 60.0
@export var reflect_duration: float = 2.0
@export var max_reflects: int = 3
@export var reflect_speed_multiplier: float = 1.2

func _init():
	action_type = ActionType.REFLECT

func get_type_name() -> String:
	match reflect_type:
		ReflectType.PROJECTILE:
			return "弹幕反弹"
		ReflectType.DAMAGE:
			return "伤害反弹"
		ReflectType.BOTH:
			return "全反弹"
	return "反弹"

func clone_deep() -> ActionData:
	var copy = ReflectActionData.new()
	copy.action_type = action_type
	copy.reflect_type = reflect_type
	copy.reflect_damage_ratio = reflect_damage_ratio
	copy.reflect_projectile = reflect_projectile
	copy.reflect_angle = reflect_angle
	copy.reflect_radius = reflect_radius
	copy.reflect_duration = reflect_duration
	copy.max_reflects = max_reflects
	copy.reflect_speed_multiplier = reflect_speed_multiplier
	return copy

func to_dict() -> Dictionary:
	var base = super.to_dict()
	base["reflect_type"] = reflect_type
	base["reflect_damage_ratio"] = reflect_damage_ratio
	base["reflect_projectile"] = reflect_projectile
	base["reflect_angle"] = reflect_angle
	base["reflect_radius"] = reflect_radius
	base["reflect_duration"] = reflect_duration
	base["max_reflects"] = max_reflects
	base["reflect_speed_multiplier"] = reflect_speed_multiplier
	return base

static func from_dict(data: Dictionary) -> ReflectActionData:
	var action = ReflectActionData.new()
	action.reflect_type = data.get("reflect_type", ReflectType.PROJECTILE)
	action.reflect_damage_ratio = data.get("reflect_damage_ratio", 0.5)
	action.reflect_projectile = data.get("reflect_projectile", true)
	action.reflect_angle = data.get("reflect_angle", 180.0)
	action.reflect_radius = data.get("reflect_radius", 60.0)
	action.reflect_duration = data.get("reflect_duration", 2.0)
	action.max_reflects = data.get("max_reflects", 3)
	action.reflect_speed_multiplier = data.get("reflect_speed_multiplier", 1.2)
	return action
