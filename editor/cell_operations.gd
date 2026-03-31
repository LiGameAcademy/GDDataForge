extends Node
class_name CellOperations

signal table_modified(table_name: String)

var _current_table: Dictionary = {}
var _current_table_name: String = ""
var _current_table_columns: Array[String] = []
var _current_table_types: Array[String] = []
var _table_view: Tree
var _status_label: Label

## 添加行操作

func add_row(row_id: String, row_data: Dictionary) -> void:
	if row_id.is_empty():
		_update_status("ID 不能为空")
		return
	
	if _current_table.has(row_id):
		_update_status("ID 已存在: " + row_id)
		return
	
	_current_table[row_id] = row_data
	_refresh_table_view()
	_update_status("已添加行: " + row_id)
	table_modified.emit(_current_table_name)

## 删除选中行
func delete_selected_row() -> void:
	var item = _table_view.get_selected()
	if not item:
		_update_status("请先选择一行")
		return
	
	var row_id = _table_view.get_item_text(item, 0)
	_current_table.erase(row_id)
	_refresh_table_view()
	_update_status("已删除行: " + row_id)
	table_modified.emit(_current_table_name)

## 添加列
func add_column(col_name: String, col_type: String = "string") -> void:
	if col_name.is_empty():
		_update_status("列名不能为空")
		return
	
	if col_name in _current_table_columns:
		_update_status("列已存在: " + col_name)
		return
	
	_current_table_columns.append(col_name)
	_current_table_types.append(col_type)
	_refresh_table_view()
	_update_status("已添加列: " + col_name)
	table_modified.emit(_current_table_name)

## 删除选中列
func delete_selected_column() -> void:
	# TODO: 实现列删除
	_update_status("列删除功能开发中...")

## 更新单元格
func update_cell(row_id: String, col_name: String, value: Variant) -> void:
	if not _current_table.has(row_id):
		_update_status("行不存在: " + row_id)
		return
	
	# 类型检查
	var col_index = _current_table_columns.find(col_name)
	if col_index >= 0:
		var expected_type = _current_table_types[col_index]
		value = _validate_and_convert_value(value, expected_type)
	
	_current_table[row_id][col_name] = value
	table_modified.emit(_current_table_name)

## 类型校验和转换
func _validate_and_convert_value(value: Variant, expected_type: String) -> Variant:
	match expected_type:
		"int":
			if typeof(value) == TYPE_STRING:
				return value.to_int()
			return int(value)
		"float":
			if typeof(value) == TYPE_STRING:
				return value.to_float()
			return float(value)
		"bool":
			if typeof(value) == TYPE_STRING:
				return bool(value.to_int())
			return bool(value)
		"vector2":
			if typeof(value) == TYPE_STRING:
				var parts = value.split(",")
				if parts.size() >= 2:
					return Vector2(parts[0].to_float(), parts[1].to_float())
			return value
	return value

## 更新状态显示（独立模块兜底实现）
func _update_status(text: String) -> void:
	if _status_label:
		_status_label.text = text
	print("[CellOperations] ", text)

func _refresh_table_view() -> void:
	# 该模块当前仅保留轻量兜底实现，实际渲染由主编辑器控制器负责。
	pass
