class_name AIRequest
extends RefCounted

var request_id: String = ""
var provider: String = ""
var model: String = ""
var messages: Array[Dictionary] = []
var temperature: float = 0.0
var max_tokens: int = 100
var timestamp_started: float = 0.0
var timeout_seconds: float = 20.0

func _init(p_provider: String = "", p_model: String = "", p_messages: Array[Dictionary] = [], p_timeout: float = 20.0) -> void:
	request_id = "req_%d_%d" % [int(Time.get_ticks_msec()), randi() % 1000]
	provider = p_provider
	model = p_model
	messages = p_messages
	timestamp_started = Time.get_ticks_msec() / 1000.0
	timeout_seconds = p_timeout
