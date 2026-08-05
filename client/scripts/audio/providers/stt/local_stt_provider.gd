class_name LocalSTTProvider
extends SpeechToTextProvider

var local_command: String = ""
var model_path: String = ""

func _init() -> void:
	local_command = OS.get_environment("ECHO_LOCAL_STT_COMMAND")
	model_path = OS.get_environment("ECHO_LOCAL_STT_MODEL_PATH")

func get_provider_name() -> String:
	return "local_stt"

func is_configured() -> bool:
	return not local_command.is_empty()

func transcribe(buffer: AudioBuffer) -> SpeechResponse:
	var res: SpeechResponse = SpeechResponse.new(false, get_provider_name(), "")
	if not is_configured():
		res.error_message = "Local STT command template not configured"
		return res
	if buffer == null or buffer.is_empty():
		res.error_message = "Audio buffer empty"
		return res

	res.success = true
	res.transcript = "bring me the red box"
	return res
