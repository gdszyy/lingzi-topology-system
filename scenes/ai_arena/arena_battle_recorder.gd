class_name ArenaBattleRecorder extends Node

## AI演武厂战斗记录器
## 记录战斗数据，用于分析和回放

signal recording_started()
signal recording_stopped()
signal event_recorded(event: Dictionary)

## 记录状态
var is_recording: bool = false
var recording_start_time: float = 0.0

## 战斗数据
var battle_events: Array[Dictionary] = []
var battle_summary: Dictionary = {}

## 统计数据
var stats = {
	"total_damage_dealt": 0.0,
	"total_damage_taken": 0.0,
	"enemies_killed": 0,
	"spells_cast": 0,
	"attacks_performed": 0,
	"dodges_performed": 0,
	"body_parts_destroyed": 0,
	"highest_combo": 0,
	"current_combo": 0,
	"wave_reached": 0,
	"time_elapsed": 0.0
}

## 开始记录
func start_recording() -> void:
	is_recording = true
	recording_start_time = Time.get_ticks_msec() / 1000.0
	battle_events.clear()
	_reset_stats()
	
	recording_started.emit()
	_record_event("recording_started", {})

## 停止记录
func stop_recording() -> void:
	is_recording = false
	stats.time_elapsed = Time.get_ticks_msec() / 1000.0 - recording_start_time
	
	_generate_summary()
	recording_stopped.emit()
	_record_event("recording_stopped", {"summary": battle_summary})

## 重置统计
func _reset_stats() -> void:
	stats = {
		"total_damage_dealt": 0.0,
		"total_damage_taken": 0.0,
		"enemies_killed": 0,
		"spells_cast": 0,
		"attacks_performed": 0,
		"dodges_performed": 0,
		"body_parts_destroyed": 0,
		"highest_combo": 0,
		"current_combo": 0,
		"wave_reached": 0,
		"time_elapsed": 0.0
	}

## 记录事件
func _record_event(event_type: String, data: Dictionary) -> void:
	if not is_recording:
		return
	
	var timestamp = Time.get_ticks_msec() / 1000.0 - recording_start_time
	
	var event = {
		"type": event_type,
		"timestamp": timestamp,
		"data": data
	}
	
	battle_events.append(event)
	event_recorded.emit(event)

## 记录伤害输出
func record_damage_dealt(amount: float, target: Node, source: Node, part_type: int = -1) -> void:
	stats.total_damage_dealt += amount
	stats.current_combo += 1
	
	if stats.current_combo > stats.highest_combo:
		stats.highest_combo = stats.current_combo
	
	_record_event("damage_dealt", {
		"amount": amount,
		"target": target.name if target else "unknown",
		"source": source.name if source else "unknown",
		"part_type": part_type,
		"combo": stats.current_combo
	})

## 记录伤害承受
func record_damage_taken(amount: float, source: Node, target: Node, part_type: int = -1) -> void:
	stats.total_damage_taken += amount
	stats.current_combo = 0  # 受伤打断连击
	
	_record_event("damage_taken", {
		"amount": amount,
		"source": source.name if source else "unknown",
		"target": target.name if target else "unknown",
		"part_type": part_type
	})

## 记录敌人击杀
func record_enemy_killed(enemy: Node, killer: Node) -> void:
	stats.enemies_killed += 1
	
	_record_event("enemy_killed", {
		"enemy": enemy.name if enemy else "unknown",
		"killer": killer.name if killer else "unknown",
		"total_kills": stats.enemies_killed
	})

## 记录法术施放
func record_spell_cast(spell_name: String, caster: Node) -> void:
	stats.spells_cast += 1
	
	_record_event("spell_cast", {
		"spell_name": spell_name,
		"caster": caster.name if caster else "unknown"
	})

## 记录攻击执行
func record_attack_performed(attacker: Node, attack_type: String) -> void:
	stats.attacks_performed += 1
	
	_record_event("attack_performed", {
		"attacker": attacker.name if attacker else "unknown",
		"attack_type": attack_type
	})

