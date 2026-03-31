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

## 主键/外键定义
var _primary_key: String = "ID"  # 默认主键
var _foreign_keys: Array[Dictionary] = []  #  [{"field": "type_id", "target_table": "weapon_types", "target_field": "ID"}]

## 字段校验规则定义
# 格式: {column_name: "PRIMARY_KEY|REQUIRED|UNIQUE|RANGE:1-100|REGEX:^[a-z]+$|FOREIGN:table.field"}
var _field_validation_rules: Dictionary = {}  # {field_name: ["REQUIRED", "UNIQUE", "RANGE:1-100"]}

## 搜索和过滤
var _search_text: String = ""
var _search_column: String = ""  # 空 = 搜索所有列
var _filter_column: String = ""
var _filter_value: String = ""
var _sort_column: String = ""
var _sort_ascending: bool = true
var _is_filtered: bool = false

## 过滤后的数据视图
var _filtered_table: Dictionary

## ===== 命令模式：撤销/重做系统 =====

## 命令接口
class ICommand:
	var description: String
	func execute() -> void:
		pass
	func undo() -> void:
		pass

## 添加行命令
class AddRowCommand extends ICommand:
	var table: Dictionary
	var row_id: String
	var row_data: Dictionary
	
	func _init(t: Dictionary, rid: String, rdata: Dictionary):
		table = t
		row_id = rid
		row_data = rdata.duplicate(true)
		description = "添加行: " + row_id
	
	func execute() -> void:
		table[row_id] = row_data.duplicate(true)
	
	func undo() -> void:
		table.erase(row_id)

## 删除行命令
class DeleteRowCommand extends ICommand:
	var table: Dictionary
	var row_id: String
	var row_data: Dictionary
	
	func _init(t: Dictionary, rid: String):
		table = t
		row_id = rid
		row_data = {}.duplicate()
		description = "删除行: " + row_id
	
	func execute() -> void:
		if table.has(row_id):
			row_data = table[row_id].duplicate(true)
			table.erase(row_id)
	
	func undo() -> void:
		table[row_id] = row_data.duplicate(true)

## 更新单元格命令
class UpdateCellCommand extends ICommand:
	var table: Dictionary
	var row_id: String
	var column: String
	var old_value: Variant
	var new_value: Variant
	
	func _init(t: Dictionary, rid: String, col: String, old: Variant, new_val: Variant):
		table = t
		row_id = rid
		column = col
		old_value = old
		new_value = new_val
		description = "修改 %s.%s" % [row_id, column]
	
	func execute() -> void:
		if table.has(row_id):
			table[row_id][column] = new_value
	
	func undo() -> void:
		if table.has(row_id):
			table[row_id][column] = old_value

## 添加列命令
class AddColumnCommand extends ICommand:
	var columns: Array[String]
	var types: Array[String]
	var col_name: String
	var col_type: String
	var default_value: Variant
	
	func _init(cols: Array[String], types: Array[String], cn: String, ct: String):
		columns = cols
		types = types
		col_name = cn
		col_type = ct
		default_value = ""
		description = "添加列: " + col_name
	
	func execute() -> void:
		columns.append(col_name)
		types.append(col_type)
	
	func undo() -> void:
		var idx = columns.find(col_name)
		if idx >= 0:
			columns.remove_at(idx)
			types.remove_at(idx)

## 删除列命令
class DeleteColumnCommand extends ICommand:
	var columns: Array[String]
	var types: Array[String]
	var idx: int
	var col_name: String
	var col_type: String
	
	func _init(cols: Array[String], types: Array[String], cn: String, ct: String):
		columns = cols
		types = types
		col_name = cn
		col_type = ct
		idx = cols.find(cn)
		description = "删除列: " + col_name
	
	func execute() -> void:
		if idx >= 0:
			columns.remove_at(idx)
			types.remove_at(idx)
	
	func undo() -> void:
		columns.insert(idx, col_name)
		types.insert(idx, col_type)

## 历史管理器
var _undo_stack: Array[ICommand] = []
var _redo_stack: Array[ICommand] = []
var _max_history: int = 50  # 最大历史记录数

## 执行命令（并添加到撤销栈）
func _execute_command(cmd: ICommand) -> void:
	cmd.execute()
	_undo_stack.append(cmd)
	_redo_stack.clear()  # 新命令清除重做栈
	
	# 限制历史记录数
	if _undo_stack.size() > _max_history:
		_undo_stack.pop_front()
	
	# 刷新 UI
	_refresh_table_view()
	_refresh_validation_rules_ui()
	print("[GDDataForge] 已执行: " + cmd.description)

## 预定义校验规则枚举
enum ValidationRuleType:
    REQUIRED = "REQUIRED"      # 必填
    UNIQUE = "UNIQUE"          # 唯一
    PRIMARY_KEY = "PRIMARY_KEY" # 主键
    RANGE = "RANGE"           # 范围: RANGE:min-max
    REGEX = "REGEX"           # 正则: REGEX:pattern
    MIN = "MIN"               # 最小值: MIN:n
    MAX = "MAX"               # 最大值: MAX:n
    FOREIGN = "FOREIGN"       # 外键: FOREIGN:table.field
    EMAIL = "EMAIL"           # 邮箱格式
    URL = "URL"               # URL 格式
    CUSTOM = "CUSTOM"         # 自定义: CUSTOM:function_name

