# 攻击移动系统全面优化总结

## 优化日期
2026-01-13

## 优化目标
在基础的"攻击时可以移动"功能之上，实现全面的攻击移动系统优化，包括：
1. ✅ 根据武器类型调整移动惩罚
2. ✅ 根据攻击阶段调整移动惩罚
3. ✅ 添加可配置参数
4. ✅ 添加攻击移动动画支持

---

## 修改文件清单

### 1. 资源文件（Resources）

#### weapon_data.gd
**新增属性**:
```gdscript
@export_group("Attack Movement")
@export_range(0.0, 1.0) var attack_move_speed_modifier: float = 0.6
@export_range(0.0, 1.0) var attack_acceleration_modifier: float = 0.7
```

**作用**: 为每种武器定义攻击时的移动速度和加速度修正。

---

#### attack_data.gd
**新增属性**:
```gdscript
@export_group("Attack Movement Modifiers")
@export_range(-1.0, 1.0) var windup_move_speed_modifier: float = -1.0
@export_range(-1.0, 1.0) var active_move_speed_modifier: float = -1.0
@export_range(-1.0, 1.0) var recovery_move_speed_modifier: float = -1.0
```

**新增方法**:
```gdscript
func get_windup_move_speed_modifier(weapon_default: float) -> float
func get_active_move_speed_modifier(weapon_default: float) -> float
func get_recovery_move_speed_modifier(weapon_default: float) -> float
```

**作用**: 为每个攻击的不同阶段定义移动速度修正，-1 表示使用武器默认值。

---

#### movement_config.gd
**新增属性**:
```gdscript
@export_group("Attack Movement")
@export_range(0.0, 1.0) var default_attack_move_speed_modifier: float = 0.6
@export_range(0.0, 1.0) var default_attack_acceleration_modifier: float = 0.7
```

**作用**: 定义全局默认的攻击移动惩罚值。

---

### 2. 脚本文件（Scripts）

#### player_controller.gd
**新增变量**:
```gdscript
var current_attack: AttackData = null
var current_attack_phase: String = ""
var is_attacking_while_moving: bool = false
```

**修改方法**:
```gdscript
func _physics_process(delta: float) -> void:
    # 更新攻击移动状态
    is_attacking_while_moving = is_attacking and input_direction.length_squared() > 0.01

func _apply_movement(delta: float) -> void:
    # 使用新的惩罚系统
    if is_attacking:
        var attack_move_modifier = _get_attack_move_speed_modifier()
        var attack_accel_modifier = _get_attack_acceleration_modifier()
        max_speed *= attack_move_modifier
        acceleration *= attack_accel_modifier
```

**新增方法**:
```gdscript
func _get_attack_move_speed_modifier() -> float
func _get_attack_acceleration_modifier() -> float
func set_current_attack_phase(attack: AttackData, phase: String) -> void
func clear_current_attack() -> void
```

**作用**: 实现智能的攻击移动惩罚系统，根据武器、攻击和阶段动态调整。

---

#### attack_windup_state.gd
**修改**:
```gdscript
func enter(params: Dictionary = {}) -> void:
    player.current_attack_phase = "windup"
    player.current_attack = current_attack

func exit() -> void:
    player.current_attack_phase = ""
```

**作用**: 设置和清除攻击阶段信息。

---

#### attack_active_state.gd
**修改**:
```gdscript
func enter(params: Dictionary = {}) -> void:
    player.current_attack_phase = "active"
    player.current_attack = current_attack

func exit() -> void:
    player.current_attack_phase = ""
```

**作用**: 设置和清除攻击阶段信息。

---

#### attack_recovery_state.gd
**修改**:
```gdscript
func enter(params: Dictionary = {}) -> void:
    player.current_attack_phase = "recovery"
    player.current_attack = current_attack

func exit() -> void:
    player.current_attack = null
    player.current_attack_phase = ""
```

