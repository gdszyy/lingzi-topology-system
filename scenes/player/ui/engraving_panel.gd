# engraving_panel.gd
# 刻录UI面板 - 管理法术刻录的用户界面（支持熟练度和前摇显示）
extends Control
class_name EngravingPanel

## 信号
signal spell_engraved(target_type: String, target_index: int, slot_index: int, spell: SpellCoreData)
signal spell_removed(target_type: String, target_index: int, slot_index: int)
signal panel_closed

## 节点引用
@onready var body_parts_container: VBoxContainer = $MainContainer/LeftPanel/BodyPartsContainer
@onready var weapon_slots_container: VBoxContainer = $MainContainer/LeftPanel/WeaponSlotsContainer
@onready var spell_library_list: ItemList = $MainContainer/RightPanel/SpellLibraryList
@onready var spell_info_label: RichTextLabel = $MainContainer/RightPanel/SpellInfoLabel
@onready var close_button: Button = $MainContainer/TopBar/CloseButton
@onready var clear_all_button: Button = $MainContainer/TopBar/ClearAllButton

## 玩家引用
var player: PlayerController = null

## 可用法术库
var spell_library: Array[SpellCoreData] = []

## 当前选中的法术
var selected_spell: SpellCoreData = null
var selected_spell_index: int = -1

## 当前选中的槽位
var selected_slot: EngravingSlot = null
var selected_slot_button: Button = null

## 槽位按钮映射
var slot_buttons: Dictionary = {}

## 槽位进度条映射
var slot_progress_bars: Dictionary = {}

func _ready() -> void:
	# 连接按钮信号
	close_button.pressed.connect(_on_close_pressed)
	clear_all_button.pressed.connect(_on_clear_all_pressed)
	spell_library_list.item_selected.connect(_on_spell_selected)

func _process(delta: float) -> void:
	# 更新槽位进度条
	_update_slot_progress_bars()

## 初始化面板
func initialize(_player: PlayerController, _spell_library: Array[SpellCoreData]) -> void:
	player = _player
	spell_library = _spell_library
	
	# 刷新UI
	refresh_ui()

## 刷新整个UI
func refresh_ui() -> void:
	_refresh_body_parts()
	_refresh_weapon_slots()
	_refresh_spell_library()
	_update_spell_info()

## 刷新肢体部件显示
func _refresh_body_parts() -> void:
	# 清空现有内容
	for child in body_parts_container.get_children():
		child.queue_free()
	
	slot_buttons.clear()
	slot_progress_bars.clear()
	
	if player == null or player.engraving_manager == null:
		return
	
	var body_parts = player.get_body_parts()
	
	for part in body_parts:
		# 创建部件容器
		var part_container = VBoxContainer.new()
		part_container.name = "Part_%s" % part.part_id
		
		# 部件标题
		var title_label = Label.new()
		title_label.text = part.part_name
		title_label.add_theme_font_size_override("font_size", 14)
		part_container.add_child(title_label)
		
		# 刻录槽
		var slots_container = HBoxContainer.new()
		for i in range(part.engraving_slots.size()):
			var slot = part.engraving_slots[i]
			var slot_widget = _create_slot_widget(slot, "body", part.part_type, i)
			slots_container.add_child(slot_widget)
		
		part_container.add_child(slots_container)
		
		# 添加分隔
		var separator = HSeparator.new()
		part_container.add_child(separator)
		
		body_parts_container.add_child(part_container)

