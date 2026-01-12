# 法术投掷物视觉优化设计文档

**作者**: Manus AI
**日期**: 2026年1月12日
**项目**: lingzi-topology-system

## 1. 简介

本文档旨在为 `lingzi-topology-system` 项目中的法术投掷物（Projectile）提供一套全面的视觉优化方案。当前系统已经根据投掷物的“相态”（固态、液态、等离子态）实现了基础的视觉区分，但仍有较大的提升空间。新的设计将引入更多动态和数据驱动的视觉元素，以响应用户的具体需求，增强游戏的视觉表现力和信息传达能力。

优化将围绕以下几个核心维度展开：

- **基础形状 (Base Shape)**: 根据投掷物的核心属性（相态、速度、嵌套层级）生成更具表现力的几何外形。
- **颜色系统 (Color System)**: 建立一个多层次的颜色方案，反映投掷物携带的状态效果和其嵌套结构。
- **特殊效果 (Special Effects)**: 为具有特定能力（如链接伤害、护盾）的投掷物设计独特的视觉标识。

## 2. 现有系统分析

在进行新设计之前，我们首先对现有代码库进行了分析，关键文件和逻辑如下：

- **`projectile.gd`**: 投掷物的主逻辑脚本。它通过 `_setup_visuals` 和 `_setup_vfx` 函数初始化视觉效果，主要依赖于 `CarrierConfigData` 中的 `phase` 属性。
- **`phase_projectile_vfx.gd`**: 核心的投掷物视觉效果脚本。该脚本根据不同的 `phase`，调用 `_setup_solid_visuals`, `_setup_liquid_visuals`, `_setup_plasma_visuals` 函数来创建不同的形状和粒子效果。
- **`carrier_config_data.gd`**: 定义了投掷物载体的基础物理属性，如 `phase`, `velocity`, `size` 等。
- **`spell_core_data.gd`**: 定义了法术的整体结构，包含了载体（`carrier`）和拓扑规则（`topology_rules`）。嵌套关系通过 `FissionActionData` 中的 `child_spell_data` 实现。
- **`vfx_manager.gd`**: 存储了游戏中使用的核心调色板，包括 `PHASE_COLORS` (基础相态) 和 `SPIRITON_PHASE_COLORS` (状态效果相态)。
- **`shield_vfx.gd`** 和 **`chain_action_data.gd`**: 分别定义了护盾和链接效果的逻辑和数据结构。

现有系统已经为数据驱动的视觉设计奠定了良好基础，但视觉元素的复杂度有待提高。

## 3. 优化设计方案

为了实现用户提出的需求，我们将对现有系统进行扩展和修改。核心的改动将集中在 `phase_projectile_vfx.gd` 文件中，同时会引入新的参数传递机制。

### 3.1. 投掷物属性扩展

为了将更多信息传递给视觉层，我们需要在 `PhaseProjectileVFX` 节点中增加新的属性。`projectile.gd` 在初始化 `PhaseProjectileVFX` 时将负责传递这些值。

将在 `phase_projectile_vfx.gd` 中添加以下变量：

```gdscript
# 新增变量
@export var spell_data: SpellCoreData = null
@export var nesting_level: int = 0

# 修改 initialize 函数签名
func initialize(p_spell_data: SpellCoreData, p_nesting_level: int = 0) -> void:
    self.spell_data = p_spell_data
    self.nesting_level = p_nesting_level
    if self.spell_data and self.spell_data.carrier:
        self.phase = self.spell_data.carrier.phase
        self.size_scale = self.spell_data.carrier.size
        self.velocity = # 从 projectile 获取
    _setup_visuals()
```

### 3.2. 基础形状生成 (Base Shape Generation)

我们将重构 `_setup_*_visuals` 系列函数，使其能够根据速度和嵌套层级动态调整形状。

| 属性 | 固态 (Solid) | 液态 (Liquid) | 等离子态 (Plasma) |
| :--- | :--- | :--- | :--- |
| **基础形态** | 棱角分明的晶体 | 不规则的流动液滴 | 不稳定的能量球体 |
| **速度影响** | 速度越快，形状越趋向于拉长的尖锥形，尾部出现更多细小碎片。 | 速度越快，液滴被拉得更长，尾部拖拽出更多细小液珠。 | 速度越快，能量球体变得不稳定，外层火焰向后拖拽，核心更亮。 |
| **嵌套影响** | 每增加一层嵌套，晶体核心会增加一个更小、更亮的内层晶体结构。 | 每增加一层嵌套，液滴内部会出现一个旋转的、颜色不同的漩涡。 | 每增加一层嵌套，能量核心会变得更加明亮和不稳定，并产生更多电弧。 |

**实现思路**: 在 `_setup_*_visuals` 函数中，读取 `spell_data.carrier.velocity` 和 `nesting_level` 变量，通过 `lerp` (线性插值) 或其他数学函数来调整 `Polygon2D` 的顶点位置和粒子发射器的参数。

### 3.3. 颜色系统设计 (Color System)

