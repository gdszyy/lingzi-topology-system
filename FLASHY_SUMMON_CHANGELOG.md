# 华丽张力效果奖励机制与召唤实体类型支持

## 概述

本次更新为 lingzi-topology-system 项目的遗传算法添加了两个重要功能：

1. **华丽张力表演效果奖励机制**：在法术适应度评估中略微奖励具有视觉华丽效果的法术
2. **召唤实体类型支持**：将所有最新的召唤实体类型纳入遗传算法的生成和评估体系

---

## 修改文件清单

| 文件 | 修改类型 | 说明 |
|------|----------|------|
| `scripts/evaluation/fitness_config.gd` | 新增配置 | 添加华丽效果和召唤系统的奖励参数 |
| `scripts/evaluation/fitness_calculator.gd` | 新增函数 | 实现华丽效果和召唤系统评分逻辑 |
| `scripts/core/spell_factory.gd` | 扩展功能 | 添加召唤和链式动作的生成函数 |
| `scripts/genetic_algorithm/genetic_operators.gd` | 扩展功能 | 添加召唤和链式动作的变异处理 |

---

## 华丽张力效果奖励机制

### 新增配置参数 (`fitness_config.gd`)

```gdscript
@export_group("华丽张力效果奖励")
@export var weight_flashy: float = 0.08          # 华丽效果权重
@export var flashy_chain_bonus: float = 12.0     # 链式效果奖励
@export var flashy_chain_fork_bonus: float = 8.0 # 链式分叉额外奖励
@export var flashy_summon_bonus: float = 10.0    # 召唤效果奖励
@export var flashy_orbiter_bonus: float = 15.0   # 环绕体召唤额外奖励
@export var flashy_multi_fission_bonus: float = 5.0  # 多重裂变奖励
@export var flashy_explosion_bonus: float = 8.0  # 爆炸效果奖励
@export var flashy_aoe_scale_bonus: float = 0.05 # 大范围AOE奖励
@export var flashy_plasma_phase_bonus: float = 6.0   # 等离子相态奖励
@export var flashy_homing_visual_bonus: float = 4.0  # 追踪效果奖励
@export var flashy_combo_multiplier: float = 1.5 # 多种华丽效果组合乘数
@export var max_flashy_bonus: float = 80.0       # 华丽效果奖励上限
```

### 华丽效果评分逻辑 (`fitness_calculator.gd`)

新增 `calculate_flashy_score()` 函数，评估以下视觉华丽元素：

| 华丽元素 | 奖励说明 |
|----------|----------|
| **等离子相态** | 视觉效果最华丽的载体相态 |
| **追踪效果** | 追踪弹道增加动态视觉效果 |
| **链式效果** | 闪电链、火焰链等视觉冲击力强 |
| **链式分叉** | 分叉的链式效果更加壮观 |
| **召唤效果** | 场面丰富，特别是环绕体 |
| **裂变效果** | 弹幕张力，多重裂变更佳 |
| **爆炸效果** | 大爆炸视觉冲击强烈 |
| **大范围AOE** | 范围超过80的AOE效果 |
| **效果组合** | 多种华丽效果组合获得乘数加成 |

---

## 召唤实体类型支持

### 支持的召唤类型

| 类型 | 枚举值 | 说明 | 特殊参数 |
|------|--------|------|----------|
| **TURRET** | 0 | 炮塔 | 固定位置，远程攻击 |
| **MINION** | 1 | 仆从 | 可移动，主动攻击 |
| **ORBITER** | 2 | 环绕体 | 围绕玩家旋转，视觉华丽 |
| **DECOY** | 3 | 诱饵 | 吸引敌人仇恨 |
| **BARRIER** | 4 | 屏障 | 提供防护 |
| **TOTEM** | 5 | 图腾 | 范围效果，周期性触发 |

### 召唤系统奖励配置

```gdscript
@export_group("召唤系统奖励")
@export var summon_base_bonus: float = 8.0       # 召唤基础奖励
@export var summon_turret_bonus: float = 6.0     # 炮塔召唤奖励
@export var summon_minion_bonus: float = 8.0     # 仆从召唤奖励
@export var summon_orbiter_bonus: float = 12.0   # 环绕体召唤奖励
@export var summon_decoy_bonus: float = 5.0      # 诱饵召唤奖励
@export var summon_barrier_bonus: float = 7.0    # 屏障召唤奖励
@export var summon_totem_bonus: float = 10.0     # 图腾召唤奖励
@export var summon_count_bonus: float = 3.0      # 每个额外召唤物奖励
@export var summon_inherit_spell_bonus: float = 15.0  # 继承法术奖励
@export var cost_per_summon: float = 3.0         # 每个召唤物的cost
```

---

## 遗传算法扩展

### 法术生成 (`spell_factory.gd`)

新增两个动作生成函数：

- `_generate_summon_action()`: 生成召唤动作，支持所有6种召唤类型
- `_generate_chain_action()`: 生成链式动作，支持分叉效果

动作类型扩展为8种（原6种 + 召唤 + 链式）。

### 遗传变异 (`genetic_operators.gd`)

新增变异处理：

- **召唤动作变异**：类型、行为模式、数量、持续时间、生命值、伤害等
- **环绕体特殊变异**：轨道半径、旋转速度
- **图腾特殊变异**：效果半径、效果间隔
- **链式动作变异**：链式类型、数量、范围、伤害、衰减
- **分叉变异**：增加或调整分叉概率和数量

---

## 使用建议

### 创建华丽效果导向的配置

```gdscript
# 使用预设的华丽效果配置
var flashy_config = FitnessConfig.create_flashy_focused()

# 或手动调整权重
var config = FitnessConfig.new()
config.weight_flashy = 0.15  # 增加华丽效果权重
config.flashy_combo_multiplier = 2.0  # 增强组合奖励
```

### 评估法术的华丽程度

```gdscript
var calculator = FitnessCalculator.new(config)
var flashy_score = calculator.calculate_flashy_score(spell)
var summon_score = calculator.calculate_summon_score(spell)
var details = calculator.get_evaluation_details(spell)
print("华丽分数: ", details.flashy_score)
print("召唤分数: ", details.summon_score)
```

---

## 提交信息

```
feat: 添加华丽张力效果奖励机制和召唤实体类型支持
Commit: 73cf802
```
