class_name SpellProficiency extends Resource

enum ProficiencyLevel {
	NOVICE,
	APPRENTICE,
	ADEPT,
	EXPERT,
	MASTER
}

@export var spell_id: String = ""

@export var experience: float = 0.0

@export var max_experience: float = 1000.0

@export var use_count: int = 0

@export var hit_count: int = 0

@export var kill_count: int = 0

func get_proficiency() -> float:
	return clampf(experience / max_experience, 0.0, 1.0)

func get_proficiency_percent() -> float:
	return get_proficiency() * 100.0

func get_level() -> ProficiencyLevel:
	var prof = get_proficiency()
	if prof < 0.2:
		return ProficiencyLevel.NOVICE
	elif prof < 0.4:
		return ProficiencyLevel.APPRENTICE
	elif prof < 0.6:
		return ProficiencyLevel.ADEPT
	elif prof < 0.8:
		return ProficiencyLevel.EXPERT
	else:
		return ProficiencyLevel.MASTER

func get_level_name() -> String:
	match get_level():
		ProficiencyLevel.NOVICE:
			return "新手"
		ProficiencyLevel.APPRENTICE:
			return "学徒"
		ProficiencyLevel.ADEPT:
			return "熟练"
		ProficiencyLevel.EXPERT:
			return "专家"
		ProficiencyLevel.MASTER:
			return "大师"
	return "未知"

func add_experience(amount: float) -> void:
	experience = minf(experience + amount, max_experience)

func record_use() -> void:
	use_count += 1
	add_experience(1.0)

func record_hit() -> void:
	hit_count += 1
	add_experience(5.0)

func record_kill() -> void:
	kill_count += 1
	add_experience(20.0)

func get_hit_rate() -> float:
	if use_count == 0:
		return 0.0
	return float(hit_count) / float(use_count)

func get_windup_reduction_percent() -> float:
	return get_proficiency() * 50.0

func to_dict() -> Dictionary:
	return {
		"spell_id": spell_id,
		"experience": experience,
		"max_experience": max_experience,
		"use_count": use_count,
		"hit_count": hit_count,
		"kill_count": kill_count
	}

static func from_dict(data: Dictionary) -> SpellProficiency:
	var prof = SpellProficiency.new()
	prof.spell_id = data.get("spell_id", "")
	prof.experience = data.get("experience", 0.0)
	prof.max_experience = data.get("max_experience", 1000.0)
	prof.use_count = data.get("use_count", 0)
	prof.hit_count = data.get("hit_count", 0)
	prof.kill_count = data.get("kill_count", 0)
	return prof

func get_summary() -> String:
	return "%s (%.0f%%) - 使用: %d, 命中: %d, 击杀: %d" % [
		get_level_name(),
		get_proficiency_percent(),
		use_count,
		hit_count,
		kill_count
	]
