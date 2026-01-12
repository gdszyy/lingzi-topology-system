class_name OnProximityTrigger
extends TriggerData

@export var detection_radius: float = 100.0
@export var target_type: String = "enemy"

func _init():
	trigger_type = TriggerType.ON_PROXIMITY

func clone_deep() -> TriggerData:
	var copy = OnProximityTrigger.new()
	copy.trigger_type = trigger_type
	copy.trigger_once = trigger_once
	copy.detection_radius = detection_radius
	copy.target_type = target_type
	return copy

func to_dict() -> Dictionary:
	var base = super.to_dict()
	base["detection_radius"] = detection_radius
	base["target_type"] = target_type
	return base

static func from_dict(data: Dictionary) -> OnProximityTrigger:
	var trigger = OnProximityTrigger.new()
	trigger.trigger_once = data.get("trigger_once", true)
	trigger.detection_radius = data.get("detection_radius", 100.0)
	trigger.target_type = data.get("target_type", "enemy")
	return trigger
