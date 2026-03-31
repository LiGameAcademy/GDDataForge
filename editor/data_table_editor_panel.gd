@tool
extends PanelContainer
class_name DataTableEditorPanel

signal table_selected(table_name: String)
signal table_modified(table_name: String)

const TableEditorUtilsScript = preload("res://addons/GDDataForge/editor/modules/table_editor_utils.gd")
const TableDataIOScript = preload("res://addons/GDDataForge/editor/modules/table_data_io.gd")
const TableEditActionsScript = preload("res://addons/GDDataForge/editor/modules/table_edit_actions.gd")
const TableDialogControllerScript = preload("res://addons/GDDataForge/editor/modules/table_dialog_controller.gd")
const TableViewControllerScript = preload("res://addons/GDDataForge/editor/modules/table_view_controller.gd")
const TableValidationControllerScript = preload("res://addons/GDDataForge/editor/modules/table_validation_controller.gd")

@onready var toolbar: Control = $VBox/Toolbar
@onready var main_content: HSplitContainer = $VBox/MainContent
@onready var left_panel: PanelContainer = $VBox/MainContent/LeftPanel
@onready var center_panel: PanelContainer = $VBox/MainContent/CenterPanel
@onready var right_panel: PanelContainer = $VBox/MainContent/RightPanel
@onready var status_bar: Label = $VBox/StatusBar

@onready var _toolbar = $VBox/Toolbar
@onready var _table_list: ItemList = $VBox/MainContent/LeftPanel/VBox/ListScroll/TableList
@onready var _table_view: GridContainer = $VBox/MainContent/CenterPanel/VBox/TableScroll/TableView

var _host_plugin: EditorPlugin
var _utils := TableEditorUtilsScript.new()
var _data_io := TableDataIOScript.new()
var _edit_actions := TableEditActionsScript.new()
var _dialog_controller := TableDialogControllerScript.new()
var _view_controller := TableViewControllerScript.new()
var _validation_controller := TableValidationControllerScript.new()
var _file_dialog: EditorFileDialog

var _loaded_tables: Dictionary = {}  # {name: {data,path,columns,types}}
var _current_table: Dictionary = {}
var _current_table_name: String = ""
var _current_table_columns: Array[String] = []
var _current_table_types: Array[String] = []
var _search_text: String = ""
var _search_column: String = ""
var _filter_column: String = ""
var _filter_value: String = ""
var _sort_column: String = ""
var _sort_ascending: bool = true
var _filtered_table: Dictionary = {}
var _is_filtered: bool = false

func initialize(host_plugin: EditorPlugin) -> void:
	_host_plugin = host_plugin
	_connect_ui_signals()
	_initialize_toolbar_options()
	set_status("DataForge Editor 已初始化")

func set_status(text: String) -> void:
	status_bar.text = text

func _exit_tree() -> void:
	if _file_dialog:
		_file_dialog.queue_free()
		_file_dialog = null

func _connect_ui_signals() -> void:
	_toolbar.btn_open.pressed.connect(_on_open_table_pressed)
	_toolbar.btn_save.pressed.connect(_on_save_table_pressed)
	_toolbar.search_input.text_changed.connect(_on_search_text_changed)
	_toolbar.search_column_option.item_selected.connect(_on_search_column_changed)
	_toolbar.filter_column_option.item_selected.connect(_on_filter_column_changed)
	_toolbar.filter_value_input.text_changed.connect(_on_filter_value_changed)
	_toolbar.btn_clear_filter.pressed.connect(_on_clear_filter_pressed)
	_table_list.item_selected.connect(_on_table_list_item_selected)
	_table_list.item_activated.connect(_on_table_list_item_activated)

func _initialize_toolbar_options() -> void:
	_toolbar.initialize_options()

func _refresh_search_filter_options() -> void:
	_view_controller.refresh_search_filter_options(
		_toolbar.search_column_option,
		_toolbar.filter_column_option,
		_current_table_columns
	)

func _on_open_table_pressed() -> void:
	if not _host_plugin:
		set_status("宿主插件未初始化")
		return
	if not _file_dialog:
		_file_dialog = EditorFileDialog.new()
		_file_dialog.title = "选择数据文件"
		_file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
		_file_dialog.access = EditorFileDialog.ACCESS_RESOURCES
		_file_dialog.add_filter("*.csv ; CSV 数据表")
		_file_dialog.add_filter("*.json ; JSON 数据表")
		_file_dialog.file_selected.connect(_on_file_selected)
		_host_plugin.get_editor_interface().get_base_control().add_child(_file_dialog)
	_file_dialog.popup_centered_ratio(0.6)
	set_status("请选择 CSV/JSON 文件")

func _on_file_selected(path: String) -> void:
	if _load_table_file(path):
		set_status("已加载: " + path.get_file().get_basename())

func _on_save_table_pressed() -> void:
	if _current_table.is_empty():
		set_status("没有数据需要保存")
		return
	var file_path := _get_current_table_path()
	if file_path.is_empty():
		set_status("未找到当前表路径")
		return
	_save_table_to_file(file_path)
	set_status("已保存: " + file_path)

