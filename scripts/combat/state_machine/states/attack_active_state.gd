# attack_active_state.gd
# 攻击判定状态 - 攻击动作的伤害判定阶段
extends State
class_name AttackActiveState

## 玩家控制器引用
var player: PlayerController

## 当前攻击数据
var current_attack: AttackData = null

## 输入类型
var input_type: int = 0

## 连击索引
var combo_index: int = 0

## 判定计时器
var active_timer: float = 0.0

## 是否从飞行状态进入
var from_fly: bool = false

## 已命中的目标（防止重复判定）
var hit_targets: Array[Node2D] = []

## 是否已施加冲量
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
	
	# 施加攻击冲量
	_apply_attack_impulse()
	
	# 播放攻击动画
	_play_active_animation()
	
	# 启用伤害判定
	_enable_hitbox()

func exit() -> void:
	active_timer = 0.0
	hit_targets.clear()
	impulse_applied = false
	
	# 禁用伤害判定
	_disable_hitbox()

func physics_update(delta: float) -> void:
	active_timer += delta
	
	# 检测命中
	_check_hits()
	
	# 检查判定是否结束
	if current_attack != null and active_timer >= current_attack.active_time:
		transition_to("AttackRecovery", {
			"attack": current_attack,
			"input_type": input_type,
			"combo_index": combo_index,
			"from_fly": from_fly
		})

## 施加攻击冲量
func _apply_attack_impulse() -> void:
	if impulse_applied or current_attack == null or player.current_weapon == null:
		return
	
	var impulse_strength = player.current_weapon.get_attack_impulse()
	impulse_strength *= current_attack.impulse_multiplier
	
	# 向朝向方向施加冲量
	var direction = Vector2.from_angle(player.get_facing_angle())
	player.apply_attack_impulse(direction, impulse_strength)
	
	impulse_applied = true

## 播放攻击动画
func _play_active_animation() -> void:
	if current_attack == null:
		return
	
	# TODO: 播放实际动画
	# player.animation_player.play(current_attack.animation_name + "_active")

## 启用伤害判定
func _enable_hitbox() -> void:
	if player.hitbox != null:
		player.hitbox.monitoring = true
		# 连接信号
		if not player.hitbox.area_entered.is_connected(_on_hitbox_area_entered):
			player.hitbox.area_entered.connect(_on_hitbox_area_entered)
		if not player.hitbox.body_entered.is_connected(_on_hitbox_body_entered):
			player.hitbox.body_entered.connect(_on_hitbox_body_entered)

## 禁用伤害判定
func _disable_hitbox() -> void:
	if player.hitbox != null:
		player.hitbox.monitoring = false

## 检测命中
func _check_hits() -> void:
	# 通过Area2D的信号处理
	pass

## 处理Area进入
func _on_hitbox_area_entered(area: Area2D) -> void:
	var target = area.get_parent()
	_try_hit_target(target)

## 处理Body进入
func _on_hitbox_body_entered(body: Node2D) -> void:
	_try_hit_target(body)

## 尝试命中目标
func _try_hit_target(target: Node2D) -> void:
	# 检查是否已命中
	if target in hit_targets:
		return
	
	# 检查是否为敌人
	if not target.is_in_group("enemies"):
		return
	
	# 计算伤害
	var damage = _calculate_damage()
	
	# 应用伤害
	if target.has_method("take_damage"):
		target.take_damage(damage)
	
	# 应用击退
	_apply_knockback(target)
	
	# 记录命中
	hit_targets.append(target)
	
	# 更新统计
	player.stats.total_damage_dealt += damage
	player.stats.total_hits += 1
	
	# 发送信号
	player.attack_hit.emit(target, damage)

## 计算伤害
func _calculate_damage() -> float:
	if current_attack == null or player.current_weapon == null:
		return 0.0
	
	return current_attack.calculate_damage(player.current_weapon.base_damage)

## 应用击退
func _apply_knockback(target: Node2D) -> void:
	if current_attack == null or player.current_weapon == null:
		return
	
	var knockback = player.current_weapon.knockback_force * current_attack.knockback_multiplier
	var direction = (target.global_position - player.global_position).normalized()
	
	if target.has_method("apply_knockback"):
		target.apply_knockback(direction * knockback)
