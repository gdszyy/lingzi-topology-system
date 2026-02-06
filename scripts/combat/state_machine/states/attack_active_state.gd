extends State
class_name AttackActiveState

## 攻击激活状态
## 在此阶段执行实际的攻击动作，包括：
## - 武器挥舞动画（由物理系统驱动）
## - 伤害判定
## - 攻击冲量
## 【优化】消除重复类型转换、增加 EventBus 集成、优化 hitbox 信号连接

var player: PlayerController

var current_attack: AttackData = null
var input_type: int = 0
var combo_index: int = 0
var active_timer: float = 0.0
var from_fly: bool = false

var hit_targets: Array[Node2D] = []
var impulse_applied: bool = false
var swing_started: bool = false

## 【优化】缓存 PlayerVisuals 引用，避免每次都做 as 类型转换
var _cached_visuals: PlayerVisuals = null
## 【优化】标记 hitbox 信号是否已连接，避免重复检查
var _hitbox_connected: bool = false

func initialize(_owner: Node) -> void:
	super.initialize(_owner)
	player = _owner as PlayerController

func enter(params: Dictionary = {}) -> void:
	player.can_move = true
	player.can_rotate = false
	player.is_attacking = true
	player.current_attack_phase = "active"

	current_attack = params.get("attack", null)
	player.current_attack = current_attack
	input_type = params.get("input_type", 0)
	combo_index = params.get("combo_index", 0)
	from_fly = params.get("from_fly", false)

	active_timer = 0.0
	hit_targets.clear()
	impulse_applied = false
	swing_started = false

	## 【优化】缓存 visuals 引用
	_cached_visuals = player.visuals as PlayerVisuals if player.visuals != null else null

	if current_attack == null:
		transition_to("Idle")
		return

	## 施加攻击冲量
	_apply_attack_impulse()

	## 开始武器挥舞动画
	_start_weapon_swing()

	## 启用伤害判定
	_enable_hitbox()

	## 【新增】通过 EventBus 发布攻击激活事件
	if Engine.has_singleton("EventBus") or has_node("/root/EventBus"):
		var event_bus = Engine.get_singleton("EventBus") if Engine.has_singleton("EventBus") else get_node_or_null("/root/EventBus")
		if event_bus != null and event_bus.has_method("emit_event"):
			event_bus.emit_event("attack_active_started", {
				"attack": current_attack,
				"player": player,
				"combo_index": combo_index
			})

func exit() -> void:
	active_timer = 0.0
	hit_targets.clear()
	impulse_applied = false
	swing_started = false
	player.current_attack_phase = ""
	_cached_visuals = null

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

	## 【优化】使用缓存的 visuals 引用
	if _cached_visuals != null:
		var angular_impulse = impulse_strength * 0.01 * signf(current_attack.swing_end_angle - current_attack.swing_start_angle)
		_cached_visuals.apply_weapon_angular_impulse(angular_impulse)

	impulse_applied = true

func _start_weapon_swing() -> void:
	if swing_started or current_attack == null:
		return

	## 【优化】使用缓存的 visuals 引用
	if _cached_visuals != null:
		_cached_visuals.play_attack_effect(current_attack)

	swing_started = true

func _enable_hitbox() -> void:
	if player.hitbox == null:
		return

	player.hitbox.monitoring = true

	## 【优化】只在首次连接信号，避免每次进入状态都检查
	if not _hitbox_connected:
		player.hitbox.area_entered.connect(_on_hitbox_area_entered)
		player.hitbox.body_entered.connect(_on_hitbox_body_entered)
		_hitbox_connected = true

func _disable_hitbox() -> void:
	if player.hitbox != null:
		player.hitbox.monitoring = false

func _check_hits() -> void:
	## 可以在这里添加额外的命中检测逻辑
	## 例如基于武器轨迹的精确碰撞检测
	pass

func _on_hitbox_area_entered(area: Area2D) -> void:
	## 【安全检查】只在激活状态下处理命中
	if not player.is_attacking or player.current_attack_phase != "active":
		return
	var target = area.get_parent()
	_try_hit_target(target)

func _on_hitbox_body_entered(body: Node2D) -> void:
	## 【安全检查】只在激活状态下处理命中
	if not player.is_attacking or player.current_attack_phase != "active":
		return
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

	## 【优化】使用缓存的 visuals 引用
	if _cached_visuals != null:
		_cached_visuals.play_hit_effect()

func _apply_camera_shake(intensity: float) -> void:
	var camera = player.get_viewport().get_camera_2d()
	if camera != null and camera.has_method("apply_shake"):
		camera.apply_shake(intensity)
