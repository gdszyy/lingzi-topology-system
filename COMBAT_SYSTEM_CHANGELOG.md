# 战斗系统修正更新日志

**更新日期**: 2026-01-12

## 概述

本次更新根据原始设计需求对战斗系统进行了全面优化，主要实现了以下核心功能：

1. **武器惯性物理系统** - 使用弹簧-阻尼模型模拟武器的物理惯性
2. **攻击前置恢复机制** - 攻击前武器先回正到起始位置
3. **双手武器正反手攻击** - 支持正向/反向挥砍的智能切换
4. **飞行加速度控制** - 飞行时方向键控制加速度而非直接速度
5. **角速度物理系统** - 转身速度有上限，站定时加成更高

---

## 新增文件

### `scripts/combat/weapon_physics.gd`

武器惯性物理系统的核心实现。

**主要功能**:
- 弹簧-阻尼模型驱动武器位置和旋转
- 根据武器重量自动调整物理参数
- 支持武器稳定状态检测
- 提供冲量施加接口

**关键参数**:
| 参数 | 默认值 | 说明 |
|------|--------|------|
| `position_stiffness` | 200.0 | 位置弹簧刚度 |
| `position_damping` | 25.0 | 位置阻尼系数 |
| `rotation_stiffness` | 150.0 | 旋转弹簧刚度 |
| `rotation_damping` | 20.0 | 旋转阻尼系数 |

---

## 修改文件

### `resources/combat/attack_data.gd`

**新增字段**:
- `attack_direction: AttackDirection` - 攻击方向枚举（正向/反向/刺击等）
- `windup_start_position: Vector2` - 前摇开始时武器的位置
- `windup_start_rotation: float` - 前摇开始时武器的旋转角度
- `requires_repositioning: bool` - 是否需要武器回正
- `reposition_time_multiplier: float` - 武器回正时间倍率
- `preferred_next_direction: AttackDirection` - 连击时优选的下一个攻击方向

**新增方法**:
- `get_reposition_target_position()` - 获取武器回正的目标位置
- `get_reposition_target_rotation()` - 获取武器回正的目标旋转
- `is_weapon_position_suitable()` - 检查当前武器位置是否适合执行此攻击

**新增静态工厂方法**:
- `create_default_reverse_slash()` - 创建反手挥砍攻击
- `create_spear_thrust()` - 创建枪刺攻击
- `create_spear_sweep()` - 创建舞枪攻击

---

### `resources/combat/weapon_data.gd`

**新增字段**:
- `weapon_length: float` - 武器长度，用于计算惯性
- `forward_attacks: Array[AttackData]` - 正向攻击数组
- `reverse_attacks: Array[AttackData]` - 反向攻击数组
- `alternate_attacks: bool` - 是否自动交替正反手攻击
- `last_attack_direction: int` - 运行时状态：上一次攻击方向

**新增方法**:
- `get_optimal_attack_for_weapon_state()` - 根据武器当前状态选择最优攻击
- `toggle_attack_direction()` - 切换攻击方向
- `reset_attack_direction()` - 重置攻击方向

---

### `resources/combat/movement_config.gd`

**新增飞行物理参数**:
- `flight_inertia_factor: float` - 飞行惯性保持因子
- `flight_turn_penalty: float` - 飞行时的转身惩罚
- `flight_acceleration_curve: Curve` - 飞行加速曲线

**新增方法**:
- `get_flight_turn_speed()` - 获取飞行时的转身速度
- `get_flight_acceleration()` - 计算飞行加速度
- `get_flight_friction()` - 计算飞行摩擦力

**新增静态工厂方法**:
- `create_light()` - 创建轻装配置
- `create_heavy()` - 创建重装配置
- `create_flight_focused()` - 创建飞行专精配置

---

### `scripts/combat/player_visuals.gd`

**主要变更**:
- 集成 `WeaponPhysics` 节点
- 武器挥舞现在由物理系统驱动
- 新增武器回正相关方法

**新增方法**:
- `start_weapon_repositioning()` - 开始武器回正
- `is_weapon_settled()` - 检查武器是否已稳定
- `get_weapon_settle_time()` - 获取武器回正预估时间
- `get_weapon_physics()` - 获取武器物理节点
- `apply_weapon_impulse()` - 施加武器冲量
- `apply_weapon_angular_impulse()` - 施加武器角冲量

