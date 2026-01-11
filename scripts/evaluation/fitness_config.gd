# fitness_config.gd
# 适应度评估配置 - 定义评估权重和场景配置
class_name FitnessConfig
extends Resource

## 场景类型枚举
enum ScenarioType {
	SINGLE_TARGET,     # 单体目标场景
	MULTI_TARGET,      # 群体目标场景
	HIGH_MOBILITY,     # 高机动性场景
	SURVIVAL           # 生存场景
}

## 性能指标权重
@export_group("指标权重")
@export var weight_damage: float = 0.25           # 总伤害权重
@export var weight_ttk: float = 0.20              # 击杀时间权重
@export var weight_accuracy: float = 0.15         # 命中率权重
@export var weight_resource_efficiency: float = 0.15  # 资源效率权重
@export var weight_overkill: float = 0.10         # 过量伤害惩罚权重
@export var weight_instability: float = 0.15      # 不稳定性惩罚权重

## 场景权重
@export_group("场景权重")
@export var weight_single_target: float = 0.35    # 单体场景权重
@export var weight_multi_target: float = 0.35     # 群体场景权重
@export var weight_high_mobility: float = 0.20    # 高机动性场景权重
@export var weight_survival: float = 0.10         # 生存场景权重

## 归一化参数
@export_group("归一化参数")
@export var max_expected_damage: float = 1000.0   # 预期最大伤害
@export var max_expected_ttk: float = 30.0        # 预期最大击杀时间（秒）
@export var max_expected_resource: float = 100.0  # 预期最大资源消耗
@export var max_instability: float = 20.0         # 最大不稳定性

## 场景配置
@export_group("场景配置")
@export var simulation_duration: float = 30.0     # 模拟持续时间
@export var cast_interval: float = 1.0            # 施法间隔

## 验证权重总和
func validate_weights() -> bool:
	var metric_sum = weight_damage + weight_ttk + weight_accuracy + \
					 weight_resource_efficiency + weight_overkill + weight_instability
	var scenario_sum = weight_single_target + weight_multi_target + \
					   weight_high_mobility + weight_survival
	
	return absf(metric_sum - 1.0) < 0.01 and absf(scenario_sum - 1.0) < 0.01

## 获取指标权重字典
func get_metric_weights() -> Dictionary:
	return {
		"damage": weight_damage,
		"ttk": weight_ttk,
		"accuracy": weight_accuracy,
		"resource_efficiency": weight_resource_efficiency,
		"overkill": weight_overkill,
		"instability": weight_instability
	}

## 获取场景权重字典
func get_scenario_weights() -> Dictionary:
	return {
		ScenarioType.SINGLE_TARGET: weight_single_target,
		ScenarioType.MULTI_TARGET: weight_multi_target,
		ScenarioType.HIGH_MOBILITY: weight_high_mobility,
		ScenarioType.SURVIVAL: weight_survival
	}

## 创建默认配置
static func create_default() -> FitnessConfig:
	var config = FitnessConfig.new()
	return config

## 创建偏向AOE的配置
static func create_aoe_focused() -> FitnessConfig:
	var config = FitnessConfig.new()
	config.weight_single_target = 0.15
	config.weight_multi_target = 0.55
	config.weight_high_mobility = 0.20
	config.weight_survival = 0.10
	return config

## 创建偏向单体的配置
static func create_single_target_focused() -> FitnessConfig:
	var config = FitnessConfig.new()
	config.weight_single_target = 0.55
	config.weight_multi_target = 0.20
	config.weight_high_mobility = 0.15
	config.weight_survival = 0.10
	return config

## 创建偏向命中率的配置
static func create_accuracy_focused() -> FitnessConfig:
	var config = FitnessConfig.new()
	config.weight_accuracy = 0.30
	config.weight_damage = 0.20
	config.weight_ttk = 0.20
	config.weight_resource_efficiency = 0.10
	config.weight_overkill = 0.10
	config.weight_instability = 0.10
	return config
