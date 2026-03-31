extends PanelContainer
class_name DataTableRightPanel

@onready var primary_key_option: OptionButton = %PrimaryKeyOption
@onready var validation_rules: VBoxContainer = %ValidationRules
@onready var foreign_key_tree: Tree = %ForeignKeyTree
@onready var btn_add_foreign_key: Button = %BtnAddForeignKey
@onready var btn_delete_foreign_key: Button = %BtnDeleteForeignKey

func reset_primary_key_options(columns: Array[String], selected_primary_key: String) -> void:
	primary_key_option.clear()
	primary_key_option.add_item("(无)", 0)
	for i in range(columns.size()):
		primary_key_option.add_item(columns[i], i + 1)
	var selected_idx := columns.find(selected_primary_key)
	primary_key_option.select(selected_idx + 1 if selected_idx >= 0 else 0)

func clear_validation_rules() -> void:
	for child in validation_rules.get_children():
		child.queue_free()

func set_foreign_keys(foreign_keys: Array[Dictionary]) -> void:
	foreign_key_tree.clear()
	var root := foreign_key_tree.create_item()
	root.set_text(0, "外键引用")
	root.collapsed = true
	for fk in foreign_keys:
		var item := foreign_key_tree.create_item(root)
		item.set_text(0, "%s → %s.%s" % [fk.get("field", "?"), fk.get("target_table", "?"), fk.get("target_field", "?")])
		item.set_metadata(0, fk)
