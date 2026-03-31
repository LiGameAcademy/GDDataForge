class_name TableValidationController
extends RefCounted

func refresh_validation_rules_ui(
	val_container: Node,
	current_table_columns: Array[String],
	current_table_types: Array[String],
	field_validation_rules: Dictionary,
	on_rule_toggled: Callable,
	on_range_rule_changed: Callable
) -> void:
	for child in val_container.get_children():
		child.queue_free()
	
	for i in range(current_table_columns.size()):
		var col_name = current_table_columns[i]
		var col_type = current_table_types[i] if i < current_table_types.size() else "string"
		
		var hbox := HBoxContainer.new()
		val_container.add_child(hbox)
		
		var label := Label.new()
		label.text = col_name + ":"
		label.custom_minimum_size.x = 80
		hbox.add_child(label)
		
		var check_container := HBoxContainer.new()
		hbox.add_child(check_container)
		
		var chk_req := CheckBox.new()
		chk_req.text = "必填"
		chk_req.button_pressed = field_validation_rules.has(col_name) and "REQUIRED" in field_validation_rules[col_name]
		chk_req.toggled.connect(func(_pressed: bool): on_rule_toggled.call(col_name, "REQUIRED", chk_req))
		check_container.add_child(chk_req)
		
		var chk_uni := CheckBox.new()
		chk_uni.text = "唯一"
		chk_uni.button_pressed = field_validation_rules.has(col_name) and "UNIQUE" in field_validation_rules[col_name]
		chk_uni.toggled.connect(func(_pressed: bool): on_rule_toggled.call(col_name, "UNIQUE", chk_uni))
		check_container.add_child(chk_uni)
		
		if col_type == "int" or col_type == "float":
			var range_label := Label.new()
			range_label.text = "范围:"
			check_container.add_child(range_label)
			
			var range_edit := LineEdit.new()
			range_edit.custom_minimum_size.x = 80
			range_edit.placeholder_text = "1-100"
			range_edit.text_submitted.connect(on_range_rule_changed.bind(col_name, range_edit))
			check_container.add_child(range_edit)
			
			if field_validation_rules.has(col_name):
				for rule in field_validation_rules[col_name]:
					if String(rule).begins_with("RANGE:"):
						range_edit.text = String(rule).substr(6)

func validate_current_table(
	current_table: Dictionary,
	primary_key: String,
	foreign_keys: Array[Dictionary],
	loaded_tables: Dictionary
) -> Dictionary:
	if current_table.is_empty():
		return {"empty": true, "issues": []}
	
	var issues: Array[String] = []
	
	if not primary_key.is_empty():
		var pk_values := {}
		for row_id in current_table.keys():
			var pk_value = current_table[row_id].get(primary_key, "")
			if String(pk_value).is_empty():
				issues.append("行 %s: 主键为空" % row_id)
			elif pk_values.has(pk_value):
				issues.append("行 %s: 主键重复 '%s'" % [row_id, pk_value])
			else:
				pk_values[pk_value] = row_id
		if pk_values.size() == current_table.size():
			issues.append("✅ 主键唯一性校验通过 (%d 行)" % pk_values.size())
	
	for fk in foreign_keys:
		var fk_field = fk.get("field", "")
		var target_table = fk.get("target_table", "")
		var target_field = fk.get("target_field", "")
		
		if String(target_table).is_empty() or not loaded_tables.has(target_table):
			issues.append("⚠️ 外键目标表不存在: " + str(target_table))
			continue
		
		var target_values := {}
		var target_data: Dictionary = loaded_tables[target_table].get("data", {})
		for row_id in target_data.keys():
			target_values[target_data[row_id].get(target_field, "")] = true
		
		var fk_issues := 0
		for row_id in current_table.keys():
			var fk_value = current_table[row_id].get(fk_field, "")
			if not String(fk_value).is_empty() and not target_values.has(fk_value):
				fk_issues += 1
				if fk_issues <= 3:
					issues.append("行 %s: 外键 '%s' 值 '%s' 在目标表不存在" % [row_id, fk_field, fk_value])
		
		if fk_issues == 0:
			issues.append("✅ 外键 %s → %s.%s 校验通过" % [fk_field, target_table, target_field])
		else:
			issues.append("⚠️ 外键 %s: %d 个无效引用" % [fk_field, fk_issues])
	
	var error_count := 0
	var warning_count := 0
	for issue in issues:
		if issue.begins_with("⚠️"):
			warning_count += 1
		elif issue.begins_with("✅"):
			pass
		else:
			error_count += 1
	
	var status := "✅ 校验通过" if issues.is_empty() else "校验完成"
	if not issues.is_empty():
		if error_count > 0:
			status += " | 🔴 %d 错误" % error_count
		if warning_count > 0:
			status += " | 🟡 %d 警告" % warning_count
	
	return {
		"empty": false,
		"issues": issues,
		"error_count": error_count,
		"warning_count": warning_count,
		"status": status
	}
