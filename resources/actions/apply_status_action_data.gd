class_name ApplyStatusActionData
extends ActionData

enum SpiritonPhase {
	WAVE,
	GAS,
	FLUID,
	SOLID,
	PLASMA
}

enum StatusType {
	ENTROPY_BURN,

	CRYO_CRYSTAL,

	STRUCTURE_LOCK,

	SPIRITON_EROSION,

	PHASE_DISRUPTION,

	RESONANCE_MARK,

	SPIRITON_SURGE,
	PHASE_SHIFT,
	SOLID_SHELL
}

enum StatusCategory {
	DEBUFF,
	BUFF,
	NEUTRAL
}

@export var status_type: StatusType = StatusType.ENTROPY_BURN
@export var spiriton_phase: SpiritonPhase = SpiritonPhase.PLASMA
@export var duration: float = 3.0
@export var tick_interval: float = 0.5
@export var effect_value: float = 5.0
@export var stack_limit: int = 3
@export var refresh_on_apply: bool = true
@export var spread_on_death: bool = false
@export var spread_radius: float = 100.0
@export var cleansable: bool = true
@export var apply_to_self: bool = false

@export var phase_counter_bonus: float = 1.5

func _init():
	action_type = ActionType.APPLY_STATUS
	_sync_phase_from_status()

func _sync_phase_from_status() -> void:
	match status_type:
		StatusType.ENTROPY_BURN:
			spiriton_phase = SpiritonPhase.PLASMA
		StatusType.CRYO_CRYSTAL:
			spiriton_phase = SpiritonPhase.FLUID
		StatusType.STRUCTURE_LOCK:
			spiriton_phase = SpiritonPhase.SOLID
		StatusType.SPIRITON_EROSION:
			spiriton_phase = SpiritonPhase.GAS
		StatusType.PHASE_DISRUPTION, StatusType.RESONANCE_MARK:
			spiriton_phase = SpiritonPhase.WAVE
		StatusType.SPIRITON_SURGE:
			spiriton_phase = SpiritonPhase.PLASMA
		StatusType.PHASE_SHIFT:
			spiriton_phase = SpiritonPhase.WAVE
		StatusType.SOLID_SHELL:
			spiriton_phase = SpiritonPhase.SOLID

func get_status_category() -> StatusCategory:
	match status_type:
		StatusType.SPIRITON_SURGE, StatusType.PHASE_SHIFT, StatusType.SOLID_SHELL:
			return StatusCategory.BUFF
		StatusType.RESONANCE_MARK:
			return StatusCategory.NEUTRAL
		_:
			return StatusCategory.DEBUFF

func get_status_name() -> String:
	match status_type:
		StatusType.ENTROPY_BURN:
			return "熵燃"
		StatusType.CRYO_CRYSTAL:
			return "冷脆化"
		StatusType.STRUCTURE_LOCK:
			return "结构锁"
		StatusType.SPIRITON_EROSION:
			return "灵蚀"
		StatusType.PHASE_DISRUPTION:
			return "相位紊乱"
		StatusType.RESONANCE_MARK:
			return "共振标记"
		StatusType.SPIRITON_SURGE:
			return "灵潮"
		StatusType.PHASE_SHIFT:
			return "相移"
		StatusType.SOLID_SHELL:
			return "固壳"
	return "未知状态"

func get_status_description() -> String:
	match status_type:
		StatusType.ENTROPY_BURN:
			return "等离子态灵子释放热量，造成持续烧蚀伤害"
		StatusType.CRYO_CRYSTAL:
			return "液态灵子强制结晶，掠夺热量，冻结并降低防御"
		StatusType.STRUCTURE_LOCK:
			return "固态灵子锁死运动结构，无法移动但可攻击"
		StatusType.SPIRITON_EROSION:
			return "气态灵子渗透侵蚀，持续伤害并降低输出"
		StatusType.PHASE_DISRUPTION:
			return "波态灵子干扰概率场，降低命中和闪避"
		StatusType.RESONANCE_MARK:
			return "波态灵子共振锁定，受到额外伤害"
		StatusType.SPIRITON_SURGE:
			return "灵子浓度激增，增强伤害输出"
		StatusType.PHASE_SHIFT:
			return "波态加速，增加移动速度"
		StatusType.SOLID_SHELL:
			return "固态灵子护甲，吸收伤害"
	return ""

