class_name GDFAddRowCommand
extends RefCounted

var description: String = ""

var table: Dictionary
var row_id: String
var row_data: Dictionary

func _init(t: Dictionary, rid: String, rdata: Dictionary):
	table = t
	row_id = rid
	row_data = rdata.duplicate(true)
	description = "添加行: " + row_id

func execute() -> void:
	table[row_id] = row_data.duplicate(true)

func undo() -> void:
	table.erase(row_id)
