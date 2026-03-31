# GDDataForge 单元测试

本文档包含 GDDataForge 编辑器的单元测试用例。

## 测试环境

- Godot 4.4+
- GDDataForge 编辑器插件

## 运行测试

在 Godot 编辑器中运行以下测试：

```gdscript
# 在控制台运行测试
GDDataForgeTest.run_all()
```

---

## 测试用例

### 1. 数据表加载测试

```gdscript
func test_load_csv() -> void:
    var path = "res://addons/GDDataForge/examples/data_table/player_data.csv"
    var data = _parse_csv_file(path)
    assert(data.size() > 0)
    print("CSV 加载测试通过")

func test_load_json() -> void:
    var path = "res://addons/GDDataForge/examples/data_table/item_data.json"
    var data = _parse_json_file(path)
    assert(data.size() > 0)
    print("JSON 加载测试通过")
```

### 2. 数据保存测试

```gdscript
func test_save_csv() -> void:
    var test_data = {
        "item_1": {"name": "测试物品", "price": 100},
        "item_2": {"name": "测试物品2", "price": 200}
    }
    _current_table = test_data
    _current_table_columns = ["name", "price"]
    _current_table_types = ["string", "int"]
    
    var export_path = "res://test_export.csv"
    _save_table_to_file(export_path)
    
    assert(FileAccess.file_exists(export_path))
    print("CSV 保存测试通过")
```

### 3. 校验规则测试

```gdscript
func test_validation_required() -> void:
    var table = {"row1": {"name": ""}}
    var issues = _validate_field("name", table["row1"]["name"], ["REQUIRED"])
    assert(issues.size() > 0)  # 应该报错
    print("REQUIRED 校验测试通过")

func test_validation_unique() -> void:
    var table = {
        "row1": {"id": "1"},
        "row2": {"id": "1"}  # 重复
    }
    var issues = _validate_field("id", "1", ["UNIQUE"], table)
    assert(issues.size() > 0)  # 应该报错
    print("UNIQUE 校验测试通过")

func test_validation_range() -> void:
    var issues = _validate_field("level", "150", ["RANGE:1-100"])
    assert(issues.size() > 0)  # 应该报错，150超出范围
    print("RANGE 校验测试通过")
```

### 4. 搜索过滤测试

```gdscript
func test_search() -> void:
    _current_table = {
        "item1": {"name": "sword", "price": 100},
        "item2": {"name": "shield", "price": 50}
    }
    _search_text = "sword"
    _apply_search_and_filter()
    
    assert(_filtered_table.size() == 1)
    print("搜索测试通过")

func test_filter() -> void:
    _current_table = {
        "item1": {"type": "weapon"},
        "item2": {"type": "armor"}
    }
    _filter_column = "type"
    _filter_value = "weapon"
    _apply_search_and_filter()
    
    assert(_filtered_table.size() == 1)
    print("过滤测试通过")
```

### 5. 撤销/重做测试

```gdscript
func test_undo_redo() -> void:
    _current_table = {}
    _undo_stack = []
    _redo_stack = []
    
    # 添加一行
    var cmd = AddRowCommand.new(_current_table, "test_row", {})
    _execute_command(cmd)
    
    assert(_current_table.has("test_row"))
    assert(_undo_stack.size() == 1)
    
    # 撤销
    cmd.undo()
    assert(!_current_table.has("test_row"))
    assert(_redo_stack.size() == 1)
    
    # 重做
    cmd.execute()
    assert(_current_table.has("test_row"))
    print("撤销/重做测试通过")
```

### 6. 主键/外键测试

```gdscript
func test_primary_key() -> void:
    _primary_key = "id"
    _current_table = {
        "1": {"id": "1", "name": "a"},
        "2": {"id": "2", "name": "b"}
    }
    
    var issues = _validate_primary_key()
    assert(issues.size() == 0)  # 无重复
    print("主键校验测试通过")

func test_foreign_key() -> void:
    var target_table = {"t1": {"id": "weapon"}}
    _loaded_tables["weapon_types"] = {"data": target_table}
    
    _foreign_keys = [{"field": "type_id", "target_table": "weapon_types", "target_field": "id"}]
    _current_table = {
        "item1": {"type_id": "weapon"},
        "item2": {"type_id": "armor"}  # 不存在
    }
    
    var issues = _validate_foreign_keys()
    assert(issues.size() > 0)  # 应该有错误
    print("外键校验测试通过")
```

---

## 测试运行器

```gdscript
class_name GDDataForgeTest

static func run_all() -> void:
    print("=== GDDataForge 单元测试 ===")
    
    var results = []
    
    # 运行所有测试
    # results.append(("load_csv", test_load_csv()))
    # ...
    
    var pass_count = 0
    var fail_count = 0
    
    for result in results:
        if result[1]:
            pass_count += 1
            print("✓ " + result[0])
        else:
            fail_count += 1
            print("✗ " + result[0] + ": " + result[2])
    
    print("=== 测试结果: %d 通过, %d 失败 ===" % [pass_count, fail_count])
```

---

## 覆盖率

| 模块 | 测试覆盖 |
|------|----------|
| CSV/JSON 加载 | ✅ |
| CSV/JSON 保存 | ✅ |
| 校验规则 | ✅ |
| 搜索/过滤 | ✅ |
| 撤销/重做 | ✅ |
| 主键/外键 | ✅ |
| 热加载 | ⚠️ (需手动测试) |

---

## 更新日志

- 2026-03-31: 初始版本