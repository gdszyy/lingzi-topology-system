# state_machine.gd
# 状态机管理器 - 管理角色的所有状态
class_name StateMachine extends Node

## 信号
signal state_changed(old_state: State, new_state: State)

## 当前状态
var current_state: State = null

## 状态字典
var states: Dictionary = {}

## 状态机所有者（通常是Player）
var owner_node: Node = null

## 初始化状态机
func initialize(_owner: Node) -> void:
	owner_node = _owner
	
	# 收集所有子状态节点
	for child in get_children():
		if child is State:
			states[child.name] = child
			child.state_machine = self
			child.initialize(owner_node)
	
	# 进入初始状态
	if states.has("Idle"):
		change_state("Idle")
	elif states.size() > 0:
		change_state(states.keys()[0])

## 切换状态
func change_state(new_state_name: String, params: Dictionary = {}) -> void:
	if not states.has(new_state_name):
		push_error("State not found: " + new_state_name)
		return
	
	var new_state = states[new_state_name]
	
	# 退出当前状态
	if current_state != null:
		current_state.exit()
	
	var old_state = current_state
	current_state = new_state
	
	# 进入新状态
	current_state.enter(params)
	
	state_changed.emit(old_state, new_state)

## 物理帧更新
func physics_update(delta: float) -> void:
	if current_state != null:
		current_state.physics_update(delta)

## 帧更新
func frame_update(delta: float) -> void:
	if current_state != null:
		current_state.frame_update(delta)

## 处理输入
func handle_input(event: InputEvent) -> void:
	if current_state != null:
		current_state.handle_input(event)

## 获取当前状态名称
func get_current_state_name() -> String:
	if current_state != null:
		return current_state.name
	return ""

## 检查是否处于指定状态
func is_in_state(state_name: String) -> bool:
	return current_state != null and current_state.name == state_name

## 检查是否处于任一指定状态
func is_in_any_state(state_names: Array[String]) -> bool:
	if current_state == null:
		return false
	return current_state.name in state_names
