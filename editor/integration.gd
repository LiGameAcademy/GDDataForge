extends EditorPlugin

## GDDataForge 主插件
## 整合数据管理和可视化编辑器

## 引用主插件
const DataManager = preload("res://addons/GDDataForge/source/data_manager.gd")

## 编辑器模块
var _editor: GDDataForgeEditor

func _enter_tree() -> void:
	# 初始化主数据管理器
	_add_data_manager()
	
	# 初始化可视化编辑器
	_init_editor()

## 添加数据管理器到场景
func _add_data_manager() -> void:
	var existing = find_child("*", DataManager, true)
	if not existing:
		var dm = DataManager.new()
		dm.name = "GDDataManager"
		add_child(dm)
		print("[GDDataForge] 数据管理器已添加")

## 初始化可视化编辑器
func _init_editor() -> void:
	# 编辑器在独立插件中，通过编辑器菜单访问
	print("[GDDataForge] 可通过 插件 菜单访问数据表编辑器")

## 获取数据管理器实例
func get_data_manager() -> DataManager:
	return find_child("*", DataManager, true) as DataManager

## 快捷方法：加载数据表
func load_table(path: String, callback: Callable = Callable()) -> void:
	var dm = get_data_manager()
	if dm:
		# 创建 TableType
		var tt = TableType.new(path.get_file().get_basename(), [path])
		dm.load_data_table(tt, callback)

## 快捷方法：批量加载
func load_tables(paths: Array[String], callback: Callable = Callable(), progress: Callable = Callable()) -> void:
	var dm = get_data_manager()
	if dm:
		var table_types: Array[TableType] = []
		for path in paths:
			var tt = TableType.new(path.get_file().get_basename(), [path])
			table_types.append(tt)
		dm.load_data_tables(table_types, callback, progress)

## 快捷方法：获取数据
func get_table_data(table_name: String) -> Dictionary:
	var dm = get_data_manager()
	if dm:
		return dm.get_table_data(table_name)
	return {}

## 快捷方法：获取数据模型
func get_data_model(table_name: String, item_id: String) -> Resource:
	var dm = get_data_manager()
	if dm:
		return dm.get_data_model(table_name, item_id)
	return null