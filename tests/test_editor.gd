extends GutTest

## GDDataForge 编辑器测试套件

var _editor: GDDataForgeEditor

func before_each() -> void:
	# 每个测试前初始化
	pass

func after_each() -> void:
	# 每个测试后清理
	pass

## ===== CSV 加载测试 =====

func test_parse_csv_basic() -> void:
	var csv_content = """ID,name,price
,sword,武器
,shield,盾牌
"""
	var result = _parse_csv_test_data(csv_content)
	assert_eq(result.size(), 2, "应该加载2行数据")

func test_parse_csv_with_types() -> void:
	var csv_content = """ID,name,price
,,string,int
sword,武器,100"""
	var result = _parse_csv_test_data(csv_content)
	assert_true(result.has("sword"))
	assert_eq(result["sword"]["price"], 100)

func test_parse_csv_with_validation() -> void:
	var csv_content = """ID,name,price
,,
string,int
,REQUIRED|UNIQUE,REQUIRED
sword,武器,100"""
	var result = _parse_csv_test_data(csv_content)
	assert_true(result.has("sword"))
	print("CSV 带校验规则解析测试通过")

## 辅助：解析 CSV 测试数据
func _parse_csv_test_data(content: String) -> Dictionary:
	var file = FileAccess.open("res://test.csv", FileAccess.WRITE)
	file.store_string(content)
	file.close()
	
	var result = {}
	var f = FileAccess.open("res://test.csv", FileAccess.READ)
	var data_names = f.get_csv_line(",")
	var comments = f.get_csv_line(",")
	var data_types = f.get_csv_line(",")
	
	while not f.eof_reached():
		var row = f.get_csv_line(",")
		if row.is_empty():
			continue
		var row_data = {}
		for i in range(data_names.size()):
			var name = data_names[i]
			if name.is_empty():
				continue
			var value = row[i] if i < row.size() else ""
			row_data[name] = value
		if row_data.has("ID") and not row_data["ID"].is_empty():
			result[row_data["ID"]] = row_data
	
	f.close()
	return result

## ===== JSON 测试 =====

func test_parse_json_basic() -> void:
	var json_content = '{"sword": {"name": "武器", "price": 100}}'
	var result = _parse_json_test_data(json_content)
	assert_true(result.has("sword"))
	assert_eq(result["sword"]["name"], "武器")

func test_parse_json_with_meta() -> void:
	var json_content = """{
	"_meta": {
		"primary_key": "ID",
		"columns": ["name", "price"],
		"types": ["string", "int"]
	},
	"_data": {
		"sword": {"name": "武器", "price": 100}
	}
}"""
	var result = _parse_json_test_data(json_content)
	assert_true(result.has("sword"))
	print("JSON 带元数据解析测试通过")

func _parse_json_test_data(content: String) -> Dictionary:
	var file = FileAccess.open("res://test.json", FileAccess.WRITE)
	file.store_string(content)
	file.close()
	
	var result = {}
	var f = FileAccess.open("res://test.json", FileAccess.READ)
	var json = JSON.new()
	var err = json.parse(f.get_as_text())
	f.close()
	
	if err == OK:
		var data = json.get_data()
		if data.has("_data"):
			result = data["_data"]
		else:
			result = data
	
	return result

## ===== 校验规则测试 =====

func test_validation_required_pass() -> void:
	var value = "test"
	var issues = _validate_value_test(value, "REQUIRED")
	assert_eq(issues.size(), 0, "必填字段有值时不应报错")

func test_validation_required_fail() -> void:
	var value = ""
	var issues = _validate_value_test(value, "REQUIRED")
	assert_gt(issues.size(), 0, "必填字段为空时应报错")

func test_validation_unique_pass() -> void:
	var value = "unique_value"
	var table = {"row1": {"id": "other"}}
	var issues = _validate_value_test(value, "UNIQUE", table)
	assert_eq(issues.size(), 0, "值唯一时不应报错")

func test_validation_unique_fail() -> void:
	var value = "duplicate"
	var table = {"row1": {"id": "duplicate"}}
	var issues = _validate_value_test(value, "UNIQUE", table)
	assert_gt(issues.size(), 0, "值重复时应报错")

func test_validation_range_pass() -> void:
	var value = "50"
	var issues = _validate_value_test(value, "RANGE:1-100")
	assert_eq(issues.size(), 0, "值在范围内不应报错")

func test_validation_range_fail() -> void:
	var value = "150"
	var issues = _validate_value_test(value, "RANGE:1-100")
	assert_gt(issues.size(), 0, "值超出范围时应报错")

func _validate_value_test(value: Variant, rules: Array[String], table: Dictionary = {}) -> Array[String]:
	var issues: Array[String] = []
	
	for rule in rules:
		if rule == "REQUIRED":
			if str(value).is_empty():
				issues.append("字段不能为空")
		
		elif rule == "UNIQUE":
			for row_id in table.keys():
				if table[row_id].get("id") == value:
					issues.append("字段值重复")
					break
		
		elif rule.begins_with("RANGE:"):
			var range_str = rule.substr(6)
			var parts = range_str.split("-")
			if parts.size() == 2:
				var min_val = parts[0].to_float()
				var max_val = parts[1].to_float()
				var num_val = float(value)
				if num_val < min_val or num_val > max_val:
					issues.append("值必须在 %s 范围内" % range_str)
	
	return issues

## ===== 搜索过滤测试 =====

func test_search_all_columns() -> void:
	var table = {
		"item1": {"name": "sword", "price": "100"},
		"item2": {"name": "shield", "price": "50"}
	}
	
	var result = _search_test(table, "sword", "")
	assert_eq(result.size(), 1, "应该找到1条匹配")
	assert_true(result.has("item1"))

