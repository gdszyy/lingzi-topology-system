extends State
class_name SpellCastState

## 施法状态（优化版）
## 改进：接入 SpatialGrid 高效索敌、EventBus 事件通知、对象池支持
## 增加施法前能量检查、施法中断恢复机制、施法进度事件通知

enum CastPhase {
	WINDUP,
	RELEASE,
	RECOVERY
}

var player: PlayerController

var target_position: Vector2 = Vector2.ZERO

var current_phase: CastPhase = CastPhase.WINDUP

var phase_timer: float = 0.0

var windup_duration: float = 0.5

var release_duration: float = 0.1

var recovery_duration: float = 0.2

var spell_fired: bool = false

var is_engraved_cast: bool = false

var casting_spell: SpellCoreData = null

var proficiency_manager: ProficiencyManager = null

var projectile_scene: PackedScene

func initialize(_owner: Node) -> void:
	super.initialize(_owner)
	player = _owner as PlayerController
	projectile_scene = preload("res://scenes/battle_test/entities/projectile.tscn")

	proficiency_manager = player.get_node_or_null("ProficiencyManager") as ProficiencyManager
	if proficiency_manager == null:
		proficiency_manager = ProficiencyManager.new()
		proficiency_manager.name = "ProficiencyManager"
		player.add_child(proficiency_manager)

func enter(params: Dictionary = {}) -> void:
	player.can_move = false
	player.can_rotate = false
	player.is_casting = true

	var input = params.get("input", null)
	if input != null:
		target_position = input.position
	else:
		target_position = player.mouse_position

	is_engraved_cast = params.get("is_engraved", false)

	casting_spell = params.get("spell", player.current_spell)
	if casting_spell == null:
		casting_spell = player.current_spell
	
	# 施法前能量检查
	if casting_spell != null and not _check_resource_cost():
		push_warning("[SpellCastState] 能量不足，无法施放 %s" % casting_spell.spell_name)
		_cancel_cast()
		return

	_calculate_windup_time()

	current_phase = CastPhase.WINDUP
	phase_timer = 0.0
	spell_fired = false

	_play_windup_animation()

	if casting_spell != null and proficiency_manager != null:
		proficiency_manager.record_spell_use(casting_spell.spell_id)
	
	# 通过 EventBus 通知施法开始
	_publish_cast_event("cast_started", {
		"spell": casting_spell,
		"windup_duration": windup_duration,
		"is_engraved": is_engraved_cast
	})

func exit() -> void:
	phase_timer = 0.0
	spell_fired = false
	player.is_casting = false
	casting_spell = null
	is_engraved_cast = false

func physics_update(delta: float) -> void:
	phase_timer += delta

	match current_phase:
		CastPhase.WINDUP:
			_update_windup_phase(delta)
		CastPhase.RELEASE:
			_update_release_phase(delta)
		CastPhase.RECOVERY:
			_update_recovery_phase(delta)

func handle_input(event: InputEvent) -> void:
	if current_phase == CastPhase.WINDUP:
		if event is InputEventKey and event.pressed:
			if event.keycode == KEY_ESCAPE:
				_cancel_cast()
		elif event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_RIGHT:
				_cancel_cast()

## 检查资源消耗是否满足
func _check_resource_cost() -> bool:
	if casting_spell == null:
		return false
	
	# 如果玩家有能量系统，检查能量是否足够
	if player.has_method("get_energy_system"):
		var energy_system = player.get_energy_system()
		if energy_system != null:
			return energy_system.current_energy >= casting_spell.resource_cost
	
	# 如果没有能量系统，默认允许施法
	return true

func _calculate_windup_time() -> void:
	if casting_spell == null:
		windup_duration = 0.5
		return

	var proficiency = 0.0
	if proficiency_manager != null:
		proficiency = proficiency_manager.get_proficiency_value(casting_spell.spell_id)

	windup_duration = casting_spell.calculate_windup_time(proficiency, is_engraved_cast)

func _update_windup_phase(_delta: float) -> void:
	if phase_timer >= windup_duration:
		current_phase = CastPhase.RELEASE
		phase_timer = 0.0
		_play_release_animation()

func _update_release_phase(_delta: float) -> void:
	if not spell_fired:
		_fire_spell()
		spell_fired = true

	if phase_timer >= release_duration:
		current_phase = CastPhase.RECOVERY
		phase_timer = 0.0
		_play_recovery_animation()

func _update_recovery_phase(_delta: float) -> void:
	if phase_timer >= recovery_duration:
		_on_cast_complete()