## 校验规则定义类
class ValidationRule:
    var name: String
    var display_name: String
    var description: String
    var param_required: bool  # 是否需要参数
    var apply_types: Array[String]  # 适用的字段类型
    
    func _init(n: String, dn: String, desc: String, param: bool = false, types: Array[String] = []):
        name = n
        display_name = dn
        description = desc
        param_required = param
        apply_types = types

## 内置校验规则注册表
var _validation_rule_registry: Array[ValidationRule] = []

## 字段校验规则定义
# 格式: {column_name: "PRIMARY_KEY|REQUIRED|UNIQUE|RANGE:1-100|REGEX:^[a-z]+$"}

## 节点引用
var _primary_key_option: OptionButton
var _foreign_key_tree: Tree
var _validation_panel: PanelContainer  # 字段校验规则面板

## 节点引用
var _primary_key_option: OptionButton
var _foreign_key_tree: Tree

## 加载的数据表缓存
var _loaded_tables: Dictionary = {}  # {table_name: {data: {}, columns: [], types: []}}

## 热加载系统
var _hot_load_enabled: bool = false
var _hot_load_timer: Timer
var _file_mod_times: Dictionary = {}  # {file_path: last_modified_time}

## 热加载设置
const HOT_LOAD_INTERVAL: float = 2.0  # 秒

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
			_register_default_validation_rules()
		NOTIFICATION_PREDELETE:
			_save_current_table()

## 注册默认校验规则
func _register_default_validation_rules() -> void:
	_validation_rule_registry = []
	
	# REQUIRED - 必填
	_validation_rule_registry.append(ValidationRule.new(
		"REQUIRED", "必填", "字段值不能为空", false, ["string", "int", "float"]))
	
	# UNIQUE - 唯一
	_validation_rule_registry.append(ValidationRule.new(
		"UNIQUE", "唯一", "字段值不能重复", false, ["string", "int", "float"]))
	
	# PRIMARY_KEY - 主键
	_validation_rule_registry.append(ValidationRule.new(
		"PRIMARY_KEY", "主键", "作为表的主键", false, ["string", "int"]))
	
	# RANGE - 数值范围
	_validation_rule_registry.append(ValidationRule.new(
		"RANGE", "范围", "数值必须落在指定范围内", true, ["int", "float"]))
	
	# MIN - 最小值
	_validation_rule_registry.append(ValidationRule.new(
		"MIN", "最小值", "数值必须大于等于指定值", true, ["int", "float"]))
	
	# MAX - 最大值
	_validation_rule_registry.append(ValidationRule.new(
		"MAX", "最大值", "数值必须小于等于指定值", true, ["int", "float"]))
	
	# REGEX - 正则表达式
	_validation_rule_registry.append(ValidationRule.new(
		"REGEX", "正则", "必须匹配指定的正则表达式", true, ["string"]))
	
	# EMAIL - 邮箱
	_validation_rule_registry.append(ValidationRule.new(
		"EMAIL", "邮箱", "必须是有效的邮箱格式", false, ["string"]))
	
	# URL - 网址
	_validation_rule_registry.append(ValidationRule.new(
		"URL", "网址", "必须是有效的URL格式", false, ["string"]))
	
	# CUSTOM - 自定义函数
	_validation_rule_registry.append(ValidationRule.new(
		"CUSTOM", "自定义", "调用自定义校验函数", true, ["string", "int", "float", "bool", "vector2"]))
	
	print("[GDDataForge] 已注册 %d 个校验规则" % _validation_rule_registry.size())

## 注册自定义校验规则（供外部调用）
func register_validation_rule(rule: ValidationRule) -> void:
	_validation_rule_registry.append(rule)
	print("[GDDataForge] 已注册自定义校验规则: %s" % rule.name)

## 移除自定义校验规则
func unregister_validation_rule(rule_name: String) -> void:
	var index = _validation_rule_registry.find_custom(func(r): return r.name == rule_name)
	if index >= 0:
		_validation_rule_registry.remove_at(index)
		print("[GDDataForge] 已移除校验规则: %s" % rule_name)

## 获取校验规则列表
func get_validation_rules() -> Array[ValidationRule]:
	return _validation_rule_registry

