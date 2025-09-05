@tool class_name AmbientBrowserWidget extends Button

const DOWNLOAD_WINDOW = preload("res://addons/ambientcg/gui/download_window/download_window.tscn")

var material_json : Dictionary

func update() -> void:
	hide()
	await ready
	tooltip_text = material_json.get("title", "")
	
	var texture_buffer = await AmbientAPI.http_request_raw(material_json.get("thumbnail", ""))
	var thumbnail_image := Image.new()
	thumbnail_image.load_png_from_buffer(texture_buffer[3])
	%Thumbnail.texture = ImageTexture.create_from_image(thumbnail_image)
	show()

func _pressed() -> void:
	var new_window = DOWNLOAD_WINDOW.instantiate()
	add_child(new_window)
	new_window.pop_up(material_json, %Thumbnail.texture)
