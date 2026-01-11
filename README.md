# 灵子拓扑构筑系统 - 遗传算法法术生成器

基于 Godot 4.5 实现的法术自动生成与评估系统，使用遗传算法在"灵子拓扑构筑系统"的设计框架下进化出新颖、强大且平衡的法术。

## 系统概述

本系统将修仙世界观与物理学概念融合，用"相态"、"热力学"、"裂变"等术语替代传统魔法概念，构建了一套独特的法术编辑体系。通过遗传算法，系统能够自动探索和发现新颖的法术组合。

## 项目结构

```
lingzi-topology-system/
├── resources/                    # 数据资源
│   ├── spell_data/              # 法术核心数据
│   │   ├── spell_core_data.gd   # 法术核心类
│   │   ├── carrier_config_data.gd # 载体配置
│   │   └── topology_rule_data.gd  # 拓扑规则
│   ├── triggers/                # 触发器
│   │   ├── trigger_data.gd      # 触发器基类
│   │   ├── on_timer_trigger.gd  # 定时触发器
│   │   └── on_proximity_trigger.gd # 接近触发器
│   └── actions/                 # 效果动作
│       ├── action_data.gd       # 动作基类
│       ├── damage_action_data.gd # 伤害动作
│       ├── fission_action_data.gd # 裂变动作
│       ├── apply_status_action_data.gd # 状态效果
│       └── area_effect_action_data.gd  # 范围效果
├── scripts/
│   ├── core/
│   │   └── spell_factory.gd     # 法术工厂
│   ├── genetic_algorithm/
│   │   ├── genetic_algorithm_manager.gd # GA主控制器
│   │   ├── genetic_operators.gd  # 遗传操作（交叉、变异）
│   │   └── selection_methods.gd  # 选择方法
│   └── evaluation/
│       ├── evaluation_manager.gd # 评估管理器
│       ├── fitness_calculator.gd # 适应度计算器
│       ├── fitness_config.gd     # 适应度配置
│       └── simulation_data_collector.gd # 数据收集器
├── scenes/
│   ├── test/                    # GA测试场景
│   │   ├── test_main.tscn       # 遗传算法测试界面
│   │   └── cli_test.gd          # 命令行测试
│   └── battle_test/             # 法术测试场
│       ├── battle_test_scene.tscn # 可视化测试场景
│       ├── battle_test_scene.gd  # 测试场景脚本
│       ├── test_result_recorder.gd # 测试结果记录器
│       └── entities/            # 游戏实体
│           ├── projectile.tscn  # 子弹/法术实体
│           ├── projectile.gd
│           ├── enemy.tscn       # 敌人实体
│           ├── enemy.gd
│           └── spell_caster.gd  # 法术发射器
└── project.godot                # 项目配置
```

## 核心功能

### 1. 遗传算法法术生成

- **基因编码**: 直接树状编码，将法术结构作为基因组
- **交叉操作**: 子树交换交叉，组合两个父代的法术逻辑
- **变异操作**: 参数变异 + 结构变异，引入新的遗传物质
- **选择方法**: 支持轮盘赌、锦标赛、排名选择等多种策略

### 2. 法术测试场 (新增)

可视化测试生成的法术效果，支持多种测试场景：

| 场景 | 描述 | 测试重点 |
|------|------|----------|
| 单体目标 | 1个静止高血量敌人 | DPS、单体伤害 |
| 群体目标 | 5个分散的敌人 | AOE能力、清场效率 |
| 移动目标 | 3个不同移动模式的敌人 | 命中率、追踪能力 |
| 生存模式 | 持续生成敌人 | 持续输出、资源效率 |

**测试场功能**:
- 实时显示 DPS、命中率等统计
- 支持自动发射和手动发射
- 可从遗传算法加载最佳法术
- 记录和比较测试结果

### 3. 法术数据结构

- **SpellCoreData**: 法术核心，包含载体配置和拓扑规则
- **CarrierConfigData**: 载体配置，定义法术的物理属性（相态、质量、速度等）
- **TopologyRuleData**: 拓扑规则，定义触发条件和效果
- **TriggerData**: 触发器，定义何时触发效果
- **ActionData**: 动作，定义触发后执行的效果

## 使用方法

### 快速开始

1. 用 Godot 4.5 打开项目
2. 运行项目（默认打开法术测试场）
3. 选择测试场景和法术
4. 点击"开始测试"观察效果

### 遗传算法生成法术

1. 打开 `scenes/test/test_main.tscn` 场景
2. 配置进化参数（种群大小、最大代数、变异率）
3. 点击"开始进化"按钮
4. 等待进化完成，查看最佳法术

### 在测试场中测试法术

1. 打开 `scenes/battle_test/battle_test_scene.tscn`
2. 点击"从GA加载最佳法术"导入进化结果
3. 选择测试场景（单体/群体/移动/生存）
4. 选择要测试的法术
5. 点击"开始测试"或手动点击发射

## 配置说明

### 进化参数

| 参数 | 默认值 | 说明 |
|------|--------|------|
| population_size | 50 | 种群大小 |
| max_generations | 100 | 最大进化代数 |
| crossover_rate | 0.8 | 交叉概率 |
| mutation_rate | 0.1 | 变异概率 |
| elitism_count | 2 | 精英保留数量 |
| tournament_size | 3 | 锦标赛大小 |

### 适应度权重

| 指标 | 默认权重 | 说明 |
|------|----------|------|
| damage | 0.25 | 总伤害 |
| ttk | 0.20 | 击杀时间 |
| accuracy | 0.15 | 命中率 |
| resource_efficiency | 0.15 | 资源效率 |
| overkill | 0.10 | 过量伤害惩罚 |
| instability | 0.15 | 不稳定性惩罚 |

## 扩展开发

### 添加新的触发器类型

1. 在 `resources/triggers/` 下创建新的触发器类
2. 继承 `TriggerData` 并实现必要方法
3. 在 `TriggerData.from_dict()` 中添加解析逻辑
4. 在 `GeneticOperators._generate_random_trigger()` 中添加生成逻辑

### 添加新的动作类型

1. 在 `resources/actions/` 下创建新的动作类
2. 继承 `ActionData` 并实现必要方法
3. 在 `ActionData.from_dict()` 中添加解析逻辑
4. 在 `GeneticOperators._generate_random_action()` 中添加生成逻辑
5. 在 `Projectile._execute_action()` 中添加执行逻辑

### 添加新的测试场景

1. 在 `BattleTestScene._setup_scenario_options()` 中添加选项
2. 在 `BattleTestScene._spawn_enemies_for_scenario()` 中添加敌人生成逻辑

## 许可证

MIT License

## 作者

Manus AI