## 获取适用当前字段类型的校验规则
func get_applicable_rules(field_type: String) -> Array[ValidationRule]:
	var result: Array[ValidationRule] = []
	for rule in _validation_rule_registry:
		if rule.apply_types.is_empty() or field_type in rule.apply_types:
			result.append(rule)
	return result

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
	
	# 添加工具栏分隔0
	var sep0 = HSeparator.new()
	toolbar.add_child(sep0)
	
	# 撤销按钮
	var btn_undo = Button.new()
	btn_undo.text = "↩ 撤销"
	btn_undo.name = "BtnUndo"
	btn_undo.disabled = true
	btn_undo.pressed.connect(_on_undo_pressed)
	toolbar.add_child(btn_undo)
	
	# 重做按钮
	var btn_redo = Button.new()
	btn_redo.text = "↪ 重做"
	btn_redo.name = "BtnRedo"
	btn_redo.disabled = true
	btn_redo.pressed.connect(_on_redo_pressed)
	toolbar.add_child(btn_redo)
	
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
	
	# 校验按钮
	var btn_validate = Button.new()
	btn_validate.text = "校验"
	btn_validate.name = "BtnValidate"
	btn_validate.pressed.connect(_on_validate_pressed)
	toolbar.add_child(btn_validate)
	
	# 添加工具栏分隔3
	var sep3 = HSeparator.new()
	toolbar.add_child(sep3)
	
	# 搜索输入框
	var search_input = LineEdit.new()
	search_input.name = "SearchInput"
	search_input.custom_minimum_size.x = 150
	search_input.placeholder_text = "搜索..."
	search_input.text_changed.connect(_on_search_text_changed)
	toolbar.add_child(search_input)
	
	# 搜索列选择
	var search_col_option = OptionButton.new()
	search_col_option.name = "SearchColumnOption"
	search_col_option.custom_minimum_size.x = 80
	search_col_option.add_item("全部列", 0)
	search_col_option.item_selected.connect(_on_search_column_changed)
	toolbar.add_child(search_col_option)
	
	# 过滤列选择
	var filter_col_option = OptionButton.new()
	filter_col_option.name = "FilterColumnOption"
	filter_col_option.custom_minimum_size.x = 80
	filter_col_option.add_item("不过滤", 0)
	filter_col_option.item_selected.connect(_on_filter_column_changed)
	toolbar.add_child(filter_col_option)
	
	# 过滤值输入
	var filter_value_input = LineEdit.new()
	filter_value_input.name = "FilterValueInput"
	filter_value_input.custom_minimum_size.x = 100
	filter_value_input.placeholder_text = "过滤值..."
	filter_value_input.text_changed.connect(_on_filter_value_changed)
	toolbar.add_child(filter_value_input)
	
	# 清除过滤按钮
	var btn_clear_filter = Button.new()
	btn_clear_filter.text = "清除"
	btn_clear_filter.name = "BtnClearFilter"
	btn_clear_filter.pressed.connect(_on_clear_filter_pressed)
	toolbar.add_child(btn_clear_filter)
	
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
	
	# 批量导入按钮
	var btn_batch_import = Button.new()
	btn_batch_import.text = "批量导入"
	btn_batch_import.name = "BtnBatchImport"
	btn_batch_import.pressed.connect(_on_batch_import_pressed)
	toolbar.add_child(btn_batch_import)
	
	# 批量导出按钮
	var btn_batch_export = Button.new()
	btn_batch_export.text = "批量导出"
	btn_batch_export.name = "BtnBatchExport"
	btn_batch_export.pressed.connect(_on_batch_export_pressed)
	toolbar.add_child(btn_batch_export)
	
	# 热加载开关
	var chk_hot_load = CheckBox.new()
	chk_hot_load.text = "热加载"
	chk_hot_load.button_toggled.connect(_on_hot_load_toggled)
	toolbar.add_child(chk_hot_load)
	
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
	
	# ----- 中间：表格视图 -----
	var center_panel = PanelContainer.new()
	center_panel.name = "CenterPanel"
	main_split.add_child(center_panel)
	
	var center_vbox = VBoxContainer.new()
	center_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_panel.add_child(center_vbox)
	
	var center_title = Label.new()
	center_title.text = "表格内容"
	center_vbox.add_child(center_title)
	
	_table_view = Tree.new()
	_table_view.name = "TableView"
	_table_view.size_flags_horizontal = Control.SIZE_FLAG_EXPAND_FILL
	_table_view.size_flags_vertical = Control.SIZE_FLAG_EXPAND_FILL
	_table_view.columns = 0  # 动态列
	_table_view.column_titles_visible = true
	_table_view.item_activated.connect(_on_table_view_item_activated)
	_table_view.item_changed.connect(_on_table_view_item_changed)
	center_vbox.add_child(_table_view)
	
	# ----- 右侧：主键/外键定义 -----
	var right_panel = PanelContainer.new()
	right_panel.name = "RightPanel"
	main_split.add_child(right_panel)
	
	var right_vbox = VBoxContainer.new()
	right_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	right_panel.add_child(right_vbox)
	
	var pk_title = Label.new()
	pk_title.text = "字段定义"
	right_vbox.add_child(pk_title)
	
	# 主键选择
	var pk_label = Label.new()
	pk_label.text = "主键字段:"
	right_vbox.add_child(pk_label)
	
	var pk_option = OptionButton.new()
	pk_option.name = "PrimaryKeyOption"
	pk_option.item_selected.connect(_on_primary_key_changed)
	right_vbox.add_child(pk_option)
	_primary_key_option = pk_option
	
	# 校验规则标题
	var val_title = Label.new()
	val_title.text = "字段校验规则:"
	right_vbox.add_child(val_title)
	
	# 校验规则滚动面板
	var val_scroll = ScrollContainer.new()
	val_scroll.name = "ValidationScroll"
	val_scroll.size_flags_vertical = Control.SIZE_FLAG_EXPAND_FILL
	right_vbox.add_child(val_scroll)
	
	var val_vbox = VBoxContainer.new()
	val_vbox.name = "ValidationRules"
	val_scroll.add_child(val_vbox)
	
	# 动态生成字段校验规则行
	# 这里会在 _load_table_by_name 中动态创建
	
	# 分隔
	var sep = HSeparator.new()
	right_vbox.add_child(sep)
	
	# 外键引用
	var fk_label = Label.new()
	fk_label.text = "外键引用:"
	right_vbox.add_child(fk_label)
	
	var fk_tree = Tree.new()
	fk_tree.name = "ForeignKeyTree"
	fk_tree.size_flags_vertical = Control.SIZE_FLAG_EXPAND_FILL
	right_vbox.add_child(fk_tree)
	_foreign_key_tree = fk_tree
	
	# 添加外键按钮
	var btn_add_fk = Button.new()
	btn_add_fk.text = "+ 添加外键"
	btn_add_fk.pressed.connect(_on_add_foreign_key_pressed)
	right_vbox.add_child(btn_add_fk)
	
	# 删除外键按钮
	var btn_del_fk = Button.new()
	btn_del_fk.text = "- 删除外键"
	btn_del_fk.pressed.connect(_on_delete_foreign_key_pressed)
	right_vbox.add_child(btn_del_fk)
	
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
	
	# 使用命令模式
	var cmd = AddRowCommand.new(_current_table, new_id, row_data)
	_execute_command(cmd)
	
	# 同时添加到过滤表
	if _filtered_table.has(new_id) or _is_filtered:
		_filtered_table[new_id] = row_data.duplicate()
	
	table_modified.emit(_current_table_name)

