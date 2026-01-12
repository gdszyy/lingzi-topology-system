# 战斗系统扩展：二维体素肢体设计文档

**版本:** 1.0
**日期:** 2026-01-12
**作者:** Manus AI

## 1. 概述

本文档旨在响应用户需求，为“灵子拓扑构筑系统”项目引入“二维体素”战斗概念。其核心机制为：角色由多个可独立损坏的“体素化”肢体构成，法术可被篆刻在这些肢体上。当一个肢体在战斗中被摧毁时，其上篆刻的所有法术将立刻失效。这一设计将极大地增强战斗的策略深度和动态性。

设计将基于并扩展现有的 `BodyPartData` 和 `EngravingManager` 系统，重点引入肢体目标伤害、损伤状态管理以及与法术系统联动的失效机制。

## 2. 核心概念与术语

| 概念 | 设计实现 |
| :--- | :--- |
| **二维体素 (2D Voxel)** | 这是对角色身体结构的一种抽象描述。在本项目中，一个“体素”即为一个 `BodyPartData` 实例，代表一个可被独立锁定、攻击和摧毁的身体部位。 |
| **肢体目标 (Body Part Targeting)** | 战斗系统将引入精确到肢体的目标机制。攻击不仅针对某个实体，而是能够精确命中该实体的特定肢体，例如“攻击敌人的左臂”。 |
| **肢体损伤与摧毁 (Limb Damage & Destruction)** | 每个肢体拥有独立的生命值。当其生命值降至零时，该肢体被视为“已摧毁”，其功能状态 `is_functional` 将被设为 `false`。 |
| **法术失效 (Spell Inoperability)** | 当一个肢体被摧毁后，`EngravingManager` 在分发触发器时将自动忽略该肢体上的所有篆刻槽，从而实现法术失效的效果。 |

## 3. 系统架构与修改方案

我们将对现有战斗系统进行以下核心修改，以实现体素化战斗逻辑。

### 3.1. 伤害流程重构

当前的伤害模型是针对角色的整体生命值。我们需要将其重构为基于肢体的分布式伤害模型。

#### 3.1.1. 扩展 `take_damage` 方法

`PlayerController.gd` 和 `Enemy.gd` 中的 `take_damage` 方法将被修改，以接受一个可选的肢体目标参数。

```gdscript
# In PlayerController.gd and relevant enemy scripts

# old: func take_damage(damage: float, source: Node2D = null)
# new:
func take_damage(damage: float, source: Node2D = null, target_part_type: BodyPartData.PartType = BodyPartData.PartType.TORSO) -> void:
    # ... (logic to route damage)
```

#### 3.1.2. 伤害路由逻辑

`take_damage` 的内部逻辑将变更为：

1.  根据传入的 `target_part_type` 查找对应的 `BodyPartData` 实例。
2.  调用该 `BodyPartData` 实例自身的 `take_damage(damage)` 方法，计算并扣除肢体生命值。
3.  肢体 `take_damage` 方法在生命值降为零时，将自身的 `is_functional` 标志设为 `false`。
4.  肢体将实际受到的伤害值返回给 `PlayerController`。
5.  `PlayerController` 的能量系统（或总生命值）将承受该部分伤害，以维持角色生死判定，但伤害数值可以根据设计进行减免（例如，肢体承受70%，躯干承受30%）。

```gdscript
# In PlayerController.gd

func take_damage(damage: float, source: Node2D = null, target_part_type: BodyPartData.PartType = BodyPartData.PartType.TORSO) -> void:
    var body_part = engraving_manager.get_body_part(target_part_type)
    var damage_to_part = damage

    if body_part and body_part.is_functional:
        var actual_damage_taken_by_part = body_part.take_damage(damage_to_part)
        
        # 核心逻辑：肢体受损的同时，角色本体也承受一定比例的伤害
        var damage_to_core = actual_damage_taken_by_part * 0.3 # 示例：30%的伤害传递到核心
        energy_system.take_damage(damage_to_core)

        if not body_part.is_functional:
            # 触发肢体摧毁事件
            emit_signal("body_part_destroyed", body_part)
    else:
        # 如果目标肢体不存在或已被摧毁，则伤害直接作用于躯干
        var torso = engraving_manager.get_body_part(BodyPartData.PartType.TORSO)
        if torso:
            torso.take_damage(damage)
        energy_system.take_damage(damage)

    took_damage.emit(damage, source)
```

