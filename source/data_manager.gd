extends Node

## 数据表管理器

const DataLoader = preload("res://addons/GDDataForge/source/data_loader.gd")
const CsvLoader = preload("res://addons/GDDataForge/source/data_loader/csv_loader.gd")
const JsonLoader = preload("res://addons/GDDataForge/source/data_loader/json_loader.gd")

## 数据表加载器
var _data_loader_factory : Dictionary[String, DataLoader] = {
	"csv": CsvLoader.new(),
	"json": JsonLoader.new()
}

## 已注册的模型类型
var _model_types: Dictionary[String, ModelType] = {}
var _table_types: Dictionary[String, TableType] = {}

## 线程池
var _thread_pool: ThreadPool
## 加载中的模型
var _loading_types: Dictionary = {}
## 加载中的表格
var _batch_results: Dictionary = {}

## 加载完成信号
signal batch_load_completed(results: Dictionary)
signal load_completed(table_name: String)

func _init() -> void:
	_thread_pool = ThreadPool.new()
	add_child(_thread_pool)
	_thread_pool.task_completed.connect(_on_table_loaded)
	_thread_pool.all_tasks_completed.connect(_on_batch_completed)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_thread_pool.shutdown()

## 注册数据表加载器
## [param type] 加载器类型
## [param loader] 加载器
func register_data_loader(type: String, loader: DataLoader) -> void:
	_data_loader_factory[type] = loader

## 移除数据表加载器
## [param type] 加载器类型
func unregister_data_loader(type: String) -> void:
	_data_loader_factory.erase(type)

## 获取数据表加载器
## [param type] 加载器类型
## [return] 加载器
func get_data_loader(type: String) -> DataLoader:
	return _data_loader_factory.get(type, null)

## 清除模型
func clear_model_types() -> void:
	_model_types.clear()

## 清除表格
func clear_table_types() -> void:
	_table_types.clear()

## 加载数据表
## [param table_type] 数据表类型
## [param completed_callback] 完成回调
## [return] 返回加载的数据表名字数组
func load_data_table(table_type: TableType, completed_callback: Callable = Callable()) -> Dictionary:
	if table_type.is_loaded:
		if completed_callback.is_valid():
			completed_callback.call(table_type.table_name)
		return table_type.cache
	
	# 创建加载任务
	var task_id = "load_table_%s" % table_type.table_name
	_loading_types[task_id] = {
		"table_type": table_type,
		"completed_callback": completed_callback
	}
	
	_thread_pool.add_task(
		task_id, 
		_load_data_type,
		[table_type],
		1) 
	return {}

## 批量加载数据表
## [param table_types] 数据表类型数组
## [param callback] 完成回调,返回加载的数据表
## [param progress_callback] 进度回调,返回当前加载的数据表数和总数据表数
## [return] 返回加载的数据表名字数组
func load_data_tables(
		table_types: Array[TableType], 
		callback: Callable = Callable(),
		progress_callback: Callable = Callable()) -> Array[String]:
	# 异步加载
	var total : int = table_types.size()
	var results : Array[String]
	
	if total == 0:
		# 没有需要加载的数据表，立刻返回
		if callback.is_valid():
			callback.call(results)
		batch_load_completed.emit(results)
		return results
	
	# 记录加载进度
	var progress_data = {"current": 0, "total": total}

	for table_type in table_types:
		if table_type.is_loaded:
			progress_data.current += 1
			results.append(table_type.table_name)
			continue
		
		# 创建加载任务
		load_data_table(table_type, 
		func(table_name: String) -> void:
			progress_data.current += 1  # 使用共享计数器
			results.append(table_name)
			
			if progress_callback.is_valid():
				progress_callback.call(progress_data.current, progress_data.total)
			
			call_deferred("emit_signal", "load_completed", table_type.table_name)
			
			if progress_data.current >= total:
				print("所有数据表加载完成，结果数：", results.size())
				if callback.is_valid():
					call_deferred("_emit_callback", callback, results)
				call_deferred("emit_signal", "batch_load_completed", results)
		)
	return results

## 检查某个路径的数据表是否已缓存
## [param table_name] 数据表名称
## [return] 是否已缓存
func has_data_table_cached(table_name: String) -> bool:
	if not _table_types.has(table_name): return false
	if not _table_types[table_name].is_loaded: return false
	return true

## 获取已缓存的数据表
## [param table_name] 数据表名称
## [return] 数据表配置
func get_table_data(table_name: String) -> Dictionary:
	var config : Dictionary
	if _table_types.has(table_name):
		config = _table_types[table_name].cache
	return config

## 获取数据表项
## [param table_name] 数据表名称
## [param item_id] 项ID
## [return] 项配置
func get_table_item(table_name: String, item_id: String) -> Dictionary:
	var data : Dictionary = get_table_data(table_name)
	if data.is_empty(): 
		push_error("数据表 %s 不存在" % table_name)
		return {}
	if not data.has(item_id):
		push_error("数据表 %s 中不存在项 %s" % [table_name, item_id])
		return {}
	return data.get(item_id)

