class_name SelectionMethods
extends RefCounted

enum Method {
	ROULETTE_WHEEL,
	TOURNAMENT,
	RANK_BASED,
	ELITISM
}

var config = {
	"tournament_size": 3,
	"elitism_count": 2,
	"selection_pressure": 1.5
}

func roulette_wheel_selection(population: Array, fitness_scores: Array[float], count: int) -> Array:
	var selected = []

	var min_fitness = fitness_scores.min()
	var adjusted_scores = []
	for score in fitness_scores:
		adjusted_scores.append(score - min_fitness + 0.001)

	var total_fitness = 0.0
	for score in adjusted_scores:
		total_fitness += score

	for i in range(count):
		var pick = randf() * total_fitness
		var current = 0.0

		for j in range(population.size()):
			current += adjusted_scores[j]
			if current >= pick:
				selected.append(population[j])
				break

		if selected.size() <= i:
			selected.append(population[population.size() - 1])

	return selected

func tournament_selection(population: Array, fitness_scores: Array[float], count: int) -> Array:
	var selected = []
	var tournament_size = mini(config.tournament_size, population.size())

	for i in range(count):
		var tournament_indices = []

		while tournament_indices.size() < tournament_size:
			var idx = randi() % population.size()
			if idx not in tournament_indices:
				tournament_indices.append(idx)

		var best_idx = tournament_indices[0]
		var best_fitness = fitness_scores[best_idx]

		for idx in tournament_indices:
			if fitness_scores[idx] > best_fitness:
				best_fitness = fitness_scores[idx]
				best_idx = idx

		selected.append(population[best_idx])

	return selected

func rank_based_selection(population: Array, fitness_scores: Array[float], count: int) -> Array:
	var indexed_scores = []
	for i in range(population.size()):
		indexed_scores.append({"index": i, "fitness": fitness_scores[i]})

	indexed_scores.sort_custom(func(a, b): return a.fitness < b.fitness)

	var rank_scores = []
	var n = population.size()
	var sp = config.selection_pressure

	for i in range(n):
		var rank_score = (2.0 - sp) + 2.0 * (sp - 1.0) * float(i) / float(n - 1) if n > 1 else 1.0
		rank_scores.append(rank_score)

	var original_rank_scores = []
	original_rank_scores.resize(n)
	for i in range(n):
		original_rank_scores[indexed_scores[i].index] = rank_scores[i]

	return roulette_wheel_selection(population, original_rank_scores, count)

func elitism_selection(population: Array, fitness_scores: Array[float], count: int) -> Array:
	var indexed_scores = []
	for i in range(population.size()):
		indexed_scores.append({"index": i, "fitness": fitness_scores[i]})

	indexed_scores.sort_custom(func(a, b): return a.fitness > b.fitness)

	var selected = []
	var select_count = mini(count, population.size())
	for i in range(select_count):
		selected.append(population[indexed_scores[i].index])

	return selected

func combined_selection(population: Array, fitness_scores: Array[float],
						 count: int, method: Method = Method.TOURNAMENT) -> Array:
	var selected = []

	var elite_count = mini(config.elitism_count, count)
	var elites = elitism_selection(population, fitness_scores, elite_count)
	selected.append_array(elites)

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
