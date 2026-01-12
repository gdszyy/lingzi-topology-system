# 角色战斗系统 - 法术刻录模块架构设计

**版本: 1.0**

**作者: Manus AI**

## 1. 概述

本文档旨在为“灵子拓扑系统”项目设计一个法术刻录（Spell Engraving）模块。该模块的核心目标是允许玩家将现有的法术拓扑规则刻录到角色的肢体或武器上，从而在特定战斗行为（如攻击、格挡、移动）发生时，触发这些法术效果。这将深度融合项目原有的法术构筑系统与新增的角色战斗系统，创造更丰富的玩法。

## 2. 核心概念

法术刻录系统的核心思想是**“将法术的触发-效果逻辑（TopologyRule）从投射物（Carrier）中剥离，并附加到角色或装备上”**。

| 核心概念 | 描述 |
| :--- | :--- |
| **肢体部件 (BodyPart)** | 代表角色身体的不同部分，如头、躯干、左臂、右臂、腿。每个部件都是一个独立的实体，可以作为法术刻d录的载体。 |
| **刻录槽 (EngravingSlot)** | 存在于肢体部件和武器上的特定“插槽”。一个刻录槽可以容纳一个完整的`SpellCoreData`。 |
| **刻录法术 (EngravedSpell)** | 当一个法术被刻录时，我们主要关注其`TopologyRuleData`（拓扑规则），即“在什么条件下，发生什么事”。法术的`CarrierConfigData`（载体配置）在大多数情况下会被忽略，因为效果是直接作用于角色或由角色发出的。 |
| **触发器映射 (TriggerMapping)** | 这是系统的关键。我们需要将法术中定义的通用触发器（如`ON_CONTACT`）映射到角色具体的战斗行为上。例如，刻录在武器上的`ON_CONTACT`法术，其触发条件会被解释为“当该武器击中敌人时”。 |

## 3. 系统架构设计

为了实现上述功能，我们将引入以下新的数据结构和管理器。

### 3.1. 数据结构

#### 3.1.1. `BodyPart.gd` (肢体部件)

这是一个新的节点类，将作为玩家场景中各个肢体（如手臂、腿）的基类。

```gdscript
# BodyPart.gd
class_name BodyPart extends Node2D

enum PartType { HEAD, TORSO, LEFT_ARM, RIGHT_ARM, LEGS }

@export var part_type: PartType
@export var engraving_slots: Array[EngravingSlot] = []

# ... 其他肢体相关逻辑，如生命值、护甲等
```

#### 3.1.2. `EngravingSlot.gd` (刻录槽)

这是一个新的资源类，用于定义一个可用的刻录位置。

```gdscript
# EngravingSlot.gd
class_name EngravingSlot extends Resource

## 刻录的法术
@export var engraved_spell: SpellCoreData = null

## 槽位是否锁定
@export var is_locked: bool = false

## 槽位激活的触发器类型
@export var allowed_triggers: Array[TriggerData.TriggerType] = []
```

#### 3.1.3. `WeaponData.gd` (扩展)

我们需要在现有的`WeaponData`资源中添加刻录槽。

```gdscript
# In WeaponData.gd
# ... (existing properties)

@export var engraving_slots: Array[EngravingSlot] = []
```

#### 3.1.4. `TriggerData.gd` (扩展)

为了支持刻录系统，我们需要在`TriggerData.TriggerType`枚举中添加更多与角色行为相关的触发器。

```gdscript
# In TriggerData.gd -> enum TriggerType

# ... (existing triggers)

# --- Engraving Triggers ---
ON_WEAPON_HIT,          # 武器命中时
ON_ATTACK_START,        # 攻击开始时
ON_ATTACK_END,          # 攻击结束时 (进入Recovery状态)
ON_BLOCK_SUCCESS,       # 成功格挡时
ON_DODGE_SUCCESS,       # 成功闪避时
ON_TAKE_DAMAGE,         # 受到伤害时
ON_DEAL_DAMAGE,         # 造成伤害时 (任何来源)
ON_FLY_START,           # 开始飞行时
ON_LAND,                # 结束飞行，落地时
ON_JUMP,                # 跳跃时 (如果未来加入)
```

### 3.2. 核心管理器

#### 3.2.1. `EngravingManager.gd` (刻录管理器)

这是刻录系统的核心中枢，将作为`PlayerController`的一个子节点。它负责管理所有刻录槽、监听玩家事件，并触发相应的法术效果。

**主要职责:**

1.  **注册与注销：** 在玩家初始化时，收集所有来自肢体部件和当前武器的刻录槽。
2.  **事件监听：** 连接`PlayerController`和`WeaponManager`的各种信号（如`attack_hit`, `state_changed`, `took_damage`等）。
3.  **触发器分发：** 当监听到一个事件时（例如，玩家成功击中敌人），`EngravingManager`会遍历所有已注册的刻る槽。如果槽中的法术包含与该事件匹配的触发器（如`ON_WEAPON_HIT`），则执行该法术的`Action`列表。
4.  **效果执行：** `EngravingManager`将调用一个`ActionExecutor`来执行法术效果。与发射投射物不同，这些效果通常是瞬时的，直接作用于玩家、敌人或周围环境（例如，在玩家脚下生成一个伤害区域，或为玩家自身施加一个护盾）。

**伪代码示例:**

```gdscript
# EngravingManager.gd

func _ready():
    player.attack_hit.connect(_on_player_attack_hit)
    player.took_damage.connect(_on_player_took_damage)
    # ... connect other signals

func _on_player_attack_hit(target, damage_info):
    # 分发 ON_WEAPON_HIT 和 ON_DEAL_DAMAGE 事件
    distribute_trigger(TriggerData.TriggerType.ON_WEAPON_HIT, {"target": target})
    distribute_trigger(TriggerData.TriggerType.ON_DEAL_DAMAGE, {"target": target, "damage": damage_info.damage})

func distribute_trigger(trigger_type, context):
    for slot in all_engraving_slots:
        if slot.engraved_spell != null:
            for rule in slot.engraved_spell.topology_rules:
                if rule.trigger.trigger_type == trigger_type:
                    # 检查其他条件 (如概率、冷却等)
                    if can_execute(rule):
                        action_executor.execute_actions(rule.actions, context)
```

## 4. 开发计划

1.  **实现数据结构：** 创建`BodyPart.gd`和`EngravingSlot.gd`，并扩展`WeaponData.gd`和`TriggerData.gd`。
2.  **实现肢体系统：** 在`Player.tscn`中添加`BodyPart`节点，代表角色的各个部位。
3.  **实现刻录管理器：** 创建`EngravingManager.gd`，并完成事件监听和触发器分发的核心逻辑。
4.  **实现效果执行器：** 创建`ActionExecutor.gd`，用于处理非投射物类型的法术效果。
5.  **创建UI界面：** 开发一个用于管理法术刻录的UI面板，允许玩家将法术库中的法术拖拽到不同的刻录槽中。
6.  **集成与测试：** 将新系统与战斗测试场景集成，并进行全面的功能测试。

## 5. 预期成果

完成开发后，系统将具备以下能力：

*   玩家可以在一个专门的UI界面中，为角色的手臂、腿、躯干以及装备的武器镶嵌不同的法术。
*   当玩家执行特定动作时（如用剑砍中敌人、成功格挡、开始飞行），可以触发这些镶嵌法术的被动效果。
*   例如，可以在剑上刻录一个“命中时触发闪电链”的法术，或在腿上刻录一个“飞行时持续恢复生命”的法术。