func test_search_specific_column() -> void:
	var table = {
		"item1": {"name": "sword", "price": "100"},
		"item2": {"name": "shield", "price": "100"}
	}
	
	var result = _search_test(table, "100", "price")
	assert_eq(result.size(), 1, "应该找到1条匹配")

func _search_test(table: Dictionary, search_text: String, search_column: String) -> Dictionary:
	var result = {}
	
	for row_id in table.keys():
		var row = table[row_id]
		var matched = false
		
		if search_column.is_empty():
			for col in row.keys():
				if search_text.to_lower() in str(row[col]).to_lower():
					matched = true
					break
		else:
			if search_text.to_lower() in str(row.get(search_column, "")).to_lower():
				matched = true
		
		if matched:
			result[row_id] = row
	
	return result

func test_filter_exact_match() -> void:
	var table = {
		"item1": {"type": "weapon", "price": "100"},
		"item2": {"type": "armor", "price": "50"}
	}
	
	var result = _filter_test(table, "type", "weapon")
	assert_eq(result.size(), 1, "应该过滤出1条")

func _filter_test(table: Dictionary, column: String, filter_value: String) -> Dictionary:
	var result = {}
	
	for row_id in table.keys():
		var row = table[row_id]
		if str(row.get(column, "")) == filter_value:
			result[row_id] = row
	
	return result

## ===== 撤销/重做测试 =====

func test_undo_add_row() -> void:
	var table = {}
	
	# 添加行
	var cmd = AddRowCommand.new(table, "test_row", {"name": "test"})
	cmd.execute()
	assert_true(table.has("test_row"), "执行后应该有该行")
	
	# 撤销
	cmd.undo()
	assert_false(table.has("test_row"), "撤销后应该删除了该行")

func test_redo_add_row() -> void:
	var table = {}
	
	# 添加行
	var cmd = AddRowCommand.new(table, "test_row", {"name": "test"})
	cmd.execute()
	cmd.undo()
	assert_false(table.has("test_row"))
	
	# 重做
	cmd.execute()
	assert_true(table.has("test_row"), "重做后应该恢复该行")

func test_undo_stack_limit() -> void:
	var table = {}
	var undo_stack: Array = []
	var max_history = 50
	
	# 添加超过限制的行
	for i in range(max_history + 10):
		var cmd = AddRowCommand.new(table, "row_%d" % i, {})
		cmd.execute()
		undo_stack.append(cmd)
	
	# 验证栈大小受限
	assert_le(undo_stack.size(), max_history, "历史记录不应超过限制")

## ===== 主键/外键测试 =====

func test_primary_key_validation_pass() -> void:
	var table = {
		"item1": {"id": "1", "name": "a"},
		"item2": {"id": "2", "name": "b"}
	}
	var pk = "id"
	
	var issues = _validate_pk_test(table, pk)
	assert_eq(issues.size(), 0, "主键唯一不应报错")

func test_primary_key_validation_fail() -> void:
	var table = {
		"item1": {"id": "1", "name": "a"},
		"item2": {"id": "1", "name": "b"}  # 重复
	}
	var pk = "id"
	
	var issues = _validate_pk_test(table, pk)
	assert_gt(issues.size(), 0, "主键重复应该报错")

func _validate_pk_test(table: Dictionary, pk_field: String) -> Array[String]:
	var issues: Array[String] = {}
	var pk_values = {}
	
	for row_id in table.keys():
		var pk_value = table[row_id].get(pk_field, "")
		if pk_value.is_empty():
			issues.append("行 %s: 主键为空" % row_id)
		elif pk_values.has(pk_value):
			issues.append("行 %s: 主键重复 '%s'" % [row_id, pk_value])
		else:
			pk_values[pk_value] = row_id
	
	return issues

func test_foreign_key_validation_pass() -> void:
	var target_table = {"t1": {"id": "weapon"}, "t2": {"id": "armor"}}
	var current_table = {
		"item1": {"type_id": "weapon"},
		"item2": {"type_id": "armor"}
	}
	var fk_field = "type_id"
	var target_field = "id"
	
	var issues = _validate_fk_test(current_table, fk_field, target_table, target_field)
	assert_eq(issues.size(), 0, "外键有效不应报错")

func test_foreign_key_validation_fail() -> void:
	var target_table = {"t1": {"id": "weapon"}}
	var current_table = {
		"item1": {"type_id": "weapon"},
		"item2": {"type_id": "invalid"}  # 无效引用
	}
	var fk_field = "type_id"
	var target_field = "id"
	
	var issues = _validate_fk_test(current_table, fk_field, target_table, target_field)
	assert_gt(issues.size(), 0, "无效外键应该报错")

func _validate_fk_test(table: Dictionary, fk_field: String, target: Dictionary, target_field: String) -> Array[String]:
	var issues: Array[String] = []
	var target_values = {}
	
	for row_id in target.keys():
		target_values[target[row_id].get(target_field, "")] = true
	
	for row_id in table.keys():
		var fk_value = table[row_id].get(fk_field, "")
		if not fk_value.is_empty() and not target_values.has(fk_value):
			issues.append("行 %s: 外键 '%s' 值 '%s' 在目标表不存在" % [row_id, fk_field, fk_value])
	
	return issues

## ===== 运行所有测试 =====

static func run_all_tests() -> void:
	print("=== GDDataForge 测试套件 ===")
	print("运行完整的 gut 测试...")
	# 在 Godot 编辑器中运行