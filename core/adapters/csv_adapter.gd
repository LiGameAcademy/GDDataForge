extends GDFDataAdapter
class_name GDFCsvAdapter

const TableDocumentScript = preload("res://addons/GDDataForge/core/table_document.gd")

func can_handle(path: String) -> bool:
	return path.get_extension().to_lower() == "csv"

func load(path: String) -> GDFTableDocument:
	var doc: GDFTableDocument = TableDocumentScript.new()
	doc.source_path = path
	doc.source_format = "csv"
	doc.table_id = path.get_file().get_basename()
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return doc
	var data_names: PackedStringArray = file.get_csv_line(",")
	file.get_csv_line(",")
	var data_types: PackedStringArray = file.get_csv_line(",")
	var validation_rules_line := PackedStringArray()
	if not file.eof_reached():
		validation_rules_line = file.get_csv_line(",")
	var validation_rules := {}
	if not validation_rules_line.is_empty():
		for i in range(data_names.size()):
			if i >= validation_rules_line.size():
				break
			var rule_str := validation_rules_line[i]
			if rule_str.is_empty():
				continue
			var col_name := data_names[i]
			var rules := []
			for rule in rule_str.split("|"):
				if not rule.is_empty():
					rules.append(rule)
			validation_rules[col_name] = rules
	var rows := {}
	var order: Array[String] = []
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line(",")
		if row.is_empty():
			continue
		var row_data := {}
		for i in range(data_names.size()):
			var data_name := data_names[i]
			var data_type := data_types[i] if i < data_types.size() else "string"
			if data_name.is_empty():
				continue
			var value := row[i] if i < row.size() else ""
			row_data[data_name] = _parse_value(value, data_type)
		if row_data.has("ID") and not String(row_data["ID"]).is_empty():
			var row_id := String(row_data["ID"])
			rows[row_id] = row_data
			order.append(row_id)
	file.close()
	doc.meta["columns"] = Array(data_names)
	doc.meta["types"] = Array(data_types)
	doc.meta["validation_rules"] = validation_rules
	doc.rows = rows
	doc.row_order = order
	return doc

func save(path: String, doc: GDFTableDocument) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return false
	var columns: Array[String] = doc.meta.get("columns", [])
	var types_arr: Array[String] = doc.meta.get("types", [])
	var validation_rules: Dictionary = doc.meta.get("validation_rules", {})
	var header := PackedStringArray()
	header.append("ID")
	header.append_array(columns)
	file.store_csv_line(header, ",")
	var comments := PackedStringArray()
	comments.append("")
	for _col in columns:
		comments.append("")
	file.store_csv_line(comments, ",")
	var types := PackedStringArray()
	types.append("string")
	types.append_array(types_arr)
	file.store_csv_line(types, ",")
	var validation_row := PackedStringArray()
	validation_row.append("")
	for col in columns:
		var rules_str := ""
		if validation_rules.has(col):
			rules_str = "|".join(validation_rules[col])
		validation_row.append(rules_str)
	file.store_csv_line(validation_row, ",")
	var row_ids: Array[String] = []
	if not doc.row_order.is_empty():
		for rid in doc.row_order:
			if doc.rows.has(rid):
				row_ids.append(rid)
	else:
		for rid in doc.rows.keys():
			row_ids.append(String(rid))
	for row_id in row_ids:
		var row_data = doc.rows[row_id]
		var row := PackedStringArray()
		row.append(str(row_id))
		for col in columns:
			row.append(str(row_data.get(col, "")))
		file.store_csv_line(row, ",")
	file.close()
	return true

func _parse_value(value: String, value_type: String) -> Variant:
	match value_type:
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
	return value
