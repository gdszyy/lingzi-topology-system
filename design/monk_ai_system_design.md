# 修士 AI 系统设计文档

## 1. 概述

本文档旨在为 `lingzi-topology-system` 项目设计一个全新的“修士”AI 系统。该系统的目标是创建一个能力与玩家角色相当的 AI，能够使用与玩家相同的战斗机制，包括能量系统、法术拓扑和肢体刻印系统。此外，该系统需要支持多个修士 AI 之间的协作，实现复杂的团队战术和混战场景。

## 2. 核心设计原则

- **对等性 (Parity with Player):** 修士 AI 的核心能力应与玩家对等，使用相同的组件和资源，如 `EnergySystemData`, `EngravingManager`, 和 `SpellCoreData`。这确保了 AI 行为的复杂性和可扩展性，并能复用现有的战斗逻辑。
- **模块化 (Modularity):** AI 的行为、决策和战斗风格应通过数据驱动的配置文件（如 `MonkBehaviorProfile`）进行定义，而不是硬编码在控制器中。这使得创建不同“性格”和战tactic的修士 AI 变得容易。
- **协作性 (Collaboration):** 系统需要包含一个团队管理器 (`TeamManager`) 和相应的通信机制，使多个修士 AI 能够共享信息、协调行动，并执行团队战术。
- **可扩展性 (Extensibility):** 整体架构应易于扩展，方便未来添加新的 AI 行为、战术角色和协作策略。

## 3. 系统架构

修士 AI 系统将由以下几个关键组件构成：

| 组件 | 基类/类型 | 文件路径 | 描述 |
| --- | --- | --- | --- |
| **修士 AI 控制器** | `CharacterBody2D` | `scripts/ai/monk_ai_controller.gd` | AI 的主控制脚本，整合所有其他组件，是 AI 的“身体”和“大脑”的连接点。 |
| **修士行为配置** | `AIBehaviorProfile` | `resources/ai/monk_behavior_profile.gd` | 数据驱动的资源，定义修士 AI 的“性格”、战术偏好、技能组合和团队角色。 |
| **刻印管理器** | `EngravingManager` | (复用) `scripts/combat/engraving_manager.gd` | 每个修士 AI 实例将拥有独立的刻印管理器，使其能像玩家一样使用复杂的法术组合。 |
| **能量系统** | `EnergySystemData` | (复用) `resources/combat/energy_system_data.gd` | 管理 AI 的能量上限（生命）和当前能量（法力），与玩家机制完全相同。 |
| **AI 状态机** | `StateMachine` | (复用) `scripts/combat/state_machine/state_machine.gd` | 管理 AI 的行为状态，将引入更复杂的、类似玩家的状态（如修炼、策略性走位）。 |
| **团队管理器** | `Node` | `scripts/ai/team_manager.gd` | 负责管理一个 AI 团队，分配角色，共享目标信息，并协调战术。 |
| **战术协调器** | `Resource` | `resources/ai/tactical_coordinator.gd` | 作为 `TeamManager` 的一部分，根据战场情况动态调整团队的宏观战术。 |

### 3.1. `MonkAIController` (修士 AI 控制器)

这是修士 AI 的核心。它将继承自 `CharacterBody2D`，并包含以下关键成员：

- `state_machine: StateMachine`: 管理 AI 的行为状态。
- `energy_system: EnergySystemData`: 管理生命和法力。
- `engraving_manager: EngravingManager`: 管理法术和技能。
- `perception: PerceptionSystem`: 感知周围环境，发现敌人和盟友。
- `target_selector: TargetSelector`: 根据战术选择最优目标。
- `behavior_profile: MonkBehaviorProfile`: 当前 AI 的行为配置。
- `team_id: int`: 所属团队的 ID。
- `team_manager: TeamManager`: 对所属团队管理器的引用。

它将负责将所有组件连接在一起，并在 `_physics_process` 中驱动状态机和移动。

### 3.2. `MonkBehaviorProfile` (修士行为配置)

