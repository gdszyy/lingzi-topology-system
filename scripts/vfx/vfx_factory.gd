class_name VFXFactory
extends RefCounted
## VFX工厂
## 提供统一的特效创建接口

# 特效场景路径
const SCENE_PATHS = {
	"projectile": "res://scenes/vfx/phase_projectile_vfx.tscn",
	"weapon_projectile": "res://scenes/vfx/weapon_engraved_projectile_vfx.tscn",
	"impact": "res://scenes/vfx/impact_vfx.tscn",
	"trail": "res://scenes/vfx/trail_vfx.tscn",
	"fission": "res://scenes/vfx/fission_vfx.tscn",
	"explosion": "res://scenes/vfx/explosion_vfx.tscn",
	"damage_zone": "res://scenes/vfx/damage_zone_vfx.tscn",
	"status_effect": "res://scenes/vfx/status_effect_vfx.tscn",
	"shield": "res://scenes/vfx/shield_vfx.tscn",
	"chain": "res://scenes/vfx/chain_vfx.tscn",
	"summon": "res://scenes/vfx/summon_vfx.tscn",
	"displacement": "res://scenes/vfx/displacement_vfx.tscn",
}

# 缓存的场景
static var _cached_scenes: Dictionary = {}

## 预加载所有特效场景
static func preload_all() -> void:
	for key in SCENE_PATHS:
		var path = SCENE_PATHS[key]
		if not _cached_scenes.has(path) and ResourceLoader.exists(path):
			_cached_scenes[path] = load(path)

## 获取场景
static func _get_scene(key: String) -> PackedScene:
	var path = SCENE_PATHS.get(key, "")
	if path.is_empty():
		push_warning("VFXFactory: 未知的特效类型: " + key)
		return null
	
	if not _cached_scenes.has(path):
		if ResourceLoader.exists(path):
			_cached_scenes[path] = load(path)
		else:
			push_warning("VFXFactory: 特效场景不存在: " + path)
			return null
	
	return _cached_scenes[path]

## 创建相态弹体特效（标准版，兼容旧代码）
static func create_projectile_vfx(phase: CarrierConfigData.Phase, size: float = 1.0, velocity: Vector2 = Vector2.ZERO) -> PhaseProjectileVFX:
	var scene = _get_scene("projectile")
	if scene == null:
		return null
	
	var vfx = scene.instantiate() as PhaseProjectileVFX
	vfx.initialize(phase, size, velocity)
	return vfx

## 创建相态弹体特效（增强版，支持完整法术数据）
static func create_projectile_vfx_enhanced(spell_data: SpellCoreData, nesting_level: int = 0, velocity: Vector2 = Vector2.ZERO) -> PhaseProjectileVFX:
	var scene = _get_scene("projectile")
	if scene == null:
		return null
	
	var vfx = scene.instantiate() as PhaseProjectileVFX
	vfx.initialize_enhanced(spell_data, nesting_level, velocity)
	return vfx

## 创建武器刻录投掷物特效
static func create_weapon_engraved_projectile_vfx(
	spell_data: SpellCoreData,
	weapon_type: int,
	trigger_type: int,
	nesting_level: int = 0,
	velocity: Vector2 = Vector2.ZERO,
	is_critical: bool = false
) -> WeaponEngravedProjectileVFX:
	var scene = _get_scene("weapon_projectile")
	if scene == null:
		# 如果场景不存在，动态创建
		var vfx = WeaponEngravedProjectileVFX.new()
		vfx.initialize_weapon_engraved(spell_data, weapon_type, trigger_type, nesting_level, velocity, is_critical)
		return vfx
	
	var vfx = scene.instantiate() as WeaponEngravedProjectileVFX
	vfx.initialize_weapon_engraved(spell_data, weapon_type, trigger_type, nesting_level, velocity, is_critical)
	return vfx

## 创建武器刻录投掷物特效（简化版，自动检测是否为刻录法术）
static func create_projectile_vfx_auto(
	spell_data: SpellCoreData,
	nesting_level: int = 0,
	velocity: Vector2 = Vector2.ZERO,
	context: Dictionary = {}
) -> Node2D:
	# 检查是否为武器刻录触发
	var is_engraved = context.get("is_engraved", false) or spell_data.is_engraved
	var weapon_type = context.get("weapon_type", 0)
	var trigger_type = context.get("trigger_type", 0)
	var is_critical = context.get("is_critical", false)
	
	# 判断是否使用武器刻录样式
	# 条件：是刻录法术 且 触发类型是武器相关的（ON_WEAPON_HIT 到 ON_CRITICAL_HIT）
	var is_weapon_trigger = trigger_type >= 17 and trigger_type <= 22  # TriggerData.TriggerType.ON_WEAPON_HIT 到 ON_CRITICAL_HIT
	
	if is_engraved and is_weapon_trigger:
		return create_weapon_engraved_projectile_vfx(
			spell_data, weapon_type, trigger_type, nesting_level, velocity, is_critical
		)
	else:
		return create_projectile_vfx_enhanced(spell_data, nesting_level, velocity)

