# weapon_manager.gd
# 武器管理器 - 管理玩家的武器装备和切换
class_name WeaponManager extends Node

## 信号
signal weapon_equipped(weapon: WeaponData)
signal weapon_unequipped(weapon: WeaponData)
signal weapon_switched(old_weapon: WeaponData, new_weapon: WeaponData)

## 玩家控制器引用
var player: PlayerController = null

## 武器槽位
var main_hand_weapon: WeaponData = null
var off_hand_weapon: WeaponData = null

## 武器库（可用武器列表）
var weapon_inventory: Array[WeaponData] = []

## 当前选中的武器索引
var current_weapon_index: int = 0

## 武器视觉节点引用
var main_hand_sprite: Sprite2D = null
var off_hand_sprite: Sprite2D = null

func _ready() -> void:
	# 获取玩家引用
	player = get_parent() as PlayerController
	
	# 获取武器精灵节点
	if player != null and player.weapon_rig != null:
		main_hand_sprite = player.weapon_rig.get_node_or_null("MainHandWeapon")
		off_hand_sprite = player.weapon_rig.get_node_or_null("OffHandWeapon")

## 初始化武器管理器
func initialize(_player: PlayerController) -> void:
	player = _player
	
	# 创建默认武器（徒手）
	var unarmed = WeaponData.create_unarmed()
	weapon_inventory.append(unarmed)
	equip_weapon(unarmed)

## 装备武器
func equip_weapon(weapon: WeaponData) -> void:
	if weapon == null:
		return
	
	var old_weapon = main_hand_weapon
	
	# 根据武器类型处理装备
	match weapon.grip_type:
		WeaponData.GripType.ONE_HANDED:
			main_hand_weapon = weapon
			# 单手武器不影响副手
		WeaponData.GripType.TWO_HANDED:
			main_hand_weapon = weapon
			off_hand_weapon = null  # 双手武器占用两只手
		WeaponData.GripType.DUAL_WIELD:
			main_hand_weapon = weapon
			# 双持武器可能需要特殊处理
	
	# 更新玩家的当前武器
	if player != null:
		player.current_weapon = weapon
	
	# 更新视觉
	_update_weapon_visuals()
	
	# 发送信号
	if old_weapon != weapon:
		weapon_switched.emit(old_weapon, weapon)
	weapon_equipped.emit(weapon)

## 卸下武器
func unequip_weapon() -> void:
	var old_weapon = main_hand_weapon
	
	main_hand_weapon = null
	off_hand_weapon = null
	
	# 装备徒手
	var unarmed = _get_or_create_unarmed()
	equip_weapon(unarmed)
	
	if old_weapon != null:
		weapon_unequipped.emit(old_weapon)

## 切换到下一把武器
func switch_to_next_weapon() -> void:
	if weapon_inventory.size() <= 1:
		return
	
	current_weapon_index = (current_weapon_index + 1) % weapon_inventory.size()
	equip_weapon(weapon_inventory[current_weapon_index])

## 切换到上一把武器
func switch_to_previous_weapon() -> void:
	if weapon_inventory.size() <= 1:
		return
	
	current_weapon_index = (current_weapon_index - 1 + weapon_inventory.size()) % weapon_inventory.size()
	equip_weapon(weapon_inventory[current_weapon_index])

## 切换到指定索引的武器
func switch_to_weapon_index(index: int) -> void:
	if index < 0 or index >= weapon_inventory.size():
		return
	
	current_weapon_index = index
	equip_weapon(weapon_inventory[index])

## 添加武器到库存
func add_weapon_to_inventory(weapon: WeaponData) -> void:
	if weapon == null or weapon in weapon_inventory:
		return
	
	weapon_inventory.append(weapon)

## 从库存移除武器
func remove_weapon_from_inventory(weapon: WeaponData) -> void:
	var index = weapon_inventory.find(weapon)
	if index >= 0:
		weapon_inventory.remove_at(index)
		
		# 如果移除的是当前武器，切换到其他武器
		if weapon == main_hand_weapon:
			if weapon_inventory.size() > 0:
				current_weapon_index = min(current_weapon_index, weapon_inventory.size() - 1)
				equip_weapon(weapon_inventory[current_weapon_index])
			else:
				unequip_weapon()

## 更新武器视觉
func _update_weapon_visuals() -> void:
	# 更新主手武器
	if main_hand_sprite != null:
		if main_hand_weapon != null and main_hand_weapon.weapon_texture != null:
			main_hand_sprite.texture = main_hand_weapon.weapon_texture
			main_hand_sprite.offset = main_hand_weapon.weapon_offset
			main_hand_sprite.scale = main_hand_weapon.weapon_scale
			main_hand_sprite.visible = true
		else:
			main_hand_sprite.visible = false
	
	# 更新副手武器
	if off_hand_sprite != null:
		if off_hand_weapon != null and off_hand_weapon.weapon_texture != null:
			off_hand_sprite.texture = off_hand_weapon.weapon_texture
			off_hand_sprite.offset = off_hand_weapon.weapon_offset
			off_hand_sprite.scale = off_hand_weapon.weapon_scale
			off_hand_sprite.visible = true
		else:
			off_hand_sprite.visible = false

## 获取或创建徒手武器
func _get_or_create_unarmed() -> WeaponData:
	for weapon in weapon_inventory:
		if weapon.weapon_type == WeaponData.WeaponType.UNARMED:
			return weapon
	
	var unarmed = WeaponData.create_unarmed()
	weapon_inventory.insert(0, unarmed)
	return unarmed

## 获取当前武器
func get_current_weapon() -> WeaponData:
	return main_hand_weapon

## 获取副手武器
func get_off_hand_weapon() -> WeaponData:
	return off_hand_weapon

## 检查是否装备了双手武器
func is_two_handed_equipped() -> bool:
	return main_hand_weapon != null and main_hand_weapon.is_two_handed()

## 检查是否装备了双持武器
func is_dual_wield_equipped() -> bool:
	return main_hand_weapon != null and main_hand_weapon.is_dual_wield()
