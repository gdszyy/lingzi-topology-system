class_name TriggerData
extends Resource

enum TriggerType {
	ON_CONTACT,
	ON_TIMER,
	ON_PROXIMITY,
	ON_DEATH,
	ON_HEALTH_THRESHOLD,
	ON_ALLY_CONTACT,
	ON_STATUS_APPLIED,
	ON_CHAIN_END,
	ON_SHIELD_BREAK,
	ON_SUMMON_DEATH,
	ON_REFLECT,

	ON_WEAPON_HIT,
	ON_ATTACK_START,
	ON_ATTACK_ACTIVE,
	ON_ATTACK_END,
	ON_COMBO_HIT,
	ON_CRITICAL_HIT,

	ON_BLOCK_SUCCESS,
	ON_BLOCK_BREAK,
	ON_PARRY_SUCCESS,
	ON_DODGE_SUCCESS,

	ON_TAKE_DAMAGE,
	ON_DEAL_DAMAGE,
	ON_KILL_ENEMY,
	ON_HEALTH_LOW,
	ON_HEALTH_RECOVER,

	ON_FLY_START,
	ON_FLY_END,
	ON_MOVE_START,
	ON_MOVE_STOP,
	ON_DASH,

	ON_STATE_ENTER,
	ON_STATE_EXIT,
	ON_SPELL_CAST,
	ON_SPELL_HIT,

	ON_TICK,
	ON_INTERVAL,
}

@export var trigger_type: TriggerType = TriggerType.ON_CONTACT
@export var trigger_once: bool = true

func get_type_name() -> String:
	match trigger_type:
		TriggerType.ON_CONTACT:
			return "碰撞触发"
		TriggerType.ON_TIMER:
			return "定时触发"
		TriggerType.ON_PROXIMITY:
			return "接近触发"
		TriggerType.ON_DEATH:
			return "消亡触发"
		TriggerType.ON_HEALTH_THRESHOLD:
			return "生命阈值触发"
		TriggerType.ON_ALLY_CONTACT:
			return "友方触发"
		TriggerType.ON_STATUS_APPLIED:
			return "状态触发"
		TriggerType.ON_CHAIN_END:
			return "链式结束触发"
		TriggerType.ON_SHIELD_BREAK:
			return "护盾破碎触发"
		TriggerType.ON_SUMMON_DEATH:
			return "召唤物死亡触发"
		TriggerType.ON_REFLECT:
			return "反弹触发"

		TriggerType.ON_WEAPON_HIT:
			return "武器命中触发"
		TriggerType.ON_ATTACK_START:
			return "攻击开始触发"
		TriggerType.ON_ATTACK_ACTIVE:
			return "攻击判定触发"
		TriggerType.ON_ATTACK_END:
			return "攻击结束触发"
		TriggerType.ON_COMBO_HIT:
			return "连击命中触发"
		TriggerType.ON_CRITICAL_HIT:
			return "暴击触发"

		TriggerType.ON_BLOCK_SUCCESS:
			return "格挡成功触发"
		TriggerType.ON_BLOCK_BREAK:
			return "格挡破碎触发"
		TriggerType.ON_PARRY_SUCCESS:
			return "弹反成功触发"
		TriggerType.ON_DODGE_SUCCESS:
			return "闪避成功触发"

		TriggerType.ON_TAKE_DAMAGE:
			return "受到伤害触发"
		TriggerType.ON_DEAL_DAMAGE:
			return "造成伤害触发"
		TriggerType.ON_KILL_ENEMY:
			return "击杀敌人触发"
		TriggerType.ON_HEALTH_LOW:
			return "低生命触发"
		TriggerType.ON_HEALTH_RECOVER:
			return "生命恢复触发"

		TriggerType.ON_FLY_START:
			return "飞行开始触发"
		TriggerType.ON_FLY_END:
			return "飞行结束触发"
		TriggerType.ON_MOVE_START:
			return "移动开始触发"
		TriggerType.ON_MOVE_STOP:
			return "移动停止触发"
		TriggerType.ON_DASH:
			return "冲刺触发"

		TriggerType.ON_STATE_ENTER:
			return "状态进入触发"
		TriggerType.ON_STATE_EXIT:
			return "状态退出触发"
		TriggerType.ON_SPELL_CAST:
			return "施法触发"
		TriggerType.ON_SPELL_HIT:
			return "法术命中触发"

		TriggerType.ON_TICK:
			return "周期触发"
		TriggerType.ON_INTERVAL:
			return "间隔触发"

	return "未知触发器"