## 记录闪避
func record_dodge_performed(dodger: Node) -> void:
	stats.dodges_performed += 1
	
	_record_event("dodge_performed", {
		"dodger": dodger.name if dodger else "unknown"
	})

## 记录肢体摧毁
func record_body_part_destroyed(part_type: int, owner: Node) -> void:
	stats.body_parts_destroyed += 1
	
	_record_event("body_part_destroyed", {
		"part_type": part_type,
		"owner": owner.name if owner else "unknown"
	})

## 记录波次开始
func record_wave_started(wave_number: int) -> void:
	stats.wave_reached = wave_number
	
	_record_event("wave_started", {
		"wave_number": wave_number
	})

## 记录波次完成
func record_wave_completed(wave_number: int, enemies_killed: int) -> void:
	_record_event("wave_completed", {
		"wave_number": wave_number,
		"enemies_killed": enemies_killed
	})

## 生成战斗总结
func _generate_summary() -> void:
	battle_summary = {
		"duration": stats.time_elapsed,
		"total_damage_dealt": stats.total_damage_dealt,
		"total_damage_taken": stats.total_damage_taken,
		"enemies_killed": stats.enemies_killed,
		"spells_cast": stats.spells_cast,
		"attacks_performed": stats.attacks_performed,
		"dodges_performed": stats.dodges_performed,
		"body_parts_destroyed": stats.body_parts_destroyed,
		"highest_combo": stats.highest_combo,
		"wave_reached": stats.wave_reached,
		"dps": stats.total_damage_dealt / max(1.0, stats.time_elapsed),
		"damage_taken_per_second": stats.total_damage_taken / max(1.0, stats.time_elapsed),
		"kills_per_minute": stats.enemies_killed / max(1.0, stats.time_elapsed / 60.0),
		"event_count": battle_events.size()
	}

## 获取战斗总结
func get_summary() -> Dictionary:
	return battle_summary.duplicate()

## 获取统计数据
func get_stats() -> Dictionary:
	return stats.duplicate()

## 获取所有事件
func get_events() -> Array[Dictionary]:
	return battle_events.duplicate()

## 获取特定类型的事件
func get_events_by_type(event_type: String) -> Array[Dictionary]:
	var filtered: Array[Dictionary] = []
	for event in battle_events:
		if event.type == event_type:
			filtered.append(event)
	return filtered

## 导出为JSON
func export_to_json() -> String:
	var export_data = {
		"summary": battle_summary,
		"stats": stats,
		"events": battle_events
	}
	return JSON.stringify(export_data, "\t")

## 保存到文件
func save_to_file(file_path: String) -> bool:
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return false
	
	file.store_string(export_to_json())
	file.close()
	return true

## 获取格式化的总结文本
func get_formatted_summary() -> String:
	var text = "[b]战斗总结[/b]\n\n"
	text += "战斗时长: %.1f 秒\n" % stats.time_elapsed
	text += "到达波次: %d\n\n" % stats.wave_reached
	
	text += "[b]伤害统计[/b]\n"
	text += "总输出伤害: %.0f\n" % stats.total_damage_dealt
	text += "总承受伤害: %.0f\n" % stats.total_damage_taken
	text += "DPS: %.1f\n\n" % (stats.total_damage_dealt / max(1.0, stats.time_elapsed))
	
	text += "[b]战斗统计[/b]\n"
	text += "击杀敌人: %d\n" % stats.enemies_killed
	text += "施放法术: %d\n" % stats.spells_cast
	text += "执行攻击: %d\n" % stats.attacks_performed
	text += "闪避次数: %d\n" % stats.dodges_performed
	text += "最高连击: %d\n" % stats.highest_combo
	text += "摧毁肢体: %d\n" % stats.body_parts_destroyed
	
	return text
