# spell_editor.gd
# 法术编辑器 - 支持嵌套规则的法术编辑界面
extends Control
class_name SpellEditor

## 信号
signal spell_saved(spell: SpellCoreData)
signal editor_closed

## 当前编辑的法术
var current_spell: SpellCoreData = null
var is_editing_child_spell: bool = false
var parent_editor: SpellEditor = null
var child_editor: SpellEditor = null

## UI 引用 - 主面板
@onready var spell_name_edit: LineEdit = $MainPanel/VBox/SpellNameEdit
@onready var cost_spin: SpinBox = $MainPanel/VBox/CostContainer/CostSpin
@onready var cooldown_spin: SpinBox = $MainPanel/VBox/CooldownContainer/CooldownSpin

## UI 引用 - 载体配置
@onready var carrier_type_option: OptionButton = $MainPanel/VBox/CarrierSection/CarrierTypeOption
@onready var phase_option: OptionButton = $MainPanel/VBox/CarrierSection/PhaseOption
@onready var velocity_spin: SpinBox = $MainPanel/VBox/CarrierSection/VelocitySpin
@onready var lifetime_spin: SpinBox = $MainPanel/VBox/CarrierSection/LifetimeSpin
@onready var mass_spin: SpinBox = $MainPanel/VBox/CarrierSection/MassSpin
@onready var size_spin: SpinBox = $MainPanel/VBox/CarrierSection/SizeSpin
@onready var piercing_spin: SpinBox = $MainPanel/VBox/CarrierSection/PiercingSpin
@onready var homing_spin: SpinBox = $MainPanel/VBox/CarrierSection/HomingSpin

## UI 引用 - 规则列表
@onready var rules_tree: Tree = $MainPanel/VBox/RulesSection/RulesTree
@onready var add_rule_button: Button = $MainPanel/VBox/RulesSection/RuleButtons/AddRuleButton
@onready var delete_rule_button: Button = $MainPanel/VBox/RulesSection/RuleButtons/DeleteRuleButton
@onready var edit_rule_button: Button = $MainPanel/VBox/RulesSection/RuleButtons/EditRuleButton

## UI 引用 - 规则编辑面板
@onready var rule_edit_panel: Control = $RuleEditPanel
@onready var rule_name_edit: LineEdit = $RuleEditPanel/VBox/RuleNameEdit
@onready var trigger_type_option: OptionButton = $RuleEditPanel/VBox/TriggerSection/TriggerTypeOption
@onready var trigger_once_check: CheckBox = $RuleEditPanel/VBox/TriggerSection/TriggerOnceCheck
@onready var trigger_params_container: VBoxContainer = $RuleEditPanel/VBox/TriggerSection/TriggerParams

## UI 引用 - 动作列表
@onready var actions_tree: Tree = $RuleEditPanel/VBox/ActionsSection/ActionsTree
@onready var add_action_button: Button = $RuleEditPanel/VBox/ActionsSection/ActionButtons/AddActionButton
@onready var delete_action_button: Button = $RuleEditPanel/VBox/ActionsSection/ActionButtons/DeleteActionButton
@onready var edit_action_button: Button = $RuleEditPanel/VBox/ActionsSection/ActionButtons/EditActionButton

## UI 引用 - 动作编辑面板
@onready var action_edit_panel: Control = $ActionEditPanel
@onready var action_type_option: OptionButton = $ActionEditPanel/VBox/ActionTypeOption
@onready var action_params_container: VBoxContainer = $ActionEditPanel/VBox/ActionParams

## UI 引用 - 按钮
@onready var save_button: Button = $MainPanel/VBox/ButtonContainer/SaveButton
@onready var cancel_button: Button = $MainPanel/VBox/ButtonContainer/CancelButton

## 当前编辑的规则和动作索引
var current_rule_index: int = -1
var current_action_index: int = -1

## 动态创建的参数控件
var trigger_param_controls: Dictionary = {}
var action_param_controls: Dictionary = {}

func _ready():
	_setup_ui()
	_connect_signals()
	rule_edit_panel.visible = false
	action_edit_panel.visible = false