func get_category() -> String:
	match trigger_type:
		TriggerType.ON_CONTACT, TriggerType.ON_TIMER, TriggerType.ON_PROXIMITY, \
		TriggerType.ON_DEATH, TriggerType.ON_HEALTH_THRESHOLD, TriggerType.ON_ALLY_CONTACT, \
		TriggerType.ON_STATUS_APPLIED, TriggerType.ON_CHAIN_END, TriggerType.ON_SHIELD_BREAK, \
		TriggerType.ON_SUMMON_DEATH, TriggerType.ON_REFLECT:
			return "投射物"

		TriggerType.ON_WEAPON_HIT, TriggerType.ON_ATTACK_START, TriggerType.ON_ATTACK_ACTIVE, \
		TriggerType.ON_ATTACK_END, TriggerType.ON_COMBO_HIT, TriggerType.ON_CRITICAL_HIT:
			return "攻击"

		TriggerType.ON_BLOCK_SUCCESS, TriggerType.ON_BLOCK_BREAK, \
		TriggerType.ON_PARRY_SUCCESS, TriggerType.ON_DODGE_SUCCESS:
			return "防御"

		TriggerType.ON_TAKE_DAMAGE, TriggerType.ON_DEAL_DAMAGE, TriggerType.ON_KILL_ENEMY, \
		TriggerType.ON_HEALTH_LOW, TriggerType.ON_HEALTH_RECOVER:
			return "伤害"

		TriggerType.ON_FLY_START, TriggerType.ON_FLY_END, TriggerType.ON_MOVE_START, \
		TriggerType.ON_MOVE_STOP, TriggerType.ON_DASH:
			return "移动"

		TriggerType.ON_STATE_ENTER, TriggerType.ON_STATE_EXIT, \
		TriggerType.ON_SPELL_CAST, TriggerType.ON_SPELL_HIT:
			return "状态"

		TriggerType.ON_TICK, TriggerType.ON_INTERVAL:
			return "周期"

	return "其他"

func is_engraving_trigger() -> bool:
	return trigger_type >= TriggerType.ON_WEAPON_HIT

func clone_deep() -> TriggerData:
	var copy = TriggerData.new()
	copy.trigger_type = trigger_type
	copy.trigger_once = trigger_once
	return copy

func to_dict() -> Dictionary:
	return {
		"trigger_type": trigger_type,
		"trigger_once": trigger_once
	}

static func from_dict(data: Dictionary) -> TriggerData:
	var trigger_type_val = data.get("trigger_type", TriggerType.ON_CONTACT)
	var trigger: TriggerData

	match trigger_type_val:
		TriggerType.ON_TIMER:
			trigger = OnTimerTrigger.from_dict(data)
		TriggerType.ON_PROXIMITY:
			trigger = OnProximityTrigger.from_dict(data)
		TriggerType.ON_STATUS_APPLIED:
			trigger = OnStatusAppliedTrigger.from_dict(data)
		_:
			trigger = TriggerData.new()
			trigger.trigger_type = trigger_type_val
			trigger.trigger_once = data.get("trigger_once", true)

	return trigger

static func get_engraving_trigger_types() -> Array[TriggerType]:
	var types: Array[TriggerType] = []
	for i in range(TriggerType.ON_WEAPON_HIT, TriggerType.ON_INTERVAL + 1):
		types.append(i as TriggerType)
	return types
