class_name VFXManager
extends Node
## 视觉特效管理器
## 统一管理所有灵子特效的创建、播放和回收

# 特效场景预加载
var _effect_scenes: Dictionary = {}
var _active_effects: Array[Node] = []
var _effect_pool: Dictionary = {}

# 相态颜色配置（基础版，保持向后兼容）
const PHASE_COLORS = {
	CarrierConfigData.Phase.SOLID: {
		"primary": Color(0.8, 0.5, 0.2, 1.0),      # 大地棕
		"secondary": Color(1.0, 0.9, 0.7, 1.0),    # 亮白能量
		"glow": Color(0.9, 0.6, 0.3, 0.8),         # 暖光晕
		"trail": Color(0.7, 0.4, 0.2, 0.5),        # 拖尾
	},
	CarrierConfigData.Phase.LIQUID: {
		"primary": Color(0.2, 0.4, 0.9, 0.9),      # 深蓝
		"secondary": Color(0.4, 0.9, 1.0, 1.0),    # 亮青
		"glow": Color(0.3, 0.6, 1.0, 0.7),         # 冷光晕
		"trail": Color(0.2, 0.5, 0.8, 0.4),        # 拖尾
	},
	CarrierConfigData.Phase.PLASMA: {
		"primary": Color(1.0, 0.3, 0.1, 1.0),      # 炽热橙红
		"secondary": Color(1.0, 1.0, 0.8, 1.0),    # 过曝白
		"glow": Color(1.0, 0.5, 0.2, 0.9),         # 火焰光晕
		"trail": Color(0.9, 0.2, 0.1, 0.6),        # 拖尾
	},
}

# 相态渐变色配置（多层渐变，用于投掷物）
const PHASE_GRADIENT_COLORS = {
	CarrierConfigData.Phase.SOLID: {
		"outer": Color(0.95, 0.6, 0.2, 0.15),       # 外层光晕：淡金色
		"middle": Color(0.9, 0.5, 0.15, 0.4),      # 中层：橙金色
		"inner": Color(1.0, 0.7, 0.3, 0.7),        # 内层：亮金色
		"core": Color(1.0, 0.95, 0.8, 1.0),        # 核心：近白金色
		"trail_start": Color(1.0, 0.7, 0.3, 0.8),  # 拖尾起点
		"trail_end": Color(0.95, 0.6, 0.2, 0.0),   # 拖尾终点
	},
	CarrierConfigData.Phase.LIQUID: {
		"outer": Color(0.2, 0.7, 0.95, 0.15),       # 外层光晕：淡青色
		"middle": Color(0.15, 0.6, 0.9, 0.4),      # 中层：天蓝色
		"inner": Color(0.3, 0.8, 1.0, 0.7),        # 内层：亮青色
		"core": Color(0.85, 0.95, 1.0, 1.0),       # 核心：近白青色
		"trail_start": Color(0.3, 0.8, 1.0, 0.8),  # 拖尾起点
		"trail_end": Color(0.2, 0.7, 0.95, 0.0),   # 拖尾终点
	},
	CarrierConfigData.Phase.PLASMA: {
		"outer": Color(0.9, 0.2, 0.7, 0.15),        # 外层光晕：淡紫红
		"middle": Color(0.85, 0.15, 0.6, 0.4),     # 中层：品红色
		"inner": Color(1.0, 0.4, 0.8, 0.7),        # 内层：亮粉紫
		"core": Color(1.0, 0.9, 0.95, 1.0),        # 核心：近白粉色
		"trail_start": Color(1.0, 0.4, 0.8, 0.8),  # 拖尾起点
		"trail_end": Color(0.9, 0.2, 0.7, 0.0),    # 拖尾终点
	},
}

