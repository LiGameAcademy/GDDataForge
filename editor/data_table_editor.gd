extends EditorPlugin

## GDDataForge 可视化数据编辑器插件
## 提供数据表的可视化编辑功能

signal table_selected(table_name: String)
signal table_modified(table_name: String)

## 编辑器面板
var _editor_panel: Control
var _table_view: Tree
var _table_list: Tree
var _status_label: Label
var _toolbar_buttons: Array[Button] = []

## 当前编辑的数据表
var _current_table: Dictionary
var _current_table_name: String = ""
var _table_columns: Array[String] = []  # 列名数组
var _table_types: Array[String] = []   # 列类型数组

## 加载的数据表缓存
var _loaded_tables: Dictionary = {}  # {table_name: {data: {}, columns: [], types: []}}

func _enter_tree() -> void:
	# 确保主插件已加载
	_make_visible(false)

func _exit_tree() -> void:
	if _editor_panel:
		_editor_panel.queue_free()

func _has_main_screen() -> bool:
	return true

func _get_plugin_name() -> String:
	return "GDDataForge"

func _get_icon() -> Texture2D:
	return load("res://addons/GDDataForge/examples/assets/sword.svg")

func _make_visible(visible: bool) -> void:
	if _editor_panel:
		_editor_panel.visible = visible
		if visible:
			show_main_screen()

func _get_plugin_state() -> EditorPluginState:
	# 自定义状态检查
	return EditorPlugin.PLUGIN_DEBUG

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_READY:
			_create_editor_panel()
		NOTIFICATION_PREDELETE:
			_save_current_table()

