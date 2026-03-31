extends RefCounted
class_name TableDataIO

const TableEditorUtils = preload("res://addons/GDDataForge/editor/modules/table_editor_utils.gd")
var _utils := TableEditorUtils.new()

func parse_csv_file(file_path: String) -> Dictionary:
	var result := {
		"data": {},
		"columns": [],
		"types": [],
		"validation_rules": {}
	}
	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return result
	
	var data_names: PackedStringArray = file.get_csv_line(",")
	file.get_csv_line(",") # 注释行
	var data_types: PackedStringArray = file.get_csv_line(",")
	
	var validation_rules_line := PackedStringArray()
	if not file.eof_reached():
		validation_rules_line = file.get_csv_line(",")
	
	var validation_rules := {}
	if not validation_rules_line.is_empty():
		for i in range(data_names.size()):
			if i >= validation_rules_line.size():
				break
			var rule_str := validation_rules_line[i]
			if rule_str.is_empty():
				continue
			var col_name := data_names[i]
			var rules := []
			for rule in rule_str.split("|"):
				if not rule.is_empty():
					rules.append(rule)
			validation_rules[col_name] = rules
	
	var data := {}
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line(",")
		if row.is_empty():
			continue
		
		var row_data := {}
		for i in range(data_names.size()):
			var data_name := data_names[i]
			var data_type := data_types[i] if i < data_types.size() else "string"
			if data_name.is_empty():
				continue
			var value := row[i] if i < row.size() else ""
			row_data[data_name] = _utils.parse_value(value, data_type)
		
		if row_data.has("ID") and not String(row_data["ID"]).is_empty():
			data[String(row_data["ID"])] = row_data
	
	file.close()
	result["data"] = data
	result["columns"] = Array(data_names)
	result["types"] = Array(data_types)
	result["validation_rules"] = validation_rules
	return result

func parse_json_file(file_path: String) -> Dictionary:
	var result := {
		"data": {},
		"validation_rules": {},
		"primary_key": "ID",
		"foreign_keys": []
	}
	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return result
	
	var content := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	if json.parse(content) != OK:
		return result
	
	var json_data = json.get_data()
	if typeof(json_data) != TYPE_DICTIONARY:
		return result
	
	if json_data.has("_meta"):
		var meta: Dictionary = json_data["_meta"]
		if meta.has("validation_rules"):
			result["validation_rules"] = meta["validation_rules"]
		if meta.has("primary_key"):
			result["primary_key"] = meta["primary_key"]
		if meta.has("foreign_keys"):
			result["foreign_keys"] = meta["foreign_keys"]
		if json_data.has("_data"):
			result["data"] = json_data["_data"]
		else:
			var data_copy: Dictionary = json_data.duplicate(true)
			data_copy.erase("_meta")
			result["data"] = data_copy
	else:
		result["data"] = json_data
	
	return result

func save_csv_file(
	file_path: String,
	current_table: Dictionary,
	current_table_columns: Array[String],
	current_table_types: Array[String],
	field_validation_rules: Dictionary,
	row_order: Array[String] = []
) -> bool:
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		return false
	
	var header := PackedStringArray()
	header.append("ID")
	header.append_array(current_table_columns)
	file.store_csv_line(header, ",")
	
	var comments := PackedStringArray()
	comments.append("")
	for _col in current_table_columns:
		comments.append("")
	file.store_csv_line(comments, ",")
	
	var types := PackedStringArray()
	types.append("string")
	types.append_array(current_table_types)
	file.store_csv_line(types, ",")
	
	var validation_row := PackedStringArray()
	validation_row.append("")
	for col in current_table_columns:
		var rules_str := ""
		if field_validation_rules.has(col):
			rules_str = "|".join(field_validation_rules[col])
		validation_row.append(rules_str)
	file.store_csv_line(validation_row, ",")
	
	var row_ids: Array[String] = []
	if not row_order.is_empty():
		for rid in row_order:
			if current_table.has(rid):
				row_ids.append(rid)
	else:
		for rid in current_table.keys():
			row_ids.append(String(rid))
	
	for row_id in row_ids:
		var row_data = current_table[row_id]
		var row := PackedStringArray()
		row.append(str(row_id))
		for col in current_table_columns:
			row.append(str(row_data.get(col, "")))
		file.store_csv_line(row, ",")
	
	file.close()
	return true

func save_json_file(
	file_path: String,
	current_table: Dictionary,
	current_table_columns: Array[String],
	current_table_types: Array[String],
	field_validation_rules: Dictionary,
	primary_key: String,
	foreign_keys: Array[Dictionary]
) -> bool:
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		return false
	
	var output := {
		"_meta": {
			"primary_key": primary_key,
			"columns": current_table_columns,
			"types": current_table_types,
			"validation_rules": field_validation_rules,
			"foreign_keys": foreign_keys
		},
		"_data": current_table
	}
	
	file.store_string(JSON.stringify(output, "\t"))
	file.close()
	return true
