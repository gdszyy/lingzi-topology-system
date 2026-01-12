class_name AIBehaviorProfile extends Resource

## AI行为配置
## 定义敌人的"性格"和战术偏好
## 通过数据驱动的方式实现AI多样性

enum AIArchetype {
	MELEE_AGGRESSIVE,   # 近战激进型
	MELEE_DEFENSIVE,    # 近战防守型
	RANGED_SNIPER,      # 远程狙击型
	RANGED_MOBILE,      # 远程机动型
	SUPPORT_HEALER,     # 辅助治疗型
	ASSASSIN,           # 刺客型
	TANK,               # 坦克型
	SWARM               # 蜂群型（低智能，数量多）
}

enum CombatStyle {
	AGGRESSIVE,  # 激进 - 优先攻击
	BALANCED,    # 平衡 - 攻防兼备
	DEFENSIVE,   # 防守 - 优先保护自己
	EVASIVE      # 闪避 - 优先躲避
}

@export_group("基础信息")
@export var profile_name: String = "默认AI"
@export var archetype: AIArchetype = AIArchetype.MELEE_AGGRESSIVE
@export var combat_style: CombatStyle = CombatStyle.BALANCED

@export_group("感知与索敌")
@export var perception_radius: float = 500.0      # 索敌范围
@export var peripheral_vision_angle: float = 120.0 # 周边视野角度（度）
@export var line_of_sight_required: bool = true   # 是否需要视线
@export var memory_duration: float = 5.0          # 丢失目标后保持追击的时间
@export var alert_allies_radius: float = 200.0    # 警报同伴的范围

@export_group("移动与站位")
@export var move_speed: float = 150.0             # 移动速度
@export var engagement_distance: float = 150.0    # 进入战斗的最佳距离
@export var min_engagement_distance: float = 50.0 # 与目标保持的最小距离
@export var max_chase_distance: float = 1000.0    # 最大追击距离
@export var strafe_enabled: bool = true           # 是否启用横向移动
@export var strafe_frequency: float = 2.0         # 横向移动频率
@export var strafe_distance: float = 80.0         # 横向移动距离
@export var retreat_enabled: bool = true          # 是否允许后退
@export var flee_health_threshold: float = 0.2    # 当生命值低于此百分比时尝试逃跑

@export_group("攻击性")
@export var aggression: float = 0.8               # 攻击欲望 (0-1)，影响攻击频率
@export var attack_cooldown: float = 2.0          # 基础攻击冷却时间
@export var attack_cooldown_variance: float = 0.5 # 攻击冷却随机浮动
@export var combo_chance: float = 0.3             # 连击概率
@export var max_combo_length: int = 3             # 最大连击长度
@export var attack_range: float = 100.0           # 攻击范围

@export_group("技能使用")
@export var skill_usage_enabled: bool = true
@export var skill_cooldown: float = 5.0
@export var skill_usage_rules: Array[AISkillRule] = []

@export_group("肢体目标策略")
@export var use_body_part_targeting: bool = true  # 是否启用肢体目标选择
@export var targeting_priorities: Array[AITargetingPriority] = []

@export_group("防御行为")
@export var block_chance: float = 0.0             # 格挡概率
@export var dodge_chance: float = 0.2             # 闪避概率
@export var dodge_distance: float = 100.0         # 闪避距离
@export var counter_attack_chance: float = 0.1    # 反击概率

@export_group("团队协作")
@export var team_awareness: float = 0.5           # 团队意识 (0-1)
@export var formation_enabled: bool = false       # 是否启用阵型
@export var preferred_formation_role: int = 0     # 阵型中的角色

## 获取实际攻击冷却时间（带随机浮动）
func get_attack_cooldown() -> float:
	return attack_cooldown + randf_range(-attack_cooldown_variance, attack_cooldown_variance)

## 根据当前战局调整攻击欲望
func get_adjusted_aggression(health_percent: float, ally_count: int, enemy_count: int) -> float:
	var adjusted = aggression
	
	# 生命值低时降低攻击欲望
	if health_percent < 0.5:
		adjusted *= 0.7
	if health_percent < 0.25:
		adjusted *= 0.5
	
	# 同伴多时增加攻击欲望
	if ally_count > enemy_count:
		adjusted *= 1.2
	elif ally_count < enemy_count:
		adjusted *= 0.8
	
	return clamp(adjusted, 0.0, 1.0)

## 判断是否应该逃跑
func should_flee(health_percent: float) -> bool:
	return health_percent <= flee_health_threshold and retreat_enabled

## 判断是否应该尝试闪避
func should_dodge() -> bool:
	return randf() < dodge_chance

## 判断是否应该尝试格挡
func should_block() -> bool:
	return randf() < block_chance

## 判断是否应该反击
func should_counter_attack() -> bool:
	return randf() < counter_attack_chance

## 判断是否应该尝试连击
func should_combo() -> bool:
	return randf() < combo_chance

## 获取最佳攻击距离
func get_optimal_attack_distance() -> float:
	return (engagement_distance + min_engagement_distance) / 2.0