## 创建编辑器面板
func _create_editor_panel() -> void:
	# 创建主面板
	_editor_panel = PanelContainer.new()
	_editor_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_editor_panel.visible = false
	add_control_to_container(EditorPlugin.CONTAINER_PLUGIN_PLUGINS, _editor_panel)
	
	# 创建主容器
	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.theme_override_constants/separation = 4
	_editor_panel.add_child(vbox)
	
	# ===== 工具栏 =====
	var toolbar = HBoxContainer.new()
	toolbar.name = "Toolbar"
	toolbar.size_flags_vertical = Control.SIZE_FLAG_EXPAND_FILL
	vbox.add_child(toolbar)
	
	# 新建表按钮
	var btn_new = Button.new()
	btn_new.text = "新建表"
	btn_new.name = "BtnNew"
	btn_new.pressed.connect(_on_new_table_pressed)
	toolbar.add_child(btn_new)
	_toolbar_buttons.append(btn_new)
	
	# 打开表按钮
	var btn_open = Button.new()
	btn_open.text = "打开表"
	btn_open.name = "BtnOpen"
	btn_open.pressed.connect(_on_open_table_pressed)
	toolbar.add_child(btn_open)
	_toolbar_buttons.append(btn_open)
	
	# 保存按钮
	var btn_save = Button.new()
	btn_save.text = "保存"
	btn_save.name = "BtnSave"
	btn_save.pressed.connect(_on_save_table_pressed)
	toolbar.add_child(btn_save)
	_toolbar_buttons.append(btn_save)
	
	# 添加工具栏分隔
	var sep = HSeparator.new()
	toolbar.add_child(sep)
	
	# 添加行按钮
	var btn_add_row = Button.new()
	btn_add_row.text = "+ 行"
	btn_add_row.name = "BtnAddRow"
	btn_add_row.pressed.connect(_on_add_row_pressed)
	toolbar.add_child(btn_add_row)
	_toolbar_buttons.append(btn_add_row)
	
	# 删除行按钮
	var btn_del_row = Button.new()
	btn_del_row.text = "- 行"
	btn_del_row.name = "BtnDelRow"
	btn_del_row.pressed.connect(_on_delete_row_pressed)
	toolbar.add_child(btn_del_row)
	_toolbar_buttons.append(btn_del_row)
	
	# 添加列按钮
	var btn_add_col = Button.new()
	btn_add_col.text = "+ 列"
	btn_add_col.name = "BtnAddCol"
	btn_add_col.pressed.connect(_on_add_column_pressed)
	toolbar.add_child(btn_add_col)
	_toolbar_buttons.append(btn_add_col)
	
	# 删除列按钮
	var btn_del_col = Button.new()
	btn_del_col.text = "- 列"
	btn_del_col.name = "BtnDelCol"
	btn_del_col.pressed.connect(_on_delete_column_pressed)
	toolbar.add_child(btn_del_col)
	_toolbar_buttons.append(btn_del_col)
	
	# 添加工具栏分隔2
	var sep2 = HSeparator.new()
	toolbar.add_child(sep2)
	
	# 导入按钮
	var btn_import = Button.new()
	btn_import.text = "导入"
	btn_import.name = "BtnImport"
	btn_import.pressed.connect(_on_import_pressed)
	toolbar.add_child(btn_import)
	
	# 导出按钮
	var btn_export = Button.new()
	btn_export.text = "导出"
	btn_export.name = "BtnExport"
	btn_export.pressed.connect(_on_export_pressed)
	toolbar.add_child(btn_export)
	
	# ===== 分隔线 =====
	var hsep = HSeparator.new()
	hsep.name = "HSeparator"
	vbox.add_child(hsep)
	
	# ===== 主内容区 =====
	var main_split = HSplitContainer.new()
	main_split.name = "MainContent"
	main_split.split_offset = 200
	main_split.size_flags_vertical = Control.SIZE_FLAG_EXPAND_FILL
	vbox.add_child(main_split)
	
	# ----- 左侧：数据表列表 -----
	var left_panel = PanelContainer.new()
	left_panel.name = "LeftPanel"
	main_split.add_child(left_panel)
	
	var left_vbox = VBoxContainer.new()
	left_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	left_panel.add_child(left_vbox)
	
	var left_title = Label.new()
	left_title.text = "数据表"
	left_vbox.add_child(left_title)
	
	_table_list = Tree.new()
	_table_list.name = "TableList"
	_table_list.size_flags_vertical = Control.SIZE_FLAG_EXPAND_FILL
	_table_list.item_selected.connect(_on_table_list_item_selected)
	_table_list.item_activated.connect(_on_table_list_item_activated)
	left_vbox.add_child(_table_list)
	
	# ----- 右侧：表格视图 -----
	var right_panel = PanelContainer.new()
	right_panel.name = "RightPanel"
	main_split.add_child(right_panel)
	
	var right_vbox = VBoxContainer.new()
	right_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	right_panel.add_child(right_vbox)
	
	var right_title = Label.new()
	right_title.text = "表格内容"
	right_vbox.add_child(right_title)
	
	_table_view = Tree.new()
	_table_view.name = "TableView"
	_table_view.size_flags_horizontal = Control.SIZE_FLAG_EXPAND_FILL
	_table_view.size_flags_vertical = Control.SIZE_FLAG_EXPAND_FILL
	_table_view.columns = 0  # 动态列
	_table_view.column_titles_visible = true
	_table_view.item_activated.connect(_on_table_view_item_activated)
	_table_view.item_changed.connect(_on_table_view_item_changed)
	right_vbox.add_child(_table_view)
	
	# ===== 状态栏 =====
	_status_label = Label.new()
	_status_label.name = "StatusBar"
	_status_label.text = "就绪"
	vbox.add_child(_status_label)
	
	# 设置状态
	_update_status("编辑器已加载")

## 更新状态栏
func _update_status(text: String) -> void:
	if _status_label:
		_status_label.text = text
	print("[GDDataForge] ", text)

## ===== 信号处理 =====

func _on_new_table_pressed() -> void:
	_update_status("新建表功能开发中...")
	# TODO: 打开新建表对话框

func _on_open_table_pressed() -> void:
	# 打开文件选择器，选择 CSV 或 JSON 文件
	var file_dialog = EditorFileDialog.new()
	file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = ["*.csv", "*.json"]
	file_dialog.file_selected.connect(_on_file_selected)
	# 这里需要特殊处理，因为 EditorFileDialog 不能直接添加到插件
	_update_status("请在资源面板选择 CSV/JSON 文件")

