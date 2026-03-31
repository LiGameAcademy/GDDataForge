@tool
extends PanelContainer
class_name DataTableCenterPanel

@onready var center_title: Label = $VBox/CenterTitle
@onready var table_view: GridContainer = $VBox/TableScroll/TableView

func set_title(text: String) -> void:
	center_title.text = text

func clear_table() -> void:
	for child in table_view.get_children():
		child.queue_free()

func setup_columns(columns: Array[String]) -> void:
	table_view.columns = columns.size()
