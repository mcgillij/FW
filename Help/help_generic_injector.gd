extends Control

class_name FW_HelpInjector

# Generic injector: provide a static API so callers can run injection without
# needing to instantiate or preload the script. Keep _ready() so this script
# still works when attached to a scene node.

static func inject_into_node(node: Node) -> void:
	# load the registry fresh (cheap) and run a static recursive injector
	var registry = preload("res://Help/help_style_registry.gd")
	_inject_in_node_static(node, registry)

func _ready() -> void:
	# Backwards-compatible: when attached to a Control, run the injector on self
	inject_into_node(self)

static func _inject_in_node_static(node: Node, registry) -> void:
	for child in node.get_children():
		if child is RichTextLabel:
			_apply_to_richtext_static(child, registry)
		elif child is Label:
			_apply_to_label_static(child, registry)
		# Recurse
		_inject_in_node_static(child, registry)

static func _apply_to_richtext_static(lbl: RichTextLabel, registry) -> void:
	var text: String = ""
	if lbl.text != "":
		text = String(lbl.text)
	else:
		text = String(lbl.bbcode_text)
	var found = registry.find_tokens_in_text(text)
	if found.size() == 0:
		return
	var mapping = {}
	for t in found:
		var _raw = registry.lookup(t)
		var resolved = registry.lookup_resolved(t)
		mapping[t] = resolved
	# call static injector on Colors so resolved Color objects and hex values work
	FW_Colors.inject_into_label(lbl, mapping)

static func _apply_to_label_static(lbl: Label, registry) -> void:
	# If the label contains any token as a substring, tint it using the
	# first resolved Color found. This makes plain Label nodes get colored
	# when they contain tokens inside a sentence.
	var text = String(lbl.text)
	if text == "":
		return
	var found = registry.find_tokens_in_text(text)
	if found.size() == 0:
		return
	for t in found:
		var resolved = registry.lookup_resolved(t)
		if resolved != null and resolved is Color:
			# Only fully tint the Label if the label text is essentially the token
			# (case-insensitive exact match). This avoids tinting whole sentences
			# that merely mention a token like "Bomb".
			var lbl_text_norm = String(lbl.text).strip_edges().to_lower()
			var token_norm = String(t).strip_edges().to_lower()
			if lbl_text_norm == token_norm:
				lbl.self_modulate = resolved
				return
	# If we reached here, the Label contained tokens but wasn't an exact match.
	# Instead of full-modulate, inject inline coloring into the Label's bbcode.
	# Build mapping of tokens -> resolved values for the found tokens and call
	# the plain-label injector.
	var mapping = {}
	for t2 in found:
		mapping[t2] = registry.lookup_resolved(t2)
	FW_Colors.inject_into_plain_label(lbl, mapping)
