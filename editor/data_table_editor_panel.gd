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
var _row_context_menu: PopupMenu
var _row_context_row_id: String = ""
var _field_context_menu: PopupMenu
var _field_context_field_name: String = ""
var _new_table_dialog: AcceptDialog
var _new_table_dir_dialog: EditorFileDialog
var _batch_open_dir_dialog: EditorFileDialog

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
var _row_order: Array[String] = []

func initialize(host_plugin: EditorPlugin) -> void:
	_host_plugin = host_plugin
	_connect_ui_signals()
	_initialize_toolbar_options()
	_ensure_row_context_menu()
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
	if _row_context_menu:
		_row_context_menu.queue_free()
		_row_context_menu = null
	if _field_context_menu:
		_field_context_menu.queue_free()
		_field_context_menu = null
	if _new_table_dialog:
		_new_table_dialog.queue_free()
		_new_table_dialog = null
	if _new_table_dir_dialog:
		_new_table_dir_dialog.queue_free()
		_new_table_dir_dialog = null
	if _batch_open_dir_dialog:
		_batch_open_dir_dialog.queue_free()
		_batch_open_dir_dialog = null

func _connect_ui_signals() -> void:
	_toolbar.btn_new.pressed.connect(_on_new_table_pressed)
	_toolbar.btn_open.pressed.connect(_on_open_table_pressed)
	_toolbar.btn_save.pressed.connect(_on_save_table_pressed)
	_toolbar.btn_add_row.pressed.connect(_on_add_row_pressed)
	_toolbar.btn_del_row.pressed.connect(_on_delete_row_pressed)
	_toolbar.btn_add_field.pressed.connect(_on_add_field_pressed)
	_toolbar.btn_batch_import.pressed.connect(_on_batch_open_folder_pressed)
	_toolbar.search_input.text_changed.connect(_on_search_text_changed)
	_toolbar.search_column_option.item_selected.connect(_on_search_column_changed)
	_toolbar.filter_column_option.item_selected.connect(_on_filter_column_changed)
	_toolbar.filter_value_input.text_changed.connect(_on_filter_value_changed)
	_toolbar.btn_clear_filter.pressed.connect(_on_clear_filter_pressed)
	_table_list.item_selected.connect(_on_table_list_item_selected)
	_table_list.item_activated.connect(_on_table_list_item_activated)

func _initialize_toolbar_options() -> void:
	_toolbar.initialize_options()

func _on_new_table_pressed() -> void:
	if not _host_plugin:
		set_status("宿主插件未初始化")
		return
	if _new_table_dialog:
		_new_table_dialog.queue_free()
	var dialog := AcceptDialog.new()
	_new_table_dialog = dialog
	dialog.title = "新建表格"
	dialog.ok_button_text = "创建"
	dialog.exclusive = false
	var grid := GridContainer.new()
	grid.name = "CreateTableForm"
	grid.columns = 2
	var name_label := Label.new()
	name_label.text = "表格名称"
	grid.add_child(name_label)
	var name_input := LineEdit.new()
	name_input.name = "TableNameInput"
	grid.add_child(name_input)
	var dir_label := Label.new()
	dir_label.text = "存放位置"
	grid.add_child(dir_label)
	var dir_row := HBoxContainer.new()
	dir_row.name = "DirRow"
	var dir_input := LineEdit.new()
	dir_input.name = "TableDirInput"
	dir_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dir_input.text = "res://datatables"
	dir_row.add_child(dir_input)
	var pick_btn := Button.new()
	pick_btn.text = "选择..."
	pick_btn.pressed.connect(_on_pick_new_table_dir.bind(dir_input))
	dir_row.add_child(pick_btn)
	grid.add_child(dir_row)
	var fmt_label := Label.new()
	fmt_label.text = "表格加载器"
	grid.add_child(fmt_label)
	var fmt_option := OptionButton.new()
	fmt_option.name = "TableFormatOption"
	fmt_option.add_item("csv")
	fmt_option.add_item("json")
	grid.add_child(fmt_option)
	dialog.add_child(grid)
	dialog.confirmed.connect(_on_new_table_dialog_confirmed.bind(dialog))
	_host_plugin.get_editor_interface().get_base_control().add_child(dialog)
	dialog.popup_centered(Vector2i(520, 220))
	name_input.grab_focus()

