extends "res://addons/GDDataForge/source/data_loader.gd"
class_name JSONDatatableHelper

## 数据类型标记
var _parse_types: Dictionary[String, String] = {
	"json": "@json://",             # 嵌套的JSON配置
	"scene": "@scene://",           # 场景资源
	"texture": "@texture://",       # 贴图资源
	"audio": "@audio://",           # 音频资源
	"resource": "@resource://",     # 资源
	"vector2" : "@vector2:",      # 2D向量
}

## 加载单个JSON文件
## [param table_path] JSON文件路径
## [return] 加载结果
func load_datatable(table_path: StringName) -> Dictionary:
	if not FileAccess.file_exists(table_path):
		push_error("JSON file not found: %s" % table_path)
		return {}
	var json_text = FileAccess.get_file_as_string(table_path)
	var json = JSON.parse_string(json_text)
	if not json is Dictionary:
		push_error("Invalid JSON format: %s" % table_path)
		return {}
	# 处理资源引用
	return _process_resource_references(json)

## 处理JSON中的资源引用
## [param data] JSON数据
## [return] 处理后的数据
func _process_resource_references(data: Variant) -> Variant:
	match typeof(data):
		TYPE_DICTIONARY:
			var result = {}
			for key in data:
				result[key] = _process_resource_references(data[key])
			return result
		TYPE_ARRAY:
			var result = []
			for item in data:
				result.append(_process_resource_references(item))
			return result
		TYPE_STRING:
			return _resolve_resource_path(data)
		_:
			return data

## 解析资源路径
## [param value] 资源路径
## [return] 加载结果
func _resolve_resource_path(value: String) -> Variant:
	for marker in _parse_types:
		var prefix = _parse_types[marker]
		if value.begins_with(prefix):
			var path = value.substr(prefix.length())
			if marker == "json":
				return load_datatable(path)
			elif marker == "vector2":
				return _load_vector2(path)
			else:
				return _load_resource(path, marker)
			return _load_resource(path, marker)
	return value

## 加载vector2
## [param value] 向量字符串
## [return] 向量
func _load_vector2(value: String) -> Vector2:
	value = value.replace("(", "").replace(")", "")
	var vs: Array[float]
	for v in value.split(", "):
		vs.append(v.to_float())
	return Vector2(vs[0], vs[1])

## 加载资源
## [param path] 资源路径
## [param type] 资源类型
## [return] 资源
func _load_resource(path: String, type: String) -> Variant:
	if ResourceLoader.exists(path):
		return ResourceLoader.load(path)
	else:
		push_error("资源地址无效: ", path)
		return null
