# engraving_manager.gd
# 刻录管理器 - 管理角色和武器上的法术刻录，处理触发逻辑（支持前摇和熟练度）
class_name EngravingManager extends Node

## 信号
signal engraving_triggered(trigger_type: int, spell: SpellCoreData, source: String)
signal engraving_windup_started(slot: EngravingSlot, windup_time: float)
signal engraving_windup_completed(slot: EngravingSlot)
signal action_executed(action: ActionData, context: Dictionary)
signal engraving_effect_applied(effect_type: String, target: Node2D, value: float)
signal proficiency_updated(spell_id: String, proficiency: float)

## 玩家控制器引用
var player: PlayerController = null

## 肢体部件列表
var body_parts: Array[BodyPartData] = []

## 所有已注册的刻录槽（来自肢体和武器）
var all_slots: Array[EngravingSlot] = []

## 效果执行器
var action_executor: ActionExecutor = null

## 熟练度管理器
var proficiency_manager: ProficiencyManager = null

## 触发上下文
var current_context: Dictionary = {}

## 触发统计
var trigger_stats: Dictionary = {}

## 刻录触发统计（用于UI显示）
var engraving_trigger_count: int = 0

## 是否启用刻录系统
var is_enabled: bool = true

func _ready() -> void:
	# 创建效果执行器
	action_executor = ActionExecutor.new()
	action_executor.name = "ActionExecutor"
	add_child(action_executor)
	
	# 创建熟练度管理器
	proficiency_manager = ProficiencyManager.new()
	proficiency_manager.name = "ProficiencyManager"
	add_child(proficiency_manager)
	
	# 连接熟练度信号
	proficiency_manager.proficiency_changed.connect(_on_proficiency_changed)
	proficiency_manager.level_up.connect(_on_proficiency_level_up)

func _process(delta: float) -> void:
	_update_slots(delta)
	_process_periodic_triggers(delta)

## 初始化刻录管理器
func initialize(_player: PlayerController) -> void:
	player = _player
	
	# 创建默认肢体部件
	body_parts = BodyPartData.create_default_body_parts()
	
	# 注册所有刻录槽
	_register_all_slots()
	
	# 连接玩家信号
	_connect_player_signals()
	
	# 初始化效果执行器
	action_executor.initialize(player)

## 注册所有刻录槽
func _register_all_slots() -> void:
	all_slots.clear()
	
	# 注册肢体部件的槽位
	for part in body_parts:
		for slot in part.engraving_slots:
			all_slots.append(slot)
			# 连接槽位信号
			if not slot.windup_started.is_connected(_on_slot_windup_started):
				slot.windup_started.connect(_on_slot_windup_started.bind(slot))
			if not slot.windup_completed.is_connected(_on_slot_windup_completed):
				slot.windup_completed.connect(_on_slot_windup_completed.bind(slot))
	
	# 注册武器的槽位
	if player != null and player.current_weapon != null:
		for slot in player.current_weapon.engraving_slots:
			all_slots.append(slot)
			# 连接槽位信号
			if not slot.windup_started.is_connected(_on_slot_windup_started):
				slot.windup_started.connect(_on_slot_windup_started.bind(slot))
			if not slot.windup_completed.is_connected(_on_slot_windup_completed):
				slot.windup_completed.connect(_on_slot_windup_completed.bind(slot))

## 连接玩家信号
func _connect_player_signals() -> void:
	if player == null:
		return
	
	# 攻击相关
	if player.has_signal("attack_started"):
		player.attack_started.connect(_on_attack_started)
	if player.has_signal("attack_hit"):
		player.attack_hit.connect(_on_attack_hit)
	if player.has_signal("attack_ended"):
		player.attack_ended.connect(_on_attack_ended)
	
	# 状态相关
	if player.has_signal("state_changed"):
		player.state_changed.connect(_on_state_changed)
	
	# 伤害相关
	if player.has_signal("took_damage"):
		player.took_damage.connect(_on_took_damage)
	if player.has_signal("health_changed"):
		player.health_changed.connect(_on_health_changed)
	
	# 施法相关
	if player.has_signal("spell_cast"):
		player.spell_cast.connect(_on_spell_cast)
	if player.has_signal("spell_hit"):
		player.spell_hit.connect(_on_spell_hit)
	
	# 武器相关
	if player.has_signal("weapon_changed"):
		player.weapon_changed.connect(_on_weapon_changed)