func _on_delete_row_pressed() -> void:
	var item = _table_view.get_selected()
	if not item:
		_update_status("请先选择一行")
		return
	
	var row_id = _table_view.get_item_text(item, 0)
	
	# 使用命令模式
	var cmd = DeleteRowCommand.new(_current_table, row_id)
	_execute_command(cmd)
	
	# 同时删除过滤表中的行
	if _filtered_table.has(row_id):
		_filtered_table.erase(row_id)
	
	_refresh_table_view()
	_update_status("已删除行: " + row_id)
	table_modified.emit(_current_table_name)
	_refresh_table_view()
	_refresh_validation_rules_ui()
	_update_status("已删除行: " + row_id)
	table_modified.emit(_current_table_name)

func _on_add_column_pressed() -> void:
	# 简单实现：添加列
	var col_name = "column_%d" % (_current_table_columns.size() + 1)
	var col_type = "string"
	
	# 使用命令模式
	var cmd = AddColumnCommand.new(
		_current_table_columns, 
		_current_table_types, 
		col_name, 
		col_type
	)
	_execute_command(cmd)
	
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
	var col_type = _current_table_types.back()
	
	# 使用命令模式
	var cmd = DeleteColumnCommand.new(
		_current_table_columns,
		_current_table_types,
		col_name,
		col_type
	)
	_execute_command(cmd)
	
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

## ===== 批量导入/导出 =====

## 批量导入
func _on_batch_import_pressed() -> void:
	# 扫描 data 文件夹下的所有 CSV/JSON 文件
	var data_folder = "res://addons/GDDataForge/examples/data_table"
	if not DirAccess.dir_exists_absolute(data_folder):
		# 尝试其他可能的数据目录
		data_folder = "res://data"
	
	var files = _scan_data_files(data_folder)
	if files.is_empty():
		_update_status("未找到数据文件")
		return
	
	var imported_count = 0
	for file_path in files:
		if _load_table_file(file_path):
			imported_count += 1
	
	_update_status("批量导入完成: %d 个文件" % imported_count)

## 批量导出
func _on_batch_export_pressed() -> void:
	if _loaded_tables.is_empty():
		_update_status("没有已加载的数据表")
		return
	
	var export_folder = "res://addons/GDDataForge/exported_data"
	
	# 确保目录存在
	if not DirAccess.dir_exists_absolute(export_folder):
		DirAccess.make_dir_recursive_absolute(export_folder)
	
	var exported_count = 0
	for table_name in _loaded_tables.keys():
		var table_data = _loaded_tables[table_name]
		_current_table_name = table_name
		_current_table = table_data.get("data", {}).duplicate(true)
		_current_table_columns = table_data.get("columns", [])
		_current_table_types = table_data.get("types", [])
		
		var export_path = export_folder + "/" + table_name + ".csv"
		_save_table_to_file(export_path)
		exported_count += 1
	
	_update_status("批量导出完成: %d 个文件" % exported_count)

## ===== 热加载系统 =====

## 启动热加载
func _start_hot_load() -> void:
	if _hot_load_enabled:
		return
	
	_hot_load_enabled = true
	_hot_load_timer = Timer.new()
	_hot_load_timer.wait_time = HOT_LOAD_INTERVAL
	_hot_load_timer.timeout.connect(_on_hot_load_check)
	add_child(_hot_load_timer)
	_hot_load_timer.start()
	
	# 记录初始文件修改时间
		for table_name in _loaded_tables.keys():
			var table = _loaded_tables[table_name]
			var path = table.get("path", "")
			if not path.is_empty():
				_file_mod_times[path] = FileAccess.get_modified_time(path)
	
	_update_status("热加载已启动")

