extends State
class_name AttackWindupState

## 攻击前摇状态
## 包含两个阶段：
## 1. REPOSITIONING - 武器从当前位置移动到攻击起始位置
## 2. WINDUP - 在攻击起始位置等待前摇时间

enum Phase {
	REPOSITIONING,  ## 武器回正阶段
	WINDUP          ## 前摇等待阶段
}

var player: PlayerController

var current_attack: AttackData = null
var input_type: int = 0
var combo_index: int = 0
var windup_timer: float = 0.0
var from_fly: bool = false

## 当前阶段
var current_phase: Phase = Phase.REPOSITIONING

## 回正阶段的最大等待时间（防止卡死）
var max_reposition_time: float = 0.5
var reposition_timer: float = 0.0

func initialize(_owner: Node) -> void:
	super.initialize(_owner)
	player = _owner as PlayerController

func enter(params: Dictionary = {}) -> void:
	player.can_move = true  ## 【修改】允许攻击时移动
	player.can_rotate = false
	player.is_attacking = true

	var input = params.get("input", null)
	if input != null:
		match input.type:
			InputBuffer.InputType.ATTACK_PRIMARY:
				input_type = 0
			InputBuffer.InputType.ATTACK_SECONDARY:
				input_type = 1
			InputBuffer.InputType.ATTACK_COMBO:
				input_type = 2

	combo_index = params.get("combo_index", 0)
	from_fly = params.get("from_fly", false)

	current_attack = _get_attack_data()

	if current_attack == null:
		transition_to("Idle")
		return

	windup_timer = 0.0
	reposition_timer = 0.0

	## 检查是否需要武器回正
	if current_attack.requires_repositioning and _needs_repositioning():
		current_phase = Phase.REPOSITIONING
		_start_weapon_repositioning()
	else:
		current_phase = Phase.WINDUP
		_start_windup_phase()

	player.attack_started.emit(current_attack)

func exit() -> void:
	windup_timer = 0.0
	reposition_timer = 0.0
	current_attack = null
	current_phase = Phase.REPOSITIONING

func physics_update(delta: float) -> void:
	match current_phase:
		Phase.REPOSITIONING:
			_update_repositioning_phase(delta)
		Phase.WINDUP:
			_update_windup_phase(delta)

func _update_repositioning_phase(delta: float) -> void:
	reposition_timer += delta
	
	## 检查武器是否已经到位
	var weapon_settled = _is_weapon_settled()
	
	## 超时或武器到位，进入前摇阶段
	if weapon_settled or reposition_timer >= max_reposition_time:
		current_phase = Phase.WINDUP
		_start_windup_phase()

func _update_windup_phase(delta: float) -> void:
	windup_timer += delta

	if current_attack != null and windup_timer >= current_attack.windup_time:
		transition_to("AttackActive", {
			"attack": current_attack,
			"input_type": input_type,
			"combo_index": combo_index,
			"from_fly": from_fly
		})

func _needs_repositioning() -> bool:
	## 检查武器当前位置是否已经接近攻击起始位置
	if player.visuals == null:
		return false
	
	var visuals = player.visuals as PlayerVisuals
	if visuals == null or visuals.weapon_physics == null:
		return false
	
	var weapon_physics = visuals.weapon_physics
	var current_rotation = weapon_physics.rotation
	var target_rotation = current_attack.get_reposition_target_rotation()
	
	## 如果角度差距大于阈值，需要回正
	var angle_diff = abs(angle_difference(current_rotation, target_rotation))
	return rad_to_deg(angle_diff) > 20.0

func _start_weapon_repositioning() -> void:
	if player.visuals == null:
		return
	
	var visuals = player.visuals as PlayerVisuals
	if visuals == null:
		return
	
	## 设置武器物理系统的目标位置
	var target_pos = current_attack.get_reposition_target_position()
	var target_rot = current_attack.get_reposition_target_rotation()
	
	visuals.start_weapon_repositioning(target_pos, target_rot)
	
	## 根据武器重量调整最大回正时间
	if player.current_weapon != null:
		max_reposition_time = 0.3 + player.current_weapon.weight * 0.05
		max_reposition_time *= current_attack.reposition_time_multiplier

func _is_weapon_settled() -> bool:
	if player.visuals == null:
		return true
	
	var visuals = player.visuals as PlayerVisuals
	if visuals == null:
		return true
	
	return visuals.is_weapon_settled()

func _start_windup_phase() -> void:
	## 开始前摇动画
	_play_windup_animation()

func _get_attack_data() -> AttackData:
	if player.current_weapon == null:
		return null

	var attacks = player.current_weapon.get_attacks_for_input(input_type)
	if attacks.size() == 0:
		return null

	## 根据连击索引和武器当前状态选择最合适的攻击
	var selected_attack = _select_best_attack(attacks)
	return selected_attack

func _select_best_attack(attacks: Array[AttackData]) -> AttackData:
	if attacks.size() == 0:
		return null
	
	## 基本情况：使用连击索引
	var index = combo_index % attacks.size()
	var base_attack = attacks[index]
	
	## 高级选择：根据武器当前位置选择最优攻击方向
	if player.visuals != null:
		var visuals = player.visuals as PlayerVisuals
		if visuals != null and visuals.weapon_physics != null:
			var current_rotation = visuals.weapon_physics.rotation
			
			## 查找最适合当前武器位置的攻击
			var best_attack: AttackData = null
			var best_score: float = -1.0
			
			for attack in attacks:
				var score = _calculate_attack_suitability(attack, current_rotation)
				if score > best_score:
					best_score = score
					best_attack = attack
			
			if best_attack != null and best_score > 0.7:
				return best_attack
	
	return base_attack

func _calculate_attack_suitability(attack: AttackData, current_weapon_rotation: float) -> float:
	## 计算攻击与当前武器位置的适合度（0-1）
	var target_rotation = attack.get_reposition_target_rotation()
	var angle_diff = abs(angle_difference(current_weapon_rotation, target_rotation))
	
	## 角度差越小，适合度越高
	var angle_score = 1.0 - clamp(rad_to_deg(angle_diff) / 180.0, 0.0, 1.0)
	
	return angle_score

func _play_windup_animation() -> void:
	if current_attack == null:
		return
	
	## 通知视觉系统播放前摇动画
	if player.visuals != null:
		var visuals = player.visuals as PlayerVisuals
		if visuals != null:
			## 在前摇阶段，武器保持在起始位置
			var target_pos = current_attack.get_reposition_target_position()
			var target_rot = current_attack.get_reposition_target_rotation()
			visuals.start_weapon_repositioning(target_pos, target_rot)
