class_name TrailVFX
extends Line2D
## 拖尾特效
## 根据灵子相态显示不同风格的拖尾效果

@export var phase: CarrierConfigData.Phase = CarrierConfigData.Phase.SOLID
@export var max_points: int = 20
@export var trail_width: float = 8.0
@export var fade_speed: float = 2.0

var _target: Node2D = null
var _colors: Dictionary = {}
var _point_ages: Array[float] = []

# 相态特有参数
var _wobble_amount: float = 0.0
var _glow_intensity: float = 0.0

func _ready() -> void:
	_setup_trail()

func initialize(p_phase: CarrierConfigData.Phase, target: Node2D, p_width: float = 8.0) -> void:
	phase = p_phase
	_target = target
	trail_width = p_width
	_setup_trail()

func _setup_trail() -> void:
	_colors = VFXManager.PHASE_COLORS.get(phase, VFXManager.PHASE_COLORS[CarrierConfigData.Phase.SOLID])
	
	# 基础设置
	width = trail_width
	default_color = _colors.trail
	
	# 根据相态设置特有参数
	match phase:
		CarrierConfigData.Phase.SOLID:
			_setup_solid_trail()
		CarrierConfigData.Phase.LIQUID:
			_setup_liquid_trail()
		CarrierConfigData.Phase.PLASMA:
			_setup_plasma_trail()
	
	# 设置渐变
	_setup_gradient()

func _setup_solid_trail() -> void:
	_wobble_amount = 0.0
	_glow_intensity = 0.3
	max_points = 15
	fade_speed = 3.0

func _setup_liquid_trail() -> void:
	_wobble_amount = 3.0
	_glow_intensity = 0.5
	max_points = 25
	fade_speed = 2.0

func _setup_plasma_trail() -> void:
	_wobble_amount = 5.0
	_glow_intensity = 0.8
	max_points = 30
	fade_speed = 4.0

func _setup_gradient() -> void:
	var gradient = Gradient.new()
	gradient.set_color(0, _colors.trail)
	
	var end_color = _colors.trail
	end_color.a = 0.0
	gradient.set_color(1, end_color)
	
	self.gradient = gradient
	
	# 宽度曲线
	var width_curve = Curve.new()
	width_curve.add_point(Vector2(0, 1.0))
	width_curve.add_point(Vector2(0.5, 0.6))
	width_curve.add_point(Vector2(1.0, 0.0))
	self.width_curve = width_curve

func _process(delta: float) -> void:
	if _target and is_instance_valid(_target):
		_update_trail(delta)
	else:
		_fade_out(delta)

func _update_trail(delta: float) -> void:
	# 添加新点
	var new_point = _target.global_position
	
	# 相态特有的点位处理
	if _wobble_amount > 0:
		new_point += Vector2(
			randf_range(-_wobble_amount, _wobble_amount),
			randf_range(-_wobble_amount, _wobble_amount)
		)
	
	# 转换为本地坐标
	if get_parent():
		new_point = to_local(new_point)
	
	# 插入新点
	add_point(new_point, 0)
	_point_ages.insert(0, 0.0)
	
	# 更新点的年龄并移除过老的点
	var i = _point_ages.size() - 1
	while i >= 0:
		_point_ages[i] += delta * fade_speed
		if _point_ages[i] > 1.0 or get_point_count() > max_points:
			if i < get_point_count():
				remove_point(i)
			if i < _point_ages.size():
				_point_ages.remove_at(i)
		i -= 1

func _fade_out(delta: float) -> void:
	# 目标消失后，逐渐淡出所有点
	var i = _point_ages.size() - 1
	while i >= 0:
		_point_ages[i] += delta * fade_speed * 2.0
		if _point_ages[i] > 1.0:
			if i < get_point_count():
				remove_point(i)
			if i < _point_ages.size():
				_point_ages.remove_at(i)
		i -= 1
	
	# 所有点消失后销毁
	if get_point_count() == 0:
		queue_free()

func stop() -> void:
	_target = null
