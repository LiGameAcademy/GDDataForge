extends Node

## 数据表管理器

const DataLoader = preload("res://addons/li_data_manager/source/data_loader.gd")
const CsvLoader = preload("res://addons/li_data_manager/source/data_loader/csv_loader.gd")
const JsonLoader = preload("res://addons/li_data_manager/source/data_loader/json_loader.gd")

## 是否启用线程加载
@export var enable_thread: bool = true

## 数据表加载器
var _data_loader_factory : Dictionary[String, DataLoader] = {
	"csv": CsvLoader.new(),
	"json": JsonLoader.new(),
}

var _table_types : Dictionary[String, TableType] = {}
## 数据模型
var _model_types: Dictionary[String, ModelType] = {}

## 加载线程
var _loading_thread: Thread
var _loading_mutex: Mutex
var _loading_semaphore: Semaphore
var _loading_queue: Array[Dictionary]
var _is_loading: bool = false

## 批量加载完成信号
signal batch_load_completed(results: Dictionary)
## 单个文件加载完成信号
signal load_completed(table_name : String)

func _init() -> void:
	if enable_thread:
		_loading_mutex = Mutex.new()
		_loading_semaphore = Semaphore.new()
		_loading_queue = []
		_start_loading_thread()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and enable_thread:
		_stop_loading_thread()

## 注册数据表加载器
func register_data_loader(type: String, loader: DataLoader) -> void:
	_data_loader_factory[type] = loader

## 移除数据表加载器
func unregister_data_loader(type: String) -> void:
	_data_loader_factory.erase(type)

## 获取数据表加载器
func get_data_loader(type: String) -> DataLoader:
	return _data_loader_factory.get(type, null)

## 清除模型
func clear_model_types() -> void:
	_model_types.clear()

## 清除表格
func clear_table_types() -> void:
	_table_types.clear()

func load_data_table(table_type: TableType, completed_callback: Callable = Callable()) -> Dictionary:
	if enable_thread:
		# 异步加载
		_loading_mutex.lock()
		_loading_queue.append({
			"table_type": table_type,
			"callback": completed_callback
		})
		_loading_mutex.unlock()
		_loading_semaphore.post()
		return {}
	else:
		# 同步加载
		# var result = _load_data_type(table_type)
		_load_data_type(table_type)
		if completed_callback.is_valid():
			completed_callback.call(table_type.table_name)
		return table_type.cache

func load_data_table_batch(
		table_types: Array[TableType], 
		callback: Callable = Callable(),
		progress_callback: Callable = Callable()) -> Array[String]:
	if enable_thread:
		# 异步加载
		var total = table_types.size()
		var results : Array[String]
		var shared_data = {"current": 0}  # 使用字典来共享计数器
		
		if total == 0:
			if callback.is_valid():
				callback.call(results)
			batch_load_completed.emit(results)
			return results
		
		for table_type in table_types:
			load_data_table(table_type, func(table_name: String) -> void:
				shared_data.current += 1  # 使用共享计数器
				results.append(table_name)
				
				if progress_callback.is_valid():
					call_deferred("_emit_progress", progress_callback, shared_data.current, total)
				
				call_deferred("emit_signal", "load_completed", table_type.table_name)
				
				if shared_data.current >= total:
					print("所有数据表加载完成，结果数：", results.size())
					if callback.is_valid():
						call_deferred("_emit_callback", callback, results)
					call_deferred("emit_signal", "batch_load_completed", results)
			)
		return results
	else:
		# 同步加载
		var results : Array[String]
		var total = table_types.size()
		for i in range(total):
			var table_type = table_types[i]
			_load_data_type(table_type)
			#results[table_type] = table_type.cache
			results.append(table_type.table_name)
			if progress_callback.is_valid():
				progress_callback.call(i + 1, total)
		if callback.is_valid():
			callback.call(results)
		batch_load_completed.emit(results)
		return results