func _on_file_selected(path: String) -> void:
	_load_table_file(path)

func _on_save_table_pressed() -> void:
	if _current_table.is_empty():
		_update_status("没有数据需要保存")
		return
	
	# 保存到文件
	var file_path = _get_current_table_path()
	if file_path.is_empty():
		_update_status("请先创建表")
		return
	
	_save_table_to_file(file_path)
	_update_status("已保存: " + file_path)

func _on_add_row_pressed() -> void:
	# 弹出对话框让用户输入新行 ID
	var dialog = AcceptDialog.new()
	dialog.title = "添加行"
	dialog.ok_button_text = "添加"
	dialog.cancel_button_text = "取消"
	
	var input = LineEdit.new()
	input.name = "RowIdInput"
	input.placeholder_text = "输入行 ID"
	
	var vbox = VBoxContainer.new()
	vbox.add_child(Label.new())
	vbox.add_child(Label.new().with_text("请输入新行的ID:"))
	vbox.add_child(input)
	
	dialog.set_content(vbox)
	# 注意: 这里简化处理，实际需要正确设置 dialog
	_add_row_with_dialog()
	_update_status("请在弹出的对话框中输入行 ID")

func _add_row_with_dialog() -> void:
	# 使用简单的方式：自动生成新 ID
	var new_id = "new_row_%d" % (_current_table.size() + 1)
	var row_data = {}
	for col in _current_table_columns:
		row_data[col] = ""
	
	_current_table[new_id] = row_data
	_refresh_table_view()
	_update_status("已添加新行: " + new_id)
	table_modified.emit(_current_table_name)

func _on_delete_row_pressed() -> void:
	var item = _table_view.get_selected()
	if not item:
		_update_status("请先选择一行")
		return
	
	var row_id = _table_view.get_item_text(item, 0)
	_current_table.erase(row_id)
	_refresh_table_view()
	_update_status("已删除行: " + row_id)
	table_modified.emit(_current_table_name)

func _on_add_column_pressed() -> void:
	# 简单实现：添加列
	var col_name = "column_%d" % (_current_table_columns.size() + 1)
	var col_type = "string"
	
	_current_table_columns.append(col_name)
	_current_table_types.append(col_type)
	
	# 为现有行添加空值
	for row_id in _current_table.keys():
		_current_table[row_id][col_name] = ""
	
	_refresh_table_view()
	_update_status("已添加列: " + col_name)
	table_modified.emit(_current_table_name)

func _on_delete_column_pressed() -> void:
	# 简单实现：删除最后一列
	if _current_table_columns.is_empty():
		_update_status("没有列可删除")
		return
	
	var col_name = _current_table_columns.back()
	_current_table_columns.erase(_current_table_columns.size() - 1)
	_current_table_types.erase(_current_table_types.size() - 1)
	
	# 删除所有行的该列数据
	for row_id in _current_table.keys():
		_current_table[row_id].erase(col_name)
	
	_refresh_table_view()
	_update_status("已删除列: " + col_name)
	table_modified.emit(_current_table_name)

func _on_import_pressed() -> void:
	_update_status("导入功能开发中...")

func _on_export_pressed() -> void:
	_update_status("导出功能开发中...")

## ===== 数据表列表 =====

func _on_table_list_item_selected() -> void:
	var item = _table_list.get_selected()
	if item:
		var table_name = _table_list.get_item_text(item)
		_load_table_by_name(table_name)

func _on_table_list_item_activated() -> void:
	_on_table_list_item_selected()

## 刷新数据表列表
func _refresh_table_list() -> void:
	_table_list.clear()
	var root = _table_list.create_item()
	root.text = "数据表"
	root.collapsed = true
	
	for table_name in _loaded_tables.keys():
		var item = _table_list.create_item(root)
		item.text = table_name
		item.set_icon(0, load("res://addons/GDDataForge/examples/assets/sword.svg"))

## ===== 表格视图 =====

