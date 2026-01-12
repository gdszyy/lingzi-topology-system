class_name RuntimeSystemsManager
extends Node

var status_effect_manager: StatusEffectManager
var shield_system: ShieldSystem
var reflect_system: ReflectSystem
var displacement_system: DisplacementSystem
var chain_system: ChainSystem
var summon_system: SummonSystem

signal damage_dealt(target: Node, damage: float, source: Node)
signal effect_applied(target: Node, effect_type: String)

func _ready():
	_initialize_systems()
	_connect_signals()
	add_to_group("runtime_systems_manager")

func _initialize_systems() -> void:
	status_effect_manager = StatusEffectManager.new()
	status_effect_manager.name = "StatusEffectManager"
	add_child(status_effect_manager)
	status_effect_manager.add_to_group("status_effect_manager")

	shield_system = ShieldSystem.new()
	shield_system.name = "ShieldSystem"
	add_child(shield_system)

	reflect_system = ReflectSystem.new()
	reflect_system.name = "ReflectSystem"
	add_child(reflect_system)

	displacement_system = DisplacementSystem.new()
	displacement_system.name = "DisplacementSystem"
	add_child(displacement_system)

	chain_system = ChainSystem.new()
	chain_system.name = "ChainSystem"
	add_child(chain_system)

	summon_system = SummonSystem.new()
	summon_system.name = "SummonSystem"
	add_child(summon_system)

func _connect_signals() -> void:
	status_effect_manager.status_applied.connect(_on_status_applied)
	status_effect_manager.status_ticked.connect(_on_status_ticked)
	status_effect_manager.phase_counter_triggered.connect(_on_phase_counter)

	shield_system.shield_broken.connect(_on_shield_broken)
	shield_system.shield_reflected.connect(_on_shield_reflected)

	chain_system.chain_jumped.connect(_on_chain_jumped)
	chain_system.chain_ended.connect(_on_chain_ended)

	summon_system.summon_attacked.connect(_on_summon_attacked)
	summon_system.summon_died.connect(_on_summon_died)

func process_damage(target: Node, damage: float, source: Node = null) -> float:
	var final_damage = damage

	if source != null and reflect_system.has_reflect(target):
		var reflected = reflect_system.try_reflect_damage(target, source, damage)
		if reflected > 0:
			final_damage *= 0.5

	if shield_system.has_shield(target):
		final_damage = shield_system.damage_shield(target, final_damage)

	if final_damage > 0 and target.has_method("take_damage"):
		target.take_damage(final_damage)
		damage_dealt.emit(target, final_damage, source)

	return final_damage

func apply_status(target: Node, status_data: ApplyStatusActionData) -> void:
	status_effect_manager.apply_status(target, status_data)

func create_shield(target: Node, shield_data: ShieldActionData) -> void:
	shield_system.create_shield(target, shield_data)

func activate_reflect(target: Node, reflect_data: ReflectActionData) -> void:
	reflect_system.activate_reflect(target, reflect_data)

func apply_displacement(target: Node, displacement_data: DisplacementActionData, source_position: Vector2) -> void:
	displacement_system.apply_displacement(target, displacement_data, source_position)

func start_chain(first_target: Node, chain_data: ChainActionData, source_position: Vector2) -> void:
	chain_system.start_chain(first_target, chain_data, source_position)

func create_summon(summon_data: SummonActionData, spawn_position: Vector2, owner: Node) -> Array[Node2D]:
	return summon_system.create_summon(summon_data, spawn_position, owner)

func try_reflect_projectile(target: Node, projectile: Node) -> bool:
	if shield_system.try_reflect_projectile(target, projectile):
		return true

	return reflect_system.try_reflect_projectile(target, projectile)

func _on_status_applied(target: Node, status_data: ApplyStatusActionData) -> void:
	effect_applied.emit(target, "status:" + status_data.get_status_name())

func _on_status_ticked(target: Node, status_type: ApplyStatusActionData.StatusType, damage: float) -> void:
	damage_dealt.emit(target, damage, null)

func _on_phase_counter(target: Node, attacker_phase: ApplyStatusActionData.SpiritonPhase, target_phase: ApplyStatusActionData.SpiritonPhase) -> void:
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

func has_shield(target: Node) -> bool:
	return shield_system.has_shield(target)

func get_shield_amount(target: Node) -> float:
	return shield_system.get_shield_amount(target)

func has_reflect(target: Node) -> bool:
	return reflect_system.has_reflect(target)

func is_being_displaced(target: Node) -> bool:
	return displacement_system.is_being_displaced(target)

func has_status(target: Node, status_type: ApplyStatusActionData.StatusType) -> bool:
	return status_effect_manager.has_status(target, status_type)

func get_status_stacks(target: Node, status_type: ApplyStatusActionData.StatusType) -> int:
	return status_effect_manager.get_status_stacks(target, status_type)

func get_active_summon_count() -> int:
	return summon_system.get_active_summon_count()

func cleanse_all_debuffs(target: Node) -> int:
	return status_effect_manager.cleanse_all_debuffs(target)

func remove_shield(target: Node) -> void:
	shield_system.remove_shield(target)

func remove_reflect(target: Node) -> void:
	reflect_system.remove_reflect(target)

func interrupt_displacement(target: Node) -> void:
	displacement_system.interrupt_displacement(target)

func remove_summons_by_owner(owner: Node) -> void:
	summon_system.remove_summons_by_owner(owner)

func on_target_death(target: Node) -> void:
	status_effect_manager.on_target_death(target)
	shield_system.remove_shield(target)
	reflect_system.remove_reflect(target)
	displacement_system.interrupt_displacement(target)
