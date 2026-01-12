# 灵子项目 - 敌人AI系统设计文档

**版本:** 1.0
**日期:** 2026-01-12
**作者:** Manus AI

## 1. 概述

本文档旨在为“灵子拓扑构筑系统”项目设计一套完整、可扩展的敌人AI系统。该系统将深度集成项目现有的战斗机制，包括状态机、数据驱动的攻击模式以及核心的“二维体素肢体战斗系统”，旨在创造出行为丰富、战术多变且易于扩展的敌人角色。

## 2. 设计目标

- **模块化与可扩展性:** AI系统应采用高内聚、低耦合的设计，方便策划通过创建新的数据资源（`Resource`）来定义全新的敌人行为模式，而无需修改核心代码。
- **战术深度:** AI应能理解并利用游戏的核心战斗机制，特别是“二维体素肢体系统”，能够根据战术意图（如削弱玩家移动能力、打断施法）选择性地攻击特定肢体。
- **性能优化:** AI系统需在保证功能的前提下，注重性能效率，避免在同屏敌人数量较多时引起性能问题。
- **与现有系统统一:** AI的行为管理将复用并扩展现有的状态机（`StateMachine`）架构，与玩家角色的实现方式保持一致性，降低项目维护成本。

## 3. 核心架构

我们将为敌人引入一套与玩家类似的、由状态机驱动的控制架构。每个敌人将由一个核心的 `EnemyAIController` 节点进行管理，并通过数据驱动的 `AIBehaviorProfile` 资源来定义其独特的行为模式。

### 3.1. 场景与节点结构

创建一个基础敌人场景 `base_enemy.tscn`，所有具体的敌人类型都将继承自该场景。

```
- EnemyAIController (CharacterBody2D) # 根节点，挂载 enemy_ai_controller.gd
  - CollisionShape2D
  - Visuals (Node2D)                  # 视觉根节点，包含模型、VFX等
    - Sprite2D / Skeleton2D
  - StateMachine (Node)               # 状态机管理器，与玩家共用
    - IdleState (State)
    - PatrolState (State)
    - ChaseState (State)
    - AttackState (State)
    - FleeState (State)
    - UseSkillState (State)
  - Perception (Area2D)               # 感知系统，用于探测玩家
    - CollisionShape2D
  - TargetSelector (Node)             # 目标选择器，用于决策攻击目标
  - HealthBar (ProgressBar)
```

### 3.2. 核心脚本与数据资源

#### `enemy_ai_controller.gd`

作为敌人的“大脑”，该脚本负责：
- 初始化并管理状态机。
- 持有并应用 `AIBehaviorProfile` 定义的行为参数。
- 接收 `Perception` 系统传来的感知信息（如玩家进入/离开视野）。
- 管理敌人的核心状态，如能量系统（`EnergySystemData`）、肢体数据（`BodyPartData`）等。
- 提供供状态节点调用的核心API，如移动、旋转、攻击执行等。
- 复用 `player_controller.gd` 中的 `take_damage` 逻辑，响应来自玩家的攻击。

#### `AIBehaviorProfile.gd` (Resource)

这是一个新的 `Resource` 类型，用于定义敌人的“性格”和战术偏好，是实现AI多样性的关键。

```gdscript
class_name AIBehaviorProfile extends Resource

@export_group("感知与索敌")
@export var perception_radius: float = 500.0  # 索敌范围
@export var line_of_sight_required: bool = true # 是否需要视线
@export var memory_duration: float = 5.0      # 丢失目标后保持追击的时间

@export_group("移动与站位")
@export var engagement_distance: float = 150.0 # 进入战斗的最佳距离
@export var disengage_distance: float = 50.0   # 与目标保持的最小距离
@export var max_chase_distance: float = 1000.0 # 最大追击距离
@export var flee_health_threshold: float = 0.2 # 当生命值低于此百分比时尝试逃跑

@export_group("攻击性")
@export var aggression: float = 0.8 # 攻击欲望 (0-1)，影响攻击频率
@export var attack_cooldown: float = 2.0 # 基础攻击冷却时间

@export_group("技能使用")
@export var skill_usage_rules: Array[AISkillRule] # 技能使用规则

@export_group("肢体目标策略")
@export var targeting_priorities: Array[AITargetingPriority] # 肢体攻击优先级
```

