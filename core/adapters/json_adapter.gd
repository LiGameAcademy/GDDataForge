extends GDFDataAdapter
class_name GDFJsonAdapter

const TableDocumentScript = preload("res://addons/GDDataForge/core/table_document.gd")

func can_handle(path: String) -> bool:
	return path.get_extension().to_lower() == "json"

func load(path: String) -> GDFTableDocument:
	var doc: GDFTableDocument = TableDocumentScript.new()
	doc.source_path = path
	doc.source_format = "json"
	doc.table_id = path.get_file().get_basename()
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return doc
	var content := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(content) != OK:
		return doc
	var json_data = json.get_data()
	if typeof(json_data) != TYPE_DICTIONARY:
		return doc
	var rows := {}
	if json_data.has("_meta"):
		var meta: Dictionary = json_data["_meta"]
		doc.meta["validation_rules"] = meta.get("validation_rules", {})
		doc.meta["primary_key"] = meta.get("primary_key", "ID")
		doc.meta["foreign_keys"] = meta.get("foreign_keys", [])
		doc.meta["columns"] = meta.get("columns", [])
		doc.meta["types"] = meta.get("types", [])
		if json_data.has("_data"):
			rows = json_data["_data"]
		else:
			rows = json_data.duplicate(true)
			rows.erase("_meta")
	else:
		rows = json_data
	doc.rows = rows
	var order: Array[String] = []
	for row_id in rows.keys():
		order.append(String(row_id))
	doc.row_order = order
	return doc

func save(path: String, doc: GDFTableDocument) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return false
	var output := {
		"_meta": {
			"primary_key": doc.meta.get("primary_key", "ID"),
			"columns": doc.meta.get("columns", []),
			"types": doc.meta.get("types", []),
			"validation_rules": doc.meta.get("validation_rules", {}),
			"foreign_keys": doc.meta.get("foreign_keys", [])
		},
		"_data": doc.rows
	}
	file.store_string(JSON.stringify(output, "\t"))
	file.close()
	return true
