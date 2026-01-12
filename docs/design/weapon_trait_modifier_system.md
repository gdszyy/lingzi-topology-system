# 武器特质规则调整系统设计文档

**版本: 1.0**

**作者: Manus AI**

## 1. 设计理念

### 1.1 世界观定位

在本系统的世界观中，**武器不再是直接伤害的来源，而是"特质"的象征**。每种武器代表着一种独特的修行理念和战斗哲学：

| 武器类型 | 特质象征 | 修行理念 |
|---------|---------|---------|
| **徒手 (UNARMED)** | 本源 | 回归本我，以身为器，无需外物 |
| **剑 (SWORD)** | 锐意 | 锋芒毕露，直指核心，一击必中 |
| **大剑 (GREATSWORD)** | 厚重 | 势大力沉，蓄势待发，一击定乾坤 |
| **双刃 (DUAL_BLADE)** | 疾风 | 双生共舞，连绵不绝，以速制敌 |
| **长枪 (SPEAR)** | 穿透 | 一往无前，势如破竹，贯穿万物 |
| **匕首 (DAGGER)** | 隐秘 | 伺机而动，一击致命，无声无息 |
| **法杖 (STAFF)** | 引导 | 沟通天地，引导灵力，法术增幅 |

### 1.2 核心设计原则

武器特质通过以下维度影响篆刻法术的表现：

1. **前摇调整 (Windup Modifier)**: 不同武器改变法术的准备时间
2. **消耗调整 (Cost Modifier)**: 不同武器改变法术的能量消耗
3. **效果调整 (Effect Modifier)**: 不同武器改变法术的效果强度
4. **冷却调整 (Cooldown Modifier)**: 不同武器改变法术的冷却时间
5. **触发器亲和 (Trigger Affinity)**: 不同武器对特定触发器有加成或惩罚

## 2. 武器特质修正器数据结构

### 2.1 WeaponTraitModifier 资源类

```gdscript
# weapon_trait_modifier.gd
class_name WeaponTraitModifier extends Resource

## 武器特质修正器
## 定义特定武器类型对篆刻法术的规则调整

## 基础修正值（乘数形式，1.0 = 无修正）
@export_group("基础修正")
@export var windup_multiplier: float = 1.0        ## 前摇时间乘数
@export var cost_multiplier: float = 1.0          ## 能量消耗乘数
@export var effect_multiplier: float = 1.0        ## 效果强度乘数
@export var cooldown_multiplier: float = 1.0      ## 冷却时间乘数

## 触发器亲和度（对特定触发器的额外修正）
@export_group("触发器亲和")
@export var trigger_affinity: Dictionary = {}     ## TriggerType -> float (乘数)

## 动作类型亲和度（对特定动作类型的额外修正）
@export_group("动作亲和")
@export var action_affinity: Dictionary = {}      ## ActionType -> float (乘数)

## 特殊规则
@export_group("特殊规则")
@export var can_cast_while_attacking: bool = false    ## 是否可在攻击中触发
@export var can_cast_while_moving: bool = true        ## 是否可在移动中触发
@export var requires_weapon_hit: bool = false         ## 是否必须武器命中才能触发
@export var chain_cast_bonus: float = 0.0             ## 连续触发加成
@export var first_cast_bonus: float = 0.0             ## 首次触发加成

## 容量修正
@export_group("容量修正")
@export var capacity_multiplier: float = 1.0          ## 篆刻容量乘数
@export var slot_count_modifier: int = 0              ## 槽位数量修正

## 获取对特定触发器的最终前摇乘数
func get_windup_for_trigger(trigger_type: int) -> float:
    var base = windup_multiplier
    if trigger_affinity.has(trigger_type):
        base *= trigger_affinity[trigger_type]
    return base

## 获取对特定动作的最终效果乘数
func get_effect_for_action(action_type: int) -> float:
    var base = effect_multiplier
    if action_affinity.has(action_type):
        base *= action_affinity[action_type]
    return base

## 获取对特定触发器的最终消耗乘数
func get_cost_for_trigger(trigger_type: int) -> float:
    var base = cost_multiplier
    if trigger_affinity.has(trigger_type):
        # 触发器亲和度高的，消耗略微降低
        var affinity = trigger_affinity[trigger_type]
        if affinity > 1.0:
            base *= (2.0 - affinity * 0.5)  # 亲和度1.5时，消耗变为0.75倍
    return base
```

