class_name SpatialGrid
extends Node

## 空间哈希网格
## 用于高效的空间查询（索敌、范围检测等）
## 将 O(n) 的线性搜索优化为接近 O(1) 的网格查询

static var instance: SpatialGrid = null

## 网格单元大小（像素）
var cell_size: float = 128.0

## 网格存储: { Vector2i(cell_x, cell_y): Array[Node2D] }
var _grid: Dictionary = {}

## 实体到单元格的映射: { Node2D: Vector2i }
var _entity_cells: Dictionary = {}

## 分组索引: { group_name: Array[Node2D] }
var _group_index: Dictionary = {}

## 统计信息
var _stats: Dictionary = {
	"total_queries": 0,
	"total_updates": 0,
	"entities_tracked": 0
}

func _ready() -> void:
	if instance == null:
		instance = self
	else:
		push_warning("[SpatialGrid] 已存在实例，当前实例将被忽略")
		queue_free()
		return
	add_to_group("spatial_grid")

func _exit_tree() -> void:
	if instance == self:
		instance = null

## 注册实体到网格中
## entity: 要注册的 Node2D 实体
## group: 实体所属的分组（如 "enemies", "allies"）
func register_entity(entity: Node2D, group: String = "") -> void:
	if entity == null:
		return
	
	var cell = _position_to_cell(entity.global_position)
	_add_to_cell(cell, entity)
	_entity_cells[entity] = cell
	
	if group != "":
		if not _group_index.has(group):
			_group_index[group] = []
		if entity not in _group_index[group]:
			_group_index[group].append(entity)
	
	_stats.entities_tracked += 1

## 从网格中注销实体
func unregister_entity(entity: Node2D) -> void:
	if entity == null:
		return
	
	if _entity_cells.has(entity):
		var old_cell = _entity_cells[entity]
		_remove_from_cell(old_cell, entity)
		_entity_cells.erase(entity)
	
	# 从所有分组中移除
	for group in _group_index:
		_group_index[group].erase(entity)
	
	_stats.entities_tracked -= 1

## 更新实体位置（应在实体移动后调用）
func update_entity(entity: Node2D) -> void:
	if entity == null or not is_instance_valid(entity):
		unregister_entity(entity)
		return
	
	var new_cell = _position_to_cell(entity.global_position)
	
	if _entity_cells.has(entity):
		var old_cell = _entity_cells[entity]
		if old_cell != new_cell:
			_remove_from_cell(old_cell, entity)
			_add_to_cell(new_cell, entity)
			_entity_cells[entity] = new_cell
	else:
		# 实体尚未注册，自动注册
		_add_to_cell(new_cell, entity)
		_entity_cells[entity] = new_cell
	
	_stats.total_updates += 1

## 批量更新指定分组中所有实体的位置
func update_group(group: String) -> void:
	if not _group_index.has(group):
		return
	
	var entities = _group_index[group].duplicate()
	for entity in entities:
		if is_instance_valid(entity):
			update_entity(entity)
		else:
			_group_index[group].erase(entity)

## 查找指定位置附近、指定半径内的所有实体
## position: 查询中心位置
## radius: 查询半径
## group: 可选的分组过滤（空字符串表示不过滤）
## exclude: 要排除的实体列表
## 返回: 在范围内的实体数组
func find_in_radius(position: Vector2, radius: float, group: String = "", exclude: Array = []) -> Array[Node2D]:
	_stats.total_queries += 1
	
	var results: Array[Node2D] = []
	var radius_sq = radius * radius
	
	# 计算需要检查的单元格范围
	var min_cell = _position_to_cell(position - Vector2(radius, radius))
	var max_cell = _position_to_cell(position + Vector2(radius, radius))
	
	for cx in range(min_cell.x, max_cell.x + 1):
		for cy in range(min_cell.y, max_cell.y + 1):
			var cell_key = Vector2i(cx, cy)
			if not _grid.has(cell_key):
				continue
			
			for entity in _grid[cell_key]:
				if not is_instance_valid(entity):
					continue
				if entity in exclude:
					continue
				if group != "" and not _is_in_group(entity, group):
					continue
				
				var dist_sq = position.distance_squared_to(entity.global_position)
				if dist_sq <= radius_sq:
					results.append(entity)
	
	return results

