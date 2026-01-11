# on_timer_trigger.gd
# 定时触发器 - 在指定时间后触发效果
class_name OnTimerTrigger
extends TriggerData

@export var delay: float = 1.0           # 延迟时间（秒）
@export var repeat_interval: float = 0.0  # 重复间隔（0 = 不重复）

func _init():
	trigger_type = TriggerType.ON_TIMER

func clone_deep() -> TriggerData:
	var copy = OnTimerTrigger.new()
	copy.trigger_type = trigger_type
	copy.trigger_once = trigger_once
	copy.delay = delay
	copy.repeat_interval = repeat_interval
	return copy

func to_dict() -> Dictionary:
	var base = super.to_dict()
	base["delay"] = delay
	base["repeat_interval"] = repeat_interval
	return base

static func from_dict(data: Dictionary) -> OnTimerTrigger:
	var trigger = OnTimerTrigger.new()
	trigger.trigger_once = data.get("trigger_once", true)
	trigger.delay = data.get("delay", 1.0)
	trigger.repeat_interval = data.get("repeat_interval", 0.0)
	return trigger
