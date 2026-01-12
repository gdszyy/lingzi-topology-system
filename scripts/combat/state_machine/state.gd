# state.gd
# 状态基类 - 所有状态的父类
class_name State extends Node

## 状态机引用
var state_machine: StateMachine = null

## 所有者引用（通常是Player）
var owner_node: Node = null

## 初始化状态
func initialize(_owner: Node) -> void:
	owner_node = _owner

## 进入状态时调用
func enter(_params: Dictionary = {}) -> void:
	pass

## 退出状态时调用
func exit() -> void:
	pass

## 物理帧更新
func physics_update(_delta: float) -> void:
	pass

## 帧更新
func frame_update(_delta: float) -> void:
	pass

## 处理输入
func handle_input(_event: InputEvent) -> void:
	pass

## 切换到另一个状态
func transition_to(state_name: String, params: Dictionary = {}) -> void:
	state_machine.change_state(state_name, params)