func _on_pick_new_table_dir(target_input: LineEdit) -> void:
	if not _host_plugin:
		return
	if _new_table_dir_dialog:
		_new_table_dir_dialog.queue_free()
	_new_table_dir_dialog = EditorFileDialog.new()
	_new_table_dir_dialog.title = "选择目录"
	_new_table_dir_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	_new_table_dir_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
	_new_table_dir_dialog.exclusive = false
	_new_table_dir_dialog.dir_selected.connect(func(path: String):
		target_input.text = path
	)
	_host_plugin.get_editor_interface().get_base_control().add_child(_new_table_dir_dialog)
	_new_table_dir_dialog.popup_centered_ratio(0.6)

func _on_new_table_dialog_confirmed(dialog: AcceptDialog) -> void:
	var name_input := dialog.find_child("TableNameInput", true, false) as LineEdit
	var dir_input := dialog.find_child("TableDirInput", true, false) as LineEdit
	var fmt_option := dialog.find_child("TableFormatOption", true, false) as OptionButton
	if name_input == null or dir_input == null or fmt_option == null:
		set_status("创建表单节点缺失，请重试")
		dialog.queue_free()
		return
	var table_name := name_input.text.strip_edges()
	var base_dir := dir_input.text.strip_edges()
	if not _utils.is_valid_identifier(table_name):
		set_status("表名不合法，请使用字母数字下划线且非数字开头")
		dialog.queue_free()
		return
	if base_dir.is_empty():
		set_status("请选择存放位置")
		dialog.queue_free()
		return
	if not _utils.ensure_dir_exists(base_dir):
		set_status("创建目录失败: " + base_dir)
		dialog.queue_free()
		return
	var ext := fmt_option.get_item_text(fmt_option.selected)
	var file_path := "%s/%s.%s" % [base_dir.trim_suffix("/"), table_name, ext]
	if FileAccess.file_exists(file_path):
		set_status("文件已存在: " + file_path)
		dialog.queue_free()
		return
	var created := _utils.create_empty_table_file(file_path, ext == "csv")
	if not created:
		set_status("创建失败: " + file_path)
		dialog.queue_free()
		return
	if _load_table_file(file_path):
		set_status("已创建并加载: " + file_path)
		_on_add_field_pressed()
	dialog.queue_free()

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

func _on_batch_open_folder_pressed() -> void:
	if not _host_plugin:
		return
	if _batch_open_dir_dialog:
		_batch_open_dir_dialog.queue_free()
	_batch_open_dir_dialog = EditorFileDialog.new()
	_batch_open_dir_dialog.title = "选择数据表目录（批量打开）"
	_batch_open_dir_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	_batch_open_dir_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
	_batch_open_dir_dialog.exclusive = false
	_batch_open_dir_dialog.dir_selected.connect(_on_batch_open_dir_selected)
	_host_plugin.get_editor_interface().get_base_control().add_child(_batch_open_dir_dialog)
	_batch_open_dir_dialog.popup_centered_ratio(0.65)

