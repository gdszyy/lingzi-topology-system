# fission_action_data.gd
# 裂变动作数据 - 生成子法术实体（核心递归机制）
class_name FissionActionData
extends ActionData

@export var spawn_count: int = 3                    # 生成数量
@export var spread_angle: float = 360.0             # 扩散角度（度）
@export var inherit_velocity: float = 0.5           # 继承父载体速度的比例
@export var spawn_offset: float = 10.0              # 生成位置偏移
@export var child_spell_id: String = ""             # 子法术ID（用于引用）
@export var child_spell_data: Resource = null       # 子法术数据（SpellCoreData）
@export var max_recursion_depth: int = 3            # 最大递归深度
@export var destroy_parent: bool = false            # 裂变后是否销毁父实体

func _init():
	action_type = ActionType.FISSION

func clone_deep() -> ActionData:
	var copy = FissionActionData.new()
	copy.action_type = action_type
	copy.spawn_count = spawn_count
	copy.spread_angle = spread_angle
	copy.inherit_velocity = inherit_velocity
	copy.spawn_offset = spawn_offset
	copy.child_spell_id = child_spell_id
	copy.max_recursion_depth = max_recursion_depth
	copy.destroy_parent = destroy_parent
	# 深拷贝子法术数据
	if child_spell_data != null and child_spell_data.has_method("clone_deep"):
		copy.child_spell_data = child_spell_data.clone_deep()
	return copy

func to_dict() -> Dictionary:
	var base = super.to_dict()
	base["spawn_count"] = spawn_count
	base["spread_angle"] = spread_angle
	base["inherit_velocity"] = inherit_velocity
	base["spawn_offset"] = spawn_offset
	base["child_spell_id"] = child_spell_id
	base["max_recursion_depth"] = max_recursion_depth
	base["destroy_parent"] = destroy_parent
	if child_spell_data != null and child_spell_data.has_method("to_dict"):
		base["child_spell_data"] = child_spell_data.to_dict()
	return base

static func from_dict(data: Dictionary) -> FissionActionData:
	var action = FissionActionData.new()
	action.spawn_count = data.get("spawn_count", 3)
	action.spread_angle = data.get("spread_angle", 360.0)
	action.inherit_velocity = data.get("inherit_velocity", 0.5)
	action.spawn_offset = data.get("spawn_offset", 10.0)
	action.child_spell_id = data.get("child_spell_id", "")
	action.max_recursion_depth = data.get("max_recursion_depth", 3)
	action.destroy_parent = data.get("destroy_parent", false)
	# 子法术数据需要在外部处理，避免循环引用
	return action
