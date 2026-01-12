class_name CarrierConfigData
extends Resource

enum Phase {
	SOLID,
	LIQUID,
	PLASMA
}

enum CarrierType {
	PROJECTILE,
	MINE,
	SLOW_ORB
}

enum DamageType {
	KINETIC_IMPACT,
	ENTROPY_BURST,
	VOID_EROSION,
	CRYO_SHATTER
}

@export var phase: Phase = Phase.SOLID
@export var carrier_type: CarrierType = CarrierType.PROJECTILE
@export var mass: float = 1.0
@export var velocity: float = 500.0
@export var instability_cost: float = 0.0
@export var lifetime: float = 5.0
@export var size: float = 1.0
@export var piercing: int = 0
@export var base_damage: float = 10.0
@export var homing_strength: float = 0.0
@export var homing_range: float = 300.0
@export var homing_turn_rate: float = 5.0
@export var homing_delay: float = 0.0

func get_default_damage_type() -> DamageType:
	match phase:
		Phase.SOLID:
			return DamageType.KINETIC_IMPACT
		Phase.LIQUID:
			return DamageType.VOID_EROSION
		Phase.PLASMA:
			return DamageType.ENTROPY_BURST
	return DamageType.KINETIC_IMPACT

func get_effective_velocity() -> float:
	match carrier_type:
		CarrierType.MINE:
			return 0.0
		CarrierType.SLOW_ORB:
			return minf(velocity, 150.0)
		_:
			return velocity

func get_effective_lifetime() -> float:
	match carrier_type:
		CarrierType.MINE:
			return lifetime * 2.0
		_:
			return lifetime

func calculate_kinetic_damage() -> float:
	var effective_vel = get_effective_velocity()
	return 0.5 * mass * effective_vel * effective_vel * 0.001

func clone_deep() -> CarrierConfigData:
	var copy = CarrierConfigData.new()
	copy.phase = phase
	copy.carrier_type = carrier_type
	copy.mass = mass
	copy.velocity = velocity
	copy.instability_cost = instability_cost
	copy.lifetime = lifetime
	copy.size = size
	copy.piercing = piercing
	copy.base_damage = base_damage
	copy.homing_strength = homing_strength
	copy.homing_range = homing_range
	copy.homing_turn_rate = homing_turn_rate
	copy.homing_delay = homing_delay
	return copy

func to_dict() -> Dictionary:
	return {
		"phase": phase,
		"carrier_type": carrier_type,
		"mass": mass,
		"velocity": velocity,
		"instability_cost": instability_cost,
		"lifetime": lifetime,
		"size": size,
		"piercing": piercing,
		"base_damage": base_damage,
		"homing_strength": homing_strength,
		"homing_range": homing_range,
		"homing_turn_rate": homing_turn_rate,
		"homing_delay": homing_delay
	}

static func from_dict(data: Dictionary) -> CarrierConfigData:
	var config = CarrierConfigData.new()
	config.phase = data.get("phase", Phase.SOLID)
	config.carrier_type = data.get("carrier_type", CarrierType.PROJECTILE)
	config.mass = data.get("mass", 1.0)
	config.velocity = data.get("velocity", 500.0)
	config.instability_cost = data.get("instability_cost", 0.0)
	config.lifetime = data.get("lifetime", 5.0)
	config.size = data.get("size", 1.0)
	config.piercing = data.get("piercing", 0)
	config.base_damage = maxf(data.get("base_damage", 10.0), 1.0)
	config.homing_strength = data.get("homing_strength", 0.0)
	config.homing_range = data.get("homing_range", 300.0)
	config.homing_turn_rate = data.get("homing_turn_rate", 5.0)
	config.homing_delay = data.get("homing_delay", 0.0)
	return config
