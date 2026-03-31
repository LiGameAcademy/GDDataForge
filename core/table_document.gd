extends RefCounted
class_name GDFTableDocument

var table_id: String = ""
var source_path: String = ""
var source_format: String = ""
var meta: Dictionary = {
	"columns": [],
	"types": [],
	"primary_key": "ID",
	"validation_rules": {},
	"foreign_keys": []
}
var rows: Dictionary = {}
var row_order: Array[String] = []

func to_legacy_csv_dict() -> Dictionary:
	return {
		"data": rows,
		"columns": meta.get("columns", []),
		"types": meta.get("types", []),
		"validation_rules": meta.get("validation_rules", {})
	}

func to_legacy_json_dict() -> Dictionary:
	return {
		"data": rows,
		"validation_rules": meta.get("validation_rules", {}),
		"primary_key": meta.get("primary_key", "ID"),
		"foreign_keys": meta.get("foreign_keys", [])
	}