### 2.2 各武器类型的特质配置

```gdscript
# weapon_trait_presets.gd
class_name WeaponTraitPresets

## 武器特质预设配置
## 定义每种武器类型的默认特质修正

static func get_modifier_for_type(weapon_type: WeaponData.WeaponType) -> WeaponTraitModifier:
    match weapon_type:
        WeaponData.WeaponType.UNARMED:
            return _create_unarmed_modifier()
        WeaponData.WeaponType.SWORD:
            return _create_sword_modifier()
        WeaponData.WeaponType.GREATSWORD:
            return _create_greatsword_modifier()
        WeaponData.WeaponType.DUAL_BLADE:
            return _create_dual_blade_modifier()
        WeaponData.WeaponType.SPEAR:
            return _create_spear_modifier()
        WeaponData.WeaponType.DAGGER:
            return _create_dagger_modifier()
        WeaponData.WeaponType.STAFF:
            return _create_staff_modifier()
    return WeaponTraitModifier.new()

## ==================== 徒手 ====================
## 特质：本源 - 回归本我，以身为器
## 特点：无法篆刻，但肢体篆刻效果增强
static func _create_unarmed_modifier() -> WeaponTraitModifier:
    var mod = WeaponTraitModifier.new()
    # 徒手无法在武器上篆刻
    mod.capacity_multiplier = 0.0
    mod.slot_count_modifier = -99  # 确保无槽位
    return mod

## ==================== 剑 ====================
## 特质：锐意 - 锋芒毕露，直指核心
## 特点：平衡型，命中触发加成，伤害类法术增强
static func _create_sword_modifier() -> WeaponTraitModifier:
    var mod = WeaponTraitModifier.new()
    
    # 基础修正 - 平衡
    mod.windup_multiplier = 1.0
    mod.cost_multiplier = 1.0
    mod.effect_multiplier = 1.1      # 轻微效果加成
    mod.cooldown_multiplier = 1.0
    
    # 触发器亲和 - 命中类触发器加成
    mod.trigger_affinity = {
        TriggerData.TriggerType.ON_WEAPON_HIT: 1.3,      # 武器命中 +30%
        TriggerData.TriggerType.ON_CRITICAL_HIT: 1.5,    # 暴击 +50%
        TriggerData.TriggerType.ON_DEAL_DAMAGE: 1.2,     # 造成伤害 +20%
    }
    
    # 动作亲和 - 伤害类动作加成
    mod.action_affinity = {
        ActionData.ActionType.DAMAGE: 1.2,               # 伤害 +20%
        ActionData.ActionType.CHAIN: 1.1,                # 链式 +10%
    }
    
    # 特殊规则
    mod.can_cast_while_attacking = true
    mod.first_cast_bonus = 0.15      # 首击加成15%
    
    # 容量
    mod.capacity_multiplier = 0.8    # 容量略低
    mod.slot_count_modifier = 0
    
    return mod

## ==================== 大剑 ====================
## 特质：厚重 - 势大力沉，蓄势待发
## 特点：高前摇高收益，攻击结束触发加成，范围效果增强
static func _create_greatsword_modifier() -> WeaponTraitModifier:
    var mod = WeaponTraitModifier.new()
    
    # 基础修正 - 高前摇高收益
    mod.windup_multiplier = 1.5      # 前摇增加50%
    mod.cost_multiplier = 1.3        # 消耗增加30%
    mod.effect_multiplier = 1.5      # 效果增加50%
    mod.cooldown_multiplier = 1.2    # 冷却增加20%
    
    # 触发器亲和 - 攻击结束和重击触发加成
    mod.trigger_affinity = {
        TriggerData.TriggerType.ON_ATTACK_END: 1.5,      # 攻击结束 +50%
        TriggerData.TriggerType.ON_COMBO_HIT: 1.3,       # 连击 +30%
        TriggerData.TriggerType.ON_ATTACK_START: 0.7,    # 攻击开始 -30%（不适合快速触发）
    }
    
    # 动作亲和 - 范围和爆炸效果加成
    mod.action_affinity = {
        ActionData.ActionType.AREA_EFFECT: 1.4,          # 范围效果 +40%
        ActionData.ActionType.SPAWN_EXPLOSION: 1.5,      # 爆炸 +50%
        ActionData.ActionType.SPAWN_DAMAGE_ZONE: 1.3,    # 伤害区域 +30%
        ActionData.ActionType.DISPLACEMENT: 1.2,         # 位移 +20%
    }
    
    # 特殊规则
    mod.can_cast_while_attacking = false  # 攻击中无法触发
    mod.can_cast_while_moving = false     # 移动中无法触发
    mod.chain_cast_bonus = -0.1           # 连续触发惩罚（需要蓄力）
    
    # 容量 - 大剑容量高
    mod.capacity_multiplier = 1.2
    mod.slot_count_modifier = 1
    
    return mod

## ==================== 双刃 ====================
## 特质：疾风 - 双生共舞，连绵不绝
## 特点：低前摇低单次效果，连续触发加成，攻击开始触发加成
static func _create_dual_blade_modifier() -> WeaponTraitModifier:
    var mod = WeaponTraitModifier.new()
    
    # 基础修正 - 快速低耗
    mod.windup_multiplier = 0.6      # 前摇减少40%
    mod.cost_multiplier = 0.7        # 消耗减少30%
    mod.effect_multiplier = 0.7      # 效果减少30%
    mod.cooldown_multiplier = 0.5    # 冷却减少50%
    
    # 触发器亲和 - 攻击开始和连击触发加成
    mod.trigger_affinity = {
        TriggerData.TriggerType.ON_ATTACK_START: 1.4,    # 攻击开始 +40%
        TriggerData.TriggerType.ON_ATTACK_ACTIVE: 1.3,   # 攻击判定 +30%
        TriggerData.TriggerType.ON_COMBO_HIT: 1.5,       # 连击 +50%
        TriggerData.TriggerType.ON_ATTACK_END: 0.6,      # 攻击结束 -40%
    }
    
    # 动作亲和 - 状态效果和链式加成
    mod.action_affinity = {
        ActionData.ActionType.APPLY_STATUS: 1.3,         # 状态效果 +30%
        ActionData.ActionType.CHAIN: 1.4,                # 链式 +40%
        ActionData.ActionType.DAMAGE: 0.8,               # 单次伤害 -20%
    }
    
    # 特殊规则
    mod.can_cast_while_attacking = true
    mod.can_cast_while_moving = true
    mod.chain_cast_bonus = 0.2        # 连续触发加成20%
    
    # 容量 - 双刃容量中等
    mod.capacity_multiplier = 0.8
    mod.slot_count_modifier = 0
    
    return mod

## ==================== 长枪 ====================
## 特质：穿透 - 一往无前，势如破竹
## 特点：中等前摇，穿透和位移效果增强，冲刺触发加成
static func _create_spear_modifier() -> WeaponTraitModifier:
    var mod = WeaponTraitModifier.new()
    
    # 基础修正 - 中等偏高
    mod.windup_multiplier = 1.2      # 前摇增加20%
    mod.cost_multiplier = 1.1        # 消耗增加10%
    mod.effect_multiplier = 1.3      # 效果增加30%
    mod.cooldown_multiplier = 1.0
    
    # 触发器亲和 - 冲刺和移动触发加成
    mod.trigger_affinity = {
        TriggerData.TriggerType.ON_DASH: 1.6,            # 冲刺 +60%
        TriggerData.TriggerType.ON_MOVE_START: 1.2,      # 移动开始 +20%
        TriggerData.TriggerType.ON_WEAPON_HIT: 1.3,      # 武器命中 +30%
        TriggerData.TriggerType.ON_ATTACK_ACTIVE: 1.4,   # 攻击判定 +40%
    }
    
    # 动作亲和 - 位移和穿透效果加成
    mod.action_affinity = {
        ActionData.ActionType.DISPLACEMENT: 1.5,         # 位移 +50%
        ActionData.ActionType.DAMAGE: 1.2,               # 伤害 +20%
        ActionData.ActionType.CHAIN: 1.3,                # 链式（穿透感） +30%
        ActionData.ActionType.AREA_EFFECT: 0.7,          # 范围效果 -30%
    }
    
    # 特殊规则
    mod.can_cast_while_attacking = true
    mod.can_cast_while_moving = true
    mod.requires_weapon_hit = false
    mod.first_cast_bonus = 0.25       # 首击加成25%（突刺）
    
    # 容量
    mod.capacity_multiplier = 1.2
    mod.slot_count_modifier = 1
    
    return mod

## ==================== 匕首 ====================
## 特质：隐秘 - 伺机而动，一击致命
## 特点：极低前摇，暴击和闪避触发加成，单体伤害增强
static func _create_dagger_modifier() -> WeaponTraitModifier:
    var mod = WeaponTraitModifier.new()
    
    # 基础修正 - 极快但效果一般
    mod.windup_multiplier = 0.4      # 前摇减少60%
    mod.cost_multiplier = 0.6        # 消耗减少40%
    mod.effect_multiplier = 0.9      # 效果略微减少
    mod.cooldown_multiplier = 0.7    # 冷却减少30%
    
    # 触发器亲和 - 暴击和闪避触发加成
    mod.trigger_affinity = {
        TriggerData.TriggerType.ON_CRITICAL_HIT: 2.0,    # 暴击 +100%
        TriggerData.TriggerType.ON_DODGE_SUCCESS: 1.5,   # 闪避成功 +50%
        TriggerData.TriggerType.ON_KILL_ENEMY: 1.8,      # 击杀 +80%
        TriggerData.TriggerType.ON_ATTACK_START: 1.2,    # 攻击开始 +20%
        TriggerData.TriggerType.ON_COMBO_HIT: 0.5,       # 连击 -50%（不适合正面连击）
    }
    
    # 动作亲和 - 单体伤害和状态效果加成
    mod.action_affinity = {
        ActionData.ActionType.DAMAGE: 1.4,               # 单体伤害 +40%
        ActionData.ActionType.APPLY_STATUS: 1.5,         # 状态效果（毒等） +50%
        ActionData.ActionType.AREA_EFFECT: 0.4,          # 范围效果 -60%
        ActionData.ActionType.SPAWN_EXPLOSION: 0.5,      # 爆炸 -50%
    }
    
    # 特殊规则
    mod.can_cast_while_attacking = true
    mod.can_cast_while_moving = true
    mod.requires_weapon_hit = true    # 必须命中才能触发
    mod.first_cast_bonus = 0.5        # 首击加成50%（暗杀）
    
    # 容量 - 匕首容量低
    mod.capacity_multiplier = 0.5
    mod.slot_count_modifier = -1
    
    return mod

## ==================== 法杖 ====================
## 特质：引导 - 沟通天地，引导灵力
## 特点：高前摇高效果，施法触发加成，所有法术效果增强
static func _create_staff_modifier() -> WeaponTraitModifier:
    var mod = WeaponTraitModifier.new()
    
    # 基础修正 - 法术专精
    mod.windup_multiplier = 1.3      # 前摇增加30%
    mod.cost_multiplier = 0.8        # 消耗减少20%（法力亲和）
    mod.effect_multiplier = 1.6      # 效果增加60%
    mod.cooldown_multiplier = 0.9    # 冷却略微减少
    
    # 触发器亲和 - 施法和法术触发加成
    mod.trigger_affinity = {
        TriggerData.TriggerType.ON_SPELL_CAST: 1.8,      # 施法 +80%
        TriggerData.TriggerType.ON_SPELL_HIT: 1.5,       # 法术命中 +50%
        TriggerData.TriggerType.ON_TICK: 1.3,            # 周期 +30%
        TriggerData.TriggerType.ON_INTERVAL: 1.3,        # 间隔 +30%
        TriggerData.TriggerType.ON_WEAPON_HIT: 0.5,      # 武器命中 -50%
        TriggerData.TriggerType.ON_ATTACK_START: 0.6,    # 攻击开始 -40%
    }
    
    # 动作亲和 - 所有法术效果加成
    mod.action_affinity = {
        ActionData.ActionType.DAMAGE: 1.3,               # 伤害 +30%
        ActionData.ActionType.AREA_EFFECT: 1.5,          # 范围效果 +50%
        ActionData.ActionType.SPAWN_EXPLOSION: 1.4,      # 爆炸 +40%
        ActionData.ActionType.CHAIN: 1.5,                # 链式 +50%
        ActionData.ActionType.APPLY_STATUS: 1.4,         # 状态效果 +40%
        ActionData.ActionType.SUMMON: 1.6,               # 召唤 +60%
        ActionData.ActionType.SHIELD: 1.3,               # 护盾 +30%
        ActionData.ActionType.FISSION: 1.4,              # 裂变 +40%
        ActionData.ActionType.ENERGY_RESTORE: 1.2,       # 能量恢复 +20%
        ActionData.ActionType.CULTIVATION: 1.2,          # 修炼 +20%
    }
    
    # 特殊规则
    mod.can_cast_while_attacking = false
    mod.can_cast_while_moving = true
    mod.requires_weapon_hit = false
    mod.chain_cast_bonus = 0.1        # 连续施法加成
    
    # 容量 - 法杖容量最高
    mod.capacity_multiplier = 1.5
    mod.slot_count_modifier = 2
    
    return mod
```

