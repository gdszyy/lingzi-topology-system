# 灵子视觉特效系统 - 实现文档

## 一、系统概述

本文档描述了"灵子拓扑构筑系统"视觉特效（VFX）系统的具体实现。该系统为游戏中的各种灵子形态、动作和状态效果提供了统一、模块化的视觉表现。

## 二、架构设计

### 2.1 目录结构

```
lingzi-topology-system/
├── scripts/vfx/                    # VFX脚本目录
│   ├── vfx_manager.gd             # 特效管理器（颜色配置、实例管理）
│   ├── vfx_factory.gd             # 特效工厂（统一创建接口）
│   ├── phase_projectile_vfx.gd    # 相态弹体特效
│   ├── impact_vfx.gd              # 命中特效
│   ├── trail_vfx.gd               # 拖尾特效
│   ├── fission_vfx.gd             # 裂变特效
│   ├── explosion_vfx.gd           # 爆炸特效
│   ├── damage_zone_vfx.gd         # 伤害区域特效
│   ├── status_effect_vfx.gd       # 状态效果特效
│   ├── shield_vfx.gd              # 护盾特效
│   ├── chain_vfx.gd               # 链式特效
│   ├── summon_vfx.gd              # 召唤特效
│   └── displacement_vfx.gd        # 位移特效
│
└── scenes/vfx/                     # VFX场景目录
    ├── phase_projectile_vfx.tscn
    ├── impact_vfx.tscn
    ├── trail_vfx.tscn
    ├── fission_vfx.tscn
    ├── explosion_vfx.tscn
    ├── damage_zone_vfx.tscn
    ├── status_effect_vfx.tscn
    ├── shield_vfx.tscn
    ├── chain_vfx.tscn
    ├── summon_vfx.tscn
    └── displacement_vfx.tscn
```

### 2.2 核心类

| 类名 | 职责 | 关键方法 |
|------|------|----------|
| **VFXManager** | 管理颜色配置、特效实例池 | `get_phase_colors()`, `spawn_effect()` |
| **VFXFactory** | 提供统一的特效创建接口 | `create_*_vfx()`, `spawn_at()` |

## 三、特效类型详解

### 3.1 相态视觉系统

#### PhaseProjectileVFX - 相态弹体特效

根据灵子的三种基础相态（固态、液态、等离子态）动态生成不同的视觉效果。

| 相态 | 核心形态 | 拖尾效果 | 环境粒子 |
|------|----------|----------|----------|
| **固态 (Solid)** | 六边形晶体 + 能量电路线 | 几何碎片 | 能量脉冲 |
| **液态 (Liquid)** | 液滴形态 + 内部漩涡 | 流动轨迹 | 气泡上升 |
| **等离子态 (Plasma)** | 不稳定能量球 + 电弧 | 炽热火焰 | 火星四溅 |

**使用示例：**
```gdscript
var projectile_vfx = VFXFactory.create_projectile_vfx(
    CarrierConfigData.Phase.PLASMA,  # 相态
    1.5,                              # 尺寸缩放
    Vector2(500, 0)                   # 速度
)
VFXFactory.spawn_at(projectile_vfx, spawn_position, self)
```

#### ImpactVFX - 命中特效

每种相态有独特的命中视觉反馈：

- **固态命中**：冲击波环 + 碎片飞溅 + 撞击闪光
- **液态命中**：液体飞溅 + 水波纹 + 冰晶覆盖
- **等离子命中**：能量爆发 + 火花粒子 + 热浪扭曲 + 焦痕

#### TrailVFX - 拖尾特效

动态跟随目标的拖尾效果，支持渐变和宽度曲线。

### 3.2 核心动作特效

#### FissionVFX - 裂变特效

展示灵子分裂时的蓄力和爆发效果：
1. **蓄力阶段**：能量向中心聚集，蓄力环收缩
2. **爆发阶段**：能量爆发，显示分裂方向指示器
3. **发射信号**：`fission_burst` 信号用于同步生成子弹

#### ExplosionVFX - 爆炸特效

范围能量释放的视觉效果：
- 核心闪光（快速膨胀）
- 冲击波扩散
- 碎片/火星粒子
- 烟雾效果
- 地面焦痕

