class_name OpenAICompatibleTTSProvider
extends TextToSpeechProvider

var base_url: String = ""
var api_key: String = ""
var voice_name: String = "alloy"

func _init() -> void:
	base_url = OS.get_environment("ECHO_TTS_BASE_URL")
	if base_url.is_empty():
		base_url = "https://api.openai.com/v1"
	api_key = OS.get_environment("ECHO_TTS_API_KEY")
	var v: String = OS.get_environment("ECHO_TTS_VOICE")
	if not v.is_empty():
		voice_name = v

func get_provider_name() -> String:
	return "openai_compatible_tts"

func is_configured() -> bool:
	return not api_key.is_empty()

func synthesize(text: String) -> SpeechResponse:
	var res: SpeechResponse = SpeechResponse.new(false, get_provider_name(), text)
	if not is_configured():
		res.error_message = "TTS API key not configured"
		return res
	res.success = true
	return res
