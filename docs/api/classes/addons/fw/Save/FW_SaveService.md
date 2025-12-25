# addons/fw/Save/FW_SaveService.gd

*Class*: `FW_SaveService`

### Functions

<a name="fn-configure"></a>
#### `configure(config: FW_ConfigService)`

- **Signature return**: `void`

<a name="fn-slot_exists"></a>
#### `slot_exists(slot_id: int)`

- **Signature return**: `bool`

<a name="fn-get_slot_path"></a>
#### `get_slot_path(slot_id: int)`

- **Signature return**: `String`

<a name="fn-load_slot"></a>
#### `load_slot(slot_id: int)`

- **Signature return**: `Dictionary`

<a name="fn-save_slot"></a>
#### `save_slot(slot_id: int, data: Dictionary, meta_overrides: Dictionary = {})`

- **Signature return**: `Dictionary`

<a name="fn-delete_slot"></a>
#### `delete_slot(slot_id: int)`

- **Signature return**: `Dictionary`

<a name="fn-_ensure_dirs"></a>
#### `_ensure_dirs()`

- **Signature return**: `void`

<a name="fn-_get_schema_version"></a>
#### `_get_schema_version(save_dict: Dictionary)`

- **Signature return**: `int`

<a name="fn-_normalize_any"></a>
#### `_normalize_any(save_dict: Dictionary)`

- **Signature return**: `Dictionary`

<a name="fn-_migrate_to_current"></a>
#### `_migrate_to_current(save_dict: Dictionary)`

- **Signature return**: `Dictionary`

<a name="fn-_migrate_minus1_to_0"></a>
#### `_migrate_minus1_to_0(legacy: Dictionary)`

- **Signature return**: `Dictionary`

<a name="fn-_normalize_v0"></a>
#### `_normalize_v0(save_dict: Dictionary)`

- **Signature return**: `Dictionary`

<a name="fn-_make_canonical_v0"></a>
#### `_make_canonical_v0(created_at_unix: int, saved_at_unix: int, data: Dictionary, meta_overrides: Dictionary = {})`

- **Signature return**: `Dictionary`

<a name="fn-_make_default_meta"></a>
#### `_make_default_meta()`

- **Signature return**: `Dictionary`

<a name="fn-_handle_corrupt_slot"></a>
#### `_handle_corrupt_slot(slot_id: int, path: String, reason: String)`

- **Signature return**: `Dictionary`

<a name="fn-_backup_corrupt_file"></a>
#### `_backup_corrupt_file(slot_id: int, path: String)`

- **Signature return**: `Dictionary`

