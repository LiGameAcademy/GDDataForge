extends RefCounted
class_name GDFDataAdapter

func can_handle(_path: String) -> bool:
	return false

func load(_path: String) -> GDFTableDocument:
	return GDFTableDocument.new()

func save(_path: String, _doc: GDFTableDocument) -> bool:
	return false
