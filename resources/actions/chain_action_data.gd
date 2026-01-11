# chain_action_data.gd
# 链式动作数据 - 伤害在多个目标间传导
class_name ChainActionData
extends ActionData

## 链式类型
enum ChainType {
	LIGHTNING,       # 闪电链（快速跳跃）
	FIRE,            # 火焰链（点燃传播）
	ICE,             # 冰霜链（冰冻传播）
	VOID             # 虚空链（标记传播）
}

## 目标选择策略
enum TargetSelection {
	NEAREST,         # 最近目标
	RANDOM,          # 随机目标
	LOWEST_HEALTH,   # 最低生命值
	HIGHEST_HEALTH   # 最高生命值
}

@export var chain_type: ChainType = ChainType.LIGHTNING
@export var chain_count: int = 3                 # 最大跳跃次数
@export var chain_range: float = 200.0           # 跳跃范围
@export var chain_damage: float = 30.0           # 每次跳跃伤害
@export var chain_damage_decay: float = 0.8      # 伤害衰减（每跳）
@export var chain_delay: float = 0.1             # 跳跃间隔（秒）
@export var chain_can_return: bool = false       # 是否可以返回已击中目标
@export var target_selection: TargetSelection = TargetSelection.NEAREST
@export var apply_status_type: int = -1          # 附带状态类型（-1表示无）
@export var apply_status_duration: float = 2.0   # 状态持续时间
@export var apply_status_value: float = 5.0      # 状态效果值
@export var chain_visual_width: float = 3.0      # 链条视觉宽度
@export var fork_chance: float = 0.0             # 分叉概率（0-1）
@export var fork_count: int = 1                  # 分叉数量

func _init():
	action_type = ActionType.CHAIN

func get_type_name() -> String:
	match chain_type:
		ChainType.LIGHTNING:
			return "闪电链"
		ChainType.FIRE:
			return "火焰链"
		ChainType.ICE:
			return "冰霜链"
		ChainType.VOID:
			return "虚空链"
	return "链式"

func clone_deep() -> ActionData:
	var copy = ChainActionData.new()
	copy.action_type = action_type
	copy.chain_type = chain_type
	copy.chain_count = chain_count
	copy.chain_range = chain_range
	copy.chain_damage = chain_damage
	copy.chain_damage_decay = chain_damage_decay
	copy.chain_delay = chain_delay
	copy.chain_can_return = chain_can_return
	copy.target_selection = target_selection
	copy.apply_status_type = apply_status_type
	copy.apply_status_duration = apply_status_duration
	copy.apply_status_value = apply_status_value
	copy.chain_visual_width = chain_visual_width
	copy.fork_chance = fork_chance
	copy.fork_count = fork_count
	return copy

func to_dict() -> Dictionary:
	var base = super.to_dict()
	base["chain_type"] = chain_type
	base["chain_count"] = chain_count
	base["chain_range"] = chain_range
	base["chain_damage"] = chain_damage
	base["chain_damage_decay"] = chain_damage_decay
	base["chain_delay"] = chain_delay
	base["chain_can_return"] = chain_can_return
	base["target_selection"] = target_selection
	base["apply_status_type"] = apply_status_type
	base["apply_status_duration"] = apply_status_duration
	base["apply_status_value"] = apply_status_value
	base["chain_visual_width"] = chain_visual_width
	base["fork_chance"] = fork_chance
	base["fork_count"] = fork_count
	return base

static func from_dict(data: Dictionary) -> ChainActionData:
	var action = ChainActionData.new()
	action.chain_type = data.get("chain_type", ChainType.LIGHTNING)
	action.chain_count = data.get("chain_count", 3)
	action.chain_range = data.get("chain_range", 200.0)
	action.chain_damage = data.get("chain_damage", 30.0)
	action.chain_damage_decay = data.get("chain_damage_decay", 0.8)
	action.chain_delay = data.get("chain_delay", 0.1)
	action.chain_can_return = data.get("chain_can_return", false)
	action.target_selection = data.get("target_selection", TargetSelection.NEAREST)
	action.apply_status_type = data.get("apply_status_type", -1)
	action.apply_status_duration = data.get("apply_status_duration", 2.0)
	action.apply_status_value = data.get("apply_status_value", 5.0)
	action.chain_visual_width = data.get("chain_visual_width", 3.0)
	action.fork_chance = data.get("fork_chance", 0.0)
	action.fork_count = data.get("fork_count", 1)
	return action
