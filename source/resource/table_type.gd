extends Resource
class_name TableType

## 表格名称
@export var table_name: StringName
## 表格文件路径列表
@export_file var table_paths: Array[String]
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

## 验证数据
## [return] 错误列表
func validate_data() -> Array[String]:
	var errors: Array[String] = []
	
	for row_id in cache:
		var row_data = cache[row_id]
		_validate_row(row_data)
	return errors

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

## 验证单行数据
func _validate_row(row_data: Dictionary,) -> Array[String]:
	var errors : Array[String]
	for field in row_data:
		var value = row_data[field]
		var rule = validation_rules[field]
		var error := _validate_rule(field, value, rule, row_data)
		if error != null:
			errors.append_array(error)
	return errors

## 验证单个数据
## [param] field 字段名
## [param] value 字段值
## [param] rule 规则
## [return] 错误信息
func _validate_rule(field: String, value: Variant, rule: Dictionary, data_row: Dictionary) -> Array[String]:
	var rule_type = rule.type
	var rule_params = rule.params
	var errors : Array[String]
	match rule_type:
		"required":
			if value == null or (value is String and value.is_empty()):
				var error = "fild {0} is not required by {1} is {2}" .format([field, data_row.get(primary_key), value])
				errors.append(error)
		"unique":
			pass
		"primary_key":
			if value == null or (value is String and value.is_empty()):
				var error = "fild {0} is not primary_key by {1} is {2}" .format([field, data_row.get(primary_key), value])
				errors.append(error)
		"min_value":
			if value != null and value < float(rule.params.value):
				var error = "fild {0} is not min_value by {1} is {2}" .format([field, data_row.get(primary_key), value])
				errors.append(error)
		"max_value":
			if value != null and value > float(rule.params.value):
				var error = "fild {0} is not max_value by {1} is {2}" .format([field, data_row.get(primary_key), value])
				errors.append(error)
		"range":
			if value != null:
				if value < rule.params.min or value > rule.params.max:
					var error = "fild {0} is not range by {1} is {2}" .format([field, data_row.get(primary_key), value])
					errors.append(error)
		"regex":
			if value != null and value is String:
				var regex = RegEx.new()
				regex.compile(rule.params.pattern)
				if not regex.search(value):
					var error = "fild {0} is not regex by {1} is {2}" .format([field, data_row.get(primary_key), value])
					errors.append(error)
		"length":
			if value != null and value is String:
				var length = value.length()
				if length < rule.params.min or length > rule.params.max:
					var error = "fild {0} is not length by {1} is {2}" .format([field, data_row.get(primary_key), value])
					errors.append(error)
		"prefix":
			if value != null and value is String:
				if not value.begins_with(rule.params.value):
					var error = "fild {0} is not prefix by {1} is {2}" .format([field, data_row.get(primary_key), value])
					errors.append(error)
		"suffix":
			if value != null and value is String:
				if not value.ends_with(rule.params.value):
					var error = "fild {0} is not suffix by {1} is {2}" .format([field, data_row.get(primary_key), value])
					errors.append(error)
		"enum":
			if value != null and not rule.params.values.has(value):
				var error = "fild {0} is not enum by {1} is {2}" .format([field, data_row.get(primary_key), value])
				errors.append(error)
		"foreign_key":
			# 验证外键
			if value != null:
				DataManager.validate_foreign_key(field, value, data_row)
		"custom":
			if value != null:
				DataManager.validate_custom(field, value, data_row)
	return errors

## 检查唯一性约束
func _check_unique_constraint(table_type: TableType, field: String, row_data: Dictionary) -> bool:
	var value = row_data.get(field)
	if value == null:
		return true
	
	var count = 0
	for other_id in table_type.cache:
		var other_data = table_type.cache[other_id]
		if other_data.get(field) == value:
			count += 1
			if count > 1:  # 允许自身
				return false
	
	return true

## 检查外键约束
func _check_foreign_key_constraint(params: Dictionary, value: Variant) -> bool:
	if value == null:
		return true
	
	var ref_table = params.get("table")
	var ref_field = params.get("field", "ID")
	
	if not _table_types.has(ref_table):
		push_warning("引用的数据表不存在: %s" % ref_table)
		return false
	
	var ref_table_type = _table_types[ref_table]
	if not ref_table_type.is_loaded:
		push_warning("引用的数据表未加载: %s" % ref_table)
		return false
	
	for ref_id in ref_table_type.cache:
		var ref_data = ref_table_type.cache[ref_id]
		if ref_data.get(ref_field) == value:
			return true
	
	return false
