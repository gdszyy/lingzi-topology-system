# spell_scenario_config.gd
# 场景化法术生成配置 - 定义不同使用场景的法术生成策略
class_name SpellScenarioConfig
extends Resource

## 法术使用场景类型
enum SpellScenario {
	HARASS,          # 牵制消耗：低cost，持续骚扰
	SINGLE_TARGET,   # 单体远程：高精准，高单体伤害
	CLOSE_COMBAT,    # 近战法术：近距离，快速释放
	AOE,             # 群伤法术：范围伤害，多目标
	AMBUSH,          # 埋伏法术：地雷/陷阱，接近触发
	DEFENSE,         # 防御法术：护盾、反弹、格挡
	CONTROL,         # 控制法术：减速、冰冻、眩晕、束缚
	SUMMON,          # 召唤法术：召唤独立实体
	CHAIN            # 链式法术：伤害在多目标间传导
}

## 场景配置
var scenario_configs: Dictionary = {
	SpellScenario.HARASS: {
		"name": "牵制消耗",
		"description": "低消耗的持续骚扰法术，适合消耗战",
		"target_count": 5,  # 每个场景生成的法术数量
		
		# 载体限制
		"carrier": {
			"allowed_types": [CarrierConfigData.CarrierType.PROJECTILE, CarrierConfigData.CarrierType.SLOW_ORB],
			"velocity_range": Vector2(200.0, 500.0),
			"lifetime_range": Vector2(2.0, 5.0),
			"mass_range": Vector2(0.3, 1.5),
			"max_homing_strength": 0.5,
			"max_piercing": 2
		},
		
		# 规则限制
		"rules": {
			"max_rules": 2,
			"preferred_triggers": [TriggerData.TriggerType.ON_CONTACT],
			"max_actions_per_rule": 2,
			"allow_fission": false,
			"allow_aoe": false
		},
		
		# Cost 限制
		"cost": {
			"max_total_cost": 30.0,
			"max_damage_per_action": 25.0
		},
		
		# 测试权重
		"test_weights": {
			"damage_efficiency": 0.35,  # 伤害/cost 效率
			"accuracy": 0.25,
			"resource_efficiency": 0.25,
			"ttk": 0.15
		},
		
		# 测试限制
		"test_limits": {
			"max_casts": 20,
			"max_total_cost": 100.0,
			"simulation_duration": 30.0
		}
	},
	
	SpellScenario.SINGLE_TARGET: {
		"name": "单体远程",
		"description": "高精准高伤害的单体法术，适合狙击",
		"target_count": 5,
		
		"carrier": {
			"allowed_types": [CarrierConfigData.CarrierType.PROJECTILE],
			"velocity_range": Vector2(400.0, 900.0),
			"lifetime_range": Vector2(3.0, 8.0),
			"mass_range": Vector2(1.0, 4.0),
			"max_homing_strength": 1.0,
			"max_piercing": 1
		},
		
		"rules": {
			"max_rules": 3,
			"preferred_triggers": [TriggerData.TriggerType.ON_CONTACT],
			"max_actions_per_rule": 3,
			"allow_fission": false,
			"allow_aoe": false
		},
		
		"cost": {
			"max_total_cost": 60.0,
			"max_damage_per_action": 60.0
		},
		
		"test_weights": {
			"single_target_damage": 0.40,
			"accuracy": 0.30,
			"ttk": 0.20,
			"resource_efficiency": 0.10
		},
		
		"test_limits": {
			"max_casts": 10,
			"max_total_cost": 200.0,
			"simulation_duration": 30.0,
			"target_count": 1  # 单目标测试
		}
	},
	
	SpellScenario.CLOSE_COMBAT: {
		"name": "近战法术",
		"description": "近距离快速释放的法术，适合贴身战斗",
		"target_count": 5,
		
		"carrier": {
			"allowed_types": [CarrierConfigData.CarrierType.PROJECTILE, CarrierConfigData.CarrierType.SLOW_ORB],
			"velocity_range": Vector2(100.0, 300.0),
			"lifetime_range": Vector2(0.5, 2.0),
			"mass_range": Vector2(0.5, 2.0),
			"max_homing_strength": 0.3,
			"max_piercing": 3
		},
		
		"rules": {
			"max_rules": 3,
			"preferred_triggers": [TriggerData.TriggerType.ON_CONTACT, TriggerData.TriggerType.ON_PROXIMITY],
			"max_actions_per_rule": 3,
			"allow_fission": true,
			"allow_aoe": true,
			"fission_probability": 0.3
		},
		
		"cost": {
			"max_total_cost": 50.0,
			"max_damage_per_action": 40.0
		},
		
		"test_weights": {
			"close_range_damage": 0.35,
			"survivability": 0.25,
			"multi_hit": 0.25,
			"resource_efficiency": 0.15
		},
		
		"test_limits": {
			"max_casts": 15,
			"max_total_cost": 150.0,
			"simulation_duration": 20.0,
			"spawn_distance": 100.0  # 近距离生成敌人
		}
	},
	
	SpellScenario.AOE: {
		"name": "群伤法术",
		"description": "范围伤害法术，适合对付群体敌人",
		"target_count": 5,
		
		"carrier": {
			"allowed_types": [CarrierConfigData.CarrierType.PROJECTILE, CarrierConfigData.CarrierType.SLOW_ORB],
			"velocity_range": Vector2(150.0, 400.0),
			"lifetime_range": Vector2(2.0, 6.0),
			"mass_range": Vector2(1.0, 3.0),
			"max_homing_strength": 0.5,
			"max_piercing": 5
		},
		
		"rules": {
			"max_rules": 4,
			"preferred_triggers": [TriggerData.TriggerType.ON_CONTACT, TriggerData.TriggerType.ON_TIMER, TriggerData.TriggerType.ON_DEATH],
			"max_actions_per_rule": 3,
			"allow_fission": true,
			"allow_aoe": true,
			"fission_probability": 0.5,
			"aoe_probability": 0.6
		},
		
		"cost": {
			"max_total_cost": 80.0,
			"max_damage_per_action": 35.0
		},
		
		"test_weights": {
			"total_damage": 0.30,
			"enemies_hit": 0.35,
			"area_coverage": 0.20,
			"resource_efficiency": 0.15
		},
		
		"test_limits": {
			"max_casts": 10,
			"max_total_cost": 250.0,
			"simulation_duration": 30.0,
			"target_count": 8  # 多目标测试
		}
	},
	
	SpellScenario.AMBUSH: {
		"name": "埋伏法术",
		"description": "地雷/陷阱类法术，敌人接近时触发",
		"target_count": 5,
		
		"carrier": {
			"allowed_types": [CarrierConfigData.CarrierType.MINE, CarrierConfigData.CarrierType.SLOW_ORB],
			"velocity_range": Vector2(0.0, 100.0),  # 地雷速度为0，慢速球低速
			"lifetime_range": Vector2(8.0, 20.0),
			"mass_range": Vector2(1.0, 3.0),
			"max_homing_strength": 0.0,  # 埋伏不追踪
			"max_piercing": 0
		},
		
		"rules": {
			"max_rules": 3,
			"preferred_triggers": [TriggerData.TriggerType.ON_PROXIMITY, TriggerData.TriggerType.ON_TIMER],
			"max_actions_per_rule": 3,
			"allow_fission": true,
			"allow_aoe": true,
			"fission_probability": 0.4,
			"aoe_probability": 0.7
		},
		
		"cost": {
			"max_total_cost": 70.0,
			"max_damage_per_action": 50.0
		},
		
		"test_weights": {
			"trap_effectiveness": 0.35,
			"area_denial": 0.25,
			"total_damage": 0.25,
			"resource_efficiency": 0.15
		},
		
		"test_limits": {
			"max_casts": 5,  # 埋伏法术数量少
			"max_total_cost": 150.0,
			"simulation_duration": 45.0,  # 更长的测试时间
			"delayed_spawn": true,  # 敌人延迟生成
			"spawn_delay": 5.0
		}
	},
	
	# ========== 新增场景 ==========
	
	SpellScenario.DEFENSE: {
		"name": "防御法术",
		"description": "生成护盾、反弹伤害、格挡投射物",
		"target_count": 5,
		
		"carrier": {
			"allowed_types": [CarrierConfigData.CarrierType.SLOW_ORB, CarrierConfigData.CarrierType.MINE],
			"velocity_range": Vector2(0.0, 100.0),  # 低速或静止
			"lifetime_range": Vector2(5.0, 15.0),   # 较长持续时间
			"mass_range": Vector2(1.0, 3.0),
			"max_homing_strength": 0.0,
			"max_piercing": 0
		},
		
		"rules": {
			"max_rules": 3,
			"preferred_triggers": [
				TriggerData.TriggerType.ON_CONTACT,
				TriggerData.TriggerType.ON_PROXIMITY,
				TriggerData.TriggerType.ON_ALLY_CONTACT
			],
			"max_actions_per_rule": 2,
			"allow_fission": false,
			"allow_aoe": false,
			"allow_shield": true,
			"allow_reflect": true,
			"shield_probability": 0.6,
			"reflect_probability": 0.4
		},
		
		"cost": {
			"max_total_cost": 60.0,
			"max_damage_per_action": 20.0  # 防御法术伤害低
		},
		
		"test_weights": {
			"damage_blocked": 0.35,
			"shield_uptime": 0.25,
			"reflect_damage": 0.20,
			"resource_efficiency": 0.20
		},
		
		"test_limits": {
			"max_casts": 8,
			"max_total_cost": 150.0,
			"simulation_duration": 40.0,
			"incoming_damage_test": true  # 需要模拟受到伤害
		}
	},
	
	SpellScenario.CONTROL: {
		"name": "控制法术",
		"description": "减速、冰冻、眩晕、束缚等控制效果",
		"target_count": 5,
		
		"carrier": {
			"allowed_types": [CarrierConfigData.CarrierType.PROJECTILE, CarrierConfigData.CarrierType.SLOW_ORB],
			"velocity_range": Vector2(200.0, 500.0),  # 中等速度
			"lifetime_range": Vector2(3.0, 8.0),
			"mass_range": Vector2(0.5, 2.0),
			"max_homing_strength": 0.8,
			"max_piercing": 2
		},
		
		"rules": {
			"max_rules": 3,
			"preferred_triggers": [
				TriggerData.TriggerType.ON_CONTACT,
				TriggerData.TriggerType.ON_PROXIMITY,
				TriggerData.TriggerType.ON_STATUS_APPLIED
			],
			"max_actions_per_rule": 3,
			"allow_fission": true,
			"allow_aoe": true,
			"allow_status": true,
			"allow_displacement": true,
			"fission_probability": 0.2,
			"aoe_probability": 0.3,
			"status_probability": 0.7,
			"displacement_probability": 0.4,
			"preferred_status_types": [
				1,  # FROZEN
				3,  # SLOWED
				4,  # STUNNED
				6   # ROOTED
			]
		},
		
		"cost": {
			"max_total_cost": 55.0,
			"max_damage_per_action": 25.0  # 控制法术伤害中等
		},
		
		"test_weights": {
			"control_duration": 0.35,
			"control_coverage": 0.25,
			"damage_dealt": 0.20,
			"resource_efficiency": 0.20
		},
		
		"test_limits": {
			"max_casts": 12,
			"max_total_cost": 180.0,
			"simulation_duration": 35.0,
			"target_count": 5
		}
	},
	
	SpellScenario.SUMMON: {
		"name": "召唤法术",
		"description": "召唤独立实体，实体有自己的行为逻辑",
		"target_count": 5,
		
		"carrier": {
			"allowed_types": [CarrierConfigData.CarrierType.PROJECTILE, CarrierConfigData.CarrierType.MINE],
			"velocity_range": Vector2(0.0, 300.0),  # 可静止或移动
			"lifetime_range": Vector2(1.0, 3.0),    # 载体快速消失
			"mass_range": Vector2(0.5, 2.0),
			"max_homing_strength": 0.3,
			"max_piercing": 0
		},
		
		"rules": {
			"max_rules": 2,
			"preferred_triggers": [
				TriggerData.TriggerType.ON_CONTACT,
				TriggerData.TriggerType.ON_TIMER,
				TriggerData.TriggerType.ON_DEATH
			],
			"max_actions_per_rule": 2,
			"allow_fission": true,
			"allow_aoe": false,
			"allow_summon": true,
			"fission_probability": 0.3,
			"summon_probability": 0.8,
			"preferred_summon_types": [
				0,  # TURRET
				1,  # MINION
				2,  # ORBITER
				5   # TOTEM
			]
		},
		
		"cost": {
			"max_total_cost": 75.0,
			"max_damage_per_action": 20.0
		},
		
		"test_weights": {
			"summon_damage": 0.30,
			"summon_uptime": 0.25,
			"summon_survivability": 0.25,
			"resource_efficiency": 0.20
		},
		
		"test_limits": {
			"max_casts": 6,
			"max_total_cost": 200.0,
			"simulation_duration": 45.0,
			"target_count": 4
		}
	},
	
	SpellScenario.CHAIN: {
		"name": "链式法术",
		"description": "伤害在多个目标间传导，类似闪电链",
		"target_count": 5,
		
		"carrier": {
			"allowed_types": [CarrierConfigData.CarrierType.PROJECTILE],
			"velocity_range": Vector2(400.0, 800.0),  # 较快速度
			"lifetime_range": Vector2(2.0, 5.0),
			"mass_range": Vector2(0.5, 2.0),
			"max_homing_strength": 0.6,
			"max_piercing": 1
		},
		
		"rules": {
			"max_rules": 3,
			"preferred_triggers": [
				TriggerData.TriggerType.ON_CONTACT,
				TriggerData.TriggerType.ON_CHAIN_END
			],
			"max_actions_per_rule": 3,
			"allow_fission": false,
			"allow_aoe": true,
			"allow_chain": true,
			"allow_status": true,
			"chain_probability": 0.8,
			"aoe_probability": 0.3,
			"status_probability": 0.4,
			"preferred_chain_types": [
				0,  # LIGHTNING
				1,  # FIRE
				2   # ICE
			]
		},
		
		"cost": {
			"max_total_cost": 65.0,
			"max_damage_per_action": 35.0
		},
		
		"test_weights": {
			"chain_damage": 0.30,
			"targets_hit": 0.30,
			"chain_efficiency": 0.20,
			"resource_efficiency": 0.20
		},
		
		"test_limits": {
			"max_casts": 10,
			"max_total_cost": 200.0,
			"simulation_duration": 30.0,
			"target_count": 6,  # 需要多目标测试链式
			"target_spacing": 150.0  # 目标间距，确保链式可以跳跃
		}
	}
}

