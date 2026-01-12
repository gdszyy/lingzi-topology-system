class_name TopologyRuleData
extends Resource

@export var rule_name: String = "默认规则"
@export var trigger: TriggerData = null
@export var actions: Array[ActionData] = []
@export var enabled: bool = true

func clone_deep() -> TopologyRuleData:
	var copy = TopologyRuleData.new()
	copy.rule_name = rule_name
	copy.enabled = enabled

	if trigger != null:
		copy.trigger = trigger.clone_deep()

	var actions_copy: Array[ActionData] = []
	for action in actions:
		if action != null:
			actions_copy.append(action.clone_deep())
	copy.actions = actions_copy

	return copy

func to_dict() -> Dictionary:
	var actions_array = []
	for action in actions:
		if action != null:
			actions_array.append(action.to_dict())

	return {
		"rule_name": rule_name,
		"enabled": enabled,
		"trigger": trigger.to_dict() if trigger != null else {},
		"actions": actions_array
	}

static func from_dict(data: Dictionary) -> TopologyRuleData:
	var rule = TopologyRuleData.new()
	rule.rule_name = data.get("rule_name", "默认规则")
	rule.enabled = data.get("enabled", true)

	var trigger_data = data.get("trigger", null)
	if trigger_data != null:
		rule.trigger = TriggerData.from_dict(trigger_data)

	var actions_data = data.get("actions", [])
	var loaded_actions: Array[ActionData] = []
	for action_data in actions_data:
		loaded_actions.append(ActionData.from_dict(action_data))
	rule.actions = loaded_actions

	return rule

func get_description() -> String:
	var trigger_name = trigger.get_type_name() if trigger != null else "无触发器"
	var action_names = []
	for action in actions:
		if action != null:
			action_names.append(action.get_type_name())

	return "%s: %s -> [%s]" % [rule_name, trigger_name, ", ".join(action_names)]
