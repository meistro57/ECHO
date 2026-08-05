class_name MockSTTProvider
extends SpeechToTextProvider

var mock_transcript_override: String = ""

func get_provider_name() -> String:
	return "mock_stt"

func is_configured() -> bool:
	return true

func transcribe(buffer: AudioBuffer) -> SpeechResponse:
	var res: SpeechResponse = SpeechResponse.new(true, get_provider_name(), "")
	res.latency_ms = 45.0
	
	if not mock_transcript_override.is_empty():
		res.transcript = mock_transcript_override
	else:
		if buffer == null or buffer.is_empty():
			res.success = false
			res.error_message = "Empty audio buffer"
		else:
			res.transcript = "bring me the red box"
			
	return res
