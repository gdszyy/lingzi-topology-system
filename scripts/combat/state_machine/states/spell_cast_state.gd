# spell_cast_state.gd
# 施法状态 - 角色施放法术的状态
extends State
class_name SpellCastState

## 玩家控制器引用
var player: PlayerController

## 施法目标位置
var target_position: Vector2 = Vector2.ZERO

## 施法计时器
var cast_timer: float = 0.0

## 施法时间（可根据法术配置）
var cast_duration: float = 0.3

## 是否已发射法术
var spell_fired: bool = false

## 子弹场景
var projectile_scene: PackedScene

func initialize(_owner: Node) -> void:
	super.initialize(_owner)
	player = _owner as PlayerController
	projectile_scene = preload("res://scenes/battle_test/entities/projectile.tscn")

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
	
	cast_timer = 0.0
	spell_fired = false
	
	# 播放施法动画
	_play_cast_animation()

func exit() -> void:
	cast_timer = 0.0
	spell_fired = false
	player.is_casting = false

func physics_update(delta: float) -> void:
	cast_timer += delta
	
	# 在施法中点发射法术
	if not spell_fired and cast_timer >= cast_duration * 0.5:
		_fire_spell()
		spell_fired = true
	
	# 施法完成
	if cast_timer >= cast_duration:
		_on_cast_complete()

## 发射法术
func _fire_spell() -> void:
	if player.current_spell == null:
		return
	
	# 计算方向
	var direction = (target_position - player.global_position).normalized()
	
	# 创建法术实体
	var projectile = _spawn_projectile(player.current_spell, direction)
	
	if projectile != null:
		# 设置追踪目标（如果法术有追踪能力）
		if player.current_spell.carrier != null and player.current_spell.carrier.homing_strength > 0:
			var nearest = _find_nearest_enemy(player.global_position)
			if nearest != null:
				projectile.set_target(nearest)
		
		# 更新统计
		player.stats.spells_cast += 1
		
		# 发送信号
		player.spell_cast.emit(player.current_spell)

## 生成法术实体
func _spawn_projectile(spell: SpellCoreData, direction: Vector2) -> Projectile:
	var projectile = projectile_scene.instantiate() as Projectile
	if projectile == null:
		return null
	
	player.get_tree().current_scene.add_child(projectile)
	projectile.initialize(spell, direction, player.global_position)
	
	# 连接信号
	projectile.hit_enemy.connect(_on_projectile_hit)
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

## 播放施法动画
func _play_cast_animation() -> void:
	# TODO: 播放实际动画
	pass

## 法术命中回调
func _on_projectile_hit(_enemy: Node2D, damage: float) -> void:
	player.stats.total_damage_dealt += damage
	player.stats.total_hits += 1

## 法术消失回调
func _on_projectile_died(_projectile: Projectile) -> void:
	pass
