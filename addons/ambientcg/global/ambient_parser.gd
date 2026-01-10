@tool extends Node

const ALLOWED_EXTENSIONS : PackedStringArray = ["png", "jpg"]

const TEMP_FILE_PATH := "user://temp_acg_tres.tres"

func api_info_to_version_string(json : Dictionary = AmbientAPI.api_information) -> String:
	# this could be cleaner but im not  gonna bother - cs
	var string = json.get("id", "") + " v" + json.get("meta", {}).get("version", "") + "\n" + json.get("data", {}).get("text", {}).get("description")
	return string


func asset_list_query(json : Dictionary) -> Dictionary:
	var data : Dictionary = json.get("data", {})
	var asset_list_query : Dictionary = data.get("asset_list_query", {})
	return asset_list_query


func get_parameter_from_key_and_type(key : String, type : String, json : Dictionary) -> Dictionary:
	var parameters = json.get("parameters", [])
	for parameter in parameters:
		if parameter.get(key, "") == type:
			return parameter
	return {}


func api_info_to_option_button(button : OptionButton, json : Dictionary = AmbientAPI.api_information) -> void:
	button.clear()
	
	var choices : Array = get_parameter_from_key_and_type("type", "select", asset_list_query(json)).get("choices", [])
	for choice : Dictionary in choices:
		button.add_item(str(choice.get("value", "")).capitalize())


func parse_search_query_data(json : Dictionary) -> Dictionary:
	var output : Dictionary = {}
	var data : Dictionary = json.get("data", {})
	var response_statistics : Dictionary = data.get("response_statistics", {})
	var next_query : Dictionary = data.get("next_query", {})
	var payload : Dictionary = next_query.get("payload", {})
	
	output["result_count_total"] = response_statistics.get("result_count_total", 0)
	
	var id : String = get_parameter_from_key_and_type("type", "text", asset_list_query(AmbientAPI.api_information)).get("id", "")
	var payload_str = "?%s=%s&offset=%d&type=%s" % [id, payload.get(id, ""), payload.get("offset", 0), payload.get("type", "any")]
	
	output["next_query_uri"] = str(next_query.get("uri", ""), payload_str)
	
	output["assets"] = parse_assets_from_search(json.get("assets", []))
	return output


func parse_assets_from_search(list : Array) -> Array:
	var output : Array = []
	for asset : Dictionary in list:
		var asset_output : Dictionary
		var id : String = asset.get("id", "")
		
		var data : Dictionary = asset.get("data", {})
		var implementation_list_query : Dictionary = data.get("implementation_list_query", {})
		
		var base_uri : String = implementation_list_query.get("uri", "")
		var parameters = implementation_list_query.get("parameters", [])
		
		var implementation_id_str : String
		var implementation_quality_str : String
		
		if not parameters.is_empty():
			var param_dict_a : Dictionary = parameters[0]
			implementation_id_str = param_dict_a.get("id", "")
			
			var param_dict_b : Dictionary = parameters[1]
			implementation_quality_str = param_dict_b.get("id", "")
			
			var choices = param_dict_b.get("choices", [])
			
			var implementation_uris : Dictionary
			
			if not choices.is_empty():
				for choice in choices:
					var full_uri = "%s?%s=%s&%s=%s" % [base_uri, implementation_id_str, id, implementation_quality_str, choice.get("value", "")]
					implementation_uris[choice.get("value", "")] = full_uri
			
			asset_output["implementation_uris"] = implementation_uris
		
		var preview_image_thumbnail : Dictionary = data.get("preview_image_thumbnail", {})
		var preview_image_thumbnail_uris : Dictionary = preview_image_thumbnail.get("uris", {})
		
		# WHY IS THIS A STRING IN THE API RESPONSE?? WHAT THE HELL??? - cs
		asset_output["thumbnail"] = preview_image_thumbnail_uris.get("128", "")
		
		var text = data.get("text", {})
		var title = text.get("title", "")
		
		asset_output["title"] = title
		
		output.append(asset_output)
	return output


func parse_asset_implementation(json : Dictionary) -> Array[Dictionary]:
	var output : Array[Dictionary] = []
	for implementation : Dictionary in json.get("implementations", []):
		var components = implementation.get("components", [])
		
		for component in components:
			var id : String = component.get("id", "")
			var data : Dictionary = component.get("data", {})
			
			var fetch_download : Dictionary = data.get("fetch.download", {})
			var unlock_query_id = fetch_download.get("unlock_query_id", null) # ignored in ambientcg
			var download_query : Dictionary = fetch_download.get("download_query", {})
			
			var uri : String = download_query.get("uri", "")
			
			var store : Dictionary = data.get("store", {})
			var local_file_path : String = store.get("local_file_path", "")
			
			var bytes : int = store.get("bytes", 0)
			
			var format : Dictionary = data.get("format", {})
			var extension : String = format.get("extension", "")
			var mediatype = format.get("mediatype", "")
			
			if not str(uri).is_empty():
				var implementation_output = {"id": id, "uri": uri, "file_size": bytes, "extension": extension, "local_file_name": local_file_path}
				output.append(implementation_output)
			
	return output

# this could be a lot more efficient but oh well - cslr
# in theory it could save the .tres file then auto populate the deps but it caused a missing dependency error when i tried it - cslr
func pull_tres_dependencies(zip_reader: ZIPReader, tres_file: String) -> Dictionary:
	var content: PackedByteArray = zip_reader.read_file(tres_file, false)
	AmbientFileHandler.save_buffer(TEMP_FILE_PATH, content)
	
	var dependencies: PackedStringArray = ResourceLoader.get_dependencies(TEMP_FILE_PATH)
	
	DirAccess.remove_absolute(TEMP_FILE_PATH)
	
	return {"tres_content": content,  "dependencies": dependencies}