#### DamageZoneVFX - 伤害区域特效

持续性领域控制的视觉表现：
- 区域边界（呼吸效果）
- 地面效果（根据相态不同）
- 环境粒子（持续发射）
- 伤害tick闪烁

### 3.3 状态效果特效

#### StatusEffectVFX - 状态效果特效

支持所有9种状态效果的视觉表现：

| 状态类型 | 视觉效果 |
|----------|----------|
| **熵燃 (ENTROPY_BURN)** | 火焰粒子 + 烧灼纹理 |
| **冷脆化 (CRYO_CRYSTAL)** | 冰晶覆盖 + 寒气粒子 |
| **结构锁 (STRUCTURE_LOCK)** | 能量法阵 + 锁链束缚 |
| **灵蚀 (SPIRITON_EROSION)** | 毒雾环绕 + 腐蚀斑点 |
| **相位紊乱 (PHASE_DISRUPTION)** | 故障艺术 + 扫描线 |
| **共振标记 (RESONANCE_MARK)** | 准星标记 + 旋转脉动 |
| **灵潮 (SPIRITON_SURGE)** | 能量光环 + 上升粒子 |
| **相移 (PHASE_SHIFT)** | 速度线 + 残影粒子 |
| **固壳 (SOLID_SHELL)** | 护甲板块覆盖 |

### 3.4 高级动作特效

#### ShieldVFX - 护盾特效

三种护盾类型的视觉表现：

| 类型 | 视觉效果 |
|------|----------|
| **个人护盾 (PERSONAL)** | 六边形网格 + 能量流动线 |
| **范围护盾 (AREA)** | 穹顶结构 + 同心圆网格 |
| **弹幕护盾 (PROJECTILE)** | 旋转护盾片 + 轨道环 |

**特殊功能：**
- `take_damage()` - 受击效果（涟漪 + 闪烁）
- `shield_hit` / `shield_broken` 信号

#### ChainVFX - 链式特效

四种链式类型的视觉表现：

| 类型 | 路径形态 | 颜色 |
|------|----------|------|
| **闪电链 (LIGHTNING)** | Z字形折线 | 电光蓝白 |
| **火焰链 (FIRE)** | 波浪形曲线 | 火焰橙黄 |
| **冰霜链 (ICE)** | 锯齿形路径 | 冰蓝白 |
| **虚空链 (VOID)** | 螺旋形路径 | 虚空紫 |

#### SummonVFX - 召唤特效

召唤物生成的完整视觉序列：
1. 法阵展开（多层圆环 + 符文）
2. 能量汇聚（粒子向中心聚集）
3. 能量光束（从法阵向上）
4. 召唤物轮廓显现
5. 特效消散

支持的召唤物类型：炮塔、仆从、环绕体、图腾等

#### DisplacementVFX - 位移特效

五种位移类型的视觉表现：

| 类型 | 视觉效果 |
|------|----------|
| **击退 (KNOCKBACK)** | 力场波弧 + 运动模糊 |
| **吸引 (PULL)** | 漩涡 + 吸引线 |
| **传送 (TELEPORT)** | 起点残影 + 终点闪现 |
| **击飞 (LAUNCH)** | 向上喷发 + 上升轨迹 |
| **冲刺 (DASH)** | 残影序列 + 速度线 |

## 四、使用指南

### 4.1 基本使用

```gdscript
# 方式1：使用VFXFactory（推荐）
var explosion = VFXFactory.create_explosion_vfx(
    CarrierConfigData.Phase.PLASMA,
    100.0,  # 半径
    0.5     # 衰减
)
VFXFactory.spawn_at(explosion, hit_position, get_tree().current_scene)

# 方式2：直接实例化场景
var scene = load("res://scenes/vfx/explosion_vfx.tscn")
var vfx = scene.instantiate()
vfx.initialize(CarrierConfigData.Phase.PLASMA, 100.0, 0.5)
vfx.global_position = hit_position
add_child(vfx)
```

### 4.2 信号连接

