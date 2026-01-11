# fitness_config.gd
# 适应度评估配置 - 定义评估权重和场景配置
class_name FitnessConfig
extends Resource

## 场景类型枚举
enum ScenarioType {
	SINGLE_TARGET,     # 单体目标场景
	MULTI_TARGET,      # 群体目标场景
	HIGH_MOBILITY,     # 高机动性场景
	SURVIVAL,          # 生存场景
	CLOSE_RANGE        # 近战场景（新增）
}

## 性能指标权重
@export_group("指标权重")
@export var weight_damage: float = 0.20           # 总伤害权重（降低，避免无脑堆叠）
@export var weight_ttk: float = 0.15              # 击杀时间权重
@export var weight_accuracy: float = 0.15         # 命中率权重
@export var weight_resource_efficiency: float = 0.15  # 资源效率权重
@export var weight_overkill: float = 0.10         # 过量伤害惩罚权重
@export var weight_instability: float = 0.10      # 不稳定性惩罚权重
@export var weight_complexity: float = 0.15       # 复杂度/华丽度奖励（新增）

## 场景权重
@export_group("场景权重")
@export var weight_single_target: float = 0.25    # 单体场景权重
@export var weight_multi_target: float = 0.25     # 群体场景权重
@export var weight_high_mobility: float = 0.20    # 高机动性场景权重
@export var weight_survival: float = 0.15         # 生存场景权重
@export var weight_close_range: float = 0.15      # 近战场景权重（新增）

## 归一化参数
@export_group("归一化参数")
@export var max_expected_damage: float = 1000.0   # 预期最大伤害
@export var max_expected_ttk: float = 30.0        # 预期最大击杀时间（秒）
@export var max_expected_resource: float = 100.0  # 预期最大资源消耗
@export var max_instability: float = 20.0         # 最大不稳定性

## Cost 限制（新增）
@export_group("Cost 限制")
@export var max_total_cost: float = 100.0         # 法术最大总 cost
@export var max_damage_per_action: float = 50.0   # 单个动作最大伤害
@export var max_fission_depth: int = 3            # 最大裂变深度
@export var max_fission_count: int = 12           # 单次裂变最大数量
@export var cost_per_damage: float = 0.5          # 每点伤害的 cost
@export var cost_per_fission: float = 2.0         # 每个裂变子弹的 cost
@export var cost_per_status: float = 1.0          # 每个状态效果的 cost
@export var cost_per_aoe_radius: float = 0.1      # 每单位 AOE 半径的 cost

## 复杂度奖励配置（新增）
@export_group("复杂度奖励")
@export var complexity_bonus_per_rule: float = 5.0       # 每条规则的奖励
@export var complexity_bonus_per_trigger_type: float = 8.0  # 每种不同触发器类型的奖励
@export var complexity_bonus_per_action_type: float = 6.0   # 每种不同动作类型的奖励
@export var complexity_bonus_fission: float = 15.0       # 使用裂变的奖励
@export var complexity_bonus_status: float = 10.0        # 使用状态效果的奖励
@export var complexity_bonus_combo: float = 20.0         # 组合效果奖励（如裂变+状态）
@export var max_complexity_bonus: float = 100.0          # 复杂度奖励上限
@export var nesting_depth_bonus: float = 12.0            # 每层嵌套的奖励（鼓励多层嵌套法术）
@export var nesting_depth_multiplier: float = 1.5        # 嵌套层数奖励乘数（每层递增）

## 多样性保护配置（增强版）
@export_group("多样性保护")
@export var diversity_weight: float = 0.25               # 多样性权重（提高）
@export var similarity_penalty: float = 0.35             # 相似度惩罚（加强）
@export var niche_radius: float = 0.25                   # 生态位半径（扩大，更容易触发惩罚）
@export var duplicate_penalty: float = 0.7               # 完全重复惩罚（新增）
@export var rare_type_bonus: float = 0.2                 # 稀有类型奖励（新增）

## 场景配置
@export_group("场景配置")
@export var simulation_duration: float = 30.0     # 模拟持续时间
@export var cast_interval: float = 1.0            # 施法间隔

## 验证权重总和
func validate_weights() -> bool:
	var metric_sum = weight_damage + weight_ttk + weight_accuracy + \
					 weight_resource_efficiency + weight_overkill + \
					 weight_instability + weight_complexity
	var scenario_sum = weight_single_target + weight_multi_target + \
					   weight_high_mobility + weight_survival + weight_close_range
	
	return absf(metric_sum - 1.0) < 0.01 and absf(scenario_sum - 1.0) < 0.01

## 获取指标权重字典
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

## 获取场景权重字典
func get_scenario_weights() -> Dictionary:
	return {
		ScenarioType.SINGLE_TARGET: weight_single_target,
		ScenarioType.MULTI_TARGET: weight_multi_target,
		ScenarioType.HIGH_MOBILITY: weight_high_mobility,
		ScenarioType.SURVIVAL: weight_survival,
		ScenarioType.CLOSE_RANGE: weight_close_range
	}

## 创建默认配置
static func create_default() -> FitnessConfig:
	var config = FitnessConfig.new()
	return config

## 创建偏向AOE的配置
static func create_aoe_focused() -> FitnessConfig:
	var config = FitnessConfig.new()
	config.weight_single_target = 0.10
	config.weight_multi_target = 0.45
	config.weight_high_mobility = 0.15
	config.weight_survival = 0.15
	config.weight_close_range = 0.15
	return config

## 创建偏向单体的配置
static func create_single_target_focused() -> FitnessConfig:
	var config = FitnessConfig.new()
	config.weight_single_target = 0.45
	config.weight_multi_target = 0.15
	config.weight_high_mobility = 0.15
	config.weight_survival = 0.15
	config.weight_close_range = 0.10
	return config

## 创建偏向华丽效果的配置（新增）
static func create_flashy_focused() -> FitnessConfig:
	var config = FitnessConfig.new()
	config.weight_damage = 0.15
	config.weight_complexity = 0.25
	config.complexity_bonus_fission = 25.0
	config.complexity_bonus_combo = 30.0
	return config

## 创建偏向近战的配置（新增）
static func create_close_range_focused() -> FitnessConfig:
	var config = FitnessConfig.new()
	config.weight_single_target = 0.15
	config.weight_multi_target = 0.15
	config.weight_high_mobility = 0.15
	config.weight_survival = 0.20
	config.weight_close_range = 0.35
	return config

## 创建平衡多样性的配置（新增）
static func create_diversity_focused() -> FitnessConfig:
	var config = FitnessConfig.new()
	config.diversity_weight = 0.2
	config.similarity_penalty = 0.3
	config.weight_damage = 0.15
	config.weight_complexity = 0.20
	return config
