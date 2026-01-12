extends Control
class_name SpellNestingTreeView
## 法术嵌套结构树形视图
## 以树状结构展示法术的多层嵌套关系

signal node_selected(spell_data: SpellCoreData, depth: int)
signal child_spell_edit_requested(fission_action: FissionActionData)

@export var show_detailed_info: bool = true
@export var color_by_depth: bool = true
@export var max_display_depth: int = 10

@onready var tree: Tree = $VBox/Tree
@onready var info_label: Label = $VBox/InfoPanel/InfoLabel
@onready var depth_indicator: Label = $VBox/InfoPanel/DepthIndicator
@onready var complexity_label: Label = $VBox/InfoPanel/ComplexityLabel

var current_spell: SpellCoreData = null
var depth_colors: Array[Color] = [
	Color(0.9, 0.9, 1.0),    # 第0层：浅蓝白
	Color(0.8, 1.0, 0.8),    # 第1层：浅绿
	Color(1.0, 1.0, 0.7),    # 第2层：浅黄
	Color(1.0, 0.9, 0.7),    # 第3层：浅橙
	Color(1.0, 0.8, 0.8),    # 第4层：浅红
	Color(0.9, 0.8, 1.0),    # 第5层：浅紫
]

func _ready() -> void:
	_setup_tree()
	_connect_signals()

func _setup_tree() -> void:
	tree.columns = 3
	tree.set_column_title(0, "法术结构")
	tree.set_column_title(1, "类型")
	tree.set_column_title(2, "详情")
	tree.set_column_titles_visible(true)
	tree.hide_root = true
	tree.allow_reselect = true
	tree.set_column_expand(0, true)
	tree.set_column_expand(1, false)
	tree.set_column_expand(2, true)
	tree.set_column_custom_minimum_width(1, 80)
	tree.set_column_custom_minimum_width(2, 200)

func _connect_signals() -> void:
	tree.item_selected.connect(_on_tree_item_selected)
	tree.item_activated.connect(_on_tree_item_activated)

## 加载并显示法术的嵌套结构
func load_spell(spell: SpellCoreData) -> void:
	current_spell = spell
	_refresh_tree()

## 刷新整个树视图
func _refresh_tree() -> void:
	tree.clear()
	var root = tree.create_item()
	
	if current_spell == null:
		info_label.text = "未加载法术"
		depth_indicator.text = "嵌套深度: 0"
		complexity_label.text = "复杂度: 0"
		return
	
	# 创建根法术节点
	_create_spell_node(root, current_spell, 0, "根法术")
	
	# 更新统计信息
	var max_depth = _calculate_max_depth(current_spell, 0)
	var total_nodes = _count_total_nodes(current_spell)
	depth_indicator.text = "嵌套深度: %d" % max_depth
	complexity_label.text = "总节点数: %d" % total_nodes
	info_label.text = "法术: %s" % current_spell.spell_name

## 创建法术节点及其所有子节点
func _create_spell_node(parent: TreeItem, spell: SpellCoreData, depth: int, label: String) -> TreeItem:
	var spell_item = tree.create_item(parent)
	
	# 设置法术基本信息
	var depth_prefix = "  ".repeat(depth) if depth > 0 else ""
	spell_item.set_text(0, "%s📜 %s" % [depth_prefix, label])
	spell_item.set_text(1, "法术")
	spell_item.set_text(2, "Cost: %.0f | CD: %.1fs" % [spell.resource_cost, spell.cooldown])
	
	# 根据深度设置颜色
	if color_by_depth and depth < depth_colors.size():
		var color = depth_colors[depth]
		spell_item.set_custom_bg_color(0, color)
		spell_item.set_custom_bg_color(1, color)
		spell_item.set_custom_bg_color(2, color)
	
	# 存储元数据
	spell_item.set_metadata(0, {
		"type": "spell",
		"spell_data": spell,
		"depth": depth
	})
	
	# 添加载体信息
	if spell.carrier != null:
		_create_carrier_node(spell_item, spell.carrier, depth)
	
	# 添加拓扑规则
	for i in range(spell.topology_rules.size()):
		var rule = spell.topology_rules[i]
		_create_rule_node(spell_item, rule, i, depth, spell)
	
	return spell_item

