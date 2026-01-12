# 手臂渲染系统更新日志

**更新日期**: 2026-01-12
**版本**: 2.0

## 概述

本次更新重构了角色手臂渲染系统，实现了以下核心功能：

1. **手臂驱动武器** - 手的位置由攻击动作决定，武器附着在手上
2. **徒手战斗支持** - 拳击动作驱动手的移动轨迹
3. **统一的武器处理** - 为每种武器类型定义了标准的手臂行为

---

## 核心设计原则

| 原则 | 说明 |
|------|------|
| **手臂驱动武器** | 手的位置由攻击动作决定，武器附着在手上跟随移动 |
| **武器是手的延伸** | 武器 Sprite 作为手的子节点，通过握柄偏移对齐 |
| **徒手是特殊武器** | 拳头就是武器，拳击动作驱动手的移动轨迹 |

---

## 新增文件

### `scripts/combat/arm_rig.gd`

单条手臂的渲染和 IK 解算。

**主要功能**:
- Two-Bone IK 解算手臂姿态
- 武器 Sprite 作为手的子节点
- 支持设置手的目标位置和旋转
- 平滑的 IK 过渡动画

**关键参数**:

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `is_left_arm` | false | 是否为左臂 |
| `upper_arm_length` | 18.0 | 上臂长度 |
| `forearm_length` | 16.0 | 前臂长度 |
| `arm_color` | 肤色 | 手臂颜色 |
| `shoulder_offset` | Vector2(12, 0) | 肩膀偏移 |

### `scripts/combat/combat_animator.gd`

战斗动画控制器，根据攻击动作驱动手部轨迹。

**主要功能**:
- 管理攻击动画的播放
- 根据攻击类型计算手部位置
- 支持挥砍、刺击、重击等不同攻击类型
- 处理徒手和持武器的不同待机姿态

---

## 修改文件

### `scripts/combat/player_visuals.gd`

**主要变更**:
- 移除旧的 `ArmIKController` 引用
- 动态创建 `ArmRig` 节点
- 集成 `CombatAnimator` 控制器
- 武器纹理旋转 -90° 使刀尖指向右方

### `scenes/player/player.tscn`

**主要变更**:
- 移除静态的 `ArmIKController` 节点
- 移除 `MainHandWeapon` 和 `OffHandWeapon` 节点（改为动态创建）
- 简化节点结构

### `resources/combat/weapon_data.gd`

**主要变更**:
- 扩展 `create_unarmed()` 方法
- 添加左拳、右拳、重拳攻击动作
- 支持拳击连击

### `resources/combat/attack_data.gd`

**新增字段**:
- `main_hand_trajectory` - 主手轨迹点数组
- `off_hand_trajectory` - 副手轨迹点数组
- `trajectory_timing` - 轨迹时间比例数组
- `main_hand_rotation_curve` - 主手旋转曲线

**新增方法**:
- `get_main_hand_position_at_progress()` - 获取主手位置
- `get_off_hand_position_at_progress()` - 获取副手位置
- `has_hand_trajectory()` - 检查是否有自定义轨迹

---

## 各武器类型处理方案

| 武器类型 | 左手行为 | 右手行为 | 武器附着 |
|----------|----------|----------|----------|
| **徒手** | 握拳在身侧，出拳时向前 | 握拳在身侧，出拳时向前 | 无武器 Sprite |
| **单手剑** | 自然下垂或护身 | 握剑，跟随挥砍轨迹 | 附着在右手 |
| **大剑** | 握剑柄下方 | 握剑柄上方 | 附着在右手，左手跟随副握点 |
| **长矛** | 握矛身中段 | 握矛身后段 | 附着在右手 |
| **匕首** | 空置或持盾 | 反握匕首 | 附着在右手 |
| **法杖** | 握杖身中段 | 握杖身下段 | 附着在右手 |
| **双持** | 握副武器 | 握主武器 | 左右手各附着一把 |

---

## 节点结构

```
Player (CharacterBody2D)
└── Visuals (Node2D) [player_visuals.gd]
    ├── LegsPivot (Node2D)
    │   └── LegsSprite (Sprite2D)
    │
    └── TorsoPivot (Node2D)
        ├── TorsoSprite (Sprite2D)
        ├── HeadSprite (Sprite2D)
        │
        ├── LeftArmRig (ArmRig) [动态创建]
        │   ├── UpperArm (Line2D)
        │   ├── Forearm (Line2D)
        │   └── Hand (Node2D)
        │       ├── HandSprite (Sprite2D)
        │       └── WeaponSprite (Sprite2D)
        │
        ├── RightArmRig (ArmRig) [动态创建]
        │   ├── UpperArm (Line2D)
        │   ├── Forearm (Line2D)
        │   └── Hand (Node2D)
        │       ├── HandSprite (Sprite2D)
        │       └── WeaponSprite (Sprite2D)
        │
        ├── WeaponRig (Node2D)
        │   └── WeaponPhysics (Node2D)
        │
        └── CombatAnimator (Node) [动态创建]
```

---

## 使用说明

### 播放攻击动画

```gdscript
var attack = AttackData.create_default_slash()
player_visuals.play_attack_effect(attack)
```

### 自定义手部轨迹

```gdscript
var attack = AttackData.new()
attack.main_hand_trajectory = [
    Vector2(10, 15),   # 起始位置
    Vector2(25, 5),    # 中间位置
    Vector2(35, 0),    # 击中位置
    Vector2(20, 10),   # 收回位置
]
attack.trajectory_timing = [0.0, 0.3, 0.5, 1.0]
```

### 设置手臂颜色

```gdscript
player_visuals.set_arms_color(Color(0.8, 0.6, 0.5))
```

---

## 后续优化建议

1. **手指动画** - 添加手指骨骼，实现握拳/张开动画
2. **武器拖尾** - 武器挥舞时的拖尾特效
3. **IK 约束** - 添加肘部角度限制，避免不自然的姿态
4. **动态握点** - 根据攻击动作动态调整握点位置
