# 攻击移动动画系统

## 概述

本文档说明如何为攻击移动添加动画支持，让玩家在攻击时移动有专门的动画表现，提升视觉效果和游戏体验。

## 动画系统架构

### 现有系统
- **CombatAnimator**: 负责攻击动画（手臂和武器）
- **BodyAnimationController**: 负责全身骨骼动画（移动和飞行）
- **PlayerVisuals**: 管理所有视觉组件

### 新增功能
- **攻击移动混合动画**: 在攻击动画的基础上叠加移动动画
- **动画状态标记**: 标记当前是否在攻击移动状态
- **动画权重控制**: 控制攻击动画和移动动画的混合比例

## 实现方案

### 方案 A: 动画混合（推荐）

**原理**: 在播放攻击动画的同时，以较低的权重播放移动动画，实现自然的混合效果。

**优点**:
- 视觉效果自然流畅
- 可以精细控制混合比例
- 适合所有武器类型

**实现步骤**:

1. **在 PlayerController 中添加攻击移动状态**
```gdscript
var is_attacking_while_moving: bool = false

func _physics_process(delta: float) -> void:
    # 检测是否在攻击时移动
    is_attacking_while_moving = is_attacking and input_direction.length_squared() > 0.01
```

2. **在 BodyAnimationController 中添加混合逻辑**
```gdscript
func update_animation(delta: float) -> void:
    if player.is_attacking_while_moving:
        # 攻击移动混合动画
        _play_attack_movement_blend(delta)
    elif player.is_attacking:
        # 纯攻击动画（由 CombatAnimator 处理）
        pass
    elif player.input_direction.length_squared() > 0.01:
        # 纯移动动画
        _play_movement_animation(delta)
    else:
        # 待机动画
        _play_idle_animation(delta)

func _play_attack_movement_blend(delta: float) -> void:
    # 获取当前移动速度
    var move_speed = player.velocity.length()
    var max_speed = player.movement_config.max_speed_ground
    var speed_ratio = clamp(move_speed / max_speed, 0.0, 1.0)
    
    # 根据速度调整混合权重
    var movement_weight = speed_ratio * 0.3  # 移动动画权重最高30%
    var attack_weight = 1.0 - movement_weight
    
    # 播放混合动画
    # 这里需要根据实际的动画系统实现
```

3. **在攻击状态中通知视觉系统**
```gdscript
# 在 AttackWindupState, AttackActiveState, AttackRecoveryState 中
func physics_update(delta: float) -> void:
    # 更新攻击移动状态
    if player.visuals != null:
        player.visuals.set_attack_moving(player.input_direction.length_squared() > 0.01)
```

---

### 方案 B: 专门的攻击移动动画

**原理**: 为每种攻击创建专门的"攻击移动"动画变体。

**优点**:
- 可以精确控制每个动画帧
- 视觉效果可以完全定制
- 适合需要特殊表现的攻击

**缺点**:
- 需要制作大量动画
- 维护成本高

**实现步骤**:

1. **在 AttackData 中添加攻击移动动画**
```gdscript
@export var attack_movement_animation: StringName = &""  # 攻击移动动画名称
@export var has_attack_movement_variant: bool = false  # 是否有攻击移动变体
```

2. **在 CombatAnimator 中检查并播放**
```gdscript
func play_attack(attack: AttackData) -> void:
    var is_moving = player.input_direction.length_squared() > 0.01
    
    if is_moving and attack.has_attack_movement_variant:
        # 播放攻击移动动画
        _play_animation(attack.attack_movement_animation)
    else:
        # 播放普通攻击动画
        _play_animation(attack.animation_name)
```

---

### 方案 C: 程序化动画调整（当前实现）

**原理**: 根据移动方向和速度，程序化调整角色的姿态和动画速度。

**优点**:
- 不需要额外的动画资源
- 自动适应所有情况
- 实现简单

**缺点**:
- 视觉效果可能不如手工制作的动画

**当前实现**:
- 玩家在攻击时可以移动
- 移动速度根据武器和攻击阶段自动调整
- 视觉系统自动处理腿部和躯干的旋转

---

## 推荐实现：方案 A + 方案 C

结合动画混合和程序化调整，既能保证视觉效果，又不需要大量额外工作。

### 具体实现

#### 1. 在 PlayerController 中添加状态标记

```gdscript
## 在 player_controller.gd 中添加
var is_attacking_while_moving: bool = false

func _physics_process(delta: float) -> void:
    # ... 现有代码 ...
    
    # 更新攻击移动状态
    is_attacking_while_moving = is_attacking and input_direction.length_squared() > 0.01
```

#### 2. 在 PlayerVisuals 中添加混合逻辑

