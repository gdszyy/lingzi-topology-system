# trigger_data.gd
# 触发器数据基类 - 定义法术效果的触发条件
class_name TriggerData
extends Resource

## 触发器类型枚举
enum TriggerType {
	ON_CONTACT,          # 碰撞触发（敌方）
	ON_TIMER,            # 定时触发
	ON_PROXIMITY,        # 接近触发
	ON_DEATH,            # 死亡触发（载体消失时）
	ON_HEALTH_THRESHOLD, # 生命值阈值触发
	ON_ALLY_CONTACT,     # 友方单位触发
	ON_STATUS_APPLIED,   # 目标被施加特定状态时触发
	ON_CHAIN_END,        # 链式传导结束时触发
	ON_SHIELD_BREAK,     # 护盾破碎时触发
	ON_SUMMON_DEATH,     # 召唤物死亡时触发
	ON_REFLECT           # 反弹发生时触发
}

@export var trigger_type: TriggerType = TriggerType.ON_CONTACT
@export var trigger_once: bool = true  # 是否只触发一次

## 获取触发器类型名称
func get_type_name() -> String:
	match trigger_type:
		TriggerType.ON_CONTACT:
			return "碰撞触发"
		TriggerType.ON_TIMER:
			return "定时触发"
		TriggerType.ON_PROXIMITY:
			return "接近触发"
		TriggerType.ON_DEATH:
			return "消亡触发"
		TriggerType.ON_HEALTH_THRESHOLD:
			return "生命阈值触发"
		TriggerType.ON_ALLY_CONTACT:
			return "友方触发"
		TriggerType.ON_STATUS_APPLIED:
			return "状态触发"
		TriggerType.ON_CHAIN_END:
			return "链式结束触发"
		TriggerType.ON_SHIELD_BREAK:
			return "护盾破碎触发"
		TriggerType.ON_SUMMON_DEATH:
			return "召唤物死亡触发"
		TriggerType.ON_REFLECT:
			return "反弹触发"
	return "未知触发器"

## 深拷贝（子类需要重写）
func clone_deep() -> TriggerData:
	var copy = TriggerData.new()
	copy.trigger_type = trigger_type
	copy.trigger_once = trigger_once
	return copy

## 转换为字典
func to_dict() -> Dictionary:
	return {
		"trigger_type": trigger_type,
		"trigger_once": trigger_once
	}

## 从字典加载
static func from_dict(data: Dictionary) -> TriggerData:
	var trigger_type_val = data.get("trigger_type", TriggerType.ON_CONTACT)
	var trigger: TriggerData
	
	# 根据类型创建具体的触发器
	match trigger_type_val:
		TriggerType.ON_TIMER:
			trigger = OnTimerTrigger.from_dict(data)
		TriggerType.ON_PROXIMITY:
			trigger = OnProximityTrigger.from_dict(data)
		TriggerType.ON_STATUS_APPLIED:
			trigger = OnStatusAppliedTrigger.from_dict(data)
		_:
			trigger = TriggerData.new()
			trigger.trigger_type = trigger_type_val
			trigger.trigger_once = data.get("trigger_once", true)
	
	return trigger
