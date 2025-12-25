extends "res://Scripts/base_menu_panel.gd"

signal back_button

@export var job_prefab: PackedScene

@onready var job_container: VBoxContainer = %job_container
@onready var job_description: RichTextLabel = %job_description

const ABILITY_ICON_PATHS := {
	"Bark": "res://Skills/Images/red.png",
	"Alertness": "res://Skills/Images/blue.png",
	"Reflex": "res://Skills/Images/green.png",
	"Vigor": "res://Skills/Images/orange.png",
	"Enthusiasm": "res://Skills/Images/pink.png",
}

var _ability_icon_cache: Dictionary = {}
var _current_selection: Control = null

const HEADER_MIN_LUMINANCE := 0.42
const INITIAL_BATCH_COUNT := 6
const ASYNC_BATCH_SIZE := 3
const COMPLETED_THRESHOLD := 50

var _job_load_generation := 0
var _pending_job_entries: Array = []
var _initial_selection_done := false

func _ready() -> void:
	job_description.text = ""
	connect("slide_in_started", Callable(self, "_on_panel_slide_in_started"))
	connect("slide_out_finished", Callable(self, "_on_panel_slide_out_finished"))
	set_process(false)

func _on_back_button_pressed() -> void:
	emit_signal("back_button")

func _populate_jobs() -> void:
	_job_load_generation += 1
	var generation := _job_load_generation
	_clear_job_container()
	job_description.text = ""
	if job_prefab == null:
		printerr("[MasteryTracker] job_prefab is not assigned")
		return
	var entries := FW_JobManager.get_all_job_entries()
	if entries.is_empty():
		job_description.text = "No jobs found."
		return

	# Filter to only completed jobs
	var completed_entries = entries.filter(func(e):
		var job_data: FW_Job = e.get("job", null)
		return job_data and UnlockManager.has_job_win(job_data.name)
	)

	if completed_entries.is_empty():
		job_description.text = "No completed jobs found."
		return

	_pending_job_entries = completed_entries.duplicate(true)

	# If below threshold, load all at once
	if _pending_job_entries.size() <= COMPLETED_THRESHOLD:
		for entry in _pending_job_entries:
			if generation != _job_load_generation:
				break
			_instantiate_job_prefab(entry)
		_pending_job_entries.clear()
		var created_prefabs = job_container.get_children()
		if created_prefabs.size() > 0:
			_select_initial_prefab(created_prefabs[0])
	else:
		# Use batch loading for large numbers
		var initial_limit: int = min(INITIAL_BATCH_COUNT, _pending_job_entries.size())
		var created: Array[Control] = _consume_pending_entries(generation, initial_limit)
		if created.size() > 0:
			_select_initial_prefab(created[0])
		_start_job_queue()

func _clear_job_container() -> void:
	for child in job_container.get_children():
		child.queue_free()
	_current_selection = null
	_pending_job_entries.clear()
	_initial_selection_done = false
	set_process(false)

func _instantiate_job_prefab(entry: Dictionary) -> Control:
	var job_data: FW_Job = entry.get("job", null)
	var resource_path: String = entry.get("resource_path", "")
	var requirements: Dictionary = entry.get("requirements", {})
	_cache_icons_for_requirements(requirements)
	var prefab_instance := job_prefab.instantiate()
	if not (prefab_instance is Control):
		prefab_instance.free()
		return null
	var prefab_control: Control = prefab_instance
	if not prefab_control.has_method("setup"):
		prefab_control.free()
		printerr("[MasteryTracker] job_prefab is missing setup()")
		return null
	job_container.add_child(prefab_control)
	var completed := false
	if job_data and job_data.name:
		completed = UnlockManager.has_job_win(job_data.name)
	prefab_control.setup(job_data, resource_path, requirements, completed, _ability_icon_cache)
	if prefab_control.has_signal("job_selected"):
		prefab_control.job_selected.connect(Callable(self, "_on_job_selected").bind(prefab_control))
	else:
		printerr("[MasteryTracker] job_prefab is missing job_selected signal")
	prefab_control.set_selected(false)
	return prefab_control

func _consume_pending_entries(generation: int, count: int) -> Array[Control]:
	var created: Array[Control] = []
	for _i in range(count):
		if generation != _job_load_generation:
			break
		if _pending_job_entries.is_empty():
			break
		var entry: Dictionary = _pending_job_entries.pop_front()
		var prefab_control := _instantiate_job_prefab(entry)
		if prefab_control:
			created.append(prefab_control)
	return created

func _start_job_queue() -> void:
	if _pending_job_entries.is_empty():
		return
	set_process(true)

