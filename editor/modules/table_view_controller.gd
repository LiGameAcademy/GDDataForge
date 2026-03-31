extends RefCounted
class_name TableViewController

func refresh_search_filter_options(search_col_option: OptionButton, filter_col_option: OptionButton, current_table_columns: Array[String]) -> void:
	search_col_option.clear()
	search_col_option.add_item("全部列", 0)
	filter_col_option.clear()
	filter_col_option.add_item("不过滤", 0)
	for i in range(current_table_columns.size()):
		var col_name = current_table_columns[i]
		search_col_option.add_item(col_name, i + 1)
		filter_col_option.add_item(col_name, i + 1)

func apply_search_filter_sort(
	current_table: Dictionary,
	current_table_columns: Array[String],
	search_text: String,
	search_column: String,
	filter_column: String,
	filter_value: String,
	sort_column: String,
	sort_ascending: bool
) -> Dictionary:
	var filtered_table: Dictionary = current_table.duplicate(true)
	var count_before := filtered_table.size()
	if not search_text.is_empty():
		var temp_table := {}
		for row_id in filtered_table.keys():
			var row = filtered_table[row_id]
			var matched := false
			if search_column.is_empty():
				for col in current_table_columns:
					var value = str(row.get(col, ""))
					if search_text.to_lower() in value.to_lower():
						matched = true
						break
			else:
				var value = str(row.get(search_column, ""))
				if search_text.to_lower() in value.to_lower():
					matched = true
			if matched:
				temp_table[row_id] = row
		filtered_table = temp_table
	if not filter_column.is_empty() and not filter_value.is_empty():
		var temp_table := {}
		for row_id in filtered_table.keys():
			var row = filtered_table[row_id]
			var value = str(row.get(filter_column, ""))
			if value == filter_value:
				temp_table[row_id] = row
		filtered_table = temp_table
	filtered_table = sort_table(filtered_table, sort_column, sort_ascending)
	var count_after := filtered_table.size()
	return {
		"filtered_table": filtered_table,
		"is_filtered": count_after != current_table.size(),
		"count_before": count_before,
		"count_after": count_after
	}

func sort_table(filtered_table: Dictionary, sort_column: String, sort_ascending: bool) -> Dictionary:
	if sort_column.is_empty():
		return filtered_table
	var sorted_keys = filtered_table.keys()
	sorted_keys.sort()
	if not sort_ascending:
		sorted_keys.reverse()
	var temp_table := {}
	for key in sorted_keys:
		temp_table[key] = filtered_table[key]
	return temp_table

