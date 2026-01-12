class_name AISkillRule extends Resource

## AI技能使用规则
## 定义AI在何种条件下使用特定技能

enum SkillCondition {
	ALWAYS,                  # 总是可用
	HEALTH_BELOW,            # 生命值低于阈值
	HEALTH_ABOVE,            # 生命值高于阈值
	ENEMY_COUNT_ABOVE,       # 敌人数量超过阈值
	ALLY_COUNT_BELOW,        # 同伴数量低于阈值
	DISTANCE_BELOW,          # 与目标距离小于阈值
	DISTANCE_ABOVE,          # 与目标距离大于阈值
	TARGET_IS_CASTING,       # 目标正在施法
	TARGET_IS_ATTACKING,     # 目标正在攻击
	TARGET_HEALTH_BELOW,     # 目标生命值低于阈值
	COOLDOWN_READY,          # 技能冷却完毕
	RANDOM_CHANCE            # 随机概率
}

enum SkillType {
	ATTACK,         # 攻击技能
	HEAL,           # 治疗技能
	BUFF,           # 增益技能
	DEBUFF,         # 减益技能
	SUMMON,         # 召唤技能
	MOVEMENT,       # 移动技能
	DEFENSIVE       # 防御技能
}

@export_group("技能信息")
@export var skill_name: String = "技能"
@export var skill_type: SkillType = SkillType.ATTACK
@export var spell_data: SpellCoreData  # 关联的法术数据
@export var cooldown: float = 5.0
@export var energy_cost: float = 10.0

@export_group("使用条件")
@export var primary_condition: SkillCondition = SkillCondition.COOLDOWN_READY
@export var condition_threshold: float = 0.5  # 条件阈值
@export var secondary_conditions: Array[SkillCondition] = []
@export var secondary_thresholds: Array[float] = []

@export_group("优先级")
@export var priority: float = 1.0  # 技能优先级
@export var interrupt_current_action: bool = false  # 是否可以打断当前动作

## 运行时状态
var current_cooldown: float = 0.0
var use_count: int = 0

## 检查技能是否可用
func can_use(context: Dictionary) -> bool:
	# 检查冷却
	if current_cooldown > 0:
		return false
	
	# 检查能量
	var current_energy = context.get("current_energy", 0.0)
	if current_energy < energy_cost:
		return false
	
	# 检查主要条件
	if not _check_condition(primary_condition, condition_threshold, context):
		return false
	
	# 检查次要条件
	for i in range(secondary_conditions.size()):
		var condition = secondary_conditions[i]
		var threshold = secondary_thresholds[i] if i < secondary_thresholds.size() else 0.5
		if not _check_condition(condition, threshold, context):
			return false
	
	return true

## 检查单个条件
func _check_condition(condition: SkillCondition, threshold: float, context: Dictionary) -> bool:
	match condition:
		SkillCondition.ALWAYS:
			return true
		
		SkillCondition.HEALTH_BELOW:
			return context.get("health_percent", 1.0) < threshold
		
		SkillCondition.HEALTH_ABOVE:
			return context.get("health_percent", 1.0) > threshold
		
		SkillCondition.ENEMY_COUNT_ABOVE:
			return context.get("enemy_count", 0) > int(threshold)
		
		SkillCondition.ALLY_COUNT_BELOW:
			return context.get("ally_count", 0) < int(threshold)
		
		SkillCondition.DISTANCE_BELOW:
			return context.get("distance_to_target", 0.0) < threshold
		
		SkillCondition.DISTANCE_ABOVE:
			return context.get("distance_to_target", 0.0) > threshold
		
		SkillCondition.TARGET_IS_CASTING:
			return context.get("target_is_casting", false)
		
		SkillCondition.TARGET_IS_ATTACKING:
			return context.get("target_is_attacking", false)
		
		SkillCondition.TARGET_HEALTH_BELOW:
			return context.get("target_health_percent", 1.0) < threshold
		
		SkillCondition.COOLDOWN_READY:
			return current_cooldown <= 0
		
		SkillCondition.RANDOM_CHANCE:
			return randf() < threshold
	
	return false

## 使用技能
func use() -> void:
	current_cooldown = cooldown
	use_count += 1

## 更新冷却时间
func update_cooldown(delta: float) -> void:
	if current_cooldown > 0:
		current_cooldown -= delta

## 重置技能状态
func reset() -> void:
	current_cooldown = 0.0
	use_count = 0

## 获取技能类型名称
func get_skill_type_name() -> String:
	match skill_type:
		SkillType.ATTACK:
			return "攻击"
		SkillType.HEAL:
			return "治疗"
		SkillType.BUFF:
			return "增益"
		SkillType.DEBUFF:
			return "减益"
		SkillType.SUMMON:
			return "召唤"
		SkillType.MOVEMENT:
			return "移动"
		SkillType.DEFENSIVE:
			return "防御"
	return "未知"

## 创建攻击技能规则
static func create_attack_skill(spell: SpellCoreData, cd: float = 5.0) -> AISkillRule:
	var rule = AISkillRule.new()
	rule.skill_name = spell.spell_name if spell else "攻击技能"
	rule.skill_type = SkillType.ATTACK
	rule.spell_data = spell
	rule.cooldown = cd
	rule.primary_condition = SkillCondition.DISTANCE_BELOW
	rule.condition_threshold = 300.0
	rule.priority = 1.0
	return rule

## 创建治疗技能规则
static func create_heal_skill(spell: SpellCoreData, cd: float = 10.0) -> AISkillRule:
	var rule = AISkillRule.new()
	rule.skill_name = spell.spell_name if spell else "治疗技能"
	rule.skill_type = SkillType.HEAL
	rule.spell_data = spell
	rule.cooldown = cd
	rule.primary_condition = SkillCondition.HEALTH_BELOW
	rule.condition_threshold = 0.5
	rule.priority = 2.0  # 治疗技能优先级更高
	rule.interrupt_current_action = true
	return rule

## 创建逃跑技能规则
static func create_escape_skill(spell: SpellCoreData, cd: float = 15.0) -> AISkillRule:
	var rule = AISkillRule.new()
	rule.skill_name = spell.spell_name if spell else "逃跑技能"
	rule.skill_type = SkillType.MOVEMENT
	rule.spell_data = spell
	rule.cooldown = cd
	rule.primary_condition = SkillCondition.HEALTH_BELOW
	rule.condition_threshold = 0.3
	rule.secondary_conditions.append(SkillCondition.DISTANCE_BELOW)
	rule.secondary_thresholds.append(150.0)
	rule.priority = 3.0  # 逃跑技能最高优先级
	rule.interrupt_current_action = true
	return rule

func to_dict() -> Dictionary:
	return {
		"skill_name": skill_name,
		"skill_type": skill_type,
		"cooldown": cooldown,
		"energy_cost": energy_cost,
		"priority": priority,
		"current_cooldown": current_cooldown,
		"use_count": use_count
	}
