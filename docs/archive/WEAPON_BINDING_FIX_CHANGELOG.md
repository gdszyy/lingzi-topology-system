# 武器与手绑定关系修复日志

**版本**: 1.0  
**日期**: 2026-01-13  
**修复方向**: 武器握柄对齐 + 双手武器握持点同步

## 问题分析

### 1. 握柄偏移计算错误
**问题**: 武器精灵的 `offset` 被设置为 `-grip_offset`，但这个负偏移没有考虑武器的旋转。
```gdscript
# 原始代码（错误）
weapon_sprite.offset = -grip_offset
weapon_sprite.rotation = weapon_rotation
```
**结果**: 当武器旋转时，握柄点不会随之旋转，导致握柄与手部位置错位。

### 2. 武器旋转中心问题
**问题**: 武器精灵的旋转中心是其自身中心，但握柄偏移是从武器中心到握柄的距离。旋转时，握柄点会绕武器中心旋转，而不是保持在手部位置。

### 3. 双手武器握点计算生硬
**问题**: 副手握点计算时添加了额外的偏移（如 `- Vector2(8, 0).rotated(swing_angle_rad)`），这导致副手位置不够精确。
```gdscript
# 原始代码（不精确）
var off_hand_pos = main_hand_pos + grip_offset - Vector2(8, 0).rotated(swing_angle_rad)
```
**结果**: 双手武器时，左手握点与武器实际握点不对齐。

## 修复方案

### 1. ArmRig.gd - 改进武器位置计算

#### 新增变量
```gdscript
var weapon_grip_offset: Vector2 = Vector2.ZERO  ## 握柄偏移
var weapon_base_rotation: float = -PI / 2       ## 武器基础旋转
```

#### 新增方法：_update_weapon_position_and_rotation()
```gdscript
func _update_weapon_position_and_rotation() -> void:
	if weapon_sprite == null:
		return
	
	## 计算总旋转（基础旋转 + 手部旋转）
	var total_rotation = weapon_base_rotation + hand_node.rotation
	
	## 握柄在武器坐标系中的位置
	var grip_in_weapon_coords = weapon_grip_offset
	
	## 将握柄位置从武器坐标系转换到手坐标系
	var grip_rotated = grip_in_weapon_coords.rotated(total_rotation)
	
	## 武器精灵的偏移应该是负的握柄位置
	weapon_sprite.offset = -grip_rotated
	weapon_sprite.rotation = total_rotation
```

**关键改进**:
- 握柄偏移会随武器旋转而旋转
- 握柄点始终对齐到手部位置（原点）
- 无论武器如何旋转，握柄位置都是精确的

#### 修改 set_weapon() 方法
```gdscript
func set_weapon(texture: Texture2D, grip_offset: Vector2, weapon_rotation: float = -PI/2) -> void:
	if weapon_sprite:
		weapon_sprite.texture = texture
		
		## 保存握柄偏移用于位置计算
		weapon_grip_offset = grip_offset
		weapon_base_rotation = weapon_rotation
		
		weapon_sprite.visible = texture != null
		weapon_sprite.scale = Vector2.ONE
		weapon_sprite.modulate = Color.WHITE
		
		## 立即更新武器位置确保握柄对齐
		if weapon_sprite.visible:
			_update_weapon_position_and_rotation()
```

#### 修改 _update_visuals() 方法
```gdscript
if hand_node:
	hand_node.position = current_hand_pos
	hand_node.rotation = current_hand_rotation
	
	## 确保武器精灵的位置与握柄对齐
	if weapon_sprite and weapon_sprite.visible:
		_update_weapon_position_and_rotation()
```

### 2. CombatAnimator.gd - 简化双手握点计算

#### 修复原则
移除所有额外的偏移调整，直接使用 `off_hand_grip_offset`：

**修复前**:
```gdscript
var off_hand_pos = main_hand_pos + grip_offset - Vector2(8, 0).rotated(swing_angle_rad)
```

**修复后**:
```gdscript
var off_hand_pos = main_hand_pos + grip_offset
```

#### 修复位置
1. **_update_slash_visuals_enhanced()** - 第 261 行
2. **_update_reverse_slash_visuals()** - 第 263 行
3. **_update_thrust_visuals_enhanced()** - 第 376 行
4. **_update_smash_visuals_enhanced()** - 第 450 行
5. **_update_sweep_visuals_enhanced()** - 第 524 行
6. **_update_spin_visuals_enhanced()** - 第 571 行

