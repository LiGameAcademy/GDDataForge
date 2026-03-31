class_name GDFAddColumnCommand
extends RefCounted

var description: String = ""

var columns: Array[String]
var types: Array[String]
var col_name: String
var col_type: String

func _init(cols: Array[String], tps: Array[String], cn: String, ct: String):
	columns = cols
	types = tps
	col_name = cn
	col_type = ct
	description = "添加列: " + col_name

func execute() -> void:
	columns.append(col_name)
	types.append(col_type)

func undo() -> void:
	var idx = columns.find(col_name)
	if idx >= 0:
		columns.remove_at(idx)
		types.remove_at(idx)
