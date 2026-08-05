class_name DeepSeekProvider
extends AIProvider

var api_key: String = ""
var model_name: String = "deepseek-v4-flash"
var base_url: String = "https://api.deepseek.com"

func _init() -> void:
	api_key = OS.get_environment("DEEPSEEK_API_KEY").strip_edges()

	var env_model: String = OS.get_environment("DEEPSEEK_MODEL").strip_edges()
	if not env_model.is_empty():
		model_name = env_model

	var env_base: String = OS.get_environment("DEEPSEEK_BASE_URL").strip_edges()
	if not env_base.is_empty():
		base_url = env_base.trim_suffix("/")

func get_provider_name() -> String:
	return "deepseek"

func is_configured() -> bool:
	return not api_key.is_empty() and not model_name.is_empty()

func get_model() -> String:
	return model_name

func get_endpoint_url() -> String:
	return base_url + "/chat/completions"

func build_headers() -> PackedStringArray:
	return PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer " + api_key
	])