## 热加载开关回调
func _on_hot_load_toggled(button_pressed: bool) -> void:
	if button_pressed:
		_start_hot_load()
	else:
		_stop_hot_load()

## 停止热加载
func _stop_hot_load() -> void:
	if not _hot_load_enabled:
		return
	
	_hot_load_enabled = false
	if _hot_load_timer:
		_hot_load_timer.stop()
		_hot_load_timer.queue_free()
		_hot_load_timer = null
	
	_update_status("热加载已停止")

## 热加载检查
func _on_hot_load_check() -> void:
	var modified_files: Array[String] = []
	
	for file_path in _file_mod_times.keys():
		if not FileAccess.file_exists(file_path):
			continue
		
		var current_time = FileAccess.get_modified_time(file_path)
		var last_time = _file_mod_times[file_path]
		
		if current_time > last_time:
			modified_files.append(file_path)
			_file_mod_times[file_path] = current_time
	
	if not modified_files.is_empty():
		_reload_modified_files(modified_files)

## 重新加载已修改的文件
func _reload_modified_files(files: Array[String]) -> void:
	var reloaded_count = 0
	
	for file_path in files:
		var table_name = file_path.get_file().get_basename()
		
		# 保存当前编辑状态
		var current_data = {}
		if _current_table_name == table_name:
			current_data = _current_table.duplicate(true)
		
		# 重新加载
		_load_table_file(file_path)
		
		# 如果是当前正在编辑的表，恢复光标位置等
		if _current_table_name == table_name:
			pass  # 可扩展：恢复选中行
		
		reloaded_count += 1
	
	if reloaded_count > 0:
		_update_status("热加载更新: %d 个文件" % reloaded_count)
		print("[GDDataForge] 热载了 %d 个文件" % reloaded_count)

## 扫描数据文件
func _scan_data_files(folder: String) -> Array[String]:
	var result: Array[String] = []
	
	var dir = DirAccess.open(folder)
	if not dir:
		return result
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if not dir.current_is_dir():
			var ext = file_name.get_extension().to_lower()
			if ext == "csv" or ext == "json":
				result.append(folder + "/" + file_name)
		file_name = dir.get_next()
	
	dir.list_dir_end()
	return result

## 批量合并导入（合并到当前表）
func _on_merge_import_pressed() -> void:
	# TODO: 实现批量合并导入
	_update_status("批量合并导入功能开发中...")

## 批量替换导出（导出所有为不同文件）
func _on_export_all_pressed() -> void:
	# TODO: 实现批量替换导出
	_update_status("批量替换导出功能开发中...")

## ===== 主键/外键操作 =====

## 主键选择变更
func _on_primary_key_changed(index: int) -> void:
	if index == 0:
		_primary_key = ""
	else:
		_primary_key = _current_table_columns[index - 1]
	
	# 保存到缓存
	if _loaded_tables.has(_current_table_name):
		_loaded_tables[_current_table_name]["primary_key"] = _primary_key
	
	_update_status("主键已设置为: " + _primary_key if not _primary_key.is_empty() else "无主键")
	table_modified.emit(_current_table_name)

## 添加外键
func _on_add_foreign_key_pressed() -> void:
	if _current_table_columns.is_empty():
		_update_status("请先加载数据表")
		return
	
	# 简单实现：使用第一个列作为外键字段，弹窗选择目标表
	var sample_fk = {
		"field": _current_table_columns[0] if _current_table_columns.size() > 0 else "",
		"target_table": "target_table",
		"target_field": "ID"
	}
	_foreign_keys.append(sample_fk)
	_refresh_foreign_key_tree()
	_update_status("已添加外键引用")
	table_modified.emit(_current_table_name)

## 删除外键
func _on_delete_foreign_key_pressed() -> void:
	var item = _foreign_key_tree.get_selected()
	if not item:
		_update_status("请先选择要删除的外键")
		return
	
	var fk = item.get_metadata(0)
	if fk in _foreign_keys:
		_foreign_keys.erase(fk)
	_refresh_foreign_key_tree()
	_update_status("已删除外键引用")
	table_modified.emit(_current_table_name)

## ===== 搜索和过滤 =====

## 搜索文本变更
func _on_search_text_changed(text: String) -> void:
	_search_text = text
	_apply_search_and_filter()

## 搜索列变更
func _on_search_column_changed(index: int) -> void:
	if index == 0:
		_search_column = ""
	else:
		_search_column = _current_table_columns[index - 1] if index - 1 < _current_table_columns.size() else ""
	_apply_search_and_filter()

## 过滤列变更
func _on_filter_column_changed(index: int) -> void:
	if index == 0:
		_filter_column = ""
	else:
		_filter_column = _current_table_columns[index - 1] if index - 1 < _current_table_columns.size() else ""
	_apply_search_and_filter()

## 过滤值变更
func _on_filter_value_changed(text: String) -> void:
	_filter_value = text
	_apply_search_and_filter()

## 清除过滤
func _on_clear_filter_pressed() -> void:
	_search_text = ""
	_search_column = ""
	_filter_column = ""
	_filter_value = ""
	_is_filtered = false
	
	# 清空输入框
	var search_input = _find_node_by_name(_editor_panel, "SearchInput")
	if search_input and search_input is LineEdit:
		search_input.text = ""
	
	var filter_input = _find_node_by_name(_editor_panel, "FilterValueInput")
	if filter_input and filter_input is LineEdit:
		filter_input.text = ""
	
	_apply_search_and_filter()
	_update_status("已清除过滤")

