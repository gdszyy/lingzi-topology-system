# 大刀、双刃剑、长矛攻击动作深度优化指南

**版本**: 1.0  
**日期**: 2026-01-13  
**优化方向**: 增强"挥出去"和"刺出去"的力度感，修复长矛握持问题

## 问题分析

### 1. 大刀和双刃剑 - 没有"挥出去"的感觉

**原因**:
- 挥舞半径太小（最大 28 左右）
- 武器伸出距离不足（最大 15）
- 没有根据武器长度动态调整参数
- 身体旋转不够明显

**表现**:
- 大刀看起来只是在原地转动
- 没有明显的"甩出去"的感觉
- 攻击幅度看起来很小

### 2. 长矛 - 握持位置错误 + 刺击不足

**原因**:
- 握点被硬编码为 `Vector2(-15 - thrust_distance * 0.2, 0)`，完全忽略了 `off_hand_grip_offset`
- 导致左手握在矛头而不是矛杆
- 刺击距离不足（最大 40）
- 没有根据长矛长度增加刺击幅度

**表现**:
- 左手握在矛头位置，看起来很奇怪
- 刺击动作没有穿透感
- 双手配合不协调

## 优化方案

### 1. CombatAnimator.gd - 动态武器长度系数

#### 挥砍攻击优化

```gdscript
## 【新增】根据武器长度计算伸缩系数
var weapon_length_factor = 1.0
if current_weapon:
    ## 武器越长，挥舞半径和伸出距离应该越大
    weapon_length_factor = clamp(current_weapon.weapon_length / 40.0, 0.8, 1.8)
```

**效果**:
- 40 长度的武器（标准剑）: 系数 1.0
- 60 长度的武器（大刀）: 系数 1.5
- 80 长度的武器（长矛）: 系数 2.0

#### 挥砍参数调整

**前摇阶段**:
```
swing_radius = (20.0 + swing_progress * 8.0) * weapon_length_factor
weapon_extension = (-5.0 + swing_progress * 12.0) * weapon_length_factor
```

**激活阶段** (关键优化):
```
swing_radius = (32.0 + swing_momentum * 8.0) * weapon_length_factor
weapon_extension = (25.0 + swing_momentum * 15.0) * weapon_length_factor  # 大幅增加
```

**恢复阶段**:
```
swing_radius = lerp(32.0, 22.0, recovery_progress) * weapon_length_factor
weapon_extension = lerp(25.0, 8.0, recovery_progress) * weapon_length_factor
```

**改进效果**:
- 大刀激活阶段伸出距离: 25 + 15 * 1.5 = 47.5（原来 15）
- 长矛激活阶段伸出距离: 25 + 15 * 2.0 = 55（原来 15）

### 2. CombatAnimator.gd - 刺击动作优化

#### 刺击参数调整

**前摇阶段**:
```
thrust_distance = lerp(20.0, 8.0, thrust_progress) * weapon_length_factor
```

**激活阶段** (关键优化):
```
thrust_distance = lerp(8.0, (60.0 + swing_momentum * 20.0) * weapon_length_factor, _ease_out_cubic(active_progress))
arm_extension = lerp(-8.0, (20.0 + swing_momentum * 8.0) * weapon_length_factor, _ease_out_cubic(active_progress))
body_lean = lerp(-0.1, 0.2, _ease_out_cubic(active_progress))  # 身体前倾更明显
```

**恢复阶段**:
```
thrust_distance = lerp((60.0 * weapon_length_factor), (20.0 * weapon_length_factor), _ease_in_out_cubic(recovery_progress))
arm_extension = lerp((20.0 * weapon_length_factor), 0.0, recovery_progress)
```

**改进效果**:
- 标准矛激活阶段刺击距离: 60 + 20 * 1.0 = 80（原来 40）
- 长矛激活阶段刺击距离: 60 + 20 * 2.0 = 100（原来 40）

### 3. CombatAnimator.gd - 修复长矛握持逻辑

#### 刺击时的双手握持修复

**修复前**:
```gdscript
var off_hand_offset = Vector2(-15 - thrust_distance * 0.2, 0)
var off_hand_pos = main_hand_pos + off_hand_offset
```

**修复后**:
```gdscript
## 使用武器数据中定义的握点
var grip_offset = off_hand_grip_offset.rotated(body_lean * 0.3)
var off_hand_pos = main_hand_pos + grip_offset
```

**效果**:
- 左手握点精确对齐到武器杆上
- 左手位置由 `WeaponData.grip_point_off` 决定
- 长矛握持位置正确

### 4. PlayerVisuals.gd - 使用武器数据中的握点

#### 握柄偏移修复

**修复前**:
```gdscript
var grip_offset = Vector2(0, weapon.weapon_length * 0.4)
```

**修复后**:
```gdscript
var grip_offset = weapon.grip_point_main
if grip_offset == Vector2.ZERO:
    grip_offset = Vector2(0, weapon.weapon_length * 0.3)
```

**效果**:
- 优先使用 `WeaponData` 中定义的 `grip_point_main`
- 如果没有定义，使用默认值
- 确保握点与武器设计一致

## 武器配置建议

### 大刀 (Greatsword)

```gdscript
weapon_length: 60.0
grip_point_main: Vector2(0, 18.0)      # 握柄靠近刀尖
grip_point_off: Vector2(0, 45.0)       # 副手握柄靠近刀柄
weight: 2.5
attack_impulse: 150.0
```

