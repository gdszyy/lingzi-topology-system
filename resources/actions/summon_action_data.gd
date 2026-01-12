class_name SummonActionData
extends ActionData

enum SummonType {
	TURRET,
	MINION,
	ORBITER,
	DECOY,
	BARRIER,
	TOTEM
}

enum BehaviorMode {
	AGGRESSIVE,
	DEFENSIVE,
	PASSIVE,
	FOLLOW
}

@export var summon_type: SummonType = SummonType.TURRET
@export var behavior_mode: BehaviorMode = BehaviorMode.AGGRESSIVE
@export var summon_count: int = 1
@export var summon_duration: float = 10.0
@export var summon_health: float = 50.0
@export var summon_damage: float = 15.0
@export var summon_attack_interval: float = 1.0
@export var summon_attack_range: float = 200.0
@export var summon_move_speed: float = 100.0
@export var orbit_radius: float = 80.0
@export var orbit_speed: float = 2.0
@export var aggro_radius: float = 150.0
@export var totem_effect_radius: float = 120.0
@export var totem_effect_interval: float = 1.0
@export var inherit_spell: bool = false
@export var custom_spell_data: Resource = null

func _init():
	action_type = ActionType.SUMMON

func get_type_name() -> String:
	match summon_type:
		SummonType.TURRET:
			return "召唤炮塔"
		SummonType.MINION:
			return "召唤仆从"
		SummonType.ORBITER:
			return "召唤环绕体"
		SummonType.DECOY:
			return "召唤诱饵"
		SummonType.BARRIER:
			return "召唤屏障"
		SummonType.TOTEM:
			return "召唤图腾"
	return "召唤"

func clone_deep() -> ActionData:
	var copy = SummonActionData.new()
	copy.action_type = action_type
	copy.summon_type = summon_type
	copy.behavior_mode = behavior_mode
	copy.summon_count = summon_count
	copy.summon_duration = summon_duration
	copy.summon_health = summon_health
	copy.summon_damage = summon_damage
	copy.summon_attack_interval = summon_attack_interval
	copy.summon_attack_range = summon_attack_range
	copy.summon_move_speed = summon_move_speed
	copy.orbit_radius = orbit_radius
	copy.orbit_speed = orbit_speed
	copy.aggro_radius = aggro_radius
	copy.totem_effect_radius = totem_effect_radius
	copy.totem_effect_interval = totem_effect_interval
	copy.inherit_spell = inherit_spell
	if custom_spell_data != null and custom_spell_data.has_method("clone_deep"):
		copy.custom_spell_data = custom_spell_data.clone_deep()
	return copy

func to_dict() -> Dictionary:
	var base = super.to_dict()
	base["summon_type"] = summon_type
	base["behavior_mode"] = behavior_mode
	base["summon_count"] = summon_count
	base["summon_duration"] = summon_duration
	base["summon_health"] = summon_health
	base["summon_damage"] = summon_damage
	base["summon_attack_interval"] = summon_attack_interval
	base["summon_attack_range"] = summon_attack_range
	base["summon_move_speed"] = summon_move_speed
	base["orbit_radius"] = orbit_radius
	base["orbit_speed"] = orbit_speed
	base["aggro_radius"] = aggro_radius
	base["totem_effect_radius"] = totem_effect_radius
	base["totem_effect_interval"] = totem_effect_interval
	base["inherit_spell"] = inherit_spell
	if custom_spell_data != null and custom_spell_data.has_method("to_dict"):
		base["custom_spell_data"] = custom_spell_data.to_dict()
	return base

static func from_dict(data: Dictionary) -> SummonActionData:
	var action = SummonActionData.new()
	action.summon_type = data.get("summon_type", SummonType.TURRET)
	action.behavior_mode = data.get("behavior_mode", BehaviorMode.AGGRESSIVE)
	action.summon_count = data.get("summon_count", 1)
	action.summon_duration = data.get("summon_duration", 10.0)
	action.summon_health = data.get("summon_health", 50.0)
	action.summon_damage = data.get("summon_damage", 15.0)
	action.summon_attack_interval = data.get("summon_attack_interval", 1.0)
	action.summon_attack_range = data.get("summon_attack_range", 200.0)
	action.summon_move_speed = data.get("summon_move_speed", 100.0)
	action.orbit_radius = data.get("orbit_radius", 80.0)
	action.orbit_speed = data.get("orbit_speed", 2.0)
	action.aggro_radius = data.get("aggro_radius", 150.0)
	action.totem_effect_radius = data.get("totem_effect_radius", 120.0)
	action.totem_effect_interval = data.get("totem_effect_interval", 1.0)
	action.inherit_spell = data.get("inherit_spell", false)
	return action
