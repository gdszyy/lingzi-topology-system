extends State
class_name AttackActiveState

## 攻击激活状态
## 在此阶段执行实际的攻击动作，包括：
## - 武器挥舞动画（由物理系统驱动）
## - 伤害判定
## - 攻击冲量

var player: PlayerController

var current_attack: AttackData = null
var input_type: int = 0
var combo_index: int = 0
var active_timer: float = 0.0
var from_fly: bool = false

var hit_targets: Array[Node2D] = []
var impulse_applied: bool = false
var swing_started: bool = false

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
	swing_started = false

	if current_attack == null:
		transition_to("Idle")
		return

	## 施加攻击冲量
	_apply_attack_impulse()
	
	## 开始武器挥舞动画
	_start_weapon_swing()

	## 启用伤害判定
	_enable_hitbox()

func exit() -> void:
	active_timer = 0.0
	hit_targets.clear()
	impulse_applied = false
	swing_started = false

	_disable_hitbox()

func physics_update(delta: float) -> void:
	active_timer += delta

	_check_hits()
	
	## 更新武器挥舞进度
	_update_weapon_swing_progress()

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
	
	## 同时给武器施加角冲量，增强挥舞感
	if player.visuals != null:
		var visuals = player.visuals as PlayerVisuals
		if visuals != null:
			var angular_impulse = impulse_strength * 0.01 * sign(current_attack.swing_end_angle - current_attack.swing_start_angle)
			visuals.apply_weapon_angular_impulse(angular_impulse)

	impulse_applied = true

func _start_weapon_swing() -> void:
	if swing_started or current_attack == null:
		return
	
	if player.visuals != null:
		var visuals = player.visuals as PlayerVisuals
		if visuals != null:
			visuals.play_attack_effect(current_attack)
	
	swing_started = true

func _update_weapon_swing_progress() -> void:
	## 武器挥舞由 PlayerVisuals 和 WeaponPhysics 自动处理
	## 这里可以添加额外的效果，如拖尾、音效等
	pass

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
	## 可以在这里添加额外的命中检测逻辑
	## 例如基于武器轨迹的精确碰撞检测
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
	
	## 触发命中效果
	_play_hit_effects(target)

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

func _play_hit_effects(target: Node2D) -> void:
	## 播放命中特效
	if current_attack != null and current_attack.hit_effect_scene != null:
		var effect = current_attack.hit_effect_scene.instantiate()
		target.get_parent().add_child(effect)
		effect.global_position = target.global_position
	
	## 屏幕震动
	if current_attack != null and current_attack.camera_shake_intensity > 0:
		_apply_camera_shake(current_attack.camera_shake_intensity)
	
	## 视觉反馈
	if player.visuals != null:
		var visuals = player.visuals as PlayerVisuals
		if visuals != null:
			visuals.play_hit_effect()

func _apply_camera_shake(intensity: float) -> void:
	## 获取相机并应用震动
	var camera = player.get_viewport().get_camera_2d()
	if camera != null and camera.has_method("apply_shake"):
		camera.apply_shake(intensity)
