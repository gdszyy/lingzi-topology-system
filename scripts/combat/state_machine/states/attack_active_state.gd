extends State
class_name AttackActiveState

var player: PlayerController

var current_attack: AttackData = null

var input_type: int = 0

var combo_index: int = 0

var active_timer: float = 0.0

var from_fly: bool = false

var hit_targets: Array[Node2D] = []

var impulse_applied: bool = false

func initialize(_owner: Node) -> void:
	super.initialize(_owner)
	player = _owner as PlayerController

func enter(params: Dictionary = {}) -> void:
	player.can_move = false
	player.can_rotate = false
	player.is_attacking = true

	current_attack = params.get("attack", null)
	input_type = params.get("input_type", 0)
	combo_index = params.get("combo_index", 0)
	from_fly = params.get("from_fly", false)

	active_timer = 0.0
	hit_targets.clear()
	impulse_applied = false

	if current_attack == null:
		transition_to("Idle")
		return

	_apply_attack_impulse()

	_play_active_animation()

	_enable_hitbox()

func exit() -> void:
	active_timer = 0.0
	hit_targets.clear()
	impulse_applied = false

	_disable_hitbox()

func physics_update(delta: float) -> void:
	active_timer += delta

	_check_hits()

	if current_attack != null and active_timer >= current_attack.active_time:
		transition_to("AttackRecovery", {
			"attack": current_attack,
			"input_type": input_type,
			"combo_index": combo_index,
			"from_fly": from_fly
		})

func _apply_attack_impulse() -> void:
	if impulse_applied or current_attack == null or player.current_weapon == null:
		return

	var impulse_strength = player.current_weapon.get_attack_impulse()
	impulse_strength *= current_attack.impulse_multiplier

	var direction = Vector2.from_angle(player.get_facing_angle())
	player.apply_attack_impulse(direction, impulse_strength)

	impulse_applied = true

func _play_active_animation() -> void:
	if current_attack == null:
		return

func _enable_hitbox() -> void:
	if player.hitbox != null:
		player.hitbox.monitoring = true
		if not player.hitbox.area_entered.is_connected(_on_hitbox_area_entered):
			player.hitbox.area_entered.connect(_on_hitbox_area_entered)
		if not player.hitbox.body_entered.is_connected(_on_hitbox_body_entered):
			player.hitbox.body_entered.connect(_on_hitbox_body_entered)

func _disable_hitbox() -> void:
	if player.hitbox != null:
		player.hitbox.monitoring = false

func _check_hits() -> void:
	pass

func _on_hitbox_area_entered(area: Area2D) -> void:
	var target = area.get_parent()
	_try_hit_target(target)

func _on_hitbox_body_entered(body: Node2D) -> void:
	_try_hit_target(body)

func _try_hit_target(target: Node2D) -> void:
	if target in hit_targets:
		return

	if not target.is_in_group("enemies"):
		return

	var damage = _calculate_damage()

	if target.has_method("take_damage"):
		target.take_damage(damage)

	_apply_knockback(target)

	hit_targets.append(target)

	player.stats.total_damage_dealt += damage
	player.stats.total_hits += 1

	player.attack_hit.emit(target, damage)

func _calculate_damage() -> float:
	if current_attack == null or player.current_weapon == null:
		return 0.0

	return current_attack.calculate_damage(player.current_weapon.base_damage)

func _apply_knockback(target: Node2D) -> void:
	if current_attack == null or player.current_weapon == null:
		return

	var knockback = player.current_weapon.knockback_force * current_attack.knockback_multiplier
	var direction = (target.global_position - player.global_position).normalized()

	if target.has_method("apply_knockback"):
		target.apply_knockback(direction * knockback)