# 扩展相态颜色（用于状态效果）
const SPIRITON_PHASE_COLORS = {
	ApplyStatusActionData.SpiritonPhase.WAVE: {
		"primary": Color(0.0, 1.0, 1.0, 0.8),      # 赛博青
		"secondary": Color(1.0, 0.0, 1.0, 0.9),    # 品红
		"glow": Color(0.5, 1.0, 1.0, 0.6),         # 全息光晕
		"trail": Color(0.0, 0.8, 0.8, 0.4),        # 拖尾
	},
	ApplyStatusActionData.SpiritonPhase.GAS: {
		"primary": Color(0.4, 0.8, 0.2, 0.7),      # 毒绿
		"secondary": Color(0.6, 0.6, 0.5, 0.8),    # 腐蚀灰
		"glow": Color(0.5, 0.9, 0.3, 0.5),         # 毒雾光晕
		"trail": Color(0.3, 0.7, 0.2, 0.3),        # 拖尾
	},
	ApplyStatusActionData.SpiritonPhase.FLUID: {
		"primary": Color(0.2, 0.4, 0.9, 0.9),      # 深蓝
		"secondary": Color(0.4, 0.9, 1.0, 1.0),    # 亮青
		"glow": Color(0.3, 0.6, 1.0, 0.7),         # 冷光晕
		"trail": Color(0.2, 0.5, 0.8, 0.4),        # 拖尾
	},
	ApplyStatusActionData.SpiritonPhase.SOLID: {
		"primary": Color(0.8, 0.5, 0.2, 1.0),      # 大地棕
		"secondary": Color(1.0, 0.9, 0.7, 1.0),    # 亮白能量
		"glow": Color(0.9, 0.6, 0.3, 0.8),         # 暖光晕
		"trail": Color(0.7, 0.4, 0.2, 0.5),        # 拖尾
	},
	ApplyStatusActionData.SpiritonPhase.PLASMA: {
		"primary": Color(1.0, 0.3, 0.1, 1.0),      # 炽热橙红
		"secondary": Color(1.0, 1.0, 0.8, 1.0),    # 过曝白
		"glow": Color(1.0, 0.5, 0.2, 0.9),         # 火焰光晕
		"trail": Color(0.9, 0.2, 0.1, 0.6),        # 拖尾
	},
}

# 状态效果渐变色（用于混合到投掷物）
const STATUS_GRADIENT_COLORS = {
	ApplyStatusActionData.SpiritonPhase.WAVE: {
		"blend": Color(0.0, 1.0, 1.0, 0.5),        # 混合色
		"accent": Color(1.0, 0.0, 1.0, 0.6),       # 强调色
	},
	ApplyStatusActionData.SpiritonPhase.GAS: {
		"blend": Color(0.4, 0.8, 0.2, 0.5),
		"accent": Color(0.6, 0.9, 0.3, 0.6),
	},
	ApplyStatusActionData.SpiritonPhase.FLUID: {
		"blend": Color(0.2, 0.6, 0.95, 0.5),
		"accent": Color(0.4, 0.9, 1.0, 0.6),
	},
	ApplyStatusActionData.SpiritonPhase.SOLID: {
		"blend": Color(0.8, 0.5, 0.2, 0.5),
		"accent": Color(1.0, 0.7, 0.3, 0.6),
	},
	ApplyStatusActionData.SpiritonPhase.PLASMA: {
		"blend": Color(1.0, 0.3, 0.1, 0.5),
		"accent": Color(1.0, 0.6, 0.2, 0.6),
	},
}

# 链式类型颜色
const CHAIN_TYPE_COLORS = {
	ChainActionData.ChainType.LIGHTNING: {
		"primary": Color(0.7, 0.9, 1.0, 1.0),      # 电光蓝白
		"secondary": Color(1.0, 1.0, 1.0, 1.0),    # 纯白
		"glow": Color(0.5, 0.8, 1.0, 0.8),
	},
	ChainActionData.ChainType.FIRE: {
		"primary": Color(1.0, 0.5, 0.1, 1.0),      # 火焰橙
		"secondary": Color(1.0, 0.9, 0.3, 1.0),    # 亮黄
		"glow": Color(1.0, 0.4, 0.1, 0.8),
	},
	ChainActionData.ChainType.ICE: {
		"primary": Color(0.6, 0.9, 1.0, 1.0),      # 冰蓝
		"secondary": Color(1.0, 1.0, 1.0, 1.0),    # 冰白
		"glow": Color(0.4, 0.8, 1.0, 0.7),
	},
	ChainActionData.ChainType.VOID: {
		"primary": Color(0.4, 0.1, 0.6, 1.0),      # 虚空紫
		"secondary": Color(0.8, 0.3, 1.0, 1.0),    # 亮紫
		"glow": Color(0.5, 0.2, 0.7, 0.8),
	},
}