```gdscript
## 在 player_visuals.gd 中添加
func _process(delta: float) -> void:
    if player == null:
        return
    
    # 更新攻击移动动画
    if player.is_attacking_while_moving:
        _update_attack_movement_animation(delta)
    elif player.is_attacking:
        # 纯攻击动画（由 CombatAnimator 处理）
        pass
    else:
        # 正常移动或待机
        _update_normal_animation(delta)

func _update_attack_movement_animation(delta: float) -> void:
    # 获取移动速度比例
    var move_speed = player.velocity.length()
    var max_speed = player.movement_config.max_speed_ground if not player.is_flying else player.movement_config.max_speed_flight
    var speed_ratio = clamp(move_speed / max_speed, 0.0, 1.0)
    
    # 调整腿部动画速度
    if body_animation_controller != null:
        body_animation_controller.set_leg_animation_speed(speed_ratio * 0.5)  # 攻击时腿部动画速度降低
    
    # 调整躯干倾斜
    var move_direction = player.input_direction.normalized()
    var tilt_angle = move_direction.x * 5.0 * speed_ratio  # 根据移动方向轻微倾斜
    torso_pivot.rotation_degrees = lerp(torso_pivot.rotation_degrees, tilt_angle, delta * 5.0)
```

#### 3. 添加视觉反馈

```gdscript
## 添加攻击移动的视觉效果
func _update_attack_movement_animation(delta: float) -> void:
    # ... 现有代码 ...
    
    # 添加拖尾效果
    if player.current_attack_phase == "active" and speed_ratio > 0.3:
        _spawn_movement_trail()
    
    # 调整武器位置
    if weapon_physics != null:
        var offset = move_direction * 2.0 * speed_ratio
        weapon_physics.position = lerp(weapon_physics.position, offset, delta * 10.0)
```

---

## 动画细节优化

### 1. 腿部动画
- **站立攻击**: 腿部保持稳定，轻微晃动
- **前进攻击**: 腿部播放慢速行走动画
- **后退攻击**: 腿部播放慢速后退动画
- **侧移攻击**: 腿部播放侧步动画

### 2. 躯干动画
- **攻击时**: 躯干跟随武器轻微旋转
- **移动时**: 躯干根据移动方向轻微倾斜
- **混合时**: 两种效果叠加，保持自然

### 3. 武器动画
- **攻击时**: 武器按照攻击轨迹挥舞
- **移动时**: 武器位置根据移动方向微调
- **混合时**: 保持攻击轨迹，但位置随移动调整

---

## 配置参数

### 在 MovementConfig 中添加

```gdscript
@export_group("Attack Movement Animation")
## 攻击移动时腿部动画速度倍率
@export var attack_movement_leg_speed: float = 0.5
## 攻击移动时躯干倾斜角度
@export var attack_movement_torso_tilt: float = 5.0
## 攻击移动时武器位置偏移
@export var attack_movement_weapon_offset: float = 2.0
```

### 在 AttackData 中添加（可选）

```gdscript
@export_group("Attack Movement Animation")
## 是否启用攻击移动动画
@export var enable_attack_movement_animation: bool = true
## 攻击移动时的动画混合权重
@export_range(0.0, 1.0) var attack_movement_blend_weight: float = 0.3
```

---

## 测试和调整

### 测试清单
1. ✅ 攻击时移动，腿部动画是否自然
2. ✅ 不同方向移动时，躯干倾斜是否合理
3. ✅ 武器挥舞轨迹是否受到影响
4. ✅ 动画混合是否流畅，无抖动
5. ✅ 不同武器的攻击移动动画是否有差异

### 调整建议
- 如果腿部动画太快，降低 `attack_movement_leg_speed`
- 如果躯干倾斜太明显，降低 `attack_movement_torso_tilt`
- 如果武器位置偏移太大，降低 `attack_movement_weapon_offset`
- 如果动画混合不自然，调整 `attack_movement_blend_weight`

---

## 实现状态

### 当前已实现
✅ 攻击时可以移动（功能层面）
✅ 移动速度根据武器和阶段调整
✅ 程序化的姿态调整

### 待实现（可选）
⬜ 动画混合系统
⬜ 专门的攻击移动动画
⬜ 攻击移动视觉效果（拖尾、粒子等）
⬜ 攻击移动音效

---

## 总结

攻击移动动画系统的核心是在保持攻击动画的同时，自然地融入移动动画。通过动画混合、程序化调整和视觉反馈的结合，可以创造出流畅自然的攻击移动体验。

当前实现已经提供了基础的功能支持（攻击时可以移动），动画优化可以作为后续的视觉增强项目逐步完善。