## 3. 系统集成设计

### 3.1 WeaponData 扩展

在现有的 `WeaponData` 中添加特质修正器：

```gdscript
# 在 weapon_data.gd 中添加

@export_group("Trait Modifier")
@export var trait_modifier: WeaponTraitModifier = null
@export var use_preset_modifier: bool = true  ## 是否使用预设修正器

func get_trait_modifier() -> WeaponTraitModifier:
    if trait_modifier != null:
        return trait_modifier
    if use_preset_modifier:
        return WeaponTraitPresets.get_modifier_for_type(weapon_type)
    return WeaponTraitModifier.new()

## 获取调整后的篆刻容量
func get_modified_engraving_capacity() -> float:
    var modifier = get_trait_modifier()
    return max_engraving_capacity * modifier.capacity_multiplier

## 获取调整后的槽位数量
func get_modified_slot_count() -> int:
    var modifier = get_trait_modifier()
    var base_count = engraving_slots.size()
    return max(0, base_count + modifier.slot_count_modifier)
```

### 3.2 EngravingSlot 扩展

在篆刻槽中集成武器特质修正：

```gdscript
# 在 engraving_slot.gd 中添加

var weapon_modifier: WeaponTraitModifier = null

func set_weapon_modifier(modifier: WeaponTraitModifier) -> void:
    weapon_modifier = modifier

## 计算调整后的前摇时间
func calculate_modified_windup(proficiency: float = 0.0, trigger_type: int = -1) -> float:
    if engraved_spell == null:
        return 0.0
    
    var base_windup = engraved_spell.calculate_windup_time(proficiency, true)
    
    if weapon_modifier != null:
        var modifier = weapon_modifier.get_windup_for_trigger(trigger_type)
        base_windup *= modifier
    
    return base_windup

## 计算调整后的能量消耗
func calculate_modified_cost(trigger_type: int = -1) -> float:
    if engraved_spell == null:
        return 0.0
    
    var base_cost = engraved_spell.resource_cost
    
    if weapon_modifier != null:
        var modifier = weapon_modifier.get_cost_for_trigger(trigger_type)
        base_cost *= modifier
    
    return base_cost

## 计算调整后的效果强度
func calculate_modified_effect(action_type: int = -1) -> float:
    var base_effect = 1.0
    
    if weapon_modifier != null:
        base_effect = weapon_modifier.get_effect_for_action(action_type)
    
    return base_effect

## 计算调整后的冷却时间
func calculate_modified_cooldown() -> float:
    var base_cooldown = cooldown
    
    if weapon_modifier != null:
        base_cooldown *= weapon_modifier.cooldown_multiplier
    
    return base_cooldown
```

