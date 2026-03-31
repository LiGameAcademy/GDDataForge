extends PanelContainer
class_name DataTableLeftPanel

@onready var left_title: Label = %LeftTitle
@onready var table_list: ItemList = %TableList

func set_title(text: String) -> void:
	left_title.text = text

func clear_tables() -> void:
	table_list.clear()

func set_tables(table_names: Array[String]) -> void:
	table_list.clear()
	for table_name in table_names:
		table_list.add_item(table_name)
