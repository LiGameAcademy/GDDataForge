extends RefCounted
class_name TableEditActions

func validate_new_row_id(current_table: Dictionary, new_id: String) -> String:
	if new_id.is_empty():
		return "行 ID 不能为空"
	if current_table.has(new_id):
		return "行 ID 已存在: " + new_id
	return ""

func create_empty_row(columns: Array[String]) -> Dictionary:
	var row_data := {}
	for col in columns:
		row_data[col] = ""
	return row_data

func validate_new_column(columns: Array[String], col_name: String) -> String:
	if col_name.is_empty():
		return "列名不能为空"
	if col_name in columns:
		return "列已存在: " + col_name
	return ""

func add_column_to_rows(table: Dictionary, col_name: String, default_value: Variant = "") -> void:
	for row_id in table.keys():
		table[row_id][col_name] = default_value

func remove_column_from_rows(table: Dictionary, col_name: String) -> void:
	for row_id in table.keys():
		table[row_id].erase(col_name)

func validate_foreign_key_prerequisites(columns: Array[String], loaded_tables_size: int) -> String:
	if columns.is_empty():
		return "请先加载数据表"
	if loaded_tables_size < 2:
		return "至少需要加载两个数据表才能设置外键"
	return ""

func build_foreign_key(field: String, target_table: String, target_field: String) -> Dictionary:
	var resolved_target_field := target_field
	if resolved_target_field.is_empty():
		resolved_target_field = "ID"
	return {
		"field": field,
		"target_table": target_table,
		"target_field": resolved_target_field
	}