func refresh_table_view(
	table_view: GridContainer,
	table_to_show: Dictionary,
	current_table_columns: Array[String],
	current_table_types: Array[String],
	on_cell_edited: Callable = Callable(),
	on_row_checked: Callable = Callable(),
	on_toggle_all_rows: Callable = Callable(),
	selected_rows: Dictionary = {},
	all_rows_selected: bool = false,
	on_id_edited: Callable = Callable(),
	on_row_index_clicked: Callable = Callable(),
	on_row_context_requested: Callable = Callable(),
	ordered_row_ids: Array[String] = [],
	on_field_clicked: Callable = Callable(),
	on_field_context_requested: Callable = Callable(),
	on_field_reordered: Callable = Callable(),
	get_field_tooltip: Callable = Callable()
) -> void:
	for child in table_view.get_children():
		child.queue_free()
	var columns = ["序号", "ID"] + current_table_columns
	table_view.columns = max(1, columns.size())
	for i in range(columns.size()):
		var header := String(columns[i])
		if i == 0:
			var header_box := HBoxContainer.new()
			header_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var header_check := CheckBox.new()
			header_check.button_pressed = all_rows_selected
			if on_toggle_all_rows.is_valid():
				header_check.toggled.connect(func(pressed: bool): on_toggle_all_rows.call(pressed))
			header_box.add_child(header_check)
			var header_label := Label.new()
			header_label.text = header
			header_box.add_child(header_label)
			table_view.add_child(header_box)
		elif i == 1:
			var id_header_btn := Button.new()
			id_header_btn.text = header
			id_header_btn.flat = true
			id_header_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			if get_field_tooltip.is_valid():
				id_header_btn.tooltip_text = String(get_field_tooltip.call("ID"))
			if on_field_clicked.is_valid():
				id_header_btn.pressed.connect(func(): on_field_clicked.call("ID"))
			if on_field_context_requested.is_valid():
				id_header_btn.gui_input.connect(func(event: InputEvent):
					if event is InputEventMouseButton:
						var mb := event as InputEventMouseButton
						if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
							on_field_context_requested.call("ID", mb.global_position)
				)
			table_view.add_child(id_header_btn)
		else:
			var field_name := header
			var header_btn := Button.new()
			header_btn.text = field_name
			header_btn.flat = true
			header_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			if get_field_tooltip.is_valid():
				header_btn.tooltip_text = String(get_field_tooltip.call(field_name))
			if on_field_clicked.is_valid():
				header_btn.pressed.connect(func(): on_field_clicked.call(field_name))
			if on_field_context_requested.is_valid():
				header_btn.gui_input.connect(func(event: InputEvent):
					if event is InputEventMouseButton:
						var mb := event as InputEventMouseButton
						if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
							on_field_context_requested.call(field_name, mb.global_position)
				)
			if on_field_reordered.is_valid():
				header_btn.set_drag_forwarding(
					func(_pos: Vector2): return {"field": field_name},
					func(_pos: Vector2, data: Variant): return typeof(data) == TYPE_DICTIONARY and data.has("field"),
					func(_pos: Vector2, data: Variant): on_field_reordered.call(String(data["field"]), field_name)
				)
			table_view.add_child(header_btn)
	var row_ids: Array[String] = []
	if not ordered_row_ids.is_empty():
		for rid in ordered_row_ids:
			if table_to_show.has(rid):
				row_ids.append(rid)
	else:
		for rid in table_to_show.keys():
			row_ids.append(String(rid))
	var row_index := 1
	for row_id in row_ids:
		var row_data = table_to_show[row_id]
		var row_id_str := String(row_id)
		var row_indicator := HBoxContainer.new()
		row_indicator.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_indicator.custom_minimum_size = Vector2(72, 0)
		var row_checkbox := CheckBox.new()
		row_checkbox.button_pressed = selected_rows.has(row_id_str)
		if on_row_checked.is_valid():
			row_checkbox.toggled.connect(func(pressed: bool): on_row_checked.call(row_id_str, pressed))
		row_indicator.add_child(row_checkbox)
		var row_number_btn := Button.new()
		row_number_btn.text = str(row_index)
		row_number_btn.flat = true
		row_number_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		if on_row_index_clicked.is_valid():
			row_number_btn.pressed.connect(func(): on_row_index_clicked.call(row_id_str))
		if on_row_context_requested.is_valid():
			row_number_btn.gui_input.connect(func(event: InputEvent):
				if event is InputEventMouseButton:
					var mb := event as InputEventMouseButton
					if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
						on_row_context_requested.call(row_id_str, mb.global_position)
			)
		row_indicator.add_child(row_number_btn)
		table_view.add_child(row_indicator)
		var id_edit := LineEdit.new()
		id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		id_edit.custom_minimum_size = Vector2(120, 0)
		id_edit.editable = true
		id_edit.select_all_on_focus = true
		id_edit.text = row_id_str
		if on_id_edited.is_valid():
			id_edit.text_submitted.connect(func(new_id: String): on_id_edited.call(row_id_str, new_id))
			id_edit.focus_exited.connect(func(): on_id_edited.call(row_id_str, id_edit.text))
		table_view.add_child(id_edit)
		for i in range(current_table_columns.size()):
			var col_name := current_table_columns[i]
			var col_type := current_table_types[i] if i < current_table_types.size() else "string"
			var value_text := str(row_data.get(col_name, ""))
			if _is_icon_column(col_name, col_type):
				var container := HBoxContainer.new()
				container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				var preview := TextureRect.new()
				preview.custom_minimum_size = Vector2(24, 24)
				preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				preview.texture = _try_load_texture(value_text)
				container.add_child(preview)
				var edit := LineEdit.new()
				edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				edit.text = value_text
				if on_cell_edited.is_valid():
					edit.text_submitted.connect(func(new_text: String):
						preview.texture = _try_load_texture(new_text)
						on_cell_edited.call(row_id_str, String(col_name), new_text)
					)
					edit.focus_exited.connect(func():
						preview.texture = _try_load_texture(edit.text)
						on_cell_edited.call(row_id_str, String(col_name), edit.text)
					)
				container.add_child(edit)
				table_view.add_child(container)
			else:
				var edit := LineEdit.new()
				edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				edit.text = value_text
				if on_cell_edited.is_valid():
					edit.text_submitted.connect(func(new_text: String): on_cell_edited.call(row_id_str, String(col_name), new_text))
					edit.focus_exited.connect(func(): on_cell_edited.call(row_id_str, String(col_name), edit.text))
				table_view.add_child(edit)
		row_index += 1

func _is_icon_column(col_name: String, col_type: String) -> bool:
	return col_name.to_lower() == "icon" or col_type.to_lower() == "texture"

func _try_load_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	var res = load(path)
	return res if res is Texture2D else null
