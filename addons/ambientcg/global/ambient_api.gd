@tool extends Node


const HOME_URL : String = "https://ambientcg.com/api/af/"

var USER_AGENT := ""

var api_information : Dictionary = {}

func update_user_agent() -> void:
	USER_AGENT = "VenitStudios AmbientCG Godot Plugin (Godot %s)" % str(Engine.get_version_info().major, ".", Engine.get_version_info().minor)


func http_request(url: String, custom_headers: PackedStringArray = PackedStringArray(), method: HTTPClient.Method = 0, request_data: String = ""):
	update_user_agent()
	if not url.is_empty():
		var http_request = HTTPRequest.new()
		add_child(http_request)
		custom_headers.append("User-Agent: %s" % USER_AGENT)
		http_request.request(url, custom_headers, method, request_data)
		var response = await http_request.request_completed
		remove_child(http_request)
		http_request.queue_free()
		return response
	return []


func http_request_raw(url: String, custom_headers: PackedStringArray = PackedStringArray(), method: HTTPClient.Method = 0, request_data: PackedByteArray = []):
	update_user_agent()
	if not url.is_empty():
		var http_request = HTTPRequest.new()
		add_child(http_request)
		custom_headers.append("User-Agent: %s" % USER_AGENT)
		http_request.request_raw(url, custom_headers, method, request_data)
		var response = await http_request.request_completed
		remove_child(http_request)
		http_request.queue_free()
		return response
	return []

var download_progress : Dictionary[String, int] = {}

func http_request_download(url: String, path : String, file_size : int) -> void:
	update_user_agent()
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.download_file = path
	http_request.request(url, ["User-Agent: %s" % USER_AGENT], HTTPClient.METHOD_GET, "")
	
	var bytes_left = file_size - http_request.get_downloaded_bytes()
	
	while bytes_left > 0:
		bytes_left = file_size - http_request.get_downloaded_bytes()
		download_progress[url] = http_request.get_downloaded_bytes()
		await get_tree().create_timer(0.1).timeout
	remove_child(http_request)
	download_progress.erase(url)
	http_request.queue_free()


func parse_pba_json(data : PackedByteArray) -> Dictionary:
	return JSON.parse_string(data.get_string_from_utf8())


func search_assets(query : String, type : String = "", override_uri : String = "") -> Dictionary:
	var asset_list_query = AmbientParser.asset_list_query(api_information)
	var search_uri = asset_list_query.get("uri", "")
	
	if not override_uri.is_empty():
		var request = await http_request(override_uri, ["User-Agent: %s" % USER_AGENT])
		var result := parse_pba_json(request[3])
		return result
	
	if not search_uri.is_empty():
		var id : String = AmbientParser.get_parameter_from_key_and_type("type", "text", AmbientParser.asset_list_query(AmbientAPI.api_information)).get("id")
		
		var final_uri = search_uri + "?%s=%s&type=%s" % [id, query.replacen(" ", ","), type]
		var request = await http_request(final_uri, ["User-Agent: %s" % USER_AGENT])
		
		var result := parse_pba_json(request[3])
		
		return result
	
	return {}


func api_init() -> Dictionary:
	var request_response = await http_request(HOME_URL + "init")
	match request_response[1]:
		200:
			var data = parse_pba_json(request_response[3])
			api_information = data
			return data
		404:
			return {}
	return {}


func api_implementation_list(implementation_uri : String) -> Dictionary:
	var request_response = await http_request(implementation_uri)
	match request_response[1]:
		200:
			var data = parse_pba_json(request_response[3])
			return data
		404:
			return {}
	return {}
