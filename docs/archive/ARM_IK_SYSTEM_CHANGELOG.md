# 手臂 IK 系统更新日志

**更新日期**: 2026-01-12

## 概述

本次更新为角色添加了完整的手臂 IK（逆向运动学）系统，实现了手臂跟随武器挥舞的效果。这解决了之前角色没有手臂渲染的问题。

---

## 新增文件

### `scripts/combat/arm_ik_controller.gd`

手臂 IK 控制器的核心实现。

**主要功能**:
- 使用 Two-Bone IK 算法解算手臂姿态
- 手臂自动跟随武器握点位置
- 支持左右手臂独立控制
- 使用 Line2D 绘制手臂，Sprite2D 绘制手部
- 平滑的 IK 过渡动画

**关键参数**:

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `upper_arm_length` | 18.0 | 上臂长度（肩到肘） |
| `forearm_length` | 16.0 | 前臂长度（肘到手） |
| `arm_color` | Color(0.9, 0.75, 0.6) | 手臂颜色（肤色） |
| `arm_width` | 6.0 | 手臂宽度 |
| `left_shoulder_offset` | Vector2(-12, 0) | 左肩相对于躯干的偏移 |
| `right_shoulder_offset` | Vector2(12, 0) | 右肩相对于躯干的偏移 |
| `ik_smoothing` | 15.0 | IK 平滑系数 |
| `elbow_bend_direction` | 1.0 | 肘部弯曲方向 (1=向外, -1=向内) |

**公开方法**:

| 方法 | 说明 |
|------|------|
| `set_hand_target(hand, target)` | 手动设置手部目标位置 |
| `get_hand_position(hand)` | 获取手部当前位置 |
| `get_elbow_position(hand)` | 获取肘部当前位置 |
| `set_arm_visible(visible)` | 设置手臂可见性 |
| `set_arm_color(color)` | 设置手臂颜色 |
| `set_arm_width(width)` | 设置手臂宽度 |
| `configure_for_weapon(weapon)` | 根据武器类型配置手臂 |

---

## 修改文件

### `scenes/player/player.tscn`

**主要变更**:
- 添加 `ArmIKController` 节点作为 `TorsoPivot` 的子节点
- 新增脚本引用 `arm_ik_controller.gd`

**新节点结构**:
```
Visuals/TorsoPivot/ArmIKController  # 手臂 IK 控制器
  ├── LeftUpperArm (Line2D)         # 左上臂
  ├── LeftForearm (Line2D)          # 左前臂
  ├── LeftHand (Sprite2D)           # 左手
  ├── RightUpperArm (Line2D)        # 右上臂
  ├── RightForearm (Line2D)         # 右前臂
  └── RightHand (Sprite2D)          # 右手
```

### `scripts/combat/player_visuals.gd`

**主要变更**:
- 添加 `arm_ik_controller` 引用
- 在 `_ready()` 中调用 `_setup_arm_ik()` 初始化手臂
- 在 `_on_weapon_changed()` 中更新手臂配置

**新增方法**:

| 方法 | 说明 |
|------|------|
| `_setup_arm_ik()` | 初始化手臂 IK 控制器 |
| `get_arm_ik_controller()` | 获取手臂 IK 控制器引用 |
| `set_arms_visible(visible)` | 设置手臂可见性 |
| `set_arms_color(color)` | 设置手臂颜色 |

---

## 技术实现

### Two-Bone IK 算法

手臂使用经典的 Two-Bone IK 算法：

1. **输入**：肩部位置、手部目标位置、上臂长度、前臂长度
2. **计算**：使用余弦定理计算肘部角度
3. **输出**：肘部位置

```gdscript
## 使用余弦定理计算肘部角度
## a = upper_len, b = distance, c = lower_len
## cos(A) = (b² + a² - c²) / (2ab)
var cos_angle = (distance * distance + upper_len * upper_len - lower_len * lower_len) / (2.0 * distance * upper_len)
```

### 武器握点跟随

手臂会自动跟随武器的握点位置：

1. 从 `WeaponPhysics` 获取武器当前旋转
2. 从 `WeaponData` 获取握点偏移（`grip_point_main`, `grip_point_off`）
3. 将握点从武器本地坐标转换到躯干坐标系
4. 使用 IK 解算手臂姿态

### 不同武器类型的手臂配置

| 武器类型 | 左手行为 | 右手行为 |
|----------|----------|----------|
| 单手武器 | 放松在身侧 | 握住武器 |
| 双手武器 | 握住武器副握点 | 握住武器主握点 |
| 双持武器 | 握住副手武器 | 握住主手武器 |
| 无武器 | 放松在身侧 | 放松在身侧 |

---

## 使用说明

### 调整手臂外观

可以通过编辑器或代码调整手臂外观：

```gdscript
# 获取手臂控制器
var arm_ik = player_visuals.get_arm_ik_controller()

# 设置手臂颜色
arm_ik.set_arm_color(Color(0.8, 0.6, 0.5))

# 设置手臂宽度
arm_ik.set_arm_width(8.0)

# 隐藏手臂
arm_ik.set_arm_visible(false)
```

### 自定义武器握点

在 `WeaponData` 资源中设置握点位置：

```gdscript
weapon.grip_point_main = Vector2(20, 0)  # 主手握点
weapon.grip_point_off = Vector2(5, 0)    # 副手握点
```

---

## 后续优化建议

1. **手指动画** - 添加手指骨骼，实现握拳/张开动画
2. **手臂碰撞** - 添加手臂与环境的碰撞检测
3. **动态手臂长度** - 根据角色体型调整手臂长度
4. **手臂受伤效果** - 手臂受伤时的视觉反馈
5. **IK 约束** - 添加肘部角度限制，避免不自然的姿态
