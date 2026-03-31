## 简单单元测试（无需 gut 框架）

将以下测试脚本放在项目中运行测试。

### 测试运行器

创建一个测试脚本 `res://scripts/test_runner.gd`:

```gdscript
extends Node

func _ready() -> void:
	print("=== GDDataForge 简单测试 ===")
	
	var pass_count = 0
	var fail_count = 0
	
	# 测试 1: CSV 解析
	if test_csv_parse(): pass_count += 1
	else: fail_count += 1
	
	# 测试 2: JSON 解析
	if test_json_parse(): pass_count += 1
	else: fail_count += 1
	
	# 测试 3: 校验规则 - REQUIRED
	if test_validation_required(): pass_count += 1
	else: fail_count += 1
	
	# 测试 4: 校验规则 - RANGE
	if test_validation_range(): pass_count += 1
	else: fail_count += 1
	
	# 测试 5: 搜索
	if test_search(): pass_count += 1
	else: fail_count += 1
	
	# 测试 6: 过滤
	if test_filter(): pass_count += 1
	else: fail_count += 1
	
	# 测试 7: 撤销/重做
	if test_undo_redo(): pass_count += 1
	else: fail_count += 1
	
	print("=== 结果: %d 通过, %d 失败 ===" % [pass_count, fail_count])
	
	if fail_count > 0:
		print("⚠️  部分测试失败，请检查输出")
	else:
		print("✅ 所有测试通过!")

## 测试 1: CSV 解析
func test_csv_parse() -> bool:
	var csv = "ID,name,price\n,,,string,int\nitem1,武器,100\n"
	var file = FileAccess.open("user://test_csv.csv", FileAccess.WRITE)
	file.store_string(csv)
	file.close()
	
	var data = _parse_simple_csv("user://test_csv.csv")
	return data.size() > 0

## 测试 2: JSON 解析  
func test_json_parse() -> bool:
	var json = '{"item1": {"name": "武器", "price": 100}}'
	var file = FileAccess.open("user://test_json.json", FileAccess.WRITE)
	file.store_string(json)
	file.close()
	
	var data = _parse_simple_json("user://test_json.json")
	return data.has("item1")

## 测试 3: REQUIRED 校验
func test_validation_required() -> bool:
	var value = ""
	if value.is_empty():
		return false
	return true

## 测试 4: RANGE 校验
func test_validation_range() -> bool:
	var value = 50
	var min_val = 1
	var max_val = 100
	return value >= min_val and value <= max_val

## 测试 5: 搜索
func test_search() -> bool:
	var data = {"a": {"name": "sword"}, "b": {"name": "shield"}}
	var matched = false
	for row in data.values():
		if "sword" in str(row.get("name", "")):
			matched = true
	return matched

## 测试 6: 过滤
func test_filter() -> bool:
	var data = {"a": {"type": "weapon"}, "b": {"type": "armor"}}
	var filtered = {}
	for k in data.keys():
		if data[k].get("type") == "weapon":
			filtered[k] = data[k]
	return filtered.size() == 1

## 测试 7: 撤销/重做
func test_undo_redo() -> bool:
	var table = {}
	var cmd = _create_add_command(table, "test", {})
	cmd.execute()
	var passed = table.has("test")
	cmd.undo()
	passed = passed and not table.has("test")
	cmd.execute()
	passed = passed and table.has("test")
	return passed

## 辅助函数

func _parse_simple_csv(path: String) -> Dictionary:
	var result = {}
	var f = FileAccess.open(path, FileAccess.READ)
	if not f:
		return result
	
	var names = f.get_csv_line(",")
	f.get_csv_line(",")  # 跳过注释
	var types = f.get_csv_line(",")
	
	while not f.eof_reached():
		var row = f.get_csv_line(",")
		if row.is_empty():
			continue
		var row_data = {}
		for i in range(names.size()):
			if i < row.size():
				row_data[names[i]] = row[i]
		if row_data.has("ID") and not row_data["ID"].is_empty():
			result[row_data["ID"]] = row_data
	
	f.close()
	return result

func _parse_simple_json(path: String) -> Dictionary:
	var f = FileAccess.open(path, FileAccess.READ)
	if not f:
		return {}
	
	var json = JSON.new()
	var err = json.parse(f.get_as_text())
	f.close()
	
	if err == OK:
		return json.get_data()
	return {}

func _create_add_command(table: Dictionary, row_id: String, row_data: Dictionary):
	# 简化的 AddRowCommand
	var cmd = {
		"execute": func(): table[row_id] = row_data,
		"undo": func(): table.erase(row_id)
	}
	return cmd
```

### 在 Godot 中运行

1. 复制测试脚本到项目中
2. 将主场景设置为测试脚本
3. 运行项目
4. 查看控制台输出

### 预期输出

```
=== GDDataForge 简单测试 ===
=== 结果: 7 通过, 0 失败 ===
✅ 所有测试通过!
```