## 加载模型
## [param model] 模型配置
## [param completed_callback] 完成回调, 返回模型对象
func load_model(model: ModelType, completed_callback: Callable = Callable()) -> void:
	if _model_types.has(model.model_name): 
		push_warning("模型 %s 已存在" % model.model_name)
		return
	_model_types[model.model_name] = model
	load_data_table(model.table, completed_callback)

## 批量加载模型
## [param models] 模型数组
## [param completed_callback] 完成回调
## [param progress_callback] 进度回调
func load_models(models: Array[ModelType], 
		completed_callback: Callable = Callable(), 
		progress_callback: Callable = Callable()) -> void:
	# 注册所有模型
	for model in models:
		_model_types[model.model_name] = model
	var tables : Array[TableType] = []
	for model in models:
		if model.table and not model.table.is_loaded:
			tables.append(model.table)
	load_data_tables(tables, completed_callback, progress_callback)

## 获取模型
## [param model_name] 模型名称
## [return] 模型配置
func get_model_type(model_name: String) -> ModelType:
	return _model_types.get(model_name, null)

## 获取数据模型
## [param model_name] 模型名称
## [param item_id] 项ID
## [return] 数据模型
func get_data_model(model_name: String, item_id: String) -> Resource:
	var model_type : ModelType = get_model_type(model_name)
	if not model_type:
		push_error("模型 %s 不存在" % model_name)
		return null
	var table_type : TableType = model_type.table
	var data : Dictionary = get_table_item(table_type.table_name, item_id)
	var model : Resource = model_type.create_instance(data)
	return model

## 获取所有数据模型
## [param model_name] 模型名称
## [return] 数据模型数组
func get_all_data_models(model_name: String) -> Array[Resource]:
	var models : Array[Resource] = []
	var model_type : ModelType = get_model_type(model_name)
	if not model_type:
		push_error("模型 %s 不存在" % model_name)
	var table_type : TableType = model_type.table
	for item_id in table_type.cache:
		var data : Dictionary = get_table_item(table_type.table_name, item_id)
		var model : Resource = model_type.create_instance(data)
		models.append(model)
	return models

## 加载数据表对象
## [param table_type] 数据表类型
## [return] 数据表对象
func _load_data_type(table_type: TableType) -> Dictionary:
	for path in table_type.table_paths:
		var data = _load_data_file(path)
		table_type.cache.merge(data, true)
	_table_types[table_type.table_name] = table_type
	return table_type.cache

## 加载数据表文件
## [param file_path] 文件路径
## [return] 数据表
func _load_data_file(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		push_error("file not found: %s" % file_path)
		return {}
	var loader := _get_file_loader(file_path)
	if not loader:
		push_error("无法加载文件:%s" % file_path)
		return {}
	var data = loader.load_datatable(file_path)
	return data

## 根据数据表文件路径后缀名选择加载器
## [param path] 文件路径
## [return] 加载器
func _get_file_loader(path: String) -> DataLoader:
	var ext = path.get_extension().to_lower()
	var loader : DataLoader
	if _data_loader_factory.has(ext):
		loader = _data_loader_factory[ext]
	else:
		push_error("未找到合适的数据表加载器：%s" % ext)
	return loader

## 发送进度回调
## [param callback] 回调函数
## [param current] 当前进度
## [param total] 总进度
func _emit_progress(callback: Callable, current: int, total: int) -> void:
	if callback.is_valid():
		callback.call(current, total)

## 发送完成回调
## [param callback] 回调函数
## [param results] 结果
func _emit_callback(callback: Callable, results: Array) -> void:
	if callback.is_valid():
		callback.call(results)

## 表格加载完成回调
## [param task_id] 任务ID
## [param result] 结果
func _on_table_loaded(task_id: String, result: Variant) -> void:
	var task_info := _loading_types.get(task_id)
	if not task_info: 
		push_error("数据表 %s 加载失败" % task_id)
		return

	var table_type : TableType = task_info.get("table_type")
	if not table_type: 
		push_error("数据表 %s 加载失败" % table_type.table_name)
		return
	var callback = task_info.get("completed_callback")
		
	# 更新缓存
	table_type.cache = result
	table_type.is_loaded = true
	_table_types[table_type.table_name] = table_type
	_batch_results[table_type.table_name] = result

	print("数据表 %s 加载完成" % table_type.table_name)

	# 发送完成回调
	if callback and callback.is_valid():
		callback.call(table_type.table_name)

	_loading_types.erase(task_id)

func _on_batch_completed() -> void:
	if not _batch_results.is_empty():
		batch_load_completed.emit(_batch_results)
		_batch_results.clear()
