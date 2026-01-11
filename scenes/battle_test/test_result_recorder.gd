# test_result_recorder.gd
# 测试结果记录器 - 记录和比较法术测试结果
class_name TestResultRecorder
extends RefCounted

## 单次测试结果
class TestResult:
	var spell_id: String
	var spell_name: String
	var scenario: String
	var timestamp: float
	
	# 效率指标
	var dps: float = 0.0
	var hit_rate: float = 0.0
	var damage_per_shot: float = 0.0
	
	# 总计数据
	var total_damage: float = 0.0
	var total_shots: int = 0
	var total_hits: int = 0
	var enemies_killed: int = 0
	var test_duration: float = 0.0
	var fissions_triggered: int = 0
	
	func to_dict() -> Dictionary:
		return {
			"spell_id": spell_id,
			"spell_name": spell_name,
			"scenario": scenario,
			"timestamp": timestamp,
			"dps": dps,
			"hit_rate": hit_rate,
			"damage_per_shot": damage_per_shot,
			"total_damage": total_damage,
			"total_shots": total_shots,
			"total_hits": total_hits,
			"enemies_killed": enemies_killed,
			"test_duration": test_duration,
			"fissions_triggered": fissions_triggered
		}
	
	static func from_dict(data: Dictionary) -> TestResult:
		var result = TestResult.new()
		result.spell_id = data.get("spell_id", "")
		result.spell_name = data.get("spell_name", "")
		result.scenario = data.get("scenario", "")
		result.timestamp = data.get("timestamp", 0.0)
		result.dps = data.get("dps", 0.0)
		result.hit_rate = data.get("hit_rate", 0.0)
		result.damage_per_shot = data.get("damage_per_shot", 0.0)
		result.total_damage = data.get("total_damage", 0.0)
		result.total_shots = data.get("total_shots", 0)
		result.total_hits = data.get("total_hits", 0)
		result.enemies_killed = data.get("enemies_killed", 0)
		result.test_duration = data.get("test_duration", 0.0)
		result.fissions_triggered = data.get("fissions_triggered", 0)
		return result

## 存储的测试结果
var results: Array[TestResult] = []

## 记录新结果
func record_result(spell: SpellCoreData, scenario: String, stats: Dictionary, 
				   total_damage: float, enemies_killed: int, duration: float) -> TestResult:
	var result = TestResult.new()
	result.spell_id = spell.spell_id
	result.spell_name = spell.spell_name
	result.scenario = scenario
	result.timestamp = Time.get_unix_time_from_system()
	
	result.total_damage = total_damage
	result.total_shots = stats.get("total_shots", 0)
	result.total_hits = stats.get("total_hits", 0)
	result.enemies_killed = enemies_killed
	result.test_duration = duration
	result.fissions_triggered = stats.get("fissions_triggered", 0)
	
	# 计算效率指标
	if duration > 0:
		result.dps = total_damage / duration
	if result.total_shots > 0:
		result.hit_rate = float(result.total_hits) / float(result.total_shots) * 100.0
		result.damage_per_shot = total_damage / float(result.total_shots)
	
	results.append(result)
	return result

## 获取法术的所有测试结果
func get_results_for_spell(spell_id: String) -> Array[TestResult]:
	var spell_results: Array[TestResult] = []
	for result in results:
		if result.spell_id == spell_id:
			spell_results.append(result)
	return spell_results

## 获取场景的所有测试结果
func get_results_for_scenario(scenario: String) -> Array[TestResult]:
	var scenario_results: Array[TestResult] = []
	for result in results:
		if result.scenario == scenario:
			scenario_results.append(result)
	return scenario_results

