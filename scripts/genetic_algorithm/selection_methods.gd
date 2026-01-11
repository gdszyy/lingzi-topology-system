# selection_methods.gd
# 选择方法 - 实现各种选择策略
class_name SelectionMethods
extends RefCounted

## 选择方法枚举
enum Method {
	ROULETTE_WHEEL,    # 轮盘赌选择
	TOURNAMENT,        # 锦标赛选择
	RANK_BASED,        # 排名选择
	ELITISM            # 精英选择
}

## 配置
var config = {
	"tournament_size": 3,      # 锦标赛大小
	"elitism_count": 2,        # 精英保留数量
	"selection_pressure": 1.5  # 选择压力（用于排名选择）
}

# ==================== 轮盘赌选择 ====================

## 轮盘赌选择 - 根据适应度比例选择
func roulette_wheel_selection(population: Array, fitness_scores: Array[float], count: int) -> Array:
	var selected = []
	
	# 处理负适应度：将所有适应度偏移为正数
	var min_fitness = fitness_scores.min()
	var adjusted_scores = []
	for score in fitness_scores:
		adjusted_scores.append(score - min_fitness + 0.001)  # 避免零值
	
	# 计算总适应度
	var total_fitness = 0.0
	for score in adjusted_scores:
		total_fitness += score
	
	# 选择
	for i in range(count):
		var pick = randf() * total_fitness
		var current = 0.0
		
		for j in range(population.size()):
			current += adjusted_scores[j]
			if current >= pick:
				selected.append(population[j])
				break
		
		# 如果没有选中任何个体（浮点误差），选择最后一个
		if selected.size() <= i:
			selected.append(population[population.size() - 1])
	
	return selected

# ==================== 锦标赛选择 ====================

## 锦标赛选择 - 随机选择k个个体，取最优者
func tournament_selection(population: Array, fitness_scores: Array[float], count: int) -> Array:
	var selected = []
	var tournament_size = mini(config.tournament_size, population.size())
	
	for i in range(count):
		var tournament_indices = []
		
		# 随机选择参赛者
		while tournament_indices.size() < tournament_size:
			var idx = randi() % population.size()
			if idx not in tournament_indices:
				tournament_indices.append(idx)
		
		# 找出最优者
		var best_idx = tournament_indices[0]
		var best_fitness = fitness_scores[best_idx]
		
		for idx in tournament_indices:
			if fitness_scores[idx] > best_fitness:
				best_fitness = fitness_scores[idx]
				best_idx = idx
		
		selected.append(population[best_idx])
	
	return selected

# ==================== 排名选择 ====================

## 排名选择 - 根据排名而非原始适应度选择
func rank_based_selection(population: Array, fitness_scores: Array[float], count: int) -> Array:
	# 创建索引-适应度对并排序
	var indexed_scores = []
	for i in range(population.size()):
		indexed_scores.append({"index": i, "fitness": fitness_scores[i]})
	
	indexed_scores.sort_custom(func(a, b): return a.fitness < b.fitness)
	
	# 分配排名分数（线性排名）
	var rank_scores = []
	var n = population.size()
	var sp = config.selection_pressure
	
	for i in range(n):
		# 线性排名公式
		var rank_score = (2.0 - sp) + 2.0 * (sp - 1.0) * float(i) / float(n - 1) if n > 1 else 1.0
		rank_scores.append(rank_score)
	
	# 创建排名到原始索引的映射
	var original_rank_scores = []
	original_rank_scores.resize(n)
	for i in range(n):
		original_rank_scores[indexed_scores[i].index] = rank_scores[i]
	
	# 使用轮盘赌在排名分数上选择
	return roulette_wheel_selection(population, original_rank_scores, count)

# ==================== 精英选择 ====================

## 精英选择 - 直接选择最优的k个个体
func elitism_selection(population: Array, fitness_scores: Array[float], count: int) -> Array:
	# 创建索引-适应度对并排序
	var indexed_scores = []
	for i in range(population.size()):
		indexed_scores.append({"index": i, "fitness": fitness_scores[i]})
	
	# 降序排序
	indexed_scores.sort_custom(func(a, b): return a.fitness > b.fitness)
	
	# 选择前count个
	var selected = []
	var select_count = mini(count, population.size())
	for i in range(select_count):
		selected.append(population[indexed_scores[i].index])
	
	return selected

# ==================== 组合选择 ====================

## 组合选择 - 精英保留 + 其他选择方法
func combined_selection(population: Array, fitness_scores: Array[float], 
						 count: int, method: Method = Method.TOURNAMENT) -> Array:
	var selected = []
	
	# 精英保留
	var elite_count = mini(config.elitism_count, count)
	var elites = elitism_selection(population, fitness_scores, elite_count)
	selected.append_array(elites)
	
	# 剩余使用指定方法选择
	var remaining_count = count - elite_count
	if remaining_count > 0:
		var others: Array
		match method:
			Method.ROULETTE_WHEEL:
				others = roulette_wheel_selection(population, fitness_scores, remaining_count)
			Method.TOURNAMENT:
				others = tournament_selection(population, fitness_scores, remaining_count)
			Method.RANK_BASED:
				others = rank_based_selection(population, fitness_scores, remaining_count)
			_:
				others = tournament_selection(population, fitness_scores, remaining_count)
		
		selected.append_array(others)
	
	return selected

# ==================== 统计辅助 ====================

## 获取种群统计信息
func get_population_stats(fitness_scores: Array[float]) -> Dictionary:
	if fitness_scores.is_empty():
		return {"min": 0.0, "max": 0.0, "avg": 0.0, "std": 0.0}
	
	var min_val = fitness_scores.min()
	var max_val = fitness_scores.max()
	
	var sum = 0.0
	for score in fitness_scores:
		sum += score
	var avg = sum / fitness_scores.size()
	
	var variance = 0.0
	for score in fitness_scores:
		variance += (score - avg) * (score - avg)
	variance /= fitness_scores.size()
	var std = sqrt(variance)
	
	return {
		"min": min_val,
		"max": max_val,
		"avg": avg,
		"std": std
	}
