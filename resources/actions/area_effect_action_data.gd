class_name AreaEffectActionData
extends ActionData

enum AreaShape {
	CIRCLE,
	CONE,
	LINE,
	RECTANGLE
}

@export var area_shape: AreaShape = AreaShape.CIRCLE
@export var radius: float = 50.0
@export var angle: float = 90.0
@export var length: float = 100.0
@export var width: float = 20.0
@export var damage_value: float = 15.0
@export var damage_falloff: float = 0.5

func _init():
	action_type = ActionType.AREA_EFFECT

func clone_deep() -> ActionData:
	var copy = AreaEffectActionData.new()
	copy.action_type = action_type
	copy.area_shape = area_shape
	copy.radius = radius
	copy.angle = angle
	copy.length = length
	copy.width = width
	copy.damage_value = damage_value
	copy.damage_falloff = damage_falloff
	return copy

func to_dict() -> Dictionary:
	var base = super.to_dict()
	base["area_shape"] = area_shape
	base["radius"] = radius
	base["angle"] = angle
	base["length"] = length
	base["width"] = width
	base["damage_value"] = damage_value
	base["damage_falloff"] = damage_falloff
	return base

static func from_dict(data: Dictionary) -> AreaEffectActionData:
	var action = AreaEffectActionData.new()
	action.area_shape = data.get("area_shape", AreaShape.CIRCLE)
	action.radius = data.get("radius", 50.0)
	action.angle = data.get("angle", 90.0)
	action.length = data.get("length", 100.0)
	action.width = data.get("width", 20.0)
	action.damage_value = data.get("damage_value", 15.0)
	action.damage_falloff = data.get("damage_falloff", 0.5)
	return action
