extends Node2D

class_name FW_Piece

const COLOR_MAPPING := {
	"red": Color("ff5555"),
	"green": Color("50fa7b"),
	"blue": Color("6272a4"),
	"orange": Color("ffb86c"),
	"pink": Color("ff79c6"),
	"Color": Color("dad8dd")
}

@export var player_sinker_tex: Texture2D
@export var monster_sinker_tex: Texture2D

enum OWNER { PLAYER, MONSTER }
var sinker_owner: OWNER
var sinker_type: FW_Ability

@export var color: String
@export var row_texture: Texture2D
@export var col_texture: Texture2D
@export var adjacent_texture: Texture2D
@export var color_bomb_texture: Texture2D

var shader_values = FW_Utils.ShaderValues.new()
var is_row_bomb: bool = false
var is_col_bomb: bool = false
var is_adjacent_bomb: bool = false
var is_color_bomb: bool = false

var matched: bool = false
var glow_shader = load("res://Shaders/glow.gdshader")

func _process(delta: float) -> void:
	if is_adjacent_bomb or is_color_bomb or is_row_bomb or is_col_bomb:
		shader_values.muck_with_shader_values(delta, $Sprite2D)

func move(target: Vector2) -> void:
	var tween = get_tree().create_tween()
	tween.tween_property(self, "position", target, .4).from(position).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func do_bitten() -> void:
	var tween = get_tree().create_tween()
	tween.tween_property(self, "modulate", Color(Color.BLUE_VIOLET, 7), .4).set_trans(Tween.TRANS_SINE)
	tween.play()

func do_clawed() -> void:
	var tween = get_tree().create_tween()
	tween.tween_property(self, "modulate", Color(Color.YELLOW_GREEN, 7), .4).set_trans(Tween.TRANS_SINE)
	tween.play()

func do_borked() -> void:
	var tween = get_tree().create_tween()
	tween.tween_property(self, "modulate", Color(Color.DARK_CYAN, 7), .4).set_trans(Tween.TRANS_SINE)
	tween.play()

func do_chewed() -> void:
	var tween = get_tree().create_tween()
	tween.tween_property(self, "modulate", Color(Color.FOREST_GREEN, 7), .4).set_trans(Tween.TRANS_SINE)
	tween.play()

func do_dashed() -> void:
	var tween = get_tree().create_tween()
	tween.tween_property(self, "modulate", Color(Color.GREEN_YELLOW, 7), .4).set_trans(Tween.TRANS_SINE)
	tween.play()

func do_thrashed() -> void:
	var tween = get_tree().create_tween()
	tween.tween_property(self, "modulate", Color(Color.ORANGE, 7), .4).set_trans(Tween.TRANS_SINE)
	tween.play()

func dim() -> void:
	var sprite = get_node("Sprite2D")
	sprite.modulate = Color(1, 1, 1, .5)

func attach_shader(sprite: Sprite2D) -> void:
	sprite.material = ShaderMaterial.new()
	sprite.material.shader = glow_shader
	sprite.get_material().set_shader_parameter("glow_color", COLOR_MAPPING[color])

func make_col_bomb() -> void:
	is_col_bomb = true
	var sprite = get_node("Sprite2D")
	sprite.texture = col_texture
	sprite.modulate = Color(1,1,1,1)
	attach_shader(sprite)

func make_row_bomb() -> void:
	is_row_bomb = true
	var sprite = get_node("Sprite2D")
	sprite.texture = row_texture
	sprite.modulate = Color(1,1,1,1)
	attach_shader(sprite)

func make_adjacent_bomb() -> void:
	is_adjacent_bomb = true
	var sprite = get_node("Sprite2D")
	sprite.texture = adjacent_texture
	sprite.modulate = Color(1,1,1,1)
	attach_shader(sprite)

func make_color_bomb() -> void:
	is_color_bomb = true
	var sprite = get_node("Sprite2D")
	sprite.texture = color_bomb_texture
	sprite.modulate = Color(1,1,1,1)
	color = "Color"
	attach_shader(sprite)

func make_into_sinker(ability: FW_Ability) -> void:
	sinker_type = ability
	if GDM.game_manager.turn_manager.is_player_turn():
		sinker_owner = OWNER.PLAYER
		$Sprite2D.texture = player_sinker_tex
		$Sprite2D.self_modulate = ability.player_color
	else:
		sinker_owner = OWNER.MONSTER
		$Sprite2D.texture = monster_sinker_tex
		$Sprite2D.self_modulate = ability.enemy_color

	# Debug: announce sinker creation and attached ability metadata
	var dbg_msg = "SINKER: created owner=%s ability=%s" % [str(sinker_owner), str(ability.name if ability else "<none>")]
	if ability:
		dbg_msg += " sinker_effects=%s" % str(ability.sinker_effects)
		var ve = ability.get("visual_effect") if ability.has_method("get") else null
		dbg_msg += " visual_effect=%s" % str(ve if ve else "<none>")
	if EventBus.has_signal("debug_log"):
		FW_Debug.debug_log([dbg_msg])
	else:
		FW_Debug.debug_log([dbg_msg])
