# ActionData 子类属性名称参考

本文档记录了各 ActionData 子类的正确属性名称，用于避免属性赋值错误。

## SpawnDamageZoneActionData

用于生成持续伤害区域。

| 属性名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| zone_damage | float | 10.0 | 每次伤害值 |
| zone_radius | float | 80.0 | 区域半径 |
| zone_duration | float | 5.0 | 持续时间 |
| tick_interval | float | 0.5 | 伤害间隔 |
| zone_damage_type | int | 0 | 伤害类型 |
| slow_amount | float | 0.0 | 减速效果 |

## SpawnExplosionActionData

用于生成爆炸效果。

| 属性名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| explosion_damage | float | 50.0 | 爆炸伤害 |
| explosion_radius | float | 100.0 | 爆炸半径 |
| damage_falloff | float | 0.5 | 伤害衰减 |
| explosion_damage_type | int | 0 | 伤害类型 |

## ChainActionData

用于链式攻击效果。

| 属性名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| chain_type | ChainType | LIGHTNING | 链式类型 |
| chain_count | int | 3 | 链式次数 |
| chain_range | float | 200.0 | 链式范围 |
| chain_damage | float | 30.0 | 链式伤害 |
| chain_damage_decay | float | 0.8 | 伤害衰减 |
| chain_delay | float | 0.1 | 链式延迟 |

## DamageActionData

用于直接伤害效果。

| 属性名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| damage_value | float | 10.0 | 伤害值 |
| damage_type | DamageType | KINETIC_IMPACT | 伤害类型 |
| use_carrier_kinetic | bool | true | 使用载体动能 |
| damage_multiplier | float | 1.0 | 伤害倍率 |

## ShieldActionData

用于护盾效果。

| 属性名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| shield_type | ShieldType | PERSONAL | 护盾类型 |
| shield_amount | float | 50.0 | 护盾量 |
| shield_duration | float | 5.0 | 持续时间 |
| shield_radius | float | 80.0 | 护盾半径 |
| shield_regen | float | 0.0 | 护盾回复 |
| damage_reduction | float | 0.0 | 伤害减免 |

## ApplyStatusActionData

用于应用状态效果。

| 属性名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| status_type | StatusType | ENTROPY_BURN | 状态类型 |
| duration | float | 3.0 | 持续时间 |
| tick_interval | float | 0.5 | 触发间隔 |
| effect_value | float | 5.0 | 效果值 |
| stack_limit | int | 3 | 叠加上限 |

## FissionActionData

用于分裂效果。

| 属性名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| spawn_count | int | 3 | 生成数量 |
| spread_angle | float | 360.0 | 扩散角度 |
| inherit_velocity | float | 0.5 | 继承速度 |
| child_spell_data | Resource | null | 子法术数据 |

## AreaEffectActionData

用于区域效果。

| 属性名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| area_shape | AreaShape | CIRCLE | 区域形状 |
| radius | float | 50.0 | 半径 |
| angle | float | 90.0 | 角度 |
| length | float | 100.0 | 长度 |
| width | float | 20.0 | 宽度 |
| damage_value | float | 15.0 | 伤害值 |
| damage_falloff | float | 0.5 | 伤害衰减 |

## 常见错误

以下是常见的属性名称错误对照：

| 错误写法 | 正确写法 | 所属类 |
|----------|----------|--------|
| damage | explosion_damage | SpawnExplosionActionData |
| radius | explosion_radius | SpawnExplosionActionData |
| damage_per_tick | zone_damage | SpawnDamageZoneActionData |
| duration | zone_duration | SpawnDamageZoneActionData |
| radius | zone_radius | SpawnDamageZoneActionData |
