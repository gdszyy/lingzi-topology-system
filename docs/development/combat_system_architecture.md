# 灵子项目 - 俯视角战斗系统架构设计

**版本:** 1.0
**日期:** 2026-01-12

## 1. 概述

本文档旨在为“灵子拓扑构筑系统”项目设计一套全新的、基于用户需求的俯视角2D角色战斗系统。该设计将严格遵循参考文档《Godot2D角色战斗系统实现.md》中提出的核心原则，并与项目现有的数据驱动和法术系统进行深度整合。

## 2. 核心设计原则

- **数据驱动:** 角色、武器和攻击动作的核心参数将通过 Godot 的 `Resource` (`.tres` 文件) 进行定义，便于策划调整和扩展。
- **状态机驱动:** 采用分层状态机（HSM）管理角色复杂的行为逻辑（移动、攻击、飞行、施法等），确保逻辑清晰、易于维护。
- **物理与视觉分离:** 角色的物理碰撞与移动逻辑（`CharacterBody2D`）将与视觉表现（`Skeleton2D`, `Sprite2D`）分离，实现“身首分离”的灵活操控感。
- **模块化与可扩展性:** 各个子系统（移动、武器、动画、法术）将设计为高内聚、低耦合的模块，方便未来独立升级或替换。

## 3. 场景与节点结构

我们将创建一个新的玩家场景 `player.tscn`，取代现有测试场景中的静态 `SpellCaster`。

### `player.tscn` 节点树

```
- Player (CharacterBody2D)  # 根节点，挂载 player_controller.gd
  - CollisionShape2D        # 物理碰撞体
  - Visuals (Node2D)          # 视觉根节点，用于整体旋转、缩放
    - LegsPivot (Node2D)      # 腿部枢纽，根据移动方向旋转
      - LegsSprite (AnimatedSprite2D) # 腿部动画
    - TorsoPivot (Node2D)     # 躯干枢纽，根据鼠标朝向旋转
      - TorsoSprite (Sprite2D) # 躯干贴图
      - HeadSprite (Sprite2D)  # 头部贴图
      - WeaponRig (Node2D)     # 武器挂载点
        - Skeleton2D         # 手臂骨骼
          - Bone: Shoulder.L -> Elbow.L -> Hand.L
          - Bone: Shoulder.R -> Elbow.R -> Hand.R
        - MainHandWeapon (Sprite2D) # 主手武器
        - OffHandWeapon (Sprite2D)  # 副手武器
  - StateMachine (Node)         # 状态机管理器
  - WeaponManager (Node)        # 武器管理器
  - AnimationPlayer (AnimationPlayer) # 动画播放器
  - InputBuffer (Node)          # 输入缓存器
```

## 4. 核心脚本与子系统设计

### 4.1. `player_controller.gd`

挂载于 `Player` 根节点，是整个角色的控制中枢。

- **职责:**
  - 接收并处理玩家输入。
  - 管理状态机（`StateMachine`）的切换。
  - 实现自定义物理移动（地面/飞行模式切换、加速度、摩擦力）。
  - 实现平滑的角速度受限旋转。
  - 提供供状态节点调用的核心API（如 `apply_velocity()`, `rotate_torso()`）。

### 4.2. 状态机 (`StateMachine`)

采用分层状态机设计，管理角色的所有行为状态。

- **基础状态:**
  - `Idle`: 静止状态。
  - `Move`: 地面移动状态。
  - `Fly`: 飞行状态，使用独立的物理参数。
  - `Turn`: 强制转身状态，用于攻击或施法前的“回正”。
- **攻击子状态机:**
  - `Attack_Windup`: 攻击前摇。
  - `Attack_Active`: 攻击判定帧，施加惯性冲量。
  - `Attack_Recovery`: 攻击后摇，检测连击输入。
- **施法子状态机:**
  - `Spell_Aim`: 施法瞄准，等待“回正”。
  - `Spell_Cast`: 执行施法动作，调用 `SpellFactory`。

