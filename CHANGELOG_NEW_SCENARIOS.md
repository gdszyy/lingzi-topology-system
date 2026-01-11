# 灵子拓扑系统 - 新场景与规则变更日志

## 版本：v0.3.0
## 日期：2026-01-12

---

## 一、新增法术场景

### 1. 防御法术 (DEFENSE)
**描述**：生成护盾、反弹伤害、格挡投射物

**核心动作**：
- `ShieldActionData` - 护盾动作
- `ReflectActionData` - 反弹动作

**核心触发器**：
- `ON_CONTACT` - 碰撞触发
- `ON_PROXIMITY` - 接近触发
- `ON_ALLY_CONTACT` - 友方触发

**场景特点**：
- 低速或静止载体
- 较长持续时间（5-15秒）
- 伤害较低，重点在防护效果

---

### 2. 控制法术 (CONTROL)
**描述**：减速、冰冻、眩晕、束缚等控制效果

**核心动作**：
- `ApplyStatusActionData` - 状态效果
- `DisplacementActionData` - 位移效果

**核心触发器**：
- `ON_CONTACT` - 碰撞触发
- `ON_PROXIMITY` - 接近触发
- `ON_STATUS_APPLIED` - 状态触发

**优先状态类型**：
- `FROZEN` - 冰冻（完全定身）
- `SLOWED` - 减速
- `STUNNED` - 眩晕
- `ROOTED` - 束缚（不能移动但能攻击）

---

### 3. 召唤法术 (SUMMON)
**描述**：召唤独立实体，实体有自己的行为逻辑

**核心动作**：
- `SummonActionData` - 召唤动作

**核心触发器**：
- `ON_CONTACT` - 碰撞触发
- `ON_TIMER` - 定时触发
- `ON_DEATH` - 消亡触发

**召唤物类型**：
- `TURRET` - 炮塔（固定位置，自动攻击）
- `MINION` - 仆从（追踪敌人，近战攻击）
- `ORBITER` - 环绕体（围绕玩家旋转）
- `DECOY` - 诱饵（吸引敌人注意）
- `BARRIER` - 屏障（阻挡投射物）
- `TOTEM` - 图腾（持续释放效果）

---

### 4. 链式法术 (CHAIN)
**描述**：伤害在多个目标间传导，类似闪电链

**核心动作**：
- `ChainActionData` - 链式动作

**核心触发器**：
- `ON_CONTACT` - 碰撞触发
- `ON_CHAIN_END` - 链式结束触发

**链式类型**：
- `LIGHTNING` - 闪电链（附带眩晕）
- `FIRE` - 火焰链（附带燃烧）
- `ICE` - 冰霜链（附带冰冻）
- `VOID` - 虚空链（附带标记）

---

## 二、新增动作类型

### 1. ShieldActionData（护盾动作）
```gdscript
# 护盾类型
enum ShieldType {
    PERSONAL,    # 个人护盾
    AREA,        # 区域护盾
    REFLECTIVE   # 反射护盾
}

# 主要属性
shield_amount: float        # 护盾值
shield_duration: float      # 持续时间
shield_radius: float        # 护盾范围（区域护盾）
on_break_explode: bool      # 破碎时是否爆炸
break_explosion_damage: float
```

### 2. ReflectActionData（反弹动作）
```gdscript
# 反弹类型
enum ReflectType {
    PROJECTILE,  # 反弹投射物
    DAMAGE,      # 反弹伤害
    AREA         # 范围反弹
}

# 主要属性
reflect_damage_ratio: float  # 反弹伤害比例
reflect_duration: float      # 反弹持续时间
max_reflects: int            # 最大反弹次数
reflect_radius: float        # 反弹范围
```

### 3. DisplacementActionData（位移动作）
```gdscript
# 位移类型
enum DisplacementType {
    KNOCKBACK,   # 击退
    PULL,        # 吸引
    TELEPORT,    # 传送
    LAUNCH       # 击飞
}

# 主要属性
displacement_force: float        # 位移力度
displacement_duration: float     # 位移持续时间
stun_after_displacement: float   # 位移后眩晕时间
damage_on_collision: float       # 碰撞伤害
```

### 4. ChainActionData（链式动作）
```gdscript
# 链式类型
enum ChainType {
    LIGHTNING,   # 闪电链
    FIRE,        # 火焰链
    ICE,         # 冰霜链
    VOID         # 虚空链
}

# 主要属性
chain_count: int             # 最大跳跃次数
chain_range: float           # 跳跃范围
chain_damage: float          # 每次跳跃伤害
chain_damage_decay: float    # 伤害衰减
chain_delay: float           # 跳跃间隔
chain_can_return: bool       # 是否可返回已击中目标
apply_status_type: int       # 附带状态类型
apply_status_duration: float # 状态持续时间
```

