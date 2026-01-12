class_name EnergySystemData
extends Resource

## 修行者能量系统
## 
## 该系统替代传统的血量系统，实现基于修行设定的能量机制：
## - 当前能量上限：相当于血量，受伤会减少，修养会恢复
## - 最大能量上限：由修为限制
## - 当前能量：用于施法、修复等活动的资源
## - 能量吸收效率：从周围环境吸收能量的速度
## - 基础修炼效率：消耗当前能量转化为能量上限的效率

# 信号，用于UI更新和状态监听
signal energy_cap_changed(current_cap: float, max_cap: float)
signal current_energy_changed(current: float, cap: float)
signal depleted()  # 能量上限耗尽（死亡）

# --- 核心属性 ---

## 当前能量上限 (相当于血量，受伤会减少)
@export var current_energy_cap: float = 100.0:
	set(value):
		var new_value = clampf(value, 0.0, max_energy_cap)
		if not is_equal_approx(current_energy_cap, new_value):
			current_energy_cap = new_value
			energy_cap_changed.emit(current_energy_cap, max_energy_cap)
			if current_energy_cap <= 0:
				depleted.emit()

## 最大能量上限 (由修为决定)
@export var max_energy_cap: float = 100.0:
	set(value):
		var new_value = maxf(0.0, value)
		if not is_equal_approx(max_energy_cap, new_value):
			max_energy_cap = new_value
			# 确保当前上限不超过新的最大值
			if current_energy_cap > max_energy_cap:
				self.current_energy_cap = max_energy_cap

## 当前能量 (用于施法和修复)
@export var current_energy: float = 100.0:
	set(value):
		var new_value = maxf(0.0, value)
		if not is_equal_approx(current_energy, new_value):
			current_energy = new_value
			current_energy_changed.emit(current_energy, current_energy_cap)

# --- 效率和转化率 ---

## 能量伤害转化比 (例如: 1点伤害消耗1点能量上限)
@export var damage_conversion_ratio: float = 1.0

## 能量吸收效率 (每秒从环境中恢复的能量)
@export var energy_absorption_rate: float = 5.0

## 基础修炼效率 (消耗X点当前能量, 恢复1点当前能量上限)
@export var cultivation_energy_cost: float = 10.0

## 能量上限自然恢复速率 (每秒恢复的能量上限，需要消耗当前能量)
@export var cap_recovery_rate: float = 1.0

## 是否自动修复能量上限
@export var auto_cultivation: bool = false

# --- 核心方法 ---

## 承受伤害，返回实际造成的能量上限损伤
func take_damage(damage_amount: float) -> float:
	var energy_cap_damage = damage_amount * damage_conversion_ratio
	var old_cap = current_energy_cap
	self.current_energy_cap -= energy_cap_damage
	return old_cap - current_energy_cap

## 从环境中被动吸收能量
func absorb_from_environment(delta: float) -> float:
	var absorbed = energy_absorption_rate * delta
	var old_energy = current_energy
	self.current_energy += absorbed
	return current_energy - old_energy

## 主动修炼/修复能量上限
## 返回实际恢复的能量上限数值
func cultivate(delta: float, intensity: float = 1.0) -> float:
	if current_energy_cap >= max_energy_cap:
		return 0.0  # 已满，无需修复
	
	var energy_cost = cap_recovery_rate * cultivation_energy_cost * intensity * delta
	if current_energy < energy_cost:
		return 0.0  # 能量不足
	
	var recovery_amount = cap_recovery_rate * intensity * delta
	var actual_recovery = minf(recovery_amount, max_energy_cap - current_energy_cap)
	
	if actual_recovery > 0:
		self.current_energy -= energy_cost * (actual_recovery / recovery_amount)
		self.current_energy_cap += actual_recovery
	
	return actual_recovery

## 消耗能量（用于施法等）
## 返回是否成功消耗
func consume_energy(amount: float) -> bool:
	if current_energy >= amount:
		self.current_energy -= amount
		return true
	return false