## 更新所有槽位（冷却和前摇）
func _update_slots(delta: float) -> void:
	for slot in all_slots:
		slot.update(delta)

## 处理周期性触发器
func _process_periodic_triggers(delta: float) -> void:
	if not is_enabled:
		return
	
	# 处理ON_TICK触发器
	current_context = {
		"delta": delta,
		"player": player,
		"position": player.global_position if player != null else Vector2.ZERO
	}
	
	distribute_trigger(TriggerData.TriggerType.ON_TICK, current_context)

## 分发触发器到所有槽位（带前摇）
func distribute_trigger(trigger_type: int, context: Dictionary = {}) -> void:
	if not is_enabled:
		return
	
	# 更新统计
	if not trigger_stats.has(trigger_type):
		trigger_stats[trigger_type] = 0
	trigger_stats[trigger_type] += 1
	
	# 遍历所有槽位
	for slot in all_slots:
		if not slot.can_trigger():
			continue
		
		if slot.engraved_spell == null:
			continue
		
		# 获取法术熟练度
		var proficiency = proficiency_manager.get_proficiency_value(slot.engraved_spell.spell_id)
		
		# 开始触发（带前摇）
		var started = slot.start_trigger(trigger_type, context, proficiency)
		
		if started:
			# 连接完成信号以执行动作
			if not slot.spell_triggered.is_connected(_on_slot_spell_triggered):
				slot.spell_triggered.connect(_on_slot_spell_triggered.bind(slot, context))

## 立即分发触发器（跳过前摇，用于特殊情况）
func distribute_trigger_immediate(trigger_type: int, context: Dictionary = {}) -> void:
	if not is_enabled:
		return
	
	for slot in all_slots:
		if not slot.can_trigger():
			continue
		
		var triggered_rules = slot.trigger(trigger_type, context)
		
		for rule in triggered_rules:
			_execute_rule_actions(rule, context, slot)
			engraving_triggered.emit(trigger_type, slot.engraved_spell, slot.slot_name)
			engraving_trigger_count += 1

## 槽位前摇开始回调
func _on_slot_windup_started(spell: SpellCoreData, windup_time: float, slot: EngravingSlot) -> void:
	engraving_windup_started.emit(slot, windup_time)
	print("[刻录前摇] %s - %s: %.2fs" % [slot.slot_name, spell.spell_name, windup_time])

## 槽位前摇完成回调
func _on_slot_windup_completed(spell: SpellCoreData, slot: EngravingSlot) -> void:
	engraving_windup_completed.emit(slot)
	print("[刻录触发] %s - %s" % [slot.slot_name, spell.spell_name])

## 槽位法术触发回调
func _on_slot_spell_triggered(spell: SpellCoreData, trigger_type: int, slot: EngravingSlot, context: Dictionary) -> void:
	# 执行法术规则
	for rule in spell.topology_rules:
		if rule.trigger != null and rule.trigger.trigger_type == trigger_type:
			if rule.enabled:
				_execute_rule_actions(rule, context, slot)
	
	# 发送信号
	engraving_triggered.emit(trigger_type, spell, slot.slot_name)
	engraving_trigger_count += 1
	
	# 记录使用
	proficiency_manager.record_spell_use(spell.spell_id)
	
	# 断开临时连接
	if slot.spell_triggered.is_connected(_on_slot_spell_triggered):
		slot.spell_triggered.disconnect(_on_slot_spell_triggered)

