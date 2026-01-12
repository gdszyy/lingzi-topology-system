class_name WeaponManager extends Node
## 武器管理器
## 负责管理武器数据和库存
## 【修复】移除冗余的视觉更新逻辑，渲染由 ArmRig 统一处理

signal weapon_equipped(weapon: WeaponData)
signal weapon_unequipped(weapon: WeaponData)
signal weapon_switched(old_weapon: WeaponData, new_weapon: WeaponData)

var player: PlayerController = null

var main_hand_weapon: WeaponData = null
var off_hand_weapon: WeaponData = null

var weapon_inventory: Array[WeaponData] = []

var current_weapon_index: int = 0

func _ready() -> void:
	player = get_parent() as PlayerController

func initialize(_player: PlayerController) -> void:
	player = _player

	var unarmed = WeaponData.create_unarmed()
	weapon_inventory.append(unarmed)
	equip_weapon(unarmed)

func equip_weapon(weapon: WeaponData) -> void:
	if weapon == null:
		return

	var old_weapon = main_hand_weapon

	match weapon.grip_type:
		WeaponData.GripType.ONE_HANDED:
			main_hand_weapon = weapon
		WeaponData.GripType.TWO_HANDED:
			main_hand_weapon = weapon
			off_hand_weapon = null
		WeaponData.GripType.DUAL_WIELD:
			main_hand_weapon = weapon

	if player != null:
		player.current_weapon = weapon

	## 【修复】移除 _update_weapon_visuals() 调用
	## 武器视觉由 PlayerVisuals 通过 weapon_changed 信号处理

	if old_weapon != weapon:
		weapon_switched.emit(old_weapon, weapon)
	weapon_equipped.emit(weapon)

func unequip_weapon() -> void:
	var old_weapon = main_hand_weapon

	main_hand_weapon = null
	off_hand_weapon = null

	var unarmed = _get_or_create_unarmed()
	equip_weapon(unarmed)

	if old_weapon != null:
		weapon_unequipped.emit(old_weapon)

func switch_to_next_weapon() -> void:
	if weapon_inventory.size() <= 1:
		return

	current_weapon_index = (current_weapon_index + 1) % weapon_inventory.size()
	equip_weapon(weapon_inventory[current_weapon_index])

func switch_to_previous_weapon() -> void:
	if weapon_inventory.size() <= 1:
		return

	current_weapon_index = (current_weapon_index - 1 + weapon_inventory.size()) % weapon_inventory.size()
	equip_weapon(weapon_inventory[current_weapon_index])

func switch_to_weapon_index(index: int) -> void:
	if index < 0 or index >= weapon_inventory.size():
		return

	current_weapon_index = index
	equip_weapon(weapon_inventory[index])

func add_weapon_to_inventory(weapon: WeaponData) -> void:
	if weapon == null or weapon in weapon_inventory:
		return

	weapon_inventory.append(weapon)

func remove_weapon_from_inventory(weapon: WeaponData) -> void:
	var index = weapon_inventory.find(weapon)
	if index >= 0:
		weapon_inventory.remove_at(index)

		if weapon == main_hand_weapon:
			if weapon_inventory.size() > 0:
				current_weapon_index = min(current_weapon_index, weapon_inventory.size() - 1)
				equip_weapon(weapon_inventory[current_weapon_index])
			else:
				unequip_weapon()

func _get_or_create_unarmed() -> WeaponData:
	for weapon in weapon_inventory:
		if weapon.weapon_type == WeaponData.WeaponType.UNARMED:
			return weapon

	var unarmed = WeaponData.create_unarmed()
	weapon_inventory.insert(0, unarmed)
	return unarmed

func get_current_weapon() -> WeaponData:
	return main_hand_weapon

func get_off_hand_weapon() -> WeaponData:
	return off_hand_weapon

func is_two_handed_equipped() -> bool:
	return main_hand_weapon != null and main_hand_weapon.is_two_handed()

func is_dual_wield_equipped() -> bool:
	return main_hand_weapon != null and main_hand_weapon.is_dual_wield()