## 直接恢复能量上限（如治疗效果）
func restore_energy_cap(amount: float) -> float:
	var old_cap = current_energy_cap
	self.current_energy_cap += amount
	return current_energy_cap - old_cap

## 直接恢复当前能量
func restore_energy(amount: float) -> float:
	var old_energy = current_energy
	self.current_energy += amount
	return current_energy - old_energy

## 检查是否耗尽（死亡）
func is_depleted() -> bool:
	return current_energy_cap <= 0

## 获取能量上限百分比（用于UI显示）
func get_cap_percent() -> float:
	if max_energy_cap <= 0:
		return 0.0
	return current_energy_cap / max_energy_cap

## 获取当前能量百分比（相对于当前能量上限）
func get_energy_percent() -> float:
	if current_energy_cap <= 0:
		return 0.0
	return minf(current_energy / current_energy_cap, 1.0)

## 处理每帧更新（被动吸收和自动修复）
func process_update(delta: float) -> void:
	# 被动吸收环境能量
	absorb_from_environment(delta)
	
	# 自动修复能量上限
	if auto_cultivation and current_energy_cap < max_energy_cap:
		cultivate(delta, 0.5)  # 自动修复以较低强度进行

## 重置状态
func reset() -> void:
	current_energy_cap = max_energy_cap
	current_energy = max_energy_cap  # 初始能量等于能量上限
	energy_cap_changed.emit(current_energy_cap, max_energy_cap)
	current_energy_changed.emit(current_energy, current_energy_cap)

## 创建默认配置
static func create_default() -> EnergySystemData:
	var data = EnergySystemData.new()
	data.max_energy_cap = 100.0
	data.current_energy_cap = 100.0
	data.current_energy = 100.0
	data.damage_conversion_ratio = 1.0
	data.energy_absorption_rate = 5.0
	data.cultivation_energy_cost = 10.0
	data.cap_recovery_rate = 1.0
	data.auto_cultivation = false
	return data

## 创建敌人配置（较低的恢复能力）
static func create_enemy_default(health: float = 100.0) -> EnergySystemData:
	var data = EnergySystemData.new()
	data.max_energy_cap = health
	data.current_energy_cap = health
	data.current_energy = health * 0.5  # 敌人初始能量较低
	data.damage_conversion_ratio = 1.0
	data.energy_absorption_rate = 1.0  # 敌人吸收效率较低
	data.cultivation_energy_cost = 20.0  # 敌人修复成本较高
	data.cap_recovery_rate = 0.5  # 敌人恢复速度较慢
	data.auto_cultivation = false
	return data

## 序列化为字典
func to_dict() -> Dictionary:
	return {
		"current_energy_cap": current_energy_cap,
		"max_energy_cap": max_energy_cap,
		"current_energy": current_energy,
		"damage_conversion_ratio": damage_conversion_ratio,
		"energy_absorption_rate": energy_absorption_rate,
		"cultivation_energy_cost": cultivation_energy_cost,
		"cap_recovery_rate": cap_recovery_rate,
		"auto_cultivation": auto_cultivation
	}

## 从字典反序列化
static func from_dict(data: Dictionary) -> EnergySystemData:
	var system = EnergySystemData.new()
	system.max_energy_cap = data.get("max_energy_cap", 100.0)
	system.current_energy_cap = data.get("current_energy_cap", system.max_energy_cap)
	system.current_energy = data.get("current_energy", 100.0)
	system.damage_conversion_ratio = data.get("damage_conversion_ratio", 1.0)
	system.energy_absorption_rate = data.get("energy_absorption_rate", 5.0)
	system.cultivation_energy_cost = data.get("cultivation_energy_cost", 10.0)
	system.cap_recovery_rate = data.get("cap_recovery_rate", 1.0)
	system.auto_cultivation = data.get("auto_cultivation", false)
	return system