## 创建命中特效
static func create_impact_vfx(phase: CarrierConfigData.Phase, scale: float = 1.0) -> ImpactVFX:
	var scene = _get_scene("impact")
	if scene == null:
		return null
	
	var vfx = scene.instantiate() as ImpactVFX
	vfx.initialize(phase, scale)
	return vfx

## 创建拖尾特效
static func create_trail_vfx(phase: CarrierConfigData.Phase, target: Node2D, width: float = 8.0) -> TrailVFX:
	var scene = _get_scene("trail")
	if scene == null:
		return null
	
	var vfx = scene.instantiate() as TrailVFX
	vfx.initialize(phase, target, width)
	return vfx

## 创建裂变特效
static func create_fission_vfx(phase: CarrierConfigData.Phase, spawn_count: int = 3, spread_angle: float = 360.0, scale: float = 1.0) -> FissionVFX:
	var scene = _get_scene("fission")
	if scene == null:
		return null
	
	var vfx = scene.instantiate() as FissionVFX
	vfx.initialize(phase, spawn_count, spread_angle, scale)
	return vfx

## 创建爆炸特效
static func create_explosion_vfx(phase: CarrierConfigData.Phase, radius: float = 100.0, falloff: float = 0.5) -> ExplosionVFX:
	var scene = _get_scene("explosion")
	if scene == null:
		return null
	
	var vfx = scene.instantiate() as ExplosionVFX
	vfx.initialize(phase, radius, falloff)
	return vfx

## 创建伤害区域特效
static func create_damage_zone_vfx(phase: CarrierConfigData.Phase, radius: float = 80.0, duration: float = 5.0, interval: float = 0.5) -> DamageZoneVFX:
	var scene = _get_scene("damage_zone")
	if scene == null:
		return null
	
	var vfx = scene.instantiate() as DamageZoneVFX
	vfx.initialize(phase, radius, duration, interval)
	return vfx

## 创建状态效果特效
static func create_status_effect_vfx(status_type: ApplyStatusActionData.StatusType, duration: float = 3.0, value: float = 5.0, target: Node2D = null) -> StatusEffectVFX:
	var scene = _get_scene("status_effect")
	if scene == null:
		return null
	
	var vfx = scene.instantiate() as StatusEffectVFX
	vfx.initialize(status_type, duration, value, target)
	return vfx

## 创建护盾特效
static func create_shield_vfx(shield_type: ShieldActionData.ShieldType, amount: float = 50.0, duration: float = 5.0, radius: float = 80.0, target: Node2D = null) -> ShieldVFX:
	var scene = _get_scene("shield")
	if scene == null:
		return null
	
	var vfx = scene.instantiate() as ShieldVFX
	vfx.initialize(shield_type, amount, duration, radius, target)
	return vfx

## 创建链式特效
static func create_chain_vfx(chain_type: ChainActionData.ChainType, targets: Array[Node2D], damage: float = 30.0, delay: float = 0.1) -> ChainVFX:
	var scene = _get_scene("chain")
	if scene == null:
		return null
	
	var vfx = scene.instantiate() as ChainVFX
	vfx.initialize(chain_type, targets, damage, delay)
	return vfx

## 创建召唤特效
static func create_summon_vfx(summon_type: SummonActionData.SummonType, count: int = 1) -> SummonVFX:
	var scene = _get_scene("summon")
	if scene == null:
		return null
	
	var vfx = scene.instantiate() as SummonVFX
	vfx.initialize(summon_type, count)
	return vfx

## 创建位移特效
static func create_displacement_vfx(displacement_type: DisplacementActionData.DisplacementType, from_pos: Vector2, to_pos: Vector2, force: float = 300.0) -> DisplacementVFX:
	var scene = _get_scene("displacement")
	if scene == null:
		return null
	
	var vfx = scene.instantiate() as DisplacementVFX
	vfx.initialize(displacement_type, from_pos, to_pos, force)
	return vfx

## 在指定位置创建并添加特效到场景树
static func spawn_at(vfx: Node2D, position: Vector2, parent: Node = null) -> Node2D:
	if vfx == null:
		return null
	
	vfx.global_position = position
	
	if parent:
		parent.add_child(vfx)
	elif Engine.get_main_loop():
		var tree = Engine.get_main_loop() as SceneTree
		if tree and tree.current_scene:
			tree.current_scene.add_child(vfx)
	
	return vfx