func get_phase_name() -> String:
	match spiriton_phase:
		SpiritonPhase.WAVE:
			return "波态"
		SpiritonPhase.GAS:
			return "气态"
		SpiritonPhase.FLUID:
			return "液态"
		SpiritonPhase.SOLID:
			return "固态"
		SpiritonPhase.PLASMA:
			return "等离子态"
	return "未知相态"

func is_counter_phase(target_phase: SpiritonPhase) -> bool:
	match spiriton_phase:
		SpiritonPhase.PLASMA:
			return target_phase == SpiritonPhase.SOLID
		SpiritonPhase.FLUID:
			return target_phase == SpiritonPhase.PLASMA
		SpiritonPhase.SOLID:
			return target_phase == SpiritonPhase.GAS
		SpiritonPhase.GAS:
			return target_phase == SpiritonPhase.WAVE
		SpiritonPhase.WAVE:
			return target_phase == SpiritonPhase.FLUID
	return false

func calculate_effective_value(target_phase: SpiritonPhase) -> float:
	var base_value = effect_value
	if is_counter_phase(target_phase):
		base_value *= phase_counter_bonus
	return base_value

func clone_deep() -> ActionData:
	var copy = ApplyStatusActionData.new()
	copy.action_type = action_type
	copy.status_type = status_type
	copy.spiriton_phase = spiriton_phase
	copy.duration = duration
	copy.tick_interval = tick_interval
	copy.effect_value = effect_value
	copy.stack_limit = stack_limit
	copy.refresh_on_apply = refresh_on_apply
	copy.spread_on_death = spread_on_death
	copy.spread_radius = spread_radius
	copy.cleansable = cleansable
	copy.apply_to_self = apply_to_self
	copy.phase_counter_bonus = phase_counter_bonus
	return copy

func to_dict() -> Dictionary:
	var base = super.to_dict()
	base["status_type"] = status_type
	base["spiriton_phase"] = spiriton_phase
	base["duration"] = duration
	base["tick_interval"] = tick_interval
	base["effect_value"] = effect_value
	base["stack_limit"] = stack_limit
	base["refresh_on_apply"] = refresh_on_apply
	base["spread_on_death"] = spread_on_death
	base["spread_radius"] = spread_radius
	base["cleansable"] = cleansable
	base["apply_to_self"] = apply_to_self
	base["phase_counter_bonus"] = phase_counter_bonus
	return base

static func from_dict(data: Dictionary) -> ApplyStatusActionData:
	var action = ApplyStatusActionData.new()
	action.status_type = data.get("status_type", StatusType.ENTROPY_BURN)
	action.spiriton_phase = data.get("spiriton_phase", SpiritonPhase.PLASMA)
	action.duration = data.get("duration", 3.0)
	action.tick_interval = data.get("tick_interval", 0.5)
	action.effect_value = data.get("effect_value", 5.0)
	action.stack_limit = data.get("stack_limit", 3)
	action.refresh_on_apply = data.get("refresh_on_apply", true)
	action.spread_on_death = data.get("spread_on_death", false)
	action.spread_radius = data.get("spread_radius", 100.0)
	action.cleansable = data.get("cleansable", true)
	action.apply_to_self = data.get("apply_to_self", false)
	action.phase_counter_bonus = data.get("phase_counter_bonus", 1.5)
	return action

static func convert_legacy_status(legacy_type: int) -> StatusType:
	match legacy_type:
		0:
			return StatusType.ENTROPY_BURN
		1:
			return StatusType.CRYO_CRYSTAL
		2:
			return StatusType.SPIRITON_EROSION
		3:
			return StatusType.STRUCTURE_LOCK
		4:
			return StatusType.CRYO_CRYSTAL
		5:
			return StatusType.SPIRITON_EROSION
		6:
			return StatusType.STRUCTURE_LOCK
		7:
			return StatusType.PHASE_DISRUPTION
		8:
			return StatusType.RESONANCE_MARK
		9:
			return StatusType.PHASE_DISRUPTION
		10:
			return StatusType.SPIRITON_EROSION
		11:
			return StatusType.SPIRITON_SURGE
		12:
			return StatusType.PHASE_SHIFT
		13:
			return StatusType.SOLID_SHELL
	return StatusType.ENTROPY_BURN