### 4.3. 武器系统

#### `WeaponData.gd` (Resource)

创建一个新的 `Resource` 类型 `WeaponData`，用于定义武器。

```gdscript
class_name WeaponData extends Resource

@export_group("Visuals")
@export var main_hand_texture: Texture2D
@export var off_hand_texture: Texture2D
@export var ik_left_hand_pos: Vector2
@export var ik_right_hand_pos: Vector2

@export_group("Physics")
@export var weight: float = 1.0 # 影响转身速度、移动惯性
@export var impulse_on_attack: float = 100.0 # 攻击时给予的冲量

@export_group("Combat")
@export var is_two_handed: bool = false
@export var attacks: Array[AttackData] # 攻击动作序列
```

#### `AttackData.gd` (Resource)

定义单次攻击的详细数据。

```gdscript
class_name AttackData extends Resource

@export var input_type: InputType # 左键, 右键, 双键
@export var animation_name: StringName
@export var damage: float
@export var windup_time: float
@export var active_time: float
@export var recovery_time: float
@export var can_combo: bool
```

#### `WeaponManager.gd`

- **职责:**
  - 管理玩家的武器库。
  - 处理武器的装备 (`equip_weapon(weapon_data)`) 和卸下。
  - 在装备时，将 `WeaponData` 的物理参数（如 `weight`）应用到 `player_controller`。
  - 更新 `WeaponRig` 中的武器贴图和 IK 目标点。

### 4.4. 动画与IK系统

- **`AnimationPlayer`** 将包含所有武器的攻击动画（例如 `greatsword_slash_1`, `dagger_stab`）。这些动画主要控制武器 `Sprite2D` 的移动和旋转。
- **`Skeleton2D`** 的骨骼将通过 `SkeletonModification2DTwoBoneIK` 修改器，使其手部骨骼（`Hand.L`, `Hand.R`）始终朝向武器上定义的IK目标点，从而实现手臂自动跟随武器挥舞的效果。

## 5. 与现有系统的集成

### 5.1. 替换 `SpellCaster`

- 在 `battle_test_scene.tscn` 中，原有的 `SpellCaster` 节点将被删除，并替换为 `player.tscn` 的实例。
- `battle_test_scene.gd` 中对 `spell_caster` 的引用将全部指向新的 `Player` 节点实例。

### 5.2. 整合法术系统

- 玩家的“施法”动作将不再是简单的 `fire()` 调用。
- 当玩家施法时，`Spell_Cast` 状态将触发。
- 该状态会从玩家的法术列表中获取当前的 `SpellCoreData`。
- 然后调用全局单例 `SpellFactory.create_spell()` 来生成法术实例（`Projectile`）。
- 这将完全复用项目现有的、成熟的法术生成和执行逻辑。
- `player_controller.gd` 将会取代 `spell_caster.gd` 的部分功能，如统计伤害、命中率等，并将结果传递给UI。

## 6. 开发步骤规划

1.  **创建基础场景和资源:** 创建 `player.tscn`, `WeaponData.gd`, `AttackData.gd`。
2.  **实现移动和旋转:** 在 `player_controller.gd` 中实现基础的移动、飞行和鼠标朝向旋转逻辑。
3.  **构建状态机:** 实现 `StateMachine` 和基础的 `Idle`, `Move`, `Fly` 状态。
4.  **实现武器系统:** 开发 `WeaponManager`，并创建几把测试武器的 `.tres` 文件。
5.  **实现攻击动作:** 实现攻击子状态机，并与 `AnimationPlayer` 和 `Skeleton2D` IK 联动。
6.  **集成法术系统:** 将现有的法术施放逻辑整合到玩家的施法状态中。
7.  **替换测试场景:** 将 `player.tscn` 放入 `battle_test_scene.tscn` 并完成适配。
8.  **测试与迭代:** 全面测试所有功能，并根据手感进行参数调整。