## 刷新武器槽位显示
func _refresh_weapon_slots() -> void:
	# 清空现有内容
	for child in weapon_slots_container.get_children():
		child.queue_free()
	
	if player == null or player.current_weapon == null:
		var no_weapon_label = Label.new()
		no_weapon_label.text = "未装备武器"
		weapon_slots_container.add_child(no_weapon_label)
		return
	
	var weapon = player.current_weapon
	
	# 武器标题
	var title_label = Label.new()
	title_label.text = "武器: %s" % weapon.weapon_name
	title_label.add_theme_font_size_override("font_size", 14)
	weapon_slots_container.add_child(title_label)
	
	# 武器刻录槽
	var slots_container = HBoxContainer.new()
	for i in range(weapon.engraving_slots.size()):
		var slot = weapon.engraving_slots[i]
		var slot_widget = _create_slot_widget(slot, "weapon", 0, i)
		slots_container.add_child(slot_widget)
	
	weapon_slots_container.add_child(slots_container)

## 创建槽位组件（包含按钮和进度条）
func _create_slot_widget(slot: EngravingSlot, target_type: String, target_index: int, slot_index: int) -> Control:
	var container = VBoxContainer.new()
	container.custom_minimum_size = Vector2(90, 80)
	
	# 创建按钮
	var button = Button.new()
	button.custom_minimum_size = Vector2(85, 50)
	
	# 设置按钮文本
	if slot.engraved_spell != null:
		var spell = slot.engraved_spell
		button.text = spell.spell_name
		button.modulate = Color(0.8, 1.0, 0.8)  # 绿色调表示已刻录
	else:
		button.text = "空槽位"
		button.modulate = Color(0.7, 0.7, 0.7)  # 灰色表示空
	
	if slot.is_locked:
		button.disabled = true
		button.modulate = Color(0.5, 0.5, 0.5)
	
	# 设置提示（包含熟练度和前摇信息）
	button.tooltip_text = _get_slot_tooltip(slot)
	
	# 连接信号
	button.pressed.connect(_on_slot_button_pressed.bind(slot, button, target_type, target_index, slot_index))
	
	container.add_child(button)
	
	# 记录按钮映射
	slot_buttons[slot.slot_id] = button
	
	# 创建进度条（显示冷却/前摇）
	var progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(85, 8)
	progress_bar.min_value = 0
	progress_bar.max_value = 1
	progress_bar.value = 1
	progress_bar.show_percentage = false
	container.add_child(progress_bar)
	
	# 记录进度条映射
	slot_progress_bars[slot.slot_id] = progress_bar
	
	# 熟练度标签
	if slot.engraved_spell != null:
		var prof_label = Label.new()
		prof_label.add_theme_font_size_override("font_size", 10)
		var proficiency = _get_spell_proficiency(slot.engraved_spell.spell_id)
		prof_label.text = "熟练度: %.0f%%" % (proficiency * 100)
		prof_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		container.add_child(prof_label)
	
	return container

## 获取槽位提示文本
func _get_slot_tooltip(slot: EngravingSlot) -> String:
	var tooltip = slot.slot_name + "\n"
	tooltip += "容量: %.0f\n" % slot.slot_capacity
	
	if slot.engraved_spell != null:
		var spell = slot.engraved_spell
		var proficiency = _get_spell_proficiency(spell.spell_id)
		
		tooltip += "\n[已刻录] %s\n" % spell.spell_name
		tooltip += "类型: %s\n" % spell.get_type_name()
		tooltip += "消耗: %.0f\n" % spell.resource_cost
		tooltip += "\n--- 前摇信息 ---\n"
		tooltip += "普通前摇: %.2fs\n" % spell.calculate_windup_time(proficiency, false)
		tooltip += "刻录前摇: %.2fs\n" % spell.calculate_windup_time(proficiency, true)
		tooltip += "熟练度: %.0f%% (减少%.0f%%前摇)\n" % [proficiency * 100, proficiency * 50]
		
		if slot.cooldown > 0:
			tooltip += "冷却时间: %.1fs\n" % slot.cooldown
	
	return tooltip

## 获取法术熟练度
func _get_spell_proficiency(spell_id: String) -> float:
	if player == null or player.engraving_manager == null:
		return 0.0
	return player.engraving_manager.get_spell_proficiency(spell_id)