## 执行规则的动作
func _execute_rule_actions(rule: TopologyRuleData, context: Dictionary, slot: EngravingSlot) -> void:
	if rule == null or not rule.enabled:
		return
	
	# 添加槽位信息到上下文
	var full_context = context.duplicate()
	full_context["slot"] = slot
	full_context["slot_level"] = slot.slot_level
	full_context["is_engraved"] = true
	
	for action in rule.actions:
		if action != null:
			action_executor.execute_action(action, full_context)
			action_executed.emit(action, full_context)

## 刻录法术到肢体部件
func engrave_to_body_part(part_type: int, slot_index: int, spell: SpellCoreData) -> bool:
	var part = _get_body_part(part_type)
	if part == null:
		push_warning("未找到肢体部件: %d" % part_type)
		return false
	
	if slot_index < 0 or slot_index >= part.engraving_slots.size():
		push_warning("槽位索引无效: %d" % slot_index)
		return false
	
	return part.engraving_slots[slot_index].engrave_spell(spell)

## 刻录法术到武器
func engrave_to_weapon(slot_index: int, spell: SpellCoreData) -> bool:
	if player == null or player.current_weapon == null:
		push_warning("没有装备武器")
		return false
	
	return player.current_weapon.engrave_spell_to_slot(slot_index, spell)

## 移除肢体部件上的刻录
func remove_from_body_part(part_type: int, slot_index: int) -> SpellCoreData:
	var part = _get_body_part(part_type)
	if part == null:
		return null
	
	if slot_index < 0 or slot_index >= part.engraving_slots.size():
		return null
	
	return part.engraving_slots[slot_index].remove_spell()

## 移除武器上的刻录
func remove_from_weapon(slot_index: int) -> SpellCoreData:
	if player == null or player.current_weapon == null:
		return null
	
	return player.current_weapon.remove_spell_from_slot(slot_index)

## 获取肢体部件
func _get_body_part(part_type: int) -> BodyPartData:
	for part in body_parts:
		if part.part_type == part_type:
			return part
	return null

## 获取所有肢体部件
func get_body_parts() -> Array[BodyPartData]:
	return body_parts

## 获取指定类型的肢体部件
func get_body_part(part_type: int) -> BodyPartData:
	return _get_body_part(part_type)

## 获取所有已刻录的法术
func get_all_engraved_spells() -> Array[SpellCoreData]:
	var spells: Array[SpellCoreData] = []
	
	for part in body_parts:
		spells.append_array(part.get_engraved_spells())
	
	if player != null and player.current_weapon != null:
		spells.append_array(player.current_weapon.get_engraved_spells())
	
	return spells

## 获取法术熟练度
func get_spell_proficiency(spell_id: String) -> float:
	return proficiency_manager.get_proficiency_value(spell_id)

## 获取法术熟练度数据
func get_spell_proficiency_data(spell_id: String) -> SpellProficiency:
	return proficiency_manager.get_proficiency(spell_id)

## 获取刻录统计信息
func get_stats() -> Dictionary:
	var total_slots = all_slots.size()
	var used_slots = 0
	var winding_up_count = 0
	
	for slot in all_slots:
		if slot.engraved_spell != null:
			used_slots += 1
		if slot.is_winding_up:
			winding_up_count += 1
	
	return {
		"total_slots": total_slots,
		"used_slots": used_slots,
		"winding_up_count": winding_up_count,
		"trigger_count": engraving_trigger_count,
		"trigger_stats": trigger_stats.duplicate(),
		"proficiency_stats": proficiency_manager.get_stats_summary()
	}

## 获取刻录触发次数
func get_trigger_count() -> int:
	return engraving_trigger_count

## 熟练度改变回调
func _on_proficiency_changed(spell_id: String, proficiency: float) -> void:
	proficiency_updated.emit(spell_id, proficiency)

## 熟练度升级回调
func _on_proficiency_level_up(spell_id: String, new_level: int) -> void:
	var level_names = ["新手", "学徒", "熟练", "专家", "大师"]
	var level_name = level_names[new_level] if new_level < level_names.size() else "未知"
	print("[熟练度提升] %s 达到 %s 级别!" % [spell_id, level_name])

