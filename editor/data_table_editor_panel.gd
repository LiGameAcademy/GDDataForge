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
var _resource_pick_dialog: EditorFileDialog
var _resource_target_line_edit: LineEdit

var _loaded_tables: Dictionary = {}  # {name: {data,path,columns,types}}
var _current_table: Dictionary = {}
var _current_table_name: String = ""
var _current_table_columns: Array[String] = []
var _current_table_types: Array[String] = []
var _field_validation_rules: Dictionary = {} # {field: ["REQUIRED","UNIQUE","RANGE:1-10"]}
var _primary_key: String = "ID"
var _foreign_keys: Array[Dictionary] = [] # [{field,target_table,target_field}]
var _search_text: String = ""
var _search_column: String = ""
var _filter_column: String = ""
var _filter_value: String = ""
var _sort_column: String = ""
var _sort_ascending: bool = true
var _filtered_table: Dictionary = {}
var _is_filtered: bool = false
var _selected_rows: Dictionary = {}  # {row_id: true}

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
	if _resource_pick_dialog:
		_resource_pick_dialog.queue_free()
		_resource_pick_dialog = null

func _connect_ui_signals() -> void:
	_toolbar.btn_open.pressed.connect(_on_open_table_pressed)
	_toolbar.btn_save.pressed.connect(_on_save_table_pressed)
	_toolbar.btn_add_row.pressed.connect(_on_add_row_pressed)
	_toolbar.btn_del_row.pressed.connect(_on_delete_row_pressed)
	_toolbar.btn_add_field.pressed.connect(_on_add_field_pressed)
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
			columns = _normalize_columns(_to_string_array(parsed_csv.get("columns", [])))
			types = _to_string_array(parsed_csv.get("types", []))
			_field_validation_rules = parsed_csv.get("validation_rules", {})
			_primary_key = "ID"
			_foreign_keys = []
			if types.size() == columns.size() + 1:
				types.remove_at(0) # CSV 第一列通常是 ID 类型
		"json":
			var parsed_json := _data_io.parse_json_file(file_path)
			table_data = parsed_json.get("data", {})
			columns = _extract_columns_from_json(table_data)
			types = _extract_types_from_json(table_data)
			_field_validation_rules = parsed_json.get("validation_rules", {})
			_primary_key = String(parsed_json.get("primary_key", "ID"))
			_foreign_keys = parsed_json.get("foreign_keys", [])
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
	_current_table_columns = _normalize_columns(_to_string_array(_loaded_tables[table_name].get("columns", [])))
	_current_table_types = _to_string_array(_loaded_tables[table_name].get("types", []))
	if _current_table_types.size() == _current_table_columns.size() + 1:
		_current_table_types.remove_at(0)
	_selected_rows.clear()
	_refresh_search_filter_options()
	_refresh_table_view()
	table_selected.emit(table_name)
	set_status("已加载表: " + table_name)

func _refresh_table_view() -> void:
	var table_to_show = _filtered_table if _is_filtered else _current_table
	_view_controller.refresh_table_view(
		_table_view,
		table_to_show,
		_current_table_columns,
		_current_table_types,
		_on_cell_value_submitted,
		_on_row_checked,
		_selected_rows,
		_on_id_submitted,
		_on_field_header_clicked,
		_on_field_reordered,
		_get_field_tooltip
	)

func _on_row_checked(row_id: String, checked: bool) -> void:
	if checked:
		_selected_rows[row_id] = true
	else:
		_selected_rows.erase(row_id)

func _on_id_submitted(old_id: String, new_id_raw: String) -> void:
	var new_id := new_id_raw.strip_edges()
	if new_id == old_id:
		return
	if new_id.is_empty():
		set_status("ID 不能为空")
		_refresh_table_view()
		return
	if _current_table.has(new_id):
		set_status("ID 已存在: " + new_id)
		_refresh_table_view()
		return
	if not _current_table.has(old_id):
		return
	
	var row_data: Dictionary = _current_table[old_id].duplicate(true)
	_current_table.erase(old_id)
	_current_table[new_id] = row_data
	
	if _selected_rows.has(old_id):
		_selected_rows.erase(old_id)
		_selected_rows[new_id] = true
	
	if _loaded_tables.has(_current_table_name):
		_loaded_tables[_current_table_name]["data"] = _current_table.duplicate(true)
	
	if _is_filtered:
		_apply_search_and_filter()
	else:
		_refresh_table_view()
	
	table_modified.emit(_current_table_name)
	set_status("ID 已更新: %s -> %s" % [old_id, new_id])

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

