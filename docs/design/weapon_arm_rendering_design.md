# 武器-手臂渲染系统设计文档

**版本**: 1.0
**日期**: 2026-01-12

## 1. 问题分析

### 1.1 当前问题

1. **武器方向错误**：武器 Sprite 默认是横向的（position = Vector2(20, 0)），但在俯视角游戏中，武器应该指向角色面朝的方向（通常是向右/前方）
2. **徒手战斗无法处理**：当前系统假设总是有武器存在，徒手时手臂没有合理的目标位置
3. **手臂跟随逻辑不统一**：不同武器类型需要不同的手臂行为，但没有统一的处理框架

### 1.2 核心设计原则

> **原则一：手臂驱动武器，而非武器驱动手臂**

在现实中，是手握住武器并挥舞它。因此：
- 手的位置应该由**攻击动作**决定
- 武器应该**附着在手上**，跟随手移动
- IK 解算手臂姿态，让肩-肘-手形成自然的链条

> **原则二：武器是手的延伸**

武器 Sprite 应该作为手的子节点或相对于手定位：
- 武器的**握柄位置**对齐到手的位置
- 武器的**旋转**由攻击动作控制
- 不同武器有不同的握柄偏移

> **原则三：徒手是特殊的"武器"**

徒手战斗不是"没有武器"，而是"拳头就是武器"：
- 拳头的攻击范围就是手的位置
- 拳击动作驱动手的移动轨迹
- 手臂 IK 自然跟随

---

## 2. 坐标系与方向约定

### 2.1 俯视角坐标系

```
        -Y (上/北)
           ↑
           |
-X (左) ←--+--→ +X (右/角色面朝方向)
           |
           ↓
        +Y (下/南)
```

### 2.2 武器方向约定

| 武器类型 | 默认朝向 | 旋转 0° 时的状态 |
|----------|----------|------------------|
| 剑/刀 | 刀尖向右 (+X) | 水平持剑，准备挥砍 |
| 长矛 | 矛尖向右 (+X) | 水平持矛，准备刺击 |
| 法杖 | 杖头向右 (+X) | 水平持杖 |
| 拳头 | 无 | 手握拳，准备出拳 |

### 2.3 Sprite 绘制约定

武器 Sprite 应该按照以下方式绘制：

```
武器 Sprite 坐标系：
- 原点 (0,0) 在握柄中心
- 刀刃/矛尖指向 +Y 方向（图片的下方）
- 在场景中旋转 -90° 使其指向 +X

或者：
- 原点 (0,0) 在握柄中心
- 刀刃/矛尖指向 +X 方向（图片的右方）
- 无需额外旋转
```

**推荐方案**：Sprite 绘制时刀尖向右 (+X)，这样 rotation = 0 时武器水平指向右方。

---

## 3. 节点层级重构

### 3.1 新的节点结构

```
Player (CharacterBody2D)
└── Visuals (Node2D) [player_visuals.gd]
    ├── LegsPivot (Node2D)
    │   └── LegsSprite (Sprite2D)
    │
    └── TorsoPivot (Node2D) [跟随鼠标旋转]
        ├── TorsoSprite (Sprite2D)
        ├── HeadSprite (Sprite2D)
        │
        ├── LeftArmRig (Node2D) [左臂装配]
        │   ├── UpperArm (Line2D)
        │   ├── Forearm (Line2D)
        │   └── Hand (Node2D) [左手，IK 末端]
        │       └── OffHandWeapon (Sprite2D) [副手武器，可选]
        │
        ├── RightArmRig (Node2D) [右臂装配]
        │   ├── UpperArm (Line2D)
        │   ├── Forearm (Line2D)
        │   └── Hand (Node2D) [右手，IK 末端]
        │       └── MainHandWeapon (Sprite2D) [主手武器]
        │
        └── WeaponPhysics (Node2D) [武器物理，控制旋转]
```

