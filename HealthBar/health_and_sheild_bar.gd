extends Control

@export var is_right_facing: bool = false

# === ANIMATION TIMING CONFIGURATION ===
# Unified bar animation timings
@export_group("Bar Animation Timing")
@export var main_bar_time: float = 0.4
@export var main_bar_delay: float = 0.0
@export var damage_bar_time: float = 0.5
@export var damage_bar_delay: float = 0.5

# Critical hit faster animations
@export_group("Critical Hit Timing")
@export var crit_main_time: float = 0.2
@export var crit_damage_time: float = 0.4

# Healing animations (preview then animate)
@export_group("Healing Timing")
@export var heal_preview_to_main_delay: float = 0.5
@export var heal_main_bar_time: float = 0.5

# Label juice animation
@export_group("Label Effects")
@export var label_juice_time: float = 0.2

# State correction timing
@export_group("State Correction")
@export var correction_check_delay: float = 0.1
@export var desync_tolerance_percent: float = 0.1

@onready var shield_bar: ProgressBar = %ShieldBar
@onready var health_bar: ProgressBar = %HealthBar
@onready var shield_damage_bar: ProgressBar = %ShieldDamageBar
@onready var health_damage_bar: ProgressBar = %HealthDamageBar
@onready var shield_value: RichTextLabel = %shield_value
@onready var health_value: RichTextLabel = %health_value

var max_health: float = 100.0
var max_shield: float = 100.0
var current_health: float = 50.0
var current_shield: float = 50.0

# Adaptive shield system
var shield_adaptive_max: float = 100.0
var shield_display_mode: String = "normal"

# Tween management to prevent conflicts
var active_health_main_tween: Tween
var active_health_damage_tween: Tween
var active_shield_main_tween: Tween
var active_shield_damage_tween: Tween

# Critical hit state tracking
var is_critical_hit_mode: bool = false
# Track whether the bar visuals have been initialized to real values
var _initialized: bool = false

func juice_label(label: RichTextLabel, color: Color) -> void:
	var label_tween = get_tree().create_tween()
	label_tween.tween_property(label, "modulate", color, label_juice_time).set_trans(Tween.TRANS_SINE)
	label_tween.tween_property(label, "modulate", Color.WHITE, label_juice_time).set_trans(Tween.TRANS_SINE)

func _ready() -> void:
	if is_right_facing:
		shield_bar.pivot_offset = shield_bar.size / 2
		shield_bar.rotation_degrees = -180
		health_bar.pivot_offset = health_bar.size / 2
		health_bar.rotation_degrees = -180
		shield_damage_bar.pivot_offset = shield_damage_bar.size / 2
		shield_damage_bar.rotation_degrees = -180
		health_damage_bar.pivot_offset = health_damage_bar.size / 2
		health_damage_bar.rotation_degrees = -180

	# Initialize bars
	set_default_values()

	# Apply shaders
	apply_health_shader()
	apply_shield_shader()

func _correct_final_state() -> void:
	# Ensure the visual bars match the actual state values
	var health_percentage: float = (current_health / max_health) * 100.0 if max_health > 0 else 0.0
	var shield_display_value = current_shield
	if shield_display_mode == "compressed":
		shield_display_value = 100 + (current_shield - 100) * (200.0 / (shield_adaptive_max - 100))
		shield_display_value = min(shield_display_value, 300)
	var shield_percentage: float = (shield_display_value / 300.0) * 100.0

	# Only correct if there's a significant difference (avoid tiny floating point issues)
	if abs(health_bar.value - health_percentage) > desync_tolerance_percent:
		health_bar.value = health_percentage
		health_damage_bar.value = health_percentage

	if abs(shield_bar.value - shield_percentage) > desync_tolerance_percent:
		shield_bar.value = shield_percentage
		shield_damage_bar.value = shield_percentage

	# Ensure labels are correct
	update_labels()

func set_default_values() -> void:
	health_bar.min_value = 0
	health_bar.max_value = 100
	health_bar.value = (current_health / max_health) * 100

	health_damage_bar.min_value = 0
	health_damage_bar.max_value = 100
	health_damage_bar.value = (current_health / max_health) * 100

	shield_bar.min_value = 0
	shield_bar.max_value = 100
	shield_damage_bar.min_value = 0
	shield_damage_bar.max_value = 100

	update_shield_display()
	update_labels()

func apply_health_shader() -> void:
	var health_shader = load("res://HealthBar/health_bubble_shader.gdshader")
	if health_shader:
		var shader_material = ShaderMaterial.new()
		shader_material.shader = health_shader
		shader_material.set_shader_parameter("bubble_density", 1.635)
		shader_material.set_shader_parameter("bubble_speed", 0.73)
		shader_material.set_shader_parameter("bubble_size", 0.10)
		shader_material.set_shader_parameter("bubble_color", Color(0.518, 0.653, 0.342, 0.8))
		shader_material.set_shader_parameter("time_scale", -0.55)
		health_bar.material = shader_material

