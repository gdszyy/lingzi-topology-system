# attack_windup_state.gd
# 攻击前摇状态 - 攻击动作的准备阶段
extends State
class_name AttackWindupState

## 玩家控制器引用
var player: PlayerController

## 当前攻击数据
var current_attack: AttackData = null

## 输入类型
var input_type: int = 0  # 0=左键, 1=右键, 2=组合

## 连击索引
var combo_index: int = 0

## 前摇计时器
var windup_timer: float = 0.0

## 是否从飞行状态进入
var from_fly: bool = false

func initialize(_owner: Node) -> void:
	super.initialize(_owner)
	player = _owner as PlayerController

func enter(params: Dictionary = {}) -> void:
	player.can_move = false  # 前摇时不能移动
	player.can_rotate = false  # 前摇时不能旋转
	player.is_attacking = true
	
	# 获取输入信息
	var input = params.get("input", null)
	if input != null:
		match input.type:
			InputBuffer.InputType.ATTACK_PRIMARY:
				input_type = 0
			InputBuffer.InputType.ATTACK_SECONDARY:
				input_type = 1
			InputBuffer.InputType.ATTACK_COMBO:
				input_type = 2
	
	# 获取连击索引
	combo_index = params.get("combo_index", 0)
	from_fly = params.get("from_fly", false)
	
	# 获取攻击数据
	current_attack = _get_attack_data()
	
	if current_attack == null:
		# 没有攻击数据，返回待机
		transition_to("Idle")
		return
	
	windup_timer = 0.0
	
	# 播放前摇动画
	_play_windup_animation()
	
	# 发送攻击开始信号
	player.attack_started.emit(current_attack)

func exit() -> void:
	windup_timer = 0.0
	current_attack = null

func physics_update(delta: float) -> void:
	windup_timer += delta
	
	# 检查前摇是否完成
	if current_attack != null and windup_timer >= current_attack.windup_time:
		transition_to("AttackActive", {
			"attack": current_attack,
			"input_type": input_type,
			"combo_index": combo_index,
			"from_fly": from_fly
		})

## 获取攻击数据
func _get_attack_data() -> AttackData:
	if player.current_weapon == null:
		return null
	
	var attacks = player.current_weapon.get_attacks_for_input(input_type)
	if attacks.size() == 0:
		return null
	
	# 根据连击索引获取攻击
	var index = combo_index % attacks.size()
	return attacks[index]

## 播放前摇动画
func _play_windup_animation() -> void:
	if current_attack == null:
		return
	
	# TODO: 播放实际动画
	# player.animation_player.play(current_attack.animation_name + "_windup")
