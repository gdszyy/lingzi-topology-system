# apply_status_action_data.gd
# 状态效果动作数据 - 对目标施加状态效果
class_name ApplyStatusActionData
extends ActionData

## 状态效果类型
enum StatusType {
	BURNING,     # 燃烧 - 持续火焰伤害
	FROZEN,      # 冰冻 - 完全定身，无法移动和攻击
	POISONED,    # 中毒 - 持续伤害
	SLOWED,      # 减速 - 降低移动速度
	STUNNED,     # 眩晕 - 短暂无法行动
	WEAKENED,    # 虚弱 - 降低防御/伤害
	ROOTED,      # 束缚 - 不能移动但能攻击
	SILENCED,    # 沉默 - 不能施法
	MARKED,      # 标记 - 受到额外伤害
	BLINDED,     # 致盲 - 降低命中率
	CURSED,      # 诅咒 - 受到治疗效果降低
	EMPOWERED,   # 强化 - 增加伤害（正面效果）
	HASTED,      # 加速 - 增加移动速度（正面效果）
	SHIELDED     # 护盾 - 吸收伤害（正面效果）
}

## 状态效果分类
enum StatusCategory {
	DEBUFF,      # 负面效果
	BUFF,        # 正面效果
	NEUTRAL      # 中性效果
}

@export var status_type: StatusType = StatusType.BURNING
@export var duration: float = 3.0           # 持续时间
@export var tick_interval: float = 0.5      # 效果触发间隔
@export var effect_value: float = 5.0       # 效果数值（伤害/减速百分比等）
@export var stack_limit: int = 3            # 最大叠加层数
@export var refresh_on_apply: bool = true   # 重复施加时是否刷新持续时间
@export var spread_on_death: bool = false   # 目标死亡时是否传播给附近敌人
@export var spread_radius: float = 100.0    # 传播范围
@export var cleansable: bool = true         # 是否可被净化

func _init():
	action_type = ActionType.APPLY_STATUS

## 获取状态分类
func get_status_category() -> StatusCategory:
	match status_type:
		StatusType.EMPOWERED, StatusType.HASTED, StatusType.SHIELDED:
			return StatusCategory.BUFF
		StatusType.MARKED:
			return StatusCategory.NEUTRAL
		_:
			return StatusCategory.DEBUFF

## 获取状态名称
func get_status_name() -> String:
	match status_type:
		StatusType.BURNING:
			return "燃烧"
		StatusType.FROZEN:
			return "冰冻"
		StatusType.POISONED:
			return "中毒"
		StatusType.SLOWED:
			return "减速"
		StatusType.STUNNED:
			return "眩晕"
		StatusType.WEAKENED:
			return "虚弱"
		StatusType.ROOTED:
			return "束缚"
		StatusType.SILENCED:
			return "沉默"
		StatusType.MARKED:
			return "标记"
		StatusType.BLINDED:
			return "致盲"
		StatusType.CURSED:
			return "诅咒"
		StatusType.EMPOWERED:
			return "强化"
		StatusType.HASTED:
			return "加速"
		StatusType.SHIELDED:
			return "护盾"
	return "未知状态"

func clone_deep() -> ActionData:
	var copy = ApplyStatusActionData.new()
	copy.action_type = action_type
	copy.status_type = status_type
	copy.duration = duration
	copy.tick_interval = tick_interval
	copy.effect_value = effect_value
	copy.stack_limit = stack_limit
	copy.refresh_on_apply = refresh_on_apply
	copy.spread_on_death = spread_on_death
	copy.spread_radius = spread_radius
	copy.cleansable = cleansable
	return copy

func to_dict() -> Dictionary:
	var base = super.to_dict()
	base["status_type"] = status_type
	base["duration"] = duration
	base["tick_interval"] = tick_interval
	base["effect_value"] = effect_value
	base["stack_limit"] = stack_limit
	base["refresh_on_apply"] = refresh_on_apply
	base["spread_on_death"] = spread_on_death
	base["spread_radius"] = spread_radius
	base["cleansable"] = cleansable
	return base

static func from_dict(data: Dictionary) -> ApplyStatusActionData:
	var action = ApplyStatusActionData.new()
	action.status_type = data.get("status_type", StatusType.BURNING)
	action.duration = data.get("duration", 3.0)
	action.tick_interval = data.get("tick_interval", 0.5)
	action.effect_value = data.get("effect_value", 5.0)
	action.stack_limit = data.get("stack_limit", 3)
	action.refresh_on_apply = data.get("refresh_on_apply", true)
	action.spread_on_death = data.get("spread_on_death", false)
	action.spread_radius = data.get("spread_radius", 100.0)
	action.cleansable = data.get("cleansable", true)
	return action
