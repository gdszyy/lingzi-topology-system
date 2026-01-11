# displacement_action_data.gd
# 位移动作数据 - 对目标造成位移效果
class_name DisplacementActionData
extends ActionData

## 位移类型
enum DisplacementType {
	KNOCKBACK,       # 击退（远离施法者）
	PULL,            # 吸引（靠近施法者）
	TELEPORT,        # 传送（瞬间移动到指定位置）
	LAUNCH,          # 击飞（向上抛起）
	DASH             # 冲刺（向前快速移动）
}

## 位移方向参考
enum DirectionReference {
	FROM_CASTER,     # 相对于施法者
	FROM_PROJECTILE, # 相对于投射物
	FROM_TARGET,     # 相对于目标
	FIXED_DIRECTION  # 固定方向
}

@export var displacement_type: DisplacementType = DisplacementType.KNOCKBACK
@export var direction_reference: DirectionReference = DirectionReference.FROM_PROJECTILE
@export var displacement_force: float = 300.0    # 位移力度/距离
@export var displacement_duration: float = 0.3   # 位移持续时间
@export var displacement_radius: float = 0.0     # 范围位移半径（0表示单体）
@export var fixed_direction: Vector2 = Vector2.RIGHT  # 固定方向（FIXED_DIRECTION使用）
@export var stun_after_displacement: float = 0.0 # 位移后眩晕时间
@export var damage_on_collision: float = 0.0     # 撞墙/撞敌伤害

func _init():
	action_type = ActionType.DISPLACEMENT

func get_type_name() -> String:
	match displacement_type:
		DisplacementType.KNOCKBACK:
			return "击退"
		DisplacementType.PULL:
			return "吸引"
		DisplacementType.TELEPORT:
			return "传送"
		DisplacementType.LAUNCH:
			return "击飞"
		DisplacementType.DASH:
			return "冲刺"
	return "位移"

func clone_deep() -> ActionData:
	var copy = DisplacementActionData.new()
	copy.action_type = action_type
	copy.displacement_type = displacement_type
	copy.direction_reference = direction_reference
	copy.displacement_force = displacement_force
	copy.displacement_duration = displacement_duration
	copy.displacement_radius = displacement_radius
	copy.fixed_direction = fixed_direction
	copy.stun_after_displacement = stun_after_displacement
	copy.damage_on_collision = damage_on_collision
	return copy

func to_dict() -> Dictionary:
	var base = super.to_dict()
	base["displacement_type"] = displacement_type
	base["direction_reference"] = direction_reference
	base["displacement_force"] = displacement_force
	base["displacement_duration"] = displacement_duration
	base["displacement_radius"] = displacement_radius
	base["fixed_direction_x"] = fixed_direction.x
	base["fixed_direction_y"] = fixed_direction.y
	base["stun_after_displacement"] = stun_after_displacement
	base["damage_on_collision"] = damage_on_collision
	return base

static func from_dict(data: Dictionary) -> DisplacementActionData:
	var action = DisplacementActionData.new()
	action.displacement_type = data.get("displacement_type", DisplacementType.KNOCKBACK)
	action.direction_reference = data.get("direction_reference", DirectionReference.FROM_PROJECTILE)
	action.displacement_force = data.get("displacement_force", 300.0)
	action.displacement_duration = data.get("displacement_duration", 0.3)
	action.displacement_radius = data.get("displacement_radius", 0.0)
	action.fixed_direction = Vector2(
		data.get("fixed_direction_x", 1.0),
		data.get("fixed_direction_y", 0.0)
	)
	action.stun_after_displacement = data.get("stun_after_displacement", 0.0)
	action.damage_on_collision = data.get("damage_on_collision", 0.0)
	return action
