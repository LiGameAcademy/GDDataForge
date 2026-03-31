@tool
extends EditorPlugin

const DATA_TABLE_EDITOR_PANEL_SCENE := preload("res://addons/GDDataForge/editor/data_table_editor_panel.tscn")
var _editor_panel: DataTableEditorPanel

func _enter_tree() -> void:
	add_autoload_singleton("DataManager", "res://addons/GDDataForge/source/data_manager.gd")
	_editor_panel = DATA_TABLE_EDITOR_PANEL_SCENE.instantiate()
	add_control_to_bottom_panel(_editor_panel, "DataForge Editor")
	_editor_panel.initialize(self)

func _exit_tree() -> void:
	remove_autoload_singleton("DataManager")
	if _editor_panel:
		remove_control_from_bottom_panel(_editor_panel)
		_editor_panel.queue_free()
		_editor_panel = null
