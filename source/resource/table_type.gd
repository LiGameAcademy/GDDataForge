extends Resource
class_name TableType

## 表格名称
@export var table_name: StringName
## 表格文件路径列表
@export_file var table_paths: PackedStringArray
## 表格描述
@export_multiline var description: String
## 主键字段名
@export var primary_key: String = "ID"
## 是否启用缓存
@export var enable_cache: bool = true
## 表格验证规则
@export var validation_rules: Dictionary = {}
## 表格缓存
@export_storage var cache: Dictionary = {}
## 加载状态
@export_storage var is_loaded: bool = false

## 初始化函数
func _init(
		p_table_name: String = "", 
		p_table_paths: Variant = [], 
		p_description: String = "", 
		p_primary_key: String = "ID", 
		p_enable_cache: bool = true) -> void:
	table_name = p_table_name
	description = p_description
	primary_key = p_primary_key
	enable_cache = p_enable_cache
	
	# 处理表格路径参数
	if p_table_paths is String:
		# 如果是单个路径字符串，转换为数组
		table_paths = [p_table_paths]
	elif p_table_paths is Array:
		# 如果是数组，确保所有元素都是字符串
		table_paths = []
		for path in p_table_paths:
			if path is String:
				table_paths.append(path)
	else:
		table_paths = []

## 获取缓存数据表行
func get_cache_item(item_id : String) -> Dictionary:
	if cache.has(item_id):
		return cache[item_id]
	push_warning("未找到缓存数据表行:%s" % item_id)
	return {}

## 验证表格数据是否有效
func validate_data(data: Dictionary) -> bool:
	if data.is_empty():
		push_error("数据为空")
		return false
	if not data.has(primary_key):
		push_error("缺少主键：%s" % primary_key)
		return false
	# 应用验证规则
	for field in validation_rules:
		var rule = validation_rules[field]
		if not _validate_field(data, field, rule):
			return false
	return true

## 验证字段
func _validate_field(data: Dictionary, field: String, rule: Dictionary) -> bool:
	if not data.has(field):
		if rule.get("required", false):
			push_error("缺少必需字段：%s" % field)
			return false
		return true
		
	var value = data[field]
	
	# 类型检查
	if rule.has("type"):
		var type_name = rule["type"]
		if not _validate_type(value, type_name):
			push_error("字段类型错误：%s，期望类型：%s" % [field, type_name])
			return false
	
	# 范围检查
	if rule.has("range"):
		var range_value = rule["range"]
		if not _validate_range(value, range_value):
			push_error("字段值超出范围：%s" % field)
			return false
	
	# 枚举检查
	if rule.has("enum"):
		var enum_values = rule["enum"]
		if not enum_values.has(value):
			push_error("字段值不在枚举范围内：%s" % field)
			return false
	
	return true

## 验证类型
func _validate_type(value: Variant, type_name: String) -> bool:
	match type_name:
		"int": return value is int
		"float": return value is float
		"string": return value is String
		"bool": return value is bool
		"array": return value is Array
		"dictionary": return value is Dictionary
		"vector2": return value is Vector2
		"vector3": return value is Vector3
		_: return true

## 验证范围
func _validate_range(value: Variant, range_value: Dictionary) -> bool:
	if range_value.has("min") and value < range_value["min"]:
		return false
	if range_value.has("max") and value > range_value["max"]:
		return false
	return true
