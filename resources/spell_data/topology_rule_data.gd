# topology_rule_data.gd
# 拓扑规则数据 - 定义一条"导能沟槽"，包含触发器和效果列表
class_name TopologyRuleData
extends Resource

@export var rule_name: String = "默认规则"
@export var trigger: TriggerData = null           # 触发条件
@export var actions: Array[ActionData] = []       # 触发后执行的效果列表
@export var enabled: bool = true                  # 是否启用

## 深拷贝
func clone_deep() -> TopologyRuleData:
	var copy = TopologyRuleData.new()
	copy.rule_name = rule_name
	copy.enabled = enabled
	
	# 深拷贝触发器
	if trigger != null:
		copy.trigger = trigger.clone_deep()
	
	# 深拷贝动作列表
	var actions_copy: Array[ActionData] = []
	for action in actions:
		if action != null:
			actions_copy.append(action.clone_deep())
	copy.actions = actions_copy
	
	return copy

## 转换为字典
func to_dict() -> Dictionary:
	var actions_array = []
	for action in actions:
		if action != null:
			actions_array.append(action.to_dict())
	
	return {
		"rule_name": rule_name,
		"enabled": enabled,
		"trigger": trigger.to_dict() if trigger != null else null,
		"actions": actions_array
	}

## 从字典加载
static func from_dict(data: Dictionary) -> TopologyRuleData:
	var rule = TopologyRuleData.new()
	rule.rule_name = data.get("rule_name", "默认规则")
	rule.enabled = data.get("enabled", true)
	
	# 加载触发器
	var trigger_data = data.get("trigger", null)
	if trigger_data != null:
		rule.trigger = TriggerData.from_dict(trigger_data)
	
	# 加载动作列表
	var actions_data = data.get("actions", [])
	var loaded_actions: Array[ActionData] = []
	for action_data in actions_data:
		loaded_actions.append(ActionData.from_dict(action_data))
	rule.actions = loaded_actions
	
	return rule

## 获取规则描述
func get_description() -> String:
	var trigger_name = trigger.get_type_name() if trigger != null else "无触发器"
	var action_names = []
	for action in actions:
		if action != null:
			action_names.append(action.get_type_name())
	
	return "%s: %s -> [%s]" % [rule_name, trigger_name, ", ".join(action_names)]
