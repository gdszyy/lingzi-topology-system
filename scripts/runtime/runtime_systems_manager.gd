# runtime_systems_manager.gd
# 运行时系统管理器 - 整合所有运行时系统的统一入口
# 
# 负责管理和协调：
# - 状态效果系统 (StatusEffectManager)
# - 护盾系统 (ShieldSystem)
# - 反弹系统 (ReflectSystem)
# - 位移系统 (DisplacementSystem)
# - 链式系统 (ChainSystem)
# - 召唤系统 (SummonSystem)
class_name RuntimeSystemsManager
extends Node

## 子系统引用
var status_effect_manager: StatusEffectManager
var shield_system: ShieldSystem
var reflect_system: ReflectSystem
var displacement_system: DisplacementSystem
var chain_system: ChainSystem
var summon_system: SummonSystem

## 信号转发
signal damage_dealt(target: Node, damage: float, source: Node)
signal effect_applied(target: Node, effect_type: String)

func _ready():
	_initialize_systems()
	_connect_signals()
	add_to_group("runtime_systems_manager")

## 初始化所有子系统
func _initialize_systems() -> void:
	# 状态效果系统
	status_effect_manager = StatusEffectManager.new()
	status_effect_manager.name = "StatusEffectManager"
	add_child(status_effect_manager)
	status_effect_manager.add_to_group("status_effect_manager")
	
	# 护盾系统
	shield_system = ShieldSystem.new()
	shield_system.name = "ShieldSystem"
	add_child(shield_system)
	
	# 反弹系统
	reflect_system = ReflectSystem.new()
	reflect_system.name = "ReflectSystem"
	add_child(reflect_system)
	
	# 位移系统
	displacement_system = DisplacementSystem.new()
	displacement_system.name = "DisplacementSystem"
	add_child(displacement_system)
	
	# 链式系统
	chain_system = ChainSystem.new()
	chain_system.name = "ChainSystem"
	add_child(chain_system)
	
	# 召唤系统
	summon_system = SummonSystem.new()
	summon_system.name = "SummonSystem"
	add_child(summon_system)

## 连接子系统信号
func _connect_signals() -> void:
	# 状态效果信号
	status_effect_manager.status_applied.connect(_on_status_applied)
	status_effect_manager.status_ticked.connect(_on_status_ticked)
	status_effect_manager.phase_counter_triggered.connect(_on_phase_counter)
	
	# 护盾信号
	shield_system.shield_broken.connect(_on_shield_broken)
	shield_system.shield_reflected.connect(_on_shield_reflected)
	
	# 链式信号
	chain_system.chain_jumped.connect(_on_chain_jumped)
	chain_system.chain_ended.connect(_on_chain_ended)
	
	# 召唤信号
	summon_system.summon_attacked.connect(_on_summon_attacked)
	summon_system.summon_died.connect(_on_summon_died)

## ========== 统一接口 ==========

## 处理伤害（考虑护盾和反弹）
func process_damage(target: Node, damage: float, source: Node = null) -> float:
	var final_damage = damage
	
	# 1. 检查反弹
	if source != null and reflect_system.has_reflect(target):
		var reflected = reflect_system.try_reflect_damage(target, source, damage)
		if reflected > 0:
			final_damage *= 0.5  # 反弹时减少受到的伤害
	
	# 2. 检查护盾
	if shield_system.has_shield(target):
		final_damage = shield_system.damage_shield(target, final_damage)
	
	# 3. 应用最终伤害
	if final_damage > 0 and target.has_method("take_damage"):
		target.take_damage(final_damage)
		damage_dealt.emit(target, final_damage, source)
	
	return final_damage

## 应用状态效果
func apply_status(target: Node, status_data: ApplyStatusActionData) -> void:
	status_effect_manager.apply_status(target, status_data)

## 创建护盾
func create_shield(target: Node, shield_data: ShieldActionData) -> void:
	shield_system.create_shield(target, shield_data)

## 激活反弹
func activate_reflect(target: Node, reflect_data: ReflectActionData) -> void:
	reflect_system.activate_reflect(target, reflect_data)

