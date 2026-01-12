class_name EnemyPresetManager extends Node

## 敌人预设管理器
## 管理和创建各种类型的敌人预设

## 敌人预设数据结构
class EnemyPreset:
	var id: String
	var name: String
	var description: String
	var profile: AIBehaviorProfile
	var color: Color
	var base_health: float
	var base_damage: float
	var score_value: int
	var tier: int  # 敌人等级 1-5
	var tags: Array[String]
	
	func _init():
		id = ""
		name = "未命名敌人"
		description = ""
		profile = null
		color = Color.RED
		base_health = 100.0
		base_damage = 10.0
		score_value = 10
		tier = 1
		tags = []

## 预设列表
var presets: Dictionary = {}

func _ready() -> void:
	_initialize_default_presets()

## 初始化默认预设
func _initialize_default_presets() -> void:
	# 近战小兵
	var grunt = EnemyPreset.new()
	grunt.id = "grunt"
	grunt.name = "近战小兵"
	grunt.description = "基础近战单位，数量众多但单体较弱"
	grunt.profile = AIBehaviorProfile.create_melee_aggressive()
	grunt.color = Color(0.8, 0.2, 0.2)
	grunt.base_health = 80.0
	grunt.base_damage = 8.0
	grunt.score_value = 10
	grunt.tier = 1
	grunt.tags = ["melee", "common"]
	presets[grunt.id] = grunt
	
	# 远程射手
	var archer = EnemyPreset.new()
	archer.id = "archer"
	archer.name = "远程射手"
	archer.description = "远程攻击单位，保持距离进行射击"
	archer.profile = AIBehaviorProfile.create_ranged_sniper()
	archer.color = Color(0.2, 0.6, 0.8)
	archer.base_health = 60.0
	archer.base_damage = 12.0
	archer.score_value = 15
	archer.tier = 2
	archer.tags = ["ranged", "common"]
	presets[archer.id] = archer
	
	# 刺客
	var assassin = EnemyPreset.new()
	assassin.id = "assassin"
	assassin.name = "暗影刺客"
	assassin.description = "高机动性刺客，擅长闪避和偷袭"
	assassin.profile = AIBehaviorProfile.create_assassin()
	assassin.color = Color(0.5, 0.2, 0.8)
	assassin.base_health = 50.0
	assassin.base_damage = 20.0
	assassin.score_value = 25
	assassin.tier = 3
	assassin.tags = ["melee", "elite", "fast"]
	presets[assassin.id] = assassin
	
	# 坦克
	var tank = EnemyPreset.new()
	tank.id = "tank"
	tank.name = "重装卫士"
	tank.description = "高生命值坦克，移动缓慢但难以击杀"
	tank.profile = AIBehaviorProfile.create_tank()
	tank.color = Color(0.4, 0.4, 0.4)
	tank.base_health = 250.0
	tank.base_damage = 15.0
	tank.score_value = 30
	tank.tier = 3
	tank.tags = ["melee", "elite", "tank"]
	presets[tank.id] = tank
	
	# 蜂群兵
	var swarm = EnemyPreset.new()
	swarm.id = "swarm"
	swarm.name = "蜂群兵"
	swarm.description = "弱小但成群出现的单位"
	swarm.profile = AIBehaviorProfile.create_swarm()
	swarm.color = Color(0.6, 0.6, 0.2)
	swarm.base_health = 30.0
	swarm.base_damage = 5.0
	swarm.score_value = 5
	swarm.tier = 1
	swarm.tags = ["melee", "swarm"]
	presets[swarm.id] = swarm
	
	# 法师
	var mage = _create_mage_preset()
	presets[mage.id] = mage
	
	# 狂战士
	var berserker = _create_berserker_preset()
	presets[berserker.id] = berserker
	
	# 治疗者
	var healer = _create_healer_preset()
	presets[healer.id] = healer
	
	# Boss - 精英战士
	var elite_warrior = _create_elite_warrior_preset()
	presets[elite_warrior.id] = elite_warrior
	
	# Boss - 暗影领主
	var shadow_lord = _create_shadow_lord_preset()
	presets[shadow_lord.id] = shadow_lord

