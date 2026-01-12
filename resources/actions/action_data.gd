class_name ActionData
extends Resource

enum ActionType {
	DAMAGE,
	FISSION,
	APPLY_STATUS,
	DISPLACEMENT,
	AREA_EFFECT,
	HEAL,
	SPAWN_ENTITY,
	SHIELD,
	REFLECT,
	CHAIN,
	SUMMON,
	ENERGY_RESTORE,   # 能量恢复
	CULTIVATION,      # 修炼（恢复能量上限）
	SPAWN_EXPLOSION,  # 生成爆炸
	SPAWN_DAMAGE_ZONE # 生成伤害区域
}

@export var action_type: ActionType = ActionType.DAMAGE

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
		ActionType.ENERGY_RESTORE:
			return "能量恢复"
		ActionType.CULTIVATION:
			return "修炼"
		ActionType.SPAWN_EXPLOSION:
			return "生成爆炸"
		ActionType.SPAWN_DAMAGE_ZONE:
			return "生成伤害区域"
	return "未知动作"

func clone_deep() -> ActionData:
	var copy = ActionData.new()
	copy.action_type = action_type
	return copy

func to_dict() -> Dictionary:
	return {
		"action_type": action_type
	}

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
			action = SpawnExplosionActionData.from_dict(data)
		ActionType.SPAWN_ENTITY:
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
		ActionType.ENERGY_RESTORE:
			action = EnergyRestoreActionData.from_dict(data)
		ActionType.CULTIVATION:
			action = CultivationActionData.from_dict(data)
		ActionType.SPAWN_EXPLOSION:
			action = SpawnExplosionActionData.from_dict(data)
		ActionType.SPAWN_DAMAGE_ZONE:
			action = SpawnDamageZoneActionData.from_dict(data)
		_:
			action = ActionData.new()
			action.action_type = action_type_val

	return action