### 5. SummonActionData（召唤动作）
```gdscript
# 召唤物类型
enum SummonType {
    TURRET,      # 炮塔
    MINION,      # 仆从
    ORBITER,     # 环绕体
    DECOY,       # 诱饵
    BARRIER,     # 屏障
    TOTEM        # 图腾
}

# 行为模式
enum BehaviorMode {
    AGGRESSIVE,  # 主动攻击
    DEFENSIVE,   # 防御模式
    PASSIVE,     # 被动模式
    FOLLOW       # 跟随模式
}

# 主要属性
summon_count: int            # 召唤数量
summon_duration: float       # 持续时间
summon_health: float         # 生命值
summon_damage: float         # 伤害
summon_attack_interval: float
summon_attack_range: float
summon_move_speed: float     # 移动速度（MINION）
orbit_radius: float          # 环绕半径（ORBITER）
orbit_speed: float           # 环绕速度（ORBITER）
aggro_radius: float          # 嘲讽范围（DECOY）
totem_effect_radius: float   # 效果范围（TOTEM）
```

---

## 三、新增触发器类型

| 触发器 | 说明 | 适用场景 |
|-------|------|---------|
| `ON_ALLY_CONTACT` | 友方单位进入范围时触发 | 防御法术（给友方加护盾） |
| `ON_STATUS_APPLIED` | 目标被施加特定状态时触发 | 控制法术（冰冻后碎裂） |
| `ON_CHAIN_END` | 链式传导结束时触发 | 链式法术（链式结束后爆炸） |
| `ON_SHIELD_BREAK` | 护盾破碎时触发 | 防御法术（护盾破碎反击） |
| `ON_SUMMON_DEATH` | 召唤物死亡时触发 | 召唤法术（召唤物死亡爆炸） |
| `ON_REFLECT` | 反弹发生时触发 | 防御法术（反弹后追加效果） |

---

## 四、扩展状态类型

### 新增负面状态
| 状态 | 效果 |
|-----|------|
| `ROOTED` | 束缚 - 不能移动但能攻击 |
| `SILENCED` | 沉默 - 不能施法 |
| `MARKED` | 标记 - 受到额外伤害 |
| `BLINDED` | 致盲 - 降低命中率 |
| `CURSED` | 诅咒 - 受到治疗效果降低 |

### 新增正面状态
| 状态 | 效果 |
|-----|------|
| `EMPOWERED` | 强化 - 增加伤害 |
| `HASTED` | 加速 - 增加移动速度 |
| `SHIELDED` | 护盾 - 吸收伤害 |

---

## 五、Cost 计算公式

### 新动作类型Cost计算

| 动作类型 | Cost公式 |
|---------|---------|
| Shield | `shield_amount * 0.15 + shield_duration * 0.5 + shield_radius * 0.03` |
| Reflect | `reflect_duration * 1.0 + max_reflects * 2.0 + reflect_damage_ratio * 5.0` |
| Displacement | `displacement_force * 0.01 + stun_after_displacement * 2.0 + damage_on_collision * 0.2` |
| Chain | `chain_count * 3.0 + chain_damage * 0.25 + chain_range * 0.02` |
| Summon | `summon_count * 5.0 + summon_duration * 0.3 + summon_damage * 0.2 + summon_health * 0.1` |

---

## 六、场景与规则对应表

| 场景 | 核心动作 | 核心触发器 | 核心状态 | Cost上限 |
|-----|---------|-----------|---------|---------|
| 防御 | Shield, Reflect | ON_CONTACT, ON_ALLY_CONTACT | - | 60 |
| 控制 | ApplyStatus, Displacement | ON_CONTACT, ON_STATUS_APPLIED | FROZEN, STUNNED, ROOTED | 55 |
| 召唤 | Summon | ON_DEATH, ON_TIMER | - | 75 |
| 链式 | Chain | ON_CONTACT, ON_CHAIN_END | MARKED | 65 |

---

## 七、文件变更清单

### 新增文件
- `resources/actions/shield_action_data.gd`
- `resources/actions/reflect_action_data.gd`
- `resources/actions/displacement_action_data.gd`
- `resources/actions/chain_action_data.gd`
- `resources/actions/summon_action_data.gd`
- `resources/triggers/on_status_applied_trigger.gd`

### 修改文件
- `resources/actions/action_data.gd` - 新增动作类型枚举
- `resources/actions/apply_status_action_data.gd` - 扩展状态类型
- `resources/triggers/trigger_data.gd` - 新增触发器类型
- `scripts/core/spell_scenario_config.gd` - 新增4个场景配置
- `scripts/core/scenario_spell_generator.gd` - 支持新场景和新动作生成
- `scripts/core/batch_spell_generator.gd` - 支持新动作类型的cost计算

---

## 八、后续实现建议

### 需要实现的运行时逻辑
1. **护盾系统**：护盾值管理、护盾破碎检测、护盾视觉效果
2. **反弹系统**：投射物反弹逻辑、伤害反弹计算
3. **位移系统**：击退/吸引物理效果、碰撞检测
4. **链式系统**：目标搜索、链式跳跃动画、伤害衰减
5. **召唤系统**：召唤物AI、生命周期管理、攻击逻辑

### 需要添加的视觉效果
- 护盾生成/破碎特效
- 链式传导特效（闪电/火焰/冰霜）
- 召唤物出现/消失特效
- 位移效果（击退轨迹、传送闪烁）

---

*此文档记录了灵子拓扑系统新场景和规则的设计与实现。*
