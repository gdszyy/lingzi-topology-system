# 攻击与移动系统分析

## 问题描述

当前玩家在进行攻击动作时，移动功能被禁用，导致攻击和移动无法同时进行。

## 核心问题定位

### 1. 攻击状态机中的移动限制

在攻击的三个状态中，`can_move` 都被设置为 `false`：

#### AttackWindupState (攻击前摇状态)
**文件**: `scripts/combat/state_machine/states/attack_windup_state.gd`
**第 33-36 行**:
```gdscript
func enter(params: Dictionary = {}) -> void:
    player.can_move = false  # ❌ 禁用移动
    player.can_rotate = false
    player.is_attacking = true
```

#### AttackActiveState (攻击激活状态)
**文件**: `scripts/combat/state_machine/states/attack_active_state.gd`
**第 26-29 行**:
```gdscript
func enter(params: Dictionary = {}) -> void:
    player.can_move = false  # ❌ 禁用移动
    player.can_rotate = false
    player.is_attacking = true
```

#### AttackRecoveryState (攻击恢复状态)
**文件**: `scripts/combat/state_machine/states/attack_recovery_state.gd`
**第 28-31 行**:
```gdscript
func enter(params: Dictionary = {}) -> void:
    player.can_move = false  # ❌ 禁用移动
    player.can_rotate = true  # 恢复阶段允许旋转
    player.is_attacking = true
```

### 2. 移动系统的实现

**文件**: `scripts/combat/player_controller.gd`
**第 199-203 行**:
```gdscript
func _apply_movement(delta: float) -> void:
    if not can_move:  # ⚠️ 如果 can_move 为 false，只应用摩擦力停止
        var stop_friction = movement_config.friction_ground if not is_flying else movement_config.friction_flight
        velocity = velocity.move_toward(Vector2.ZERO, stop_friction * delta)
        return  # 直接返回，不处理输入
```

## 问题根源

当玩家进入任何攻击状态时，`can_move` 被设置为 `false`，导致 `_apply_movement()` 函数直接返回，不处理玩家的移动输入。这是一个**设计决策**，而不是 bug，但它限制了战斗的流畅性。

## 解决方案

### 方案 A: 允许攻击时移动（推荐）

**优点**:
- 战斗更加流畅和动态
- 符合现代动作游戏的设计理念
- 玩家可以边攻击边走位

**实现**:
1. 在攻击状态中保持 `can_move = true`
2. 可选：添加移动速度惩罚（如攻击时移动速度降低 30-50%）

### 方案 B: 仅在特定攻击阶段允许移动

**优点**:
- 保留攻击的重量感
- 前摇和激活阶段锁定，恢复阶段可移动

**实现**:
1. 前摇和激活阶段：`can_move = false`
2. 恢复阶段：`can_move = true`（已经允许旋转）

### 方案 C: 根据武器类型决定

**优点**:
- 不同武器有不同的移动特性
- 轻武器可以边攻击边移动，重武器需要站定

**实现**:
1. 在 `WeaponData` 中添加 `allow_movement_during_attack` 属性
2. 在攻击状态中根据武器属性决定是否允许移动

## 推荐实现：方案 A（完全允许移动）

这是最简单且最符合现代动作游戏体验的方案。