func _load_table_file(file_path: String) -> bool:
	if not FileAccess.file_exists(file_path):
		set_status("文件不存在: " + file_path)
		return false
	var ext := file_path.get_extension().to_lower()
	var table_name := file_path.get_file().get_basename()
	var table_data: Dictionary = {}
	var columns: Array[String] = []
	var types: Array[String] = []
	match ext:
		"csv":
			var parsed_csv := _data_io.parse_csv_file(file_path)
			table_data = parsed_csv.get("data", {})
			columns = _to_string_array(parsed_csv.get("columns", []))
			types = _to_string_array(parsed_csv.get("types", []))
		"json":
			var parsed_json := _data_io.parse_json_file(file_path)
			table_data = parsed_json.get("data", {})
			columns = _extract_columns_from_json(table_data)
			types = _extract_types_from_json(table_data)
		_:
			set_status("不支持的文件类型: " + ext)
			return false
	if table_data.is_empty():
		set_status("加载失败或数据为空: " + file_path)
		return false
	_loaded_tables[table_name] = {
		"data": table_data,
		"path": file_path,
		"columns": columns,
		"types": types
	}
	_refresh_table_list()
	_load_table_by_name(table_name)
	return true

func _refresh_table_list() -> void:
	_table_list.clear()
	for table_name in _loaded_tables.keys():
		_table_list.add_item(table_name)

func _on_table_list_item_selected(index: int) -> void:
	if index < 0 or index >= _table_list.item_count:
		return
	var table_name := _table_list.get_item_text(index)
	_load_table_by_name(table_name)

func _on_table_list_item_activated(index: int) -> void:
	_on_table_list_item_selected(index)

func _load_table_by_name(table_name: String) -> void:
	if not _loaded_tables.has(table_name):
		set_status("表不存在: " + table_name)
		return
	_current_table_name = table_name
	_current_table = _loaded_tables[table_name].get("data", {}).duplicate(true)
	_current_table_columns = _to_string_array(_loaded_tables[table_name].get("columns", []))
	_current_table_types = _to_string_array(_loaded_tables[table_name].get("types", []))
	_refresh_search_filter_options()
	_refresh_table_view()
	table_selected.emit(table_name)
	set_status("已加载表: " + table_name)

func _refresh_table_view() -> void:
	var table_to_show = _filtered_table if _is_filtered else _current_table
	_view_controller.refresh_table_view(_table_view, table_to_show, _current_table_columns, _on_cell_value_submitted)

func _on_cell_value_submitted(row_id: String, col_name: String, new_text: String) -> void:
	if not _current_table.has(row_id):
		return
	var col_idx := _current_table_columns.find(col_name)
	if col_idx < 0:
		return
	var new_value: Variant = new_text
	if col_idx < _current_table_types.size():
		new_value = _utils.validate_and_convert_value(new_value, _current_table_types[col_idx])
	_current_table[row_id][col_name] = new_value
	if _loaded_tables.has(_current_table_name):
		_loaded_tables[_current_table_name]["data"] = _current_table.duplicate(true)
	table_modified.emit(_current_table_name)
	set_status("已更新: %s.%s" % [row_id, col_name])

func _apply_search_and_filter() -> void:
	var result := _view_controller.apply_search_filter_sort(
		_current_table,
		_current_table_columns,
		_search_text,
		_search_column,
		_filter_column,
		_filter_value,
		_sort_column,
		_sort_ascending
	)
	_filtered_table = result.get("filtered_table", {})
	_is_filtered = result.get("is_filtered", false)
	_refresh_table_view()
	var count_before: int = result.get("count_before", 0)
	var count_after: int = result.get("count_after", 0)
	if _is_filtered:
		set_status("显示 %d / %d 条记录" % [count_after, count_before])
	else:
		set_status("共 %d 条记录" % count_before)

func _on_search_text_changed(text: String) -> void:
	_search_text = text
	_apply_search_and_filter()

func _on_search_column_changed(index: int) -> void:
	_search_column = "" if index == 0 else _current_table_columns[index - 1]
	_apply_search_and_filter()

func _on_filter_column_changed(index: int) -> void:
	_filter_column = "" if index == 0 else _current_table_columns[index - 1]
	_apply_search_and_filter()

func _on_filter_value_changed(text: String) -> void:
	_filter_value = text
	_apply_search_and_filter()

func _on_clear_filter_pressed() -> void:
	_search_text = ""
	_search_column = ""
	_filter_column = ""
	_filter_value = ""
	_is_filtered = false
	_toolbar.clear_search_filter_inputs()
	_apply_search_and_filter()

func _get_current_table_path() -> String:
	if _loaded_tables.has(_current_table_name):
		return _loaded_tables[_current_table_name].get("path", "")
	return ""

func _save_table_to_file(file_path: String) -> void:
	var ext := file_path.get_extension().to_lower()
	match ext:
		"csv":
			_data_io.save_csv_file(file_path, _current_table, _current_table_columns, _current_table_types, {})
		"json":
			_data_io.save_json_file(file_path, _current_table, _current_table_columns, _current_table_types, {}, "ID", [])

func _extract_columns_from_json(data: Dictionary) -> Array[String]:
	var columns: Array[String] = []
	if data.is_empty():
		return columns
	var first_row = data.values()[0]
	if typeof(first_row) == TYPE_DICTIONARY:
		for key in first_row.keys():
			columns.append(key)
	return columns

func _extract_types_from_json(data: Dictionary) -> Array[String]:
	var types: Array[String] = []
	if data.is_empty():
		return types
	var first_row = data.values()[0]
	if typeof(first_row) == TYPE_DICTIONARY:
		for key in first_row.keys():
			var value = first_row[key]
			var type_name := "string"
			match typeof(value):
				TYPE_INT:
					type_name = "int"
				TYPE_FLOAT:
					type_name = "float"
				TYPE_BOOL:
					type_name = "bool"
				TYPE_VECTOR2:
					type_name = "vector2"
			types.append(type_name)
	return types

func _to_string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(String(value))
	return result
