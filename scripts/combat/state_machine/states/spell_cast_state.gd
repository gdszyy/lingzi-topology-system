# spell_cast_state.gd
# 施法状态 - 角色施放法术的状态（支持前摇和熟练度系统）
extends State
class_name SpellCastState

## 施法阶段枚举
enum CastPhase {
	WINDUP,     # 前摇/蓄能阶段
	RELEASE,    # 释放阶段
	RECOVERY    # 后摇阶段
}

## 玩家控制器引用
var player: PlayerController

## 施法目标位置
var target_position: Vector2 = Vector2.ZERO

## 当前施法阶段
var current_phase: CastPhase = CastPhase.WINDUP

## 阶段计时器
var phase_timer: float = 0.0

## 前摇时间（根据法术cost和熟练度计算）
var windup_duration: float = 0.5

## 释放时间
var release_duration: float = 0.1

## 后摇时间
var recovery_duration: float = 0.2

## 是否已发射法术
var spell_fired: bool = false

## 是否为刻录触发
var is_engraved_cast: bool = false

## 当前施放的法术
var casting_spell: SpellCoreData = null

## 熟练度管理器引用
var proficiency_manager: ProficiencyManager = null

## 子弹场景
var projectile_scene: PackedScene

func initialize(_owner: Node) -> void:
	super.initialize(_owner)
	player = _owner as PlayerController
	projectile_scene = preload("res://scenes/battle_test/entities/projectile.tscn")
	
	# 尝试获取熟练度管理器
	proficiency_manager = player.get_node_or_null("ProficiencyManager") as ProficiencyManager
	if proficiency_manager == null:
		# 创建一个新的熟练度管理器
		proficiency_manager = ProficiencyManager.new()
		proficiency_manager.name = "ProficiencyManager"
		player.add_child(proficiency_manager)

func enter(params: Dictionary = {}) -> void:
	player.can_move = false
	player.can_rotate = false
	player.is_casting = true
	
	# 获取目标位置
	var input = params.get("input", null)
	if input != null:
		target_position = input.position
	else:
		target_position = player.mouse_position
	
	# 检查是否为刻录触发
	is_engraved_cast = params.get("is_engraved", false)
	
	# 获取要施放的法术
	casting_spell = params.get("spell", player.current_spell)
	if casting_spell == null:
		casting_spell = player.current_spell
	
	# 计算前摇时间
	_calculate_windup_time()
	
	# 初始化状态
	current_phase = CastPhase.WINDUP
	phase_timer = 0.0
	spell_fired = false
	
	# 播放蓄能动画
	_play_windup_animation()
	
	# 记录法术使用
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
	# 允许在前摇阶段取消施法（按ESC或右键）
	if current_phase == CastPhase.WINDUP:
		if event is InputEventKey and event.pressed:
			if event.keycode == KEY_ESCAPE:
				_cancel_cast()
		elif event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_RIGHT:
				_cancel_cast()

## 计算前摇时间
func _calculate_windup_time() -> void:
	if casting_spell == null:
		windup_duration = 0.5
		return
	
	# 获取熟练度
	var proficiency = 0.0
	if proficiency_manager != null:
		proficiency = proficiency_manager.get_proficiency_value(casting_spell.spell_id)
	
	# 计算前摇时间（考虑是否为刻录触发）
	windup_duration = casting_spell.calculate_windup_time(proficiency, is_engraved_cast)
	
	# 调试输出
	var normal_windup = casting_spell.calculate_windup_time(proficiency, false)
	print("[施法] %s | 熟练度: %.0f%% | 普通前摇: %.2fs | 实际前摇: %.2fs%s" % [
		casting_spell.spell_name,
		proficiency * 100,
		normal_windup,
		windup_duration,
		" (刻录)" if is_engraved_cast else ""
	])

## 更新前摇阶段
func _update_windup_phase(delta: float) -> void:
	# 前摇完成，进入释放阶段
	if phase_timer >= windup_duration:
		current_phase = CastPhase.RELEASE
		phase_timer = 0.0
		_play_release_animation()

## 更新释放阶段
func _update_release_phase(delta: float) -> void:
	# 在释放阶段发射法术
	if not spell_fired:
		_fire_spell()
		spell_fired = true
	
	# 释放完成，进入后摇阶段
	if phase_timer >= release_duration:
		current_phase = CastPhase.RECOVERY
		phase_timer = 0.0
		_play_recovery_animation()