#### `AITargetingPriority.gd` (Resource)

定义了攻击玩家特定肢体的优先级和条件。

```gdscript
class_name AITargetingPriority extends Resource

@export var part_type: BodyPartData.PartType # 目标肢体类型
@export var priority_score: float = 1.0      # 基础优先级分数

@export_group("动态权重调节")
@export var player_is_casting_bonus: float = 0.0 # 当玩家正在施法时，攻击此部位的额外加分（如攻击手部打断施法）
@export var player_is_moving_bonus: float = 0.0  # 当玩家正在移动时，攻击此部位的额外加分（如攻击腿部减速）
@export var part_is_damaged_bonus: float = 0.0   # 当此部位已受伤时，追击的额外加分
```

## 4. AI行为状态机

敌人AI将使用一套专门的状态来管理其行为。

- **`IdleState` (空闲):** 默认状态，执行原地待机动画或行为。
- **`PatrolState` (巡逻):** 在预设的路径点之间来回移动。
- **`ChaseState` (追击):** 当感知到玩家后，向玩家移动，试图进入最佳攻击距离（`engagement_distance`）。
- **`AttackState` (攻击):** 当与玩家的距离在攻击范围内时，执行攻击。攻击逻辑将与玩家类似，包含前摇、攻击、后摇阶段。攻击时会调用 `TargetSelector` 来决定具体攻击哪个肢体。
- **`FleeState` (逃跑):** 当满足特定条件时（如生命值过低），尝试远离玩家。
- **`UseSkillState` (使用技能):** 根据 `AIBehaviorProfile` 中的规则决定是否使用特殊技能。

## 5. 核心子系统设计

### 5.1. 感知系统 (`Perception`)

- 使用一个 `Area2D` 节点来定义敌人的感知范围。
- 当玩家的 `CharacterBody2D` 进入或离开该区域时，发出信号通知 `EnemyAIController`。
- 可选的射线检测（`RayCast2D`）用于判断玩家是否在视线范围内，实现更真实的索敌逻辑。

### 5.2. 目标选择器 (`TargetSelector`)

这是实现战术深度的核心模块。当 `AttackState` 请求攻击时，`TargetSelector` 将执行以下操作：

1.  获取玩家所有肢体（`BodyPartData`）的当前状态（生命值、是否正在施法等）。
2.  遍历 `AIBehaviorProfile` 中定义的所有 `AITargetingPriority` 规则。
3.  根据当前战局，为每个肢体计算一个“威胁度”或“优先级”分数。
    > 例如：如果玩家正在施法，则“右手”和“左手”的优先级分数会根据 `player_is_casting_bonus` 增加。
4.  选择得分最高的肢体作为本次攻击的目标，并将该肢体的 `PartType` 传递给攻击执行逻辑。

## 6. 开发步骤规划

1.  **创建基础资源:** 创建 `AIBehaviorProfile.gd`, `AITargetingPriority.gd` 等新的 `Resource` 脚本。
2.  **构建基础场景:** 搭建 `base_enemy.tscn` 场景，包含完整的节点结构。
3.  **开发AI控制器:** 编写 `enemy_ai_controller.gd`，实现状态机管理和基础的移动、承伤逻辑。
4.  **实现AI状态:** 逐一实现 `Idle`, `Patrol`, `Chase`, `Attack` 等核心状态脚本。
5.  **开发目标选择器:** 实现 `TargetSelector` 脚本，完成基于规则的肢体目标选择逻辑。
6.  **创建测试敌人:** 创建一个或多个继承自 `base_enemy.tscn` 的具体敌人，并为其创建对应的 `AIBehaviorProfile.tres` 配置文件。
7.  **测试与迭代:** 在测试场景中放置新敌人，全面测试其行为、攻击模式和肢体目标选择的有效性，并根据测试结果调整AI参数。

通过以上设计，我们将构建一个既强大又灵活的AI系统，能够充分利用现有战斗系统的深度，为玩家提供富有挑战和乐趣的战斗体验。