## 更新槽位进度条
func _update_slot_progress_bars() -> void:
	if player == null or player.engraving_manager == null:
		return
	
	for slot in player.engraving_manager.all_slots:
		if not slot_progress_bars.has(slot.slot_id):
			continue
		
		var progress_bar = slot_progress_bars[slot.slot_id] as ProgressBar
		
		if slot.is_winding_up:
			# 显示前摇进度
			progress_bar.value = slot.get_windup_progress()
			progress_bar.modulate = Color(1.0, 0.8, 0.2)  # 黄色表示蓄能中
		elif slot.cooldown_timer > 0:
			# 显示冷却进度
			progress_bar.value = 1.0 - (slot.cooldown_timer / slot.cooldown) if slot.cooldown > 0 else 1.0
			progress_bar.modulate = Color(0.5, 0.5, 1.0)  # 蓝色表示冷却中
		else:
			# 就绪状态
			progress_bar.value = 1.0
			progress_bar.modulate = Color(0.5, 1.0, 0.5)  # 绿色表示就绪

## 刷新法术库显示
func _refresh_spell_library() -> void:
	spell_library_list.clear()
	
	for i in range(spell_library.size()):
		var spell = spell_library[i]
		var type_icon = _get_spell_type_icon(spell)
		var proficiency = _get_spell_proficiency(spell.spell_id)
		var text = "%s %s (%.0f%%)" % [type_icon, spell.spell_name, proficiency * 100]
		spell_library_list.add_item(text)

## 获取法术类型图标
func _get_spell_type_icon(spell: SpellCoreData) -> String:
	match spell.spell_type:
		SpellCoreData.SpellType.PROJECTILE:
			return "🎯"
		SpellCoreData.SpellType.ENGRAVING:
			return "🔮"
		SpellCoreData.SpellType.HYBRID:
			return "⚡"
	return "❓"

## 更新法术信息显示
func _update_spell_info() -> void:
	if selected_spell == null:
		spell_info_label.text = "[center]选择一个法术查看详情[/center]"
		return
	
	var proficiency = _get_spell_proficiency(selected_spell.spell_id)
	var prof_data = null
	if player != null and player.engraving_manager != null:
		prof_data = player.engraving_manager.get_spell_proficiency_data(selected_spell.spell_id)
	
	var info = "[b]%s[/b] %s\n\n" % [selected_spell.spell_name, _get_spell_type_icon(selected_spell)]
	info += "[color=gray]%s[/color]\n\n" % selected_spell.description
	
	# 基本信息
	info += "[b]基本属性[/b]\n"
	info += "类型: %s\n" % selected_spell.get_type_name()
	info += "复杂度: %.1f\n" % selected_spell.calculate_total_instability()
	info += "消耗: %.0f\n" % selected_spell.resource_cost
	info += "冷却: %.1fs\n\n" % selected_spell.cooldown
	
	# 前摇信息
	info += "[b]前摇/蓄能[/b]\n"
	var normal_windup = selected_spell.calculate_windup_time(proficiency, false)
	var engraved_windup = selected_spell.calculate_windup_time(proficiency, true)
	info += "普通施放: [color=yellow]%.2fs[/color]\n" % normal_windup
	info += "刻录触发: [color=green]%.2fs[/color]\n" % engraved_windup
	if normal_windup > 0:
		var reduction = (1.0 - engraved_windup / normal_windup) * 100
		info += "刻录减少: [color=cyan]%.0f%%[/color]\n\n" % reduction
	
	# 熟练度信息
	info += "[b]熟练度[/b]\n"
	if prof_data != null:
		info += "等级: %s (%.0f%%)\n" % [prof_data.get_level_name(), proficiency * 100]
		info += "使用次数: %d\n" % prof_data.use_count
		info += "命中次数: %d\n" % prof_data.hit_count
		info += "击杀次数: %d\n" % prof_data.kill_count
		info += "前摇减少: %.0f%%\n\n" % (proficiency * 50)
	else:
		info += "等级: 新手 (0%%)\n"
		info += "前摇减少: 0%%\n\n"
	
	# 显示拓扑规则
	info += "[b]拓扑规则[/b]\n"
	for rule in selected_spell.topology_rules:
		info += "- %s\n" % rule.get_description()
	
	spell_info_label.text = info