## 更新后摇阶段
func _update_recovery_phase(delta: float) -> void:
	# 后摇完成，施法结束
	if phase_timer >= recovery_duration:
		_on_cast_complete()

## 发射法术
func _fire_spell() -> void:
	if casting_spell == null:
		return
	
	# 检查法术类型
	if not casting_spell.is_projectile_spell():
		# 非投射物法术，只触发效果
		_trigger_spell_effects()
		return
	
	# 计算方向
	var direction = (target_position - player.global_position).normalized()
	
	# 创建法术实体
	var projectile = _spawn_projectile(casting_spell, direction)
	
	if projectile != null:
		# 设置追踪目标（如果法术有追踪能力）
		if casting_spell.carrier != null and casting_spell.carrier.homing_strength > 0:
			var nearest = _find_nearest_enemy(player.global_position)
			if nearest != null:
				projectile.set_target(nearest)
		
		# 更新统计
		player.stats.spells_cast += 1
		
		# 发送信号
		player.spell_cast.emit(casting_spell)

## 触发法术效果（非投射物法术）
func _trigger_spell_effects() -> void:
	# 对于刻录法术或纯效果法术，直接触发其规则
	if player.engraving_manager != null:
		var context = {
			"spell": casting_spell,
			"player": player,
			"position": player.global_position,
			"target_position": target_position,
			"is_engraved": is_engraved_cast
		}
		
		# 触发施法相关的刻录效果
		player.engraving_manager.distribute_trigger(
			TriggerData.TriggerType.ON_SPELL_CAST,
			context
		)
	
	# 发送信号
	player.spell_cast.emit(casting_spell)

## 生成法术实体
func _spawn_projectile(spell: SpellCoreData, direction: Vector2) -> Projectile:
	var projectile = projectile_scene.instantiate() as Projectile
	if projectile == null:
		return null
	
	player.get_tree().current_scene.add_child(projectile)
	projectile.initialize(spell, direction, player.global_position)
	
	# 连接信号
	projectile.hit_enemy.connect(_on_projectile_hit.bind(spell))
	projectile.projectile_died.connect(_on_projectile_died)
	
	return projectile

## 查找最近的敌人
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

## 取消施法
func _cancel_cast() -> void:
	print("[施法取消] %s" % (casting_spell.spell_name if casting_spell else "未知"))
	
	# 返回正常状态
	if player.input_direction.length_squared() > 0.01:
		if player.is_flying:
			transition_to("Fly")
		else:
			transition_to("Move")
	else:
		transition_to("Idle")

## 施法完成
func _on_cast_complete() -> void:
	# 返回正常状态
	if player.input_direction.length_squared() > 0.01:
		if player.is_flying:
			transition_to("Fly")
		else:
			transition_to("Move")
	else:
		transition_to("Idle")

## 播放蓄能动画
func _play_windup_animation() -> void:
	# TODO: 播放实际动画
	pass

## 播放释放动画
func _play_release_animation() -> void:
	# TODO: 播放实际动画
	pass

## 播放后摇动画
func _play_recovery_animation() -> void:
	# TODO: 播放实际动画
	pass

## 法术命中回调
func _on_projectile_hit(_enemy: Node2D, damage: float, spell: SpellCoreData) -> void:
	player.stats.total_damage_dealt += damage
	player.stats.total_hits += 1
	
	# 记录命中
	if proficiency_manager != null and spell != null:
		proficiency_manager.record_spell_hit(spell.spell_id)
	
	# 发送信号
	player.spell_hit.emit(_enemy, damage)

## 法术消失回调
func _on_projectile_died(_projectile: Projectile) -> void:
	pass

## 获取当前施法进度 (0.0 - 1.0)
func get_cast_progress() -> float:
	match current_phase:
		CastPhase.WINDUP:
			return (phase_timer / windup_duration) * 0.5 if windup_duration > 0 else 0.5
		CastPhase.RELEASE:
			return 0.5 + (phase_timer / release_duration) * 0.3 if release_duration > 0 else 0.8
		CastPhase.RECOVERY:
			return 0.8 + (phase_timer / recovery_duration) * 0.2 if recovery_duration > 0 else 1.0
	return 0.0

## 获取当前阶段名称
func get_phase_name() -> String:
	match current_phase:
		CastPhase.WINDUP:
			return "蓄能"
		CastPhase.RELEASE:
			return "释放"
		CastPhase.RECOVERY:
			return "后摇"
	return "未知"
