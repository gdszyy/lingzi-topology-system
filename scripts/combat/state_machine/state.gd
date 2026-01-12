class_name State extends Node

var state_machine: StateMachine = null

var owner_node: Node = null

func initialize(_owner: Node) -> void:
	owner_node = _owner

func enter(_params: Dictionary = {}) -> void:
	pass

func exit() -> void:
	pass

func physics_update(_delta: float) -> void:
	pass

func frame_update(_delta: float) -> void:
	pass

func handle_input(_event: InputEvent) -> void:
	pass

func transition_to(state_name: String, params: Dictionary = {}) -> void:
	state_machine.change_state(state_name, params)
