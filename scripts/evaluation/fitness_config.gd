class_name FitnessConfig
extends Resource

enum ScenarioType {
	SINGLE_TARGET,
	MULTI_TARGET,
	HIGH_MOBILITY,
	SURVIVAL,
	CLOSE_RANGE
}

@export_group("指标权重")
@export var weight_damage: float = 0.20
@export var weight_ttk: float = 0.15
@export var weight_accuracy: float = 0.15
@export var weight_resource_efficiency: float = 0.15
@export var weight_overkill: float = 0.10
@export var weight_instability: float = 0.10
@export var weight_complexity: float = 0.15

@export_group("场景权重")
@export var weight_single_target: float = 0.25
@export var weight_multi_target: float = 0.25
@export var weight_high_mobility: float = 0.20
@export var weight_survival: float = 0.15
@export var weight_close_range: float = 0.15

@export_group("归一化参数")
@export var max_expected_damage: float = 1000.0
@export var max_expected_ttk: float = 30.0
@export var max_expected_resource: float = 100.0
@export var max_instability: float = 20.0

@export_group("Cost 限制")
@export var max_total_cost: float = 100.0
@export var max_damage_per_action: float = 50.0
@export var max_fission_depth: int = 4
@export var max_fission_count: int = 10
@export var cost_per_damage: float = 0.3
@export var cost_per_fission: float = 2.5
@export var cost_per_status: float = 0.8
@export var cost_per_aoe_radius: float = 0.08

@export_group("嵌套 Cost 预算")
@export var layer_1_budget: float = 80.0
@export var layer_2_budget: float = 60.0
@export var layer_3_budget: float = 45.0
@export var layer_4_budget: float = 35.0
@export var child_cost_decay: float = 0.4
@export var child_cost_decay_rate: float = 1.5

@export_group("复杂度奖励")
@export var complexity_bonus_per_rule: float = 5.0
@export var complexity_bonus_per_trigger_type: float = 8.0
@export var complexity_bonus_per_action_type: float = 6.0
@export var complexity_bonus_fission: float = 15.0
@export var complexity_bonus_status: float = 10.0
@export var complexity_bonus_combo: float = 20.0
@export var max_complexity_bonus: float = 100.0
@export var nesting_depth_bonus: float = 15.0
@export var nesting_depth_multiplier: float = 1.3

@export_group("多样性保护")
@export var diversity_weight: float = 0.25
@export var similarity_penalty: float = 0.35
@export var niche_radius: float = 0.25
@export var duplicate_penalty: float = 0.7
@export var rare_type_bonus: float = 0.2

@export_group("场景配置")
@export var simulation_duration: float = 30.0
@export var cast_interval: float = 1.0

func get_layer_budget(nesting_depth: int) -> float:
	match nesting_depth:
		1: return layer_1_budget
		2: return layer_2_budget
		3: return layer_3_budget
		4: return layer_4_budget
		_: return layer_4_budget * 0.8

func get_child_cost_ratio(depth: int) -> float:
	return child_cost_decay / pow(child_cost_decay_rate, depth)

func validate_weights() -> bool:
	var metric_sum = weight_damage + weight_ttk + weight_accuracy + \
					 weight_resource_efficiency + weight_overkill + \
					 weight_instability + weight_complexity
	var scenario_sum = weight_single_target + weight_multi_target + \
					   weight_high_mobility + weight_survival + weight_close_range

	return absf(metric_sum - 1.0) < 0.01 and absf(scenario_sum - 1.0) < 0.01

func get_metric_weights() -> Dictionary:
	return {
		"damage": weight_damage,
		"ttk": weight_ttk,
		"accuracy": weight_accuracy,
		"resource_efficiency": weight_resource_efficiency,
		"overkill": weight_overkill,
		"instability": weight_instability,
		"complexity": weight_complexity
	}

func get_scenario_weights() -> Dictionary:
	return {
		ScenarioType.SINGLE_TARGET: weight_single_target,
		ScenarioType.MULTI_TARGET: weight_multi_target,
		ScenarioType.HIGH_MOBILITY: weight_high_mobility,
		ScenarioType.SURVIVAL: weight_survival,
		ScenarioType.CLOSE_RANGE: weight_close_range
	}

static func create_default() -> FitnessConfig:
	var config = FitnessConfig.new()
	return config

static func create_aoe_focused() -> FitnessConfig:
	var config = FitnessConfig.new()
	config.weight_single_target = 0.10
	config.weight_multi_target = 0.45
	config.weight_high_mobility = 0.15
	config.weight_survival = 0.15
	config.weight_close_range = 0.15
	return config

static func create_single_target_focused() -> FitnessConfig:
	var config = FitnessConfig.new()
	config.weight_single_target = 0.45
	config.weight_multi_target = 0.15
	config.weight_high_mobility = 0.15
	config.weight_survival = 0.15
	config.weight_close_range = 0.10
	return config

static func create_flashy_focused() -> FitnessConfig:
	var config = FitnessConfig.new()
	config.weight_damage = 0.15
	config.weight_complexity = 0.25
	config.complexity_bonus_fission = 25.0
	config.complexity_bonus_combo = 30.0
	return config

static func create_close_range_focused() -> FitnessConfig:
	var config = FitnessConfig.new()
	config.weight_single_target = 0.15
	config.weight_multi_target = 0.15
	config.weight_high_mobility = 0.15
	config.weight_survival = 0.20
	config.weight_close_range = 0.35
	return config

static func create_diversity_focused() -> FitnessConfig:
	var config = FitnessConfig.new()
	config.diversity_weight = 0.2
	config.similarity_penalty = 0.3
	config.weight_damage = 0.15
	config.weight_complexity = 0.20
	return config

static func create_deep_nesting_focused() -> FitnessConfig:
	var config = FitnessConfig.new()
	config.max_fission_depth = 4
	config.nesting_depth_bonus = 20.0
	config.nesting_depth_multiplier = 1.5
	config.cost_per_damage = 0.25
	config.cost_per_fission = 2.0
	config.child_cost_decay = 0.35
	return config
