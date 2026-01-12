class_name MovementConfig extends Resource

@export_group("Ground Movement")
@export var max_speed_ground: float = 300.0
@export var acceleration_ground: float = 2000.0
@export var friction_ground: float = 3000.0

@export_group("Flight Movement")
@export var max_speed_flight: float = 500.0
@export var acceleration_flight: float = 800.0
@export var friction_flight: float = 200.0

@export_group("Directional Speed Modifiers")
@export var forward_speed_multiplier: float = 1.0
@export var strafe_speed_multiplier: float = 0.75
@export var backward_speed_multiplier: float = 0.5

@export_group("Rotation")
@export var base_turn_speed: float = 10.0
@export var standing_turn_bonus: float = 1.5
@export var perpendicular_turn_bonus: float = 1.2

@export_group("Turn Gating")
@export var attack_angle_threshold: float = 30.0
@export var spell_angle_threshold: float = 15.0

func get_directional_speed_modifier(face_direction: Vector2, move_direction: Vector2) -> float:
	if move_direction.length_squared() < 0.01:
		return 1.0

	var dot = face_direction.dot(move_direction)

	if dot >= 0:
		return lerpf(strafe_speed_multiplier, forward_speed_multiplier, dot)
	else:
		return lerpf(strafe_speed_multiplier, backward_speed_multiplier, -dot)

func get_turn_speed(is_standing: bool, face_direction: Vector2, move_direction: Vector2) -> float:
	var turn_speed = base_turn_speed

	if is_standing:
		turn_speed *= standing_turn_bonus

	if move_direction.length_squared() > 0.01:
		var dot = abs(face_direction.dot(move_direction))
		var perpendicular_factor = 1.0 - dot
		turn_speed *= lerpf(1.0, perpendicular_turn_bonus, perpendicular_factor)

	return turn_speed

func is_angle_valid_for_attack(current_angle: float, target_angle: float) -> bool:
	var angle_diff = abs(angle_difference(current_angle, target_angle))
	return rad_to_deg(angle_diff) <= attack_angle_threshold

func is_angle_valid_for_spell(current_angle: float, target_angle: float) -> bool:
	var angle_diff = abs(angle_difference(current_angle, target_angle))
	return rad_to_deg(angle_diff) <= spell_angle_threshold

static func create_default() -> MovementConfig:
	var config = MovementConfig.new()
	return config
