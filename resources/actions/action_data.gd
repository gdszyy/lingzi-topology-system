class_name ActionData
extends Resource

## 动作数据基类（优化版）
## 改进：使用数据驱动的类型名称映射表替代 match 链
## 修复 AREA_EFFECT 反序列化错误映射到 SpawnExplosionActionData 的 bug
## 使用注册表模式的 from_dict 反序列化，便于扩展

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

## 类型名称映射表（数据驱动，替代冗长的 match 链）
const TYPE_NAMES: Dictionary = {
	ActionType.DAMAGE: "伤害",
	ActionType.FISSION: "裂变",
	ActionType.APPLY_STATUS: "状态效果",
	ActionType.DISPLACEMENT: "位移",
	ActionType.AREA_EFFECT: "范围效果",
	ActionType.HEAL: "治疗",
	ActionType.SPAWN_ENTITY: "生成实体",
	ActionType.SHIELD: "护盾",
	ActionType.REFLECT: "反弹",
	ActionType.CHAIN: "链式",
	ActionType.SUMMON: "召唤",
	ActionType.ENERGY_RESTORE: "能量恢复",
	ActionType.CULTIVATION: "修炼",
	ActionType.SPAWN_EXPLOSION: "生成爆炸",
	ActionType.SPAWN_DAMAGE_ZONE: "生成伤害区域",
}

func get_type_name() -> String:
	return TYPE_NAMES.get(action_type, "未知动作")

func clone_deep() -> ActionData:
	var copy = ActionData.new()
	copy.action_type = action_type
	return copy

func to_dict() -> Dictionary:
	return {
		"action_type": action_type
	}

## 反序列化注册表: { ActionType -> Callable(data: Dictionary) -> ActionData }
## 使用注册表模式替代冗长的 match 链，新增动作类型时只需注册即可
static var _deserializers: Dictionary = {}
static var _deserializers_initialized: bool = false

## 初始化反序列化注册表
static func _ensure_deserializers() -> void:
	if _deserializers_initialized:
		return
	_deserializers_initialized = true
	
	_deserializers[ActionType.DAMAGE] = func(data: Dictionary) -> ActionData: return DamageActionData.from_dict(data)
	_deserializers[ActionType.FISSION] = func(data: Dictionary) -> ActionData: return FissionActionData.from_dict(data)
	_deserializers[ActionType.APPLY_STATUS] = func(data: Dictionary) -> ActionData: return ApplyStatusActionData.from_dict(data)
	_deserializers[ActionType.AREA_EFFECT] = func(data: Dictionary) -> ActionData: return AreaEffectActionData.from_dict(data)  # 修复：原来错误映射到 SpawnExplosionActionData
	_deserializers[ActionType.DISPLACEMENT] = func(data: Dictionary) -> ActionData: return DisplacementActionData.from_dict(data)
	_deserializers[ActionType.SHIELD] = func(data: Dictionary) -> ActionData: return ShieldActionData.from_dict(data)
	_deserializers[ActionType.REFLECT] = func(data: Dictionary) -> ActionData: return ReflectActionData.from_dict(data)
	_deserializers[ActionType.CHAIN] = func(data: Dictionary) -> ActionData: return ChainActionData.from_dict(data)
	_deserializers[ActionType.SUMMON] = func(data: Dictionary) -> ActionData: return SummonActionData.from_dict(data)
	_deserializers[ActionType.ENERGY_RESTORE] = func(data: Dictionary) -> ActionData: return EnergyRestoreActionData.from_dict(data)
	_deserializers[ActionType.CULTIVATION] = func(data: Dictionary) -> ActionData: return CultivationActionData.from_dict(data)
	_deserializers[ActionType.SPAWN_EXPLOSION] = func(data: Dictionary) -> ActionData: return SpawnExplosionActionData.from_dict(data)
	_deserializers[ActionType.SPAWN_DAMAGE_ZONE] = func(data: Dictionary) -> ActionData: return SpawnDamageZoneActionData.from_dict(data)
	# SPAWN_ENTITY 使用智能分发
	_deserializers[ActionType.SPAWN_ENTITY] = func(data: Dictionary) -> ActionData: return _deserialize_spawn_entity(data)

## SPAWN_ENTITY 的智能分发反序列化
static func _deserialize_spawn_entity(data: Dictionary) -> ActionData:
	if data.has("zone_damage"):
		return SpawnDamageZoneActionData.from_dict(data)
	else:
		return SpawnExplosionActionData.from_dict(data)

## 注册自定义反序列化器（扩展点）
static func register_deserializer(type: ActionType, deserializer: Callable) -> void:
	_ensure_deserializers()
	_deserializers[type] = deserializer

static func from_dict(data: Dictionary) -> ActionData:
	_ensure_deserializers()
	
	var action_type_val = data.get("action_type", ActionType.DAMAGE)
	
	if _deserializers.has(action_type_val):
		return _deserializers[action_type_val].call(data)
	
	# 未注册的类型，创建基础 ActionData
	push_warning("[ActionData] 未注册的动作类型反序列化器: %d" % action_type_val)
	var action = ActionData.new()
	action.action_type = action_type_val
	return action
