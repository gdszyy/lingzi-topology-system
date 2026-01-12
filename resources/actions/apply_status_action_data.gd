# apply_status_action_data.gd
# 状态效果动作数据 - 基于灵子相变理论的状态效果系统
# 
# 灵子物理学基础：
# - 波态 (Wave): 概率云，通过共振捕获
# - 气态 (Gas): 低能高流动，渗透作用
# - 液态 (Fluid): 亚稳态高势能，吸热结晶
# - 固态 (Solid): 极低熵，强相互作用
# - 等离子 (Plasma): 高熵剧烈跃迁，熵增释放
class_name ApplyStatusActionData
extends ActionData

## 灵子相态类型 - 决定状态效果的物理本质
enum SpiritonPhase {
	WAVE,      # 波态 - 概率干扰、共振效果
	GAS,       # 气态 - 渗透、侵蚀效果
	FLUID,     # 液态 - 吸热结晶、冷脆化
	SOLID,     # 固态 - 结构锁死、束缚
	PLASMA     # 等离子态 - 熵增释放、燃烧
}

## 状态效果类型 - 基于灵子相变的效果分类
enum StatusType {
	# === 等离子态效果 (Plasma) - 熵增释放 ===
	ENTROPY_BURN,      # 熵燃 - 灵子等离子态持续释放热量，造成烧蚀伤害
	
	# === 液态效果 (Fluid) - 吸热结晶 ===
	CRYO_CRYSTAL,      # 冷脆化 - 液态灵子强制结晶，掠夺目标热量
	                   # 效果：冻结 + 防御力大幅下降（分子动能归零）
	                   # 克制：对高温目标（熵燃状态）伤害翻倍
	
	# === 固态效果 (Solid) - 结构锁死 ===
	STRUCTURE_LOCK,    # 结构锁 - 固态灵子锁死目标运动结构
	                   # 效果：无法移动，但可以攻击/施法
	
	# === 气态效果 (Gas) - 渗透侵蚀 ===
	SPIRITON_EROSION,  # 灵蚀 - 气态灵子渗透侵蚀，持续削弱
	                   # 效果：持续伤害 + 降低输出
	
	# === 波态效果 (Wave) - 概率干扰 ===
	PHASE_DISRUPTION,  # 相位紊乱 - 波态灵子干扰目标概率场
	                   # 效果：降低命中/闪避，行动不稳定
	
	RESONANCE_MARK,    # 共振标记 - 波态灵子共振锁定
	                   # 效果：受到额外伤害，被追踪
	
	# === 正面效果 (Buff) ===
	SPIRITON_SURGE,    # 灵潮 - 灵子浓度激增，增强输出
	PHASE_SHIFT,       # 相移 - 波态加速，增加移动速度
	SOLID_SHELL        # 固壳 - 固态灵子护甲，吸收伤害
}

## 状态效果分类
enum StatusCategory {
	DEBUFF,      # 负面效果
	BUFF,        # 正面效果
	NEUTRAL      # 中性效果（如标记）
}

@export var status_type: StatusType = StatusType.ENTROPY_BURN
@export var spiriton_phase: SpiritonPhase = SpiritonPhase.PLASMA  # 灵子相态
@export var duration: float = 3.0           # 持续时间
@export var tick_interval: float = 0.5      # 效果触发间隔
@export var effect_value: float = 5.0       # 效果数值（伤害/减速百分比等）
@export var stack_limit: int = 3            # 最大叠加层数
@export var refresh_on_apply: bool = true   # 重复施加时是否刷新持续时间
@export var spread_on_death: bool = false   # 目标死亡时是否传播给附近敌人
@export var spread_radius: float = 100.0    # 传播范围
@export var cleansable: bool = true         # 是否可被净化
@export var apply_to_self: bool = false      # 是否应用于自身

## 相态克制关系
# 等离子 -> 固态（熔化）
# 液态 -> 等离子（吸热克制高温）
# 固态 -> 气态（阻挡渗透）
# 气态 -> 波态（干扰共振）
# 波态 -> 液态（概率坍缩稳定）
@export var phase_counter_bonus: float = 1.5  # 相态克制时的效果加成

func _init():
	action_type = ActionType.APPLY_STATUS
	_sync_phase_from_status()

## 根据状态类型同步灵子相态
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

## 获取状态分类
func get_status_category() -> StatusCategory:
	match status_type:
		StatusType.SPIRITON_SURGE, StatusType.PHASE_SHIFT, StatusType.SOLID_SHELL:
			return StatusCategory.BUFF
		StatusType.RESONANCE_MARK:
			return StatusCategory.NEUTRAL
		_:
			return StatusCategory.DEBUFF

## 获取状态名称
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

## 获取状态描述
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

## 获取相态名称
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

## 检查是否克制目标相态
func is_counter_phase(target_phase: SpiritonPhase) -> bool:
	match spiriton_phase:
		SpiritonPhase.PLASMA:
			return target_phase == SpiritonPhase.SOLID  # 等离子克固态（熔化）
		SpiritonPhase.FLUID:
			return target_phase == SpiritonPhase.PLASMA  # 液态克等离子（吸热）
		SpiritonPhase.SOLID:
			return target_phase == SpiritonPhase.GAS  # 固态克气态（阻挡）
		SpiritonPhase.GAS:
			return target_phase == SpiritonPhase.WAVE  # 气态克波态（干扰）
		SpiritonPhase.WAVE:
			return target_phase == SpiritonPhase.FLUID  # 波态克液态（稳定）
	return false

## 计算对目标的实际效果值（考虑相态克制）
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

## ========== 兼容旧版状态类型的映射 ==========
## 用于将旧版状态类型转换为新版灵子相态状态
static func convert_legacy_status(legacy_type: int) -> StatusType:
	# 旧版枚举值映射
	match legacy_type:
		0:  # BURNING
			return StatusType.ENTROPY_BURN
		1:  # FROZEN
			return StatusType.CRYO_CRYSTAL
		2:  # POISONED
			return StatusType.SPIRITON_EROSION
		3:  # SLOWED
			return StatusType.STRUCTURE_LOCK
		4:  # STUNNED
			return StatusType.CRYO_CRYSTAL
		5:  # WEAKENED
			return StatusType.SPIRITON_EROSION
		6:  # ROOTED
			return StatusType.STRUCTURE_LOCK
		7:  # SILENCED
			return StatusType.PHASE_DISRUPTION
		8:  # MARKED
			return StatusType.RESONANCE_MARK
		9:  # BLINDED
			return StatusType.PHASE_DISRUPTION
		10: # CURSED
			return StatusType.SPIRITON_EROSION
		11: # EMPOWERED
			return StatusType.SPIRITON_SURGE
		12: # HASTED
			return StatusType.PHASE_SHIFT
		13: # SHIELDED
			return StatusType.SOLID_SHELL
	return StatusType.ENTROPY_BURN
