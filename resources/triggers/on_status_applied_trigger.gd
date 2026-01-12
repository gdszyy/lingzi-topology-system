class_name OnStatusAppliedTrigger
extends TriggerData

@export var required_status_type: int = 0

@export var required_stacks: int = 1

@export var trigger_on_expire: bool = false

@export var trigger_on_first_apply_only: bool = false

func _init():
	trigger_type = TriggerType.ON_STATUS_APPLIED

func get_type_name() -> String:
	var status_name = _get_status_name(required_status_type)
	if trigger_on_expire:
		return "状态结束触发 (%s)" % status_name
	return "状态触发 (%s)" % status_name

func _get_status_name(status_type: int) -> String:
	match status_type:
		0: return "燃烧"
		1: return "冰冻"
		2: return "中毒"
		3: return "减速"
		4: return "眩晕"
		5: return "虚弱"
		6: return "束缚"
		7: return "沉默"
		8: return "标记"
		9: return "致盲"
		10: return "诅咒"
		11: return "强化"
		12: return "加速"
		13: return "护盾"
	return "未知"

func clone_deep() -> TriggerData:
	var copy = OnStatusAppliedTrigger.new()
	copy.trigger_type = trigger_type
	copy.trigger_once = trigger_once
	copy.required_status_type = required_status_type
	copy.required_stacks = required_stacks
	copy.trigger_on_expire = trigger_on_expire
	copy.trigger_on_first_apply_only = trigger_on_first_apply_only
	return copy

func to_dict() -> Dictionary:
	var base = super.to_dict()
	base["required_status_type"] = required_status_type
	base["required_stacks"] = required_stacks
	base["trigger_on_expire"] = trigger_on_expire
	base["trigger_on_first_apply_only"] = trigger_on_first_apply_only
	return base

static func from_dict(data: Dictionary) -> OnStatusAppliedTrigger:
	var trigger = OnStatusAppliedTrigger.new()
	trigger.trigger_once = data.get("trigger_once", true)
	trigger.required_status_type = data.get("required_status_type", 0)
	trigger.required_stacks = data.get("required_stacks", 1)
	trigger.trigger_on_expire = data.get("trigger_on_expire", false)
	trigger.trigger_on_first_apply_only = data.get("trigger_on_first_apply_only", false)
	return trigger
