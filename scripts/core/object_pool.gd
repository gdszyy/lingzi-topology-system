class_name ObjectPool
extends Node

## 通用对象池
## 管理可复用节点的创建和回收，避免频繁的 instantiate() 和 queue_free()
## 显著降低弹射物、VFX 等高频创建对象的性能开销

static var instance: ObjectPool = null

## 池存储: { scene_path: Array[Node] }
var _pools: Dictionary = {}

## 活跃对象追踪: { scene_path: Array[Node] }
var _active: Dictionary = {}

## 预加载的场景缓存: { scene_path: PackedScene }
var _scene_cache: Dictionary = {}

## 每个池的最大容量
var _pool_limits: Dictionary = {}

## 默认池容量
const DEFAULT_POOL_SIZE: int = 50

## 统计信息
var _stats: Dictionary = {
	"total_acquired": 0,
	"total_released": 0,
	"cache_hits": 0,
	"cache_misses": 0
}

func _ready() -> void:
	if instance == null:
		instance = self
	else:
		push_warning("[ObjectPool] 已存在实例，当前实例将被忽略")
		queue_free()
		return
	add_to_group("object_pool")

func _exit_tree() -> void:
	if instance == self:
		instance = null

## 预热池：预先创建指定数量的对象
## scene_path: 场景资源路径
## count: 预创建数量
## max_size: 池最大容量（0 表示使用默认值）
func warmup(scene_path: String, count: int, max_size: int = 0) -> void:
	_ensure_pool_exists(scene_path)
	
	if max_size > 0:
		_pool_limits[scene_path] = max_size
	
	var scene = _get_or_load_scene(scene_path)
	if scene == null:
		push_error("[ObjectPool] 无法加载场景: %s" % scene_path)
		return
	
	for i in range(count):
		if _pools[scene_path].size() >= _get_pool_limit(scene_path):
			break
		var node = scene.instantiate()
		_prepare_for_pool(node)
		_pools[scene_path].append(node)
	
	print("[ObjectPool] 预热完成: %s x%d (池大小: %d)" % [scene_path, count, _pools[scene_path].size()])

## 从池中获取一个对象
## scene_path: 场景资源路径
## 返回: 可用的节点实例
func acquire(scene_path: String) -> Node:
	_ensure_pool_exists(scene_path)
	
	var node: Node = null
	
	if _pools[scene_path].size() > 0:
		node = _pools[scene_path].pop_back()
		_stats.cache_hits += 1
	else:
		# 池为空，创建新实例
		var scene = _get_or_load_scene(scene_path)
		if scene == null:
			push_error("[ObjectPool] 无法加载场景: %s" % scene_path)
			return null
		node = scene.instantiate()
		_stats.cache_misses += 1
	
	_activate_node(node)
	
	if not _active.has(scene_path):
		_active[scene_path] = []
	_active[scene_path].append(node)
	
	_stats.total_acquired += 1
	return node

## 将对象归还到池中
## node: 要归还的节点
## scene_path: 场景资源路径（可选，如果不提供则自动查找）
func release(node: Node, scene_path: String = "") -> void:
	if node == null or not is_instance_valid(node):
		return
	
	# 如果未提供 scene_path，尝试自动查找
	if scene_path == "":
		scene_path = _find_scene_path_for_node(node)
		if scene_path == "":
			# 无法确定场景路径，直接销毁
			node.queue_free()
			return
	
	_ensure_pool_exists(scene_path)
	
	# 从活跃列表中移除
	if _active.has(scene_path):
		_active[scene_path].erase(node)
	
	# 检查池是否已满
	if _pools[scene_path].size() >= _get_pool_limit(scene_path):
		# 池已满，直接销毁
		node.queue_free()
		return
	
	# 如果节点有 reset_for_pool 方法，调用它进行状态重置
	if node.has_method("reset_for_pool"):
		node.reset_for_pool()
	
	_prepare_for_pool(node)
	_pools[scene_path].append(node)
	
	_stats.total_released += 1

## 根据节点查找其对应的场景路径
func _find_scene_path_for_node(node: Node) -> String:
	for path in _active:
		if node in _active[path]:
			return path
	return ""

## 释放指定池中的所有活跃对象
func release_all(scene_path: String) -> void:
	if not _active.has(scene_path):
		return
	
	var active_copy = _active[scene_path].duplicate()
	for node in active_copy:
		release(node, scene_path)

## 清空指定池
func clear_pool(scene_path: String) -> void:
	if _pools.has(scene_path):
		for node in _pools[scene_path]:
			if is_instance_valid(node):
				node.queue_free()
		_pools[scene_path].clear()
	
	if _active.has(scene_path):
		for node in _active[scene_path]:
			if is_instance_valid(node):
				node.queue_free()
		_active[scene_path].clear()

## 清空所有池
func clear_all() -> void:
	for scene_path in _pools.keys():
		clear_pool(scene_path)
	_pools.clear()
	_active.clear()
	_scene_cache.clear()

## 获取统计信息
func get_stats() -> Dictionary:
	var pool_sizes: Dictionary = {}
	var active_sizes: Dictionary = {}
	
	for path in _pools:
		pool_sizes[path] = _pools[path].size()
	for path in _active:
		active_sizes[path] = _active[path].size()
	
	return {
		"pool_sizes": pool_sizes,
		"active_sizes": active_sizes,
		"total_acquired": _stats.total_acquired,
		"total_released": _stats.total_released,
		"cache_hits": _stats.cache_hits,
		"cache_misses": _stats.cache_misses,
		"hit_rate": float(_stats.cache_hits) / maxf(float(_stats.cache_hits + _stats.cache_misses), 1.0)
	}

## 确保池存在
func _ensure_pool_exists(scene_path: String) -> void:
	if not _pools.has(scene_path):
		_pools[scene_path] = []
	if not _active.has(scene_path):
		_active[scene_path] = []

## 获取或加载场景
func _get_or_load_scene(scene_path: String) -> PackedScene:
	if _scene_cache.has(scene_path):
		return _scene_cache[scene_path]
	
	var scene = load(scene_path) as PackedScene
	if scene != null:
		_scene_cache[scene_path] = scene
	return scene

## 获取池容量限制
func _get_pool_limit(scene_path: String) -> int:
	return _pool_limits.get(scene_path, DEFAULT_POOL_SIZE)

## 准备节点进入池（停用）
func _prepare_for_pool(node: Node) -> void:
	# 从场景树中移除（但不销毁）
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	
	# 停用处理
	node.set_process(false)
	node.set_physics_process(false)
	
	if node is Node2D:
		(node as Node2D).visible = false
	
	if node is Area2D:
		(node as Area2D).monitoring = false
		(node as Area2D).monitorable = false

## 激活节点（从池中取出时）
func _activate_node(node: Node) -> void:
	node.set_process(true)
	node.set_physics_process(true)
	
	if node is Node2D:
		(node as Node2D).visible = true
	
	if node is Area2D:
		(node as Area2D).monitoring = true
		(node as Area2D).monitorable = true
