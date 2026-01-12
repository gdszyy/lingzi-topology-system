# 武器特质规则调整系统变更日志

**版本: 1.0.0**
**日期: 2026-01-12**

## 概述

本次更新引入了**武器特质规则调整系统**，重新定义了武器在战斗系统中的角色。在新的世界观中，武器不再是直接伤害的来源，而是"特质"的象征，每种武器代表着独特的修行理念和战斗哲学。

## 核心理念

| 武器类型 | 特质名称 | 修行理念 |
|---------|---------|---------|
| 徒手 | 本源 | 回归本我，以身为器，无需外物 |
| 剑 | 锐意 | 锋芒毕露，直指核心，一击必中 |
| 大剑 | 厚重 | 势大力沉，蓄势待发，一击定乾坤 |
| 双刃 | 疾风 | 双生共舞，连绵不绝，以速制敌 |
| 长枪 | 穿透 | 一往无前，势如破竹，贯穿万物 |
| 匕首 | 隐秘 | 伺机而动，一击致命，无声无息 |
| 法杖 | 引导 | 沟通天地，引导灵力，法术增幅 |

## 新增文件

### 资源类
- `resources/combat/weapon_trait_modifier.gd` - 武器特质修正器资源类
- `resources/combat/weapon_trait_presets.gd` - 武器特质预设配置

### 设计文档
- `docs/design/weapon_trait_modifier_system.md` - 完整设计文档

## 修改文件

### resources/combat/weapon_data.gd
- 新增 `trait_modifier` 属性：自定义特质修正器
- 新增 `use_preset_modifier` 属性：是否使用预设修正器
- 新增特质相关方法：
  - `get_trait_modifier()` - 获取武器特质修正器
  - `get_trait_name()` - 获取特质名称
  - `get_trait_description()` - 获取特质描述
  - `get_modified_engraving_capacity()` - 获取调整后的篆刻容量
  - `get_modified_slot_count()` - 获取调整后的槽位数量
  - `can_trigger_engraving_in_state()` - 检查是否可在当前状态下触发
  - `check_weapon_hit_requirement()` - 检查武器命中要求
  - `get_modified_windup()` - 获取调整后的前摇时间
  - `get_modified_cost()` - 获取调整后的能量消耗
  - `get_modified_effect()` - 获取调整后的效果强度
  - `get_modified_cooldown()` - 获取调整后的冷却时间
  - `get_chain_bonus()` - 获取连续触发加成
  - `get_trigger_affinity()` - 获取触发器亲和度
  - `get_action_affinity()` - 获取动作亲和度

### resources/engraving/engraving_slot.gd
- 新增 `weapon_modifier` 属性：武器特质修正器引用
- 新增 `consecutive_trigger_count` 属性：连续触发计数
- 新增 `last_trigger_time` 属性：上次触发时间
- 新增方法：
  - `set_weapon_modifier()` - 设置武器特质修正器
  - `calculate_modified_windup()` - 计算调整后的前摇时间
  - `calculate_modified_cost()` - 计算调整后的能量消耗
  - `calculate_modified_effect()` - 计算调整后的效果强度
  - `calculate_modified_cooldown()` - 计算调整后的冷却时间
  - `get_chain_bonus()` - 获取连续触发加成
  - `update_consecutive_count()` - 更新连续触发计数
  - `reset_consecutive_count()` - 重置连续触发计数

### scripts/combat/engraving_manager.gd
- 修改 `distribute_trigger()` 方法：
  - 添加武器特质规则检查（攻击中/移动中触发限制）
  - 添加武器命中要求检查
  - 设置武器特质修正器到槽位
  - 计算并扣除调整后的能量消耗
  - 更新连续触发计数
  - 传递武器特质上下文信息
- 修改 `_execute_rule_actions()` 方法：
  - 应用武器特质效果修正
  - 应用连续触发加成/首次触发加成

### scripts/combat/action_executor.gd
- 修改 `execute_action()` 方法：
  - 应用武器特质总效果修正（`total_effect_modifier`）

## 武器特质对比表

| 武器类型 | 前摇 | 消耗 | 效果 | 冷却 | 容量 | 槽位 | 特长触发器 | 特长动作 |
|---------|------|------|------|------|------|------|-----------|---------|
| 徒手 | - | - | - | - | 0% | -99 | - | - |
| 剑 | 100% | 100% | 110% | 100% | 80% | +0 | 命中、暴击 | 伤害、链式 |
| 大剑 | 150% | 130% | 150% | 120% | 120% | +1 | 攻击结束 | 范围、爆炸 |
| 双刃 | 60% | 70% | 70% | 50% | 80% | +0 | 攻击开始、连击 | 状态、链式 |
| 长枪 | 120% | 110% | 130% | 100% | 120% | +1 | 冲刺、移动 | 位移、穿透 |
| 匕首 | 40% | 60% | 90% | 70% | 50% | -1 | 暴击、闪避 | 单体伤害、状态 |
| 法杖 | 130% | 80% | 160% | 90% | 150% | +2 | 施法、法术命中 | 全法术增强 |

## 特殊规则

### 触发限制
- **大剑**：攻击中和移动中无法触发篆刻法术
- **法杖**：攻击中无法触发篆刻法术
- **匕首**：必须武器命中才能触发篆刻法术

### 连续触发机制
- **双刃**：连续触发加成 +20%/次
- **法杖**：连续触发加成 +10%/次
- **大剑**：连续触发惩罚 -10%/次

### 首次触发加成
- **匕首**：首击加成 +50%（暗杀）
- **长枪**：首击加成 +25%（突刺）
- **剑**：首击加成 +15%

## 使用示例

### 获取武器特质信息
```gdscript
var weapon = player.current_weapon
print("武器特质: %s" % weapon.get_trait_name())
print("特质描述: %s" % weapon.get_trait_description())
print("特质摘要: %s" % weapon.get_trait_summary())
```

### 计算调整后的法术数值
```gdscript
var spell = slot.engraved_spell
var trigger_type = TriggerData.TriggerType.ON_WEAPON_HIT

# 设置武器特质修正器
slot.set_weapon_modifier(weapon.get_trait_modifier())

# 计算调整后的数值
var modified_windup = slot.calculate_modified_windup(proficiency, trigger_type)
var modified_cost = slot.calculate_modified_cost(trigger_type)
var modified_effect = slot.calculate_modified_effect(action.action_type)
```

### 自定义武器特质
```gdscript
# 创建自定义特质修正器
var custom_modifier = WeaponTraitModifier.new()
custom_modifier.trait_name = "破晓"
custom_modifier.trait_description = "黎明之光，驱散黑暗"
custom_modifier.windup_multiplier = 0.8
custom_modifier.effect_multiplier = 1.3
custom_modifier.trigger_affinity = {
    TriggerData.TriggerType.ON_CRITICAL_HIT: 1.5
}

# 应用到武器
weapon.trait_modifier = custom_modifier
weapon.use_preset_modifier = false
```

## 向后兼容

- 所有现有武器默认使用预设特质修正器（`use_preset_modifier = true`）
- 未设置特质修正器的武器将使用默认修正（所有乘数为 1.0）
- 现有的篆刻槽和法术系统保持兼容

## 未来扩展

1. **稀有度系统**：武器稀有度影响特质修正强度
2. **武器成长系统**：武器通过使用获得经验，提升特质修正
3. **武器共鸣系统**：武器特质与法术属性匹配时产生共鸣效果
4. **特质觉醒系统**：解锁武器隐藏特质

---

*此变更日志记录了武器特质规则调整系统的所有更新内容。*
