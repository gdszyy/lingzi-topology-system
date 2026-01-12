class_name MonkBehaviorProfile extends AIBehaviorProfile

## 修士AI行为配置
## 扩展基础AI配置，增加修士特有的战斗逻辑和团队协作参数

enum TeamRole {
	BALANCED,   # 平衡型
	VANGUARD,   # 先锋（冲锋陷阵）
	GUARDIAN,   # 守护者（保护队友）
	SNIPER,     # 狙击手（远程输出）
	SUPPORT     # 辅助（治疗和增益）
}

enum PositioningStyle {
	DYNAMIC,    # 动态调整
	CLOSE,      # 贴身紧逼
	MID_RANGE,  # 中距离拉扯
	LONG_RANGE, # 远距离狙击
	FLANKING    # 侧翼包抄
}

@export_group("修士专属配置")
@export var team_role: TeamRole = TeamRole.BALANCED
@export var positioning_style: PositioningStyle = PositioningStyle.DYNAMIC
@export var cultivation_threshold: float = 0.3  # 能量上限低于此值时尝试修炼恢复
@export var spell_loadout: Array[SpellCoreData] = [] # 初始携带的法术

@export_group("团队协作参数")
@export var help_ally_threshold: float = 0.4    # 队友生命低于此值时尝试救援
@export var focus_fire_willingness: float = 0.8 # 参与集火的意愿 (0-1)
@export var coordination_frequency: float = 1.0 # 与团队同步战术的频率

## 创建默认修士配置
static func create_default_monk() -> MonkBehaviorProfile:
	var profile = MonkBehaviorProfile.new()
	profile.profile_name = "标准修士"
	profile.archetype = AIArchetype.MELEE_AGGRESSIVE
	profile.combat_style = CombatStyle.BALANCED
	profile.perception_radius = 600.0
	profile.move_speed = 180.0
	profile.engagement_distance = 120.0
	profile.aggression = 0.7
	profile.attack_cooldown = 1.2
	profile.dodge_chance = 0.3
	profile.use_body_part_targeting = true
	
	profile.team_role = TeamRole.BALANCED
	profile.positioning_style = PositioningStyle.DYNAMIC
	profile.cultivation_threshold = 0.4
	
	return profile