## 获取法术在特定场景的平均表现
func get_average_performance(spell_id: String, scenario: String) -> Dictionary:
	var matching_results: Array[TestResult] = []
	for result in results:
		if result.spell_id == spell_id and result.scenario == scenario:
			matching_results.append(result)
	
	if matching_results.is_empty():
		return {}
	
	var avg_dps = 0.0
	var avg_hit_rate = 0.0
	var avg_damage_per_shot = 0.0
	
	for result in matching_results:
		avg_dps += result.dps
		avg_hit_rate += result.hit_rate
		avg_damage_per_shot += result.damage_per_shot
	
	var count = float(matching_results.size())
	return {
		"avg_dps": avg_dps / count,
		"avg_hit_rate": avg_hit_rate / count,
		"avg_damage_per_shot": avg_damage_per_shot / count,
		"test_count": matching_results.size()
	}

## 比较两个法术的表现
func compare_spells(spell_id_a: String, spell_id_b: String, scenario: String) -> Dictionary:
	var perf_a = get_average_performance(spell_id_a, scenario)
	var perf_b = get_average_performance(spell_id_b, scenario)
	
	if perf_a.is_empty() or perf_b.is_empty():
		return {"error": "数据不足"}
	
	return {
		"spell_a": perf_a,
		"spell_b": perf_b,
		"dps_diff": perf_a.avg_dps - perf_b.avg_dps,
		"hit_rate_diff": perf_a.avg_hit_rate - perf_b.avg_hit_rate,
		"winner_dps": "A" if perf_a.avg_dps > perf_b.avg_dps else "B",
		"winner_hit_rate": "A" if perf_a.avg_hit_rate > perf_b.avg_hit_rate else "B"
	}

## 获取排行榜（按 DPS）
func get_leaderboard(scenario: String, top_n: int = 10) -> Array[Dictionary]:
	var spell_performances: Dictionary = {}
	
	for result in results:
		if result.scenario != scenario:
			continue
		
		if not spell_performances.has(result.spell_id):
			spell_performances[result.spell_id] = {
				"spell_id": result.spell_id,
				"spell_name": result.spell_name,
				"total_dps": 0.0,
				"count": 0
			}
		
		spell_performances[result.spell_id].total_dps += result.dps
		spell_performances[result.spell_id].count += 1
	
	# 计算平均并排序
	var leaderboard: Array[Dictionary] = []
	for spell_id in spell_performances:
		var perf = spell_performances[spell_id]
		leaderboard.append({
			"spell_id": perf.spell_id,
			"spell_name": perf.spell_name,
			"avg_dps": perf.total_dps / perf.count,
			"test_count": perf.count
		})
	
	leaderboard.sort_custom(func(a, b): return a.avg_dps > b.avg_dps)
	
	return leaderboard.slice(0, top_n)

## 保存到文件
func save_to_file(path: String) -> void:
	var data = []
	for result in results:
		data.append(result.to_dict())
	
	var json = JSON.stringify(data, "\t")
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(json)
		file.close()

## 从文件加载
func load_from_file(path: String) -> bool:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	
	var json = file.get_as_text()
	file.close()
	
	var data = JSON.parse_string(json)
	if data == null or not data is Array:
		return false
	
	results.clear()
	for item in data:
		results.append(TestResult.from_dict(item))
	
	return true

## 清除所有结果
func clear() -> void:
	results.clear()

## 生成报告
func generate_report() -> String:
	var report = "===== 法术测试报告 =====\n\n"
	report += "总测试次数: %d\n\n" % results.size()
	
	# 按场景统计
	var scenarios = ["SINGLE_TARGET", "GROUP_TARGETS", "MOVING_TARGETS", "SURVIVAL"]
	for scenario in scenarios:
		var scenario_results = get_results_for_scenario(scenario)
		if scenario_results.is_empty():
			continue
		
		report += "--- %s ---\n" % scenario
		var leaderboard = get_leaderboard(scenario, 5)
		for i in range(leaderboard.size()):
			var entry = leaderboard[i]
			report += "%d. %s - 平均DPS: %.1f (测试%d次)\n" % [
				i + 1, entry.spell_name, entry.avg_dps, entry.test_count
			]
		report += "\n"
	
	return report
