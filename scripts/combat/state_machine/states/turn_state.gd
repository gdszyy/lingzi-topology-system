# turn_state.gd
# 转身状态 - 攻击或施法前的回正状态
extends State
class_name TurnState

## 玩家控制器引用
var player: PlayerController

## 下一个状态
var next_state: String = "Idle"

## 传递给下一个状态的参数
var next_params: Dictionary = {}

## 最大转身时间（防止卡住）
var max_turn_time: float = 1.0
var turn_timer: float = 0.0

func initialize(_owner: Node) -> void:
	super.initialize(_owner)
	player = _owner as PlayerController

func enter(params: Dictionary = {}) -> void:
	player.can_move = false  # 转身时不能移动
	player.can_rotate = true  # 但可以旋转
	
	next_state = params.get("next_state", "Idle")
	next_params = params.duplicate()
	next_params.erase("next_state")
	
	turn_timer = 0.0

func exit() -> void:
	turn_timer = 0.0

func physics_update(delta: float) -> void:
	turn_timer += delta
	
	# 超时保护
	if turn_timer >= max_turn_time:
		transition_to("Idle")
		return
	
	# 检查是否完成转身
	var is_attack = next_state == "AttackWindup"
	var angle_valid = false
	
	if is_attack:
		angle_valid = player.can_attack_at_angle()
	else:
		angle_valid = player.can_cast_at_angle()
	
	if angle_valid:
		transition_to(next_state, next_params)