颜色系统将变得更加丰富，以反映状态效果和嵌套关系。

1.  **主色调 (Primary Color)**: 投掷物的基础颜色依然由其 `phase` 决定，使用 `VFXManager.PHASE_COLORS`。

2.  **状态效果颜色 (Status Effect Color)**: 检查 `spell_data.topology_rules` 中是否存在 `ApplyStatusActionData`。如果存在，我们将使用 `VFXManager.SPIRITON_PHASE_COLORS` 中对应的颜色来点缀投掷物。例如，可以将其作为辉光（Glow）或次要细节（Secondary）的颜色。

    ```gdscript
    # 在 _setup_visuals 中
    var status_color = null
    for rule in spell_data.topology_rules:
        for action in rule.actions:
            if action is ApplyStatusActionData:
                var status_action = action as ApplyStatusActionData
                status_color = VFXManager.get_spiriton_phase_colors(status_action.spiriton_phase).secondary
                break
        if status_color: break

    # 在创建视觉组件时使用 status_color
    if status_color:
        glow_visual.color = status_color
    ```

3.  **嵌套颜色 (Nested Color)**: 如果 `nesting_level > 0`，我们需要为投掷物创建一个内部核心，并赋予其子法术（`child_spell_data`）的颜色。这需要 `FissionActionData` 能正确地将子法术信息传递下来。

    **实现思路**: 在 `projectile.gd` 中追踪当前的嵌套层级。当发生裂变（Fission）时，为子投掷物传入 `current_nesting_level + 1`。在 `phase_projectile_vfx.gd` 中，如果 `nesting_level > 0`，则创建一个额外的 `Polygon2D` 作为内部核心，其颜色来自于 `child_spell_data` 的相态。

### 3.4. 特殊效果实现 (Special Effects)

#### 3.4.1. 链接伤害 (Chain Damage)

对于包含 `ChainActionData` 的投掷物，我们将在其飞行过程中周期性地迸发出微小的电弧，以预示其链接能力。

**实现思路**: 在 `phase_projectile_vfx.gd` 的 `_process` 函数中，检查 `spell_data` 是否包含 `ChainActionData`。如果包含，则每隔一小段时间（例如 0.2 秒）就在投掷物表面随机位置生成一个短暂的、细小的电弧 `Line2D` 效果。

#### 3.4.2. 护盾效果 (Shield Effect)

对于带有 `ShieldActionData` 且 `shield_type` 为 `PROJECTILE` 的投掷物，我们将在其表面渲染一个流动的能量护盾。

**实现思路**: 现有 `shield_vfx.gd` 中已经实现了六边形护盾的视觉效果。我们将修改 `projectile.gd`，当检测到 `ShieldActionData` 时，直接在投掷物节点下实例化一个 `ShieldVFX` 节点，并将其设置为适合投掷物的尺寸和样式。

具体来说，在 `projectile.gd` 的 `_setup_vfx` 函数中增加逻辑：

```gdscript
# 在 projectile.gd 的 _setup_vfx 中
for rule in spell_data.topology_rules:
    for action in rule.actions:
        if action is ShieldActionData and action.shield_type == ShieldActionData.ShieldType.PROJECTILE:
            var shield_vfx = VFXFactory.create_shield_vfx(action.shield_type, action.shield_amount, action.shield_duration, carrier.size * 20.0, self)
            if shield_vfx:
                add_child(shield_vfx)
                # 调整 shield_vfx 的视觉参数以适应投掷物
                shield_vfx.get_node("HexagonalShell").scale = Vector2.ONE * carrier.size
            break
```

我们将修改 `shield_vfx.gd`，使其能更好地作为子节点工作，并实现用户期望的“流动蜂巢格”效果。这可以通过在 `_update_animations` 中为六边形网格的 `ShaderMaterial` 更新 `time` uniform 来实现，从而创造出能量流动的视觉感受。

## 4. 实施计划

1.  **阶段一：扩展数据结构**
    -   修改 `PhaseProjectileVFX`，增加 `spell_data` 和 `nesting_level` 属性。
    -   调整 `projectile.gd` 中 `initialize` 和 `fission` 相关逻辑，正确传递新增的属性。

2.  **阶段二：实现基础形状和颜色**
    -   重构 `phase_projectile_vfx.gd` 中的 `_setup_*_visuals` 函数，实现基于速度和嵌套层级的形状变化。
    -   实现新的颜色逻辑，融合状态效果和嵌套颜色。

3.  **阶段三：实现特殊效果**
    -   在 `phase_projectile_vfx.gd` 中添加链接伤害的闲置电弧特效。
    -   集成和调整 `shield_vfx.gd`，为投掷物添加流动的蜂巢护盾效果。

4.  **阶段四：测试与整合**
    -   创建测试场景，验证不同属性组合下的视觉表现是否符合设计预期。
    -   修复 Bug 并进行性能优化。

通过以上设计，我们期望能够显著提升法术投掷物的视觉质量，使其外观能够准确、丰富地反映其内在属性和能力，从而提升整体游戏体验。
