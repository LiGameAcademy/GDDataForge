class_name TableEditorUtils
extends RefCounted

func is_valid_identifier(name: String) -> bool:
	var reg := RegEx.new()
	if reg.compile("^[A-Za-z_][A-Za-z0-9_]*$") != OK:
		return false
	return reg.search(name) != null

func ensure_dir_exists(path: String) -> bool:
	if DirAccess.dir_exists_absolute(path):
		return true
	return DirAccess.make_dir_recursive_absolute(path) == OK

func create_empty_table_file(path: String, is_csv: bool) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return false
	
	if is_csv:
		# 与当前解析器兼容：列名 / 注释 / 类型 / 校验规则
		file.store_line("ID")
		file.store_line("")
		file.store_line("string")
		file.store_line("")
	else:
		var output := {
			"_meta": {
				"primary_key": "ID",
				"columns": [],
				"types": [],
				"validation_rules": {},
				"foreign_keys": []
			},
			"_data": {}
		}
		file.store_string(JSON.stringify(output, "\t"))
	
	file.close()
	return true

func create_model_script(model_path: String, table_name: String) -> void:
	var file := FileAccess.open(model_path, FileAccess.WRITE)
	if not file:
		return
	var model_class_name := "%sModel" % table_name.capitalize()
	file.store_string("extends Resource\nclass_name %s\n\n# 在可视化编辑器中添加列后，可同步补充导出字段。\n" % model_class_name)
	file.close()

func parse_value(value: String, value_type: String) -> Variant:
	match value_type:
		"int":
			return value.to_int()
		"float":
			return value.to_float()
		"bool":
			return bool(value.to_int())
		"vector2":
			var parts = value.split(",")
			if parts.size() >= 2:
				return Vector2(parts[0].to_float(), parts[1].to_float())
		_:
			return value
	return value

func validate_and_convert_value(value: Variant, expected_type: String) -> Variant:
	match expected_type:
		"int":
			if typeof(value) == TYPE_STRING:
				return String(value).to_int()
			return int(value)
		"float":
			if typeof(value) == TYPE_STRING:
				return String(value).to_float()
			return float(value)
		"bool":
			if typeof(value) == TYPE_STRING:
				var lowered = String(value).to_lower()
				return lowered == "1" or lowered == "true"
			return bool(value)
		"vector2":
			if typeof(value) == TYPE_STRING:
				var parts = String(value).split(",")
				if parts.size() >= 2:
					return Vector2(parts[0].to_float(), parts[1].to_float())
	return value