## 槽位按钮点击回调
func _on_slot_button_pressed(slot: EngravingSlot, button: Button, target_type: String, target_index: int, slot_index: int) -> void:
	# 取消之前选中的按钮
	if selected_slot_button != null:
		selected_slot_button.modulate = _get_slot_color(selected_slot)
	
	# 如果点击的是已选中的槽位，尝试刻录或移除
	if selected_slot == slot:
		if selected_spell != null and slot.engraved_spell == null:
			# 刻录法术
			_engrave_spell(target_type, target_index, slot_index, selected_spell)
		elif slot.engraved_spell != null:
			# 移除法术
			_remove_spell(target_type, target_index, slot_index)
		
		selected_slot = null
		selected_slot_button = null
		return
	
	# 选中新槽位
	selected_slot = slot
	selected_slot_button = button
	button.modulate = Color(1.0, 1.0, 0.5)  # 黄色高亮

## 法术选择回调
func _on_spell_selected(index: int) -> void:
	if index < 0 or index >= spell_library.size():
		selected_spell = null
		selected_spell_index = -1
	else:
		selected_spell = spell_library[index]
		selected_spell_index = index
	
	_update_spell_info()
	
	# 如果有选中的槽位，尝试刻录
	if selected_slot != null and selected_spell != null and selected_slot.engraved_spell == null:
		# 需要知道槽位的target信息，这里简化处理
		pass

## 刻录法术
func _engrave_spell(target_type: String, target_index: int, slot_index: int, spell: SpellCoreData) -> void:
	var success = false
	
	if target_type == "body":
		success = player.engrave_to_body(target_index, slot_index, spell)
	elif target_type == "weapon":
		success = player.engrave_to_weapon(slot_index, spell)
	
	if success:
		spell_engraved.emit(target_type, target_index, slot_index, spell)
		refresh_ui()
	else:
		print("刻录失败")

## 移除法术
func _remove_spell(target_type: String, target_index: int, slot_index: int) -> void:
	var removed: SpellCoreData = null
	
	if target_type == "body":
		removed = player.engraving_manager.remove_from_body_part(target_index, slot_index)
	elif target_type == "weapon":
		removed = player.engraving_manager.remove_from_weapon(slot_index)
	
	if removed != null:
		spell_removed.emit(target_type, target_index, slot_index)
		refresh_ui()

## 获取槽位颜色
func _get_slot_color(slot: EngravingSlot) -> Color:
	if slot == null:
		return Color(0.7, 0.7, 0.7)
	if slot.is_locked:
		return Color(0.5, 0.5, 0.5)
	elif slot.engraved_spell != null:
		return Color(0.8, 1.0, 0.8)
	else:
		return Color(0.7, 0.7, 0.7)

## 关闭按钮回调
func _on_close_pressed() -> void:
	hide()
	panel_closed.emit()

## 清除所有刻录
func _on_clear_all_pressed() -> void:
	if player == null or player.engraving_manager == null:
		return
	
	# 清除肢体刻录
	for part in player.get_body_parts():
		for i in range(part.engraving_slots.size()):
			part.engraving_slots[i].remove_spell()
	
	# 清除武器刻录
	if player.current_weapon != null:
		for i in range(player.current_weapon.engraving_slots.size()):
			player.current_weapon.remove_spell_from_slot(i)
	
	refresh_ui()

## 显示面板
func show_panel() -> void:
	refresh_ui()
	show()

## 隐藏面板
func hide_panel() -> void:
	hide()
