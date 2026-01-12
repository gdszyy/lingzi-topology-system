# 法术嵌套结构 UI 展示功能

## 功能概述

本功能为灵子拓扑系统添加了完整的法术多层嵌套结构可视化界面,使用户能够直观地查看和理解复杂法术的层级关系。

## 核心组件

### 1. SpellNestingTreeView (法术嵌套树形视图)

**文件位置**: `scenes/player/ui/spell_nesting_tree_view.gd` 和 `.tscn`

**主要功能**:
- 以树状结构递归展示法术的完整嵌套层级
- 支持显示法术、载体、规则、动作的详细信息
- 根据嵌套深度使用不同颜色标识(最多6层颜色)
- 实时计算并显示嵌套深度和总节点数
- 支持展开/折叠节点,可按深度展开

**显示内容**:
- 📜 法术节点: 显示法术名称、Cost、冷却时间
- 🚀 载体配置: 显示相态、速度、寿命、质量
- ⚡ 拓扑规则: 显示触发器类型和动作数量
- 各类动作图标:
  - ⚔️ 伤害动作
  - 💥 裂变动作(关键:递归显示子法术)
  - 🌊 范围效果
  - 🧪 状态效果
  - 👻 召唤动作(支持显示召唤物的自定义法术)
  - ⛓️ 链式动作
  - 🛡️ 护盾动作
  - 🪞 反射动作
  - 🌀 位移动作
  - 💣 爆炸动作
  - 🔥 伤害区域

**关键特性**:
- **递归嵌套显示**: 自动识别 `FissionActionData.child_spell_data` 和 `SummonActionData.custom_spell_data`,递归创建子法术树
- **深度限制**: 默认最多显示10层嵌套,防止无限递归
- **颜色编码**: 不同深度使用不同背景色,便于识别层级
- **详细描述**: 每个节点都有详细的参数信息

### 2. SpellNestingViewer (嵌套查看器窗口)

**文件位置**: `scenes/player/ui/spell_nesting_viewer.gd` 和 `.tscn`

**主要功能**:
- 提供独立的弹出窗口展示嵌套结构
- 窗口大小可调整(默认800x600,最小600x400)
- 包含关闭按钮和窗口控制

### 3. 法术编辑器集成

**修改文件**: `scenes/battle_test/spell_editor.gd` 和 `.tscn`

**新增功能**:
- 在法术编辑器的按钮栏添加"查看嵌套结构"按钮
- 点击按钮自动保存当前编辑状态并打开嵌套查看器
- 支持在编辑过程中随时查看法术的完整结构

## 使用方法

### 在法术编辑器中使用

1. 打开法术编辑器(`scenes/battle_test/spell_editor.tscn`)
2. 加载或创建一个法术
3. 点击"查看嵌套结构"按钮
4. 在弹出的窗口中查看法术的完整嵌套树

### 独立使用

```gdscript
# 在任何场景中使用
var viewer_scene = preload("res://scenes/player/ui/spell_nesting_viewer.tscn")
var viewer = viewer_scene.instantiate()
get_tree().root.add_child(viewer)
viewer.show_spell(your_spell_data)

# 监听关闭事件
viewer.viewer_closed.connect(func(): viewer.queue_free())
```

### 测试场景

运行 `scenes/test/nesting_viewer_test.tscn` 可以测试嵌套查看器功能:
- 自动加载一个3层嵌套的复杂测试法术
- 包含裂变、召唤、伤害、范围效果等多种动作
- 演示完整的嵌套显示效果

## 技术实现

### 递归树构建

```gdscript
func _create_spell_node(parent: TreeItem, spell: SpellCoreData, depth: int, label: String) -> TreeItem:
    # 创建法术节点
    var spell_item = tree.create_item(parent)
    
    # 添加载体和规则
    _create_carrier_node(spell_item, spell.carrier, depth)
    for rule in spell.topology_rules:
        _create_rule_node(spell_item, rule, depth, spell)
    
    return spell_item

func _create_action_node(parent: TreeItem, action: ActionData, depth: int) -> TreeItem:
    # 创建动作节点
    var action_item = tree.create_item(parent)
    
    # 关键:检测裂变动作并递归
    if action is FissionActionData:
        var fission = action as FissionActionData
        if fission.child_spell_data != null:
            if depth + 1 < max_display_depth:
                # 递归创建子法术树
                _create_spell_node(action_item, fission.child_spell_data, depth + 1, "子法术")
    
    return action_item
```

### 深度计算

```gdscript
func _calculate_max_depth(spell: SpellCoreData, current_depth: int) -> int:
    var max_depth = current_depth
    
    for rule in spell.topology_rules:
        for action in rule.actions:
            if action is FissionActionData and fission.child_spell_data:
                var child_depth = _calculate_max_depth(fission.child_spell_data, current_depth + 1)
                max_depth = maxi(max_depth, child_depth)
    
    return max_depth
```

