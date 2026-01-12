extends Area2D
class_name DummyEnemy

signal damage_taken(amount: float)

@export var move_speed: float = 100.0
@export var move_pattern: MovePattern = MovePattern.PATROL

enum MovePattern {
	PATROL,
	CIRCULAR,
	FIGURE_EIGHT,
	RANDOM_WALK,
	ORBIT
}

var move_time: float = 0.0
var start_position: Vector2
var patrol_direction: int = 1
var random_target: Vector2
var orbit_center: Vector2
var orbit_radius: float = 150.0
var orbit_speed: float = 1.5

var total_damage_received: float = 0.0
var hit_count: int = 0
var last_hit_time: float = 0.0

@onready var sprite: Polygon2D = $Visual
@onready var damage_label: Label = $DamageLabel

const NORMAL_COLOR = Color(0.2, 0.6, 0.8)
const HIT_COLOR = Color(0.8, 0.8, 0.2)

func _ready():
	add_to_group("enemies")
	add_to_group("dummy_enemies")
	start_position = global_position
	orbit_center = start_position
	random_target = start_position
	_update_damage_display()

func _physics_process(delta: float) -> void:
	move_time += delta
	_update_movement(delta)

func _update_movement(delta: float) -> void:
	if move_speed <= 0:
		return

	match move_pattern:
		MovePattern.PATROL:
			_move_patrol(delta)
		MovePattern.CIRCULAR:
			_move_circular(delta)
		MovePattern.FIGURE_EIGHT:
			_move_figure_eight(delta)
		MovePattern.RANDOM_WALK:
			_move_random_walk(delta)
		MovePattern.ORBIT:
			_move_orbit(delta)

func _move_patrol(delta: float) -> void:
	var patrol_distance = 200.0
	position.x += patrol_direction * move_speed * delta

	if abs(position.x - start_position.x) > patrol_distance:
		patrol_direction *= -1

func _move_circular(_delta: float) -> void:
	var radius = 100.0
	var angular_speed = move_speed / radius
	position.x = start_position.x + cos(move_time * angular_speed) * radius
	position.y = start_position.y + sin(move_time * angular_speed) * radius

func _move_figure_eight(_delta: float) -> void:
	var scale_x = 120.0
	var scale_y = 60.0
	var t = move_time * move_speed * 0.01
	position.x = start_position.x + sin(t) * scale_x
	position.y = start_position.y + sin(t * 2) * scale_y

func _move_random_walk(delta: float) -> void:
	var distance_to_target = position.distance_to(random_target)

	if distance_to_target < 10.0 or move_time > 3.0:
		var angle = randf() * TAU
		var distance = randf_range(100, 250)
		random_target = start_position + Vector2(cos(angle), sin(angle)) * distance
		move_time = 0.0

	var direction = (random_target - position).normalized()
	position += direction * move_speed * delta

	var max_distance = 300.0
	if position.distance_to(start_position) > max_distance:
		var to_center = (start_position - position).normalized()
		position += to_center * move_speed * delta * 2

func _move_orbit(_delta: float) -> void:
	var angle = move_time * orbit_speed
	position.x = orbit_center.x + cos(angle) * orbit_radius
	position.y = orbit_center.y + sin(angle) * orbit_radius

func set_orbit_center(center: Vector2, radius: float = 150.0) -> void:
	orbit_center = center
	orbit_radius = radius

func take_damage(amount: float, _damage_type: int = 0) -> void:
	total_damage_received += amount
	hit_count += 1
	last_hit_time = Time.get_unix_time_from_system()

	damage_taken.emit(amount)

	_flash_hit()

	_update_damage_display()

func _flash_hit() -> void:
	if sprite:
		sprite.color = HIT_COLOR
		var tween = create_tween()
		tween.tween_property(sprite, "color", NORMAL_COLOR, 0.15)

func _update_damage_display() -> void:
	if damage_label:
		damage_label.text = "伤害: %.0f\n命中: %d" % [total_damage_received, hit_count]

func reset_stats() -> void:
	total_damage_received = 0.0
	hit_count = 0
	_update_damage_display()

func get_stats() -> Dictionary:
	return {
		"total_damage": total_damage_received,
		"hit_count": hit_count,
		"avg_damage_per_hit": total_damage_received / hit_count if hit_count > 0 else 0.0,
		"position": global_position,
		"move_pattern": move_pattern
	}

func apply_status(_status_type: int, _duration: float, _value: float) -> void:
	pass