## ===== 撤销/重做 =====

## 撤销
func _on_undo_pressed() -> void:
	if _undo_stack.is_empty():
		_update_status("没有可撤销的操作")
		return
	
	var cmd = _undo_stack.back()
	cmd.undo()
	_undo_stack.pop_back()
	_redo_stack.append(cmd)
	
	_update_undo_redo_buttons()
	_refresh_table_view()
	_update_status("已撤销: " + cmd.description)

## 重做
func _on_redo_pressed() -> void:
	if _redo_stack.is_empty():
		_update_status("没有可重做的操作")
		return
	
	var cmd = _redo_stack.back()
	cmd.execute()
	_redo_stack.pop_back()
	_undo_stack.append(cmd)
	
	_update_undo_redo_buttons()
	_refresh_table_view()
	_update_status("已重做: " + cmd.description)

## 更新撤销/重做按钮状态
func _update_undo_redo_buttons() -> void:
	var undo_btn = _find_node_by_name(_editor_panel, "BtnUndo")
	var redo_btn = _find_node_by_name(_editor_panel, "BtnRedo")
	
	if undo_btn and undo_btn is Button:
		undo_btn.disabled = _undo_stack.is_empty()
		undo_btn.text = "↩ 撤销 (%d)" % _undo_stack.size() if not _undo_stack.is_empty() else "↩ 撤销"
	
	if redo_btn and redo_btn is Button:
		redo_btn.disabled = _redo_stack.is_empty()
		redo_btn.text = "↪ 重做 (%d)" % _redo_stack.size() if not _redo_stack.is_empty() else "↪ 重做"

## 应用搜索和过滤
func _apply_search_and_filter() -> void:
	_filtered_table = _current_table.duplicate(true)
	
	var count_before = _filtered_table.size()
	
	# 1. 应用搜索过滤（文本搜索）
	if not _search_text.is_empty():
		var temp_table = {}
		for row_id in _filtered_table.keys():
			var row = _filtered_table[row_id]
			var matched = false
			
			if _search_column.is_empty():
				# 搜索所有列
				for col in _current_table_columns:
					var value = str(row.get(col, ""))
					if _search_text.to_lower() in value.to_lower():
						matched = true
						break
			else:
				# 搜索指定列
				var value = str(row.get(_search_column, ""))
				if _search_text.to_lower() in value.to_lower():
					matched = true
			
			if matched:
				temp_table[row_id] = row
		
		_filtered_table = temp_table
	
	# 2. 应用列过滤（精确匹配）
	if not _filter_column.is_empty() and not _filter_value.is_empty():
		var temp_table = {}
		for row_id in _filtered_table.keys():
			var row = _filtered_table[row_id]
			var value = str(row.get(_filter_column, ""))
			if value == _filter_value:
				temp_table[row_id] = row
		_filtered_table = temp_table
	
	# 3. 应用排序
	_apply_sort()
	
	_is_filtered = _filtered_table.size() != _current_table.size()
	
	# 刷新视图
	_refresh_table_view()
	
	# 更新状态
	var count_after = _filtered_table.size()
	if _is_filtered:
		_update_status("显示 %d / %d 条记录" % [count_after, count_before])
	else:
		_update_status("共 %d 条记录" % count_before)

## 应用排序
func _apply_sort() -> void:
	if _sort_column.is_empty():
		return
	
	# 简单排序实现
	var sorted_keys = _filtered_table.keys()
	sorted_keys.sort()
	
	if not _sort_ascending:
		sorted_keys.reverse()
	
	var temp_table = {}
	for key in sorted_keys:
		temp_table[key] = _filtered_table[key]
	
	_filtered_table = temp_table

func _on_validate_pressed() -> void:
	_validate_current_table()