# ========== 信号回调 ==========

## 攻击开始回调
func _on_attack_started(attack: AttackData) -> void:
	current_context = {
		"attack": attack,
		"player": player,
		"position": player.global_position
	}
	distribute_trigger(TriggerData.TriggerType.ON_ATTACK_START, current_context)

## 攻击命中回调
func _on_attack_hit(target: Node2D, damage: float) -> void:
	current_context = {
		"target": target,
		"damage": damage,
		"player": player,
		"position": player.global_position,
		"target_position": target.global_position if target != null else Vector2.ZERO
	}
	
	# 分发武器命中触发器
	distribute_trigger(TriggerData.TriggerType.ON_WEAPON_HIT, current_context)
	
	# 分发造成伤害触发器
	distribute_trigger(TriggerData.TriggerType.ON_DEAL_DAMAGE, current_context)
	
	# 检查是否击杀
	if target != null and target.has_method("is_dead") and target.is_dead():
		distribute_trigger(TriggerData.TriggerType.ON_KILL_ENEMY, current_context)
		
		# 记录击杀（为所有已刻录的法术增加经验）
		for spell in get_all_engraved_spells():
			proficiency_manager.record_spell_kill(spell.spell_id)

## 攻击结束回调
func _on_attack_ended(attack: AttackData) -> void:
	current_context = {
		"attack": attack,
		"player": player,
		"position": player.global_position
	}
	distribute_trigger(TriggerData.TriggerType.ON_ATTACK_END, current_context)

## 状态改变回调
func _on_state_changed(state_name: String) -> void:
	current_context = {
		"state_name": state_name,
		"player": player,
		"position": player.global_position
	}
	
	# 状态进入触发
	distribute_trigger(TriggerData.TriggerType.ON_STATE_ENTER, current_context)
	
	# 特定状态触发
	match state_name:
		"Fly":
			distribute_trigger(TriggerData.TriggerType.ON_FLY_START, current_context)
		"Move":
			distribute_trigger(TriggerData.TriggerType.ON_MOVE_START, current_context)
		"Idle":
			# 检查之前是否在飞行
			if player.was_flying:
				distribute_trigger(TriggerData.TriggerType.ON_FLY_END, current_context)
			distribute_trigger(TriggerData.TriggerType.ON_MOVE_STOP, current_context)

## 受到伤害回调
func _on_took_damage(damage: float, source: Node2D) -> void:
	current_context = {
		"damage": damage,
		"source": source,
		"player": player,
		"position": player.global_position
	}
	distribute_trigger(TriggerData.TriggerType.ON_TAKE_DAMAGE, current_context)

## 生命值改变回调
func _on_health_changed(current: float, maximum: float) -> void:
	var ratio = current / maximum if maximum > 0 else 0
	
	current_context = {
		"current_health": current,
		"max_health": maximum,
		"health_ratio": ratio,
		"player": player,
		"position": player.global_position
	}
	
	# 低生命触发（低于30%）
	if ratio < 0.3:
		distribute_trigger(TriggerData.TriggerType.ON_HEALTH_LOW, current_context)

## 施法回调
func _on_spell_cast(spell: SpellCoreData) -> void:
	current_context = {
		"spell": spell,
		"player": player,
		"position": player.global_position
	}
	distribute_trigger(TriggerData.TriggerType.ON_SPELL_CAST, current_context)

## 法术命中回调
func _on_spell_hit(target: Node2D, damage: float) -> void:
	current_context = {
		"target": target,
		"damage": damage,
		"player": player,
		"position": player.global_position
	}
	
	# 记录命中（为当前法术增加经验）
	if player.current_spell != null:
		proficiency_manager.record_spell_hit(player.current_spell.spell_id)

## 武器改变回调
func _on_weapon_changed(weapon: WeaponData) -> void:
	# 重新注册所有槽位
	_register_all_slots()
