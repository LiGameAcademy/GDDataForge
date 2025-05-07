extends Control

## 数据模型
const ItemModel = preload("res://addons/GDDataForge/examples/scripts/resource/item_model.gd")
const PlayerModel = preload("res://addons/GDDataForge/examples/scripts/resource/player_model.gd")

## UI 组件
@onready var test_output : RichTextLabel = %TestOutput

@export var _model_types : Array[ModelType]

var _data_manager : Node

func _ready() -> void:
	if has_node(^"/root/DataManager"):
		_data_manager = get_node(^"/root/DataManager")
	else:
		assert(false, "请开启GDDataForge插件，并检查DataManager单例是否存在！")
	if _data_manager:
		# 连接信号
		_data_manager.load_completed.connect(_on_load_completed)
		_data_manager.batch_load_completed.connect(_on_batch_load_completed)
	
	# 输出初始信息
	_print_test_info("数据管理器测试")
	_print_test_info("点击按钮开始测试...")

## 加载完成回调
func _on_load_completed(table_name: String) -> void:
	_print_test_info("\n表格加载完成: %s" % table_name)
	var data = _data_manager.get_table_data(table_name)
	_print_table_data(table_name, data)

## 批量加载完成回调
func _on_batch_load_completed(loaded_tables: Array[String]) -> void:
	_print_test_info("\n批量加载完成!")
	_print_test_info("已加载表格: {0}".format([loaded_tables]))

## 输出测试信息
func _print_test_info(text: String) -> void:
	if test_output:
		test_output.append_text("[{0}]{1}\n".format([Time.get_unix_time_from_system(), text]))

## 打印表格数据
func _print_table_data(table_name: String, data: Dictionary) -> void:
	if data == null:
		_print_test_info("[color=yellow]警告: 表格数据为空: %s[/color]" % table_name)
		return
		
	_print_test_info("\n=== 表格内容: %s ===" % table_name)
	for key in data:
		var value = data[key]
		if typeof(value) == TYPE_ARRAY:
			value = ""
			for v in data[key]:
				value += v + " "
		_print_test_info("{0}: {1}".format([key, value]))

## 测试数据模型的方法
func _test_model_methods() -> void:
	_print_test_info("\n=== 测试数据模型方法 ===")
	
	# 测试玩家模型方法
	var player_models : Array = _data_manager.get_all_data_models("player")
	for player : PlayerModel in player_models:
		_print_test_info("\n玩家模型方法测试 : %s" %player.name)
		_print_test_info("- 攻击力: %d" % player.get_attack())
		_print_test_info("- 防御力: %d" % player.get_defense())
		_print_test_info("- 速度: %d" % player.get_speed())
	
	# 测试物品模型方法
	var item_models : Array = _data_manager.get_all_data_models("item")
	var sword : ItemModel = _data_manager.get_data_model("item", "sword_1") 
	if sword:
		_print_test_info("\n物品模型方法测试 (sword_1):")
		_print_test_info("- 是否武器: %s" % sword.is_weapon())
		_print_test_info("- 是否防具: %s" % sword.is_shield())
		_print_test_info("- 主属性值: %d" % sword.get_main_property())
		_print_test_info("- 是否有'武器'标签: %s" % sword.has_tag("武器"))
		
	var shield : ItemModel = _data_manager.get_data_model("item", "shield_1")
	if shield:
		_print_test_info("\n物品模型方法测试 (shield_1):")
		_print_test_info("- 是否武器: %s" % shield.is_weapon())
		_print_test_info("- 是否防具: %s" % shield.is_shield())
		_print_test_info("- 主属性值: %d" % shield.get_main_property())
		_print_test_info("- 是否有'防具'标签: %s" % shield.has_tag("防具"))
		
	print("table shield :", DataManager.get_table_item("item", "shield_1") )

func _on_load_btn_pressed() -> void:
	_print_test_info("\n=== 开始异步加载测试 ===")
	
	# 异步加载
	_data_manager.load_models(_model_types, func(loaded_tables: Array[String]):
		_print_test_info("\n异步加载完成回调!")
		_print_test_info("已加载表格:{0}".format([loaded_tables]))
		# 测试数据模型方法
		_test_model_methods()
	)


func _on_clear_btn_pressed() -> void:
	_print_test_info("\n=== 清理测试数据 ===")
	_data_manager.clear_model_types()
	_data_manager.clear_table_types()
	test_output.text = ""
	_print_test_info("数据已清理!")
	_print_test_info("点击按钮开始新的测试...")
