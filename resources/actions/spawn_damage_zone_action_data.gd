# spawn_damage_zone_action_data.gd
# 生成持续伤害区域动作数据 - 创建持续伤害区域
class_name SpawnDamageZoneActionData
extends ActionData

@export var zone_damage: float = 10.0                # 每次伤害
@export var zone_radius: float = 80.0                # 区域半径
@export var zone_duration: float = 5.0               # 持续时间
@export var tick_interval: float = 0.5               # 伤害间隔
@export var zone_damage_type: int = 0                # 伤害类型
@export var slow_amount: float = 0.0                 # 减速效果 (0-1)

func _init():
	action_type = ActionType.SPAWN_ENTITY

func get_type_name() -> String:
	return "生成伤害区域"

func clone_deep() -> ActionData:
	var copy = SpawnDamageZoneActionData.new()
	copy.action_type = action_type
	copy.zone_damage = zone_damage
	copy.zone_radius = zone_radius
	copy.zone_duration = zone_duration
	copy.tick_interval = tick_interval
	copy.zone_damage_type = zone_damage_type
	copy.slow_amount = slow_amount
	return copy

func to_dict() -> Dictionary:
	var base = super.to_dict()
	base["zone_damage"] = zone_damage
	base["zone_radius"] = zone_radius
	base["zone_duration"] = zone_duration
	base["tick_interval"] = tick_interval
	base["zone_damage_type"] = zone_damage_type
	base["slow_amount"] = slow_amount
	return base

static func from_dict(data: Dictionary) -> SpawnDamageZoneActionData:
	var action = SpawnDamageZoneActionData.new()
	action.zone_damage = data.get("zone_damage", 10.0)
	action.zone_radius = data.get("zone_radius", 80.0)
	action.zone_duration = data.get("zone_duration", 5.0)
	action.tick_interval = data.get("tick_interval", 0.5)
	action.zone_damage_type = data.get("zone_damage_type", 0)
	action.slow_amount = data.get("slow_amount", 0.0)
	return action
