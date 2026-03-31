@tool
extends EditorPlugin

func _enter_tree() -> void:
	push_warning("`editor/editor.cfg` 已弃用。请仅启用 `addons/GDDataForge/plugin.cfg`。")