## 加载数据表
func _load_table_by_name(table_name: String) -> void:
	if not _loaded_tables.has(table_name):
		_update_status("表不存在: " + table_name)
		return
	
	_current_table = _loaded_tables[table_name].duplicate(true)
	_current_table_name = table_name
	_current_table_columns = _loaded_tables[table_name].get("columns", [])
	_current_table_types = _loaded_tables[table_name].get("types", [])
	
	_refresh_table_view()
	_update_status("已加载: " + table_name)
	table_selected.emit(table_name)

## 刷新表格视图
func _refresh_table_view() -> void:
	_table_view.clear()
	
	if _current_table.is_empty():
		return
	
	# 设置列
	var columns = ["ID"] + _current_table_columns
	_table_view.columns = columns.size()
	
	for i in range(columns.size()):
		_table_view.set_column_title(i, columns[i])
		_table_view.set_column_expand(i, true if i > 0 else false)
		_table_view.set_column_min_width(i, 100)
	
	# 添加数据行
	for row_id in _current_table.keys():
		var row_data = _current_table[row_id]
		var item = _table_view.create_item()
		
		# ID 列
		item.set_text(0, row_id)
		
		# 数据列
		for i in range(_current_table_columns.size()):
			var col_name = _current_table_columns[i]
			if row_data.has(col_name):
				item.set_text(i + 1, str(row_data[col_name]))

## 表格项双击编辑
func _on_table_view_item_activated() -> void:
	var item = _table_view.get_selected()
	if not item:
		return
	
	var column = _table_view.get_selected_column()
	if column == 0:
		_update_status("ID 列不能编辑")
		return
	
	# 简单的单元格编辑：直接弹出输入框
	_show_cell_edit_dialog(item, column)

## 数据变更处理
func _on_table_view_item_changed(item: TreeItem) -> void:
	# 当单元格编辑完成后更新数据
	var row_id = _table_view.get_item_text(item, 0)
	var column = _table_view.get_selected_column()
	if column <= 0:
		return
	
	var col_name = _current_table_columns[column - 1]
	var new_value = _table_view.get_item_text(item, column)
	
	# 类型转换
	if column - 1 < _current_table_types.size():
		var expected_type = _current_table_types[column - 1]
		new_value = _validate_and_convert_value(new_value, expected_type)
	
	_current_table[row_id][col_name] = new_value
	table_modified.emit(_current_table_name)

## 单元格编辑弹窗
func _show_cell_edit_dialog(item: TreeItem, column: int) -> void:
	# 这是简化实现，实际需要自定义 Dialog
	# Godot 4.x 中 Tree 的单元格编辑比较复杂
	# 这里用状态消息提示用户
	var col_name = _current_table_columns[column - 1] if column - 1 < _current_table_columns.size() else "?"
	var current_value = item.get_text(column)
	_update_status("编辑列: " + col_name + " = " + current_value)
	# TODO: 实现真正的单元格编辑

## ===== 文件加载 =====

func _load_table_file(file_path: String) -> void:
	if not FileAccess.file_exists(file_path):
		_update_status("文件不存在: " + file_path)
		return
	
	var ext = file_path.get_extension().to_lower()
	var table_data: Dictionary = {}
	var columns: Array[String] = []
	var types: Array[String] = []
	var table_name = file_path.get_file().get_basename()
	
	match ext:
		"csv":
			table_data = _parse_csv_file(file_path)
			# 列信息已在 _parse_csv_file 中填充到 _current_table_columns/_current_table_types
			columns = _current_table_columns.duplicate()
			types = _current_table_types.duplicate()
		"json":
			table_data = _parse_json_file(file_path)
			# JSON 格式：需要从第一条数据推断列类型
			columns = _extract_columns_from_json(table_data)
			types = _extract_types_from_json(table_data)
	
	# 缓存数据表
	_loaded_tables[table_name] = {
		"data": table_data,
		"path": file_path,
		"columns": columns,
		"types": types
	}
	
	# 刷新列表
	_refresh_table_list()
	
	# 自动加载
	_load_table_by_name(table_name)
	
	_update_status("已加载: " + table_name)

