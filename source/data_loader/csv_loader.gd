extends "res://addons/GDDataForge/source/data_loader.gd"

## 数据类型处理器
var _parsers : Dictionary[String, Callable] = {
	"string": _parse_string,
	"int": _parse_int,
	"float": _parse_float,
	"bool": _parse_bool,
	"vector2": _parse_vector2,
	"resource": _parse_resource,
	"dictionary": _parse_dictionary,
}

## 重写加载单一数据表，这里对CSV文件数据行格式化
func load_datatable(table_path: StringName) -> Dictionary:
	var file := FileAccess.open(table_path, FileAccess.READ)
	var ok := FileAccess.get_open_error()
	if ok != OK: 
		push_error("未能正确打开文件！")
	var _file_data : Dictionary = {}
	# CSV数据解析
	var data_names : PackedStringArray = file.get_csv_line(",")					# 第1行是数据名称字段
	var _dec : PackedStringArray = file.get_csv_line(",")						# 第2行是数据注释字段
	var data_types : PackedStringArray = file.get_csv_line(",")					# 第3行是数据类型字段
	while not file.eof_reached():
		var row : PackedStringArray = file.get_csv_line(",")				# 每行的数据，如果为空则跳过
		if row.is_empty(): continue
		var row_data := {}
		for index: int in row.size():
			# 遍历当前行的每一列
			var data_name : StringName = data_names[index]
			if data_name.is_empty(): continue
			var data_type : StringName = data_types[index]
			if data_type.is_empty(): continue
			# row_data[data_name] = row[index]
			row_data[data_name] = _parse_value(row[index], data_type)
		if not row_data.is_empty() and not row_data.ID.is_empty(): 
			_file_data[StringName(row_data.ID)] = row_data
	return _file_data

## 注册数据类型处理器
func register_parser(type: StringName, parser: Callable) -> void:
	_parsers[type] = parser

## 注销数据类型处理器
func unregister_parser(type: StringName) -> void:
	_parsers.erase(type)

## 清空数据类型处理器
func clear_parsers() -> void:
	_parsers.clear()

## 数据格式化
func _parse_value(value: String, type: String) -> Variant:
	# 检查是否是数组类型
	if type.ends_with("[]"):
		var base_type = type.substr(0, type.length() - 2)  # 移除 "[]" 后缀
		return _parse_array(value, base_type)
	elif _parsers.has(type):
		return _parsers[type].call(value)
	else:
		push_error("未知的数据类型：{0} in _parsers: {1}".format([type, _parsers]))
		return null

## 通用数组处理函数
func _parse_array(value: String, base_type: String) -> Variant:
	if value.is_empty():
		return []
	
	var elements = value.split("*")
	var result = []
	
	# 根据基础类型处理每个元素
	if _parsers.has(base_type):
		for element in elements:
			result.append(_parsers[base_type].call(element))
	else:
		push_error("未知的数组基础类型：" + base_type)
		return []
	
	return result

## 处理字符串
func _parse_string(v: String) -> String:
	return v

## 处理整数
func _parse_int(v: String) -> int:
	return v.to_int()

## 处理浮点数
func _parse_float(v: String) -> float:
	return v.to_float()

## 处理布尔值
func _parse_bool(v: String) -> bool:
	return bool(v.to_int())

## 处理向量
func _parse_vector2(v: String) -> Vector2:
	var vs : Array[float]
	for element in v.split(","):
		vs.append(element.to_float())
	return Vector2(vs[0], vs[1])

## 处理资源
func _parse_resource(v: String) -> Resource:
	if v.is_empty():
		return null
	if ResourceLoader.exists(v):
		return ResourceLoader.load(v)
	else:
		var error_info: String = "未知的资源类型：" + v
		if OS.has_feature("release"):
			push_error(error_info)
		return null

## 处理字典
func _parse_dictionary(v: String) -> Dictionary:
	var dict : Dictionary
	var kv_pairs = v.split(",")
	for pair in kv_pairs:
		var kv = pair.split(":")
		if kv.size() == 2:
			dict[kv[0].strip_edges()] = kv[1].strip_edges()
	return dict
