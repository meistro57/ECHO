class_name MemoryQuery
extends RefCounted

var memory_types: Array[String] = []
var entities: Array[String] = []
var event_type: String = ""
var session_id: String = ""
var time_range_min: float = 0.0
var time_range_max: float = 0.0
var max_results: int = 5
var min_importance: float = 0.0
var query_text: String = ""

func _init(p_max_results: int = 5) -> void:
	max_results = max(1, p_max_results)