func _on_batch_open_dir_selected(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		set_status("目录不可访问: " + dir_path)
		return
	var loaded_count := 0
	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name.is_empty():
			break
		if dir.current_is_dir():
			continue
		var lower := name.to_lower()
		if lower.ends_with(".csv") or lower.ends_with(".json"):
			var full_path := dir_path.path_join(name)
			if _load_table_file(full_path):
				loaded_count += 1
	dir.list_dir_end()
	set_status("批量加载完成: %d 个表" % loaded_count)

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
	if _save_table_to_file(file_path):
		var table_name := _current_table_name
		if _load_table_file(file_path) and not table_name.is_empty():
			_load_table_by_name(table_name)
		set_status("已保存并重载: " + file_path)
	else:
		set_status("保存失败: " + file_path)

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
		table_data = {}
	_loaded_tables[table_name] = {
		"data": table_data,
		"path": file_path,
		"columns": columns,
		"types": types,
		"row_order": _to_ordered_row_ids(table_data)
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
	_row_order = _to_string_array(_loaded_tables[table_name].get("row_order", []))
	if _row_order.is_empty():
		_row_order = _to_ordered_row_ids(_current_table)
	_refresh_search_filter_options()
	_refresh_table_view()
	table_selected.emit(table_name)
	set_status("已加载表: " + table_name)

func _refresh_table_view() -> void:
	var table_to_show = _filtered_table if _is_filtered else _current_table
	var ordered_ids: Array[String] = []
	if _sort_column.is_empty():
		ordered_ids = _row_order
	_view_controller.refresh_table_view(
		_table_view,
		table_to_show,
		_current_table_columns,
		_current_table_types,
		_on_cell_value_submitted,
		_on_row_checked,
		_on_toggle_all_rows,
		_selected_rows,
		_are_all_visible_rows_selected(table_to_show),
		_on_id_submitted,
		_on_row_index_clicked,
		_on_row_context_requested,
		ordered_ids,
		_on_field_header_clicked,
		_on_field_context_requested,
		_on_field_reordered,
		_get_field_tooltip
	)

func _on_row_checked(row_id: String, checked: bool) -> void:
	if checked:
		_selected_rows[row_id] = true
	else:
		_selected_rows.erase(row_id)

func _on_toggle_all_rows(checked: bool) -> void:
	var visible_table := _filtered_table if _is_filtered else _current_table
	for row_id in visible_table.keys():
		var row_id_str := String(row_id)
		if checked:
			_selected_rows[row_id_str] = true
		else:
			_selected_rows.erase(row_id_str)
	_refresh_table_view()

func _are_all_visible_rows_selected(table_to_show: Dictionary) -> bool:
	if table_to_show.is_empty():
		return false
	for row_id in table_to_show.keys():
		if not _selected_rows.has(String(row_id)):
			return false
	return true

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
	var order_idx := _row_order.find(old_id)
	if order_idx >= 0:
		_row_order[order_idx] = new_id
	
	if _selected_rows.has(old_id):
		_selected_rows.erase(old_id)
		_selected_rows[new_id] = true
	
	if _loaded_tables.has(_current_table_name):
		_loaded_tables[_current_table_name]["data"] = _current_table.duplicate(true)
		_loaded_tables[_current_table_name]["row_order"] = _row_order.duplicate()
	
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
	form.name = "AddRowForm"
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
	var id_input := dialog.find_child("Field_ID", true, false) as LineEdit
	if id_input == null:
		set_status("添加数据表单节点缺失，请重试")
		dialog.queue_free()
		return
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
		var node_name := "Field_%s" % col_name
		if col_type == "bool":
			var check := dialog.find_child(node_name, true, false) as CheckBox
			if check == null:
				continue
			row_data[col_name] = check.button_pressed
		elif col_name.to_lower() == "icon" or col_type.to_lower() == "texture":
			var input := dialog.find_child(node_name, true, false) as LineEdit
			if input == null:
				continue
			row_data[col_name] = input.text.strip_edges()
		else:
			var input := dialog.find_child(node_name, true, false) as LineEdit
			if input == null:
				continue
			row_data[col_name] = _utils.validate_and_convert_value(input.text, col_type)
	
	_current_table[row_id] = row_data
	_row_order.append(row_id)
	if _loaded_tables.has(_current_table_name):
		_loaded_tables[_current_table_name]["data"] = _current_table.duplicate(true)
		_loaded_tables[_current_table_name]["row_order"] = _row_order.duplicate()
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
		_row_order.erase(String(row_id))
	_selected_rows.clear()
	if _loaded_tables.has(_current_table_name):
		_loaded_tables[_current_table_name]["data"] = _current_table.duplicate(true)
		_loaded_tables[_current_table_name]["row_order"] = _row_order.duplicate()
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
	var name_input := dialog.find_child("FieldNameInput", true, false) as LineEdit
	var type_option := dialog.find_child("FieldTypeOption", true, false) as OptionButton
	if name_input == null or type_option == null:
		set_status("添加字段表单节点缺失，请重试")
		dialog.queue_free()
		return
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
	if _loaded_tables.has(_current_table_name):
		_loaded_tables[_current_table_name]["data"] = _current_table.duplicate(true)
		_loaded_tables[_current_table_name]["columns"] = _current_table_columns.duplicate()
		_loaded_tables[_current_table_name]["types"] = _current_table_types.duplicate()
	_apply_search_and_filter()
	set_status("已添加字段: " + field_name)
	dialog.queue_free()

func _open_insert_field_left_dialog(left_of_field: String) -> void:
	if _current_table_name.is_empty():
		return
	var dialog := AcceptDialog.new()
	dialog.title = "左侧插入字段: " + left_of_field
	dialog.ok_button_text = "插入"
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
	dialog.confirmed.connect(_on_insert_field_left_confirmed.bind(dialog, left_of_field))
	if _host_plugin:
		_host_plugin.get_editor_interface().get_base_control().add_child(dialog)
	dialog.popup_centered(Vector2i(420, 170))
	name_input.grab_focus()

func _on_insert_field_left_confirmed(dialog: AcceptDialog, left_of_field: String) -> void:
	var name_input := dialog.find_child("FieldNameInput", true, false) as LineEdit
	var type_option := dialog.find_child("FieldTypeOption", true, false) as OptionButton
	if name_input == null or type_option == null:
		set_status("插入字段表单节点缺失，请重试")
		dialog.queue_free()
		return
	var field_name := name_input.text.strip_edges()
	if field_name.is_empty():
		set_status("字段名不能为空")
		dialog.queue_free()
		return
	if field_name == "ID" or field_name in _current_table_columns:
		set_status("字段已存在: " + field_name)
		dialog.queue_free()
		return
	var insert_idx := _current_table_columns.find(left_of_field)
	if insert_idx < 0:
		insert_idx = _current_table_columns.size()
	_current_table_columns.insert(insert_idx, field_name)
	_current_table_types.insert(insert_idx, type_option.get_item_text(type_option.selected))
	for row_id in _current_table.keys():
		_current_table[row_id][field_name] = ""
	if _loaded_tables.has(_current_table_name):
		_loaded_tables[_current_table_name]["data"] = _current_table.duplicate(true)
		_loaded_tables[_current_table_name]["columns"] = _current_table_columns.duplicate()
		_loaded_tables[_current_table_name]["types"] = _current_table_types.duplicate()
	_apply_search_and_filter()
	set_status("已左侧插入字段: " + field_name)
	dialog.queue_free()

func _on_field_header_clicked(field_name: String) -> void:
	if field_name == "ID":
		_open_id_field_settings_dialog()
		return
	var dialog := AcceptDialog.new()
	dialog.title = "字段设置: " + field_name
	dialog.ok_button_text = "保存"
	var grid := GridContainer.new()
	grid.columns = 2
	
	var field_name_label := Label.new()
	field_name_label.text = "字段名"
	grid.add_child(field_name_label)
	var field_name_input := LineEdit.new()
	field_name_input.name = "FieldNameInput"
	field_name_input.text = field_name
	grid.add_child(field_name_input)
	
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
	fk_chk.visible = false
	grid.add_child(fk_chk)
	grid.add_child(Control.new())
	
	var fk_table_label := Label.new()
	fk_table_label.text = "外键目标表"
	fk_table_label.visible = false
	grid.add_child(fk_table_label)
	var fk_table := LineEdit.new()
	fk_table.name = "ForeignTableInput"
	fk_table.text = String(fk.get("target_table", ""))
	fk_table.visible = false
	grid.add_child(fk_table)
	
	var fk_field_label := Label.new()
	fk_field_label.text = "外键目标字段"
	fk_field_label.visible = false
	grid.add_child(fk_field_label)
	var fk_field := LineEdit.new()
	fk_field.name = "ForeignFieldInput"
	fk_field.text = String(fk.get("target_field", "ID"))
	fk_field.visible = false
	grid.add_child(fk_field)
	var del_field_btn := dialog.add_button("移除字段", false, "delete_field")
	del_field_btn.modulate = Color(1, 0.45, 0.45)
	dialog.add_child(grid)
	dialog.confirmed.connect(_on_field_settings_confirmed.bind(dialog, field_name))
	dialog.custom_action.connect(_on_field_settings_custom_action.bind(dialog, field_name))
	if _host_plugin:
		_host_plugin.get_editor_interface().get_base_control().add_child(dialog)
	dialog.popup_centered(Vector2i(480, 320))

func _on_field_settings_confirmed(dialog: AcceptDialog, field_name: String) -> void:
	var field_name_input := dialog.find_child("FieldNameInput", true, false) as LineEdit
	var req_chk := dialog.find_child("RequiredCheck", true, false) as CheckBox
	var uniq_chk := dialog.find_child("UniqueCheck", true, false) as CheckBox
	var pk_chk := dialog.find_child("PrimaryCheck", true, false) as CheckBox
	var fk_chk := dialog.find_child("ForeignCheck", true, false) as CheckBox
	var fk_table := dialog.find_child("ForeignTableInput", true, false) as LineEdit
	var fk_field := dialog.find_child("ForeignFieldInput", true, false) as LineEdit
	if field_name_input == null or req_chk == null or uniq_chk == null or pk_chk == null or fk_chk == null or fk_table == null or fk_field == null:
		set_status("字段设置表单节点缺失，请重试")
		dialog.queue_free()
		return
	var target_field_name := field_name_input.text.strip_edges()
	if target_field_name.is_empty():
		set_status("字段名不能为空")
		dialog.queue_free()
		return
	if target_field_name != field_name and target_field_name in _current_table_columns:
		set_status("字段名已存在: " + target_field_name)
		dialog.queue_free()
		return
	
	if target_field_name != field_name:
		var rename_idx := _current_table_columns.find(field_name)
		if rename_idx >= 0:
			_current_table_columns[rename_idx] = target_field_name
		for row_id in _current_table.keys():
			_current_table[row_id][target_field_name] = _current_table[row_id].get(field_name, "")
			_current_table[row_id].erase(field_name)
		if _field_validation_rules.has(field_name):
			_field_validation_rules[target_field_name] = _field_validation_rules[field_name]
			_field_validation_rules.erase(field_name)
		for fk_item in _foreign_keys:
			if String(fk_item.get("field", "")) == field_name:
				fk_item["field"] = target_field_name
		if _primary_key == field_name:
			_primary_key = target_field_name
	
	_set_field_rule(target_field_name, "REQUIRED", req_chk.button_pressed)
	_set_field_rule(target_field_name, "UNIQUE", uniq_chk.button_pressed)
	if pk_chk.button_pressed:
		_primary_key = target_field_name
	elif _primary_key == target_field_name:
		_primary_key = "ID"
	
	_foreign_keys = _foreign_keys.filter(func(item): return String(item.get("field", "")) != target_field_name)
	if fk_chk.button_pressed and not fk_table.text.strip_edges().is_empty():
		_foreign_keys.append({
			"field": target_field_name,
			"target_table": fk_table.text.strip_edges(),
			"target_field": fk_field.text.strip_edges() if not fk_field.text.strip_edges().is_empty() else "ID"
		})
	if _loaded_tables.has(_current_table_name):
		_loaded_tables[_current_table_name]["data"] = _current_table.duplicate(true)
		_loaded_tables[_current_table_name]["columns"] = _current_table_columns.duplicate()
		_loaded_tables[_current_table_name]["types"] = _current_table_types.duplicate()
	_refresh_table_view()
	set_status("字段设置已更新: " + target_field_name)
	dialog.queue_free()

func _on_field_settings_custom_action(action: String, dialog: AcceptDialog, field_name: String) -> void:
	if action != "delete_field":
		return
	_on_delete_field_confirmed(dialog, field_name)

func _open_id_field_settings_dialog() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "字段设置: ID"
	dialog.ok_button_text = "确定"
	var vb := VBoxContainer.new()
	var tip := Label.new()
	tip.text = "ID 为主键列，支持编辑单元格值；不支持删除或改名。"
	vb.add_child(tip)
	dialog.add_child(vb)
	if _host_plugin:
		_host_plugin.get_editor_interface().get_base_control().add_child(dialog)
	dialog.popup_centered(Vector2i(420, 120))

func _on_delete_field_confirmed(dialog: AcceptDialog, field_name: String) -> void:
	if field_name == "ID":
		set_status("ID 字段不允许删除")
		dialog.queue_free()
		return
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
	if _loaded_tables.has(_current_table_name):
		_loaded_tables[_current_table_name]["data"] = _current_table.duplicate(true)
		_loaded_tables[_current_table_name]["columns"] = _current_table_columns.duplicate()
		_loaded_tables[_current_table_name]["types"] = _current_table_types.duplicate()
	_apply_search_and_filter()
	set_status("已删除字段: " + field_name)
	dialog.queue_free()

func _on_field_reordered(from_field: String, to_field: String) -> void:
	if from_field == "ID" or to_field == "ID":
		set_status("ID 字段位置固定")
		return
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

func _save_table_to_file(file_path: String) -> bool:
	var ext := file_path.get_extension().to_lower()
	match ext:
		"csv":
			return _data_io.save_csv_file(
				file_path,
				_current_table,
				_current_table_columns,
				_current_table_types,
				_field_validation_rules,
				_row_order
			)
		"json":
			return _data_io.save_json_file(
				file_path,
				_current_table,
				_current_table_columns,
				_current_table_types,
				_field_validation_rules,
				_primary_key,
				_foreign_keys
			)
	return false

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

func _to_ordered_row_ids(data: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for key in data.keys():
		ids.append(String(key))
	return ids

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

func _on_row_index_clicked(row_id: String) -> void:
	_open_row_edit_dialog(row_id)

func _on_row_context_requested(row_id: String, global_pos: Vector2) -> void:
	_row_context_row_id = row_id
	_ensure_row_context_menu()
	var _unused := global_pos
	_row_context_menu.position = DisplayServer.mouse_get_position()
	_row_context_menu.popup()

func _on_field_context_requested(field_name: String, global_pos: Vector2) -> void:
	_field_context_field_name = field_name
	_ensure_field_context_menu()
	var _unused := global_pos
	_field_context_menu.position = DisplayServer.mouse_get_position()
	_field_context_menu.popup()

func _ensure_row_context_menu() -> void:
	if _row_context_menu:
		return
	_row_context_menu = PopupMenu.new()
	_row_context_menu.add_item("上移", 0)
	_row_context_menu.add_item("下移", 1)
	_row_context_menu.add_item("向上插入", 2)
	_row_context_menu.add_item("删除", 3)
	_row_context_menu.add_separator()
	_row_context_menu.add_item("分割(待实现)", 4)
	_row_context_menu.add_item("查看引用(待实现)", 5)
	_row_context_menu.id_pressed.connect(_on_row_context_menu_id_pressed)
	if _host_plugin:
		_host_plugin.get_editor_interface().get_base_control().add_child(_row_context_menu)
	else:
		add_child(_row_context_menu)

func _ensure_field_context_menu() -> void:
	if _field_context_menu:
		return
	_field_context_menu = PopupMenu.new()
	_field_context_menu.add_item("编辑字段", 0)
	_field_context_menu.add_item("向左移动", 1)
	_field_context_menu.add_item("向右移动", 2)
	_field_context_menu.add_item("左侧插入字段", 3)
	_field_context_menu.add_item("删除字段", 4)
	_field_context_menu.id_pressed.connect(_on_field_context_menu_id_pressed)
	if _host_plugin:
		_host_plugin.get_editor_interface().get_base_control().add_child(_field_context_menu)
	else:
		add_child(_field_context_menu)

func _on_field_context_menu_id_pressed(id: int) -> void:
	match id:
		0:
			_on_field_header_clicked(_field_context_field_name)
		1:
			_move_field(_field_context_field_name, -1)
		2:
			_move_field(_field_context_field_name, 1)
		3:
			_open_insert_field_left_dialog(_field_context_field_name)
		4:
			var dialog := AcceptDialog.new()
			_on_delete_field_confirmed(dialog, _field_context_field_name)

func _move_field(field_name: String, delta: int) -> void:
	if field_name == "ID":
		set_status("ID 字段位置固定，不支持移动")
		return
	var idx := _current_table_columns.find(field_name)
	if idx < 0:
		return
	var target_idx := clampi(idx + delta, 0, _current_table_columns.size() - 1)
	if target_idx == idx:
		return
	var col := _current_table_columns[idx]
	var typ := _current_table_types[idx] if idx < _current_table_types.size() else "string"
	_current_table_columns.remove_at(idx)
	_current_table_types.remove_at(idx)
	_current_table_columns.insert(target_idx, col)
	_current_table_types.insert(target_idx, typ)
	if _loaded_tables.has(_current_table_name):
		_loaded_tables[_current_table_name]["columns"] = _current_table_columns.duplicate()
		_loaded_tables[_current_table_name]["types"] = _current_table_types.duplicate()
	_refresh_table_view()

func _on_row_context_menu_id_pressed(id: int) -> void:
	match id:
		0:
			_move_row(_row_context_row_id, -1)
		1:
			_move_row(_row_context_row_id, 1)
		2:
			_insert_row_above(_row_context_row_id)
		3:
			_delete_single_row(_row_context_row_id)
		4:
			set_status("分割功能待实现")
		5:
			set_status("查看引用功能待实现")

func _move_row(row_id: String, delta: int) -> void:
	var idx := _row_order.find(row_id)
	if idx < 0:
		return
	var target_idx := clampi(idx + delta, 0, _row_order.size() - 1)
	if target_idx == idx:
		return
	_row_order.remove_at(idx)
	_row_order.insert(target_idx, row_id)
	if _loaded_tables.has(_current_table_name):
		_loaded_tables[_current_table_name]["row_order"] = _row_order.duplicate()
	_refresh_table_view()
	set_status("已移动行: " + row_id)

func _insert_row_above(row_id: String) -> void:
	var idx := _row_order.find(row_id)
	if idx < 0:
		return
	var new_id := "new_row_%d" % (_current_table.size() + 1)
	while _current_table.has(new_id):
		new_id = "new_row_%d" % (randi() % 100000)
	var row_data: Dictionary = {}
	for col in _current_table_columns:
		row_data[col] = ""
	_current_table[new_id] = row_data
	_row_order.insert(idx, new_id)
	if _loaded_tables.has(_current_table_name):
		_loaded_tables[_current_table_name]["data"] = _current_table.duplicate(true)
		_loaded_tables[_current_table_name]["row_order"] = _row_order.duplicate()
	_apply_search_and_filter()
	set_status("已向上插入行: " + new_id)

func _delete_single_row(row_id: String) -> void:
	if not _current_table.has(row_id):
		return
	_current_table.erase(row_id)
	_row_order.erase(row_id)
	_selected_rows.erase(row_id)
	if _loaded_tables.has(_current_table_name):
		_loaded_tables[_current_table_name]["data"] = _current_table.duplicate(true)
		_loaded_tables[_current_table_name]["row_order"] = _row_order.duplicate()
	_apply_search_and_filter()
	set_status("已删除行: " + row_id)

func _open_row_edit_dialog(row_id: String) -> void:
	if not _current_table.has(row_id):
		return
	var dialog := AcceptDialog.new()
	dialog.title = "编辑行: " + row_id
	dialog.ok_button_text = "保存"
	var del_row_btn := dialog.add_button("移除数据", false, "delete_row")
	del_row_btn.modulate = Color(1, 0.45, 0.45)
	var form := GridContainer.new()
	form.columns = 2
	var id_label := Label.new()
	id_label.text = "ID"
	form.add_child(id_label)
	var id_input := LineEdit.new()
	id_input.name = "Field_ID"
	id_input.text = row_id
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
			check.button_pressed = bool(_current_table[row_id].get(col_name, false))
			form.add_child(check)
		else:
			var input := LineEdit.new()
			input.name = "Field_%s" % col_name
			input.text = str(_current_table[row_id].get(col_name, ""))
			form.add_child(input)
	dialog.add_child(form)
	dialog.confirmed.connect(_on_row_edit_dialog_confirmed.bind(dialog, row_id))
	dialog.custom_action.connect(_on_row_edit_dialog_custom_action.bind(dialog, row_id))
	if _host_plugin:
		_host_plugin.get_editor_interface().get_base_control().add_child(dialog)
	dialog.popup_centered(Vector2i(540, 420))

func _on_row_edit_dialog_confirmed(dialog: AcceptDialog, old_row_id: String) -> void:
	var id_input: LineEdit = dialog.get_node("GridContainer/Field_ID")
	var new_row_id := id_input.text.strip_edges()
	if new_row_id.is_empty():
		set_status("ID 不能为空")
		dialog.queue_free()
		return
	if new_row_id != old_row_id and _current_table.has(new_row_id):
		set_status("ID 已存在: " + new_row_id)
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
		else:
			var input: LineEdit = dialog.get_node(node_name)
			row_data[col_name] = _utils.validate_and_convert_value(input.text, col_type)
	_current_table.erase(old_row_id)
	_current_table[new_row_id] = row_data
	var idx := _row_order.find(old_row_id)
	if idx >= 0:
		_row_order[idx] = new_row_id
	if _selected_rows.has(old_row_id):
		_selected_rows.erase(old_row_id)
		_selected_rows[new_row_id] = true
	if _loaded_tables.has(_current_table_name):
		_loaded_tables[_current_table_name]["data"] = _current_table.duplicate(true)
		_loaded_tables[_current_table_name]["row_order"] = _row_order.duplicate()
	_apply_search_and_filter()
	set_status("已更新行: " + new_row_id)
	dialog.queue_free()

func _on_row_edit_dialog_custom_action(action: String, dialog: AcceptDialog, row_id: String) -> void:
	if action != "delete_row":
		return
	_delete_single_row(row_id)
	dialog.queue_free()