该资源将扩展现有的 `AIBehaviorProfile`，增加修士特有的配置选项：

- `spell_loadout: Array[SpellCoreData]`: 该 AI 出生时携带的法术列表，用于初始化 `EngravingManager`。
- `engraving_strategy: Dictionary`: 定义如何将 `spell_loadout` 中的法术刻印到不同的身体部位和武器上。
- `cultivation_threshold: float`: 当能量上限低于此百分比时，优先寻找机会进行修炼恢复。
- `team_role: TeamRole` (enum): 定义 AI 在团队中的角色，如 `ATTACKER`, `DEFENDER`, `SUPPORT`。
- `combat_positioning: PositioningStyle` (enum): 定义战斗中的走位风格，如 `CLOSE_QUARTERS`, `KITING`, `FLANKING`。

### 3.3. `TeamManager` (团队管理器) 与协作机制

为了实现多人混战，需要引入团队的概念。

- **`TeamManager`**: 这是一个场景节点，负责管理一个团队的所有修士 AI。它会维护一个成员列表，并为每个成员分配角色。它还负责信息共享，例如将一个成员发现的敌人广播给所有团队成员。
- **`TacticalCoordinator`**: 这是 `TeamManager` 内部的一个模块，它会根据战场态势（如敌我数量对比、关键目标状态等）决定整个团队的宏观战术，例如“集火关键目标”、“分散拉扯”或“战略性撤退”。
- **AI 间通信**: AI 之间的通信通过 `TeamManager` 中转。例如，一个 AI 可以向 `TeamManager` 请求援助，`TeamManager` 会根据战术和角色分配，指令其他 AI 前往支援。

## 4. 状态机设计

修士 AI 的状态机将比普通敌人更复杂，以支持类似玩家的决策。除了基本的 `Idle`, `Chase`, `Attack` 状态外，还将引入：

- **`CultivateState` (修炼状态):** 在安全时（如脱离战斗），AI 会进入此状态，使用“修炼”技能恢复损失的能量上限。
- **`RepositionState` (走位状态):** AI 会根据其 `combat_positioning` 风格和战场情况，动态调整自己的位置，而不是简单地冲向敌人。例如，远程 AI 会试图与敌人保持距离，而侧翼 AI 会尝试绕到敌人背后。
- **`TeamActionState` (团队行动状态):** AI 在此状态下执行由 `TeamManager` 指派的宏观指令，如集火特定目标或保护某个盟友。
- **`UseSpellState` (法术状态):** 类似于现有的 `AIUseSkillState`，但会与 `EngravingManager` 深度集成，能够根据 `AISkillRule` 触发复杂的刻印法术组合。

## 5. 实现步骤

1.  **创建 `MonkAIController`:** 创建 `monk_ai_controller.gd` 文件，并设置好所有必要的节点和组件引用。
2.  **扩展行为配置:** 创建 `monk_behavior_profile.gd` 并添加新的修士专属属性。
3.  **实现状态机:** 创建新的状态脚本 (`CultivateState`, `RepositionState`, `TeamActionState`) 并集成到 `MonkAIController` 的状态机中。
4.  **集成 `EngravingManager`:** 在 `MonkAIController` 的 `_ready` 函数中实例化并初始化 `EngravingManager`，并根据 `MonkBehaviorProfile` 中的配置来刻印初始法术。
5.  **创建 `TeamManager`:** 创建 `team_manager.gd` 和 `tactical_coordinator.gd`，实现团队管理、角色分配和基本的信息共享功能。
6.  **连接协作逻辑:** 在 `MonkAIController` 中实现与 `TeamManager` 的交互逻辑，使其能够接收和执行团队指令。
7.  **创建测试场景:** 修改 `ai_arena_scene.tscn` 或创建一个新场景，用于测试单个修士 AI 的行为以及多个 AI 团队之间的混战。

通过以上设计，我们将能构建一个强大、灵活且具备团队协作能力的修士 AI 系统，极大地丰富游戏的战斗体验。