## 创建法师预设
func _create_mage_preset() -> EnemyPreset:
	var mage = EnemyPreset.new()
	mage.id = "mage"
	mage.name = "元素法师"
	mage.description = "远程法术攻击者，能够施放强力法术"
	
	var profile = AIBehaviorProfile.new()
	profile.profile_name = "元素法师"
	profile.archetype = AIBehaviorProfile.AIArchetype.RANGED_MOBILE
	profile.combat_style = AIBehaviorProfile.CombatStyle.BALANCED
	profile.perception_radius = 600.0
	profile.engagement_distance = 350.0
	profile.min_engagement_distance = 250.0
	profile.move_speed = 100.0
	profile.aggression = 0.7
	profile.attack_cooldown = 2.5
	profile.attack_range = 400.0
	profile.flee_health_threshold = 0.25
	profile.dodge_chance = 0.2
	profile.skill_usage_enabled = true
	profile.use_body_part_targeting = true
	
	mage.profile = profile
	mage.color = Color(0.3, 0.3, 0.9)
	mage.base_health = 70.0
	mage.base_damage = 25.0
	mage.score_value = 35
	mage.tier = 3
	mage.tags = ["ranged", "elite", "caster"]
	
	return mage

## 创建狂战士预设
func _create_berserker_preset() -> EnemyPreset:
	var berserker = EnemyPreset.new()
	berserker.id = "berserker"
	berserker.name = "狂战士"
	berserker.description = "生命值越低攻击力越高的疯狂战士"
	
	var profile = AIBehaviorProfile.new()
	profile.profile_name = "狂战士"
	profile.archetype = AIBehaviorProfile.AIArchetype.MELEE_AGGRESSIVE
	profile.combat_style = AIBehaviorProfile.CombatStyle.AGGRESSIVE
	profile.perception_radius = 450.0
	profile.engagement_distance = 60.0
	profile.min_engagement_distance = 20.0
	profile.move_speed = 180.0
	profile.aggression = 1.0
	profile.attack_cooldown = 1.0
	profile.combo_chance = 0.7
	profile.max_combo_length = 5
	profile.attack_range = 70.0
	profile.flee_health_threshold = 0.0  # 狂战士永不逃跑
	profile.dodge_chance = 0.0
	profile.use_body_part_targeting = false
	
	berserker.profile = profile
	berserker.color = Color(0.9, 0.3, 0.1)
	berserker.base_health = 120.0
	berserker.base_damage = 15.0
	berserker.score_value = 40
	berserker.tier = 3
	berserker.tags = ["melee", "elite", "berserker"]
	
	return berserker

## 创建治疗者预设
func _create_healer_preset() -> EnemyPreset:
	var healer = EnemyPreset.new()
	healer.id = "healer"
	healer.name = "治疗祭司"
	healer.description = "能够治疗其他敌人的支援单位"
	
	var profile = AIBehaviorProfile.new()
	profile.profile_name = "治疗祭司"
	profile.archetype = AIBehaviorProfile.AIArchetype.SUPPORT_HEALER
	profile.combat_style = AIBehaviorProfile.CombatStyle.DEFENSIVE
	profile.perception_radius = 500.0
	profile.engagement_distance = 300.0
	profile.min_engagement_distance = 200.0
	profile.move_speed = 90.0
	profile.aggression = 0.3
	profile.attack_cooldown = 3.0
	profile.attack_range = 250.0
	profile.flee_health_threshold = 0.4
	profile.retreat_enabled = true
	profile.dodge_chance = 0.3
	profile.skill_usage_enabled = true
	profile.team_awareness = 0.9
	profile.use_body_part_targeting = false
	
	healer.profile = profile
	healer.color = Color(0.2, 0.8, 0.3)
	healer.base_health = 80.0
	healer.base_damage = 8.0
	healer.score_value = 50
	healer.tier = 4
	healer.tags = ["ranged", "elite", "support", "priority"]
	
	return healer