### 3.3 EngravingManager 集成

在篆刻管理器中应用武器特质修正：

```gdscript
# 在 engraving_manager.gd 中修改

## 分发触发器时应用武器特质修正
func distribute_trigger(trigger_type: int, context: Dictionary = {}) -> void:
    if not is_enabled:
        return
    
    # ... 现有代码 ...
    
    # 武器槽位处理 - 应用武器特质修正
    if player != null and player.current_weapon != null:
        var weapon = player.current_weapon
        var trait_modifier = weapon.get_trait_modifier()
        
        # 检查特殊规则
        if not _check_weapon_trait_rules(trait_modifier, trigger_type, context):
            return
        
        for slot in weapon.engraving_slots:
            if not slot.can_trigger():
                continue
            
            if slot.engraved_spell == null:
                continue
            
            # 设置武器修正器
            slot.set_weapon_modifier(trait_modifier)
            
            var proficiency = proficiency_manager.get_proficiency_value(slot.engraved_spell.spell_id)
            
            # 使用调整后的前摇时间
            var modified_windup = slot.calculate_modified_windup(proficiency, trigger_type)
            
            # 检查能量消耗
            var modified_cost = slot.calculate_modified_cost(trigger_type)
            if not _can_afford_cost(modified_cost):
                continue
            
            var started = slot.start_trigger(trigger_type, context, proficiency)
            
            if started:
                # 扣除能量
                _consume_energy(modified_cost)
                
                if not slot.spell_triggered.is_connected(_on_slot_spell_triggered):
                    slot.spell_triggered.connect(_on_slot_spell_triggered.bind(slot, context))

## 检查武器特质规则
func _check_weapon_trait_rules(modifier: WeaponTraitModifier, trigger_type: int, context: Dictionary) -> bool:
    if modifier == null:
        return true
    
    # 检查是否可在攻击中触发
    if context.get("is_attacking", false) and not modifier.can_cast_while_attacking:
        return false
    
    # 检查是否可在移动中触发
    if context.get("is_moving", false) and not modifier.can_cast_while_moving:
        return false
    
    # 检查是否需要武器命中
    if modifier.requires_weapon_hit:
        if trigger_type != TriggerData.TriggerType.ON_WEAPON_HIT and \
           trigger_type != TriggerData.TriggerType.ON_CRITICAL_HIT:
            return false
    
    return true

## 执行规则动作时应用效果修正
func _execute_rule_actions(rule: TopologyRuleData, context: Dictionary, slot: EngravingSlot) -> void:
    if rule == null or not rule.enabled:
        return
    
    var full_context = context.duplicate()
    full_context["slot"] = slot
    full_context["slot_level"] = slot.slot_level
    full_context["is_engraved"] = true
    
    # 应用武器特质效果修正
    if slot.weapon_modifier != null:
        for action in rule.actions:
            if action != null:
                var effect_modifier = slot.calculate_modified_effect(action.action_type)
                full_context["weapon_effect_modifier"] = effect_modifier
                
                # 应用连续触发加成
                var cast_count = context.get("consecutive_cast_count", 0)
                if cast_count > 0:
                    var chain_bonus = slot.weapon_modifier.chain_cast_bonus * cast_count
                    full_context["chain_bonus"] = chain_bonus
                elif cast_count == 0:
                    full_context["first_cast_bonus"] = slot.weapon_modifier.first_cast_bonus
                
                action_executor.execute_action(action, full_context)
                action_executed.emit(action, full_context)
    else:
        # 原有逻辑
        var part_efficiency = context.get("part_efficiency", 1.0)
        full_context["effect_multiplier"] = part_efficiency
        
        for action in rule.actions:
            if action != null:
                action_executor.execute_action(action, full_context)
                action_executed.emit(action, full_context)
```

