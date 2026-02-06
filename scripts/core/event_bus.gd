class_name EventBus
extends Node

## 全局事件总线
## 实现模块间的解耦通信，替代分散的 signal 连接方式
## 使用方式：EventBus.instance.publish("event_name", data)
##           EventBus.instance.subscribe("event_name", callable)

static var instance: EventBus = null

## 事件订阅者注册表: { event_name: Array[Callable] }
var _subscribers: Dictionary = {}

## 事件历史记录（用于调试）
var _event_history: Array[Dictionary] = []

## 是否启用调试日志
var debug_logging: bool = false

## 历史记录最大条数
const MAX_HISTORY_SIZE: int = 100

func _ready() -> void:
	if instance == null:
		instance = self
	else:
		push_warning("[EventBus] 已存在实例，当前实例将被忽略")
		queue_free()
		return
	add_to_group("event_bus")

func _exit_tree() -> void:
	if instance == self:
		instance = null

## 订阅事件
## event_name: 事件名称
## callback: 回调函数，签名为 func(data: Dictionary) -> void
func subscribe(event_name: String, callback: Callable) -> void:
	if not _subscribers.has(event_name):
		_subscribers[event_name] = []
	
	# 防止重复订阅
	if callback not in _subscribers[event_name]:
		_subscribers[event_name].append(callback)
		if debug_logging:
			print("[EventBus] 订阅事件: %s (当前订阅者数: %d)" % [event_name, _subscribers[event_name].size()])

## 取消订阅事件
func unsubscribe(event_name: String, callback: Callable) -> void:
	if _subscribers.has(event_name):
		_subscribers[event_name].erase(callback)
		if debug_logging:
			print("[EventBus] 取消订阅: %s (剩余订阅者数: %d)" % [event_name, _subscribers[event_name].size()])

## 发布事件
## event_name: 事件名称
## data: 事件数据字典
func publish(event_name: String, data: Dictionary = {}) -> void:
	if debug_logging:
		print("[EventBus] 发布事件: %s, 数据: %s" % [event_name, str(data).substr(0, 100)])
	
	# 记录事件历史
	_record_event(event_name, data)
	
	if not _subscribers.has(event_name):
		return
	
	# 复制订阅者列表，防止在回调中修改列表导致迭代错误
	var subscribers_copy = _subscribers[event_name].duplicate()
	
	for callback in subscribers_copy:
		if callback.is_valid():
			callback.call(data)
		else:
			# 自动清理无效的回调
			_subscribers[event_name].erase(callback)

## 延迟发布事件（在下一帧处理）
func publish_deferred(event_name: String, data: Dictionary = {}) -> void:
	call_deferred("publish", event_name, data)

## 清除指定事件的所有订阅者
func clear_event(event_name: String) -> void:
	if _subscribers.has(event_name):
		_subscribers[event_name].clear()

## 清除所有订阅
func clear_all() -> void:
	_subscribers.clear()

## 获取指定事件的订阅者数量
func get_subscriber_count(event_name: String) -> int:
	if _subscribers.has(event_name):
		return _subscribers[event_name].size()
	return 0

## 获取所有已注册的事件名称
func get_registered_events() -> Array[String]:
	var events: Array[String] = []
	for key in _subscribers.keys():
		events.append(key)
	return events

## 记录事件历史
func _record_event(event_name: String, data: Dictionary) -> void:
	_event_history.append({
		"event": event_name,
		"time": Time.get_unix_time_from_system(),
		"data_keys": data.keys()
	})
	
	# 限制历史记录大小
	if _event_history.size() > MAX_HISTORY_SIZE:
		_event_history.pop_front()

## 获取事件历史（用于调试）
func get_event_history() -> Array[Dictionary]:
	return _event_history

## 获取统计信息
func get_stats() -> Dictionary:
	var total_subscribers = 0
	for event_name in _subscribers:
		total_subscribers += _subscribers[event_name].size()
	
	return {
		"registered_events": _subscribers.size(),
		"total_subscribers": total_subscribers,
		"history_size": _event_history.size()
	}

# ============================================================
# 预定义事件名称常量（避免字符串拼写错误）
# ============================================================

## 动作执行事件
const EVENT_EXECUTE_ACTION = "execute_action"

## 伤害事件
const EVENT_DAMAGE_DEALT = "damage_dealt"
const EVENT_DAMAGE_TAKEN = "damage_taken"

## 弹射物事件
const EVENT_PROJECTILE_SPAWNED = "projectile_spawned"
const EVENT_PROJECTILE_HIT = "projectile_hit"
const EVENT_PROJECTILE_DIED = "projectile_died"

## 法术事件
const EVENT_SPELL_CAST = "spell_cast"
const EVENT_SPELL_HIT = "spell_hit"

## 裂变事件
const EVENT_FISSION_TRIGGERED = "fission_triggered"

## 爆炸事件
const EVENT_EXPLOSION_REQUESTED = "explosion_requested"

## 伤害区域事件
const EVENT_DAMAGE_ZONE_REQUESTED = "damage_zone_requested"

## 状态效果事件
const EVENT_STATUS_APPLIED = "status_applied"
const EVENT_STATUS_REMOVED = "status_removed"

## 能量事件
const EVENT_ENERGY_RESTORED = "energy_restored"
const EVENT_ENERGY_CAP_RESTORED = "energy_cap_restored"

## 肢体事件
const EVENT_BODY_PART_DAMAGED = "body_part_damaged"
const EVENT_BODY_PART_DESTROYED = "body_part_destroyed"
const EVENT_BODY_PART_RESTORED = "body_part_restored"

## 链式效果事件
const EVENT_CHAIN_STARTED = "chain_started"
const EVENT_CHAIN_JUMPED = "chain_jumped"
const EVENT_CHAIN_ENDED = "chain_ended"

## 召唤事件
const EVENT_SUMMON_CREATED = "summon_created"
const EVENT_SUMMON_DIED = "summon_died"
