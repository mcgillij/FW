extends Node
class_name FW_SaveService

signal save_completed(slot_id: int, ok: bool, result: Dictionary)
signal load_completed(slot_id: int, ok: bool, result: Dictionary)
signal slot_deleted(slot_id: int, ok: bool, result: Dictionary)

const SLOT_COUNT := 3
const SLOT_MIN := 0
const SLOT_MAX := SLOT_COUNT - 1

const SAVE_ROOT_DIR := "user://save"
const CORRUPT_DIR := "user://save/corrupt"

const SLOT_FILENAME_FORMAT := "slot_%d.json"

const SCHEMA_KEY := "_fw_schema_version"
const CURRENT_SCHEMA_VERSION := 0
const MISSING_SCHEMA_VERSION := -1

const FW_VERSION := "0.0.0"

var _config: FW_ConfigService

func configure(config: FW_ConfigService) -> void:
	_config = config

func slot_exists(slot_id: int) -> bool:
	var path := get_slot_path(slot_id)
	if path.is_empty():
		return false
	return FileAccess.file_exists(path)

func get_slot_path(slot_id: int) -> String:
	if slot_id < SLOT_MIN or slot_id > SLOT_MAX:
		return ""
	return "%s/%s" % [SAVE_ROOT_DIR, SLOT_FILENAME_FORMAT % slot_id]

func load_slot(slot_id: int) -> Dictionary:
	var path := get_slot_path(slot_id)
	if path.is_empty():
		var r := {"ok": false, "error": "save.slot_invalid", "slot_id": slot_id}
		load_completed.emit(slot_id, false, r)
		return r

	if not FileAccess.file_exists(path):
		var r := {"ok": false, "error": "save.file_missing", "slot_id": slot_id, "path": path}
		load_completed.emit(slot_id, false, r)
		return r

	var read := FW_FileStore.read_json(path)
	if not bool(read.get("ok", false)):
		# JSON parse failed or cant open => treat as corruption and reset.
		var r := _handle_corrupt_slot(slot_id, path, str(read.get("error", "read_failed")))
		load_completed.emit(slot_id, false, r)
		return r

	var raw: Variant = read.get("data", null)
	if raw == null:
		# Empty file is treated as corruption to avoid silently losing state.
		var r := _handle_corrupt_slot(slot_id, path, "empty_file")
		load_completed.emit(slot_id, false, r)
		return r

	if not (raw is Dictionary):
		var r := _handle_corrupt_slot(slot_id, path, "root_not_dictionary")
		load_completed.emit(slot_id, false, r)
		return r

	var save_dict: Dictionary = raw
	var version := _get_schema_version(save_dict)
	if version > CURRENT_SCHEMA_VERSION:
		var r := {
			"ok": false,
			"error": "save.future_schema",
			"slot_id": slot_id,
			"path": path,
			"schema_version": version,
			"current_schema_version": CURRENT_SCHEMA_VERSION,
		}
		load_completed.emit(slot_id, false, r)
		return r

	var migrated := false
	var prev_version := version
	var canonical: Dictionary
	if version < CURRENT_SCHEMA_VERSION:
		var mig := _migrate_to_current(save_dict)
		if not bool(mig.get("ok", false)):
			var r := _handle_corrupt_slot(slot_id, path, str(mig.get("error", "migration_failed")))
			load_completed.emit(slot_id, false, r)
			return r
		canonical = mig.get("save", {})
		migrated = true
	else:
		# version == 0
		var norm := _normalize_v0(save_dict)
		if not bool(norm.get("ok", false)):
			var r := _handle_corrupt_slot(slot_id, path, str(norm.get("error", "schema_invalid")))
			load_completed.emit(slot_id, false, r)
			return r
		canonical = norm.get("save", {})

	# Missing schema is treated as legacy (-1) and migrated to v0.
	# This is handled by _get_schema_version + _migrate_to_current.
	if prev_version == MISSING_SCHEMA_VERSION and not migrated:
		var mig2 := _migrate_to_current(save_dict)
		if not bool(mig2.get("ok", false)):
			var r := _handle_corrupt_slot(slot_id, path, str(mig2.get("error", "migration_failed")))
			load_completed.emit(slot_id, false, r)
			return r
		canonical = mig2.get("save", {})
		migrated = true

	if migrated:
		# Write back canonical migrated save.
		_ensure_dirs()
		var write_err := FW_FileStore.write_json(path, canonical)
		if write_err != OK:
			var r := {
				"ok": false,
				"error": "save.write_failed",
				"slot_id": slot_id,
				"path": path,
				"code": write_err,
			}
			load_completed.emit(slot_id, false, r)
			return r

	var r_ok := {
		"ok": true,
		"slot_id": slot_id,
		"path": path,
		"migrated": migrated,
		"previous_schema_version": prev_version,
		"save": canonical,
		"data": canonical.get("data", {}),
	}
	load_completed.emit(slot_id, true, r_ok)
	return r_ok