## 设置 UI
func _setup_ui() -> void:
	# 载体类型选项
	carrier_type_option.clear()
	carrier_type_option.add_item("投射物", CarrierConfigData.CarrierType.PROJECTILE)
	carrier_type_option.add_item("地雷", CarrierConfigData.CarrierType.MINE)
	carrier_type_option.add_item("慢速球", CarrierConfigData.CarrierType.SLOW_ORB)
	
	# 相态选项
	phase_option.clear()
	phase_option.add_item("固态", CarrierConfigData.Phase.SOLID)
	phase_option.add_item("液态", CarrierConfigData.Phase.LIQUID)
	phase_option.add_item("等离子态", CarrierConfigData.Phase.PLASMA)
	
	# 触发器类型选项
	trigger_type_option.clear()
	trigger_type_option.add_item("碰撞触发", TriggerData.TriggerType.ON_CONTACT)
	trigger_type_option.add_item("定时触发", TriggerData.TriggerType.ON_TIMER)
	trigger_type_option.add_item("接近触发", TriggerData.TriggerType.ON_PROXIMITY)
	trigger_type_option.add_item("消亡触发", TriggerData.TriggerType.ON_DEATH)
	
	# 动作类型选项
	action_type_option.clear()
	action_type_option.add_item("伤害", ActionData.ActionType.DAMAGE)
	action_type_option.add_item("裂变", ActionData.ActionType.FISSION)
	action_type_option.add_item("范围效果", ActionData.ActionType.AREA_EFFECT)
	action_type_option.add_item("状态效果", ActionData.ActionType.APPLY_STATUS)
	action_type_option.add_item("生成爆炸", ActionData.ActionType.SPAWN_ENTITY)
	
	# 设置规则树
	rules_tree.columns = 1
	rules_tree.hide_root = true
	rules_tree.create_item()  # 创建根节点
	
	# 设置动作树
	actions_tree.columns = 1
	actions_tree.hide_root = true
	actions_tree.create_item()

