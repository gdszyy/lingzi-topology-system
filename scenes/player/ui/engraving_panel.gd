extends Control
class_name EngravingPanel

signal spell_engraved(target_type: String, target_index: int, slot_index: int, spell: SpellCoreData)
signal spell_removed(target_type: String, target_index: int, slot_index: int)
signal panel_closed

@onready var body_parts_container: VBoxContainer = $MainContainer/LeftPanel/BodyPartsContainer
@onready var weapon_slots_container: VBoxContainer = $MainContainer/LeftPanel/WeaponSlotsContainer
@onready var spell_library_list: ItemList = $MainContainer/RightPanel/SpellLibraryList
@onready var spell_info_label: RichTextLabel = $MainContainer/RightPanel/SpellInfoLabel
@onready var close_button: Button = $MainContainer/TopBar/CloseButton
@onready var clear_all_button: Button = $MainContainer/TopBar/ClearAllButton

var player: PlayerController = null

var spell_library: Array[SpellCoreData] = []

var selected_spell: SpellCoreData = null
var selected_spell_index: int = -1

var selected_slot: EngravingSlot = null
var selected_slot_button: Button = null

var slot_buttons: Dictionary = {}

var slot_progress_bars: Dictionary = {}

func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	clear_all_button.pressed.connect(_on_clear_all_pressed)
	spell_library_list.item_selected.connect(_on_spell_selected)

func _process(_delta: float) -> void:
	_update_slot_progress_bars()

func initialize(_player: PlayerController, _spell_library: Array[SpellCoreData]) -> void:
	player = _player
	spell_library = _spell_library

	refresh_ui()

func refresh_ui() -> void:
	_refresh_body_parts()
	_refresh_weapon_slots()
	_refresh_spell_library()
	_update_spell_info()

func _refresh_body_parts() -> void:
	for child in body_parts_container.get_children():
		child.queue_free()

	slot_buttons.clear()
	slot_progress_bars.clear()

	if player == null or player.engraving_manager == null:
		return

	var body_parts = player.get_body_parts()

	for part in body_parts:
		var part_container = VBoxContainer.new()
		part_container.name = "Part_%s" % part.part_id

		var title_label = Label.new()
		title_label.text = part.part_name
		title_label.add_theme_font_size_override("font_size", 14)
		part_container.add_child(title_label)

		var slots_container = HBoxContainer.new()
		for i in range(part.engraving_slots.size()):
			var slot = part.engraving_slots[i]
			var slot_widget = _create_slot_widget(slot, "body", part.part_type, i)
			slots_container.add_child(slot_widget)

		part_container.add_child(slots_container)

		var separator = HSeparator.new()
		part_container.add_child(separator)

		body_parts_container.add_child(part_container)

func _refresh_weapon_slots() -> void:
	for child in weapon_slots_container.get_children():
		child.queue_free()

	if player == null or player.current_weapon == null:
		var no_weapon_label = Label.new()
		no_weapon_label.text = "未装备武器"
		weapon_slots_container.add_child(no_weapon_label)
		return

	var weapon = player.current_weapon

	var title_label = Label.new()
	title_label.text = "武器: %s" % weapon.weapon_name
	title_label.add_theme_font_size_override("font_size", 14)
	weapon_slots_container.add_child(title_label)

	var slots_container = HBoxContainer.new()
	for i in range(weapon.engraving_slots.size()):
		var slot = weapon.engraving_slots[i]
		var slot_widget = _create_slot_widget(slot, "weapon", 0, i)
		slots_container.add_child(slot_widget)

	weapon_slots_container.add_child(slots_container)

func _create_slot_widget(slot: EngravingSlot, target_type: String, target_index: int, slot_index: int) -> Control:
	var container = VBoxContainer.new()
	container.custom_minimum_size = Vector2(90, 80)

	var button = Button.new()
	button.custom_minimum_size = Vector2(85, 50)

	if slot.engraved_spell != null:
		var spell = slot.engraved_spell
		button.text = spell.spell_name
		button.modulate = Color(0.8, 1.0, 0.8)
	else:
		button.text = "空槽位"
		button.modulate = Color(0.7, 0.7, 0.7)

	if slot.is_locked:
		button.disabled = true
		button.modulate = Color(0.5, 0.5, 0.5)

	button.tooltip_text = _get_slot_tooltip(slot)

	button.pressed.connect(_on_slot_button_pressed.bind(slot, button, target_type, target_index, slot_index))

	container.add_child(button)

	slot_buttons[slot.slot_id] = button

	var progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(85, 8)
	progress_bar.min_value = 0
	progress_bar.max_value = 1
	progress_bar.value = 1
	progress_bar.show_percentage = false
	container.add_child(progress_bar)

	slot_progress_bars[slot.slot_id] = progress_bar

	if slot.engraved_spell != null:
		var prof_label = Label.new()
		prof_label.add_theme_font_size_override("font_size", 10)
		var proficiency = _get_spell_proficiency(slot.engraved_spell.spell_id)
		prof_label.text = "熟练度: %.0f%%" % (proficiency * 100)
		prof_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		container.add_child(prof_label)

	return container

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

