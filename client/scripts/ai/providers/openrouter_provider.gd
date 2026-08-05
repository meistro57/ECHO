class_name OpenRouterProvider
extends AIProvider

var api_key: String = ""
var model_name: String = "deepseek/deepseek-v4-flash"
var base_url: String = "https://openrouter.ai/api/v1"
var site_url: String = "https://github.com/meistro57/ECHO"
var app_name: String = "ECHO"

func _init() -> void:
	api_key = OS.get_environment("OPENROUTER_API_KEY").strip_edges()
	
	var env_model: String = OS.get_environment("OPENROUTER_MODEL").strip_edges()
	if not env_model.is_empty():
		model_name = env_model

	var env_base: String = OS.get_environment("OPENROUTER_BASE_URL").strip_edges()
	if not env_base.is_empty():
		base_url = env_base.trim_suffix("/")

	var env_site: String = OS.get_environment("OPENROUTER_SITE_URL").strip_edges()
	if not env_site.is_empty():
		site_url = env_site

	var env_app: String = OS.get_environment("OPENROUTER_APP_NAME").strip_edges()
	if not env_app.is_empty():
		app_name = env_app

func get_provider_name() -> String:
	return "openrouter"

func is_configured() -> bool:
	return not api_key.is_empty() and not model_name.is_empty()

func get_model() -> String:
	return model_name

func get_endpoint_url() -> String:
	return base_url + "/chat/completions"

func build_headers() -> PackedStringArray:
	var headers: PackedStringArray = PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer " + api_key
	])
	if not site_url.is_empty():
		headers.append("HTTP-Referer: " + site_url)
	if not app_name.is_empty():
		headers.append("X-Title: " + app_name)
	return headers
