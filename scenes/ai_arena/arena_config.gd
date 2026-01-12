class_name ArenaConfig extends Resource

## AI演武厂配置
## 定义演武厂的各种模式和参数

enum ArenaMode {
	FREE_PLAY,      # 自由模式 - 随意生成敌人测试
	WAVE_SURVIVAL,  # 波次生存 - 连续波次战斗
	BOSS_RUSH,      # Boss连战 - 挑战强力敌人
	TRAINING,       # 训练模式 - 无限生命，专注练习
	AI_VS_AI        # AI对战 - 观看AI之间的战斗
}

enum Difficulty {
	EASY,
	NORMAL,
	HARD,
	NIGHTMARE
}

@export_group("基础设置")
@export var arena_mode: ArenaMode = ArenaMode.FREE_PLAY
@export var difficulty: Difficulty = Difficulty.NORMAL
@export var arena_name: String = "默认演武场"

@export_group("波次设置")
@export var max_waves: int = 10
@export var enemies_per_wave_base: int = 3
@export var enemies_per_wave_increment: int = 2
@export var wave_spawn_delay: float = 1.0
@export var wave_break_time: float = 3.0

@export_group("敌人设置")
@export var enemy_health_multiplier: float = 1.0
@export var enemy_damage_multiplier: float = 1.0
@export var enemy_speed_multiplier: float = 1.0
@export var max_enemies_on_screen: int = 15

@export_group("玩家设置")
@export var player_health_multiplier: float = 1.0
@export var player_damage_multiplier: float = 1.0
@export var player_invincible: bool = false
@export var infinite_energy: bool = false

@export_group("奖励设置")
@export var score_multiplier: float = 1.0
@export var bonus_score_per_wave: int = 100

## 根据难度获取敌人生命倍率
func get_enemy_health_multiplier() -> float:
	var base = enemy_health_multiplier
	match difficulty:
		Difficulty.EASY:
			return base * 0.7
		Difficulty.NORMAL:
			return base * 1.0
		Difficulty.HARD:
			return base * 1.5
		Difficulty.NIGHTMARE:
			return base * 2.5
	return base

## 根据难度获取敌人伤害倍率
func get_enemy_damage_multiplier() -> float:
	var base = enemy_damage_multiplier
	match difficulty:
		Difficulty.EASY:
			return base * 0.5
		Difficulty.NORMAL:
			return base * 1.0
		Difficulty.HARD:
			return base * 1.5
		Difficulty.NIGHTMARE:
			return base * 2.0
	return base

## 获取指定波次的敌人数量
func get_enemies_for_wave(wave_number: int) -> int:
	var count = enemies_per_wave_base + (wave_number - 1) * enemies_per_wave_increment
	
	# 难度调整
	match difficulty:
		Difficulty.EASY:
			count = int(count * 0.7)
		Difficulty.HARD:
			count = int(count * 1.3)
		Difficulty.NIGHTMARE:
			count = int(count * 1.8)
	
	return mini(count, max_enemies_on_screen)

## 获取波次生成延迟
func get_spawn_delay_for_wave(wave_number: int) -> float:
	var delay = wave_spawn_delay
	
	# 后期波次生成更快
	delay = max(0.3, delay - wave_number * 0.05)
	
	return delay

## 获取分数倍率
func get_score_multiplier() -> float:
	var base = score_multiplier
	match difficulty:
		Difficulty.EASY:
			return base * 0.5
		Difficulty.NORMAL:
			return base * 1.0
		Difficulty.HARD:
			return base * 2.0
		Difficulty.NIGHTMARE:
			return base * 4.0
	return base

## 创建简单模式配置
static func create_easy_mode() -> ArenaConfig:
	var config = ArenaConfig.new()
	config.arena_name = "新手训练场"
	config.arena_mode = ArenaMode.WAVE_SURVIVAL
	config.difficulty = Difficulty.EASY
	config.max_waves = 5
	config.enemies_per_wave_base = 2
	config.enemies_per_wave_increment = 1
	config.player_health_multiplier = 1.5
	return config

## 创建普通模式配置
static func create_normal_mode() -> ArenaConfig:
	var config = ArenaConfig.new()
	config.arena_name = "标准演武场"
	config.arena_mode = ArenaMode.WAVE_SURVIVAL
	config.difficulty = Difficulty.NORMAL
	config.max_waves = 10
	config.enemies_per_wave_base = 3
	config.enemies_per_wave_increment = 2
	return config

## 创建困难模式配置
static func create_hard_mode() -> ArenaConfig:
	var config = ArenaConfig.new()
	config.arena_name = "精英挑战"
	config.arena_mode = ArenaMode.WAVE_SURVIVAL
	config.difficulty = Difficulty.HARD
	config.max_waves = 15
	config.enemies_per_wave_base = 4
	config.enemies_per_wave_increment = 3
	config.enemy_speed_multiplier = 1.2
	return config

## 创建噩梦模式配置
static func create_nightmare_mode() -> ArenaConfig:
	var config = ArenaConfig.new()
	config.arena_name = "噩梦深渊"
	config.arena_mode = ArenaMode.WAVE_SURVIVAL
	config.difficulty = Difficulty.NIGHTMARE
	config.max_waves = 20
	config.enemies_per_wave_base = 5
	config.enemies_per_wave_increment = 4
	config.enemy_speed_multiplier = 1.5
	config.wave_spawn_delay = 0.5
	return config

## 创建训练模式配置
static func create_training_mode() -> ArenaConfig:
	var config = ArenaConfig.new()
	config.arena_name = "无限训练"
	config.arena_mode = ArenaMode.TRAINING
	config.difficulty = Difficulty.NORMAL
	config.player_invincible = true
	config.infinite_energy = true
	config.max_enemies_on_screen = 5
	return config

## 创建AI对战模式配置
static func create_ai_vs_ai_mode() -> ArenaConfig:
	var config = ArenaConfig.new()
	config.arena_name = "AI对战观摩"
	config.arena_mode = ArenaMode.AI_VS_AI
	config.difficulty = Difficulty.NORMAL
	config.max_enemies_on_screen = 10
	return config

func to_dict() -> Dictionary:
	return {
		"arena_mode": arena_mode,
		"difficulty": difficulty,
		"arena_name": arena_name,
		"max_waves": max_waves,
		"enemy_health_multiplier": get_enemy_health_multiplier(),
		"enemy_damage_multiplier": get_enemy_damage_multiplier(),
		"score_multiplier": get_score_multiplier()
	}
