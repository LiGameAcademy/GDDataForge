# GDDataForge 校验规则扩展指南

本文档介绍如何扩展 GDDataForge 的校验规则系统。

## 内置校验规则

GDDataForge 提供以下内置校验规则：

| 规则名 | 显示名 | 说明 | 适用类型 | 需要参数 |
|--------|--------|------|----------|----------|
| REQUIRED | 必填 | 字段值不能为空 | string, int, float | ❌ |
| UNIQUE | 唯一 | 字段值不能重复 | string, int, float | ❌ |
| PRIMARY_KEY | 主键 | 作为表的主键 | string, int | ❌ |
| RANGE | 范围 | 数值必须落在指定范围内 | int, float | ✅ (格式: min-max) |
| MIN | 最小值 | 数值必须大于等于指定值 | int, float | ✅ (格式: 数字) |
| MAX | 最大值 | 数值必须小于等于指定值 | int, float | ✅ (格式: 数字) |
| REGEX | 正则 | 必须匹配指定的正则表达式 | string | ✅ (格式: 正则表达式) |
| EMAIL | 邮箱 | 必须是有效的邮箱格式 | string | ❌ |
| URL | 网址 | 必须是有效的URL格式 | string | ❌ |
| CUSTOM | 自定义 | 调用自定义校验函数 | 全部 | ✅ (格式: 函数名) |

## 规则参数格式

### RANGE（范围）
```
RANGE:1-100      # 数值在 1 到 100 之间
RANGE:0.0-1.0   # 浮点数范围
```

### MIN/MAX（极值）
```
MIN:1           # 必须 >= 1
MAX:100          # 必须 <= 100
```

### REGEX（正则）
```
REGEX:^[a-z]+$   # 只允许小写字母
REGEX:\\d{4}     # 必须恰好4位数字
```

### CUSTOM（自定义）
```
CUSTOM:validate_level   # 调用自定义函数 validate_level(value, row_data)
```

---

## 扩展校验规则

### 方式一：代码扩展

在项目中注册自定义校验规则：

```gdscript
extends EditorPlugin

# 可视化数据编辑器脚本中
var _editor: GDDataForgeEditor  # 编辑器实例

func _ready() -> void:
    # 创建自定义校验规则
    var custom_rule = GDDataForgeEditor.ValidationRule.new(
        "LEVEL_CHECK",           # 规则名称
        "等级检查",               # 显示名称
        "检查角色等级是否足够",     # 描述
        true,                   # 需要参数
        ["int"]                 # 适用类型
    )
    
    # 注册到编辑器
    _editor.register_validation_rule(custom_rule)
```

### 方式二：自定义校验函数

在游戏代码中实现校验逻辑：

```gdscript
# res://scripts/custom_validators.gd

## 自定义等级检查
## [param value] 字段值
## [param row_data] 整行数据
## [return] {valid: bool, message: String}
func validate_level(value: Variant, row_data: Dictionary) -> Dictionary:
    var player_level = row_data.get("player_level", 0)
    var required_level = value
    
    if player_level < required_level:
        return {
            "valid": false,
            "message": "需要 %d 级，当前 %d 级" % [required_level, player_level]
        }
    
    return {"valid": true, "message": ""}

## 自定义颜色检查
func validate_color(value: Variant, row_data: Dictionary) -> Dictionary:
    var colors = ["red", "blue", "green", "yellow"]
    if value not in colors:
        return {
            "valid": false,
            "message": "颜色必须是: %s" % ", ".join(colors)
        }
    return {"valid": true, "message": ""}

## 自定义范围检查（带参数）
func validate_in_range(value: Variant, row_data: Dictionary) -> Dictionary:
    # 参数格式: min,max
    var params = value.split(",")
    if params.size() != 2:
        return {"valid": false, "message": "参数格式错误"}
    
    var min_val = params[0].to_float()
    var max_val = params[1].to_float()
    var num_value = float(value)
    
    if num_value < min_val or num_value > max_val:
        return {
            "valid": false,
            "message": "值必须在 %d 到 %d 之间" % [min_val, max_val]
        }
    
    return {"valid": true, "message": ""}
```

---

## 使用自定义规则

### 在 CSV 中使用
```csv
ID,name,price,min_level
,,,
string,int,int,int
REQUIRED|UNIQUE,,REQUIRED|CUSTOM:validate_level
sword,100,1
```

### 在 JSON 中使用
```json
{
  "_meta": {
    "columns": ["name", "price", "min_level"],
    "validation_rules": {
      "name": ["REQUIRED", "UNIQUE"],
      "min_level": ["REQUIRED", "CUSTOM:validate_level"]
    }
  },
  "_data": {
    "sword": {"name": "长剑", "price": 100, "min_level": 1}
  }
}
```

---

## 校验执行流程

```
1. 加载数据表
2. 解析校验规则
3. 遍历每一行数据
4. 对每个字段执行校验规则
5. 收集校验结果
6. 显示错误/警告
```

### 自动校验

编辑器会在以下时机自动校验：
- 保存数据时
- 点击"校验"按钮时
- 切换数据表时

---

## API 参考

### ValidationRule 类

```gdscript
class ValidationRule:
    var name: String                    # 规则名称（英文）
    var display_name: String          # 显示名称（中文）
    var description: String         # 描述
    var param_required: bool      # 是否需要参数
    var apply_types: Array[String] # 适用的字段类型
```

### 编辑器方法

```gdscript
# 注册自定义校验规则
editor.register_validation_rule(rule: ValidationRule) -> void

# 移除校验规则
editor.unregister_validation_rule(rule_name: String) -> void

# 获取所有校验规则
editor.get_validation_rules() -> Array[ValidationRule]

# 获取适用于特定字段类型的规则
editor.get_applicable_rules(field_type: String) -> Array[ValidationRule]
```

---

## 示例：完整扩展示例

```gdscript
# 在游戏的 EditorPlugin 中扩展
extends EditorPlugin

func _ready() -> void:
    # 等待编辑器初始化完成
    await get_tree().process_frame
    
    # 找到编辑器实例
    var editor = _find_editor()
    if editor:
        _register_custom_rules(editor)

func _find_editor() -> GDDataForgeEditor:
    for child in get_children():
        if child.name == "GDDataForgeEditor":
            return child
    return null

func _register_custom_rules(editor: GDDataForgeEditor) -> void:
    # 添加等级校验规则
    editor.register_validation_rule(GDDataForgeEditor.ValidationRule.new(
        "LEVEL_REQUIRED", "需要等级", "必须达到指定等级", true, ["int"]))
    
    # 添加颜色校验规则
    editor.register_validation_rule(GDDataForgeEditor.ValidationRule.new(
        "COLOR_VALID", "有效颜色", "必须是有效颜色之一", true, ["string"]))
    
    # 添加冷却时间校验规则
    editor.register_validation_rule(GDDataForgeEditor.ValidationRule.new(
        "COOLDOWN", "冷却时间", "冷却时间必须为正数", false, ["int", "float"]))
    
    print("[MyGame] 自定义校验规则已注册")
```

---

## 常见问题

### Q: 如何验证自定义规则是否生效？

A: 在编辑器中点击"校验"按钮，查看控制台输出。

### Q: 自定义规则不生效怎么办？

A: 检查以下几点：
1. 规则名称是否与内置规则冲突
2. apply_types 是否包含目标字段类型
3. 参数格式是否正确

### Q: 如何调试自定义校验函数？

A: 在校验函数中添加 print 语句，检查参数值。

---

## 更新日志

- 2026-03-31: 初始版本