## 创建精英战士预设
func _create_elite_warrior_preset() -> EnemyPreset:
	var elite = EnemyPreset.new()
	elite.id = "elite_warrior"
	elite.name = "精英战士"
	elite.description = "强大的精英近战单位，具有多种战斗技能"
	
	var profile = AIBehaviorProfile.new()
	profile.profile_name = "精英战士"
	profile.archetype = AIBehaviorProfile.AIArchetype.MELEE_AGGRESSIVE
	profile.combat_style = AIBehaviorProfile.CombatStyle.BALANCED
	profile.perception_radius = 500.0
	profile.engagement_distance = 80.0
	profile.min_engagement_distance = 30.0
	profile.move_speed = 140.0
	profile.aggression = 0.8
	profile.attack_cooldown = 1.5
	profile.combo_chance = 0.5
	profile.max_combo_length = 4
	profile.attack_range = 80.0
	profile.flee_health_threshold = 0.1
	profile.block_chance = 0.3
	profile.dodge_chance = 0.2
	profile.counter_attack_chance = 0.25
	profile.skill_usage_enabled = true
	profile.use_body_part_targeting = true
	
	# 添加肢体目标优先级
	var head_priority = AITargetingPriority.create_head_priority()
	var hand_priority = AITargetingPriority.create_hand_priority()
	profile.targeting_priorities.append(head_priority)
	profile.targeting_priorities.append(hand_priority)
	
	elite.profile = profile
	elite.color = Color(0.8, 0.6, 0.1)
	elite.base_health = 300.0
	elite.base_damage = 25.0
	elite.score_value = 100
	elite.tier = 4
	elite.tags = ["melee", "boss", "elite"]
	
	return elite

## 创建暗影领主预设
func _create_shadow_lord_preset() -> EnemyPreset:
	var boss = EnemyPreset.new()
	boss.id = "shadow_lord"
	boss.name = "暗影领主"
	boss.description = "终极Boss，拥有多种攻击模式和强大的生命力"
	
	var profile = AIBehaviorProfile.new()
	profile.profile_name = "暗影领主"
	profile.archetype = AIBehaviorProfile.AIArchetype.ASSASSIN
	profile.combat_style = AIBehaviorProfile.CombatStyle.BALANCED
	profile.perception_radius = 800.0
	profile.engagement_distance = 100.0
	profile.min_engagement_distance = 40.0
	profile.move_speed = 160.0
	profile.aggression = 0.85
	profile.attack_cooldown = 1.2
	profile.combo_chance = 0.6
	profile.max_combo_length = 6
	profile.attack_range = 100.0
	profile.flee_health_threshold = 0.0
	profile.block_chance = 0.2
	profile.dodge_chance = 0.4
	profile.dodge_distance = 200.0
	profile.counter_attack_chance = 0.4
	profile.skill_usage_enabled = true
	profile.use_body_part_targeting = true
	
	# 添加全面的肢体目标优先级
	profile.targeting_priorities.append(AITargetingPriority.create_head_priority())
	profile.targeting_priorities.append(AITargetingPriority.create_hand_priority())
	profile.targeting_priorities.append(AITargetingPriority.create_legs_priority())
	profile.targeting_priorities.append(AITargetingPriority.create_arm_priority())
	
	boss.profile = profile
	boss.color = Color(0.2, 0.1, 0.3)
	boss.base_health = 500.0
	boss.base_damage = 35.0
	boss.score_value = 500
	boss.tier = 5
	boss.tags = ["melee", "boss", "final"]
	
	return boss

## 获取预设
func get_preset(id: String) -> EnemyPreset:
	return presets.get(id, null)

## 获取所有预设
func get_all_presets() -> Array:
	return presets.values()

## 获取指定等级的预设
func get_presets_by_tier(tier: int) -> Array:
	var result = []
	for preset in presets.values():
		if preset.tier == tier:
			result.append(preset)
	return result

## 获取指定标签的预设
func get_presets_by_tag(tag: String) -> Array:
	var result = []
	for preset in presets.values():
		if tag in preset.tags:
			result.append(preset)
	return result

## 获取随机预设
func get_random_preset(max_tier: int = 5) -> EnemyPreset:
	var valid_presets = []
	for preset in presets.values():
		if preset.tier <= max_tier:
			valid_presets.append(preset)
	
	if valid_presets.is_empty():
		return null
	
	return valid_presets[randi() % valid_presets.size()]

## 获取波次适合的预设列表
func get_presets_for_wave(wave_number: int) -> Array:
	var max_tier = mini(1 + wave_number / 3, 5)
	var result = []
	
	for preset in presets.values():
		if preset.tier <= max_tier:
			result.append(preset)
	
	return result