**攻击特性**:
- 挥舞半径: 32 + 8 * 1.5 = 44（激活阶段）
- 伸出距离: 25 + 15 * 1.5 = 47.5
- 总伸展距离: 44 + 47.5 = 91.5（非常明显的"挥出去"感）

### 双刃剑 (Dual Blade)

```gdscript
weapon_length: 50.0
grip_point_main: Vector2(0, 15.0)
grip_point_off: Vector2(0, 35.0)
weight: 1.8
attack_impulse: 120.0
```

**攻击特性**:
- 挥舞半径: 32 + 8 * 1.25 = 42
- 伸出距离: 25 + 15 * 1.25 = 43.75
- 总伸展距离: 42 + 43.75 = 85.75

### 长矛 (Spear)

```gdscript
weapon_length: 80.0
grip_point_main: Vector2(0, 24.0)      # 握在矛杆中部
grip_point_off: Vector2(0, 60.0)       # 副手握在矛杆下部
weight: 1.5
attack_impulse: 130.0
```

**攻击特性**:
- 刺击距离: 60 + 20 * 2.0 = 100（非常明显的"刺出去"感）
- 手臂伸展: 20 + 8 * 2.0 = 36
- 总伸展距离: 100 + 36 = 136（穿透感十足）

## 技术细节

### 武器长度系数计算

```
weapon_length_factor = clamp(weapon_length / 40.0, 0.8, 1.8)

示例:
- 30 长度: 0.75 -> 0.8（最小值）
- 40 长度: 1.0
- 50 长度: 1.25
- 60 长度: 1.5
- 80 长度: 2.0
- 100 长度: 2.5 -> 1.8（最大值）
```

### 动态伸缩的视觉效果

**激活阶段的伸展**:
```
总伸展 = swing_radius + weapon_extension
      = (32 + 8 * momentum) * factor + (25 + 15 * momentum) * factor
      = (57 + 23 * momentum) * factor
```

**对于大刀（factor = 1.5）**:
```
无动量: 57 * 1.5 = 85.5
最大动量(1.0): 80 * 1.5 = 120
```

**对于长矛（factor = 2.0）**:
```
无动量: 57 * 2.0 = 114
最大动量(1.0): 80 * 2.0 = 160
```

## 修复效果对比

| 方面 | 修复前 | 修复后 |
|------|--------|--------|
| **大刀激活伸展** | 28 + 15 = 43 | 32 + 37.5 = 69.5 (+62%) |
| **长矛刺击距离** | 40 | 100 (+150%) |
| **长矛握持** | 握在矛头 | 握在矛杆 ✓ |
| **视觉冲击感** | 一般 | 强烈 |
| **动作流畅性** | 基础 | 流畅自然 |

## 测试建议

### 1. 大刀测试

```
步骤:
1. 装备大刀
2. 执行挥砍攻击
3. 观察激活阶段的伸展距离
4. 验证是否有明显的"挥出去"感觉

预期结果:
✓ 激活阶段武器伸展距离明显增加
✓ 看起来像真的在挥舞一把大刀
✓ 身体旋转明显
✓ 动作流畅有力
```

### 2. 长矛测试

```
步骤:
1. 装备长矛
2. 执行刺击攻击
3. 观察左手握点位置
4. 验证刺击距离和穿透感

预期结果:
✓ 左手握在矛杆上，位置正确
✓ 刺击距离大幅增加
✓ 身体前倾明显
✓ 有明显的"刺出去"感觉
```

### 3. 双手武器协调测试

```
步骤:
1. 装备大刀或双刃剑
2. 执行各种攻击
3. 观察左右手的协调性
4. 验证握点是否始终对齐

预期结果:
✓ 左右手始终握在武器上
✓ 左手握点与武器旋转同步
✓ 双手协调感强
```

## 已知限制

1. 武器长度系数有上下限（0.8-1.8），防止过度伸展
2. 伸展距离受手臂长度限制（物理约束）
3. 动量系数固定，不会根据武器重量调整

## 未来改进方向

1. 根据武器重量动态调整动量系数
2. 支持不同的握持方式（单手、双手、反握）
3. 添加武器特效（如大刀的挥舞风效）
4. 支持连击时的手臂过渡动画

## 相关文件修改

- `scripts/combat/combat_animator.gd` - 增加武器长度系数，优化挥砍和刺击参数
- `scripts/combat/player_visuals.gd` - 使用武器数据中的握点
- `resources/combat/weapon_data.gd` - 定义握点偏移（已有）

## 总结

这次优化通过以下方式显著改进了大刀、双刃剑和长矛的攻击动作：

1. ✅ **动态武器长度系数**: 根据武器长度自动调整挥舞和刺击幅度
2. ✅ **大幅增加伸展距离**: 激活阶段的伸展距离增加 50-150%
3. ✅ **修复长矛握持**: 左手握点精确对齐到武器杆
4. ✅ **增强视觉冲击**: 大刀和长矛现在有明显的"挥出去"和"刺出去"的感觉
5. ✅ **保持动画流畅**: 所有改进都基于缓动函数，动画仍然流畅自然

现在大刀、双刃剑和长矛的攻击动作应该看起来更加生动有力，能够给玩家带来更好的战斗体验。