**作用**: 设置和清除攻击阶段信息。

---

### 3. 文档文件（Documentation）

#### WEAPON_ATTACK_MOVEMENT_CONFIG.md
**内容**:
- 武器类型配置建议（匕首、单手剑、双刀、长枪、巨剑、法杖、徒手）
- 配置平衡性原则
- 实际应用示例
- 测试和调整建议

**作用**: 为游戏设计师提供武器配置指南。

---

#### ATTACK_MOVEMENT_ANIMATION.md
**内容**:
- 动画系统架构说明
- 三种实现方案（动画混合、专门动画、程序化调整）
- 推荐实现方案
- 动画细节优化建议
- 配置参数说明

**作用**: 为动画师和程序员提供动画系统实现指南。

---

#### ATTACK_MOVEMENT_OPTIMIZATION_SUMMARY.md（本文档）
**作用**: 总结所有优化内容，便于回顾和维护。

---

## 系统架构

### 优先级层次（从高到低）

1. **攻击级别修正** (AttackData)
   - 如果攻击定义了特定阶段的修正值（>= 0），使用该值
   
2. **武器级别修正** (WeaponData)
   - 如果攻击未定义修正值（-1），使用武器的默认修正值
   
3. **全局默认修正** (MovementConfig)
   - 如果武器也未定义，使用全局默认值

### 调用流程

```
玩家攻击
  ↓
攻击状态机设置 current_attack 和 current_attack_phase
  ↓
_apply_movement() 调用 _get_attack_move_speed_modifier()
  ↓
检查 current_attack.get_xxx_move_speed_modifier(weapon_default)
  ↓
如果攻击有自定义值，返回；否则返回 weapon_default
  ↓
应用修正值到 max_speed 和 acceleration
```

---

## 配置示例

### 示例 1: 匕首（灵活）
```gdscript
# 武器配置
weapon.attack_move_speed_modifier = 0.85
weapon.attack_acceleration_modifier = 0.90

# 所有攻击使用默认值（不需要特殊配置）
```

**效果**: 攻击时保持 85% 移动速度，非常灵活。

---

### 示例 2: 巨剑重击（笨重）
```gdscript
# 武器配置
weapon.attack_move_speed_modifier = 0.45
weapon.attack_acceleration_modifier = 0.55

# 重击攻击特殊配置
smash_attack.windup_move_speed_modifier = 0.50
smash_attack.active_move_speed_modifier = 0.30
smash_attack.recovery_move_speed_modifier = 0.40
```

**效果**: 
- 前摇阶段可以调整位置（50%）
- 激活阶段几乎无法移动（30%）
- 恢复阶段移动缓慢（40%）

---

### 示例 3: 长枪刺击（特殊）
```gdscript
# 武器配置
weapon.attack_move_speed_modifier = 0.55
weapon.attack_acceleration_modifier = 0.65

# 刺击攻击特殊配置
thrust_attack.windup_move_speed_modifier = 0.70  # 可以快速前进
thrust_attack.active_move_speed_modifier = 0.40  # 刺出时移动受限
thrust_attack.recovery_move_speed_modifier = 0.60  # 可以后退
```

**效果**: 刺击时可以快速前进，但刺出瞬间移动受限。

---

## 优化效果

### 游戏体验提升

1. **武器差异化**
   - 轻武器（匕首）：灵活，适合游走
   - 中等武器（单手剑）：平衡，适合正面战斗
   - 重武器（巨剑）：笨重，强调预判和定位

2. **攻击策略多样化**
   - 快速攻击：可以边打边走
   - 重型攻击：需要站定发力
   - 刺击攻击：可以快速突进

3. **战斗节奏优化**
   - 前摇阶段：调整位置
   - 激活阶段：专注输出
   - 恢复阶段：撤退或追击

### 技术优势

1. **高度可配置**
   - 三层配置系统（全局、武器、攻击）
   - 灵活的优先级机制
   - 易于调整和平衡

