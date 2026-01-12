extends State
class_name MonkCultivateState

## 修士修炼状态
## 当能量上限受损且环境相对安全时，进入此状态恢复能量上限

var monk: MonkAIController
var cultivate_timer: float = 0.0

func initialize(_owner: Node) -> void:
	super.initialize(_owner)
	monk = _owner as MonkAIController

func enter(_params: Dictionary = {}) -> void:
	monk.stop_movement()
	monk.is_cultivating = true
	cultivate_timer = 0.0
	print("[修士AI] %s 开始修炼恢复..." % monk.name)

func exit() -> void:
	monk.is_cultivating = false

func physics_update(delta: float) -> void:
	# 检查是否受到威胁
	if monk.current_target != null and monk.global_position.distance_to(monk.current_target.global_position) < 400:
		transition_to("MonkChase") # 敌人靠近，停止修炼
		return
	
	# 执行修炼逻辑
	if monk.energy_system != null:
		var recovered = monk.energy_system.cultivate(delta, 1.5) # 高强度修炼
		
		# 如果恢复满了，或者能量耗尽，停止修炼
		if monk.energy_system.current_energy_cap >= monk.energy_system.max_energy_cap:
			_finish_cultivation()
		elif monk.energy_system.current_energy < 5.0:
			_finish_cultivation()

func _finish_cultivation() -> void:
	if monk.current_target != null:
		transition_to("MonkChase")
	else:
		transition_to("MonkIdle")
