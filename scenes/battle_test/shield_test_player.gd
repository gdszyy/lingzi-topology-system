extends Node2D
class_name ShieldTestPlayer

## 护盾测试玩家
## 用于测试护盾系统的简化玩家实体

signal shield_changed(new_shield: float, old_shield: float)
signal took_damage(damage: float, source: Node2D)
signal health_changed(current: float, max_val: float)

## 基础属性
@export var max_health: float = 100.0
@export var current_health: float = 100.0

## 护盾系统
var current_shield: float = 0.0
var shield_duration: float = 0.0
var max_shield: float = 0.0

## 护盾特效引用
var shield_vfx: ShieldVFX = null

## 视觉组件
var visual: Polygon2D
var health_bar: ProgressBar
var shield_bar: ProgressBar
var shield_indicator: Node2D

func _ready() -> void:
	_setup_visuals()
	add_to_group("players")
	add_to_group("allies")

func _setup_visuals() -> void:
	# 玩家视觉
	visual = Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(20, 0),
		Vector2(-15, -12),
		Vector2(-8, 0),
		Vector2(-15, 12)
	])
	visual.color = Color(0.2, 0.8, 0.4, 1.0)
	add_child(visual)
	
	# 血条
	health_bar = ProgressBar.new()
	health_bar.position = Vector2(-25, -35)
	health_bar.size = Vector2(50, 8)
	health_bar.show_percentage = false
	health_bar.value = 100.0
	add_child(health_bar)
	
	# 护盾条
	shield_bar = ProgressBar.new()
	shield_bar.position = Vector2(-25, -45)
	shield_bar.size = Vector2(50, 6)
	shield_bar.show_percentage = false
	shield_bar.value = 0.0
	shield_bar.modulate = Color(0.3, 0.7, 1.0, 1.0)
	add_child(shield_bar)
	
	# 护盾指示器
	shield_indicator = Node2D.new()
	shield_indicator.visible = false
	add_child(shield_indicator)
	
	var shield_circle = Polygon2D.new()
	var points: PackedVector2Array = []
	var segments = 32
	for i in range(segments + 1):
		var angle = i * TAU / segments
		points.append(Vector2(cos(angle), sin(angle)) * 35.0)
	shield_circle.polygon = points
	shield_circle.color = Color(0.3, 0.7, 1.0, 0.3)
	shield_indicator.add_child(shield_circle)

func _process(delta: float) -> void:
	_update_shield(delta)
	_update_visuals()

func _update_shield(delta: float) -> void:
	if shield_duration > 0:
		shield_duration -= delta
		if shield_duration <= 0:
			var old_shield = current_shield
			current_shield = 0
			max_shield = 0
			shield_changed.emit(current_shield, old_shield)
			_remove_shield_vfx()

func _update_visuals() -> void:
	# 更新血条
	health_bar.value = (current_health / max_health) * 100.0
	
	# 更新护盾条
	if max_shield > 0:
		shield_bar.value = (current_shield / max_shield) * 100.0
		shield_bar.visible = true
	else:
		shield_bar.visible = false
	
	# 更新护盾指示器
	shield_indicator.visible = current_shield > 0

func take_damage(damage: float, source: Node2D = null) -> void:
	var actual_damage = damage
	var old_shield = current_shield
	
	# 护盾优先吸收伤害
	if current_shield > 0:
		var shield_absorb = min(current_shield, actual_damage)
		current_shield -= shield_absorb
		actual_damage -= shield_absorb
		
		# 护盾受击效果
		if shield_vfx and is_instance_valid(shield_vfx):
			shield_vfx.take_damage(shield_absorb)
		
		if current_shield <= 0:
			_remove_shield_vfx()
		
		shield_changed.emit(current_shield, old_shield)
	
	# 剩余伤害扣血
	if actual_damage > 0:
		current_health = max(0, current_health - actual_damage)
		health_changed.emit(current_health, max_health)
		_flash_damage()
	
	took_damage.emit(damage, source)

func apply_shield(amount: float, duration: float) -> void:
	var old_shield = current_shield
	
	# 更新护盾值
	if amount > current_shield:
		current_shield = amount
		max_shield = amount
	
	# 更新持续时间
	if duration > shield_duration:
		shield_duration = duration
	
	# 创建护盾特效
	_spawn_shield_vfx(ShieldActionData.ShieldType.PERSONAL, amount, duration)
	
	shield_changed.emit(current_shield, old_shield)

func _spawn_shield_vfx(shield_type: ShieldActionData.ShieldType, amount: float, duration: float) -> void:
	# 移除旧的护盾特效
	_remove_shield_vfx()
	
	# 创建新的护盾特效
	shield_vfx = VFXFactory.create_shield_vfx(shield_type, amount, duration, 40.0, self)
	if shield_vfx:
		get_tree().current_scene.add_child(shield_vfx)
		shield_vfx.shield_hit.connect(_on_shield_vfx_hit)
		shield_vfx.shield_broken.connect(_on_shield_vfx_broken)

func _remove_shield_vfx() -> void:
	if shield_vfx and is_instance_valid(shield_vfx):
		shield_vfx.stop()
		shield_vfx = null

func _on_shield_vfx_hit(_damage: float) -> void:
	pass

func _on_shield_vfx_broken() -> void:
	current_shield = 0
	max_shield = 0

func _flash_damage() -> void:
	if visual:
		var original_color = visual.color
		visual.color = Color(1.0, 0.5, 0.5, 1.0)
		var tween = create_tween()
		tween.tween_property(visual, "color", original_color, 0.2)

func heal(amount: float) -> float:
	var old_health = current_health
	current_health = min(max_health, current_health + amount)
	var healed = current_health - old_health
	health_changed.emit(current_health, max_health)
	return healed

func get_health_percent() -> float:
	return current_health / max_health if max_health > 0 else 0.0

func get_shield_percent() -> float:
	return current_shield / max_shield if max_shield > 0 else 0.0