## 连接信号
func _connect_signals() -> void:
	save_button.pressed.connect(_on_save_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	
	add_rule_button.pressed.connect(_on_add_rule_pressed)
	delete_rule_button.pressed.connect(_on_delete_rule_pressed)
	edit_rule_button.pressed.connect(_on_edit_rule_pressed)
	
	add_action_button.pressed.connect(_on_add_action_pressed)
	delete_action_button.pressed.connect(_on_delete_action_pressed)
	edit_action_button.pressed.connect(_on_edit_action_pressed)
	
	trigger_type_option.item_selected.connect(_on_trigger_type_changed)
	action_type_option.item_selected.connect(_on_action_type_changed)

## 打开编辑器编辑法术
func edit_spell(spell: SpellCoreData) -> void:
	if spell == null:
		current_spell = SpellCoreData.new()
		current_spell.generate_id()
		current_spell.carrier = CarrierConfigData.new()
	else:
		current_spell = spell.clone_deep()
	
	_load_spell_to_ui()
	visible = true

## 加载法术数据到 UI
func _load_spell_to_ui() -> void:
	spell_name_edit.text = current_spell.spell_name
	cost_spin.value = current_spell.resource_cost
	cooldown_spin.value = current_spell.cooldown
	
	if current_spell.carrier != null:
		carrier_type_option.selected = current_spell.carrier.carrier_type
		phase_option.selected = current_spell.carrier.phase
		velocity_spin.value = current_spell.carrier.velocity
		lifetime_spin.value = current_spell.carrier.lifetime
		mass_spin.value = current_spell.carrier.mass
		size_spin.value = current_spell.carrier.size
		piercing_spin.value = current_spell.carrier.piercing
		homing_spin.value = current_spell.carrier.homing_strength
	
	_refresh_rules_tree()

## 刷新规则树
func _refresh_rules_tree() -> void:
	rules_tree.clear()
	var root = rules_tree.create_item()
	
	for i in range(current_spell.topology_rules.size()):
		var rule = current_spell.topology_rules[i]
		var item = rules_tree.create_item(root)
		item.set_text(0, "%d. %s [%s]" % [i + 1, rule.rule_name, rule.trigger.get_type_name() if rule.trigger else "无触发器"])
		item.set_metadata(0, i)
		
		# 添加动作作为子节点
		for j in range(rule.actions.size()):
			var action = rule.actions[j]
			var action_item = rules_tree.create_item(item)
			action_item.set_text(0, "  → %s" % _get_action_description(action))
			action_item.set_metadata(0, {"rule_index": i, "action_index": j})

## 获取动作描述
func _get_action_description(action: ActionData) -> String:
	if action is DamageActionData:
		return "伤害: %.1f × %.1f" % [action.damage_value, action.damage_multiplier]
	elif action is FissionActionData:
		var child_name = action.child_spell_data.spell_name if action.child_spell_data else "无"
		return "裂变: %d个 [子法术: %s]" % [action.spawn_count, child_name]
	elif action is AreaEffectActionData:
		return "范围: 半径%.0f, 伤害%.1f" % [action.radius, action.damage_value]
	elif action is ApplyStatusActionData:
		return "状态: 类型%d, 持续%.1fs" % [action.status_type, action.duration]
	elif action is SpawnExplosionActionData:
		return "爆炸: 伤害%.1f, 半径%.0f" % [action.explosion_damage, action.explosion_radius]
	elif action is SpawnDamageZoneActionData:
		return "伤害区域: 伤害%.1f, 持续%.1fs" % [action.zone_damage, action.zone_duration]
	return action.get_type_name()

## 从 UI 保存数据到法术
func _save_ui_to_spell() -> void:
	current_spell.spell_name = spell_name_edit.text
	current_spell.resource_cost = cost_spin.value
	current_spell.cooldown = cooldown_spin.value
	
	if current_spell.carrier == null:
		current_spell.carrier = CarrierConfigData.new()
	
	current_spell.carrier.carrier_type = carrier_type_option.selected
	current_spell.carrier.phase = phase_option.selected
	current_spell.carrier.velocity = velocity_spin.value
	current_spell.carrier.lifetime = lifetime_spin.value
	current_spell.carrier.mass = mass_spin.value
	current_spell.carrier.size = size_spin.value
	current_spell.carrier.piercing = int(piercing_spin.value)
	current_spell.carrier.homing_strength = homing_spin.value

## 保存按钮
func _on_save_pressed() -> void:
	_save_ui_to_spell()
	spell_saved.emit(current_spell)
	visible = false

## 取消按钮
func _on_cancel_pressed() -> void:
	editor_closed.emit()
	visible = false

## 添加规则
func _on_add_rule_pressed() -> void:
	var rule = TopologyRuleData.new()
	rule.rule_name = "新规则_%d" % (current_spell.topology_rules.size() + 1)
	rule.trigger = TriggerData.new()
	rule.trigger.trigger_type = TriggerData.TriggerType.ON_CONTACT
	current_spell.topology_rules.append(rule)
	_refresh_rules_tree()

## 删除规则
func _on_delete_rule_pressed() -> void:
	var selected = rules_tree.get_selected()
	if selected == null:
		return
	
	var metadata = selected.get_metadata(0)
	if metadata is int:
		current_spell.topology_rules.remove_at(metadata)
		_refresh_rules_tree()

## 编辑规则
func _on_edit_rule_pressed() -> void:
	var selected = rules_tree.get_selected()
	if selected == null:
		return
	
	var metadata = selected.get_metadata(0)
	if metadata is int:
		current_rule_index = metadata
		_open_rule_editor(current_spell.topology_rules[current_rule_index])

## 打开规则编辑面板
func _open_rule_editor(rule: TopologyRuleData) -> void:
	rule_name_edit.text = rule.rule_name
	trigger_type_option.selected = rule.trigger.trigger_type if rule.trigger else 0
	trigger_once_check.button_pressed = rule.trigger.trigger_once if rule.trigger else true
	
	_update_trigger_params(rule.trigger)
	_refresh_actions_tree(rule)
	
	rule_edit_panel.visible = true

## 更新触发器参数控件
func _update_trigger_params(trigger: TriggerData) -> void:
	# 清除现有控件
	for child in trigger_params_container.get_children():
		child.queue_free()
	trigger_param_controls.clear()
	
	if trigger == null:
		return
	
	match trigger.trigger_type:
		TriggerData.TriggerType.ON_TIMER:
			if trigger is OnTimerTrigger:
				_add_param_spinbox("delay", "延迟(秒)", trigger.delay, 0.1, 10.0, 0.1)
				_add_param_spinbox("repeat_interval", "重复间隔", trigger.repeat_interval, 0.0, 10.0, 0.1)
		
		TriggerData.TriggerType.ON_PROXIMITY:
			if trigger is OnProximityTrigger:
				_add_param_spinbox("detection_radius", "检测半径", trigger.detection_radius, 10.0, 500.0, 10.0)

## 添加参数 SpinBox
func _add_param_spinbox(key: String, label_text: String, value: float, min_val: float, max_val: float, step: float) -> void:
	var hbox = HBoxContainer.new()
	var label = Label.new()
	label.text = label_text + ":"
	label.custom_minimum_size.x = 100
	var spin = SpinBox.new()
	spin.min_value = min_val
	spin.max_value = max_val
	spin.step = step
	spin.value = value
	spin.custom_minimum_size.x = 80
	
	hbox.add_child(label)
	hbox.add_child(spin)
	trigger_params_container.add_child(hbox)
	trigger_param_controls[key] = spin

## 刷新动作树
func _refresh_actions_tree(rule: TopologyRuleData) -> void:
	actions_tree.clear()
	var root = actions_tree.create_item()
	
	for i in range(rule.actions.size()):
		var action = rule.actions[i]
		var item = actions_tree.create_item(root)
		item.set_text(0, "%d. %s" % [i + 1, _get_action_description(action)])
		item.set_metadata(0, i)

## 触发器类型改变
func _on_trigger_type_changed(index: int) -> void:
	if current_rule_index < 0:
		return
	
	var rule = current_spell.topology_rules[current_rule_index]
	var trigger_type = trigger_type_option.get_item_id(index)
	
	match trigger_type:
		TriggerData.TriggerType.ON_TIMER:
			var timer_trigger = OnTimerTrigger.new()
			timer_trigger.delay = 1.0
			rule.trigger = timer_trigger
		TriggerData.TriggerType.ON_PROXIMITY:
			var prox_trigger = OnProximityTrigger.new()
			prox_trigger.detection_radius = 100.0
			rule.trigger = prox_trigger
		_:
			rule.trigger = TriggerData.new()
			rule.trigger.trigger_type = trigger_type
	
	rule.trigger.trigger_once = trigger_once_check.button_pressed
	_update_trigger_params(rule.trigger)

## 添加动作
func _on_add_action_pressed() -> void:
	if current_rule_index < 0:
		return
	
	var rule = current_spell.topology_rules[current_rule_index]
	var action = DamageActionData.new()
	action.damage_value = 10.0
	action.damage_multiplier = 1.0
	rule.actions.append(action)
	_refresh_actions_tree(rule)

## 删除动作
func _on_delete_action_pressed() -> void:
	if current_rule_index < 0:
		return
	
	var selected = actions_tree.get_selected()
	if selected == null:
		return
	
	var action_index = selected.get_metadata(0)
	if action_index is int:
		var rule = current_spell.topology_rules[current_rule_index]
		rule.actions.remove_at(action_index)
		_refresh_actions_tree(rule)

## 编辑动作
func _on_edit_action_pressed() -> void:
	if current_rule_index < 0:
		return
	
	var selected = actions_tree.get_selected()
	if selected == null:
		return
	
	var action_index = selected.get_metadata(0)
	if action_index is int:
		current_action_index = action_index
		var rule = current_spell.topology_rules[current_rule_index]
		_open_action_editor(rule.actions[current_action_index])

## 打开动作编辑面板
func _open_action_editor(action: ActionData) -> void:
	action_type_option.selected = action.action_type
	_update_action_params(action)
	action_edit_panel.visible = true

## 更新动作参数控件
func _update_action_params(action: ActionData) -> void:
	# 清除现有控件
	for child in action_params_container.get_children():
		child.queue_free()
	action_param_controls.clear()
	
	if action is DamageActionData:
		_add_action_param_spinbox("damage_value", "伤害值", action.damage_value, 1.0, 500.0, 1.0)
		_add_action_param_spinbox("damage_multiplier", "伤害倍率", action.damage_multiplier, 0.1, 5.0, 0.1)
	
	elif action is FissionActionData:
		_add_action_param_spinbox("spawn_count", "生成数量", action.spawn_count, 1, 20, 1)
		_add_action_param_spinbox("spread_angle", "散布角度", action.spread_angle, 0, 360, 10)
		_add_action_param_spinbox("inherit_velocity", "继承速度", action.inherit_velocity, 0, 1, 0.1)
		
		# 添加子法术编辑按钮
		var child_button = Button.new()
		child_button.text = "编辑子法术: %s" % (action.child_spell_data.spell_name if action.child_spell_data else "无")
		child_button.pressed.connect(_on_edit_child_spell_pressed.bind(action))
		action_params_container.add_child(child_button)
		action_param_controls["child_spell_button"] = child_button
	
	elif action is AreaEffectActionData:
		_add_action_param_spinbox("radius", "半径", action.radius, 10.0, 500.0, 10.0)
		_add_action_param_spinbox("damage_value", "伤害值", action.damage_value, 1.0, 200.0, 1.0)
		_add_action_param_spinbox("damage_falloff", "伤害衰减", action.damage_falloff, 0.0, 1.0, 0.1)
	
	elif action is ApplyStatusActionData:
		_add_action_param_spinbox("status_type", "状态类型", action.status_type, 0, 5, 1)
		_add_action_param_spinbox("duration", "持续时间", action.duration, 0.5, 30.0, 0.5)
		_add_action_param_spinbox("effect_value", "效果值", action.effect_value, 1.0, 100.0, 1.0)
	
	elif action is SpawnExplosionActionData:
		_add_action_param_spinbox("explosion_damage", "爆炸伤害", action.explosion_damage, 1.0, 500.0, 1.0)
		_add_action_param_spinbox("explosion_radius", "爆炸半径", action.explosion_radius, 10.0, 500.0, 10.0)
		_add_action_param_spinbox("damage_falloff", "伤害衰减", action.damage_falloff, 0.0, 1.0, 0.1)
	
	elif action is SpawnDamageZoneActionData:
		_add_action_param_spinbox("zone_damage", "区域伤害", action.zone_damage, 1.0, 100.0, 1.0)
		_add_action_param_spinbox("zone_radius", "区域半径", action.zone_radius, 10.0, 300.0, 10.0)
		_add_action_param_spinbox("zone_duration", "持续时间", action.zone_duration, 1.0, 30.0, 1.0)
		_add_action_param_spinbox("tick_interval", "伤害间隔", action.tick_interval, 0.1, 2.0, 0.1)

## 添加动作参数 SpinBox
func _add_action_param_spinbox(key: String, label_text: String, value: float, min_val: float, max_val: float, step: float) -> void:
	var hbox = HBoxContainer.new()
	var label = Label.new()
	label.text = label_text + ":"
	label.custom_minimum_size.x = 100
	var spin = SpinBox.new()
	spin.min_value = min_val
	spin.max_value = max_val
	spin.step = step
	spin.value = value
	spin.custom_minimum_size.x = 80
	
	hbox.add_child(label)
	hbox.add_child(spin)
	action_params_container.add_child(hbox)
	action_param_controls[key] = spin

## 编辑子法术（嵌套编辑）
func _on_edit_child_spell_pressed(fission_action: FissionActionData) -> void:
	# 创建子法术编辑器
	if child_editor != null:
		child_editor.queue_free()
	
	child_editor = duplicate()
	child_editor.is_editing_child_spell = true
	child_editor.parent_editor = self
	
	# 如果没有子法术，创建一个默认的
	if fission_action.child_spell_data == null:
		fission_action.child_spell_data = SpellCoreData.new()
		fission_action.child_spell_data.generate_id()
		fission_action.child_spell_data.spell_name = "子法术"
		fission_action.child_spell_data.carrier = CarrierConfigData.new()
	
	child_editor.spell_saved.connect(_on_child_spell_saved.bind(fission_action))
	child_editor.editor_closed.connect(_on_child_editor_closed)
	
	get_parent().add_child(child_editor)
	child_editor.edit_spell(fission_action.child_spell_data)
	
	# 隐藏当前编辑器
	visible = false

## 子法术保存回调
func _on_child_spell_saved(spell: SpellCoreData, fission_action: FissionActionData) -> void:
	fission_action.child_spell_data = spell
	
	# 更新按钮文本
	if action_param_controls.has("child_spell_button"):
		action_param_controls["child_spell_button"].text = "编辑子法术: %s" % spell.spell_name
	
	# 显示父编辑器
	visible = true
	
	# 清理子编辑器
	if child_editor != null:
		child_editor.queue_free()
		child_editor = null

## 子编辑器关闭回调
func _on_child_editor_closed() -> void:
	visible = true
	if child_editor != null:
		child_editor.queue_free()
		child_editor = null

## 动作类型改变
func _on_action_type_changed(index: int) -> void:
	if current_rule_index < 0 or current_action_index < 0:
		return
	
	var rule = current_spell.topology_rules[current_rule_index]
	var action_type = action_type_option.get_item_id(index)
	var new_action: ActionData
	
	match action_type:
		ActionData.ActionType.DAMAGE:
			var damage = DamageActionData.new()
			damage.damage_value = 10.0
			damage.damage_multiplier = 1.0
			new_action = damage
		
		ActionData.ActionType.FISSION:
			var fission = FissionActionData.new()
			fission.spawn_count = 3
			fission.spread_angle = 60.0
			fission.inherit_velocity = 0.8
			new_action = fission
		
		ActionData.ActionType.AREA_EFFECT:
			var area = AreaEffectActionData.new()
			area.radius = 80.0
			area.damage_value = 20.0
			new_action = area
		
		ActionData.ActionType.APPLY_STATUS:
			var status = ApplyStatusActionData.new()
			status.status_type = 0
			status.duration = 3.0
			status.effect_value = 5.0
			new_action = status
		
		ActionData.ActionType.SPAWN_ENTITY:
			var explosion = SpawnExplosionActionData.new()
			explosion.explosion_damage = 30.0
			explosion.explosion_radius = 100.0
			new_action = explosion
		
		_:
			new_action = ActionData.new()
			new_action.action_type = action_type
	
	rule.actions[current_action_index] = new_action
	_update_action_params(new_action)
	_refresh_actions_tree(rule)

## 保存规则编辑
func save_rule_edit() -> void:
	if current_rule_index < 0:
		return
	
	var rule = current_spell.topology_rules[current_rule_index]
	rule.rule_name = rule_name_edit.text
	
	if rule.trigger != null:
		rule.trigger.trigger_once = trigger_once_check.button_pressed
		
		# 保存触发器参数
		if rule.trigger is OnTimerTrigger:
			if trigger_param_controls.has("delay"):
				rule.trigger.delay = trigger_param_controls["delay"].value
			if trigger_param_controls.has("repeat_interval"):
				rule.trigger.repeat_interval = trigger_param_controls["repeat_interval"].value
		
		elif rule.trigger is OnProximityTrigger:
			if trigger_param_controls.has("detection_radius"):
				rule.trigger.detection_radius = trigger_param_controls["detection_radius"].value
	
	_refresh_rules_tree()
	rule_edit_panel.visible = false
	current_rule_index = -1

## 保存动作编辑
func save_action_edit() -> void:
	if current_rule_index < 0 or current_action_index < 0:
		return
	
	var rule = current_spell.topology_rules[current_rule_index]
	var action = rule.actions[current_action_index]
	
	# 保存动作参数
	if action is DamageActionData:
		if action_param_controls.has("damage_value"):
			action.damage_value = action_param_controls["damage_value"].value
		if action_param_controls.has("damage_multiplier"):
			action.damage_multiplier = action_param_controls["damage_multiplier"].value
	
	elif action is FissionActionData:
		if action_param_controls.has("spawn_count"):
			action.spawn_count = int(action_param_controls["spawn_count"].value)
		if action_param_controls.has("spread_angle"):
			action.spread_angle = action_param_controls["spread_angle"].value
		if action_param_controls.has("inherit_velocity"):
			action.inherit_velocity = action_param_controls["inherit_velocity"].value
	
	elif action is AreaEffectActionData:
		if action_param_controls.has("radius"):
			action.radius = action_param_controls["radius"].value
		if action_param_controls.has("damage_value"):
			action.damage_value = action_param_controls["damage_value"].value
		if action_param_controls.has("damage_falloff"):
			action.damage_falloff = action_param_controls["damage_falloff"].value
	
	elif action is ApplyStatusActionData:
		if action_param_controls.has("status_type"):
			action.status_type = int(action_param_controls["status_type"].value)
		if action_param_controls.has("duration"):
			action.duration = action_param_controls["duration"].value
		if action_param_controls.has("effect_value"):
			action.effect_value = action_param_controls["effect_value"].value
	
	elif action is SpawnExplosionActionData:
		if action_param_controls.has("explosion_damage"):
			action.explosion_damage = action_param_controls["explosion_damage"].value
		if action_param_controls.has("explosion_radius"):
			action.explosion_radius = action_param_controls["explosion_radius"].value
		if action_param_controls.has("damage_falloff"):
			action.damage_falloff = action_param_controls["damage_falloff"].value
	
	elif action is SpawnDamageZoneActionData:
		if action_param_controls.has("zone_damage"):
			action.zone_damage = action_param_controls["zone_damage"].value
		if action_param_controls.has("zone_radius"):
			action.zone_radius = action_param_controls["zone_radius"].value
		if action_param_controls.has("zone_duration"):
			action.zone_duration = action_param_controls["zone_duration"].value
		if action_param_controls.has("tick_interval"):
			action.tick_interval = action_param_controls["tick_interval"].value
	
	_refresh_actions_tree(rule)
	action_edit_panel.visible = false
	current_action_index = -1

## 关闭规则编辑面板
func close_rule_edit() -> void:
	rule_edit_panel.visible = false
	current_rule_index = -1

## 关闭动作编辑面板
func close_action_edit() -> void:
	action_edit_panel.visible = false
	current_action_index = -1
