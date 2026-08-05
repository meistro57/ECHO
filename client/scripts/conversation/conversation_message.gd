class_name ConversationMessage
extends RefCounted

var sender: String = "human" # "human" or "apc"
var text: String = ""
var timestamp: float = 0.0
var turn_id: String = ""

func _init(p_sender: String = "human", p_text: String = "", p_turn_id: String = "") -> void:
	sender = p_sender
	text = p_text
	turn_id = p_turn_id
	timestamp = Time.get_ticks_msec() / 1000.0