## 创建载体配置节点
func _create_carrier_node(parent: TreeItem, carrier: CarrierConfigData, depth: int) -> TreeItem:
	var carrier_item = tree.create_item(parent)
	
	var phase_name = ["固态", "液态", "等离子态"][carrier.phase]
	carrier_item.set_text(0, "  🚀 载体配置")
	carrier_item.set_text(1, phase_name)
	carrier_item.set_text(2, "速度: %.0f | 寿命: %.1fs | 质量: %.1f" % [carrier.velocity, carrier.lifetime, carrier.mass])
	
	carrier_item.set_metadata(0, {
		"type": "carrier",
		"carrier_data": carrier,
		"depth": depth
	})
	
	return carrier_item

## 创建规则节点
func _create_rule_node(parent: TreeItem, rule: TopologyRuleData, index: int, depth: int, spell: SpellCoreData) -> TreeItem:
	var rule_item = tree.create_item(parent)
	
	var trigger_name = rule.trigger.get_type_name() if rule.trigger else "无触发器"
	rule_item.set_text(0, "  ⚡ 规则 %d: %s" % [index + 1, rule.rule_name])
	rule_item.set_text(1, trigger_name)
	rule_item.set_text(2, "%d个动作" % rule.actions.size())
	
	rule_item.set_metadata(0, {
		"type": "rule",
		"rule_data": rule,
		"depth": depth
	})
	
	# 添加动作节点
	for j in range(rule.actions.size()):
		var action = rule.actions[j]
		_create_action_node(rule_item, action, j, depth, spell)
	
	return rule_item

## 创建动作节点(关键：处理嵌套)
func _create_action_node(parent: TreeItem, action: ActionData, index: int, depth: int, parent_spell: SpellCoreData) -> TreeItem:
	var action_item = tree.create_item(parent)
	
	var action_icon = _get_action_icon(action)
	var action_desc = _get_action_description(action)
	
	action_item.set_text(0, "    %s 动作 %d" % [action_icon, index + 1])
	action_item.set_text(1, action.get_type_name())
	action_item.set_text(2, action_desc)
	
	action_item.set_metadata(0, {
		"type": "action",
		"action_data": action,
		"depth": depth
	})
	
	# 关键：如果是裂变动作且有子法术，递归创建子法术树
	if action is FissionActionData:
		var fission = action as FissionActionData
		if fission.child_spell_data != null and fission.child_spell_data is SpellCoreData:
			var child_spell = fission.child_spell_data as SpellCoreData
			
			# 检查深度限制
			if depth + 1 < max_display_depth:
				_create_spell_node(action_item, child_spell, depth + 1, "子法术: %s" % child_spell.spell_name)
			else:
				var warning_item = tree.create_item(action_item)
				warning_item.set_text(0, "      ⚠️ 已达最大显示深度")
				warning_item.set_custom_color(0, Color.ORANGE)
	
	# 如果是召唤动作，显示召唤物信息
	elif action is SummonActionData:
		var summon = action as SummonActionData
		if summon.custom_spell_data != null and summon.custom_spell_data is SpellCoreData:
			var summon_spell = summon.custom_spell_data as SpellCoreData
			if depth + 1 < max_display_depth:
				_create_spell_node(action_item, summon_spell, depth + 1, "召唤物法术: %s" % summon_spell.spell_name)
	
	return action_item

## 获取动作图标
func _get_action_icon(action: ActionData) -> String:
	if action is DamageActionData:
		return "⚔️"
	elif action is FissionActionData:
		return "💥"
	elif action is AreaEffectActionData:
		return "🌊"
	elif action is ApplyStatusActionData:
		return "🧪"
	elif action is SummonActionData:
		return "👻"
	elif action is ChainActionData:
		return "⛓️"
	elif action is ShieldActionData:
		return "🛡️"
	elif action is ReflectActionData:
		return "🪞"
	elif action is DisplacementActionData:
		return "🌀"
	elif action is SpawnExplosionActionData:
		return "💣"
	elif action is SpawnDamageZoneActionData:
		return "🔥"
	return "✨"

