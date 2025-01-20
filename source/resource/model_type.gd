extends Resource
class_name ModelType

## 模型名称
@export var model_name: StringName
## 模型脚本
@export var model_script: GDScript
## 关联的数据表
@export var table: TableType
## 模型描述
@export_multiline var description: String
## 字段映射规则
@export var field_mappings: Dictionary[String, String] = {}
## 默认值
@export var default_values: Dictionary[String, Variant] = {}

## 构造函数
func _init(
		p_model_name: String = "", 
		p_model_script: GDScript = null, 
		p_table: TableType = null, 
		p_description: String = "", 
		p_field_mappings: Dictionary[String, String] = {}, 
		p_default_values: Dictionary[String, Variant] = {}) -> void:
	model_name = p_model_name
	model_script = p_model_script
	table = p_table
	description = p_description
	field_mappings = p_field_mappings
	default_values = p_default_values

## 验证模型配置
func validate() -> bool:
	if model_name.is_empty():
		push_error("模型名称为空")
		return false
		
	if not is_instance_valid(model_script):
		push_error("无效的模型脚本")
		return false
		
	# 验证每个表格配置
	if not is_instance_valid(table):
		push_error("无效的表格配置")
		return false
			
	return true

## 创建模型实例
func create_instance(data: Dictionary = {}) -> Resource:
	if not validate():
		return null
		
	var instance = model_script.new()
	if not is_instance_valid(instance):
		push_error("模型实例创建失败")
		return null
	
	# 应用默认值
	for field in default_values:
		instance.set(field, default_values[field])
	
	# 应用数据映射
	for field in data:
		var target_field = field_mappings.get(field, field)
		if instance.get_property_list().any(func(p): return p["name"] == target_field):
			instance.set(target_field, data[field])
	
	# 调用初始化方法
	if instance.has_method("_init_from_data"):
		instance.call("_init_from_data", data)
	
	return instance

## 获取模型的所有属性
func get_properties() -> Array[Dictionary]:
	if not is_instance_valid(model_script):
		return []
		
	var instance = model_script.new()
	if not is_instance_valid(instance):
		return []
		
	var properties: Array[Dictionary] = []
	for property in instance.get_property_list():
		if property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			properties.append(property)
	
	instance.free()
	return properties

## 获取字段映射
func get_field_mapping(field: String = "") -> String:
	return field_mappings.get(field, field)

## 获取默认值
func get_default_value(field: String) -> Variant:
	return default_values.get(field, null)
