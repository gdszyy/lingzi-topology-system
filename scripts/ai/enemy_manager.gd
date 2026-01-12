class_name EnemyManager extends Node

## 敌人管理器
## 负责管理场景中的所有敌人
## 支持敌人生成、警报系统、团队协作

signal enemy_spawned(enemy: EnemyAIController)
signal enemy_died(enemy: EnemyAIController)
signal all_enemies_defeated()
signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)

## 敌人预制体
@export var enemy_prefabs: Array[PackedScene] = []

## 生成配置
@export var max_enemies: int = 10
@export var spawn_interval: float = 5.0
@export var auto_spawn: bool = false

## 当前状态
var active_enemies: Array[EnemyAIController] = []
var spawn_timer: float = 0.0
var total_spawned: int = 0
var total_killed: int = 0
var current_wave: int = 0

## 波次配置
var wave_configs: Array[Dictionary] = []
var current_wave_index: int = 0
var wave_in_progress: bool = false

func _ready() -> void:
	# 查找场景中已存在的敌人
	_find_existing_enemies()

func _process(delta: float) -> void:
	# 自动生成
	if auto_spawn and active_enemies.size() < max_enemies:
		spawn_timer += delta
		if spawn_timer >= spawn_interval:
			spawn_timer = 0.0
			spawn_random_enemy()
	
	# 清理无效敌人
	_cleanup_invalid_enemies()

## 查找场景中已存在的敌人
func _find_existing_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is EnemyAIController:
			_register_enemy(enemy)

## 注册敌人
func _register_enemy(enemy: EnemyAIController) -> void:
	if enemy not in active_enemies:
		active_enemies.append(enemy)
		enemy.enemy_died.connect(_on_enemy_died)

## 清理无效敌人
func _cleanup_invalid_enemies() -> void:
	var valid_enemies: Array[EnemyAIController] = []
	for enemy in active_enemies:
		if is_instance_valid(enemy):
			valid_enemies.append(enemy)
	active_enemies = valid_enemies

## 生成敌人
func spawn_enemy(prefab: PackedScene, position: Vector2, profile: AIBehaviorProfile = null) -> EnemyAIController:
	if prefab == null:
		return null
	
	if active_enemies.size() >= max_enemies:
		return null
	
	var enemy = prefab.instantiate() as EnemyAIController
	if enemy == null:
		return null
	
	enemy.global_position = position
	
	if profile != null:
		enemy.behavior_profile = profile
	
	# 添加到场景
	get_tree().current_scene.add_child(enemy)
	
	# 注册敌人
	_register_enemy(enemy)
	
	total_spawned += 1
	enemy_spawned.emit(enemy)
	
	return enemy

## 生成随机敌人
func spawn_random_enemy(position: Vector2 = Vector2.ZERO) -> EnemyAIController:
	if enemy_prefabs.is_empty():
		return null
	
	var prefab = enemy_prefabs[randi() % enemy_prefabs.size()]
	
	# 如果没有指定位置，使用随机位置
	if position == Vector2.ZERO:
		position = _get_random_spawn_position()
	
	return spawn_enemy(prefab, position)

## 获取随机生成位置
func _get_random_spawn_position() -> Vector2:
	# 默认在屏幕边缘生成
	var viewport_size = get_viewport().get_visible_rect().size
	var side = randi() % 4
	var pos: Vector2
	
	match side:
		0:  # 上
			pos = Vector2(randf_range(0, viewport_size.x), -50)
		1:  # 下
			pos = Vector2(randf_range(0, viewport_size.x), viewport_size.y + 50)
		2:  # 左
			pos = Vector2(-50, randf_range(0, viewport_size.y))
		3:  # 右
			pos = Vector2(viewport_size.x + 50, randf_range(0, viewport_size.y))
	
	return pos

## 敌人死亡回调
func _on_enemy_died(enemy: EnemyAIController) -> void:
	active_enemies.erase(enemy)
	total_killed += 1
	enemy_died.emit(enemy)
	
	# 检查波次是否完成
	if wave_in_progress and active_enemies.is_empty():
		_complete_wave()
	
	# 检查是否所有敌人都被击败
	if active_enemies.is_empty() and not auto_spawn:
		all_enemies_defeated.emit()

## 警报所有敌人
func alert_all_enemies(target: Node2D) -> void:
	for enemy in active_enemies:
		if is_instance_valid(enemy) and enemy.perception != null:
			enemy.perception.alert_to_target(target)

## 警报范围内的敌人
func alert_enemies_in_range(position: Vector2, radius: float, target: Node2D) -> void:
	for enemy in active_enemies:
		if not is_instance_valid(enemy):
			continue
		
		var distance = enemy.global_position.distance_to(position)
		if distance <= radius and enemy.perception != null:
			enemy.perception.alert_to_target(target)

## 获取最近的敌人
func get_nearest_enemy(position: Vector2) -> EnemyAIController:
	var nearest: EnemyAIController = null
	var min_distance: float = INF
	
	for enemy in active_enemies:
		if not is_instance_valid(enemy):
			continue
		
		var distance = enemy.global_position.distance_to(position)
		if distance < min_distance:
			min_distance = distance
			nearest = enemy
	
	return nearest

## 获取范围内的敌人
func get_enemies_in_range(position: Vector2, radius: float) -> Array[EnemyAIController]:
	var result: Array[EnemyAIController] = []
	
	for enemy in active_enemies:
		if not is_instance_valid(enemy):
			continue
		
		var distance = enemy.global_position.distance_to(position)
		if distance <= radius:
			result.append(enemy)
	
	return result

## 获取活跃敌人数量
func get_active_enemy_count() -> int:
	return active_enemies.size()

## 清除所有敌人
func clear_all_enemies() -> void:
	for enemy in active_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	active_enemies.clear()

## 开始波次
func start_wave(config: Dictionary) -> void:
	if wave_in_progress:
		return
	
	current_wave += 1
	wave_in_progress = true
	wave_started.emit(current_wave)
	
	# 解析波次配置
	var enemy_count = config.get("enemy_count", 5)
	var spawn_delay = config.get("spawn_delay", 1.0)
	var enemy_types = config.get("enemy_types", [0])
	
	# 生成敌人
	_spawn_wave_enemies(enemy_count, spawn_delay, enemy_types)

## 生成波次敌人
func _spawn_wave_enemies(count: int, delay: float, types: Array) -> void:
	for i in range(count):
		await get_tree().create_timer(delay).timeout
		
		if enemy_prefabs.is_empty():
			continue
		
		var type_index = types[i % types.size()] if not types.is_empty() else 0
		type_index = clamp(type_index, 0, enemy_prefabs.size() - 1)
		
		var prefab = enemy_prefabs[type_index]
		var position = _get_random_spawn_position()
		spawn_enemy(prefab, position)

## 完成波次
func _complete_wave() -> void:
	wave_in_progress = false
	wave_completed.emit(current_wave)

## 获取统计数据
func get_stats() -> Dictionary:
	return {
		"active_enemies": active_enemies.size(),
		"total_spawned": total_spawned,
		"total_killed": total_killed,
		"current_wave": current_wave
	}