## 校验当前数据表
func _validate_current_table() -> void:
	if _current_table.is_empty():
		_update_status("没有数据可校验")
		return
	
	var issues: Array[String] = []
	
	# 1. 主键校验
	if not _primary_key.is_empty():
		var pk_values: Dictionary = {}
		for row_id in _current_table.keys():
			var pk_value = _current_table[row_id].get(_primary_key, "")
			if pk_value.is_empty():
				issues.append("行 %s: 主键为空" % row_id)
			elif pk_values.has(pk_value):
				issues.append("行 %s: 主键重复 '%s'" % [row_id, pk_value])
			else:
				pk_values[pk_value] = row_id
		
		if pk_values.size() == _current_table.size():
			issues.append("✅ 主键唯一性校验通过 (%d 行)" % pk_values.size())
	
	# 2. 外键校验
	for fk in _foreign_keys:
		var fk_field = fk.get("field", "")
		var target_table = fk.get("target_table", "")
		var target_field = fk.get("target_field", "")
		
		if target_table.is_empty() or not _loaded_tables.has(target_table):
			issues.append("⚠️ 外键目标表不存在: " + target_table)
			continue
		
		# 获取目标表的字段值集合
		var target_values = {}
		var target_data = _loaded_tables[target_table].get("data", {})
		for row_id in target_data.keys():
			target_values[target_data[row_id].get(target_field, "")] = true
		
		# 检查当前表的外键引用
		var fk_issues = 0
		for row_id in _current_table.keys():
			var fk_value = _current_table[row_id].get(fk_field, "")
			if not fk_value.is_empty() and not target_values.has(fk_value):
				fk_issues += 1
				if fk_issues <= 3:  # 只显示前3个错误
					issues.append("行 %s: 外键 '%s' 值 '%s' 在目标表不存在" % [row_id, fk_field, fk_value])
		
		if fk_issues == 0:
			issues.append("✅ 外键 %s → %s.%s 校验通过" % [fk_field, target_table, target_field])
		else:
			issues.append("⚠️ 外键 %s: %d 个无效引用" % [fk_field, fk_issues])
	
	# 显示校验结果
	if issues.is_empty():
		_update_status("✅ 校验通过")
	else:
		var error_count = 0
		var warning_count = 0
		for issue in issues:
			if issue.begins_with("⚠️"):
				warning_count += 1
			elif issue.begins_with("✅"):
				pass  # 成功消息
			else:
				error_count += 1
		
		var status = "校验完成"
		if error_count > 0:
			status += " | 🔴 %d 错误" % error_count
		if warning_count > 0:
			status += " | 🟡 %d 警告" % warning_count
		
		_update_status(status)
		print("[GDDataForge] 校验结果:")
		for issue in issues:
			print("  ", issue)

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
	
	# 加载主键/外键定义
	if _loaded_tables[table_name].has("primary_key"):
		_primary_key = _loaded_tables[table_name].get("primary_key", "ID")
	if _loaded_tables[table_name].has("foreign_keys"):
		_foreign_keys = _loaded_tables[table_name].get("foreign_keys", [])
	
	_refresh_table_view()
	_refresh_primary_key_options()
	_refresh_foreign_key_tree()
	_refresh_validation_rules_ui()
	_update_status("已加载: " + table_name + " | 主键: " + _primary_key)
	table_selected.emit(table_name)

## 刷新字段校验规则 UI
func _refresh_validation_rules_ui() -> void:
	# 查找校验规则容器并动态生成编辑控件
	var val_container = _find_node_by_name(_editor_panel, "ValidationRules")
	if not val_container:
		return
	
	# 清空现有子节点（保留自动创建的）
	for child in val_container.get_children():
		child.queue_free()
	
	# 为每个字段创建校验规则编辑控件
	for i in range(_current_table_columns.size()):
		var col_name = _current_table_columns[i]
		var col_type = _current_table_types[i] if i < _current_table_types.size() else "string"
		
		# 创建水平容器
		var hbox = HBoxContainer.new()
		val_container.add_child(hbox)
		
		# 字段名标签
		var label = Label.new()
		label.text = col_name + ":"
		label.custom_minimum_size.x = 80
		hbox.add_child(label)
		
		# 校验选项（多选复选框）
		var check_container = HBoxContainer.new()
		hbox.add_child(check_container)
		
		# REQUIRED 复选框
		var chk_req = CheckBox.new()
		chk_req.text = "必填"
		chk_req.button_pressed.connect(_on_validation_rule_toggled.bind(col_name, "REQUIRED", chk_req))
		if _field_validation_rules.has(col_name) and "REQUIRED" in _field_validation_rules[col_name]:
			chk_req.button_pressed = true
		check_container.add_child(chk_req)
		
		# UNIQUE 复选框
		var chk_uni = CheckBox.new()
		chk_uni.text = "唯一"
		chk_uni.button_pressed.connect(_on_validation_rule_toggled.bind(col_name, "UNIQUE", chk_uni))
		if _field_validation_rules.has(col_name) and "UNIQUE" in _field_validation_rules[col_name]:
			chk_uni.button_pressed = true
		check_container.add_child(chk_uni)
		
		# RANGE 输入（仅数字类型显示）
		if col_type == "int" or col_type == "float":
			var range_label = Label.new()
			range_label.text = "范围:"
			check_container.add_child(range_label)
			
			var range_edit = LineEdit.new()
			range_edit.custom_minimum_size.x = 80
			range_edit.placeholder_text = "1-100"
			range_edit.text_entered.connect(_on_range_rule_changed.bind(col_name, range_edit))
			check_container.add_child(range_edit)
			
			# 设置当前值
			if _field_validation_rules.has(col_name):
				for rule in _field_validation_rules[col_name]:
					if rule.begins_with("RANGE:"):
						range_edit.text = rule.substr(6)

## 查找子节点辅助函数
func _find_node_by_name(parent: Node, name: String) -> Node:
	if parent.name == name:
		return parent
	for child in parent.get_children():
		var found = _find_node_by_name(child, name)
		if found:
			return found
	return null

## 校验规则复选框变更
func _on_validation_rule_toggled(col_name: String, rule: String, checkbox: CheckBox) -> void:
	if not _field_validation_rules.has(col_name):
		_field_validation_rules[col_name] = []
	
	if checkbox.button_pressed:
		if rule not in _field_validation_rules[col_name]:
			_field_validation_rules[col_name].append(rule)
	else:
		_field_validation_rules[col_name].erase(rule)
	
	table_modified.emit(_current_table_name)
	_update_status("字段 %s 规则已更新" % col_name)