### 3.4 ActionExecutor 集成

在动作执行器中应用武器特质修正：

```gdscript
# 在 action_executor.gd 中修改

func execute_action(action: ActionData, context: Dictionary) -> void:
    # 获取武器效果修正
    var weapon_effect_modifier = context.get("weapon_effect_modifier", 1.0)
    var chain_bonus = context.get("chain_bonus", 0.0)
    var first_cast_bonus = context.get("first_cast_bonus", 0.0)
    
    # 计算最终效果乘数
    var final_modifier = weapon_effect_modifier * (1.0 + chain_bonus + first_cast_bonus)
    
    match action.action_type:
        ActionData.ActionType.DAMAGE:
            _execute_damage_action(action, context, final_modifier)
        ActionData.ActionType.AREA_EFFECT:
            _execute_area_effect_action(action, context, final_modifier)
        # ... 其他动作类型
```

## 4. 武器特质对比表

| 武器类型 | 前摇 | 消耗 | 效果 | 冷却 | 容量 | 槽位 | 特长触发器 | 特长动作 |
|---------|------|------|------|------|------|------|-----------|---------|
| 徒手 | - | - | - | - | 0% | -99 | - | - |
| 剑 | 100% | 100% | 110% | 100% | 80% | +0 | 命中、暴击 | 伤害、链式 |
| 大剑 | 150% | 130% | 150% | 120% | 120% | +1 | 攻击结束 | 范围、爆炸 |
| 双刃 | 60% | 70% | 70% | 50% | 80% | +0 | 攻击开始、连击 | 状态、链式 |
| 长枪 | 120% | 110% | 130% | 100% | 120% | +1 | 冲刺、移动 | 位移、穿透 |
| 匕首 | 40% | 60% | 90% | 70% | 50% | -1 | 暴击、闪避 | 单体伤害、状态 |
| 法杖 | 130% | 80% | 160% | 90% | 150% | +2 | 施法、法术命中 | 全法术增强 |

