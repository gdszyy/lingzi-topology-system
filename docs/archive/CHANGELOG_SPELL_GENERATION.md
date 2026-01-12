# 法术生成系统增强 - 变更日志

## 概述

本次更新实现了以下核心功能：

1. **按场景分类生成法术**：每个场景生成2个法术
2. **批量差异化生成**：点击一次生成3批，每批计算相似度和差异值
3. **Cost平衡机制**：确保100 cost限制支持1-4层嵌套
4. **沙包敌人测试场景**：不会死亡、持续移动的测试目标

---

## 新增文件

### 1. `scripts/core/batch_spell_generator.gd`

批量差异化法术生成器，核心功能：

```gdscript
# 配置常量
const SPELLS_PER_SCENARIO: int = 2          # 每个场景生成的法术数量
const BATCHES_PER_CLICK: int = 3            # 每次点击生成的批次数
const MIN_DIVERSITY_THRESHOLD: float = 0.4  # 最小差异阈值
const MAX_GENERATION_ATTEMPTS: int = 20     # 单个法术最大生成尝试次数
```

**主要方法**：
- `generate_all_batches()` - 生成所有场景的法术（3批）
- `_generate_single_batch()` - 生成单批法术
- `_generate_spells_for_scenario_with_diversity()` - 为指定场景生成差异化法术
- `_calculate_diversity_score()` - 计算法术与现有法术的差异度
- `get_batch_statistics()` - 获取批次统计信息

### 2. `scenes/battle_test/entities/dummy_enemy.gd`

沙包敌人脚本，特点：
- **不会死亡**：`take_damage()` 只记录伤害，不减少生命值
- **持续移动**：5种移动模式
- **实时统计**：显示累计伤害和命中次数

```gdscript
enum MovePattern {
    PATROL,           # 巡逻（来回移动）
    CIRCULAR,         # 圆周运动
    FIGURE_EIGHT,     # 8字形运动
    RANDOM_WALK,      # 随机游走
    ORBIT             # 围绕中心点轨道运动
}
```

### 3. `scenes/battle_test/entities/dummy_enemy.tscn`

沙包敌人场景文件，蓝色六边形外观（区别于普通敌人的红色）。

---

## 修改文件

### 1. `scenes/battle_test/battle_test_scene.gd`

**新增功能**：
- 添加 `TestScenario.DUMMY_TARGETS` 沙包测试场景
- 添加 `generate_batch_button` 批量生成按钮
- 添加 `_on_generate_batch_pressed()` 批量生成回调
- 添加 `_spawn_dummy_enemy()` 沙包敌人生成方法
- 沙包场景统计显示

### 2. `scenes/battle_test/battle_test_scene.tscn`

- 添加 "批量生成法术 (3批)" 按钮
- 更新提示文字

### 3. `scripts/core/scenario_spell_generator.gd`

**Cost平衡机制**：

```gdscript
const COST_BUDGET: Dictionary = {
    1: {"main": 80.0, "child": 40.0},   # 1层嵌套
    2: {"main": 60.0, "child": 30.0},   # 2层嵌套
    3: {"main": 45.0, "child": 22.0},   # 3层嵌套
    4: {"main": 35.0, "child": 15.0}    # 4层嵌套
}
```

**新增方法**：
- `_decide_nesting_depth()` - 根据场景决定嵌套层数
- `_generate_nested_child_spell()` - 生成可嵌套的子法术
- `_generate_chain_child_spell()` - 生成链式子法术

### 4. `scripts/evaluation/fitness_config.gd`

**新增配置**：

```gdscript
## 嵌套 Cost 预算
@export var layer_1_budget: float = 80.0
@export var layer_2_budget: float = 60.0
@export var layer_3_budget: float = 45.0
@export var layer_4_budget: float = 35.0
@export var child_cost_decay: float = 0.4
@export var child_cost_decay_rate: float = 1.5

## 嵌套深度奖励
@export var nesting_depth_bonus: float = 15.0
@export var nesting_depth_multiplier: float = 1.3
```

**新增方法**：
- `get_layer_budget()` - 获取指定嵌套层数的cost预算
- `get_child_cost_ratio()` - 计算子法术的cost系数
- `create_deep_nesting_focused()` - 创建支持深层嵌套的配置

---

## 使用说明

### 批量生成法术

1. 打开法术测试场景
2. 点击左侧面板的 **"批量生成法术 (3批)"** 按钮
3. 系统将自动生成 3批 × 5场景 × 2法术 = **30个法术**
4. 右侧面板显示生成统计（差异度、嵌套分布等）

### 沙包测试场景

1. 在场景选择下拉框中选择 **"沙包测试 (不死亡)"**
2. 点击 **"开始测试"**
3. 观察各沙包的伤害统计
4. 沙包不会死亡，可以持续测试法术效果

### 场景与嵌套深度对应

| 场景 | 倾向嵌套深度 | 说明 |
|------|-------------|------|
| 牵制消耗 | 1-2层 | 简单快速，低cost |
| 单体远程 | 1-3层 | 中等复杂度 |
| 近战法术 | 2-3层 | 复杂，多效果 |
| 群伤法术 | 2-4层 | 最复杂，裂变+AOE |
| 埋伏法术 | 1-3层 | 中等复杂度 |

---

## 技术细节

### 差异度计算

差异度评分综合考虑：
- 与现有法术的最小距离（权重60%）
- 与现有法术的平均距离（权重40%）
- 同场景法术差异要求更高（系数0.8）

### Cost计算公式

```
总Cost = 载体Cost + Σ规则Cost

载体Cost = mass×2 + velocity×0.008 + homing×8 + piercing×4

规则Cost = 1.5 + Σ动作Cost

动作Cost:
- 伤害: damage × multiplier × 0.3
- 裂变: spawn_count × 2.5 + 子法术Cost × 衰减系数
- AOE: radius × 0.08 + damage × 0.25
- 状态: duration × 0.8 + value × 0.3
```

### 子法术Cost衰减

```
衰减系数 = 0.4 / (1.5 ^ depth)

示例：
- 第1层子法术: 0.4 / 1.5 = 0.267
- 第2层子法术: 0.4 / 2.25 = 0.178
- 第3层子法术: 0.4 / 3.375 = 0.119
```

---

## 后续计划

完成基础需求后，可考虑添加以下新场景：
- **防御法术**：护盾、反弹类
- **控制法术**：减速、冰冻为主
- **召唤法术**：召唤多个独立实体
- **链式法术**：连锁反应类型

这些新场景需要设计新的规则机制，待用户确认后实现。
