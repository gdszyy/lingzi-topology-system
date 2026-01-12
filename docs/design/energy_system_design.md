# 能量系统设计文档

## 1. 核心概念

基于用户提出的修行设定，我们引入了一套新的能量系统来替代传统的生命值（HP）系统。该系统围绕以下核心属性展开：

| 属性名称 | 英文名 | 说明 |
|---------|--------|------|
| 当前能量 | Current Energy | 修行者当前拥有的能量，是施展法术、进行修复等所有活动的基础资源 |
| 当前能量上限 | Current Energy Cap | 代表修行者当前能够承受的能量上限。受到攻击会损伤此上限，相当于传统的"生命值" |
| 最大能量上限 | Max Energy Cap | 由修行者的"修为"决定，是"当前能量上限"所能达到的理论最大值 |
| 能量伤害转化比 | Damage Conversion Ratio | 定义了外部伤害如何转化为对"当前能量上限"的损伤 |
| 能量吸收效率 | Energy Absorption Rate | 修行者从周围环境中被动吸收能量的速度 |
| 基础修炼效率 | Cultivation Energy Cost | 修行者通过主动修炼，消耗"当前能量"来修复"当前能量上限"的成本 |

## 2. 战斗逻辑

### 2.1 伤害处理流程

```
外部伤害 → 护盾吸收 → 能量系统处理 → 能量上限损伤
                                    ↓
                            检查是否耗尽（死亡）
```

1. **护盾优先**：如果目标有护盾，伤害首先被护盾吸收
2. **能量转化**：剩余伤害通过 `damage_conversion_ratio` 转化为能量上限损伤
3. **状态检查**：当能量上限降至0时，触发死亡/耗尽事件

### 2.2 恢复机制

| 恢复类型 | 说明 | 触发方式 |
|---------|------|---------|
| 被动能量吸收 | 从环境中持续吸收能量 | 每帧自动执行 |
| 主动修炼 | 消耗当前能量恢复能量上限 | 玩家主动触发或自动修复 |
| 治疗效果 | 直接恢复能量上限 | 法术/技能效果 |
| 能量补充 | 直接恢复当前能量 | 法术/技能效果 |

### 2.3 新增动作类型

为支持能量系统，我们新增了两种动作类型：

**能量恢复动作 (EnergyRestoreActionData)**
- `INSTANT`: 瞬间恢复当前能量
- `OVER_TIME`: 持续恢复当前能量
- `PERCENTAGE`: 按百分比恢复当前能量

**修炼动作 (CultivationActionData)**
- `INSTANT`: 瞬间消耗能量恢复能量上限
- `OVER_TIME`: 持续修复能量上限
- `BOOST`: 临时提升修炼效率

## 3. 数据模型

### 3.1 EnergySystemData (能量系统数据)

位置：`resources/combat/energy_system_data.gd`

```gdscript
class_name EnergySystemData
extends Resource

# 核心属性
@export var current_energy_cap: float = 100.0   # 当前能量上限
@export var max_energy_cap: float = 100.0       # 最大能量上限
@export var current_energy: float = 100.0       # 当前能量

# 效率参数
@export var damage_conversion_ratio: float = 1.0    # 伤害转化比
@export var energy_absorption_rate: float = 5.0     # 能量吸收效率
@export var cultivation_energy_cost: float = 10.0   # 修炼成本
@export var cap_recovery_rate: float = 1.0          # 能量上限恢复速率
@export var auto_cultivation: bool = false          # 是否自动修复

# 信号
signal energy_cap_changed(current_cap, max_cap)
signal current_energy_changed(current, cap)
signal depleted()
```

### 3.2 核心方法

| 方法 | 说明 |
|------|------|
| `take_damage(amount)` | 承受伤害，返回实际能量上限损伤 |
| `absorb_from_environment(delta)` | 从环境吸收能量 |
| `cultivate(delta, intensity)` | 主动修炼，消耗能量恢复能量上限 |
| `consume_energy(amount)` | 消耗能量（用于施法） |
| `restore_energy_cap(amount)` | 直接恢复能量上限 |
| `restore_energy(amount)` | 直接恢复当前能量 |
| `is_depleted()` | 检查是否耗尽 |

## 4. 文件变更清单

| 文件 | 变更类型 | 说明 |
|------|---------|------|
| `resources/combat/energy_system_data.gd` | 新增 | 能量系统数据类 |
| `resources/actions/action_data.gd` | 修改 | 添加新动作类型枚举 |
| `resources/actions/energy_restore_action_data.gd` | 新增 | 能量恢复动作 |
| `resources/actions/cultivation_action_data.gd` | 新增 | 修炼动作 |
| `scripts/combat/player_controller.gd` | 修改 | 集成能量系统 |
| `scripts/combat/action_executor.gd` | 修改 | 支持新动作类型 |
| `scenes/battle_test/entities/enemy.gd` | 修改 | 集成能量系统 |
| `scenes/battle_test/battle_test_scene.gd` | 修改 | 适配新的敌人初始化方式 |

## 5. 向后兼容

为保持与旧代码的兼容性，我们在 `PlayerController` 和 `Enemy` 中保留了以下兼容方法：

```gdscript
# PlayerController
func get_current_health() -> float   # 返回 energy_system.current_energy_cap
func get_max_health() -> float       # 返回 energy_system.max_energy_cap
func get_health_percent() -> float   # 返回 energy_system.get_cap_percent()

# Enemy
var max_health: float   # getter/setter 映射到能量系统
var current_health: float  # getter 映射到能量系统
```

## 6. 使用示例

### 6.1 创建带能量系统的敌人

```gdscript
var enemy = enemy_scene.instantiate() as Enemy
enemy.set_max_energy_cap(150.0)  # 设置能量上限为150
```

### 6.2 玩家施法消耗能量

```gdscript
if player.consume_energy(spell.resource_cost):
    # 能量足够，执行施法
    cast_spell(spell)
else:
    # 能量不足
    show_message("能量不足！")
```

### 6.3 主动修炼恢复

```gdscript
# 在 _process 中持续修炼
func _process(delta):
    if is_cultivating:
        player.cultivate(delta, 1.0)  # 以1.0强度修炼
```

---

*此文档为灵子拓扑系统能量系统设计的技术规范。*
*最后更新：2026-01-12*
