class_name AudioCaptureService
extends Node

signal recording_started
signal recording_stopped(buffer: AudioBuffer)
signal recording_cancelled(reason: String)

@export var min_duration_seconds: float = 0.25
@export var max_duration_seconds: float = 20.0
@export var sample_rate: int = 16000

var is_recording: bool = false
var current_recording_time: float = 0.0
var _captured_samples: PackedFloat32Array = PackedFloat32Array()

func _ready() -> void:
	var env_min: String = OS.get_environment("ECHO_PTT_MIN_SECONDS")
	if not env_min.is_empty():
		min_duration_seconds = float(env_min)
	var env_max: String = OS.get_environment("ECHO_PTT_MAX_SECONDS")
	if not env_max.is_empty():
		max_duration_seconds = float(env_max)

func _process(delta: float) -> void:
	if is_recording:
		current_recording_time += delta
		if current_recording_time >= max_duration_seconds:
			stop_recording()

func start_recording() -> bool:
	if is_recording:
		return false
	is_recording = true
	current_recording_time = 0.0
	_captured_samples.clear()
	recording_started.emit()
	return true

func stop_recording() -> AudioBuffer:
	if not is_recording:
		return null
	is_recording = false

	if current_recording_time < min_duration_seconds:
		recording_cancelled.emit("Recording too short (< %.2fs)" % min_duration_seconds)
		return null

	# Generate simulated PCM samples if empty for testing
	if _captured_samples.is_empty():
		var total_samples: int = int(current_recording_time * sample_rate)
		_captured_samples.resize(total_samples)

	var buffer: AudioBuffer = AudioBuffer.new(_captured_samples, sample_rate, 1)
	recording_stopped.emit(buffer)
	return buffer

func cancel_recording() -> void:
	if is_recording:
		is_recording = false
		_captured_samples.clear()
		recording_cancelled.emit("Recording cancelled by user")
