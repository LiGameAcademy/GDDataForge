extends Resource

## 物品ID
@export var id: String
## 物品名称
@export var name: String
## 物品类型
@export var type: String
## 伤害值
@export var damage: int
## 防御值
@export var defense: int
## 位置
@export var position: Vector2
## 图标
@export var icon: Resource
## 属性列表
@export var properties: Dictionary
## 标签列表
@export var tags: Array

## 从数据初始化
func _init_from_data(data: Dictionary) -> void:
	# 可以在这里添加额外的初始化逻辑
	pass

## 是否是武器
func is_weapon() -> bool:
	return type == "weapon"

## 是否是防具
func is_shield() -> bool:
	return type == "shield"

## 获取主属性值
func get_main_property() -> float:
	return properties.values()[0] if not properties.is_empty() else 0.0

## 检查是否有指定标签
func has_tag(tag: String) -> bool:
	return tags.has(tag)

func _to_string() -> String:
	return "Item: %s" % name + " (%s)" % type + " (%s)" % id
