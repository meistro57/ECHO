class_name LocalTTSProvider
extends TextToSpeechProvider

var local_command: String = ""

func _init() -> void:
	local_command = OS.get_environment("ECHO_LOCAL_TTS_COMMAND")

func get_provider_name() -> String:
	return "local_tts"

func is_configured() -> bool:
	return not local_command.is_empty()

func synthesize(text: String) -> SpeechResponse:
	var res: SpeechResponse = SpeechResponse.new(false, get_provider_name(), text)
	if not is_configured():
		res.error_message = "Local TTS command template not configured"
		return res
	res.success = true
	return res