func _on_add_row_pressed() -> void:
	if _current_table_name.is_empty():
		set_status("请先加载数据表")
		return
	var dialog := AcceptDialog.new()
	dialog.title = "添加数据"
	dialog.ok_button_text = "添加"
	
	var form := GridContainer.new()
	form.columns = 2
	
	var id_label := Label.new()
	id_label.text = "ID"
	form.add_child(id_label)
	var id_input := LineEdit.new()
	id_input.name = "Field_ID"
	form.add_child(id_input)
	
	for i in range(_current_table_columns.size()):
		var col_name := _current_table_columns[i]
		var col_type := _current_table_types[i] if i < _current_table_types.size() else "string"
		var label := Label.new()
		label.text = col_name
		form.add_child(label)
		if col_type == "bool":
			var check := CheckBox.new()
			check.name = "Field_%s" % col_name
			form.add_child(check)
		elif col_name.to_lower() == "icon" or col_type.to_lower() == "texture":
			var icon_row := HBoxContainer.new()
			var input := LineEdit.new()
			input.name = "Field_%s" % col_name
			input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			icon_row.add_child(input)
			var browse_btn := Button.new()
			browse_btn.text = "浏览"
			browse_btn.pressed.connect(_on_pick_resource_for_line_edit.bind(input))
			icon_row.add_child(browse_btn)
			form.add_child(icon_row)
		else:
			var input := LineEdit.new()
			input.name = "Field_%s" % col_name
			form.add_child(input)
	
	dialog.add_child(form)
	dialog.confirmed.connect(_on_add_row_dialog_confirmed.bind(dialog))
	if _host_plugin:
		_host_plugin.get_editor_interface().get_base_control().add_child(dialog)
	dialog.popup_centered(Vector2i(520, 380))
	id_input.grab_focus()

func _on_add_row_dialog_confirmed(dialog: AcceptDialog) -> void:
	var id_input: LineEdit = dialog.get_node("GridContainer/Field_ID")
	var row_id := id_input.text.strip_edges()
	if row_id.is_empty():
		set_status("ID 不能为空")
		dialog.queue_free()
		return
	if _current_table.has(row_id):
		set_status("ID 已存在: " + row_id)
		dialog.queue_free()
		return
	
	var row_data: Dictionary = {}
	for i in range(_current_table_columns.size()):
		var col_name := _current_table_columns[i]
		var col_type := _current_table_types[i] if i < _current_table_types.size() else "string"
		var node_name := "GridContainer/Field_%s" % col_name
		if col_type == "bool":
			var check: CheckBox = dialog.get_node(node_name)
			row_data[col_name] = check.button_pressed
		elif col_name.to_lower() == "icon" or col_type.to_lower() == "texture":
			var icon_row: HBoxContainer = dialog.get_node(node_name)
			var input: LineEdit = icon_row.get_child(0)
			row_data[col_name] = input.text.strip_edges()
		else:
			var input: LineEdit = dialog.get_node(node_name)
			row_data[col_name] = _utils.validate_and_convert_value(input.text, col_type)
	
	_current_table[row_id] = row_data
	if _loaded_tables.has(_current_table_name):
		_loaded_tables[_current_table_name]["data"] = _current_table.duplicate(true)
	_selected_rows.clear()
	_apply_search_and_filter()
	table_modified.emit(_current_table_name)
	set_status("已添加行: " + row_id)
	dialog.queue_free()

func _on_delete_row_pressed() -> void:
	if _selected_rows.is_empty():
		set_status("请先勾选要删除的行")
		return
	var ids_to_delete := _selected_rows.keys()
	for row_id in ids_to_delete:
		_current_table.erase(String(row_id))
	_selected_rows.clear()
	if _loaded_tables.has(_current_table_name):
		_loaded_tables[_current_table_name]["data"] = _current_table.duplicate(true)
	_apply_search_and_filter()
	table_modified.emit(_current_table_name)
	set_status("已删除 %d 行" % ids_to_delete.size())

func _on_add_field_pressed() -> void:
	if _current_table_name.is_empty():
		set_status("请先加载数据表")
		return
	var dialog := AcceptDialog.new()
	dialog.title = "添加字段"
	dialog.ok_button_text = "添加"
	var grid := GridContainer.new()
	grid.columns = 2
	var name_label := Label.new()
	name_label.text = "字段名"
	grid.add_child(name_label)
	var name_input := LineEdit.new()
	name_input.name = "FieldNameInput"
	grid.add_child(name_input)
	var type_label := Label.new()
	type_label.text = "字段类型"
	grid.add_child(type_label)
	var type_option := OptionButton.new()
	type_option.name = "FieldTypeOption"
	for t in ["string", "int", "float", "bool", "texture", "vector2"]:
		type_option.add_item(t)
	grid.add_child(type_option)
	dialog.add_child(grid)
	dialog.confirmed.connect(_on_add_field_dialog_confirmed.bind(dialog))
	if _host_plugin:
		_host_plugin.get_editor_interface().get_base_control().add_child(dialog)
	dialog.popup_centered(Vector2i(420, 170))
	name_input.grab_focus()