## 从 JSON 数据提取列名
func _extract_columns_from_json(data: Dictionary) -> Array[String]:
	var columns: Array[String] = []
	if data.is_empty():
		return columns
	
	# 取第一条数据获取键名
	var first_row = data.values()[0]
	if typeof(first_row) == TYPE_DICTIONARY:
		for key in first_row.keys():
			columns.append(key)
	
	return columns

## 从 JSON 数据推断列类型
func _extract_types_from_json(data: Dictionary) -> Array[String]:
	var types: Array[String] = []
	if data.is_empty():
		return types
	
	# 取第一条数据推断类型
	var first_row = data.values()[0]
	if typeof(first_row) == TYPE_DICTIONARY:
		for key in first_row.keys():
			var value = first_row[key]
			var type_name = "string"
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

func _parse_csv_file(file_path: String) -> Dictionary:
	var result = {}
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return result
	
	# 读取列名
	var data_names = file.get_csv_line(",")
	# 读取注释行（跳过）
	var comments = file.get_csv_line(",")
	# 读取类型
	var data_types = file.get_csv_line(",")
	
	# 存储列信息（转换为 Array）
	_current_table_columns = []
	for name in data_names:
		_current_table_columns.append(name)
	_current_table_types = []
	for t in data_types:
		_current_table_types.append(t)
	
	# 读取数据
	while not file.eof_reached():
		var row = file.get_csv_line(",")
		if row.is_empty():
			continue
		
		var row_data = {}
		for i in range(data_names.size()):
			var data_name = data_names[i]
			var data_type = data_types[i] if i < data_types.size() else "string"
			if data_name.is_empty():
				continue
			
			# 基础类型解析
			var value = row[i] if i < row.size() else ""
			row_data[data_name] = _parse_value(value, data_type)
		
		if row_data.has("ID") and not row_data["ID"].is_empty():
			result[row_data["ID"]] = row_data
	
	file.close()
	return result

func _parse_json_file(file_path: String) -> Dictionary:
	var result = {}
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return result
	
	var content = file.get_as_text()
	file.close()
	
	# 简单的 JSON 解析
	var json = JSON.new()
	var parse_result = json.parse(content)
	if parse_result != OK:
		return result
	
	var json_data = json.get_data()
	if typeof(json_data) == TYPE_DICTIONARY:
		result = json_data
	
	return result

## 基础类型解析
func _parse_value(value: String, type: String) -> Variant:
	match type:
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

## ===== 文件保存 =====

func _get_current_table_path() -> String:
	if _loaded_tables.has(_current_table_name):
		return _loaded_tables[_current_table_name].get("path", "")
	return ""

func _save_table_to_file(file_path: String) -> void:
	var ext = file_path.get_extension().to_lower()
	
	match ext:
		"csv":
			_save_csv_file(file_path)
		"json":
			_save_json_file(file_path)

func _save_csv_file(file_path: String) -> void:
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		_update_status("无法保存文件")
		return
	
	# 写入列名
	var header = PackedStringArray()
	header.append("ID")
	header.append_array(_current_table_columns)
	file.store_csv_line(header, ",")
	
	# 写入注释行（留空）
	var comments = PackedStringArray()
	for col in _current_table_columns:
		comments.append("")
	file.store_csv_line(comments, ",")
	
	# 写入类型
	var types = PackedStringArray()
	types.append("string")  # ID ��型
	types.append_array(_current_table_types)
	file.store_csv_line(types, ",")
	
	# 写入数据
	for row_id in _current_table.keys():
		var row_data = _current_table[row_id]
		var row = PackedStringArray()
		row.append(row_id)
		for col in _current_table_columns:
			row.append(str(row_data.get(col, "")))
		file.store_csv_line(row, ",")
	
	file.close()

func _save_json_file(file_path: String) -> void:
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		_update_status("无法保存文件")
		return
	
	# 简单的 JSON 序列化
	var json_string = JSON.stringify(_current_table, "\t")
	file.store_string(json_string)
	file.close()

func _save_current_table() -> void:
	# 自动保存当前编辑的表
	if not _current_table.is_empty():
		var path = _get_current_table_path()
		if not path.is_empty():
			_save_table_to_file(path)