## 应用位移
func apply_displacement(target: Node, displacement_data: DisplacementActionData, source_position: Vector2) -> void:
	displacement_system.apply_displacement(target, displacement_data, source_position)

## 启动链式
func start_chain(first_target: Node, chain_data: ChainActionData, source_position: Vector2) -> void:
	chain_system.start_chain(first_target, chain_data, source_position)

## 创建召唤物
func create_summon(summon_data: SummonActionData, spawn_position: Vector2, owner: Node) -> Array[Node2D]:
	return summon_system.create_summon(summon_data, spawn_position, owner)

## 尝试反弹投射物
func try_reflect_projectile(target: Node, projectile: Node) -> bool:
	# 先检查护盾反弹
	if shield_system.try_reflect_projectile(target, projectile):
		return true
	
	# 再检查反弹效果
	return reflect_system.try_reflect_projectile(target, projectile)

## ========== 信号处理 ==========

func _on_status_applied(target: Node, status_data: ApplyStatusActionData) -> void:
	effect_applied.emit(target, "status:" + status_data.get_status_name())

func _on_status_ticked(target: Node, status_type: ApplyStatusActionData.StatusType, damage: float) -> void:
	damage_dealt.emit(target, damage, null)

func _on_phase_counter(target: Node, attacker_phase: ApplyStatusActionData.SpiritonPhase, target_phase: ApplyStatusActionData.SpiritonPhase) -> void:
	# 相态克制触发时可以添加视觉效果
	pass

func _on_shield_broken(target: Node, overkill_damage: float) -> void:
	effect_applied.emit(target, "shield_broken")

func _on_shield_reflected(target: Node, projectile: Node) -> void:
	effect_applied.emit(target, "projectile_reflected")

func _on_chain_jumped(from_target: Node, to_target: Node, jump_index: int, damage: float) -> void:
	damage_dealt.emit(to_target, damage, from_target)

func _on_chain_ended(final_target: Node, total_jumps: int, total_damage: float) -> void:
	pass

func _on_summon_attacked(summon: Node, target: Node, damage: float) -> void:
	damage_dealt.emit(target, damage, summon)

func _on_summon_died(summon: Node, death_position: Vector2) -> void:
	effect_applied.emit(summon, "summon_died")

## ========== 查询接口 ==========

## 检查目标是否有护盾
func has_shield(target: Node) -> bool:
	return shield_system.has_shield(target)

## 获取护盾剩余值
func get_shield_amount(target: Node) -> float:
	return shield_system.get_shield_amount(target)

## 检查目标是否有反弹效果
func has_reflect(target: Node) -> bool:
	return reflect_system.has_reflect(target)

## 检查目标是否正在位移中
func is_being_displaced(target: Node) -> bool:
	return displacement_system.is_being_displaced(target)

## 检查目标是否有指定状态
func has_status(target: Node, status_type: ApplyStatusActionData.StatusType) -> bool:
	return status_effect_manager.has_status(target, status_type)

## 获取状态层数
func get_status_stacks(target: Node, status_type: ApplyStatusActionData.StatusType) -> int:
	return status_effect_manager.get_status_stacks(target, status_type)

## 获取活跃召唤物数量
func get_active_summon_count() -> int:
	return summon_system.get_active_summon_count()

## ========== 清理接口 ==========

## 净化目标的所有负面状态
func cleanse_all_debuffs(target: Node) -> int:
	return status_effect_manager.cleanse_all_debuffs(target)

## 移除目标的护盾
func remove_shield(target: Node) -> void:
	shield_system.remove_shield(target)

## 移除目标的反弹效果
func remove_reflect(target: Node) -> void:
	reflect_system.remove_reflect(target)

## 中断目标的位移
func interrupt_displacement(target: Node) -> void:
	displacement_system.interrupt_displacement(target)

## 移除指定主人的所有召唤物
func remove_summons_by_owner(owner: Node) -> void:
	summon_system.remove_summons_by_owner(owner)

## 处理目标死亡
func on_target_death(target: Node) -> void:
	status_effect_manager.on_target_death(target)
	shield_system.remove_shield(target)
	reflect_system.remove_reflect(target)
	displacement_system.interrupt_displacement(target)