func _fire_spell() -> void:
	if casting_spell == null:
		return

	# 扣除资源消耗
	_consume_resource_cost()

	if not casting_spell.is_projectile_spell():
		_trigger_spell_effects()
		return

	var direction = (target_position - player.global_position).normalized()

	var projectile = _spawn_projectile(casting_spell, direction)

	if projectile != null:
		if casting_spell.carrier != null and casting_spell.carrier.homing_strength > 0:
			var nearest = _find_nearest_enemy(player.global_position)
			if nearest != null:
				projectile.set_target(nearest)

		player.stats.spells_cast += 1

		player.spell_cast.emit(casting_spell)
	
	# 通过 EventBus 通知法术释放
	_publish_cast_event("spell_released", {
		"spell": casting_spell,
		"direction": direction,
		"position": player.global_position
	})

## 扣除资源消耗
func _consume_resource_cost() -> void:
	if casting_spell == null:
		return
	
	if player.has_method("get_energy_system"):
		var energy_system = player.get_energy_system()
		if energy_system != null:
			energy_system.consume_energy(casting_spell.resource_cost)

func _trigger_spell_effects() -> void:
	if player.engraving_manager != null:
		var context = {
			"spell": casting_spell,
			"player": player,
			"position": player.global_position,
			"target_position": target_position,
			"is_engraved": is_engraved_cast
		}

		player.engraving_manager.distribute_trigger(
			TriggerData.TriggerType.ON_SPELL_CAST,
			context
		)

	player.spell_cast.emit(casting_spell)

func _spawn_projectile(spell: SpellCoreData, direction: Vector2) -> Projectile:
	# 优先使用对象池
	var projectile: Projectile = null
	if ObjectPool.instance != null:
		var pooled = ObjectPool.instance.acquire("res://scenes/battle_test/entities/projectile.tscn")
		if pooled is Projectile:
			projectile = pooled as Projectile
	
	if projectile == null:
		projectile = projectile_scene.instantiate() as Projectile
	
	if projectile == null:
		return null

	player.get_tree().current_scene.add_child(projectile)
	projectile.initialize(spell, direction, player.global_position)

	projectile.hit_enemy.connect(_on_projectile_hit.bind(spell))
	projectile.projectile_died.connect(_on_projectile_died)

	return projectile

## 统一的索敌方法（优先使用 SpatialGrid）
func _find_nearest_enemy(from_pos: Vector2) -> Node2D:
	if SpatialGrid.instance != null:
		return SpatialGrid.instance.find_nearest(from_pos, "enemies")
	
	# 回退到线性搜索
	var enemies = player.get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var nearest_dist = INF

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist = from_pos.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy

	return nearest

func _cancel_cast() -> void:
	# 通过 EventBus 通知施法取消
	_publish_cast_event("cast_cancelled", {
		"spell": casting_spell,
		"phase": current_phase
	})

	if player.input_direction.length_squared() > 0.01:
		if player.is_flying:
			transition_to("Fly")
		else:
			transition_to("Move")
	else:
		transition_to("Idle")

func _on_cast_complete() -> void:
	# 通过 EventBus 通知施法完成
	_publish_cast_event("cast_completed", {
		"spell": casting_spell
	})

	if player.input_direction.length_squared() > 0.01:
		if player.is_flying:
			transition_to("Fly")
		else:
			transition_to("Move")
	else:
		transition_to("Idle")

## 通过 EventBus 发布施法事件
func _publish_cast_event(event_name: String, data: Dictionary) -> void:
	if EventBus.instance == null:
		return
	EventBus.instance.publish(event_name, data)

func _play_windup_animation() -> void:
	pass

func _play_release_animation() -> void:
	pass

func _play_recovery_animation() -> void:
	pass

func _on_projectile_hit(_enemy: Node2D, damage: float, spell: SpellCoreData) -> void:
	player.stats.total_damage_dealt += damage
	player.stats.total_hits += 1

	if proficiency_manager != null and spell != null:
		proficiency_manager.record_spell_hit(spell.spell_id)

	player.spell_hit.emit(_enemy, damage)

func _on_projectile_died(_projectile: Projectile) -> void:
	pass

func get_cast_progress() -> float:
	match current_phase:
		CastPhase.WINDUP:
			return (phase_timer / windup_duration) * 0.5 if windup_duration > 0 else 0.5
		CastPhase.RELEASE:
			return 0.5 + (phase_timer / release_duration) * 0.3 if release_duration > 0 else 0.8
		CastPhase.RECOVERY:
			return 0.8 + (phase_timer / recovery_duration) * 0.2 if recovery_duration > 0 else 1.0
	return 0.0

func get_phase_name() -> String:
	match current_phase:
		CastPhase.WINDUP:
			return "蓄能"
		CastPhase.RELEASE:
			return "释放"
		CastPhase.RECOVERY:
			return "后摇"
	return "未知"