### 3.2. `EngravingManager` 逻辑增强

`EngravingManager` 是实现法术失效的关键。我们需要修改其触发器分发逻辑。

```gdscript
# In EngravingManager.gd

# 修改 distribute_trigger 和 distribute_trigger_immediate 方法

func distribute_trigger(trigger_type: int, context: Dictionary = {}) -> void:
    # ...
    for part in body_parts:
        # 核心检查：只处理功能完好的肢体
        if not part.is_functional:
            continue

        for slot in part.engraving_slots:
            if not slot.can_trigger():
                continue
            # ... (rest of the logic)

    # 对武器槽位的处理保持不变
    if player != null and player.current_weapon != null:
        for slot in player.current_weapon.engraving_slots:
            # ...
```

通过在遍历肢体时增加 `if not part.is_functional: continue` 的判断，即可简单高效地实现对已摧毁肢体上所有法术的禁用。

### 3.3. 攻击与目标锁定

为了让玩家和AI能够执行肢体目标攻击，我们需要：

1.  **引入肢体碰撞体 (Hitbox):** 在 `Player` 和 `Enemy` 场景中，为每个重要的 `BodyPartData` 关联一个 `Area2D` 作为其专有碰撞盒。这些碰撞盒应属于一个特定的物理层（例如 `body_parts`）。
2.  **修改攻击逻辑:** 攻击动作（无论是近战还是远程投射物）在检测命中时，应优先检测是否命中了 `body_parts` 层的碰撞盒。如果命中，则可以从该 `Area2D` 获取其关联的 `BodyPartData.PartType`，并将其作为参数传递给 `take_damage` 方法。
3.  **UI指示:** 在UI中增加一个目标指示器，当玩家锁定一个敌人时，可以循环切换锁定其不同的肢体部位，并将选择的 `PartType` 用于后续的攻击指令。

## 4. 视觉与玩法反馈

清晰地向玩家反馈肢体状态至关重要。

- **视觉效果 (VFX):** 当一个肢体被摧毁时，应在其位置播放一个明显的视觉效果（如断裂、能量泄露）。同时，该肢体的视觉表现可以发生改变（例如，手臂断裂后不再渲染）。
- **UI反馈:** 在角色状态UI中，以图标或列表形式展示所有肢体的健康状况。被摧毁的肢体及其上的法术应以灰色或红色高亮显示，明确告知玩家其已失效。
- **游戏性影响:** 肢体摧毁应带来直接的游戏性后果。例如：
    - **手臂被毁:** 无法使用该手臂上的武器或盾牌。
    - **腿部被毁:** 移动速度大幅降低，无法飞行或冲刺。
    - **头部被毁:** 产生“眩晕”或“感知模糊”效果（例如，屏幕特效，小地图失效）。

## 5. 开发步骤规划

1.  **重构伤害系统:** 按照 3.1 节的设计，修改 `take_damage` 方法，并实现伤害路由逻辑。
2.  **增强管理器:** 按照 3.2 节的设计，为 `EngravingManager` 添加肢体功能状态检查。
3.  **实现肢体碰撞盒:** 为角色和敌人添加肢体 `Area2D`，并完成攻击逻辑的适配。
4.  **开发UI与VFX:** 创建肢体状态UI，并制作肢体受损和被摧毁的视觉效果。
5.  **实现游戏性影响:** 根据肢体类型，编写当肢体被摧毁时触发相应游戏性惩罚的逻辑。
6.  **测试与迭代:** 全面测试新的战斗系统，调整伤害、生命值、惩罚效果等参数，确保系统的平衡性和趣味性。

通过以上设计，我们将能够成功地将“二维体素”战斗系统无缝整合到现有框架中，为玩家带来更具深度和沉浸感的战斗体验。
