class_name StateMachine extends Node

signal state_changed(old_state: State, new_state: State)

var current_state: State = null

var states: Dictionary = {}

var owner_node: Node = null

func initialize(_owner: Node) -> void:
	owner_node = _owner

	for child in get_children():
		if child is State:
			states[child.name] = child
			child.state_machine = self
			child.initialize(owner_node)

	if states.has("Idle"):
		change_state("Idle")
	elif states.size() > 0:
		change_state(states.keys()[0])

func change_state(new_state_name: String, params: Dictionary = {}) -> void:
	if not states.has(new_state_name):
		push_error("State not found: " + new_state_name)
		return

	var new_state = states[new_state_name]

	if current_state != null:
		current_state.exit()

	var old_state = current_state
	current_state = new_state

	current_state.enter(params)

	state_changed.emit(old_state, new_state)

func physics_update(delta: float) -> void:
	if current_state != null:
		current_state.physics_update(delta)

func frame_update(delta: float) -> void:
	if current_state != null:
		current_state.frame_update(delta)

func handle_input(event: InputEvent) -> void:
	if current_state != null:
		current_state.handle_input(event)

func get_current_state_name() -> String:
	if current_state != null:
		return current_state.name
	return ""

func is_in_state(state_name: String) -> bool:
	return current_state != null and current_state.name == state_name

func is_in_any_state(state_names: Array[String]) -> bool:
	if current_state == null:
		return false
	return current_state.name in state_names