func apply_shield_shader() -> void:
	var shield_shader = load("res://HealthBar/shield_energy_shader.gdshader")
	if shield_shader:
		var shield_shader_material = ShaderMaterial.new()
		shield_shader_material.shader = shield_shader
		shield_shader_material.set_shader_parameter("energy_intensity", 0.5)
		shield_shader_material.set_shader_parameter("pulse_speed", 1.5)
		shield_shader_material.set_shader_parameter("time_scale", 0.6)
		shield_bar.material = shield_shader_material

func update_shield_display() -> void:
	# Adaptive shield bar scaling
	if current_shield <= 100:
		shield_display_mode = "normal"
		shield_adaptive_max = 100.0
	elif current_shield <= 300:
		shield_display_mode = "normal"
		shield_adaptive_max = max(shield_adaptive_max, current_shield * 1.2)
	else:
		shield_display_mode = "compressed"
		shield_adaptive_max = max(shield_adaptive_max, current_shield * 1.5)

	# Update shield bar value based on display mode
	var display_value = current_shield
	if shield_display_mode == "compressed":
		display_value = 100 + (current_shield - 100) * (200.0 / (shield_adaptive_max - 100))
		display_value = min(display_value, 300)

	var shield_percentage = (display_value / 300.0) * 100
	shield_bar.value = shield_percentage
	shield_damage_bar.value = shield_percentage

func update_labels() -> void:
	health_value.text = "[color=red]❤️[/color] " + str(int(current_health)) + "/" + str(int(max_health))

	if current_shield >= 1000:
		shield_value.text = "[color=blue]🛡️[/color] " + str(int(current_shield / 100) * 100) + "+"
	elif current_shield >= 500:
		shield_value.text = "[color=blue]🛡️[/color] " + str(int(current_shield))
	elif current_shield <= 0:
		shield_value.text = ""
	else:
		shield_value.text = "[color=blue]🛡️[/color] " + str(int(current_shield))

func _on_tween_finished(bar: ProgressBar) -> void:
	# When a tween finishes, nullify its tracker
	if bar == health_bar: active_health_main_tween = null
	elif bar == health_damage_bar: active_health_damage_tween = null
	elif bar == shield_bar: active_shield_main_tween = null
	elif bar == shield_damage_bar: active_shield_damage_tween = null

	# If all tweens are done, run the final state correction
	if not active_health_main_tween and not active_health_damage_tween and \
	   not active_shield_main_tween and not active_shield_damage_tween:
		_correct_final_state()

func _do_bar_tween(bar: ProgressBar, value: float, length: float, delay: float, bar_type: String) -> void:

	var target_value: float
	if bar_type == "health":
		target_value = (value / max_health) * 100.0 if max_health > 0 else 0.0
	elif bar_type == "shield":
		var display_value = value
		if shield_display_mode == "compressed":
			display_value = 100 + (value - 100) * (200.0 / (shield_adaptive_max - 100))
			display_value = min(display_value, 300)
		target_value = (display_value / 300.0) * 100.0

	var tween = get_tree().create_tween()

	# Kill and manage active tweens
	if bar == health_bar:
		if active_health_main_tween: active_health_main_tween.kill()
		active_health_main_tween = tween
	elif bar == health_damage_bar:
		if active_health_damage_tween: active_health_damage_tween.kill()
		active_health_damage_tween = tween
	elif bar == shield_bar:
		if active_shield_main_tween: active_shield_main_tween.kill()
		active_shield_main_tween = tween
	elif bar == shield_damage_bar:
		if active_shield_damage_tween: active_shield_damage_tween.kill()
		active_shield_damage_tween = tween

	tween.tween_property(bar, "value", target_value, length).set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	tween.finished.connect(_on_tween_finished.bind(bar))

func set_health(new_health: float) -> void:
	# Route to atomic apply_state so heal/damage behave consistently
	apply_state(max_health, new_health, max_shield, current_shield)

func set_shield(new_shield: float) -> void:
	# Route to atomic apply_state so heal/damage behave consistently
	apply_state(max_health, current_health, max_shield, new_shield)

func apply_normal_damage(damage_health: float, damage_shield: float) -> void:
	apply_state(max_health, current_health - damage_health, max_shield, current_shield - damage_shield)

func apply_critical_hit(damage_health: float, damage_shield: float) -> void:
	# Enable critical hit mode for faster animations
	is_critical_hit_mode = true
	apply_state(max_health, current_health - damage_health, max_shield, current_shield - damage_shield)
	# Reset critical hit mode
	is_critical_hit_mode = false

