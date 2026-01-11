# action_data.gd
# 效果动作数据基类 - 定义触发后执行的效果
class_name ActionData
extends Resource

## 动作类型枚举
enum ActionType {
	DAMAGE,          # 造成伤害
	FISSION,         # 裂变（生成子弹）
	APPLY_STATUS,    # 施加状态效果
	DISPLACEMENT,    # 位移效果（击退/吸引/传送）
	AREA_EFFECT,     # 范围效果（已弃用，保留兼容）
	HEAL,            # 治疗
	SPAWN_ENTITY,    # 生成实体（爆炸、持续伤害区域等）
	SHIELD,          # 护盾
	REFLECT,         # 反弹
	CHAIN,           # 链式传导
	SUMMON           # 召唤
}

@export var action_type: ActionType = ActionType.DAMAGE

## 获取动作类型名称
func get_type_name() -> String:
	match action_type:
		ActionType.DAMAGE:
			return "伤害"
		ActionType.FISSION:
			return "裂变"
		ActionType.APPLY_STATUS:
			return "状态效果"
		ActionType.DISPLACEMENT:
			return "位移"
		ActionType.AREA_EFFECT:
			return "范围效果"
		ActionType.HEAL:
			return "治疗"
		ActionType.SPAWN_ENTITY:
			return "生成实体"
		ActionType.SHIELD:
			return "护盾"
		ActionType.REFLECT:
			return "反弹"
		ActionType.CHAIN:
			return "链式"
		ActionType.SUMMON:
			return "召唤"
	return "未知动作"

## 深拷贝（子类需要重写）
func clone_deep() -> ActionData:
	var copy = ActionData.new()
	copy.action_type = action_type
	return copy

## 转换为字典
func to_dict() -> Dictionary:
	return {
		"action_type": action_type
	}

## 从字典加载
static func from_dict(data: Dictionary) -> ActionData:
	var action_type_val = data.get("action_type", ActionType.DAMAGE)
	var action: ActionData
	
	match action_type_val:
		ActionType.DAMAGE:
			action = DamageActionData.from_dict(data)
		ActionType.FISSION:
			action = FissionActionData.from_dict(data)
		ActionType.APPLY_STATUS:
			action = ApplyStatusActionData.from_dict(data)
		ActionType.AREA_EFFECT:
			# 兼容旧数据，转换为SpawnExplosionActionData
			action = SpawnExplosionActionData.from_dict(data)
		ActionType.SPAWN_ENTITY:
			# 根据具体类型判断
			if data.has("explosion_damage"):
				action = SpawnExplosionActionData.from_dict(data)
			elif data.has("zone_damage"):
				action = SpawnDamageZoneActionData.from_dict(data)
			else:
				action = SpawnExplosionActionData.from_dict(data)
		ActionType.DISPLACEMENT:
			action = DisplacementActionData.from_dict(data)
		ActionType.SHIELD:
			action = ShieldActionData.from_dict(data)
		ActionType.REFLECT:
			action = ReflectActionData.from_dict(data)
		ActionType.CHAIN:
			action = ChainActionData.from_dict(data)
		ActionType.SUMMON:
			action = SummonActionData.from_dict(data)
		_:
			action = ActionData.new()
			action.action_type = action_type_val
	
	return action