### 3.2 关键变化

1. **武器作为手的子节点**：MainHandWeapon 是 RightHand 的子节点
2. **手的位置由动作驱动**：攻击动作定义手的目标位置
3. **IK 解算手臂**：根据手的位置反推肘部位置
4. **WeaponPhysics 控制旋转**：武器的旋转由物理系统控制，但位置跟随手

---

## 4. 各武器类型处理方案

### 4.1 徒手 (UNARMED)

**视觉表现**：
- 双手握拳，放在身体两侧
- 攻击时拳头向前伸出

**手臂行为**：
| 状态 | 左手位置 | 右手位置 |
|------|----------|----------|
| 待机 | 肩膀偏移 + (-8, 12) | 肩膀偏移 + (8, 12) |
| 左拳 | 肩膀偏移 + (25, 0) | 保持待机 |
| 右拳 | 保持待机 | 肩膀偏移 + (25, 0) |
| 双拳 | 同时出拳 | 同时出拳 |

**武器 Sprite**：
- 不显示武器 Sprite
- 可选：显示拳头特效

**攻击动作**：
```gdscript
# 右拳攻击
var punch_right = AttackData.new()
punch_right.attack_name = "右拳"
punch_right.hand_trajectory = [
    Vector2(8, 12),   # 起始：身侧
    Vector2(20, 5),   # 中间：向前伸
    Vector2(30, 0),   # 击中：最远点
    Vector2(15, 8),   # 收回
]
```

### 4.2 单手剑 (SWORD)

**视觉表现**：
- 右手握剑，剑尖指向前方
- 左手自然下垂或护在身前

**手臂行为**：
| 状态 | 左手位置 | 右手位置 |
|------|----------|----------|
| 待机 | 肩膀偏移 + (-5, 15) | 肩膀偏移 + (20, 0) |
| 挥砍 | 保持 | 跟随武器轨迹 |

**武器 Sprite**：
- 附着在右手上
- grip_offset = Vector2(0, 15) # 握柄在剑身下方 15 像素

**武器旋转**：
- 待机：rotation = 0°（水平向右）
- 挥砍：rotation 从 -60° 到 +60°

### 4.3 大剑 (GREATSWORD)

**视觉表现**：
- 双手握剑，剑身较长
- 两只手都在剑柄上

**手臂行为**：
| 状态 | 左手位置 | 右手位置 |
|------|----------|----------|
| 待机 | 握柄下方 | 握柄上方 |
| 正手挥砍 | 跟随武器 | 跟随武器 |
| 反手挥砍 | 跟随武器 | 跟随武器 |

**武器 Sprite**：
- 附着在右手上（主握点）
- 左手跟随副握点
- main_grip_offset = Vector2(0, 20)
- off_grip_offset = Vector2(0, 35)

### 4.4 长矛 (SPEAR)

**视觉表现**：
- 双手握矛，矛尖指向前方
- 刺击时矛身向前推进

**手臂行为**：
| 状态 | 左手位置 | 右手位置 |
|------|----------|----------|
| 待机 | 矛身中段 | 矛身后段 |
| 刺击 | 向前推进 | 向前推进 |
| 舞枪 | 跟随旋转 | 跟随旋转 |

**武器 Sprite**：
- 矛尖向右
- main_grip_offset = Vector2(0, 30) # 右手在后
- off_grip_offset = Vector2(0, 60)  # 左手在前

### 4.5 匕首 (DAGGER)

**视觉表现**：
- 右手反握匕首
- 左手可以持盾或空置

**手臂行为**：
| 状态 | 左手位置 | 右手位置 |
|------|----------|----------|
| 待机 | 身侧 | 身前，匕首向前 |
| 刺击 | 保持 | 快速向前刺 |

**武器 Sprite**：
- 较短的刀身
- grip_offset = Vector2(0, 8)

### 4.6 法杖 (STAFF)