func _process(_delta: float) -> void:
	if _pending_job_entries.is_empty():
		set_process(false)
		return
	var generation := _job_load_generation
	var created: Array[Control] = _consume_pending_entries(generation, ASYNC_BATCH_SIZE)
	if created.size() > 0 and not _initial_selection_done:
		_select_initial_prefab(created[0])
	if _pending_job_entries.is_empty() or generation != _job_load_generation:
		set_process(false)

func _select_initial_prefab(prefab: Control) -> void:
	if prefab == null or _initial_selection_done:
		return
	_initial_selection_done = true
	_on_job_selected(prefab.get_job(), prefab.get_requirements(), prefab.is_completed(), prefab.get_display_name(), prefab.get_accent_color(), prefab)

func _cache_icons_for_requirements(requirements: Dictionary) -> void:
	for ability_key in requirements.keys():
		_cache_icon_for_ability(ability_key)

func _cache_icon_for_ability(ability_key) -> void:
	var key := str(ability_key)
	if _ability_icon_cache.has(key):
		return
	var canonical := key.capitalize()
	var path: String = ABILITY_ICON_PATHS.get(canonical, "")
	if path == "":
		return
	if ResourceLoader.exists(path):
		var texture := load(path)
		_ability_icon_cache[key] = texture
		if canonical != key:
			_ability_icon_cache[canonical] = texture
	else:
		printerr("[MasteryTracker] Missing ability icon at path: ", path)

func _on_job_selected(job: FW_Job, requirements: Dictionary, completed: bool, display_name: String, accent_color: Color, sender: Control) -> void:
	if _current_selection and _current_selection != sender and _current_selection.has_method("set_selected"):
		_current_selection.set_selected(false)
	_current_selection = sender
	if _current_selection and _current_selection.has_method("set_selected"):
		_current_selection.set_selected(true)
	var header_color: Color = accent_color
	if job and job.job_color != null:
		header_color = FW_Utils.normalize_color(job.job_color)
	else:
		if sender and sender.has_method("get_accent_color"):
			header_color = sender.get_accent_color()
	header_color = _ensure_readable_color(header_color)
	_update_job_description(job, requirements, completed, display_name, header_color)

func _update_job_description(job: FW_Job, requirements: Dictionary, completed: bool, display_name: String, accent_color: Color) -> void:
	var lines: Array[String] = []
	var header := "[b]%s[/b]" % display_name
	header = FW_Colors.colorize_text(display_name, accent_color, true)
	lines.append(header)
	if job and job.description:
		var desc := job.description.strip_edges()
		if desc != "":
			lines.append("")
			lines.append(desc)
	lines.append("")
	lines.append("[b]Requirements:[/b]")
	var ability_keys := requirements.keys()
	ability_keys.sort()
	for ability_key in ability_keys:
		var ability_name: String = str(ability_key)
		var colored_name: String = ability_name
		var ability_color = FW_Colors.get_color(ability_name)
		if ability_color is Color:
			colored_name = FW_Colors.colorize_text(ability_name, ability_color, true)
		var count: int = int(requirements[ability_key])
		lines.append("- %s x%d" % [colored_name, count])
	var status_color := Color(0.3, 0.85, 0.4, 1.0) if completed else Color(0.95, 0.7, 0.25, 1.0)
	var status_text := "Completed" if completed else "In Progress"
	lines.append("")
	lines.append("[b]Status:[/b] " + FW_Colors.colorize_text(status_text, status_color, true))
	var total_jobs := FW_JobManager.get_total_jobs()
	var completed_jobs := UnlockManager.get_job_wins_count()
	lines.append("[i]Overall Progress: %d / %d jobs mastered[/i]" % [completed_jobs, total_jobs])
	var buffer := ""
	for idx in range(lines.size()):
		buffer += lines[idx]
		if idx < lines.size() - 1:
			buffer += "\n"
	job_description.text = buffer

func _ensure_readable_color(color_value: Color) -> Color:
	var base := Color(color_value.r, color_value.g, color_value.b, 1.0)
	var luminance := base.r * 0.2126 + base.g * 0.7152 + base.b * 0.0722
	if luminance < HEADER_MIN_LUMINANCE:
		var boost := clampf((HEADER_MIN_LUMINANCE - luminance) * 1.6, 0.0, 0.8)
		base = base.lerp(Color(1, 1, 1, 1), boost)
	return base

func _on_panel_slide_in_started() -> void:
	_populate_jobs()

func _on_panel_slide_out_finished() -> void:
	# Free child controls to keep memory usage low when hidden
	_job_load_generation += 1
	_clear_job_container()
	job_description.text = ""