## 5. 使用示例

### 5.1 创建带特质的武器

```gdscript
# 创建一把自定义剑
var sword = WeaponData.new()
sword.weapon_name = "破晓之剑"
sword.weapon_type = WeaponData.WeaponType.SWORD
sword.use_preset_modifier = true  # 使用预设特质

# 或者自定义特质
var custom_modifier = WeaponTraitModifier.new()
custom_modifier.windup_multiplier = 0.8
custom_modifier.effect_multiplier = 1.3
sword.trait_modifier = custom_modifier
sword.use_preset_modifier = false
```

### 5.2 篆刻法术时的特质影响

```gdscript
# 在篆刻面板中显示调整后的数值
func _update_spell_preview(spell: SpellCoreData, slot: EngravingSlot) -> void:
    var modifier = current_weapon.get_trait_modifier()
    slot.set_weapon_modifier(modifier)
    
    var base_windup = spell.calculate_windup_time(0.0, true)
    var modified_windup = slot.calculate_modified_windup(0.0, TriggerData.TriggerType.ON_WEAPON_HIT)
    
    var base_cost = spell.resource_cost
    var modified_cost = slot.calculate_modified_cost(TriggerData.TriggerType.ON_WEAPON_HIT)
    
    preview_label.text = "前摇: %.2fs → %.2fs\n消耗: %.1f → %.1f" % [
        base_windup, modified_windup,
        base_cost, modified_cost
    ]
```