## 检查某个路径的数据表是否已缓存
func has_data_table_cached(table_name: String) -> bool:
	if not _table_types.has(table_name): return false
	if not _table_types[table_name].is_loaded: return false
	return true

## 获取已缓存的数据表
func get_table_data(table_name: String) -> Dictionary:
	var config : Dictionary
	if _table_types.has(table_name):
		config = _table_types[table_name].cache
	return config

## 获取数据表项
func get_table_item(table_name: String, item_id: String) -> Dictionary:
	var config : Dictionary = get_table_data(table_name)
	if not config.is_empty():
		return config[item_id]
	return {}

## 加载模型
func load_model(model: ModelType, completed_callback: Callable = Callable()) -> void:
	if _model_types.has(model.model_name): return
	_model_types[model.model_name] = model
	load_data_table(model.table, completed_callback)

## 批量加载模型
func load_models(models: Array[ModelType], 
		completed_callback: Callable = Callable(), 
		progress_callback: Callable = Callable()) -> void:
	for model in models:
		_model_types[model.model_name] = model
	var tables : Array[TableType] = []
	for model in models:
		tables.append(model.table)
	load_data_table_batch(tables, completed_callback, progress_callback)

## 获取模型
func get_model_type(model_name: String) -> ModelType:
	return _model_types.get(model_name, null)

## 获取数据模型
func get_data_model(model_name: String, item_id: String) -> Resource:
	var model_type : ModelType = get_model_type(model_name)
	if not model_type:
		push_error("模型 %s 不存在" % model_name)
	var table_type : TableType = model_type.table
	var data : Dictionary = get_table_item(table_type.table_name, item_id)
	var model : Resource = model_type.create_instance(data)
	return model

## 获取所有数据模型
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
func _load_data_type(table_type: TableType) -> Dictionary:
	for path in table_type.table_paths:
		var data = _load_data_file(path)
		table_type.cache.merge(data, true)
	_table_types[table_type.table_name] = table_type
	return table_type.cache

## 加载数据表文件
func _load_data_file(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		push_error("JSON file not found: %s" % file_path)
		return {}
	var loader := _get_file_loader(file_path)
	if not loader:
		push_error("无法加载文件:%s" % file_path)
		return {}
	var data = loader.load_datatable(file_path)
	return data

## 启动加载线程
func _start_loading_thread() -> void:
	_loading_thread = Thread.new()
	_is_loading = true
	_loading_thread.start(_loading_thread_function)

## 停止加载线程
func _stop_loading_thread() -> void:
	_is_loading = false
	_loading_semaphore.post()  # 唤醒线程以便退出
	_loading_thread.wait_to_finish()

## 加载线程函数
func _loading_thread_function() -> void:
	while _is_loading:
		_loading_semaphore.wait()  # 等待加载请求
		if not _is_loading:
			break
			
		# 获取下一个加载任务
		_loading_mutex.lock()
		var task = _loading_queue.pop_front() if not _loading_queue.is_empty() else null
		_loading_mutex.unlock()
		
		if task:
			var table_type : TableType = task.table_type
			_load_data_type(table_type)
			# 即使加载失败也调用回调
			if task.callback.is_valid():
				task.callback.call(table_type.table_name)

## 根据数据表文件路径后缀名选择加载器
func _get_file_loader(path: String) -> DataLoader:
	var ext = path.get_extension().to_lower()
	var loader : DataLoader
	if _data_loader_factory.has(ext):
		loader = _data_loader_factory[ext]
	else:
		push_error("未找到合适的数据表加载器：%s" % ext)
	return loader

## 发送进度回调
func _emit_progress(callback: Callable, current: int, total: int) -> void:
	if callback.is_valid():
		callback.call(current, total)

## 发送完成回调
func _emit_callback(callback: Callable, results: Array) -> void:
	if callback.is_valid():
		callback.call(results)
