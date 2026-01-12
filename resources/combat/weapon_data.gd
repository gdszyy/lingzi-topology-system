class_name WeaponData extends Resource

enum WeaponType {
	UNARMED,
	SWORD,
	GREATSWORD,
	DUAL_BLADE,
	SPEAR,
	DAGGER,
	STAFF
}

enum GripType {
	ONE_HANDED,
	TWO_HANDED,
	DUAL_WIELD
}

@export_group("Basic Info")
@export var weapon_name: String = "未命名武器"
@export var weapon_type: WeaponType = WeaponType.UNARMED
@export var grip_type: GripType = GripType.ONE_HANDED
@export var description: String = ""

@export_group("Visuals")
@export var weapon_texture: Texture2D
@export var weapon_offset: Vector2 = Vector2.ZERO
@export var weapon_scale: Vector2 = Vector2.ONE
@export var grip_point_main: Vector2 = Vector2.ZERO
@export var grip_point_off: Vector2 = Vector2.ZERO

@export_group("Physics")
@export var weight: float = 1.0
@export_range(0.0, 1.0) var inertia_factor: float = 0.5
@export var attack_impulse: float = 100.0
@export var swing_arc: float = 90.0

@export_group("Combat Stats")
@export var base_damage: float = 10.0
@export var attack_range: float = 50.0
@export var knockback_force: float = 50.0

@export_group("Attack Actions")
@export var primary_attacks: Array[AttackData] = []
@export var secondary_attacks: Array[AttackData] = []
@export var combo_attacks: Array[AttackData] = []

@export_group("Engraving")
@export var engraving_slots: Array[EngravingSlot] = []
@export var max_engraving_capacity: float = 100.0

func get_turn_speed_modifier() -> float:
	return 1.0 / (1.0 + weight * 0.1)

func get_move_speed_modifier() -> float:
	return 1.0 / (1.0 + weight * 0.05)

func get_acceleration_modifier() -> float:
	return 1.0 / (1.0 + weight * 0.08)

func get_attack_impulse() -> float:
	return attack_impulse * (1.0 + weight * 0.2)

func is_two_handed() -> bool:
	return grip_type == GripType.TWO_HANDED

func is_dual_wield() -> bool:
	return grip_type == GripType.DUAL_WIELD

func get_attacks_for_input(input_type: int) -> Array[AttackData]:
	match input_type:
		0:
			return primary_attacks
		1:
			return secondary_attacks
		2:
			return combo_attacks
		_:
			return primary_attacks

func initialize_engraving_slots(slot_count: int = 2) -> void:
	engraving_slots.clear()

	var capacity = max_engraving_capacity
	match weapon_type:
		WeaponType.UNARMED:
			slot_count = 0
			capacity = 0
		WeaponType.DAGGER:
			slot_count = 1
			capacity = 50.0
		WeaponType.SWORD, WeaponType.DUAL_BLADE:
			slot_count = 2
			capacity = 80.0
		WeaponType.GREATSWORD, WeaponType.SPEAR:
			slot_count = 3
			capacity = 120.0
		WeaponType.STAFF:
			slot_count = 4
			capacity = 150.0

	for i in range(slot_count):
		var slot = EngravingSlot.new()
		slot.initialize(
			"%s_slot_%d" % [weapon_name.to_lower().replace(" ", "_"), i],
			"%s刻录槽%d" % [weapon_name, i + 1],
			capacity / slot_count
		)
		slot.allowed_triggers = [
			TriggerData.TriggerType.ON_WEAPON_HIT,
			TriggerData.TriggerType.ON_ATTACK_START,
			TriggerData.TriggerType.ON_ATTACK_ACTIVE,
			TriggerData.TriggerType.ON_ATTACK_END,
			TriggerData.TriggerType.ON_COMBO_HIT,
			TriggerData.TriggerType.ON_CRITICAL_HIT,
			TriggerData.TriggerType.ON_DEAL_DAMAGE,
			TriggerData.TriggerType.ON_KILL_ENEMY
		]
		engraving_slots.append(slot)

func get_engraved_spells() -> Array[SpellCoreData]:
	var spells: Array[SpellCoreData] = []
	for slot in engraving_slots:
		if slot.engraved_spell != null:
			spells.append(slot.engraved_spell)
	return spells

func get_triggerable_rules(trigger_type: int) -> Array[TopologyRuleData]:
	var rules: Array[TopologyRuleData] = []
	for slot in engraving_slots:
		var slot_rules = slot.trigger(trigger_type)
		rules.append_array(slot_rules)
	return rules

func update_engraving_cooldowns(delta: float) -> void:
	for slot in engraving_slots:
		slot.update_cooldown(delta)

func engrave_spell_to_slot(slot_index: int, spell: SpellCoreData) -> bool:
	if slot_index < 0 or slot_index >= engraving_slots.size():
		return false
	return engraving_slots[slot_index].engrave_spell(spell)

func remove_spell_from_slot(slot_index: int) -> SpellCoreData:
	if slot_index < 0 or slot_index >= engraving_slots.size():
		return null
	return engraving_slots[slot_index].remove_spell()

func get_engraving_slot_count() -> int:
	return engraving_slots.size()

func get_used_engraving_capacity() -> float:
	var used = 0.0
	for slot in engraving_slots:
		if slot.engraved_spell != null:
			used += slot.engraved_spell.calculate_total_instability()
	return used

static func create_unarmed() -> WeaponData:
	var weapon = WeaponData.new()
	weapon.weapon_name = "徒手"
	weapon.weapon_type = WeaponType.UNARMED
	weapon.grip_type = GripType.ONE_HANDED
	weapon.weight = 0.0
	weapon.base_damage = 5.0
	weapon.attack_range = 30.0
	weapon.max_engraving_capacity = 0.0

	var punch = AttackData.new()
	punch.attack_name = "拳击"
	punch.damage_multiplier = 1.0
	punch.windup_time = 0.1
	punch.active_time = 0.1
	punch.recovery_time = 0.2
	punch.can_combo = true
	weapon.primary_attacks.append(punch)

	return weapon
