class_name HUD
extends Control

@onready var phase_label: Label = $MarginContainer/Panel/MarginContainer/VBoxContainer/PhaseLabel
@onready var state_label: Label = $MarginContainer/Panel/MarginContainer/VBoxContainer/APCStateLabel

var apc_node: APCController

func _ready() -> void:
	if phase_label:
		phase_label.text = "Phase 2: APC Locomotion & Following"

func _process(_delta: float) -> void:
	if apc_node == null:
		var apcs = get_tree().get_nodes_in_group("apc")
		if apcs.size() > 0 and apcs[0] is APCController:
			apc_node = apcs[0] as APCController

	if apc_node and state_label:
		state_label.text = "APC State: " + apc_node.get_state_string()