func _ready() -> void:
	_preload_effect_scenes()

func _preload_effect_scenes() -> void:
	# 预加载所有特效场景
	var effect_paths = [
		"res://scenes/vfx/phase_projectile_vfx.tscn",
		"res://scenes/vfx/impact_vfx.tscn",
		"res://scenes/vfx/explosion_vfx.tscn",
		"res://scenes/vfx/fission_vfx.tscn",
		"res://scenes/vfx/damage_zone_vfx.tscn",
		"res://scenes/vfx/status_effect_vfx.tscn",
		"res://scenes/vfx/shield_vfx.tscn",
		"res://scenes/vfx/chain_vfx.tscn",
		"res://scenes/vfx/summon_vfx.tscn",
	]
	for path in effect_paths:
		if ResourceLoader.exists(path):
			_effect_scenes[path] = load(path)

## 获取相态颜色配置
func get_phase_colors(phase: CarrierConfigData.Phase) -> Dictionary:
	return PHASE_COLORS.get(phase, PHASE_COLORS[CarrierConfigData.Phase.SOLID])

## 获取相态渐变色配置
func get_phase_gradient_colors(phase: CarrierConfigData.Phase) -> Dictionary:
	return PHASE_GRADIENT_COLORS.get(phase, PHASE_GRADIENT_COLORS[CarrierConfigData.Phase.SOLID])

## 获取灵子相态颜色配置
func get_spiriton_phase_colors(phase: ApplyStatusActionData.SpiritonPhase) -> Dictionary:
	return SPIRITON_PHASE_COLORS.get(phase, SPIRITON_PHASE_COLORS[ApplyStatusActionData.SpiritonPhase.PLASMA])

## 获取状态效果渐变色配置
func get_status_gradient_colors(phase: ApplyStatusActionData.SpiritonPhase) -> Dictionary:
	return STATUS_GRADIENT_COLORS.get(phase, STATUS_GRADIENT_COLORS[ApplyStatusActionData.SpiritonPhase.PLASMA])

## 获取链式类型颜色配置
func get_chain_type_colors(chain_type: ChainActionData.ChainType) -> Dictionary:
	return CHAIN_TYPE_COLORS.get(chain_type, CHAIN_TYPE_COLORS[ChainActionData.ChainType.LIGHTNING])

## 创建拖尾渐变
static func create_trail_gradient(phase: CarrierConfigData.Phase, status_phase: int = -1) -> Gradient:
	var gradient = Gradient.new()
	var colors = PHASE_GRADIENT_COLORS.get(phase, PHASE_GRADIENT_COLORS[CarrierConfigData.Phase.SOLID])
	
	var start_color = colors.trail_start
	var end_color = colors.trail_end
	
	# 如果有状态效果，混合状态颜色
	if status_phase >= 0:
		var status_colors = STATUS_GRADIENT_COLORS.get(status_phase, {})
		if status_colors.has("blend"):
			start_color = start_color.lerp(status_colors.blend, 0.3)
	
	gradient.set_color(0, start_color)
	gradient.add_point(0.3, Color(colors.inner.r, colors.inner.g, colors.inner.b, 0.6))
	gradient.add_point(0.6, Color(colors.middle.r, colors.middle.g, colors.middle.b, 0.35))
	gradient.set_color(1, end_color)
	
	return gradient

## 创建特效实例
func spawn_effect(scene_path: String, position: Vector2, parent: Node = null) -> Node:
	var scene = _effect_scenes.get(scene_path)
	if scene == null:
		if ResourceLoader.exists(scene_path):
			scene = load(scene_path)
			_effect_scenes[scene_path] = scene
		else:
			push_warning("VFXManager: 特效场景不存在: " + scene_path)
			return null
	
	var effect = scene.instantiate()
	effect.global_position = position
	
	if parent:
		parent.add_child(effect)
	else:
		get_tree().current_scene.add_child(effect)
	
	_active_effects.append(effect)
	effect.tree_exited.connect(_on_effect_removed.bind(effect))
	
	return effect

## 清理已移除的特效
func _on_effect_removed(effect: Node) -> void:
	_active_effects.erase(effect)

## 清理所有活动特效
func clear_all_effects() -> void:
	for effect in _active_effects:
		if is_instance_valid(effect):
			effect.queue_free()
	_active_effects.clear()
