extends Area2D
class_name Explosion

signal explosion_hit(enemy: Node2D, damage: float)
signal explosion_finished(explosion: Explosion)

var damage: float = 50.0
var radius: float = 100.0
var damage_falloff: float = 0.5
var damage_type: int = 0
var duration: float = 0.3

@onready var visual: Polygon2D = $Visual
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var time_elapsed: float = 0.0
var has_dealt_damage: bool = false

func _ready():
	var shape = CircleShape2D.new()
	shape.radius = radius
	collision_shape.shape = shape

	_setup_visual()

func _process(delta: float) -> void:
	time_elapsed += delta

	if not has_dealt_damage:
		_deal_damage()
		has_dealt_damage = true

	_update_visual(delta)

	if time_elapsed >= duration:
		explosion_finished.emit(self)
		queue_free()

func initialize(pos: Vector2, dmg: float, rad: float, falloff: float = 0.5, dmg_type: int = 0) -> void:
	global_position = pos
	damage = dmg
	radius = rad
	damage_falloff = falloff
	damage_type = dmg_type

	if collision_shape and collision_shape.shape:
		(collision_shape.shape as CircleShape2D).radius = radius

func _setup_visual() -> void:
	if visual == null:
		return

	var points = PackedVector2Array()
	var segments = 32
	for i in range(segments):
		var angle = i * TAU / segments
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	visual.polygon = points

	var colors = [
		Color(1.0, 0.5, 0.0, 0.8),
		Color(0.5, 0.8, 1.0, 0.8),
		Color(0.8, 0.2, 0.8, 0.8),
		Color(0.5, 0.8, 0.2, 0.8)
	]
	visual.color = colors[damage_type % colors.size()]

func _update_visual(_delta: float) -> void:
	if visual == null:
		return

	var progress = time_elapsed / duration
	visual.modulate.a = 1.0 - progress

	var scale_factor = 1.0 + progress * 0.3
	visual.scale = Vector2(scale_factor, scale_factor)

func _deal_damage() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		var distance = global_position.distance_to(enemy.global_position)
		if distance <= radius:
			var distance_ratio = distance / radius
			var damage_multiplier = 1.0 - (distance_ratio * damage_falloff)
			var final_damage = damage * damage_multiplier

			if enemy.has_method("take_damage"):
				enemy.take_damage(final_damage, damage_type)
				explosion_hit.emit(enemy, final_damage)