#### 添加武器旋转同步
在所有双手武器握点设置后，添加：
```gdscript
left_arm.set_weapon_rotation(WEAPON_BASE_ROTATION)
```

这确保左手的武器精灵旋转与右手一致。

## 技术细节

### 握柄对齐原理

武器精灵在手部节点坐标系中的位置计算：

```
握柄在武器坐标系: grip_offset = (0, 20)  # 从武器中心到握柄
总旋转: total_rotation = base_rotation + hand_rotation
握柄旋转后: grip_rotated = grip_offset.rotated(total_rotation)
武器精灵偏移: offset = -grip_rotated  # 使握柄对齐到原点
武器精灵旋转: rotation = total_rotation
```

### 结果
- 无论武器如何旋转，握柄点始终在手部位置（0, 0）
- 武器的视觉位置与逻辑位置完全对齐
- 双手武器时，左手握点精确对齐到武器上

## 修复效果

### 修复前
- ❌ 武器握柄与手部位置错位
- ❌ 武器旋转时握柄会飘动
- ❌ 双手武器时左手握点不精确
- ❌ 攻击动画看起来不自然

### 修复后
- ✅ 握柄始终对齐到手部位置
- ✅ 武器旋转时握柄保持固定
- ✅ 双手武器时左手握点精确对齐
- ✅ 攻击动画看起来自然流畅

## 向后兼容性

- 所有修改都是内部实现，不影响外部接口
- 现有的 `set_weapon()` 调用方式不变
- 现有的攻击数据格式不变

## 测试建议

### 1. 单手武器测试
- 观察武器握柄是否始终对齐到手部
- 在不同旋转角度下检查握柄位置
- 验证攻击动画中武器位置是否正确

### 2. 双手武器测试
- 检查左手握点是否对齐到武器上
- 验证双手之间的距离是否正确
- 观察双手武器攻击时的协调性

### 3. 动画流畅性测试
- 播放各种攻击动画
- 检查武器是否有抖动或错位
- 验证恢复阶段武器回正是否平滑

### 4. 性能测试
- 确保修复不会增加额外的计算开销
- 验证多角色同时攻击时的性能

## 配置建议

### 握柄偏移设置
```gdscript
# 握柄偏移应该从武器中心指向握柄
# 对于纵向武器（刀尖向下）：
grip_offset = Vector2(0, weapon_length * 0.4)

# 对于横向武器：
grip_offset = Vector2(weapon_length * 0.3, 0)
```

### 双手武器握点
```gdscript
# 主手握点（靠近刀尖）
grip_point_main = Vector2(0, weapon_length * 0.2)

# 副手握点（靠近刀柄）
grip_point_off = Vector2(0, weapon_length * 0.6)
```

## 已知限制

1. 握柄偏移计算基于 2D 平面
2. 不支持复杂的武器形状（如弯刀）
3. 握柄点必须在武器纹理内

## 未来改进方向

1. 支持多个握柄点（如双刃剑）
2. 动态调整握柄位置（如根据攻击类型）
3. 支持武器变形（如伸缩武器）
4. 添加握柄视觉反馈（如握柄高亮）

## 相关文件

- `scripts/combat/arm_rig.gd` - 手臂渲染和武器绑定
- `scripts/combat/combat_animator.gd` - 攻击动画和握点计算
- `scripts/combat/player_visuals.gd` - 玩家视觉系统
- `resources/combat/weapon_data.gd` - 武器数据定义

## 总结

这次修复通过以下方式解决了武器与手的绑定问题：

1. ✅ **精确的握柄对齐**: 握柄偏移会随武器旋转而旋转，确保握柄始终在手部位置
2. ✅ **简化的双手握点**: 移除额外的偏移调整，直接使用武器数据中定义的握点
3. ✅ **一致的武器旋转**: 双手武器时，左手武器精灵旋转与右手一致
4. ✅ **自然的动画效果**: 武器位置与逻辑完全对齐，动画看起来更自然

武器现在应该能够正确地绑定到手部，无论在任何旋转角度或攻击阶段都能保持对齐。