func _get_spell_proficiency(spell_id: String) -> float:
	if player == null or player.engraving_manager == null:
		return 0.0
	return player.engraving_manager.get_spell_proficiency(spell_id)

func _update_slot_progress_bars() -> void:
	if player == null or player.engraving_manager == null:
		return

	for slot in player.engraving_manager.all_slots:
		if not slot_progress_bars.has(slot.slot_id):
			continue

		var progress_bar = slot_progress_bars[slot.slot_id] as ProgressBar

		if slot.is_winding_up:
			progress_bar.value = slot.get_windup_progress()
			progress_bar.modulate = Color(1.0, 0.8, 0.2)
		elif slot.cooldown_timer > 0:
			progress_bar.value = 1.0 - (slot.cooldown_timer / slot.cooldown) if slot.cooldown > 0 else 1.0
			progress_bar.modulate = Color(0.5, 0.5, 1.0)
		else:
			progress_bar.value = 1.0
			progress_bar.modulate = Color(0.5, 1.0, 0.5)

func _refresh_spell_library() -> void:
	spell_library_list.clear()

	for i in range(spell_library.size()):
		var spell = spell_library[i]
		var type_icon = _get_spell_type_icon(spell)
		var proficiency = _get_spell_proficiency(spell.spell_id)
		var text = "%s %s (%.0f%%)" % [type_icon, spell.spell_name, proficiency * 100]
		spell_library_list.add_item(text)

func _get_spell_type_icon(spell: SpellCoreData) -> String:
	match spell.spell_type:
		SpellCoreData.SpellType.PROJECTILE:
			return "🎯"
		SpellCoreData.SpellType.ENGRAVING:
			return "🔮"
		SpellCoreData.SpellType.HYBRID:
			return "⚡"
	return "❓"

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

	info += "[b]基本属性[/b]\n"
	info += "类型: %s\n" % selected_spell.get_type_name()
	info += "复杂度: %.1f\n" % selected_spell.calculate_total_instability()
	info += "消耗: %.0f\n" % selected_spell.resource_cost
	info += "冷却: %.1fs\n\n" % selected_spell.cooldown

	info += "[b]前摇/蓄能[/b]\n"
	var normal_windup = selected_spell.calculate_windup_time(proficiency, false)
	var engraved_windup = selected_spell.calculate_windup_time(proficiency, true)
	info += "普通施放: [color=yellow]%.2fs[/color]\n" % normal_windup
	info += "刻录触发: [color=green]%.2fs[/color]\n" % engraved_windup
	if normal_windup > 0:
		var reduction = (1.0 - engraved_windup / normal_windup) * 100
		info += "刻录减少: [color=cyan]%.0f%%[/color]\n\n" % reduction

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

	info += "[b]拓扑规则[/b]\n"
	for rule in selected_spell.topology_rules:
		info += "- %s\n" % rule.get_description()

	spell_info_label.text = info

func _on_slot_button_pressed(slot: EngravingSlot, button: Button, target_type: String, target_index: int, slot_index: int) -> void:
	if selected_slot_button != null:
		selected_slot_button.modulate = _get_slot_color(selected_slot)

	if selected_slot == slot:
		if selected_spell != null and slot.engraved_spell == null:
			_engrave_spell(target_type, target_index, slot_index, selected_spell)
		elif slot.engraved_spell != null:
			_remove_spell(target_type, target_index, slot_index)

		selected_slot = null
		selected_slot_button = null
		return

	selected_slot = slot
	selected_slot_button = button
	button.modulate = Color(1.0, 1.0, 0.5)

func _on_spell_selected(index: int) -> void:
	if index < 0 or index >= spell_library.size():
		selected_spell = null
		selected_spell_index = -1
	else:
		selected_spell = spell_library[index]
		selected_spell_index = index

	_update_spell_info()

	if selected_slot != null and selected_spell != null and selected_slot.engraved_spell == null:
		pass

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

func _remove_spell(target_type: String, target_index: int, slot_index: int) -> void:
	var removed: SpellCoreData = null

	if target_type == "body":
		removed = player.engraving_manager.remove_from_body_part(target_index, slot_index)
	elif target_type == "weapon":
		removed = player.engraving_manager.remove_from_weapon(slot_index)

	if removed != null:
		spell_removed.emit(target_type, target_index, slot_index)
		refresh_ui()

func _get_slot_color(slot: EngravingSlot) -> Color:
	if slot == null:
		return Color(0.7, 0.7, 0.7)
	if slot.is_locked:
		return Color(0.5, 0.5, 0.5)
	elif slot.engraved_spell != null:
		return Color(0.8, 1.0, 0.8)
	else:
		return Color(0.7, 0.7, 0.7)

func _on_close_pressed() -> void:
	hide()
	panel_closed.emit()

func _on_clear_all_pressed() -> void:
	if player == null or player.engraving_manager == null:
		return

	for part in player.get_body_parts():
		for i in range(part.engraving_slots.size()):
			part.engraving_slots[i].remove_spell()

	if player.current_weapon != null:
		for i in range(player.current_weapon.engraving_slots.size()):
			player.current_weapon.remove_spell_from_slot(i)

	refresh_ui()

func show_panel() -> void:
	refresh_ui()
	show()

func hide_panel() -> void:
	hide()