```gdscript
# 裂变特效 - 同步生成子弹
var fission_vfx = VFXFactory.create_fission_vfx(phase, 5, 120.0)
fission_vfx.fission_burst.connect(_on_fission_burst)
fission_vfx.effect_finished.connect(_on_effect_finished)

# 护盾特效 - 监听受击和破碎
var shield_vfx = VFXFactory.create_shield_vfx(ShieldActionData.ShieldType.PERSONAL, 100.0)
shield_vfx.shield_hit.connect(_on_shield_hit)
shield_vfx.shield_broken.connect(_on_shield_broken)
```

### 4.3 预加载

```gdscript
# 在游戏启动时预加载所有特效
func _ready():
    VFXFactory.preload_all()
```

## 五、颜色配置

### 5.1 相态颜色

所有相态颜色定义在 `VFXManager.PHASE_COLORS` 中：

```gdscript
const PHASE_COLORS = {
    CarrierConfigData.Phase.SOLID: {
        "primary": Color(0.8, 0.5, 0.2, 1.0),    # 大地棕
        "secondary": Color(1.0, 0.9, 0.7, 1.0),  # 亮白能量
        "glow": Color(0.9, 0.6, 0.3, 0.8),       # 暖光晕
        "trail": Color(0.7, 0.4, 0.2, 0.5),      # 拖尾
    },
    # ... 其他相态
}
```

### 5.2 扩展相态颜色

用于状态效果的五种灵子相态颜色定义在 `VFXManager.SPIRITON_PHASE_COLORS` 中。

### 5.3 链式类型颜色

四种链式类型的颜色定义在 `VFXManager.CHAIN_TYPE_COLORS` 中。

## 六、系统集成

### 6.1 已集成的组件

VFX系统已与以下法术系统组件完成集成：

| 组件 | 集成的特效 | 触发时机 |
|------|-----------|----------|
| **Projectile (弹体实体)** | 相态弹体、拖尾、命中、裂变、状态效果 | 初始化、碰撞、死亡 |
| **Explosion (爆炸实体)** | 爆炸特效 | 初始化 |
| **DamageZone (伤害区域)** | 伤害区域特效 | 初始化 |
| **SpellCaster (法术施放器)** | 裂变特效 | 裂变触发 |
| **ActionExecutor (动作执行器)** | 命中、状态、位移、护盾、爆炸、裂变、链式、召唤 | 动作执行 |
| **Enemy (敌人实体)** | 状态效果特效 | 状态施加/移除 |
| **ShieldSystem (护盾系统)** | 护盾特效 | 创建、受击、破碎、反弹 |

### 6.2 集成代码示例

**在弹体中集成相态特效：**
```gdscript
# projectile.gd
func _setup_vfx() -> void:
    # 创建相态弹体特效
    phase_vfx = VFXFactory.create_projectile_vfx(carrier.phase, carrier.size, velocity)
    if phase_vfx:
        add_child(phase_vfx)
    
    # 创建拖尾特效
    trail_vfx = VFXFactory.create_trail_vfx(carrier.phase, self, carrier.size * 6.0)
    if trail_vfx:
        get_tree().current_scene.add_child(trail_vfx)
```

**在敌人中集成状态效果特效：**
```gdscript
# enemy.gd
func apply_status(status_type: int, duration: float, value: float) -> void:
    var is_new_status = not status_effects.has(status_type)
    status_effects[status_type] = {"duration": duration, "value": value}
    
    if is_new_status:
        var status_vfx = VFXFactory.create_status_effect_vfx(status_type, duration, value, self)
        if status_vfx:
            get_tree().current_scene.add_child(status_vfx)
            status_vfx_instances[status_type] = status_vfx
```

## 七、扩展开发

### 6.1 添加新的特效类型

1. 在 `scripts/vfx/` 下创建新的特效脚本
2. 在 `scenes/vfx/` 下创建对应的场景文件
3. 在 `VFXFactory.SCENE_PATHS` 中注册路径
4. 在 `VFXFactory` 中添加创建方法

### 6.2 自定义颜色

可以通过修改 `VFXManager` 中的颜色常量来自定义视觉风格。

---

*本文档为灵子拓扑系统VFX实现的技术规范。*
