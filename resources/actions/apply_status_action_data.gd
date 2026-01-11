# apply_status_action_data.gd
# 状态效果动作数据 - 对目标施加状态效果
class_name ApplyStatusActionData
extends ActionData

## 状态效果类型
enum StatusType {
	BURNING,     # 燃烧 - 持续火焰伤害
	FROZEN,      # 冰冻 - 减速/定身
	POISONED,    # 中毒 - 持续伤害
	SLOWED,      # 减速
	STUNNED,     # 眩晕
	WEAKENED     # 虚弱 - 降低防御
}

@export var status_type: StatusType = StatusType.BURNING
@export var duration: float = 3.0           # 持续时间
@export var tick_interval: float = 0.5      # 效果触发间隔
@export var effect_value: float = 5.0       # 效果数值（伤害/减速百分比等）
@export var stack_limit: int = 3            # 最大叠加层数

func _init():
	action_type = ActionType.APPLY_STATUS

func clone_deep() -> ActionData:
	var copy = ApplyStatusActionData.new()
	copy.action_type = action_type
	copy.status_type = status_type
	copy.duration = duration
	copy.tick_interval = tick_interval
	copy.effect_value = effect_value
	copy.stack_limit = stack_limit
	return copy

func to_dict() -> Dictionary:
	var base = super.to_dict()
	base["status_type"] = status_type
	base["duration"] = duration
	base["tick_interval"] = tick_interval
	base["effect_value"] = effect_value
	base["stack_limit"] = stack_limit
	return base

static func from_dict(data: Dictionary) -> ApplyStatusActionData:
	var action = ApplyStatusActionData.new()
	action.status_type = data.get("status_type", StatusType.BURNING)
	action.duration = data.get("duration", 3.0)
	action.tick_interval = data.get("tick_interval", 0.5)
	action.effect_value = data.get("effect_value", 5.0)
	action.stack_limit = data.get("stack_limit", 3)
	return action