func save_slot(slot_id: int, data: Dictionary, meta_overrides: Dictionary = {}) -> Dictionary:
	var path := get_slot_path(slot_id)
	if path.is_empty():
		var r := {"ok": false, "error": "save.slot_invalid", "slot_id": slot_id}
		save_completed.emit(slot_id, false, r)
		return r

	_ensure_dirs()

	var now := int(Time.get_unix_time_from_system())
	var created_at := now

	# Preserve created_at_unix if an existing valid save is present.
	if FileAccess.file_exists(path):
		var read := FW_FileStore.read_json(path)
		if bool(read.get("ok", false)) and (read.get("data", null) is Dictionary):
			var existing: Dictionary = read.get("data", {})
			if _get_schema_version(existing) <= CURRENT_SCHEMA_VERSION:
				var norm := _normalize_any(existing)
				if bool(norm.get("ok", false)):
					var existing_canon: Dictionary = norm.get("save", {})
					created_at = int(existing_canon.get("created_at_unix", now))
		else:
			# Existing file is unreadable; back it up so we don't destroy evidence.
			# If the backup fails, fail closed to avoid losing the only copy.
			var backup := _backup_corrupt_file(slot_id, path)
			if not bool(backup.get("ok", false)):
				var r_backup := {
					"ok": false,
					"error": "save.corrupt_backup_failed",
					"slot_id": slot_id,
					"path": path,
					"reason": "save_over_corrupt",
					"details": backup,
				}
				save_completed.emit(slot_id, false, r_backup)
				return r_backup

	var canonical := _make_canonical_v0(created_at, now, data, meta_overrides)
	var err := FW_FileStore.write_json(path, canonical)
	if err != OK:
		var r := {"ok": false, "error": "save.write_failed", "slot_id": slot_id, "path": path, "code": err}
		save_completed.emit(slot_id, false, r)
		return r

	var r_ok := {"ok": true, "slot_id": slot_id, "path": path}
	save_completed.emit(slot_id, true, r_ok)
	return r_ok

func delete_slot(slot_id: int) -> Dictionary:
	var path := get_slot_path(slot_id)
	if path.is_empty():
		var r := {"ok": false, "error": "save.slot_invalid", "slot_id": slot_id}
		slot_deleted.emit(slot_id, false, r)
		return r

	if not FileAccess.file_exists(path):
		var r_missing := {"ok": false, "error": "save.file_missing", "slot_id": slot_id, "path": path}
		slot_deleted.emit(slot_id, false, r_missing)
		return r_missing

	var err := DirAccess.remove_absolute(path)
	if err != OK:
		var r := {"ok": false, "error": "save.delete_failed", "slot_id": slot_id, "path": path, "code": err}
		slot_deleted.emit(slot_id, false, r)
		return r

	var r_ok := {"ok": true, "slot_id": slot_id, "path": path}
	slot_deleted.emit(slot_id, true, r_ok)
	return r_ok

func _ensure_dirs() -> void:
	FW_FileStore.ensure_dir(SAVE_ROOT_DIR)
	FW_FileStore.ensure_dir(CORRUPT_DIR)

func _get_schema_version(save_dict: Dictionary) -> int:
	if save_dict.has(SCHEMA_KEY):
		return int(save_dict.get(SCHEMA_KEY, MISSING_SCHEMA_VERSION))
	return MISSING_SCHEMA_VERSION

func _normalize_any(save_dict: Dictionary) -> Dictionary:
	var v := _get_schema_version(save_dict)
	if v == CURRENT_SCHEMA_VERSION:
		return _normalize_v0(save_dict)
	if v == MISSING_SCHEMA_VERSION:
		# Treat as legacy root dict.
		return _migrate_minus1_to_0(save_dict)
	if v < CURRENT_SCHEMA_VERSION:
		return _migrate_to_current(save_dict)
	return {"ok": false, "error": "save.future_schema"}

func _migrate_to_current(save_dict: Dictionary) -> Dictionary:
	var v := _get_schema_version(save_dict)
	if v == MISSING_SCHEMA_VERSION:
		v = MISSING_SCHEMA_VERSION

	if v > CURRENT_SCHEMA_VERSION:
		return {"ok": false, "error": "save.future_schema", "schema_version": v}

	# Only v0 exists currently.
	if v == CURRENT_SCHEMA_VERSION:
		return _normalize_v0(save_dict)

	if v == MISSING_SCHEMA_VERSION:
		return _migrate_minus1_to_0(save_dict)

	return {"ok": false, "error": "save.no_migration_path", "schema_version": v}

