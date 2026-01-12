class_name AITargetingPriority extends Resource

## AI肢体目标优先级
## 定义攻击玩家特定肢体的优先级和条件
## 用于实现战术性的肢体目标选择

@export_group("目标肢体")
@export var part_type: BodyPartData.PartType = BodyPartData.PartType.TORSO
@export var priority_score: float = 1.0  # 基础优先级分数

@export_group("动态权重调节")
@export var player_is_casting_bonus: float = 0.0    # 当玩家正在施法时的额外加分
@export var player_is_moving_bonus: float = 0.0     # 当玩家正在移动时的额外加分
@export var player_is_attacking_bonus: float = 0.0  # 当玩家正在攻击时的额外加分
@export var player_is_flying_bonus: float = 0.0     # 当玩家正在飞行时的额外加分
@export var part_is_damaged_bonus: float = 0.0      # 当此部位已受伤时的额外加分
@export var part_is_critical_bonus: float = 0.0     # 当此部位重伤时的额外加分
@export var part_has_spell_bonus: float = 0.0       # 当此部位有篆刻法术时的额外加分

@export_group("条件限制")
@export var min_health_percent: float = 0.0         # AI最低生命值百分比要求
@export var max_distance: float = 0.0               # 最大攻击距离（0表示无限制）
@export var require_line_of_sight: bool = false     # 是否需要视线

## 计算当前战局下的实际优先级分数
func calculate_score(context: Dictionary) -> float:
	var score = priority_score
	
	# 玩家状态加成
	if context.get("player_is_casting", false):
		score += player_is_casting_bonus
	
	if context.get("player_is_moving", false):
		score += player_is_moving_bonus
	
	if context.get("player_is_attacking", false):
		score += player_is_attacking_bonus
	
	if context.get("player_is_flying", false):
		score += player_is_flying_bonus
	
	# 肢体状态加成
	var part_health_percent = context.get("part_health_percent", 1.0)
	if part_health_percent < 1.0 and part_health_percent > 0.25:
		score += part_is_damaged_bonus
	elif part_health_percent <= 0.25 and part_health_percent > 0:
		score += part_is_critical_bonus
	
	# 法术加成
	if context.get("part_has_spell", false):
		score += part_has_spell_bonus
	
	return max(0.0, score)

## 检查是否满足条件限制
func check_conditions(context: Dictionary) -> bool:
	# 检查AI生命值
	var ai_health_percent = context.get("ai_health_percent", 1.0)
	if ai_health_percent < min_health_percent:
		return false
	
	# 检查距离
	if max_distance > 0:
		var distance = context.get("distance", 0.0)
		if distance > max_distance:
			return false
	
	# 检查视线
	if require_line_of_sight:
		if not context.get("has_line_of_sight", true):
			return false
	
	return true

## 获取肢体类型名称
func get_part_type_name() -> String:
	match part_type:
		BodyPartData.PartType.HEAD:
			return "头部"
		BodyPartData.PartType.TORSO:
			return "躯干"
		BodyPartData.PartType.LEFT_ARM:
			return "左臂"
		BodyPartData.PartType.RIGHT_ARM:
			return "右臂"
		BodyPartData.PartType.LEFT_HAND:
			return "左手"
		BodyPartData.PartType.RIGHT_HAND:
			return "右手"
		BodyPartData.PartType.LEGS:
			return "腿部"
		BodyPartData.PartType.LEFT_FOOT:
			return "左脚"
		BodyPartData.PartType.RIGHT_FOOT:
			return "右脚"
	return "未知"

## 创建攻击头部优先级（用于刺客型）
static func create_head_priority() -> AITargetingPriority:
	var priority = AITargetingPriority.new()
	priority.part_type = BodyPartData.PartType.HEAD
	priority.priority_score = 2.0
	priority.part_is_damaged_bonus = 1.0
	priority.part_is_critical_bonus = 2.0
	return priority

## 创建攻击手部优先级（用于打断施法）
static func create_hand_priority() -> AITargetingPriority:
	var priority = AITargetingPriority.new()
	priority.part_type = BodyPartData.PartType.RIGHT_HAND
	priority.priority_score = 1.0
	priority.player_is_casting_bonus = 3.0
	priority.part_has_spell_bonus = 1.5
	return priority

## 创建攻击腿部优先级（用于限制移动）
static func create_legs_priority() -> AITargetingPriority:
	var priority = AITargetingPriority.new()
	priority.part_type = BodyPartData.PartType.LEGS
	priority.priority_score = 1.0
	priority.player_is_moving_bonus = 2.0
	priority.player_is_flying_bonus = 3.0
	return priority

## 创建攻击手臂优先级（用于削弱攻击）
static func create_arm_priority() -> AITargetingPriority:
	var priority = AITargetingPriority.new()
	priority.part_type = BodyPartData.PartType.RIGHT_ARM
	priority.priority_score = 1.0
	priority.player_is_attacking_bonus = 2.5
	return priority

## 创建默认躯干优先级
static func create_torso_priority() -> AITargetingPriority:
	var priority = AITargetingPriority.new()
	priority.part_type = BodyPartData.PartType.TORSO
	priority.priority_score = 1.5
	return priority

func to_dict() -> Dictionary:
	return {
		"part_type": part_type,
		"priority_score": priority_score,
		"player_is_casting_bonus": player_is_casting_bonus,
		"player_is_moving_bonus": player_is_moving_bonus,
		"player_is_attacking_bonus": player_is_attacking_bonus,
		"player_is_flying_bonus": player_is_flying_bonus,
		"part_is_damaged_bonus": part_is_damaged_bonus,
		"part_is_critical_bonus": part_is_critical_bonus,
		"part_has_spell_bonus": part_has_spell_bonus
	}
