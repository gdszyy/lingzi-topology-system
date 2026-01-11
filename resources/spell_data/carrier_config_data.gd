# carrier_config_data.gd
# 载体配置数据 - 定义法术载体的物理属性
class_name CarrierConfigData
extends Resource

## 相态枚举 - 对应修仙世界观中的灵子聚合形态
enum Phase {
	SOLID,    # 固态 - 高动能，低热能
	LIQUID,   # 液态 - 中等属性，可流动
	PLASMA    # 等离子态 - 高热能，高不稳定性
}

## 伤害类型枚举
enum DamageType {
	KINETIC_IMPACT,   # 动能冲击 - 物理伤害
	ENTROPY_BURST,    # 熵能爆发 - 热能伤害
	VOID_EROSION,     # 虚空侵蚀 - 持续伤害
	CRYO_SHATTER      # 冰晶碎裂 - 冰冻伤害
}

@export var phase: Phase = Phase.SOLID
@export var mass: float = 1.0                    # 质量，影响动能伤害
@export var velocity: float = 500.0              # 初始速度
@export var instability_cost: float = 0.0        # 不稳定性成本
@export var lifetime: float = 5.0                # 存活时间（秒）
@export var size: float = 1.0                    # 碰撞体大小
@export var piercing: int = 0                    # 穿透次数
@export var homing_strength: float = 0.0         # 追踪强度 (0 = 不追踪)
@export var homing_range: float = 300.0          # 追踪范围
@export var homing_turn_rate: float = 5.0        # 追踪转向速率
@export var homing_delay: float = 0.0            # 追踪延迟（秒）

## 根据相态获取默认伤害类型
func get_default_damage_type() -> DamageType:
	match phase:
		Phase.SOLID:
			return DamageType.KINETIC_IMPACT
		Phase.LIQUID:
			return DamageType.VOID_EROSION
		Phase.PLASMA:
			return DamageType.ENTROPY_BURST
	return DamageType.KINETIC_IMPACT

## 计算基础动能伤害
func calculate_kinetic_damage() -> float:
	return 0.5 * mass * velocity * velocity * 0.001  # 简化的动能公式

## 深拷贝
func clone_deep() -> CarrierConfigData:
	var copy = CarrierConfigData.new()
	copy.phase = phase
	copy.mass = mass
	copy.velocity = velocity
	copy.instability_cost = instability_cost
	copy.lifetime = lifetime
	copy.size = size
	copy.piercing = piercing
	copy.homing_strength = homing_strength
	copy.homing_range = homing_range
	copy.homing_turn_rate = homing_turn_rate
	copy.homing_delay = homing_delay
	return copy

## 转换为字典（用于序列化）
func to_dict() -> Dictionary:
	return {
		"phase": phase,
		"mass": mass,
		"velocity": velocity,
		"instability_cost": instability_cost,
		"lifetime": lifetime,
		"size": size,
		"piercing": piercing,
		"homing_strength": homing_strength,
		"homing_range": homing_range,
		"homing_turn_rate": homing_turn_rate,
		"homing_delay": homing_delay
	}

## 从字典加载
static func from_dict(data: Dictionary) -> CarrierConfigData:
	var config = CarrierConfigData.new()
	config.phase = data.get("phase", Phase.SOLID)
	config.mass = data.get("mass", 1.0)
	config.velocity = data.get("velocity", 500.0)
	config.instability_cost = data.get("instability_cost", 0.0)
	config.lifetime = data.get("lifetime", 5.0)
	config.size = data.get("size", 1.0)
	config.piercing = data.get("piercing", 0)
	config.homing_strength = data.get("homing_strength", 0.0)
	config.homing_range = data.get("homing_range", 300.0)
	config.homing_turn_rate = data.get("homing_turn_rate", 5.0)
	config.homing_delay = data.get("homing_delay", 0.0)
	return config