## 创建近战激进型配置
static func create_melee_aggressive() -> AIBehaviorProfile:
	var profile = AIBehaviorProfile.new()
	profile.profile_name = "近战激进型"
	profile.archetype = AIArchetype.MELEE_AGGRESSIVE
	profile.combat_style = CombatStyle.AGGRESSIVE
	profile.perception_radius = 400.0
	profile.engagement_distance = 80.0
	profile.min_engagement_distance = 30.0
	profile.aggression = 0.9
	profile.attack_cooldown = 1.5
	profile.combo_chance = 0.5
	profile.max_combo_length = 4
	profile.attack_range = 60.0
	profile.flee_health_threshold = 0.1
	profile.dodge_chance = 0.1
	profile.use_body_part_targeting = true
	return profile

## 创建远程狙击型配置
static func create_ranged_sniper() -> AIBehaviorProfile:
	var profile = AIBehaviorProfile.new()
	profile.profile_name = "远程狙击型"
	profile.archetype = AIArchetype.RANGED_SNIPER
	profile.combat_style = CombatStyle.DEFENSIVE
	profile.perception_radius = 800.0
	profile.engagement_distance = 400.0
	profile.min_engagement_distance = 300.0
	profile.aggression = 0.6
	profile.attack_cooldown = 3.0
	profile.combo_chance = 0.0
	profile.attack_range = 500.0
	profile.flee_health_threshold = 0.3
	profile.retreat_enabled = true
	profile.strafe_enabled = true
	profile.strafe_frequency = 3.0
	profile.dodge_chance = 0.3
	profile.use_body_part_targeting = true
	return profile

## 创建刺客型配置
static func create_assassin() -> AIBehaviorProfile:
	var profile = AIBehaviorProfile.new()
	profile.profile_name = "刺客型"
	profile.archetype = AIArchetype.ASSASSIN
	profile.combat_style = CombatStyle.EVASIVE
	profile.perception_radius = 600.0
	profile.engagement_distance = 60.0
	profile.min_engagement_distance = 20.0
	profile.move_speed = 200.0
	profile.aggression = 0.7
	profile.attack_cooldown = 2.5
	profile.combo_chance = 0.2
	profile.attack_range = 50.0
	profile.flee_health_threshold = 0.4
	profile.dodge_chance = 0.5
	profile.dodge_distance = 150.0
	profile.counter_attack_chance = 0.3
	profile.use_body_part_targeting = true
	
	# 刺客优先攻击头部和手部
	var head_priority = AITargetingPriority.new()
	head_priority.part_type = BodyPartData.PartType.HEAD
	head_priority.priority_score = 2.0
	profile.targeting_priorities.append(head_priority)
	
	var hand_priority = AITargetingPriority.new()
	hand_priority.part_type = BodyPartData.PartType.RIGHT_HAND
	hand_priority.priority_score = 1.5
	hand_priority.player_is_casting_bonus = 2.0
	profile.targeting_priorities.append(hand_priority)
	
	return profile

## 创建坦克型配置
static func create_tank() -> AIBehaviorProfile:
	var profile = AIBehaviorProfile.new()
	profile.profile_name = "坦克型"
	profile.archetype = AIArchetype.TANK
	profile.combat_style = CombatStyle.DEFENSIVE
	profile.perception_radius = 350.0
	profile.engagement_distance = 100.0
	profile.min_engagement_distance = 40.0
	profile.move_speed = 80.0
	profile.aggression = 0.5
	profile.attack_cooldown = 3.0
	profile.combo_chance = 0.1
	profile.attack_range = 80.0
	profile.flee_health_threshold = 0.0  # 坦克不逃跑
	profile.block_chance = 0.4
	profile.dodge_chance = 0.0
	profile.use_body_part_targeting = false  # 坦克不精确瞄准
	return profile

## 创建蜂群型配置（低智能小兵）
static func create_swarm() -> AIBehaviorProfile:
	var profile = AIBehaviorProfile.new()
	profile.profile_name = "蜂群型"
	profile.archetype = AIArchetype.SWARM
	profile.combat_style = CombatStyle.AGGRESSIVE
	profile.perception_radius = 300.0
	profile.engagement_distance = 50.0
	profile.min_engagement_distance = 20.0
	profile.move_speed = 120.0
	profile.aggression = 1.0
	profile.attack_cooldown = 1.0
	profile.combo_chance = 0.0
	profile.attack_range = 40.0
	profile.flee_health_threshold = 0.0  # 蜂群不逃跑
	profile.skill_usage_enabled = false
	profile.use_body_part_targeting = false  # 蜂群不精确瞄准
	profile.team_awareness = 0.8
	return profile

func to_dict() -> Dictionary:
	return {
		"profile_name": profile_name,
		"archetype": archetype,
		"combat_style": combat_style,
		"perception_radius": perception_radius,
		"engagement_distance": engagement_distance,
		"aggression": aggression,
		"attack_cooldown": attack_cooldown,
		"flee_health_threshold": flee_health_threshold
	}