## 获取动作详细描述
func _get_action_description(action: ActionData) -> String:
	if action is DamageActionData:
		var dmg = action as DamageActionData
		return "伤害: %.1f × %.2f" % [dmg.damage_value, dmg.damage_multiplier]
	
	elif action is FissionActionData:
		var fission = action as FissionActionData
		var child_name = "无"
		if fission.child_spell_data != null and fission.child_spell_data is SpellCoreData:
			child_name = fission.child_spell_data.spell_name
		return "分裂: %d个 | 角度: %.0f° | 子法术: %s" % [fission.spawn_count, fission.spread_angle, child_name]
	
	elif action is AreaEffectActionData:
		var area = action as AreaEffectActionData
		return "范围: 半径 %.0f | 伤害: %.1f" % [area.radius, area.damage_value]
	
	elif action is ApplyStatusActionData:
		var status = action as ApplyStatusActionData
		var status_names = ["灼烧", "冻结", "中毒", "虚弱", "减速", "眩晕"]
		var status_name = status_names[status.status_type] if status.status_type < status_names.size() else "未知"
		return "状态: %s | 持续: %.1fs | 层数: %d" % [status_name, status.duration, status.stacks]
	
	elif action is SummonActionData:
		var summon = action as SummonActionData
		var summon_types = ["炮塔", "仆从", "环绕体", "诱饵", "屏障", "图腾"]
		var summon_type_name = summon_types[summon.summon_type] if summon.summon_type < summon_types.size() else "未知"
		return "召唤: %s × %d | 持续: %.1fs | 伤害: %.1f" % [summon_type_name, summon.summon_count, summon.summon_duration, summon.summon_damage]
	
	elif action is ChainActionData:
		var chain = action as ChainActionData
		return "链式: %d跳 | 范围: %.0f | 伤害衰减: %.0f%%" % [chain.max_jumps, chain.jump_range, chain.damage_falloff * 100]
	
	elif action is ShieldActionData:
		var shield = action as ShieldActionData
		return "护盾: 吸收 %.0f | 持续: %.1fs" % [shield.shield_amount, shield.shield_duration]
	
	elif action is ReflectActionData:
		var reflect = action as ReflectActionData
		return "反射: 持续 %.1fs | 倍率: %.1fx" % [reflect.reflect_duration, reflect.reflect_multiplier]
	
	elif action is DisplacementActionData:
		var disp = action as DisplacementActionData
		return "位移: 距离 %.0f | 速度: %.0f" % [disp.displacement_distance, disp.displacement_speed]
	
	elif action is SpawnExplosionActionData:
		var exp = action as SpawnExplosionActionData
		return "爆炸: 伤害 %.1f | 半径: %.0f" % [exp.explosion_damage, exp.explosion_radius]
	
	elif action is SpawnDamageZoneActionData:
		var zone = action as SpawnDamageZoneActionData
		return "伤害区: 伤害 %.1f/s | 持续: %.1fs" % [zone.zone_damage, zone.zone_duration]
	
	return action.get_type_name()

## 计算最大嵌套深度
func _calculate_max_depth(spell: SpellCoreData, current_depth: int) -> int:
	var max_depth = current_depth
	
	for rule in spell.topology_rules:
		for action in rule.actions:
			if action is FissionActionData:
				var fission = action as FissionActionData
				if fission.child_spell_data != null and fission.child_spell_data is SpellCoreData:
					var child_depth = _calculate_max_depth(fission.child_spell_data, current_depth + 1)
					max_depth = maxi(max_depth, child_depth)
			
			elif action is SummonActionData:
				var summon = action as SummonActionData
				if summon.custom_spell_data != null and summon.custom_spell_data is SpellCoreData:
					var child_depth = _calculate_max_depth(summon.custom_spell_data, current_depth + 1)
					max_depth = maxi(max_depth, child_depth)
	
	return max_depth