## 获取场景配置
func get_scenario_config(scenario: SpellScenario) -> Dictionary:
	return scenario_configs.get(scenario, {})

## 获取所有场景
func get_all_scenarios() -> Array:
	return scenario_configs.keys()

## 获取所有场景（包括新场景）
func get_all_scenario_types() -> Array[SpellScenario]:
	return [
		SpellScenario.HARASS,
		SpellScenario.SINGLE_TARGET,
		SpellScenario.CLOSE_COMBAT,
		SpellScenario.AOE,
		SpellScenario.AMBUSH,
		SpellScenario.DEFENSE,
		SpellScenario.CONTROL,
		SpellScenario.SUMMON,
		SpellScenario.CHAIN
	]

## 获取场景名称
func get_scenario_name(scenario: SpellScenario) -> String:
	var config = get_scenario_config(scenario)
	return config.get("name", "未知场景")

## 获取场景描述
func get_scenario_description(scenario: SpellScenario) -> String:
	var config = get_scenario_config(scenario)
	return config.get("description", "")

## 检查场景是否允许某种动作类型
func is_action_allowed(scenario: SpellScenario, action_type: ActionData.ActionType) -> bool:
	var config = get_scenario_config(scenario)
	var rules = config.get("rules", {})
	
	match action_type:
		ActionData.ActionType.FISSION:
			return rules.get("allow_fission", false)
		ActionData.ActionType.AREA_EFFECT, ActionData.ActionType.SPAWN_ENTITY:
			return rules.get("allow_aoe", false)
		ActionData.ActionType.SHIELD:
			return rules.get("allow_shield", false)
		ActionData.ActionType.REFLECT:
			return rules.get("allow_reflect", false)
		ActionData.ActionType.DISPLACEMENT:
			return rules.get("allow_displacement", false)
		ActionData.ActionType.CHAIN:
			return rules.get("allow_chain", false)
		ActionData.ActionType.SUMMON:
			return rules.get("allow_summon", false)
		ActionData.ActionType.APPLY_STATUS:
			return rules.get("allow_status", true)  # 默认允许状态
		ActionData.ActionType.DAMAGE:
			return true  # 伤害总是允许
	
	return true

## 获取场景的动作概率
func get_action_probability(scenario: SpellScenario, action_type: ActionData.ActionType) -> float:
	var config = get_scenario_config(scenario)
	var rules = config.get("rules", {})
	
	match action_type:
		ActionData.ActionType.FISSION:
			return rules.get("fission_probability", 0.0)
		ActionData.ActionType.AREA_EFFECT, ActionData.ActionType.SPAWN_ENTITY:
			return rules.get("aoe_probability", 0.0)
		ActionData.ActionType.SHIELD:
			return rules.get("shield_probability", 0.0)
		ActionData.ActionType.REFLECT:
			return rules.get("reflect_probability", 0.0)
		ActionData.ActionType.DISPLACEMENT:
			return rules.get("displacement_probability", 0.0)
		ActionData.ActionType.CHAIN:
			return rules.get("chain_probability", 0.0)
		ActionData.ActionType.SUMMON:
			return rules.get("summon_probability", 0.0)
		ActionData.ActionType.APPLY_STATUS:
			return rules.get("status_probability", 0.3)
	
	return 0.5

## 创建默认配置
static func create_default() -> SpellScenarioConfig:
	return SpellScenarioConfig.new()
