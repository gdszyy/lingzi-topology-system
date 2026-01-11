# spawn_explosion_action_data.gd
# 生成爆炸动作数据 - 在指定位置创建爆炸效果
class_name SpawnExplosionActionData
extends ActionData

@export var explosion_damage: float = 50.0           # 爆炸伤害
@export var explosion_radius: float = 100.0          # 爆炸半径
@export var damage_falloff: float = 0.5              # 边缘伤害衰减 (0-1)
@export var explosion_damage_type: int = 0           # 伤害类型

func _init():
	action_type = ActionType.SPAWN_ENTITY

func get_type_name() -> String:
	return "生成爆炸"

func clone_deep() -> ActionData:
	var copy = SpawnExplosionActionData.new()
	copy.action_type = action_type
	copy.explosion_damage = explosion_damage
	copy.explosion_radius = explosion_radius
	copy.damage_falloff = damage_falloff
	copy.explosion_damage_type = explosion_damage_type
	return copy

func to_dict() -> Dictionary:
	var base = super.to_dict()
	base["explosion_damage"] = explosion_damage
	base["explosion_radius"] = explosion_radius
	base["damage_falloff"] = damage_falloff
	base["explosion_damage_type"] = explosion_damage_type
	return base

static func from_dict(data: Dictionary) -> SpawnExplosionActionData:
	var action = SpawnExplosionActionData.new()
	action.explosion_damage = data.get("explosion_damage", 50.0)
	action.explosion_radius = data.get("explosion_radius", 100.0)
	action.damage_falloff = data.get("damage_falloff", 0.5)
	action.explosion_damage_type = data.get("explosion_damage_type", 0)
	return action