**视觉表现**：
- 单手或双手持杖
- 施法时杖头发光

**手臂行为**：
| 状态 | 左手位置 | 右手位置 |
|------|----------|----------|
| 待机 | 杖身中段 | 杖身下段 |
| 施法 | 举起法杖 | 举起法杖 |

### 4.7 双持 (DUAL_WIELD)

**视觉表现**：
- 左右手各持一把武器
- 可以交替攻击

**手臂行为**：
| 状态 | 左手位置 | 右手位置 |
|------|----------|----------|
| 待机 | 持副武器 | 持主武器 |
| 左手攻击 | 向前挥 | 保持 |
| 右手攻击 | 保持 | 向前挥 |

---

## 5. 攻击动作数据扩展

### 5.1 新增字段

```gdscript
class_name AttackData extends Resource

## 手部轨迹
@export_group("Hand Trajectory")
@export var main_hand_trajectory: Array[Vector2] = []  # 主手轨迹点
@export var off_hand_trajectory: Array[Vector2] = []   # 副手轨迹点
@export var trajectory_timing: Array[float] = []       # 每个点的时间比例 (0-1)

## 手部旋转
@export var main_hand_rotation_start: float = 0.0
@export var main_hand_rotation_end: float = 0.0
```

### 5.2 轨迹插值

```gdscript
func get_hand_position_at_progress(progress: float, is_main_hand: bool) -> Vector2:
    var trajectory = main_hand_trajectory if is_main_hand else off_hand_trajectory
    if trajectory.size() == 0:
        return Vector2.ZERO
    
    # 根据 progress 在轨迹点之间插值
    for i in range(trajectory_timing.size() - 1):
        if progress >= trajectory_timing[i] and progress < trajectory_timing[i + 1]:
            var local_progress = (progress - trajectory_timing[i]) / (trajectory_timing[i + 1] - trajectory_timing[i])
            return trajectory[i].lerp(trajectory[i + 1], local_progress)
    
    return trajectory[-1]
```

---

## 6. 实现步骤

### 6.1 第一阶段：修复武器方向

1. 修改武器 Sprite 的默认旋转，使其指向正确方向
2. 调整 `_create_rect_texture` 生成的纹理方向
3. 更新 `weapon_offset` 的含义为握柄偏移

### 6.2 第二阶段：重构手臂系统

1. 将手臂节点改为独立的 Rig
2. 武器 Sprite 作为手的子节点
3. 实现手部位置驱动的 IK

### 6.3 第三阶段：实现徒手战斗

1. 创建徒手攻击动作数据
2. 实现拳头轨迹
3. 添加拳击特效

### 6.4 第四阶段：完善各武器类型

1. 为每种武器类型创建默认的手部轨迹
2. 调整握点偏移
3. 测试和调优

---

## 7. 代码结构

### 7.1 新增/修改的脚本

| 脚本 | 职责 |
|------|------|
| `arm_rig.gd` | 单条手臂的渲染和 IK 解算 |
| `hand_controller.gd` | 手的位置控制，武器附着 |
| `combat_animator.gd` | 根据攻击动作驱动手部轨迹 |

### 7.2 数据流

```
AttackData (手部轨迹)
    ↓
CombatAnimator (计算当前手部目标位置)
    ↓
HandController (设置手的位置和旋转)
    ↓
ArmRig (IK 解算肘部位置，渲染手臂)
    ↓
WeaponSprite (作为手的子节点，自动跟随)
```

---

## 8. 总结

| 问题 | 解决方案 |
|------|----------|
| 武器方向错误 | 统一 Sprite 绘制约定，刀尖向右 |
| 徒手无法处理 | 徒手作为特殊武器，拳头轨迹驱动手部 |
| 手臂跟随不统一 | 手部位置由攻击动作驱动，IK 解算手臂 |
| 武器位置不对 | 武器作为手的子节点，通过握柄偏移对齐 |
