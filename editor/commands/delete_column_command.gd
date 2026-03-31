class_name GDFDeleteColumnCommand
extends RefCounted

var description: String = ""

var columns: Array[String]
var types: Array[String]
var idx: int
var col_name: String
var col_type: String

func _init(cols: Array[String], tps: Array[String], cn: String, ct: String):
	columns = cols
	types = tps
	col_name = cn
	col_type = ct
	idx = cols.find(cn)
	description = "删除列: " + col_name

func execute() -> void:
	if idx >= 0:
		columns.remove_at(idx)
		types.remove_at(idx)

func undo() -> void:
	columns.insert(idx, col_name)
	types.insert(idx, col_type)
