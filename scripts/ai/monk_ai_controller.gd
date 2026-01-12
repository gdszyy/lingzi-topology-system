class_name MonkAIController extends CharacterBody2D

## 修士AI控制器
## 具备与玩家对等的战斗能力，支持肢体刻印、能量系统和团队协作

# 信号
signal monk_died(monk: MonkAIController)
signal damage_taken(amount: float, source: Node2D)
signal state_changed(old_state: String, new_state: String)
signal target_acquired(target: Node2D)
signal target_lost(target: Node2D)

# 节点引用
@onready var state_machine: StateMachine = $StateMachine
@onready var perception: Node2D = $Perception # 假设有一个感知组件
@onready var visuals: Node2D = $Visuals
@onready var hitbox: Area2D = $Hitbox

# 组件
var energy_system: EnergySystemData
var engraving_manager: EngravingManager

# 配置
@export var behavior_profile: MonkBehaviorProfile
@export var team_id: int = 0

# 状态变量
var current_target: Node2D = null
var facing_direction: Vector2 = Vector2.RIGHT
var movement_penalty: float = 1.0
var is_attacking: bool = false
var is_casting: bool = false
var is_cultivating: bool = false

# 团队引用
var team_manager: Node = null # 将在运行时由TeamManager设置

func _ready() -> void:
	# 初始化行为配置
	if behavior_profile == null:
		behavior_profile = MonkBehaviorProfile.create_default_monk()
	
	# 初始化能量系统 (使用玩家级别的默认配置)
	energy_system = EnergySystemData.create_default()
	energy_system.depleted.connect(_on_energy_depleted)
	
	# 初始化刻印管理器
	_setup_engraving_manager()
	
	# 初始化状态机
	if state_machine != null:
		state_machine.initialize(self)
		state_machine.state_changed.connect(_on_state_changed)
	
	# 添加到组
	add_to_group("monks")
	add_to_group("team_" + str(team_id))
	
	# 初始刻印法术
	_apply_initial_engravings()

func _physics_process(delta: float) -> void:
	if state_machine != null:
		state_machine.physics_update(delta)
	
	# 更新能量系统 (被动吸收)
	if energy_system != null:
		energy_system.absorb_from_environment(delta)
	
	# 应用移动
	move_and_slide()
	
	# 更新视觉朝向
	_update_visuals()

func _setup_engraving_manager() -> void:
	engraving_manager = EngravingManager.new()
	engraving_manager.name = "EngravingManager"
	add_child(engraving_manager)
	
	# 模拟玩家控制器的接口，以便复用EngravingManager
	# 注意：EngravingManager内部需要引用player，这里我们传递self
	# 我们需要确保MonkAIController具备EngravingManager所需的方法
	engraving_manager.initialize(self as Node)

func _apply_initial_engravings() -> void:
	if behavior_profile.spell_loadout.is_empty():
		return
	
	# 简单的刻印策略：将法术分配到躯干和手部
	var parts = [
		BodyPartData.PartType.TORSO,
		BodyPartData.PartType.RIGHT_HAND,
		BodyPartData.PartType.LEFT_HAND
	]
	
	for i in range(min(behavior_profile.spell_loadout.size(), parts.size())):
		engraving_manager.engrave_to_body_part(parts[i], 0, behavior_profile.spell_loadout[i])

func _update_visuals() -> void:
	if velocity.length_squared() > 10:
		facing_direction = velocity.normalized()
	elif current_target != null:
		facing_direction = (current_target.global_position - global_position).normalized()
	
	if visuals != null:
		visuals.rotation = facing_direction.angle()

# ==================== 战斗接口 (复用玩家逻辑) ====================

func take_damage(damage: float, source: Node2D = null, target_part_type: int = BodyPartData.PartType.TORSO) -> void:
	if engraving_manager != null:
		var core_damage = engraving_manager.damage_body_part(target_part_type, damage)
		if energy_system != null and core_damage > 0:
			energy_system.take_damage(core_damage)
	
	damage_taken.emit(damage, source)
	
	# 如果受到伤害，且没有目标，则将来源设为目标
	if current_target == null and source != null:
		current_target = source

func take_damage_random_part(damage: float, source: Node2D = null) -> void:
	var functional_parts = engraving_manager.get_functional_body_parts()
	if functional_parts.is_empty():
		if energy_system != null:
			energy_system.take_damage(damage)
		return
	
	var target_part = functional_parts[randi() % functional_parts.size()]
	take_damage(damage, source, target_part.part_type)

func get_health_percent() -> float:
	return energy_system.get_cap_percent() if energy_system else 0.0

func _on_energy_depleted() -> void:
	monk_died.emit(self)
	queue_free()

func _on_state_changed(old_state: State, new_state: State) -> void:
	state_changed.emit(old_state.name if old_state else "", new_state.name if new_state else "")

# ==================== 移动与行为接口 ====================

func move_to(target_pos: Vector2, speed_mult: float = 1.0) -> void:
	var dir = (target_pos - global_position).normalized()
	velocity = dir * behavior_profile.move_speed * speed_mult * movement_penalty

func stop_movement() -> void:
	velocity = Vector2.ZERO

func is_enemy(node: Node2D) -> bool:
	if node.is_in_group("team_" + str(team_id)):
		return false
	return node.is_in_group("monks") or node.is_in_group("players") or node.is_in_group("enemies")

# ==================== 刻印管理器所需的模拟接口 ====================
# 这些接口是为了让现有的 EngravingManager 能够正常工作

var current_weapon: WeaponData = null # 修士也可以装备武器

func get_energy_system() -> EnergySystemData:
	return energy_system

func get_body_parts() -> Array[BodyPartData]:
	return engraving_manager.get_body_parts() if engraving_manager else []