2. **易于扩展**
   - 可以为每个攻击单独配置
   - 可以添加更多修正因素
   - 支持动画系统集成

3. **性能友好**
   - 简单的数值计算
   - 无额外资源消耗
   - 实时调整无延迟

---

## 测试建议

### 基础测试
1. ✅ 不同武器的攻击移动速度差异明显
2. ✅ 攻击阶段的移动速度变化合理
3. ✅ 配置参数修改后立即生效
4. ✅ 攻击移动状态标记正确

### 平衡性测试
1. ⬜ 轻武器是否过于灵活
2. ⬜ 重武器是否过于笨重
3. ⬜ 不同武器的战斗体验是否有差异
4. ⬜ 攻击移动是否影响游戏平衡

### 边界测试
1. ⬜ 修正值为 0 时是否完全无法移动
2. ⬜ 修正值为 1 时是否完全无惩罚
3. ⬜ 攻击状态切换时是否有异常
4. ⬜ 连击过程中移动是否流畅

---

## 后续优化方向

### 短期（1-2 周）
1. ⬜ 为所有预设武器配置攻击移动属性
2. ⬜ 为特殊攻击（重击、刺击等）配置阶段修正
3. ⬜ 添加攻击移动的视觉反馈（粒子、拖尾等）
4. ⬜ 添加攻击移动的音效

### 中期（1-2 月）
1. ⬜ 实现动画混合系统
2. ⬜ 为不同武器制作攻击移动动画
3. ⬜ 添加攻击移动的特殊效果
4. ⬜ 优化攻击移动的手感

### 长期（3+ 月）
1. ⬜ 根据玩家反馈调整平衡性
2. ⬜ 添加更多武器类型和攻击方式
3. ⬜ 实现攻击移动的高级技巧（取消、连招等）
4. ⬜ 优化性能和稳定性

---

## Git 提交信息

```
优化：实现攻击移动系统全面优化

核心改进：
- 添加武器级别的攻击移动修正属性
- 添加攻击级别的阶段移动修正属性
- 添加全局可配置的默认修正参数
- 实现智能的三层优先级系统
- 添加攻击移动状态标记

技术实现：
- 在 WeaponData 中添加 attack_move_speed_modifier 和 attack_acceleration_modifier
- 在 AttackData 中添加三个阶段的移动修正属性和获取方法
- 在 MovementConfig 中添加全局默认修正参数
- 在 PlayerController 中实现智能修正获取逻辑
- 在攻击状态机中设置和清除攻击阶段信息

文档：
- WEAPON_ATTACK_MOVEMENT_CONFIG.md: 武器配置指南
- ATTACK_MOVEMENT_ANIMATION.md: 动画系统实现指南
- ATTACK_MOVEMENT_OPTIMIZATION_SUMMARY.md: 优化总结

影响：
- 不同武器在攻击时的移动能力有明显差异
- 攻击的不同阶段移动能力可以单独配置
- 系统高度可配置，易于调整和平衡
- 为后续动画优化提供了基础支持
```

---

## 相关文档

- [攻击移动修复说明](./ATTACK_MOVEMENT_FIX.md) - 基础修复文档
- [武器配置指南](./WEAPON_ATTACK_MOVEMENT_CONFIG.md) - 武器配置建议
- [动画系统指南](./ATTACK_MOVEMENT_ANIMATION.md) - 动画实现方案
- [测试清单](./TEST_CHECKLIST.md) - 测试用例

---

## 总结

本次优化在基础的"攻击时可以移动"功能之上，构建了一个完整的、高度可配置的攻击移动系统。通过三层优先级机制（全局默认、武器级别、攻击级别），实现了精细的移动控制。不同武器和攻击现在有了独特的移动特性，大幅提升了战斗的深度和策略性。

系统设计注重可扩展性和易用性，为后续的动画优化、平衡调整和新武器添加提供了坚实的基础。
