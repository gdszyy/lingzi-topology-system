# 武器攻击移动配置指南

## 概述

本文档定义了不同武器类型在攻击时的移动速度和加速度修正值。这些值会影响玩家在攻击时的移动能力，从而影响战斗的流畅性和平衡性。

## 配置参数说明

### 武器级别参数
- `attack_move_speed_modifier`: 攻击时移动速度修正（0.0-1.0）
  - 1.0 = 无惩罚，可以全速移动
  - 0.0 = 完全无法移动
  
- `attack_acceleration_modifier`: 攻击时加速度修正（0.0-1.0）
  - 1.0 = 无惩罚，正常加速
  - 0.0 = 无法加速

### 攻击级别参数（可选覆盖）
- `windup_move_speed_modifier`: 前摇阶段移动速度修正（-1 表示使用武器默认值）
- `active_move_speed_modifier`: 激活阶段移动速度修正（-1 表示使用武器默认值）
- `recovery_move_speed_modifier`: 恢复阶段移动速度修正（-1 表示使用武器默认值）

## 武器类型配置建议

### 1. 匕首 (Dagger)
**特点**: 轻巧灵活，攻击快速

**推荐配置**:
```gdscript
attack_move_speed_modifier = 0.85  # 攻击时可以保持85%的移动速度
attack_acceleration_modifier = 0.90  # 加速度降低10%
```

**设计理念**: 匕首是最灵活的武器，攻击时几乎不影响移动，适合游走战术。

---

### 2. 单手剑 (Sword)
**特点**: 平衡的攻击和移动

**推荐配置**:
```gdscript
attack_move_speed_modifier = 0.70  # 攻击时保持70%的移动速度
attack_acceleration_modifier = 0.75  # 加速度降低25%
```

**设计理念**: 单手剑是标准武器，提供平衡的攻击和移动能力。

---

### 3. 双刀 (Dual Blade)
**特点**: 连击流畅，移动灵活

**推荐配置**:
```gdscript
attack_move_speed_modifier = 0.75  # 攻击时保持75%的移动速度
attack_acceleration_modifier = 0.80  # 加速度降低20%
```

**设计理念**: 双刀比单手剑稍快，适合连续攻击和走位。

---

### 4. 长枪 (Spear)
**特点**: 攻击范围长，但移动受限

**推荐配置**:
```gdscript
attack_move_speed_modifier = 0.55  # 攻击时保持55%的移动速度
attack_acceleration_modifier = 0.65  # 加速度降低35%
```

**特殊配置**: 刺击攻击时可以移动更快
```gdscript
# 对于刺击攻击 (Thrust)
windup_move_speed_modifier = 0.70  # 前摇阶段可以快速前进
active_move_speed_modifier = 0.40  # 激活阶段移动受限
recovery_move_speed_modifier = 0.60  # 恢复阶段可以后退
```

**设计理念**: 长枪攻击时移动受限，但刺击时可以快速前进。

---

### 5. 巨剑 (Greatsword)
**特点**: 重型武器，攻击强力但移动缓慢

**推荐配置**:
```gdscript
attack_move_speed_modifier = 0.45  # 攻击时保持45%的移动速度
attack_acceleration_modifier = 0.55  # 加速度降低45%
```

**特殊配置**: 不同攻击阶段差异明显
```gdscript
# 重击攻击 (Smash)
windup_move_speed_modifier = 0.50  # 前摇阶段可以调整位置
active_move_speed_modifier = 0.30  # 激活阶段几乎无法移动
recovery_move_speed_modifier = 0.40  # 恢复阶段移动缓慢
```

**设计理念**: 巨剑攻击时移动大幅受限，强调攻击的重量感和预判。

---

### 6. 法杖 (Staff)
**特点**: 远程攻击，移动灵活

**推荐配置**:
```gdscript
attack_move_speed_modifier = 0.80  # 攻击时保持80%的移动速度
attack_acceleration_modifier = 0.85  # 加速度降低15%
```

