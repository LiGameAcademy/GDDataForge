extends RefCounted
class_name GDFDataRepository

const CsvAdapterScript = preload("res://addons/GDDataForge/core/adapters/csv_adapter.gd")
const JsonAdapterScript = preload("res://addons/GDDataForge/core/adapters/json_adapter.gd")
const TableDocumentScript = preload("res://addons/GDDataForge/core/table_document.gd")

var _adapters: Array = []

func _init() -> void:
	_adapters = [
		CsvAdapterScript.new(),
		JsonAdapterScript.new()
	]

func register_adapter(adapter: GDFDataAdapter) -> void:
	if adapter == null:
		return
	_adapters.append(adapter)

func load_table(path: String) -> GDFTableDocument:
	var adapter := _find_adapter(path)
	if adapter == null:
		return TableDocumentScript.new()
	return adapter.load(path)

func save_table(path: String, doc: GDFTableDocument) -> bool:
	var adapter := _find_adapter(path)
	if adapter == null:
		return false
	return adapter.save(path, doc)

func _find_adapter(path: String) -> GDFDataAdapter:
	for adapter in _adapters:
		if adapter.can_handle(path):
			return adapter
	return null
