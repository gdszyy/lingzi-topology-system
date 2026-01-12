extends State
class_name MonkUseSpellState

var monk: MonkAIController
var cast_timer: float = 0.0

func initialize(_owner: Node) -> void:
	super.initialize(_owner)
	monk = _owner as MonkAIController

func enter(_params: Dictionary = {}) -> void:
	monk.stop_movement()
	monk.is_casting = true
	cast_timer = 0.0
	
	# 触发刻印管理器的法术
	if monk.engraving_manager != null:
		# 模拟触发 ON_TICK 或特定条件的触发器
		monk.engraving_manager.distribute_trigger(TriggerData.TriggerType.ON_TICK, {
			"is_attacking": true,
			"target": monk.current_target
		})

func exit() -> void:
	monk.is_casting = false

func physics_update(delta: float) -> void:
	cast_timer += delta
	if cast_timer > 1.0: # 假设施法持续1秒
		transition_to("MonkChase")
