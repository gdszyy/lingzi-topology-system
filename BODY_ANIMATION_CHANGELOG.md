# 全身骨骼动画系统更新日志

## 版本 1.0.0 - 2026-01-12

### 新增功能

#### BodyAnimationController - 全身骨骼动画控制器

新增 `BodyAnimationController` 类，用于管理角色在移动和飞行时的全身骨骼动画效果。

**核心特性：**

1. **动画状态管理**
   - `IDLE` - 待机状态，带有轻微的呼吸动画
   - `WALKING` - 行走状态，手臂交替摆动
   - `RUNNING` - 奔跑状态，更大幅度的手臂摆动和躯干前倾
   - `FLYING` - 飞行状态，手臂向两侧展开并随风波动
   - `FLYING_FAST` - 高速飞行状态，手臂向后掠，身体大幅前倾
   - `ATTACKING` - 攻击状态（由 CombatAnimator 控制）

2. **行走动画**
   - 手臂交替前后摆动，模拟自然行走
   - 躯干轻微上下摆动和左右摇摆
   - 头部随躯干轻微摆动
   - 动画幅度与移动速度成正比

3. **奔跑动画**
   - 更大幅度的手臂摆动
   - 手臂弯曲更多，位置更靠近身体
   - 躯干根据移动方向前倾
   - 增强的头部稳定性

4. **飞行动画**
   - 手臂向两侧展开，模拟滑翔姿态
   - 手臂带有波动效果，模拟气流影响
   - 躯干根据飞行方向倾斜
   - 头部轻微倾斜

5. **高速飞行动画**
   - 手臂向后掠，贴近身体
   - 身体大幅前倾，减少空气阻力
   - 更流线型的姿态
   - 速度阈值：350 像素/秒

6. **与攻击动画的协调**
   - 当 `CombatAnimator` 播放攻击动画时，自动暂停移动/飞行动画
   - 攻击结束后平滑恢复到当前状态的动画
   - 完全不影响攻击动画的表现

### 配置参数

所有动画参数都可以通过 `@export` 变量进行调整：

```gdscript
## 行走动画参数
walk_arm_swing_amplitude: float = 12.0      # 手臂摆动幅度
walk_torso_bob_amplitude: float = 2.0       # 躯干上下摆动幅度
walk_torso_sway_amplitude: float = 0.05     # 躯干左右摇摆幅度
walk_head_bob_amplitude: float = 1.0        # 头部摆动幅度

## 奔跑动画参数
run_arm_swing_amplitude: float = 18.0       # 手臂摆动幅度
run_torso_bob_amplitude: float = 3.0        # 躯干上下摆动幅度
run_torso_lean_max: float = 0.15            # 躯干前倾最大角度
run_head_bob_amplitude: float = 1.5         # 头部摆动幅度

## 飞行动画参数
flight_arm_spread_angle: float = 0.8        # 手臂展开角度
flight_arm_wave_amplitude: float = 8.0      # 手臂波动幅度
flight_arm_wave_speed: float = 3.0          # 手臂波动速度
flight_torso_lean_factor: float = 0.2       # 躯干倾斜因子
flight_torso_lean_max: float = 0.4          # 躯干最大倾斜角度
flight_head_tilt_factor: float = 0.1        # 头部倾斜因子

## 高速飞行动画参数
fast_flight_arm_back_angle: float = 1.2     # 手臂后掠角度
fast_flight_torso_lean: float = 0.5         # 躯干前倾角度
fast_flight_speed_threshold: float = 350.0  # 高速飞行速度阈值

## 过渡参数
state_transition_speed: float = 8.0         # 状态过渡速度
arm_smoothing: float = 12.0                 # 手臂平滑度
```

### 修改的文件

1. **scripts/combat/body_animation_controller.gd** (新增)
   - 全身骨骼动画控制器的完整实现

2. **scripts/combat/player_visuals.gd** (修改)
   - 集成 `BodyAnimationController`
   - 添加增强的腿部动画
   - 优化躯干动画与新系统的协调

3. **scripts/combat/combat_animator.gd** (修改)
   - 添加与 `BodyAnimationController` 的协作机制
   - 当移动/飞行动画活跃时不更新 idle 状态

### 技术细节

#### 动画系统架构

```
PlayerVisuals
├── BodyAnimationController (移动/飞行动画)
│   ├── 手臂位置控制
│   ├── 躯干动画
│   └── 头部动画
├── CombatAnimator (攻击动画)
│   ├── 手臂位置控制
│   └── 武器旋转控制
└── 腿部动画 (内置)
```

#### 优先级机制

1. 攻击动画具有最高优先级
2. 当 `CombatAnimator.is_playing()` 返回 `true` 时：
   - `BodyAnimationController` 暂停更新
   - `CombatAnimator` 完全控制手臂
3. 攻击结束后，`BodyAnimationController` 恢复控制

#### 平滑过渡

- 使用 `lerp` 进行位置插值
- 手臂平滑度：12.0（可配置）
- 状态过渡速度：8.0（可配置）
- 确保不同状态间的动画切换流畅自然

### 使用示例

```gdscript
# 获取动画控制器
var body_anim = player.visuals.get_body_animation_controller()

# 检查当前状态
var state = body_anim.get_current_state()
if state == BodyAnimationController.AnimationState.FLYING:
    print("角色正在飞行")

# 获取速度因子
var speed_factor = body_anim.get_speed_factor()

# 检查是否正在播放移动动画
if body_anim.is_movement_animation_active():
    print("移动动画活跃中")
```

### 注意事项

1. **不影响攻击动画**：系统设计确保攻击动画不受影响
2. **性能优化**：使用增量更新，避免每帧重新计算所有值
3. **可扩展性**：可以轻松添加新的动画状态或调整现有参数
4. **向后兼容**：现有代码无需修改即可使用新功能

### 后续计划

- [ ] 添加受伤时的动画反馈
- [ ] 添加施法时的手臂动画
- [ ] 支持不同武器类型的待机姿势
- [ ] 添加跳跃/落地动画
- [ ] 支持自定义动画曲线
