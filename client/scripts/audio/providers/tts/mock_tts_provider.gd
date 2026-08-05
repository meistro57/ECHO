class_name MockTTSProvider
extends TextToSpeechProvider

func get_provider_name() -> String:
	return "mock_tts"

func is_configured() -> bool:
	return true

func synthesize(text: String) -> SpeechResponse:
	var res: SpeechResponse = SpeechResponse.new(true, get_provider_name(), text)
	res.latency_ms = 30.0
	return res