## 计算总节点数
func _count_total_nodes(spell: SpellCoreData) -> int:
	var count = 1  # 法术本身
	
	if spell.carrier != null:
		count += 1
	
	for rule in spell.topology_rules:
		count += 1  # 规则
		count += rule.actions.size()  # 动作
		
		for action in rule.actions:
			if action is FissionActionData:
				var fission = action as FissionActionData
				if fission.child_spell_data != null and fission.child_spell_data is SpellCoreData:
					count += _count_total_nodes(fission.child_spell_data)
			
			elif action is SummonActionData:
				var summon = action as SummonActionData
				if summon.custom_spell_data != null and summon.custom_spell_data is SpellCoreData:
					count += _count_total_nodes(summon.custom_spell_data)
	
	return count

## 树节点选中事件
func _on_tree_item_selected() -> void:
	var selected = tree.get_selected()
	if selected == null:
		return
	
	var metadata = selected.get_metadata(0)
	if metadata == null:
		return
	
	var type = metadata.get("type", "")
	var depth = metadata.get("depth", 0)
	
	# 更新信息面板
	match type:
		"spell":
			var spell = metadata.get("spell_data")
			info_label.text = "法术: %s | 深度: %d" % [spell.spell_name, depth]
			node_selected.emit(spell, depth)
		
		"carrier":
			var carrier = metadata.get("carrier_data")
			var phase_name = ["固态", "液态", "等离子态"][carrier.phase]
			info_label.text = "载体: %s相态 | 速度: %.0f | 寿命: %.1fs" % [phase_name, carrier.velocity, carrier.lifetime]
		
		"rule":
			var rule = metadata.get("rule_data")
			info_label.text = "规则: %s | %d个动作" % [rule.rule_name, rule.actions.size()]
		
		"action":
			var action = metadata.get("action_data")
			info_label.text = "动作: %s | %s" % [action.get_type_name(), _get_action_description(action)]

## 树节点双击事件
func _on_tree_item_activated() -> void:
	var selected = tree.get_selected()
	if selected == null:
		return
	
	var metadata = selected.get_metadata(0)
	if metadata == null:
		return
	
	var type = metadata.get("type", "")
	
	# 如果是裂变动作，发出编辑请求信号
	if type == "action":
		var action = metadata.get("action_data")
		if action is FissionActionData:
			child_spell_edit_requested.emit(action)

## 展开所有节点
func expand_all() -> void:
	_expand_recursive(tree.get_root())

func _expand_recursive(item: TreeItem) -> void:
	if item == null:
		return
	
	item.collapsed = false
	var child = item.get_first_child()
	while child != null:
		_expand_recursive(child)
		child = child.get_next()

## 折叠所有节点
func collapse_all() -> void:
	_collapse_recursive(tree.get_root())

func _collapse_recursive(item: TreeItem) -> void:
	if item == null:
		return
	
	item.collapsed = true
	var child = item.get_first_child()
	while child != null:
		_collapse_recursive(child)
		child = child.get_next()

## 展开到指定深度
func expand_to_depth(target_depth: int) -> void:
	_expand_to_depth_recursive(tree.get_root(), 0, target_depth)

func _expand_to_depth_recursive(item: TreeItem, current_depth: int, target_depth: int) -> void:
	if item == null:
		return
	
	if current_depth < target_depth:
		item.collapsed = false
	else:
		item.collapsed = true
	
	var child = item.get_first_child()
	while child != null:
		_expand_to_depth_recursive(child, current_depth + 1, target_depth)
		child = child.get_next()

## 清空树
func clear() -> void:
	tree.clear()
	current_spell = null
	info_label.text = "未加载法术"
	depth_indicator.text = "嵌套深度: 0"
	complexity_label.text = "复杂度: 0"
