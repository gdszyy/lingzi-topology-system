extends State
class_name SpellCastState

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

	_calculate_windup_time()

	current_phase = CastPhase.WINDUP
	phase_timer = 0.0
	spell_fired = false

	_play_windup_animation()

	if casting_spell != null and proficiency_manager != null:
		proficiency_manager.record_spell_use(casting_spell.spell_id)

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

func _calculate_windup_time() -> void:
	if casting_spell == null:
		windup_duration = 0.5
		return

	var proficiency = 0.0
	if proficiency_manager != null:
		proficiency = proficiency_manager.get_proficiency_value(casting_spell.spell_id)

	windup_duration = casting_spell.calculate_windup_time(proficiency, is_engraved_cast)

	var normal_windup = casting_spell.calculate_windup_time(proficiency, false)
	print("[施法] %s | 熟练度: %.0f%% | 普通前摇: %.2fs | 实际前摇: %.2fs%s" % [
		casting_spell.spell_name,
		proficiency * 100,
		normal_windup,
		windup_duration,
		" (刻录)" if is_engraved_cast else ""
	])

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
	var projectile = projectile_scene.instantiate() as Projectile
	if projectile == null:
		return null

	player.get_tree().current_scene.add_child(projectile)
	projectile.initialize(spell, direction, player.global_position)

	projectile.hit_enemy.connect(_on_projectile_hit.bind(spell))
	projectile.projectile_died.connect(_on_projectile_died)

	return projectile

func _find_nearest_enemy(from_pos: Vector2) -> Node2D:
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
	print("[施法取消] %s" % (casting_spell.spell_name if casting_spell else "未知"))

	if player.input_direction.length_squared() > 0.01:
		if player.is_flying:
			transition_to("Fly")
		else:
			transition_to("Move")
	else:
		transition_to("Idle")

func _on_cast_complete() -> void:
	if player.input_direction.length_squared() > 0.01:
		if player.is_flying:
			transition_to("Fly")
		else:
			transition_to("Move")
	else:
		transition_to("Idle")

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
