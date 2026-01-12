extends State
class_name AIIdleState

## AI空闲状态
## 敌人在没有目标时的默认状态
## 可以执行待机动画或简单的巡逻行为

var ai: EnemyAIController
var idle_timer: float = 0.0
var idle_duration: float = 2.0  # 空闲持续时间
var look_around_timer: float = 0.0
var look_around_interval: float = 3.0  # 环顾四周的间隔

func initialize(_owner: Node) -> void:
	super.initialize(_owner)
	ai = _owner as EnemyAIController

func enter(_params: Dictionary = {}) -> void:
	idle_timer = 0.0
	look_around_timer = 0.0
	idle_duration = randf_range(1.5, 3.0)
	
	# 停止移动
	ai.stop_movement()

func exit() -> void:
	idle_timer = 0.0

func physics_update(delta: float) -> void:
	idle_timer += delta
	look_around_timer += delta
	
	# 检查是否发现目标
	if ai.current_target != null:
		transition_to("AIChase")
		return
	
	# 环顾四周（简单的视觉效果）
	if look_around_timer >= look_around_interval:
		look_around_timer = 0.0
		_look_around()
	
	# 空闲一段时间后可以切换到巡逻
	if idle_timer >= idle_duration:
		# 如果有巡逻状态，可以切换
		if state_machine.states.has("AIPatrol"):
			transition_to("AIPatrol")
		else:
			# 重置空闲计时器
			idle_timer = 0.0
			idle_duration = randf_range(1.5, 3.0)

func frame_update(_delta: float) -> void:
	# 可以在这里更新待机动画
	pass

## 环顾四周
func _look_around() -> void:
	# 随机改变朝向
	var random_angle = randf_range(-PI / 4, PI / 4)
	ai.facing_direction = ai.facing_direction.rotated(random_angle)