---

### `scripts/combat/state_machine/states/attack_windup_state.gd`

**主要变更**:
- 实现两阶段前摇：回正阶段 + 等待阶段
- 根据武器当前位置智能选择攻击

**新增枚举**:
- `Phase { REPOSITIONING, WINDUP }` - 前摇阶段

**新增方法**:
- `_needs_repositioning()` - 检查是否需要武器回正
- `_start_weapon_repositioning()` - 开始武器回正
- `_is_weapon_settled()` - 检查武器是否已到位
- `_select_best_attack()` - 选择最适合当前武器位置的攻击
- `_calculate_attack_suitability()` - 计算攻击适合度

---

### `scripts/combat/state_machine/states/attack_active_state.gd`

**主要变更**:
- 集成武器物理系统
- 攻击时施加角冲量增强挥舞感

---

### `scripts/combat/state_machine/states/attack_recovery_state.gd`

**主要变更**:
- 恢复阶段允许旋转
- 武器自动回到休息位置

---

### `scripts/combat/state_machine/states/fly_state.gd`

**主要变更**:
- 实现加速度控制的飞行物理
- 方向键控制推进力而非直接速度
- 具有惯性滑行效果

**新增方法**:
- `_apply_flight_physics()` - 应用飞行物理
- `_apply_flight_rotation()` - 应用飞行时的旋转
- `get_flight_speed()` - 获取当前飞行速度
- `get_flight_direction()` - 获取飞行方向

---

### `scripts/combat/state_machine/states/turn_state.gd`

**主要变更**:
- 实现角速度物理系统
- 角速度有上限和加速度
- 站定时转身更快
- 垂直移动时有转身加成

**新增方法**:
- `_get_max_angular_velocity()` - 计算最大角速度
- `_apply_angular_physics()` - 应用角速度物理
- `get_angular_velocity()` - 获取当前角速度
- `get_remaining_angle()` - 获取剩余转身角度

---

### `scripts/combat/weapon_presets.gd`

**主要变更**:
- 所有武器预设添加了攻击回正位置信息
- 双手武器添加了正反向攻击数组

---

### `scenes/player/player.tscn`

**主要变更**:
- 添加 `WeaponPhysics` 节点
- 调整节点层级结构：武器精灵现在是 `WeaponPhysics` 的子节点

**新节点结构**:
```
Visuals/TorsoPivot/WeaponRig/WeaponPhysics/MainHandWeapon
Visuals/TorsoPivot/WeaponRig/WeaponPhysics/OffHandWeapon
```

---

### `scripts/combat/player_controller.gd`

**新增信号**:
- `weapon_settled` - 武器物理系统稳定信号

---

## 使用说明

### 武器惯性物理

武器惯性物理系统会自动根据武器重量调整响应速度：
- **重武器**（如大刀）：响应较慢，但挥舞有力
- **轻武器**（如匕首）：响应迅速，但惯性小

### 攻击前置恢复

攻击时，系统会自动检查武器当前位置：
1. 如果武器已经接近攻击起始位置，直接进入前摇
2. 如果武器位置偏差较大，先进行回正，然后再开始前摇

### 双手武器正反手攻击

对于双手武器（如大刀、双刃剑）：
- 左键：根据上一次攻击方向自动选择正向或反向攻击
- 右键：强制使用特定攻击（如重击或刺击）
- 系统会智能选择最适合当前武器位置的攻击方向

### 飞行物理

飞行时（按住空格）：
- 方向键控制推进力（加速度），而非直接速度
- 松开方向键后会惯性滑行
- 速度越快，加速度越低（模拟空气阻力）
- 转身速度有惩罚

---

## 后续优化建议

1. **IK骨骼系统** - 实现手臂跟随武器的IK动画
2. **武器轨迹碰撞** - 基于武器挥舞轨迹的精确碰撞检测
3. **攻击曲线编辑器** - 可视化编辑攻击动作曲线
4. **武器特效系统** - 武器挥舞时的拖尾和光效
