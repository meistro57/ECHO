class_name TaskResult
extends RefCounted

var task_id: String = ""
var success: bool = false
var status: String = "PENDING" # PENDING, RUNNING, COMPLETED, FAILED, CANCELLED
var current_step: int = 0
var completed_steps: int = 0
var failed_step: int = -1
var error_code: String = ""
var message: String = ""
var time_started: float = 0.0
var time_completed: float = 0.0

func _init(p_task_id: String = "") -> void:
	task_id = p_task_id
	time_started = Time.get_ticks_msec() / 1000.0