func _on_add_field_dialog_confirmed(dialog: AcceptDialog) -> void:
	var name_input: LineEdit = dialog.get_node("GridContainer/FieldNameInput")
	var type_option: OptionButton = dialog.get_node("GridContainer/FieldTypeOption")
	var field_name := name_input.text.strip_edges()
	if field_name.is_empty():
		set_status("字段名不能为空")
		dialog.queue_free()
		return
	if field_name == "ID" or field_name in _current_table_columns:
		set_status("字段已存在: " + field_name)
		dialog.queue_free()
		return
	_current_table_columns.append(field_name)
	_current_table_types.append(type_option.get_item_text(type_option.selected))
	for row_id in _current_table.keys():
		_current_table[row_id][field_name] = ""
	_apply_search_and_filter()
	set_status("已添加字段: " + field_name)
	dialog.queue_free()

func _on_field_header_clicked(field_name: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "字段设置: " + field_name
	dialog.ok_button_text = "保存"
	var grid := GridContainer.new()
	grid.columns = 2
	
	var req_chk := CheckBox.new()
	req_chk.name = "RequiredCheck"
	req_chk.text = "必填"
	req_chk.button_pressed = _has_field_rule(field_name, "REQUIRED")
	grid.add_child(req_chk)
	grid.add_child(Control.new())
	
	var uniq_chk := CheckBox.new()
	uniq_chk.name = "UniqueCheck"
	uniq_chk.text = "唯一"
	uniq_chk.button_pressed = _has_field_rule(field_name, "UNIQUE")
	grid.add_child(uniq_chk)
	grid.add_child(Control.new())
	
	var pk_chk := CheckBox.new()
	pk_chk.name = "PrimaryCheck"
	pk_chk.text = "主键"
	pk_chk.button_pressed = (_primary_key == field_name)
	grid.add_child(pk_chk)
	grid.add_child(Control.new())
	
	var fk_chk := CheckBox.new()
	fk_chk.name = "ForeignCheck"
	fk_chk.text = "外键"
	var fk = _get_foreign_key_for_field(field_name)
	fk_chk.button_pressed = not fk.is_empty()
	grid.add_child(fk_chk)
	grid.add_child(Control.new())
	
	var fk_table_label := Label.new()
	fk_table_label.text = "外键目标表"
	grid.add_child(fk_table_label)
	var fk_table := LineEdit.new()
	fk_table.name = "ForeignTableInput"
	fk_table.text = String(fk.get("target_table", ""))
	grid.add_child(fk_table)
	
	var fk_field_label := Label.new()
	fk_field_label.text = "外键目标字段"
	grid.add_child(fk_field_label)
	var fk_field := LineEdit.new()
	fk_field.name = "ForeignFieldInput"
	fk_field.text = String(fk.get("target_field", "ID"))
	grid.add_child(fk_field)
	
	var del_btn := Button.new()
	del_btn.text = "删除字段"
	del_btn.modulate = Color(1, 0.6, 0.6)
	del_btn.pressed.connect(_on_delete_field_confirmed.bind(dialog, field_name))
	grid.add_child(del_btn)
	grid.add_child(Control.new())
	
	dialog.add_child(grid)
	dialog.confirmed.connect(_on_field_settings_confirmed.bind(dialog, field_name))
	if _host_plugin:
		_host_plugin.get_editor_interface().get_base_control().add_child(dialog)
	dialog.popup_centered(Vector2i(480, 320))

func _on_field_settings_confirmed(dialog: AcceptDialog, field_name: String) -> void:
	var req_chk: CheckBox = dialog.get_node("GridContainer/RequiredCheck")
	var uniq_chk: CheckBox = dialog.get_node("GridContainer/UniqueCheck")
	var pk_chk: CheckBox = dialog.get_node("GridContainer/PrimaryCheck")
	var fk_chk: CheckBox = dialog.get_node("GridContainer/ForeignCheck")
	var fk_table: LineEdit = dialog.get_node("GridContainer/ForeignTableInput")
	var fk_field: LineEdit = dialog.get_node("GridContainer/ForeignFieldInput")
	
	_set_field_rule(field_name, "REQUIRED", req_chk.button_pressed)
	_set_field_rule(field_name, "UNIQUE", uniq_chk.button_pressed)
	if pk_chk.button_pressed:
		_primary_key = field_name
	elif _primary_key == field_name:
		_primary_key = "ID"
	
	_foreign_keys = _foreign_keys.filter(func(item): return String(item.get("field", "")) != field_name)
	if fk_chk.button_pressed and not fk_table.text.strip_edges().is_empty():
		_foreign_keys.append({
			"field": field_name,
			"target_table": fk_table.text.strip_edges(),
			"target_field": fk_field.text.strip_edges() if not fk_field.text.strip_edges().is_empty() else "ID"
		})
	_refresh_table_view()
	set_status("字段设置已更新: " + field_name)
	dialog.queue_free()

func _on_delete_field_confirmed(dialog: AcceptDialog, field_name: String) -> void:
	var idx := _current_table_columns.find(field_name)
	if idx >= 0:
		_current_table_columns.remove_at(idx)
		if idx < _current_table_types.size():
			_current_table_types.remove_at(idx)
	for row_id in _current_table.keys():
		_current_table[row_id].erase(field_name)
	_field_validation_rules.erase(field_name)
	_foreign_keys = _foreign_keys.filter(func(item): return String(item.get("field", "")) != field_name)
	if _primary_key == field_name:
		_primary_key = "ID"
	_apply_search_and_filter()
	set_status("已删除字段: " + field_name)
	dialog.queue_free()

func _on_field_reordered(from_field: String, to_field: String) -> void:
	if from_field == to_field:
		return
	var from_idx := _current_table_columns.find(from_field)
	var to_idx := _current_table_columns.find(to_field)
	if from_idx < 0 or to_idx < 0:
		return
	var col := _current_table_columns[from_idx]
	var typ := _current_table_types[from_idx] if from_idx < _current_table_types.size() else "string"
	_current_table_columns.remove_at(from_idx)
	_current_table_types.remove_at(from_idx)
	if from_idx < to_idx:
		to_idx -= 1
	_current_table_columns.insert(to_idx, col)
	_current_table_types.insert(to_idx, typ)
	_refresh_table_view()

func _get_field_tooltip(field_name: String) -> String:
	var lines: Array[String] = []
	var idx := _current_table_columns.find(field_name)
	var field_type := _current_table_types[idx] if idx >= 0 and idx < _current_table_types.size() else "string"
	lines.append("类型: %s" % field_type)
	if _primary_key == field_name:
		lines.append("主键: 是")
	var rules = _field_validation_rules.get(field_name, [])
	if not rules.is_empty():
		lines.append("规则: " + ", ".join(rules))
	var fk = _get_foreign_key_for_field(field_name)
	if not fk.is_empty():
		lines.append("外键: %s.%s" % [fk.get("target_table", ""), fk.get("target_field", "ID")])
	return "\n".join(lines)

func _has_field_rule(field_name: String, rule: String) -> bool:
	if not _field_validation_rules.has(field_name):
		return false
	return rule in _field_validation_rules[field_name]

func _set_field_rule(field_name: String, rule: String, enabled: bool) -> void:
	if not _field_validation_rules.has(field_name):
		_field_validation_rules[field_name] = []
	if enabled:
		if rule not in _field_validation_rules[field_name]:
			_field_validation_rules[field_name].append(rule)
	else:
		_field_validation_rules[field_name].erase(rule)
	if _field_validation_rules[field_name].is_empty():
		_field_validation_rules.erase(field_name)

func _get_foreign_key_for_field(field_name: String) -> Dictionary:
	for fk in _foreign_keys:
		if String(fk.get("field", "")) == field_name:
			return fk
	return {}

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

func _normalize_columns(columns: Array[String]) -> Array[String]:
	var normalized: Array[String] = []
	for c in columns:
		var col_name := String(c).strip_edges().trim_prefix("\ufeff")
		if col_name == "ID":
			continue
		if col_name.is_empty():
			continue
		normalized.append(col_name)
	return normalized

func _on_pick_resource_for_line_edit(target_line_edit: LineEdit) -> void:
	if not _host_plugin:
		return
	_resource_target_line_edit = target_line_edit
	if not _resource_pick_dialog:
		_resource_pick_dialog = EditorFileDialog.new()
		_resource_pick_dialog.title = "选择资源文件"
		_resource_pick_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
		_resource_pick_dialog.access = EditorFileDialog.ACCESS_RESOURCES
		_resource_pick_dialog.add_filter("*.tres,*.res,*.png,*.jpg,*.jpeg,*.webp ; 图标/纹理资源")
		_resource_pick_dialog.file_selected.connect(_on_resource_file_selected)
		_host_plugin.get_editor_interface().get_base_control().add_child(_resource_pick_dialog)
	_resource_pick_dialog.popup_centered_ratio(0.55)

func _on_resource_file_selected(path: String) -> void:
	if _resource_target_line_edit:
		_resource_target_line_edit.text = path
