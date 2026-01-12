# 灵子相变状态系统设计文档

## 概述

本文档描述了基于灵子物理学的状态效果系统设计。该系统将传统的游戏状态效果（燃烧、冰冻、中毒等）重新诠释为灵子相变的物理现象，使其更符合《灵子拓扑系统》的世界观设定。

---

## 一、灵子相变理论基础

### 1.1 灵子相态图谱

| 相态 | 物理属性 | 战术/功能 | 核心机制 |
|-----|---------|----------|---------|
| **波态 (Wave)** | 无形、概率云 | 能源捕获 | 概率坍缩 |
| **气态 (Gas)** | 低能、高流动 | 循环滋养 | 渗透作用 |
| **液态 (Fluid)** | 亚稳态、高势能 | 储能/冰攻 | 逆向热力学（吸热） |
| **固态 (Solid)** | 极低熵、结构锁死 | 构筑/动能 | 强相互作用 |
| **等离子 (Plasma)** | 高熵、剧烈跃迁 | 输出/火攻 | 熵增释放（放热） |

### 1.2 相态克制关系

```
等离子 → 固态（熔化）
液态 → 等离子（吸热克制高温）
固态 → 气态（阻挡渗透）
气态 → 波态（干扰共振）
波态 → 液态（概率坍缩稳定）
```

---

## 二、状态效果类型

### 2.1 负面状态（Debuff）

| 状态名称 | 灵子相态 | 效果描述 | 物理原理 |
|---------|---------|---------|---------|
| **熵燃 (ENTROPY_BURN)** | 等离子态 | 持续火焰伤害 | 等离子态灵子释放热量，造成烧蚀 |
| **冷脆化 (CRYO_CRYSTAL)** | 液态 | 冻结 + 降低防御 | 液态灵子强制结晶，掠夺目标热量 |
| **结构锁 (STRUCTURE_LOCK)** | 固态 | 禁止移动（可攻击） | 固态灵子锁死运动结构 |
| **灵蚀 (SPIRITON_EROSION)** | 气态 | 持续伤害 + 降低输出 | 气态灵子渗透侵蚀 |
| **相位紊乱 (PHASE_DISRUPTION)** | 波态 | 降低命中和闪避 | 波态灵子干扰概率场 |
| **共振标记 (RESONANCE_MARK)** | 波态 | 受到额外伤害 | 波态灵子共振锁定 |

### 2.2 正面状态（Buff）

| 状态名称 | 灵子相态 | 效果描述 | 物理原理 |
|---------|---------|---------|---------|
| **灵潮 (SPIRITON_SURGE)** | 等离子态 | 增加伤害输出 | 灵子浓度激增 |
| **相移 (PHASE_SHIFT)** | 波态 | 增加移动速度 | 波态加速 |
| **固壳 (SOLID_SHELL)** | 固态 | 吸收伤害 | 固态灵子护甲 |

---

## 三、相态克制机制

### 3.1 克制效果

当攻击者的灵子相态克制目标的主导相态时，效果值增加 **50%**（默认 `phase_counter_bonus = 1.5`）。

### 3.2 克制示例

| 攻击相态 | 目标相态 | 克制效果 |
|---------|---------|---------|
| 液态（冷脆化） | 等离子态（熵燃中） | 冷脆化伤害 ×1.5 |
| 等离子态（熵燃） | 固态（固壳中） | 熵燃伤害 ×1.5 |
| 固态（结构锁） | 气态（灵蚀中） | 结构锁持续时间 ×1.5 |

### 3.3 主导相态判定

目标的主导相态按以下优先级判定：
1. 等离子态（熵燃状态）
2. 液态（冷脆化状态）
3. 固态（结构锁/固壳状态）
4. 气态（灵蚀状态）
5. 波态（默认）

---

## 四、与旧版状态的映射

为保持向后兼容，提供旧版状态类型到新版的映射：

| 旧版状态 | 新版状态 | 说明 |
|---------|---------|------|
| BURNING | ENTROPY_BURN | 燃烧 → 熵燃 |
| FROZEN | CRYO_CRYSTAL | 冰冻 → 冷脆化 |
| POISONED | SPIRITON_EROSION | 中毒 → 灵蚀 |
| SLOWED | STRUCTURE_LOCK | 减速 → 结构锁 |
| STUNNED | CRYO_CRYSTAL | 眩晕 → 冷脆化 |
| WEAKENED | SPIRITON_EROSION | 虚弱 → 灵蚀 |
| ROOTED | STRUCTURE_LOCK | 束缚 → 结构锁 |
| SILENCED | PHASE_DISRUPTION | 沉默 → 相位紊乱 |
| MARKED | RESONANCE_MARK | 标记 → 共振标记 |
| BLINDED | PHASE_DISRUPTION | 致盲 → 相位紊乱 |
| CURSED | SPIRITON_EROSION | 诅咒 → 灵蚀 |
| EMPOWERED | SPIRITON_SURGE | 强化 → 灵潮 |
| HASTED | PHASE_SHIFT | 加速 → 相移 |
| SHIELDED | SOLID_SHELL | 护盾 → 固壳 |

---

## 五、运行时系统架构

### 5.1 系统组成

```
RuntimeSystemsManager
├── StatusEffectManager    # 状态效果管理
├── ShieldSystem          # 护盾系统
├── ReflectSystem         # 反弹系统
├── DisplacementSystem    # 位移系统
├── ChainSystem           # 链式系统
└── SummonSystem          # 召唤系统
```

### 5.2 使用示例

```gdscript
# 获取运行时系统管理器
var runtime = get_tree().get_first_node_in_group("runtime_systems_manager")

# 应用状态效果
var status = ApplyStatusActionData.new()
status.status_type = ApplyStatusActionData.StatusType.ENTROPY_BURN
status.duration = 5.0
status.effect_value = 10.0
runtime.apply_status(target, status)

# 创建护盾
var shield = ShieldActionData.new()
shield.shield_amount = 100.0
shield.shield_duration = 10.0
runtime.create_shield(player, shield)

# 启动链式攻击
var chain = ChainActionData.new()
chain.chain_count = 5
chain.chain_damage = 30.0
chain.chain_type = ChainActionData.ChainType.LIGHTNING
runtime.start_chain(first_target, chain, source_position)
```

---

## 六、设计原则

### 6.1 物理一致性
所有状态效果都有对应的灵子物理学解释，确保世界观的一致性。

### 6.2 精简化
将原有的 14 种状态精简为 9 种，减少玩家认知负担，同时保持战术深度。

### 6.3 相态互动
引入相态克制机制，增加战术层次，鼓励玩家根据敌人状态选择法术。

### 6.4 可扩展性
系统设计支持未来添加新的状态类型和相态效果。

---

*此文档为灵子拓扑系统状态效果设计的技术规范。*
