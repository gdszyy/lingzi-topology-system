# 二维体素战斗系统 - 变更日志

**版本:** 1.0.0
**日期:** 2026-01-12

## 概述

本次更新为"灵子拓扑构筑系统"引入了全新的"二维体素战斗系统"。该系统的核心理念是将角色身体视为由多个可独立损伤的"体素"（即肢体）构成。法术可以被篆刻在这些肢体上，当一个肢体在战斗中被摧毁时，其上篆刻的所有法术将立刻失效。

## 新增功能

### 1. 肢体数据增强 (`resources/engraving/body_part_data.gd`)

- **新增信号:**
  - `health_changed(current, maximum)`: 肢体生命值变化时触发。
  - `destroyed(part)`: 肢体被摧毁时触发。
  - `restored(part)`: 肢体从摧毁状态恢复时触发。
  - `damage_taken(damage, remaining_health)`: 肢体承受伤害时触发。

- **新增属性:**
  - `DamageState` 枚举: 定义肢体的损伤状态（健康、受损、重伤、残废、摧毁）。
  - `core_damage_ratio`: 肢体受伤时传递到角色核心的伤害比例。
  - `is_vital`: 标记肢体是否为关键部位（头部、躯干）。关键部位被摧毁将导致角色死亡。
  - `efficiency`: 肢体效率，受损伤状态影响，用于调整篆刻法术的效果。

- **新增方法:**
  - `fully_restore()`: 完全修复肢体。
  - `get_health_percent()`: 获取生命值百分比。
  - `can_use_engravings()`: 检查肢体是否可以使用篆刻法术。
  - `get_effect_multiplier()`: 获取肢体效率修正后的效果倍率。
  - `get_status_summary()`: 获取简短状态信息。

### 2. 篆刻管理器增强 (`scripts/combat/engraving_manager.gd`)

- **新增信号:**
  - `body_part_damaged(part, damage, remaining_health)`: 肢体受伤时触发。
  - `body_part_destroyed(part)`: 肢体被摧毁时触发。
  - `body_part_restored(part)`: 肢体恢复时触发。
  - `spells_disabled(part, spell_count)`: 肢体上的法术因摧毁而失效时触发。
  - `spells_enabled(part, spell_count)`: 肢体恢复后法术重新生效时触发。

- **核心逻辑变更:**
  - `distribute_trigger()` 方法现在会检查肢体的 `is_functional` 状态。只有功能完好的肢体上的法术才会被触发。
  - 新增 `damage_body_part(part_type, damage)` 方法，用于对特定肢体造成伤害。
  - 新增 `heal_body_part(part_type, amount)` 方法，用于治疗特定肢体。
  - 新增 `restore_all_body_parts()` 方法，用于完全恢复所有肢体。
  - 新增 `get_functional_body_parts()` 和 `get_destroyed_body_parts()` 方法。

### 3. 玩家控制器增强 (`scripts/combat/player_controller.gd`)

- **新增信号:**
  - `body_part_damaged(part, damage)`: 肢体受伤时触发。
  - `body_part_destroyed(part)`: 肢体被摧毁时触发。
  - `body_part_restored(part)`: 肢体恢复时触发。
  - `vital_part_destroyed(part)`: 关键部位被摧毁时触发（导致死亡）。

- **核心逻辑变更:**
  - `take_damage()` 方法新增 `target_part_type` 参数，支持指定攻击目标肢体。
  - 新增 `take_damage_random_part()` 方法，用于非定向攻击。
  - 新增 `take_damage_spread()` 方法，用于范围攻击。
  - 新增 `heal_body_part()` 和 `heal_all_body_parts()` 方法。
  - 新增 `movement_penalty` 属性，根据腿部损伤状态动态调整移动速度。
  - 新增 `can_fly_override` 属性，腿部被摧毁后禁止飞行。
  - 新增 `can_use_weapon()`, `can_cast_spell()`, `get_cast_speed_modifier()`, `get_attack_damage_modifier()` 等方法，用于检查肢体损伤对战斗能力的影响。

### 4. 敌人单位增强 (`scenes/battle_test/entities/enemy.gd`)

- **新增属性:**
  - `use_voxel_system`: 是否启用二维体素战斗系统。
  - `body_parts`: 敌人肢体列表。
  - `movement_penalty`: 移动速度惩罚。

- **新增信号:**
  - `body_part_damaged(part, damage)`: 肢体受伤时触发。
  - `body_part_destroyed(part)`: 肢体被摧毁时触发。

- **核心逻辑变更:**
  - `take_damage()` 方法新增 `target_part_type` 参数，支持指定攻击目标肢体。
  - 新增 `_initialize_body_parts()` 方法，为敌人初始化简化版肢体系统。
  - 新增 `get_body_part()`, `get_functional_body_parts()`, `get_body_parts_summary()` 等方法。

## 新增文件

| 文件路径 | 描述 |
| :--- | :--- |
| `docs/development/VOXEL_COMBAT_SYSTEM_DESIGN.md` | 二维体素战斗系统的详细设计文档。 |
| `docs/development/VOXEL_COMBAT_TESTING_PLAN.md` | 系统测试计划和测试用例。 |
| `docs/archive/VOXEL_COMBAT_CHANGELOG.md` | 本变更日志。 |
| `scenes/test/voxel_combat_test.gd` | 测试场景脚本。 |
| `scenes/test/voxel_combat_test.tscn` | 测试场景文件。 |

## 修改文件

| 文件路径 | 修改摘要 |
| :--- | :--- |
| `resources/engraving/body_part_data.gd` | 增加损伤状态、效率、信号等。 |
| `scripts/combat/engraving_manager.gd` | 增加肢体功能检查、伤害路由等。 |
| `scripts/combat/player_controller.gd` | 增加肢体目标伤害、移动惩罚等。 |
| `scenes/battle_test/entities/enemy.gd` | 增加敌人肢体系统。 |
