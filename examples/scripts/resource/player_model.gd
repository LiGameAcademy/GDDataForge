extends Resource

## 玩家ID
@export var id: String
## 玩家名称
@export var name: String
## 玩家图标
@export var icon : Texture2D
## 等级
@export var level: int
## 位置
@export var position: Vector2
## 技能列表
@export var skills: Array
## 属性值列表
@export var properties: Dictionary[String, float]
## 是否激活
@export var is_active: bool

## 从数据初始化
func _init_from_data(data: Dictionary) -> void:
	# 可以在这里添加额外的初始化逻辑
	print("player init form data, do something here")
	for key in data.properties:
		var value = data.properties[key]
		properties[key] = float(value)

## 获取攻击力
func get_attack() -> float:
	return properties["attack"]

## 获取防御力
func get_defense() -> float:
	return properties["defense"]

## 获取速度
func get_speed() -> float:
	return properties["speed"]
