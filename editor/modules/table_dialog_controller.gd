extends RefCounted
class_name TableDialogController

## 数据表对话框控制器

## 创建新建数据表对话框
func create_new_table_dialog() -> AcceptDialog:
	var dialog := AcceptDialog.new()
	dialog.title = "新建数据表"
	dialog.ok_button_text = "创建"
	
	var vbox := VBoxContainer.new()
	
	var table_name_input := LineEdit.new()
	table_name_input.name = "TableNameInput"
	table_name_input.placeholder_text = "表名（例如 items）"
	vbox.add_child(table_name_input)
	
	var format_option := OptionButton.new()
	format_option.name = "FormatOption"
	format_option.add_item("CSV")
	format_option.add_item("JSON")
	vbox.add_child(format_option)
	
	var folder_input := LineEdit.new()
	folder_input.name = "FolderInput"
	folder_input.placeholder_text = "数据目录"
	folder_input.text = "res://data"
	vbox.add_child(folder_input)
	
	var create_model_check := CheckBox.new()
	create_model_check.name = "CreateModelCheck"
	create_model_check.text = "同时创建模型脚本"
	create_model_check.button_pressed = true
	vbox.add_child(create_model_check)
	
	var model_folder_input := LineEdit.new()
	model_folder_input.name = "ModelFolderInput"
	model_folder_input.placeholder_text = "模型脚本目录"
	model_folder_input.text = "res://data/models"
	vbox.add_child(model_folder_input)
	
	dialog.add_child(vbox)
	return dialog

func read_new_table_form(dialog: AcceptDialog) -> Dictionary:
	var table_name_input: LineEdit = dialog.get_node("VBoxContainer/TableNameInput")
	var format_option: OptionButton = dialog.get_node("VBoxContainer/FormatOption")
	var folder_input: LineEdit = dialog.get_node("VBoxContainer/FolderInput")
	var create_model_check: CheckBox = dialog.get_node("VBoxContainer/CreateModelCheck")
	var model_folder_input: LineEdit = dialog.get_node("VBoxContainer/ModelFolderInput")
	return {
		"table_name": table_name_input.text.strip_edges(),
		"is_csv": format_option.selected == 0,
		"folder": folder_input.text.strip_edges(),
		"create_model": create_model_check.button_pressed,
		"model_folder": model_folder_input.text.strip_edges()
	}

func create_add_row_dialog(default_row_id: String) -> AcceptDialog:
	var dialog := AcceptDialog.new()
	dialog.title = "添加行"
	dialog.ok_button_text = "添加"
	
	var input := LineEdit.new()
	input.name = "RowIdInput"
	input.placeholder_text = "输入唯一 ID"
	input.text = default_row_id
	
	var vbox := VBoxContainer.new()
	vbox.add_child(input)
	dialog.add_child(vbox)
	return dialog

func read_add_row_form(dialog: AcceptDialog) -> String:
	var input: LineEdit = dialog.get_node("VBoxContainer/RowIdInput")
	return input.text.strip_edges()

func create_add_column_dialog(default_column_name: String) -> AcceptDialog:
	var dialog := AcceptDialog.new()
	dialog.title = "添加列"
	dialog.ok_button_text = "添加"
	
	var vbox := VBoxContainer.new()
	
	var col_name_input := LineEdit.new()
	col_name_input.name = "ColumnNameInput"
	col_name_input.placeholder_text = "列名"
	col_name_input.text = default_column_name
	vbox.add_child(col_name_input)
	
	var col_type_option := OptionButton.new()
	col_type_option.name = "ColumnTypeOption"
	for t in ["string", "int", "float", "bool", "vector2"]:
		col_type_option.add_item(t)
	vbox.add_child(col_type_option)
	
	dialog.add_child(vbox)
	return dialog

func read_add_column_form(dialog: AcceptDialog) -> Dictionary:
	var col_name_input: LineEdit = dialog.get_node("VBoxContainer/ColumnNameInput")
	var col_type_option: OptionButton = dialog.get_node("VBoxContainer/ColumnTypeOption")
	return {
		"col_name": col_name_input.text.strip_edges(),
		"col_type": col_type_option.get_item_text(col_type_option.selected)
	}

func create_add_foreign_key_dialog(current_columns: Array[String], loaded_table_names: Array[String], current_table_name: String) -> AcceptDialog:
	var dialog := AcceptDialog.new()
	dialog.title = "添加外键"
	dialog.ok_button_text = "添加"
	
	var vbox := VBoxContainer.new()
	
	var field_option := OptionButton.new()
	field_option.name = "FieldOption"
	for col in current_columns:
		field_option.add_item(col)
	vbox.add_child(field_option)
	
	var table_option := OptionButton.new()
	table_option.name = "TargetTableOption"
	for table_name in loaded_table_names:
		if table_name != current_table_name:
			table_option.add_item(table_name)
	vbox.add_child(table_option)
	
	var target_field_input := LineEdit.new()
	target_field_input.name = "TargetFieldInput"
	target_field_input.placeholder_text = "目标字段"
	target_field_input.text = "ID"
	vbox.add_child(target_field_input)
	
	dialog.add_child(vbox)
	return dialog

func read_add_foreign_key_form(dialog: AcceptDialog) -> Dictionary:
	var field_option: OptionButton = dialog.get_node("VBoxContainer/FieldOption")
	var table_option: OptionButton = dialog.get_node("VBoxContainer/TargetTableOption")
	var target_field_input: LineEdit = dialog.get_node("VBoxContainer/TargetFieldInput")
	return {
		"table_option_count": table_option.item_count,
		"field": field_option.get_item_text(field_option.selected),
		"target_table": table_option.get_item_text(table_option.selected) if table_option.item_count > 0 else "",
		"target_field": target_field_input.text.strip_edges()
	}
