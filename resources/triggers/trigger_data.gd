# trigger_data.gd
# 触发器数据基类 - 定义法术效果的触发条件
class_name TriggerData
extends Resource

## 触发器类型枚举
enum TriggerType {
	# === 投射物触发器 ===
	ON_CONTACT,          # 碰撞触发（敌方）
	ON_TIMER,            # 定时触发
	ON_PROXIMITY,        # 接近触发
	ON_DEATH,            # 死亡触发（载体消失时）
	ON_HEALTH_THRESHOLD, # 生命值阈值触发
	ON_ALLY_CONTACT,     # 友方单位触发
	ON_STATUS_APPLIED,   # 目标被施加特定状态时触发
	ON_CHAIN_END,        # 链式传导结束时触发
	ON_SHIELD_BREAK,     # 护盾破碎时触发
	ON_SUMMON_DEATH,     # 召唤物死亡时触发
	ON_REFLECT,          # 反弹发生时触发
	
	# === 刻录触发器 - 攻击相关 ===
	ON_WEAPON_HIT,       # 武器命中敌人时
	ON_ATTACK_START,     # 攻击动作开始时（进入前摇）
	ON_ATTACK_ACTIVE,    # 攻击判定开始时
	ON_ATTACK_END,       # 攻击动作结束时（进入后摇）
	ON_COMBO_HIT,        # 连击命中时
	ON_CRITICAL_HIT,     # 暴击时
	
	# === 刻录触发器 - 防御相关 ===
	ON_BLOCK_SUCCESS,    # 成功格挡时
	ON_BLOCK_BREAK,      # 格挡被破时
	ON_PARRY_SUCCESS,    # 成功弹反时
	ON_DODGE_SUCCESS,    # 成功闪避时
	
	# === 刻录触发器 - 伤害相关 ===
	ON_TAKE_DAMAGE,      # 受到伤害时
	ON_DEAL_DAMAGE,      # 造成伤害时（任何来源）
	ON_KILL_ENEMY,       # 击杀敌人时
	ON_HEALTH_LOW,       # 生命值低于阈值时
	ON_HEALTH_RECOVER,   # 生命值恢复时
	
	# === 刻录触发器 - 移动相关 ===
	ON_FLY_START,        # 开始飞行时
	ON_FLY_END,          # 结束飞行时
	ON_MOVE_START,       # 开始移动时
	ON_MOVE_STOP,        # 停止移动时
	ON_DASH,             # 冲刺时
	
	# === 刻录触发器 - 状态相关 ===
	ON_STATE_ENTER,      # 进入特定状态时
	ON_STATE_EXIT,       # 退出特定状态时
	ON_SPELL_CAST,       # 施放法术时
	ON_SPELL_HIT,        # 法术命中时
	
	# === 刻录触发器 - 周期性 ===
	ON_TICK,             # 周期性触发（每帧/每秒）
	ON_INTERVAL,         # 固定间隔触发
}

@export var trigger_type: TriggerType = TriggerType.ON_CONTACT
@export var trigger_once: bool = true  # 是否只触发一次

## 获取触发器类型名称
func get_type_name() -> String:
	match trigger_type:
		# 投射物触发器
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
		
		# 刻录触发器 - 攻击相关
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
		
		# 刻录触发器 - 防御相关
		TriggerType.ON_BLOCK_SUCCESS:
			return "格挡成功触发"
		TriggerType.ON_BLOCK_BREAK:
			return "格挡破碎触发"
		TriggerType.ON_PARRY_SUCCESS:
			return "弹反成功触发"
		TriggerType.ON_DODGE_SUCCESS:
			return "闪避成功触发"
		
		# 刻录触发器 - 伤害相关
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
		
		# 刻录触发器 - 移动相关
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
		
		# 刻录触发器 - 状态相关
		TriggerType.ON_STATE_ENTER:
			return "状态进入触发"
		TriggerType.ON_STATE_EXIT:
			return "状态退出触发"
		TriggerType.ON_SPELL_CAST:
			return "施法触发"
		TriggerType.ON_SPELL_HIT:
			return "法术命中触发"
		
		# 刻录触发器 - 周期性
		TriggerType.ON_TICK:
			return "周期触发"
		TriggerType.ON_INTERVAL:
			return "间隔触发"
	
	return "未知触发器"

## 获取触发器分类
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

## 检查是否为刻录触发器
func is_engraving_trigger() -> bool:
	return trigger_type >= TriggerType.ON_WEAPON_HIT

## 深拷贝（子类需要重写）
func clone_deep() -> TriggerData:
	var copy = TriggerData.new()
	copy.trigger_type = trigger_type
	copy.trigger_once = trigger_once
	return copy

## 转换为字典
func to_dict() -> Dictionary:
	return {
		"trigger_type": trigger_type,
		"trigger_once": trigger_once
	}

## 从字典加载
static func from_dict(data: Dictionary) -> TriggerData:
	var trigger_type_val = data.get("trigger_type", TriggerType.ON_CONTACT)
	var trigger: TriggerData
	
	# 根据类型创建具体的触发器
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

## 获取所有刻录触发器类型
static func get_engraving_trigger_types() -> Array[TriggerType]:
	var types: Array[TriggerType] = []
	for i in range(TriggerType.ON_WEAPON_HIT, TriggerType.ON_INTERVAL + 1):
		types.append(i as TriggerType)
	return types
