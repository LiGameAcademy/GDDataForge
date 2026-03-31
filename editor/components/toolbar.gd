@tool
extends MarginContainer
class_name DataTableToolbar

@onready var btn_new: Button = %BtnNew
@onready var btn_open: Button = %BtnOpen
@onready var btn_save: Button = %BtnSave
@onready var btn_add_row: Button = %BtnAddRow
@onready var btn_del_row: Button = %BtnDelRow
@onready var btn_undo: Button = %BtnUndo
@onready var btn_redo: Button = %BtnRedo
@onready var btn_add_col: Button = %BtnAddCol
@onready var btn_del_col: Button = %BtnDelCol
@onready var btn_validate: Button = %BtnValidate
@onready var search_input: LineEdit = %SearchInput
@onready var search_column_option: OptionButton = %SearchColumnOption
@onready var filter_column_option: OptionButton = %FilterColumnOption
@onready var filter_value_input: LineEdit = %FilterValueInput
@onready var btn_clear_filter: Button = %BtnClearFilter
@onready var btn_import: Button = %BtnImport
@onready var btn_export: Button = %BtnExport
@onready var btn_batch_import: Button = %BtnBatchImport
@onready var btn_batch_export: Button = %BtnBatchExport
@onready var chk_hot_load: CheckBox = %ChkHotLoad

func initialize_options() -> void:
	search_column_option.clear()
	search_column_option.add_item("全部列", 0)
	filter_column_option.clear()
	filter_column_option.add_item("不过滤", 0)

func refresh_column_options(columns: Array[String]) -> void:
	initialize_options()
	for i in range(columns.size()):
		var col_name := columns[i]
		search_column_option.add_item(col_name, i + 1)
		filter_column_option.add_item(col_name, i + 1)

func clear_search_filter_inputs() -> void:
	search_input.text = ""
	filter_value_input.text = ""

func set_undo_redo_state(can_undo: bool, undo_count: int, can_redo: bool, redo_count: int) -> void:
	btn_undo.disabled = not can_undo
	btn_redo.disabled = not can_redo
	btn_undo.text = "↩ 撤销 (%d)" % undo_count if can_undo else "↩ 撤销"
	btn_redo.text = "↪ 重做 (%d)" % redo_count if can_redo else "↪ 重做"
