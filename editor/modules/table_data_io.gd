extends RefCounted
class_name TableDataIO

const DataRepositoryScript = preload("res://addons/GDDataForge/core/data_repository.gd")
const TableDocumentScript = preload("res://addons/GDDataForge/core/table_document.gd")
var _repo := DataRepositoryScript.new()

func parse_csv_file(file_path: String) -> Dictionary:
	var doc = _repo.callv("load_table", [file_path])
	return doc.to_legacy_csv_dict()

func parse_json_file(file_path: String) -> Dictionary:
	var doc = _repo.callv("load_table", [file_path])
	return doc.to_legacy_json_dict()

func save_csv_file(
	file_path: String,
	current_table: Dictionary,
	current_table_columns: Array[String],
	current_table_types: Array[String],
	field_validation_rules: Dictionary,
	row_order: Array[String] = []
) -> bool:
	var doc = TableDocumentScript.new()
	doc.source_path = file_path
	doc.source_format = "csv"
	doc.rows = current_table.duplicate(true)
	doc.row_order = row_order.duplicate()
	doc.meta["columns"] = current_table_columns.duplicate()
	doc.meta["types"] = current_table_types.duplicate()
	doc.meta["validation_rules"] = field_validation_rules.duplicate(true)
	doc.meta["primary_key"] = "ID"
	doc.meta["foreign_keys"] = []
	return _repo.callv("save_table", [file_path, doc])

func save_json_file(
	file_path: String,
	current_table: Dictionary,
	current_table_columns: Array[String],
	current_table_types: Array[String],
	field_validation_rules: Dictionary,
	primary_key: String,
	foreign_keys: Array[Dictionary]
) -> bool:
	var doc = TableDocumentScript.new()
	doc.source_path = file_path
	doc.source_format = "json"
	doc.rows = current_table.duplicate(true)
	doc.meta["columns"] = current_table_columns.duplicate()
	doc.meta["types"] = current_table_types.duplicate()
	doc.meta["validation_rules"] = field_validation_rules.duplicate(true)
	doc.meta["primary_key"] = primary_key
	doc.meta["foreign_keys"] = foreign_keys.duplicate(true)
	return _repo.callv("save_table", [file_path, doc])