### 颜色编码

```gdscript
var depth_colors: Array[Color] = [
    Color(0.9, 0.9, 1.0),    # 第0层:浅蓝白
    Color(0.8, 1.0, 0.8),    # 第1层:浅绿
    Color(1.0, 1.0, 0.7),    # 第2层:浅黄
    Color(1.0, 0.9, 0.7),    # 第3层:浅橙
    Color(1.0, 0.8, 0.8),    # 第4层:浅红
    Color(0.9, 0.8, 1.0),    # 第5层:浅紫
]
```

## 信号系统

### SpellNestingTreeView 信号

```gdscript
signal node_selected(spell_data: SpellCoreData, depth: int)
signal child_spell_edit_requested(fission_action: FissionActionData)
```

- `node_selected`: 当用户选中树中的法术节点时触发
- `child_spell_edit_requested`: 当用户双击裂变动作时触发(预留用于编辑子法术)

### SpellNestingViewer 信号

```gdscript
signal viewer_closed
```

- `viewer_closed`: 窗口关闭时触发,用于清理资源

## 配置选项

### SpellNestingTreeView 导出变量

```gdscript
@export var show_detailed_info: bool = true       # 是否显示详细信息
@export var color_by_depth: bool = true           # 是否根据深度着色
@export var max_display_depth: int = 10           # 最大显示深度
```

## 扩展建议

### 1. 添加编辑功能

可以监听 `child_spell_edit_requested` 信号,实现双击子法术节点时打开子法术编辑器:

```gdscript
tree_view.child_spell_edit_requested.connect(func(fission_action):
    var child_editor = SpellEditor.new()
    child_editor.edit_spell(fission_action.child_spell_data)
    # ... 保存逻辑
)
```

### 2. 添加导出功能

可以添加导出按钮,将嵌套结构导出为文本或图片:

```gdscript
func export_to_text() -> String:
    return _export_recursive(current_spell, 0)

func _export_recursive(spell: SpellCoreData, depth: int) -> String:
    var indent = "  ".repeat(depth)
    var result = "%s- %s\n" % [indent, spell.spell_name]
    # ... 递归处理
    return result
```

### 3. 添加搜索功能

可以添加搜索框,高亮匹配的节点:

```gdscript
func search_nodes(keyword: String) -> void:
    _search_recursive(tree.get_root(), keyword)

func _search_recursive(item: TreeItem, keyword: String) -> void:
    if keyword in item.get_text(0):
        item.set_custom_bg_color(0, Color.YELLOW)
    # ... 递归处理
```

## 性能考虑

- **深度限制**: 默认最多显示10层,防止过深的递归导致性能问题
- **延迟加载**: 可以考虑实现节点的延迟展开,仅在用户点击时才创建子节点
- **缓存计算**: 深度和节点数等统计信息可以缓存,避免重复计算

## 已知限制

1. **最大深度**: 默认限制为10层,超过部分会显示警告
2. **颜色数量**: 仅预定义6种深度颜色,超过6层会循环使用
3. **窗口管理**: 每次打开都会创建新窗口,不会复用已有窗口

## 测试清单

- [x] 单层法术显示
- [x] 2层嵌套显示
- [x] 3层及以上嵌套显示
- [x] 召唤物自定义法术显示
- [x] 展开/折叠功能
- [x] 按深度展开功能
- [x] 节点选中事件
- [x] 信息面板更新
- [x] 窗口打开/关闭
- [x] 与法术编辑器集成

## 更新日志

### 2026-01-13
- ✅ 初始实现完成
- ✅ 创建 SpellNestingTreeView 组件
- ✅ 创建 SpellNestingViewer 窗口
- ✅ 集成到法术编辑器
- ✅ 创建测试场景
- ✅ 支持裂变动作的递归嵌套显示
- ✅ 支持召唤动作的自定义法术显示
- ✅ 实现深度颜色编码
- ✅ 实现统计信息显示

## 相关文件

### 新增文件
- `scenes/player/ui/spell_nesting_tree_view.gd` - 树形视图脚本
- `scenes/player/ui/spell_nesting_tree_view.tscn` - 树形视图场景
- `scenes/player/ui/spell_nesting_viewer.gd` - 查看器窗口脚本
- `scenes/player/ui/spell_nesting_viewer.tscn` - 查看器窗口场景
- `scenes/test/nesting_viewer_test.gd` - 测试场景脚本
- `scenes/test/nesting_viewer_test.tscn` - 测试场景

### 修改文件
- `scenes/battle_test/spell_editor.gd` - 添加查看嵌套按钮功能
- `scenes/battle_test/spell_editor.tscn` - 添加查看嵌套按钮UI

## 许可证

MIT License - 与项目主体保持一致
