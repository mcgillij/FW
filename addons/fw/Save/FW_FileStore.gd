extends Node
class_name FW_FileStore

static func ensure_dir(path: String) -> void:
	if path.is_empty():
		return
	if DirAccess.dir_exists_absolute(path):
		return
	DirAccess.make_dir_recursive_absolute(path)

static func write_text(path: String, text: String) -> int:
	ensure_dir(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ERR_CANT_OPEN
	f.store_string(text)
	f.close()
	return OK

static func read_text(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "file_missing"}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"ok": false, "error": "cant_open"}
	var text := f.get_as_text()
	f.close()
	return {"ok": true, "text": text}

static func write_json(path: String, data: Variant) -> int:
	var text := JSON.stringify(data)
	return write_text(path, text)

static func read_json(path: String) -> Dictionary:
	var r := read_text(path)
	if not r.get("ok", false):
		return r
	var parsed: Variant = JSON.parse_string(str(r.get("text", "")))
	if parsed == null and r.get("text", "") != "":
		return {"ok": false, "error": "json_parse_failed"}
	return {"ok": true, "data": parsed}
