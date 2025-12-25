# Save Service (FW_SaveService)

Features:
- Versioned save slots (3 slots, 0-based)
- Schema migrations (missing schema treated as -1)
- Corruption backup and safe fail behavior

## Usage

```gdscript
var s := services["save"]
# Save
s.save_slot(0, {"hello":"world"})
# Load
var r = s.load_slot(0)
if r["ok"]:
	var data = r["data"]
```

## Notes
- Files are stored under `user://save/slot_{i}.json`.
- The key `_fw_schema_version` is used to manage schema changes.
- If you change the save schema, implement a migration path that moves data from older schema to the new format.
