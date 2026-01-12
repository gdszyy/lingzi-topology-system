# 攻击与移动系统修复说明

## 修改日期
2026-01-13

## 问题描述
玩家在进行攻击动作时无法移动，导致战斗体验不够流畅。

## 解决方案
允许玩家在攻击的所有阶段（前摇、激活、恢复）中继续移动，同时添加移动速度惩罚以保持游戏平衡。

## 修改文件清单

### 1. 攻击前摇状态 (Attack Windup State)
**文件**: `scripts/combat/state_machine/states/attack_windup_state.gd`

**修改内容**:
- 第 33 行：`player.can_move = false` → `player.can_move = true`
- 添加注释：`## 【修改】允许攻击时移动`

**影响**:
- 玩家在攻击前摇阶段可以移动
- 可以边蓄力边走位

### 2. 攻击激活状态 (Attack Active State)
**文件**: `scripts/combat/state_machine/states/attack_active_state.gd`

**修改内容**:
- 第 27 行：`player.can_move = false` → `player.can_move = true`
- 添加注释：`## 【修改】允许攻击时移动`

**影响**:
- 玩家在攻击判定阶段可以移动
- 可以边挥舞武器边调整位置

### 3. 攻击恢复状态 (Attack Recovery State)
**文件**: `scripts/combat/state_machine/states/attack_recovery_state.gd`

**修改内容**:
- 第 29 行：`player.can_move = false` → `player.can_move = true`
- 添加注释：`## 【修改】允许攻击时移动`

**影响**:
- 玩家在攻击后摇阶段可以移动
- 可以立即追击或撤退

### 4. 玩家控制器 (Player Controller)
**文件**: `scripts/combat/player_controller.gd`

**修改内容**:
- 在 `_apply_movement()` 函数中添加攻击时的移动速度惩罚（第 226-229 行）
```gdscript
## 【新增】攻击时移动速度惩罚
if is_attacking:
    max_speed *= 0.6  # 攻击时移动速度降低40%
    acceleration *= 0.7  # 攻击时加速度降低30%
```

**影响**:
- 攻击时移动速度降低 40%
- 攻击时加速度降低 30%
- 保持游戏平衡，避免攻击时移动过快

## 游戏体验改进

### 优点
1. **战斗更流畅**: 玩家可以边攻击边走位，不会被"钉"在原地
2. **更高的操作上限**: 熟练玩家可以通过走位优化输出和生存
3. **符合现代动作游戏设计**: 类似《暗黑破坏神》、《哈迪斯》等游戏的设计理念
4. **保持平衡**: 通过速度惩罚避免攻击时移动过快

### 平衡性调整
- 攻击时移动速度降低 40%，确保玩家不能边攻击边全速逃跑
- 攻击时加速度降低 30%，让移动更有"重量感"
- 可以根据测试反馈调整惩罚系数

## 后续优化建议

### 1. 根据武器类型调整速度惩罚
```gdscript
## 示例：轻武器惩罚更小，重武器惩罚更大
if is_attacking:
    var attack_move_penalty = 0.6  # 默认值
    if current_weapon != null:
        attack_move_penalty = current_weapon.attack_move_speed_modifier
    max_speed *= attack_move_penalty
```

### 2. 根据攻击阶段调整速度惩罚
```gdscript
## 示例：前摇阶段惩罚小，激活阶段惩罚大
if is_attacking:
    var penalty = 0.6
    if current_attack_phase == AttackPhase.ACTIVE:
        penalty = 0.4  # 激活阶段移动更慢
    max_speed *= penalty
```

### 3. 添加配置选项
在 `MovementConfig` 中添加可配置的攻击移动惩罚参数：
```gdscript
@export var attack_move_speed_penalty: float = 0.6
@export var attack_acceleration_penalty: float = 0.7
```

## 测试建议

1. **基础移动测试**: 确认攻击时可以正常移动
2. **速度测试**: 确认攻击时移动速度确实降低
3. **连击测试**: 确认连击过程中可以持续移动
4. **不同武器测试**: 测试不同武器的攻击移动体验
5. **飞行攻击测试**: 确认飞行状态下的攻击移动正常

## 回滚方案
如果需要回滚修改，将三个状态文件中的 `player.can_move = true` 改回 `player.can_move = false`，并删除 `player_controller.gd` 中的速度惩罚代码即可。

## 相关文档
- `attack_movement_analysis.md` - 问题分析文档
- `COMBAT_SYSTEM_CHANGELOG.md` - 战斗系统变更日志（建议更新）