## 查找指定位置最近的实体
## position: 查询中心位置
## group: 可选的分组过滤
## max_radius: 最大搜索半径（0 表示无限制）
## exclude: 要排除的实体列表
## 返回: 最近的实体，如果没有找到则返回 null
func find_nearest(position: Vector2, group: String = "", max_radius: float = 0.0, exclude: Array = []) -> Node2D:
	_stats.total_queries += 1
	
	var nearest: Node2D = null
	var nearest_dist_sq = INF
	
	if max_radius > 0:
		# 使用网格加速搜索
		var min_cell = _position_to_cell(position - Vector2(max_radius, max_radius))
		var max_cell = _position_to_cell(position + Vector2(max_radius, max_radius))
		var max_radius_sq = max_radius * max_radius
		
		for cx in range(min_cell.x, max_cell.x + 1):
			for cy in range(min_cell.y, max_cell.y + 1):
				var cell_key = Vector2i(cx, cy)
				if not _grid.has(cell_key):
					continue
				
				for entity in _grid[cell_key]:
					if not is_instance_valid(entity):
						continue
					if entity in exclude:
						continue
					if group != "" and not _is_in_group(entity, group):
						continue
					
					var dist_sq = position.distance_squared_to(entity.global_position)
					if dist_sq <= max_radius_sq and dist_sq < nearest_dist_sq:
						nearest_dist_sq = dist_sq
						nearest = entity
	else:
		# 无半径限制，搜索分组索引中的所有实体
		var search_entities: Array = []
		if group != "" and _group_index.has(group):
			search_entities = _group_index[group]
		else:
			for cell_key in _grid:
				search_entities.append_array(_grid[cell_key])
		
		for entity in search_entities:
			if not is_instance_valid(entity):
				continue
			if entity in exclude:
				continue
			
			var dist_sq = position.distance_squared_to(entity.global_position)
			if dist_sq < nearest_dist_sq:
				nearest_dist_sq = dist_sq
				nearest = entity
	
	return nearest

## 查找指定位置最近的 N 个实体
func find_nearest_n(position: Vector2, count: int, group: String = "", max_radius: float = 0.0) -> Array[Node2D]:
	var all_in_radius = find_in_radius(position, max_radius if max_radius > 0 else 10000.0, group)
	
	# 按距离排序
	all_in_radius.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return position.distance_squared_to(a.global_position) < position.distance_squared_to(b.global_position)
	)
	
	# 取前 N 个
	if all_in_radius.size() > count:
		all_in_radius.resize(count)
	
	return all_in_radius

## 获取指定分组中的所有实体
func get_group_entities(group: String) -> Array[Node2D]:
	if not _group_index.has(group):
		return []
	
	# 清理无效实体
	var valid_entities: Array[Node2D] = []
	for entity in _group_index[group]:
		if is_instance_valid(entity):
			valid_entities.append(entity)
	_group_index[group] = valid_entities
	
	return valid_entities

## 清空网格
func clear() -> void:
	_grid.clear()
	_entity_cells.clear()
	_group_index.clear()
	_stats.entities_tracked = 0

## 获取统计信息
func get_stats() -> Dictionary:
	return {
		"entities_tracked": _stats.entities_tracked,
		"total_queries": _stats.total_queries,
		"total_updates": _stats.total_updates,
		"grid_cells": _grid.size(),
		"groups": _group_index.keys()
	}

# ============================================================
# 内部方法
# ============================================================

func _position_to_cell(position: Vector2) -> Vector2i:
	return Vector2i(
		floori(position.x / cell_size),
		floori(position.y / cell_size)
	)

func _add_to_cell(cell: Vector2i, entity: Node2D) -> void:
	if not _grid.has(cell):
		_grid[cell] = []
	if entity not in _grid[cell]:
		_grid[cell].append(entity)

func _remove_from_cell(cell: Vector2i, entity: Node2D) -> void:
	if _grid.has(cell):
		_grid[cell].erase(entity)
		if _grid[cell].is_empty():
			_grid.erase(cell)

func _is_in_group(entity: Node2D, group: String) -> bool:
	if _group_index.has(group):
		return entity in _group_index[group]
	return entity.is_in_group(group)