## 7. 使用说明

敌人AI系统已经完成基础代码的编写，并已集成到项目中。以下是如何在项目中使用和扩展此AI系统的说明。

### 7.1. 创建新敌人

1.  **继承基础场景:** 在Godot编辑器中，右键点击 `scenes/enemies/base_enemy.tscn`，选择“新建继承场景”。
2.  **自定义视觉效果:** 在新创建的场景中，你可以修改 `Visuals` 节点下的内容，例如替换 `Polygon2D` 为一个 `Sprite2D` 或 `AnimatedSprite2D` 来定义敌人的外观。
3.  **配置AI行为:** 在 `EnemyAIController` 节点的 `Inspector` 面板中，为其分配一个 `AIBehaviorProfile` 资源。你可以：
    *   点击 `Behavior Profile` 属性旁的 `[空]`，选择“新建 AIBehaviorProfile”。
    *   在新建的资源中，可以从预设的 `Archetype`（如 `MELEE_AGGRESSIVE`, `RANGED_SNIPER`）中选择一个作为模板，然后微调各项参数。
    *   为了方便复用，建议将配置好的 `AIBehaviorProfile` 保存为 `.tres` 文件（例如 `resources/ai/profiles/grunt_profile.tres`）。
4.  **配置战斗属性:**
    *   **能量系统 (`Energy System`):** 创建或复用一个 `EnergySystemData` 资源来定义敌人的生命值、护盾等。
    *   **武器 (`Weapon Data`):** 创建或复用一个 `WeaponData` 资源来定义敌人的攻击方式、伤害和范围。
5.  **保存场景:** 将新敌人场景保存在 `scenes/enemies/` 目录下（例如 `scenes/enemies/grunt.tscn`）。

### 7.2. 在关卡中放置敌人

- **手动放置:** 直接将创建好的敌人场景文件（如 `grunt.tscn`）拖拽到你的关卡场景中。
- **通过 `EnemyManager` 动态生成:**
    1.  在你的关卡场景中添加一个 `EnemyManager` 节点（脚本位于 `scripts/ai/enemy_manager.gd`）。
    2.  在 `Inspector` 中，将你的敌人场景（`grunt.tscn` 等）添加到 `Enemy Prefabs` 数组中。
    3.  你可以设置 `Max Enemies`（最大敌人数量）和 `Spawn Interval`（生成间隔），并勾选 `Auto Spawn` 来让管理器自动在随机位置生成敌人。
    4.  你也可以在代码中调用 `enemy_manager.spawn_enemy(prefab, position)` 来在指定位置生成特定敌人。

### 7.3. 扩展AI行为

- **创建新的AI原型 (`Archetype`):**
    - 打开 `resources/ai/ai_behavior_profile.gd`。
    - 在 `AIArchetype` 枚举中添加新的原型名称。
    - 在该文件中添加一个新的静态函数，例如 `create_new_archetype()`，用于生成该原型的默认配置。这使得策划可以在编辑器中快速选择和创建新类型的AI。
- **添加新的肢体目标策略:**
    - 创建一个新的 `AITargetingPriority` 资源。
    - 在其中定义你想要攻击的 `Part Type`（肢体类型）和各种条件下的 `Bonus`（加分）。
    - 将这个新的优先级资源添加到 `AIBehaviorProfile` 的 `Targeting Priorities` 数组中。
- **添加新的技能:**
    - 创建一个新的 `AISkillRule` 资源。
    - 关联一个 `SpellCoreData` 作为技能效果。
    - 定义技能的使用条件（`Condition`）和阈值（`Threshold`）。
    - 将这个技能规则添加到 `AIBehaviorProfile` 的 `Skill Usage Rules` 数组中。

### 7.4. 调试与可视化

- 每个基础敌人场景都包含一个 `AIDebugVisualizer` 节点。
- 在编辑器中选中敌人，或者在运行时，你可以在 `Inspector` 中勾选 `Enabled` 来开启调试视图。
- 你可以分别控制是否显示感知范围、攻击范围、目标连线、状态标签等信息，方便直观地调试AI的行为。