## 范围规则变更
func _on_range_rule_changed(col_name: String, line_edit: LineEdit) -> void:
	var range_value = line_edit.text.strip_edges()
	if range_value.is_empty():
		if _field_validation_rules.has(col_name):
			_field_validation_rules[col_name].erase("RANGE:" + range_value)
	else:
		if not _field_validation_rules.has(col_name):
			_field_validation_rules[col_name] = []
		# 移除旧的 RANGE 规则
		var old_rules = _field_validation_rules[col_name].duplicate()
		for r in old_rules:
			if r.begins_with("RANGE:"):
				_field_validation_rules[col_name].erase(r)
		# 添加新的 RANGE 规则
		_field_validation_rules[col_name].append("RANGE:" + range_value)
	
	table_modified.emit(_current_table_name)

## 刷新主键下拉选项
func _refresh_primary_key_options() -> void:
	if not _primary_key_option:
		return
	
	_primary_key_option.clear()
	
	# 添加"无主键"选项
	_primary_key_option.add_item("(无)", 0)
	
	# 添加所有列作为主键选项
	for i in range(_current_table_columns.size()):
		_primary_key_option.add_item(_current_table_columns[i], i + 1)
	
	# 设置当前主键
	var current_idx = _current_table_columns.find(_primary_key)
	if current_idx >= 0:
		_primary_key_option.select(current_idx + 1)
	else:
		_primary_key_option.select(0)

## 刷新外键树
func _refresh_foreign_key_tree() -> void:
	if not _foreign_key_tree:
		return
	
	_foreign_key_tree.clear()
	var root = _foreign_key_tree.create_item()
	root.text = "外键引用"
	root.collapsed = true
	
	for fk in _foreign_keys:
		var item = _foreign_key_tree.create_item(root)
		item.text = "%s → %s.%s" % [fk.get("field", "?"), fk.get("target_table", "?"), fk.get("target_field", "?")]
		item.set_metadata(0, fk)

## 刷新表格视图
func _refresh_table_view() -> void:
	_table_view.clear()
	
	# 使用过滤后的数据（如果没有过滤则使用原始数据）
	var table_to_show = _filtered_table if _is_filtered else _current_table
	
	if table_to_show.is_empty():
		return
	
	# 设置列
	var columns = ["ID"] + _current_table_columns
	_table_view.columns = columns.size()
	
	for i in range(columns.size()):
		_table_view.set_column_title(i, columns[i])
		_table_view.set_column_expand(i, true if i > 0 else false)
		_table_view.set_column_min_width(i, 100)
	
	# 添加数据行
	for row_id in table_to_show.keys():
		var row_data = table_to_show[row_id]
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
		"types": types,
		"primary_key": _primary_key,
		"foreign_keys": _foreign_keys
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
	
	# 读取校验规则（可选，第4行）
	var validation_rules_line = PackedStringArray()
	if not file.eof_reached():
		validation_rules_line = file.get_csv_line(",")
	
	# 解析校验规则
	_field_validation_rules = {}
	if not validation_rules_line.is_empty():
		for i in range(data_names.size()):
			if i >= validation_rules_line.size():
				break
			var rule_str = validation_rules_line[i]
			if rule_str.is_empty():
				continue
			var col_name = data_names[i]
			var rules = rule_str.split("|")
			_field_validation_rules[col_name] = []
			for rule in rules:
				if not rule.is_empty():
					_field_validation_rules[col_name].append(rule)
	
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
		# 检查是否带有 _meta
		if json_data.has("_meta"):
			var meta = json_data["_meta"]
			if meta.has("validation_rules"):
				_field_validation_rules = meta["validation_rules"]
			if meta.has("primary_key"):
				_primary_key = meta["primary_key"]
			if meta.has("foreign_keys"):
				_foreign_keys = meta["foreign_keys"]
			if meta.has("_data"):
				result = meta["_data"]
			else:
				result = json_data.duplicate()
				result.erase("_meta")
		else:
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
	types.append("string")  # ID 类型
	types.append_array(_current_table_types)
	file.store_csv_line(types, ",")
	
	# 写入校验规则（第4行）
	var validation_row = PackedStringArray()
	validation_row.append("")  # ID 列无校验
	for col in _current_table_columns:
		var rules_str = ""
		if _field_validation_rules.has(col):
			rules_str = "|".join(_field_validation_rules[col])
		validation_row.append(rules_str)
	file.store_csv_line(validation_row, ",")
	
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
	
	# 构建带校验规则元数据的 JSON
	var output = {
		"_meta": {
			"primary_key": _primary_key,
			"columns": _current_table_columns,
			"types": _current_table_types,
			"validation_rules": _field_validation_rules,
			"foreign_keys": _foreign_keys
		},
		"_data": _current_table
	}
	
	var json_string = JSON.stringify(output, "\t")
	file.store_string(json_string)
	file.close()

func _save_current_table() -> void:
	# 自动保存当前编辑的表
	if not _current_table.is_empty():
		var path = _get_current_table_path()
		if not path.is_empty():
			_save_table_to_file(path)