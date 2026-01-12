# 灵子拓扑构筑系统 - 功能索引与说明

本文档旨在提供一个清晰、全面的功能索引，帮助开发者快速理解“灵子拓扑构筑系统”的各项核心功能、数据结构及其相互关系。

## 一、核心系统概述

系统整体架构围绕着**法术的生成、评估与执行**三大环节，并辅以一个全新的**角色战斗框架**。所有系统都遵循数据驱动的设计原则，高度模块化。

| 核心系统 | 主要功能 | 关键脚本/目录 |
| :--- | :--- | :--- |
| **法术构筑系统** | 定义法术的数据结构，是整个系统的基石。 | `resources/spell_data/` |
| **遗传算法系统** | 通过进化算法自动生成和优化法术。 | `scripts/genetic_algorithm/` |
| **法术评估系统** | 在模拟环境中测试法术性能，计算其适应度。 | `scripts/evaluation/` |
| **运行时效果系统** | 统一管理护盾、召唤、链式等复杂的实时法术效果。 | `scripts/runtime/` |
| **角色战斗系统** | 实现了玩家角色的移动、攻击和法术刻录功能。 | `scripts/combat/` |
| **法术工厂** | 负责根据规则随机或按场景生成法术实例。 | `scripts/core/` |

## 二、法术生命周期

一个法术从诞生到最终在战斗中呈现效果，主要经历以下流程：

1.  **生成 (Generation)**: `GeneticAlgorithmManager` 或 `BatchSpellGenerator` 调用 `SpellFactory` 或 `ScenarioSpellGenerator`，创建出符合特定规则的 `SpellCoreData` 对象作为初始种群。
2.  **进化 (Evolution)**: 在遗传算法的主循环中，通过 `SelectionMethods`（选择）、`GeneticOperators`（交叉与变异）对法术种群进行迭代优化。
3.  **评估 (Evaluation)**: 在每一代进化中，`EvaluationManager` 和 `FitnessCalculator` 会对每个法术的各项指标（伤害、效率、复杂度等）进行量化评估，得出适应度分数。
4.  **执行 (Execution)**: 在战斗场景中，法术通过两种方式被执行：
    *   **主动施放**: 玩家通过 `PlayerController` 施法，生成一个 `Projectile` (投射物) 实例，该实例根据其内部的拓扑规则行动。
    *   **被动刻录**: `EngravingManager` 监听玩家的战斗行为（如攻击、格挡），当行为满足刻录在装备上的法术触发条件时，直接通过 `ActionExecutor` 执行其效果。
5.  **效果呈现**: 无论是投射物还是刻录效果，最终的复杂行为（如召唤、护盾、链式攻击）都被委托给 `RuntimeSystemsManager` 进行统一处理，确保逻辑一致性。

## 三、核心数据结构 API

系统的核心是其数据驱动的设计。理解这些核心 `Resource` 是理解整个系统的关键。

### 1. `SpellCoreData` - 法术核心

这是定义一个完整法术的顶层数据结构。

| 属性 | 类型 | 描述 |
| :--- | :--- | :--- |
| `spell_name` | `String` | 法术的名称。 |
| `spell_type` | `enum` | 法术类型，分为 `PROJECTILE` (投射物)、`ENGRAVING` (刻录)、`HYBRID` (混合)。 |
| `carrier` | `CarrierConfigData` | **【投射物核心】**定义法术载体的物理属性。仅对投射物法术有效。 |
| `topology_rules` | `Array[TopologyRuleData]` | **【逻辑核心】**定义法术的“触发-效果”规则列表。 |
| `resource_cost` | `float` | 施放该法术需要消耗的资源。 |
| `cooldown` | `float` | 施法冷却时间。 |

### 2. `TopologyRuleData` - 拓扑规则

“当满足某个条件时，执行一系列效果”——这是构成法术逻辑的基本单元。

| 属性 | 类型 | 描述 |
| :--- | :--- | :--- |
| `trigger` | `TriggerData` | **触发器**：定义了规则被触发的条件。 |
| `actions` | `Array[ActionData]` | **动作列表**：定义了触发后需要执行的一个或多个效果。 |

### 3. `TriggerData` - 触发器

定义了“**何时**”触发法术效果。触发器被分为两大类：投射物触发器和刻录触发器。

| 分类 | 示例 | 描述 |
| :--- | :--- | :--- |
| **投射物触发器** | `ON_CONTACT`, `ON_TIMER`, `ON_DEATH` | 与法术载体（子弹）的生命周期和事件绑定。 |
| **刻录触发器** | `ON_WEAPON_HIT`, `ON_DODGE_SUCCESS`, `ON_TAKE_DAMAGE` | 与玩家角色的战斗行为绑定，用于法术刻录系统。 |

*完整列表请参见 `resources/triggers/trigger_data.gd`*。

### 4. `ActionData` - 效果动作

定义了“**做什么**”。每个动作都是一个独立的 `Resource`，拥有各自的属性。

| 动作类型 (`ActionType`) | 描述 | 关键属性 |
| :--- | :--- | :--- |
| `DAMAGE` | 对目标造成直接伤害。 | `damage_value`, `damage_type` |
| `FISSION` | 分裂，生成多个子法术。 | `spawn_count`, `spread_angle`, `child_spell_data` |
| `APPLY_STATUS` | 对目标施加状态效果（如燃烧、冰冻）。 | `status_type`, `duration`, `effect_value` |
| `SHIELD` | 为目标创建护盾。 | `shield_amount`, `shield_duration` |
| `SUMMON` | 召唤一个或多个实体（如炮塔、仆从）。 | `summon_type`, `summon_count`, `summon_duration` |
| `CHAIN` | 产生在多个目标间跳跃的链式效果。 | `chain_count`, `chain_range`, `chain_damage` |
| `DISPLACEMENT` | 对目标产生位移（如击退、吸引）。 | `displacement_type`, `displacement_force` |
| `REFLECT` | 为目标提供反弹投射物或伤害的能力。 | `reflect_type`, `reflect_duration` |

*完整列表请参见 `resources/actions/action_data.gd`*。

## 四、文档结构索引

为了方便查阅，所有项目文档已按类别重新组织。

| 路径 | 内容说明 |
| :--- | :--- |
| `README.md` | 项目的入口，提供高级概述和快速上手指南。 |
| `docs/feature_index.md` | **[本文档]** 提供详细的功能、API和系统工作流程说明。 |
| `docs/design/` | 存放系统的核心设计理念与评估文档，帮助理解“为什么”这么设计。 |
| `docs/development/` | 存放具体模块的架构设计文档，用于指导开发。 |
| `docs/archive/` | 存放历史的变更日志（Changelog），用于追溯版本迭代。 |
| `docs/api/` | **[规划中]** 用于存放未来自动生成的代码级API文档。 |
