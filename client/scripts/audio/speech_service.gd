class_name SpeechService
extends Node

var active_stt_provider: SpeechToTextProvider
var active_tts_provider: TextToSpeechProvider

var stt_enabled: bool = true
var tts_enabled: bool = true
var last_stt_response: SpeechResponse
var last_tts_response: SpeechResponse

signal stt_completed(response: SpeechResponse)
signal tts_completed(response: SpeechResponse)

func _ready() -> void:
	add_to_group("speech_service")

	var env_stt_en: String = OS.get_environment("ECHO_STT_ENABLED").to_lower()
	if env_stt_en == "false" or env_stt_en == "0":
		stt_enabled = false

	var env_tts_en: String = OS.get_environment("ECHO_TTS_ENABLED").to_lower()
	if env_tts_en == "false" or env_tts_en == "0":
		tts_enabled = false

	_init_providers()

func _init_providers() -> void:
	var stt_name: String = OS.get_environment("ECHO_STT_PROVIDER").to_lower()
	match stt_name:
		"openai_compatible":
			active_stt_provider = OpenAICompatibleSTTProvider.new()
		"local":
			active_stt_provider = LocalSTTProvider.new()
		_:
			active_stt_provider = MockSTTProvider.new()

	var tts_name: String = OS.get_environment("ECHO_TTS_PROVIDER").to_lower()
	match tts_name:
		"openai_compatible":
			active_tts_provider = OpenAICompatibleTTSProvider.new()
		"local":
			active_tts_provider = LocalTTSProvider.new()
		_:
			active_tts_provider = MockTTSProvider.new()

func transcribe(buffer: AudioBuffer) -> SpeechResponse:
	if not stt_enabled or active_stt_provider == null:
		var err_res: SpeechResponse = SpeechResponse.new(false, "none", "")
		err_res.error_message = "STT service disabled"
		stt_completed.emit(err_res)
		return err_res

	var res: SpeechResponse = active_stt_provider.transcribe(buffer)
	last_stt_response = res
	stt_completed.emit(res)
	return res

func synthesize(text: String) -> SpeechResponse:
	if not tts_enabled or active_tts_provider == null:
		var err_res: SpeechResponse = SpeechResponse.new(false, "none", text)
		err_res.error_message = "TTS service disabled"
		tts_completed.emit(err_res)
		return err_res

	var res: SpeechResponse = active_tts_provider.synthesize(text)
	last_tts_response = res
	tts_completed.emit(res)
	return res

func get_stt_provider_name() -> String:
	return active_stt_provider.get_provider_name() if active_stt_provider else "none"

func get_tts_provider_name() -> String:
	return active_tts_provider.get_provider_name() if active_tts_provider else "none"
