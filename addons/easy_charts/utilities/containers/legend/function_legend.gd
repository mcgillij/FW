extends VBoxContainer
class_name FW_FunctionLegend

@onready var f_label_scn: PackedScene = preload("res://addons/easy_charts/utilities/containers/legend/function_label.tscn")

var chart_properties: FW_ChartProperties

func _ready() -> void:
    pass

func clear() -> void:
    for label in get_children():
        label.queue_free()

func add_function(function: FW_Function) -> void:
    var f_label: FW_FunctionLabel = f_label_scn.instantiate()
    add_child(f_label)
    f_label.init_label(function)

func add_label(type: int, color: Color, marker: int, name: String) -> void:
    var f_label: FW_FunctionLabel = f_label_scn.instantiate()
    add_child(f_label)
    f_label.init_clabel(type, color, marker, name)