## 6. 扩展建议

### 6.1 稀有度系统

可以为武器添加稀有度，影响特质修正的强度：

```gdscript
enum WeaponRarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

func get_rarity_multiplier(rarity: WeaponRarity) -> float:
    match rarity:
        WeaponRarity.COMMON: return 1.0
        WeaponRarity.UNCOMMON: return 1.1
        WeaponRarity.RARE: return 1.25
        WeaponRarity.EPIC: return 1.5
        WeaponRarity.LEGENDARY: return 2.0
    return 1.0
```

### 6.2 武器成长系统

武器可以通过使用获得经验，提升特质修正：

```gdscript
var weapon_experience: float = 0.0
var weapon_level: int = 1

func add_experience(amount: float) -> void:
    weapon_experience += amount
    while weapon_experience >= get_exp_for_level(weapon_level + 1):
        weapon_level += 1
        _on_level_up()

func get_trait_bonus_from_level() -> float:
    return 1.0 + (weapon_level - 1) * 0.05  # 每级+5%
```

### 6.3 武器共鸣系统

当武器特质与法术属性匹配时，产生共鸣效果：

```gdscript
func calculate_resonance(weapon: WeaponData, spell: SpellCoreData) -> float:
    var resonance = 0.0
    var modifier = weapon.get_trait_modifier()
    
    # 检查触发器共鸣
    for rule in spell.topology_rules:
        if rule.trigger != null:
            var affinity = modifier.trigger_affinity.get(rule.trigger.trigger_type, 1.0)
            if affinity > 1.2:
                resonance += 0.1
    
    # 检查动作共鸣
    for rule in spell.topology_rules:
        for action in rule.actions:
            var affinity = modifier.action_affinity.get(action.action_type, 1.0)
            if affinity > 1.2:
                resonance += 0.05
    
    return min(resonance, 0.5)  # 最高50%共鸣加成
```

---

*此文档为灵子拓扑系统武器特质规则调整系统的设计规范。*
*最后更新：2026-01-12*
