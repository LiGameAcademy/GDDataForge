class_name GDFUpdateCellCommand
extends RefCounted

var description: String = ""

var table: Dictionary
var row_id: String
var column: String
var old_value: Variant
var new_value: Variant

func _init(t: Dictionary, rid: String, col: String, old: Variant, new_val: Variant):
	table = t
	row_id = rid
	column = col
	old_value = old
	new_value = new_val
	description = "修改 %s.%s" % [row_id, column]

func execute() -> void:
	if table.has(row_id):
		table[row_id][column] = new_value

func undo() -> void:
	if table.has(row_id):
		table[row_id][column] = old_value
