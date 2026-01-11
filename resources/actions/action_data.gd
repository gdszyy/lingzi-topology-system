# action_data.gd
# 效果动作数据基类 - 定义触发后执行的效果
class_name ActionData
extends Resource

## 动作类型枚举
enum ActionType {
	DAMAGE,          # 造成伤害
	FISSION,         # 裂变（生成子弹）
	APPLY_STATUS,    # 施加状态效果
	MOVEMENT_CHANGE, # 改变运动状态
	AREA_EFFECT,     # 范围效果
	HEAL             # 治疗
}

@export var action_type: ActionType = ActionType.DAMAGE

## 获取动作类型名称
func get_type_name() -> String:
	match action_type:
		ActionType.DAMAGE:
			return "伤害"
		ActionType.FISSION:
			return "裂变"
		ActionType.APPLY_STATUS:
			return "状态效果"
		ActionType.MOVEMENT_CHANGE:
			return "运动改变"
		ActionType.AREA_EFFECT:
			return "范围效果"
		ActionType.HEAL:
			return "治疗"
	return "未知动作"

## 深拷贝（子类需要重写）
func clone_deep() -> ActionData:
	var copy = ActionData.new()
	copy.action_type = action_type
	return copy

## 转换为字典
func to_dict() -> Dictionary:
	return {
		"action_type": action_type
	}

## 从字典加载
static func from_dict(data: Dictionary) -> ActionData:
	var action_type_val = data.get("action_type", ActionType.DAMAGE)
	var action: ActionData
	
	match action_type_val:
		ActionType.DAMAGE:
			action = DamageActionData.from_dict(data)
		ActionType.FISSION:
			action = FissionActionData.from_dict(data)
		ActionType.APPLY_STATUS:
			action = ApplyStatusActionData.from_dict(data)
		ActionType.AREA_EFFECT:
			action = AreaEffectActionData.from_dict(data)
		_:
			action = ActionData.new()
			action.action_type = action_type_val
	
	return action
