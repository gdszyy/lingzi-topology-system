extends Area2D
class_name AttackingEnemy

## 攻击型敌人
## 会主动攻击玩家，用于测试护盾系统

signal enemy_died(enemy: AttackingEnemy)
signal damage_taken(amount: float)
signal attack_performed(damage: float)

## 能量系统配置
@export var energy_system: EnergySystemData

## 移动配置
@export var move_speed: float = 100.0
@export var attack_range: float = 150.0
@export var attack_damage: float = 10.0
@export var attack_cooldown: float = 1.5

var target_position: Vector2 = Vector2.ZERO
var attack_timer: float = 0.0
var can_attack: bool = true

@onready var health_bar: ProgressBar = $HealthBar
@onready var sprite: Polygon2D = $Visual
@onready var attack_indicator: Node2D = $AttackIndicator

const NORMAL_COLOR = Color(0.8, 0.3, 0.3)
const ATTACKING_COLOR = Color(1.0, 0.5, 0.0)
const DAMAGED_COLOR = Color(1.0, 0.7, 0.7)

func _ready():
	add_to_group("enemies")
	
	# 初始化能量系统
	if energy_system == null:
		energy_system = EnergySystemData.create_enemy_default(80.0)
	
	# 连接能量系统信号
	energy_system.energy_cap_changed.connect(_on_energy_cap_changed)
	energy_system.depleted.connect(_on_energy_depleted)
	
	_update_health_bar()
	
	# 创建攻击指示器
	if attack_indicator == null:
		attack_indicator = Node2D.new()
		attack_indicator.name = "AttackIndicator"
		add_child(attack_indicator)
	_setup_attack_indicator()

func _setup_attack_indicator() -> void:
	# 创建攻击范围指示器
	var range_circle = Polygon2D.new()
	var points: PackedVector2Array = []
	var segments = 32
	
	for i in range(segments + 1):
		var angle = i * TAU / segments
		points.append(Vector2(cos(angle), sin(angle)) * attack_range)
	
	range_circle.polygon = points
	range_circle.color = Color(1.0, 0.3, 0.3, 0.1)
	range_circle.name = "RangeCircle"
	attack_indicator.add_child(range_circle)

func _physics_process(delta: float) -> void:
	_update_movement(delta)
	_update_attack(delta)
	
	# 能量系统更新
	if energy_system:
		energy_system.absorb_from_environment(delta)

func set_target_position(pos: Vector2) -> void:
	target_position = pos

func set_max_energy_cap(value: float) -> void:
	if energy_system:
		energy_system.max_energy_cap = value
		energy_system.current_energy_cap = value
		energy_system.current_energy = value * 0.5
		_update_health_bar()

func _update_movement(delta: float) -> void:
	if move_speed <= 0:
		return
	
	var distance = global_position.distance_to(target_position)
	
	# 保持在攻击范围边缘
	var desired_distance = attack_range * 0.8
	
	if distance > desired_distance:
		var direction = (target_position - global_position).normalized()
		global_position += direction * move_speed * delta
	elif distance < desired_distance * 0.5:
		# 太近了，后退
		var direction = (global_position - target_position).normalized()
		global_position += direction * move_speed * 0.5 * delta

func _update_attack(delta: float) -> void:
	if not can_attack:
		attack_timer -= delta
		if attack_timer <= 0:
			can_attack = true
			sprite.color = NORMAL_COLOR
		return
	
	var distance = global_position.distance_to(target_position)
	
	if distance <= attack_range:
		_perform_attack()

func _perform_attack() -> void:
	can_attack = false
	attack_timer = attack_cooldown
	
	# 视觉反馈
	sprite.color = ATTACKING_COLOR
	_play_attack_animation()
	
	# 查找玩家并造成伤害
	var players = get_tree().get_nodes_in_group("players")
	for player in players:
		if player.has_method("take_damage"):
			player.take_damage(attack_damage, self)
			attack_performed.emit(attack_damage)
			break

func _play_attack_animation() -> void:
	# 攻击动画 - 向目标方向冲刺
	var direction = (target_position - global_position).normalized()
	var original_pos = global_position
	
	var tween = create_tween()
	tween.tween_property(self, "global_position", global_position + direction * 20.0, 0.1)
	tween.tween_property(self, "global_position", original_pos, 0.2)
	
	# 攻击波纹效果
	_spawn_attack_wave()

func _spawn_attack_wave() -> void:
	var wave = Polygon2D.new()
	var points: PackedVector2Array = []
	var segments = 24
	
	for i in range(segments + 1):
		var angle = i * TAU / segments
		points.append(Vector2(cos(angle), sin(angle)) * 10.0)
	
	wave.polygon = points
	wave.color = Color(1.0, 0.5, 0.0, 0.5)
	wave.global_position = global_position
	get_tree().current_scene.add_child(wave)
	
	var tween = create_tween()
	tween.tween_property(wave, "scale", Vector2.ONE * (attack_range / 10.0), 0.3)
	tween.parallel().tween_property(wave, "modulate:a", 0.0, 0.3)
	tween.tween_callback(wave.queue_free)

func take_damage(amount: float, _damage_type: int = 0) -> void:
	if energy_system:
		energy_system.take_damage(amount)
	
	damage_taken.emit(amount)
	_flash_damage()

func _flash_damage() -> void:
	if sprite:
		sprite.color = DAMAGED_COLOR
		var tween = create_tween()
		tween.tween_property(sprite, "color", NORMAL_COLOR, 0.2)

func _update_health_bar() -> void:
	if health_bar and energy_system:
		health_bar.value = energy_system.get_cap_percent() * 100.0

func _on_energy_cap_changed(_current_cap: float, _max_cap: float) -> void:
	_update_health_bar()

func _on_energy_depleted() -> void:
	_die()

func _die() -> void:
	enemy_died.emit(self)
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	call_deferred("queue_free")

func apply_knockback(knockback: Vector2) -> void:
	global_position += knockback * 0.1

func get_health_percent() -> float:
	if energy_system:
		return energy_system.get_cap_percent()
	return 0.0
