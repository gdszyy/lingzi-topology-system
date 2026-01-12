# proficiency_manager.gd
# 熟练度管理器 - 管理玩家对所有法术的熟练度
class_name ProficiencyManager extends Node

## 信号
signal proficiency_changed(spell_id: String, proficiency: float)
signal level_up(spell_id: String, new_level: int)

## 熟练度数据存储 (spell_id -> SpellProficiency)
var proficiencies: Dictionary = {}

## 保存路径
var save_path: String = "user://proficiency_data.json"

func _ready() -> void:
	# 尝试加载保存的数据
	load_data()

## 获取法术熟练度
func get_proficiency(spell_id: String) -> SpellProficiency:
	if not proficiencies.has(spell_id):
		# 创建新的熟练度记录
		var prof = SpellProficiency.new()
		prof.spell_id = spell_id
		proficiencies[spell_id] = prof
	
	return proficiencies[spell_id]

## 获取熟练度值 (0.0 - 1.0)
func get_proficiency_value(spell_id: String) -> float:
	return get_proficiency(spell_id).get_proficiency()

## 获取熟练度等级
func get_proficiency_level(spell_id: String) -> int:
	return get_proficiency(spell_id).get_level()

## 记录法术使用
func record_spell_use(spell_id: String) -> void:
	var prof = get_proficiency(spell_id)
	var old_level = prof.get_level()
	
	prof.record_use()
	
	var new_level = prof.get_level()
	if new_level != old_level:
		level_up.emit(spell_id, new_level)
	
	proficiency_changed.emit(spell_id, prof.get_proficiency())

## 记录法术命中
func record_spell_hit(spell_id: String) -> void:
	var prof = get_proficiency(spell_id)
	var old_level = prof.get_level()
	
	prof.record_hit()
	
	var new_level = prof.get_level()
	if new_level != old_level:
		level_up.emit(spell_id, new_level)
	
	proficiency_changed.emit(spell_id, prof.get_proficiency())

## 记录法术击杀
func record_spell_kill(spell_id: String) -> void:
	var prof = get_proficiency(spell_id)
	var old_level = prof.get_level()
	
	prof.record_kill()
	
	var new_level = prof.get_level()
	if new_level != old_level:
		level_up.emit(spell_id, new_level)
	
	proficiency_changed.emit(spell_id, prof.get_proficiency())

## 添加经验值
func add_experience(spell_id: String, amount: float) -> void:
	var prof = get_proficiency(spell_id)
	var old_level = prof.get_level()
	
	prof.add_experience(amount)
	
	var new_level = prof.get_level()
	if new_level != old_level:
		level_up.emit(spell_id, new_level)
	
	proficiency_changed.emit(spell_id, prof.get_proficiency())

## 计算法术的实际前摇时间
func calculate_spell_windup(spell: SpellCoreData, is_engraved: bool = false) -> float:
	if spell == null:
		return 0.5
	
	var proficiency = get_proficiency_value(spell.spell_id)
	return spell.calculate_windup_time(proficiency, is_engraved)

## 获取所有熟练度数据
func get_all_proficiencies() -> Dictionary:
	return proficiencies.duplicate()

## 获取统计摘要
func get_stats_summary() -> String:
	var total_spells = proficiencies.size()
	var total_uses = 0
	var total_hits = 0
	var total_kills = 0
	var avg_proficiency = 0.0
	
	for spell_id in proficiencies:
		var prof = proficiencies[spell_id] as SpellProficiency
		total_uses += prof.use_count
		total_hits += prof.hit_count
		total_kills += prof.kill_count
		avg_proficiency += prof.get_proficiency()
	
	if total_spells > 0:
		avg_proficiency /= total_spells
	
	return "法术数: %d | 总使用: %d | 总命中: %d | 总击杀: %d | 平均熟练度: %.0f%%" % [
		total_spells,
		total_uses,
		total_hits,
		total_kills,
		avg_proficiency * 100
	]

## 保存数据
func save_data() -> void:
	var data = {}
	for spell_id in proficiencies:
		data[spell_id] = proficiencies[spell_id].to_dict()
	
	var json_string = JSON.stringify(data, "\t")
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file != null:
		file.store_string(json_string)
		file.close()

## 加载数据
func load_data() -> void:
	if not FileAccess.file_exists(save_path):
		return
	
	var file = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		push_warning("加载熟练度数据失败: %s" % json.get_error_message())
		return
	
	var data = json.get_data()
	if data is Dictionary:
		proficiencies.clear()
		for spell_id in data:
			proficiencies[spell_id] = SpellProficiency.from_dict(data[spell_id])

## 重置所有熟练度
func reset_all() -> void:
	proficiencies.clear()
	save_data()

## 重置单个法术熟练度
func reset_spell(spell_id: String) -> void:
	if proficiencies.has(spell_id):
		proficiencies.erase(spell_id)
		save_data()
