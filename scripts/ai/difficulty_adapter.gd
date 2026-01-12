class_name DifficultyAdapter extends Node

## 难度自适应系统
## 根据玩家表现动态调整游戏难度
## 确保游戏既有挑战性又不会过于挫败

signal difficulty_adjusted(new_multiplier: float, reason: String)
signal player_performance_updated(performance_score: float)

# 配置
@export var adaptive_enabled: bool = true
@export var adjustment_interval: float = 30.0  # 每30秒评估一次
@export var min_multiplier: float = 0.5
@export var max_multiplier: float = 2.0
@export var adjustment_step: float = 0.1

# 性能指标权重
@export_group("性能权重")
@export var damage_dealt_weight: float = 0.3
@export var damage_taken_weight: float = 0.25
@export var kill_rate_weight: float = 0.25
@export var survival_time_weight: float = 0.2

# 当前状态
var current_multiplier: float = 1.0
var performance_history: Array[float] = []
var max_history_size: int = 5

# 统计数据
var session_stats = {
	"damage_dealt": 0.0,
	"damage_taken": 0.0,
	"enemies_killed": 0,
	"deaths": 0,
	"waves_completed": 0,
	"time_played": 0.0,
	"last_evaluation_time": 0.0
}

# 期望值（用于比较）
var expected_values = {
	"dps": 50.0,           # 期望每秒伤害
	"damage_taken_rate": 20.0,  # 期望每秒承受伤害
	"kill_rate": 0.5,      # 期望每秒击杀
	"survival_time": 60.0  # 期望生存时间
}

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	if not adaptive_enabled:
		return
	
	session_stats.time_played += delta
	
	# 定期评估
	if session_stats.time_played - session_stats.last_evaluation_time >= adjustment_interval:
		_evaluate_and_adjust()
		session_stats.last_evaluation_time = session_stats.time_played

## 记录伤害输出
func record_damage_dealt(amount: float) -> void:
	session_stats.damage_dealt += amount

## 记录伤害承受
func record_damage_taken(amount: float) -> void:
	session_stats.damage_taken += amount

## 记录击杀
func record_kill() -> void:
	session_stats.enemies_killed += 1

## 记录死亡
func record_death() -> void:
	session_stats.deaths += 1

## 记录波次完成
func record_wave_completed() -> void:
	session_stats.waves_completed += 1

## 评估并调整难度
func _evaluate_and_adjust() -> void:
	var performance = _calculate_performance_score()
	performance_history.append(performance)
	
	# 保持历史记录在限制内
	while performance_history.size() > max_history_size:
		performance_history.pop_front()
	
	# 计算平均性能
	var avg_performance = 0.0
	for p in performance_history:
		avg_performance += p
	avg_performance /= performance_history.size()
	
	player_performance_updated.emit(avg_performance)
	
	# 根据性能调整难度
	var old_multiplier = current_multiplier
	var reason = ""
	
	if avg_performance > 0.7:
		# 玩家表现优秀，增加难度
		current_multiplier = min(current_multiplier + adjustment_step, max_multiplier)
		reason = "玩家表现优秀"
	elif avg_performance < 0.3:
		# 玩家表现不佳，降低难度
		current_multiplier = max(current_multiplier - adjustment_step, min_multiplier)
		reason = "玩家表现不佳"
	elif avg_performance < 0.4 and session_stats.deaths > 0:
		# 玩家死亡且表现较差
		current_multiplier = max(current_multiplier - adjustment_step * 1.5, min_multiplier)
		reason = "玩家死亡"
	
	if current_multiplier != old_multiplier:
		difficulty_adjusted.emit(current_multiplier, reason)

## 计算性能分数 (0-1)
func _calculate_performance_score() -> float:
	var time = max(1.0, session_stats.time_played)
	
	# 计算各项指标
	var dps = session_stats.damage_dealt / time
	var damage_taken_rate = session_stats.damage_taken / time
	var kill_rate = session_stats.enemies_killed / time
	var survival_factor = 1.0 if session_stats.deaths == 0 else 0.5
	
	# 归一化各项指标
	var dps_score = clamp(dps / expected_values.dps, 0.0, 2.0) / 2.0
	var damage_taken_score = 1.0 - clamp(damage_taken_rate / (expected_values.damage_taken_rate * 2), 0.0, 1.0)
	var kill_rate_score = clamp(kill_rate / expected_values.kill_rate, 0.0, 2.0) / 2.0
	var survival_score = survival_factor
	
	# 加权平均
	var total_weight = damage_dealt_weight + damage_taken_weight + kill_rate_weight + survival_time_weight
	var score = (
		dps_score * damage_dealt_weight +
		damage_taken_score * damage_taken_weight +
		kill_rate_score * kill_rate_weight +
		survival_score * survival_time_weight
	) / total_weight
	
	return clamp(score, 0.0, 1.0)

## 获取当前难度倍率
func get_difficulty_multiplier() -> float:
	return current_multiplier

## 获取敌人生命值倍率
func get_enemy_health_multiplier() -> float:
	return current_multiplier

## 获取敌人伤害倍率
func get_enemy_damage_multiplier() -> float:
	return current_multiplier * 0.8  # 伤害调整幅度稍小

## 获取敌人速度倍率
func get_enemy_speed_multiplier() -> float:
	return 1.0 + (current_multiplier - 1.0) * 0.3  # 速度调整幅度更小

## 获取敌人数量倍率
func get_enemy_count_multiplier() -> float:
	return current_multiplier

## 获取分数倍率
func get_score_multiplier() -> float:
	return current_multiplier * 1.5  # 高难度给更多分数

## 重置统计
func reset_stats() -> void:
	session_stats = {
		"damage_dealt": 0.0,
		"damage_taken": 0.0,
		"enemies_killed": 0,
		"deaths": 0,
		"waves_completed": 0,
		"time_played": 0.0,
		"last_evaluation_time": 0.0
	}
	performance_history.clear()
	current_multiplier = 1.0

## 手动设置难度倍率
func set_difficulty_multiplier(multiplier: float) -> void:
	current_multiplier = clamp(multiplier, min_multiplier, max_multiplier)
	difficulty_adjusted.emit(current_multiplier, "手动设置")

## 获取难度等级描述
func get_difficulty_description() -> String:
	if current_multiplier <= 0.6:
		return "非常简单"
	elif current_multiplier <= 0.8:
		return "简单"
	elif current_multiplier <= 1.2:
		return "普通"
	elif current_multiplier <= 1.5:
		return "困难"
	elif current_multiplier <= 1.8:
		return "非常困难"
	else:
		return "噩梦"

## 获取性能报告
func get_performance_report() -> Dictionary:
	var time = max(1.0, session_stats.time_played)
	
	return {
		"current_multiplier": current_multiplier,
		"difficulty_description": get_difficulty_description(),
		"dps": session_stats.damage_dealt / time,
		"damage_taken_rate": session_stats.damage_taken / time,
		"kill_rate": session_stats.enemies_killed / time,
		"deaths": session_stats.deaths,
		"waves_completed": session_stats.waves_completed,
		"time_played": session_stats.time_played,
		"performance_score": _calculate_performance_score(),
		"performance_history": performance_history.duplicate()
	}
