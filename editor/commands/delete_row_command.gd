class_name GDFDeleteRowCommand
extends RefCounted

var description: String = ""

var table: Dictionary
var row_id: String
var row_data: Dictionary

func _init(t: Dictionary, rid: String):
	table = t
	row_id = rid
	row_data = {}.duplicate()
	description = "删除行: " + row_id

func execute() -> void:
	if table.has(row_id):
		row_data = table[row_id].duplicate(true)
		table.erase(row_id)

func undo() -> void:
	table[row_id] = row_data.duplicate(true)