**设计理念**: 法杖攻击时移动受限较小，适合边移动边施法。

---

### 7. 徒手 (Unarmed)
**特点**: 最灵活，攻击快速

**推荐配置**:
```gdscript
attack_move_speed_modifier = 0.90  # 攻击时保持90%的移动速度
attack_acceleration_modifier = 0.95  # 加速度降低5%
```

**设计理念**: 徒手攻击几乎不影响移动，最灵活的战斗方式。

---

## 配置平衡性原则

### 1. 武器重量与移动惩罚成正比
- 轻武器（匕首、徒手）：0.85-0.90
- 中等武器（单手剑、双刀、法杖）：0.70-0.80
- 重武器（长枪、巨剑）：0.45-0.55

### 2. 攻击类型影响移动
- 快速攻击（刺击、轻击）：惩罚较小
- 重型攻击（重击、横扫）：惩罚较大

### 3. 攻击阶段差异
- 前摇阶段：可以有较高的移动能力（调整位置）
- 激活阶段：移动能力最低（攻击发力）
- 恢复阶段：中等移动能力（撤退或追击）

### 4. 游戏风格考虑
- **快节奏战斗**: 提高所有武器的移动修正（+0.1-0.15）
- **慢节奏战斗**: 降低所有武器的移动修正（-0.1-0.15）
- **硬核模式**: 大幅降低移动修正，强调预判和定位

## 实际应用示例

### 示例 1: 匕首快速连击
```gdscript
# 武器配置
weapon.attack_move_speed_modifier = 0.85
weapon.attack_acceleration_modifier = 0.90

# 所有攻击使用默认值
# 玩家可以在整个连击过程中保持高移动能力
```

### 示例 2: 巨剑重击
```gdscript
# 武器配置
weapon.attack_move_speed_modifier = 0.45
weapon.attack_acceleration_modifier = 0.55

# 重击攻击特殊配置
smash_attack.windup_move_speed_modifier = 0.50  # 前摇可以调整位置
smash_attack.active_move_speed_modifier = 0.30  # 激活时几乎无法移动
smash_attack.recovery_move_speed_modifier = 0.40  # 恢复时移动缓慢
```

### 示例 3: 长枪刺击
```gdscript
# 武器配置
weapon.attack_move_speed_modifier = 0.55
weapon.attack_acceleration_modifier = 0.65

# 刺击攻击特殊配置
thrust_attack.windup_move_speed_modifier = 0.70  # 前摇可以快速前进
thrust_attack.active_move_speed_modifier = 0.40  # 激活时移动受限
thrust_attack.recovery_move_speed_modifier = 0.60  # 恢复时可以后退
```

## 测试和调整

### 测试清单
1. ✅ 每种武器的攻击移动感觉是否符合预期
2. ✅ 不同武器之间的移动差异是否明显
3. ✅ 攻击阶段的移动差异是否合理
4. ✅ 是否能够边攻击边追击敌人
5. ✅ 是否能够边攻击边躲避攻击

### 调整建议
- 如果武器感觉太"笨重"，提高 `attack_move_speed_modifier`
- 如果武器感觉太"轻飘"，降低 `attack_move_speed_modifier`
- 如果攻击时无法调整位置，提高 `windup_move_speed_modifier`
- 如果攻击时移动过快失去重量感，降低 `active_move_speed_modifier`

## 配置文件位置

### 武器数据文件
- 路径: `resources/combat/weapon_data.gd`
- 在 `@export_group("Attack Movement")` 部分配置

### 攻击数据文件
- 路径: `resources/combat/attack_data.gd`
- 在 `@export_group("Attack Movement Modifiers")` 部分配置

### 移动配置文件
- 路径: `resources/combat/movement_config.gd`
- 在 `@export_group("Attack Movement")` 部分配置默认值

## 总结

通过精细调整每种武器和攻击的移动修正值，可以创造出独特的战斗体验。轻武器强调灵活性和走位，重武器强调预判和定位。合理的配置能够让每种武器都有独特的手感和战术价值。
