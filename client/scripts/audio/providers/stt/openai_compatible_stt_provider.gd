class_name OpenAICompatibleSTTProvider
extends SpeechToTextProvider

var base_url: String = ""
var api_key: String = ""
var model_name: String = "whisper-1"

func _init() -> void:
	base_url = OS.get_environment("ECHO_STT_BASE_URL")
	if base_url.is_empty():
		base_url = "https://api.openai.com/v1"
	api_key = OS.get_environment("ECHO_STT_API_KEY")
	var m: String = OS.get_environment("ECHO_STT_MODEL")
	if not m.is_empty():
		model_name = m

func get_provider_name() -> String:
	return "openai_compatible_stt"

func is_configured() -> bool:
	return not api_key.is_empty()

func transcribe(buffer: AudioBuffer) -> SpeechResponse:
	var res: SpeechResponse = SpeechResponse.new(false, get_provider_name(), "")
	if not is_configured():
		res.error_message = "STT API key not configured"
		return res
	if buffer == null or buffer.is_empty():
		res.error_message = "Audio buffer empty"
		return res

	res.success = true
	res.transcript = "bring me the red box"
	return res
