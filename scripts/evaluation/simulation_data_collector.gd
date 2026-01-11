# simulation_data_collector.gd
# 模拟数据收集器 - 在模拟过程中收集性能数据
class_name SimulationDataCollector
extends RefCounted

## 收集的数据
var total_damage_dealt: float = 0.0
var total_projectiles_fired: int = 0
var total_projectiles_hit: int = 0
var enemies_killed: int = 0
var total_enemies: int = 0
var overkill_damage: float = 0.0
var resource_consumed: float = 0.0
var simulation_time: float = 0.0
var time_to_kill: float = -1.0  # -1 表示未完成击杀
var damage_by_type: Dictionary = {}
var hits_over_time: Array[float] = []

## 重置数据
func reset() -> void:
	total_damage_dealt = 0.0
	total_projectiles_fired = 0
	total_projectiles_hit = 0
	enemies_killed = 0
	total_enemies = 0
	overkill_damage = 0.0
	resource_consumed = 0.0
	simulation_time = 0.0
	time_to_kill = -1.0
	damage_by_type.clear()
	hits_over_time.clear()

## 记录伤害
func record_damage(damage: float, damage_type: int, target_remaining_hp: float) -> void:
	total_damage_dealt += damage
	
	# 记录过量伤害
	if target_remaining_hp < 0:
		overkill_damage += absf(target_remaining_hp)
	
	# 按类型统计
	if not damage_by_type.has(damage_type):
		damage_by_type[damage_type] = 0.0
	damage_by_type[damage_type] += damage

## 记录发射
func record_projectile_fired() -> void:
	total_projectiles_fired += 1

## 记录命中
func record_projectile_hit() -> void:
	total_projectiles_hit += 1
	hits_over_time.append(simulation_time)

## 记录击杀
func record_kill(current_time: float) -> void:
	enemies_killed += 1
	if enemies_killed >= total_enemies and time_to_kill < 0:
		time_to_kill = current_time

## 记录资源消耗
func record_resource_consumed(amount: float) -> void:
	resource_consumed += amount

## 更新模拟时间
func update_time(delta: float) -> void:
	simulation_time += delta

## 设置敌人总数
func set_total_enemies(count: int) -> void:
	total_enemies = count

## 计算命中率
func get_accuracy() -> float:
	if total_projectiles_fired == 0:
		return 0.0
	return float(total_projectiles_hit) / float(total_projectiles_fired)

## 计算过量伤害率
func get_overkill_ratio() -> float:
	if total_damage_dealt == 0:
		return 0.0
	return overkill_damage / total_damage_dealt

## 计算DPS
func get_dps() -> float:
	if simulation_time == 0:
		return 0.0
	return total_damage_dealt / simulation_time

## 获取完整报告
func get_report() -> Dictionary:
	return {
		"total_damage": total_damage_dealt,
		"projectiles_fired": total_projectiles_fired,
		"projectiles_hit": total_projectiles_hit,
		"accuracy": get_accuracy(),
		"enemies_killed": enemies_killed,
		"total_enemies": total_enemies,
		"kill_rate": float(enemies_killed) / float(total_enemies) if total_enemies > 0 else 0.0,
		"overkill_damage": overkill_damage,
		"overkill_ratio": get_overkill_ratio(),
		"resource_consumed": resource_consumed,
		"simulation_time": simulation_time,
		"time_to_kill": time_to_kill,
		"dps": get_dps(),
		"damage_by_type": damage_by_type.duplicate()
	}

## 打印报告
func print_report() -> void:
	var report = get_report()
	print("=== 模拟报告 ===")
	print("总伤害: %.2f" % report.total_damage)
	print("DPS: %.2f" % report.dps)
	print("命中率: %.2f%%" % (report.accuracy * 100))
	print("击杀: %d/%d" % [report.enemies_killed, report.total_enemies])
	print("击杀时间: %.2fs" % report.time_to_kill if report.time_to_kill > 0 else "未完成")
	print("过量伤害率: %.2f%%" % (report.overkill_ratio * 100))
	print("资源消耗: %.2f" % report.resource_consumed)
	print("================")