func _migrate_minus1_to_0(legacy: Dictionary) -> Dictionary:
	var now := int(Time.get_unix_time_from_system())

	# If the legacy dict already looks like a canonical save, keep its data/meta.
	var has_data := legacy.has("data") and (legacy.get("data") is Dictionary)
	var has_meta := legacy.has("meta") and (legacy.get("meta") is Dictionary)

	var created_at := now
	if legacy.has("created_at_unix"):
		created_at = int(legacy.get("created_at_unix", now))
	elif legacy.has("saved_at_unix"):
		created_at = int(legacy.get("saved_at_unix", now))

	var saved_at := now
	if legacy.has("saved_at_unix"):
		saved_at = int(legacy.get("saved_at_unix", now))

	var data: Dictionary = {}
	if has_data:
		data = legacy.get("data", {})
	else:
		# Wrap the whole legacy dict as data.
		data = legacy.duplicate(true)

	var meta: Dictionary = {}
	if has_meta:
		meta = legacy.get("meta", {})

	var canonical := _make_canonical_v0(created_at, saved_at, data, meta)
	return {"ok": true, "save": canonical, "from_schema_version": MISSING_SCHEMA_VERSION, "to_schema_version": CURRENT_SCHEMA_VERSION}

func _normalize_v0(save_dict: Dictionary) -> Dictionary:
	if save_dict.get(SCHEMA_KEY, MISSING_SCHEMA_VERSION) != CURRENT_SCHEMA_VERSION:
		return {"ok": false, "error": "save.schema_mismatch"}

	if not save_dict.has("data") or not (save_dict.get("data") is Dictionary):
		return {"ok": false, "error": "save.missing_data"}

	var now := int(Time.get_unix_time_from_system())
	var created_at := int(save_dict.get("created_at_unix", now))
	var saved_at := int(save_dict.get("saved_at_unix", now))
	var data: Dictionary = save_dict.get("data", {})
	var meta: Dictionary = {}
	if save_dict.has("meta") and (save_dict.get("meta") is Dictionary):
		meta = save_dict.get("meta", {})

	var canonical := _make_canonical_v0(created_at, saved_at, data, meta)
	return {"ok": true, "save": canonical}

func _make_canonical_v0(created_at_unix: int, saved_at_unix: int, data: Dictionary, meta_overrides: Dictionary = {}) -> Dictionary:
	var meta := _make_default_meta()
	for k in meta_overrides.keys():
		meta[k] = meta_overrides[k]

	return {
		SCHEMA_KEY: CURRENT_SCHEMA_VERSION,
		"created_at_unix": int(created_at_unix),
		"saved_at_unix": int(saved_at_unix),
		"data": data,
		"meta": meta,
	}

func _make_default_meta() -> Dictionary:
	var m := {
		"platform": OS.get_name(),
		"fw_version": FW_VERSION,
		"app_version": "unknown",
	}
	if OS.has_method("get_version"):
		m["os_version"] = str(OS.get_version())
	return m

func _handle_corrupt_slot(slot_id: int, path: String, reason: String) -> Dictionary:
	_ensure_dirs()
	var backup := _backup_corrupt_file(slot_id, path)
	if not bool(backup.get("ok", false)):
		return {
			"ok": false,
			"error": "save.corrupt_backup_failed",
			"slot_id": slot_id,
			"path": path,
			"reason": reason,
			"details": backup,
		}

	# Create an empty v0 slot so future loads work, but still report failure.
	var now := int(Time.get_unix_time_from_system())
	var empty := _make_canonical_v0(now, now, {}, {})
	var write_err := FW_FileStore.write_json(path, empty)
	if write_err != OK:
		return {
			"ok": false,
			"error": "save.reset_write_failed",
			"slot_id": slot_id,
			"path": path,
			"backup_path": str(backup.get("backup_path", "")),
			"reason": reason,
			"code": write_err,
		}

	return {
		"ok": false,
		"error": "save.corrupt",
		"slot_id": slot_id,
		"path": path,
		"backup_path": str(backup.get("backup_path", "")),
		"reason": reason,
	}

func _backup_corrupt_file(slot_id: int, path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": true, "backup_path": ""}

	var stamp := "%d_%d" % [int(Time.get_unix_time_from_system()), int(randi() % 1000000)]
	var backup_filename := "slot_%d.corrupt.%s.json" % [slot_id, stamp]
	var backup_path := "%s/%s" % [CORRUPT_DIR, backup_filename]

	var err := DirAccess.rename_absolute(path, backup_path)
	if err == OK:
		return {"ok": true, "backup_path": backup_path, "method": "rename"}

	# Fallback: copy then remove.
	var r := FW_FileStore.read_text(path)
	if not bool(r.get("ok", false)):
		return {"ok": false, "error": "save.backup_read_failed", "path": path, "read_error": r.get("error", "")}
	var write_err := FW_FileStore.write_text(backup_path, str(r.get("text", "")))
	if write_err != OK:
		return {"ok": false, "error": "save.backup_write_failed", "backup_path": backup_path, "code": write_err}

	DirAccess.remove_absolute(path)
	return {"ok": true, "backup_path": backup_path, "method": "copy_remove"}
