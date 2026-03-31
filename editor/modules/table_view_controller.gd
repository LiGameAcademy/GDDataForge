extends RefCounted
class_name TableViewController

## 数据表视图控制器

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
	var is_filtered := count_after != current_table.size()
	
	return {
		"filtered_table": filtered_table,
		"is_filtered": is_filtered,
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
	on_cell_edited: Callable = Callable()
) -> void:
	for child in table_view.get_children():
		child.queue_free()
	
	var columns = ["ID"] + current_table_columns
	table_view.columns = max(1, columns.size())
	
	for header in columns:
		var header_label := Label.new()
		header_label.text = String(header)
		table_view.add_child(header_label)
	
	for row_id in table_to_show.keys():
		var row_data = table_to_show[row_id]
		
		var id_label := Label.new()
		id_label.text = String(row_id)
		table_view.add_child(id_label)
		
		for col_name in current_table_columns:
			var edit := LineEdit.new()
			edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			edit.text = str(row_data.get(col_name, ""))
			if on_cell_edited.is_valid():
				edit.text_submitted.connect(func(new_text: String):
					on_cell_edited.call(String(row_id), String(col_name), new_text)
				)
			table_view.add_child(edit)