func apply_healing(heal_amount: float, shield_gain: float) -> void:
	apply_state(max_health, current_health + heal_amount, max_shield, current_shield + shield_gain)

func kill_active_tweens() -> void:
	# Kill any existing tweens to prevent conflicts
	if active_health_main_tween:
		active_health_main_tween.kill()
		active_health_main_tween = null
	if active_health_damage_tween:
		active_health_damage_tween.kill()
		active_health_damage_tween = null
	if active_shield_main_tween:
		active_shield_main_tween.kill()
		active_shield_main_tween = null
	if active_shield_damage_tween:
		active_shield_damage_tween.kill()
		active_shield_damage_tween = null

func set_max_health(new_max: float) -> void:
	max_health = new_max
	current_health = min(current_health, max_health)
	# Immediately update bars
	_correct_final_state()

func set_max_shield(new_max: float) -> void:
	max_shield = new_max
	current_shield = min(current_shield, max_shield)
	# Immediately update bars
	_correct_final_state()

func force_immediate_correction() -> void:
	# Immediately kill all tweens and set correct values
	kill_active_tweens()
	_correct_final_state()

func get_display_state() -> Dictionary:
	# Return current display state for debugging
	return {
		"actual_health": current_health,
		"actual_max_health": max_health,
		"actual_shield": current_shield,
		"display_health_bar": health_bar.value,
		"display_health_damage_bar": health_damage_bar.value,
		"display_shield_bar": shield_bar.value,
		"display_shield_damage_bar": shield_damage_bar.value,
		"health_percentage_should_be": (current_health / max_health) * 100.0 if max_health > 0 else 0.0
	}

func _update_bar_visuals(bar_type: String, old_value: float, new_value: float, max_val: float) -> void:
	var main_bar: ProgressBar
	var damage_bar: ProgressBar
	var label: RichTextLabel
	var value_color: Color

	if bar_type == "health":
		main_bar = health_bar
		damage_bar = health_damage_bar
		label = health_value
	else: # shield
		main_bar = shield_bar
		damage_bar = shield_damage_bar
		label = shield_value

	if new_value < old_value: # Damage
		var main_time = crit_main_time if is_critical_hit_mode else main_bar_time
		var damage_time = crit_damage_time if is_critical_hit_mode else damage_bar_time

		_do_bar_tween(main_bar, new_value, main_time, main_bar_delay, bar_type)
		_do_bar_tween(damage_bar, new_value, damage_time, damage_bar_delay, bar_type)
		value_color = Color.RED
	else: # Gain / Heal
		var preview_pct: float
		if bar_type == "health":
			preview_pct = (new_value / max_val) * 100.0 if max_val > 0 else 0.0
		else: # shield
			var display_value = new_value
			if shield_display_mode == "compressed":
				display_value = 100 + (new_value - 100) * (200.0 / (shield_adaptive_max - 100))
				display_value = min(display_value, 300)
			preview_pct = (display_value / 300.0) * 100.0

		damage_bar.value = preview_pct
		_do_bar_tween(main_bar, new_value, heal_main_bar_time, heal_preview_to_main_delay, bar_type)
		value_color = Color.GREEN

	if label:
		juice_label(label, value_color)

func apply_state(new_max_health: float, new_current_health: float, new_max_shield: float, new_current_shield: float) -> void:
	# Atomically update max/current values
	var old_health_val = current_health
	max_health = new_max_health
	current_health = clamp(new_current_health, 0, max_health)

	var old_shield_val = current_shield
	max_shield = new_max_shield
	current_shield = max(0, new_current_shield)

	# Update adaptive shield max
	if current_shield > shield_adaptive_max:
		shield_adaptive_max = max(shield_adaptive_max, current_shield * 1.2)

	# If this is the first time we're being given real values, set visuals
	# immediately (no delayed damage tweens). This prevents the damage
	# bars from briefly showing editor-default values while the delayed
	# damage animation plays during initialization.
	if not _initialized:
		# Stop any tweens and set values directly to the correct percentages
		kill_active_tweens()
		# Health
		var health_percentage: float = (current_health / max_health) * 100.0 if max_health > 0 else 0.0
		health_bar.value = health_percentage
		health_damage_bar.value = health_percentage
		# Shield
		update_shield_display()
		# Mark initialized so subsequent calls animate normally
		_initialized = true
		# Ensure labels are correct and return early
		update_labels()
		return

	if current_health != old_health_val:
		_update_bar_visuals("health", old_health_val, current_health, max_health)

	if current_shield != old_shield_val:
		_update_bar_visuals("shield", old_shield_val, current_shield, max_shield)

	# Update labels after visual updates
	update_labels()
