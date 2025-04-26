@tool
extends Control

const search_url = "https://ambientcg.com/hx/asset-list?id=&childrenOf=&variationsOf=&parentsOf=&q={keywords}&colorMode=&thumbnails=200&sort=popular"
const ACG_MATERIAL_WIDGET = preload("res://addons/ambientcg/acg_material_widget.tscn")
const DOWNLOAD_PANEL = preload("res://addons/ambientcg/download_panel.tscn")

var active_download_panel : Control

var plugin : EditorPlugin

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	visibility_changed.connect(self_visibility_changed)

func self_visibility_changed():
	if visible:
		await request_for_key_words()
	else:
		delete_all_items()

func delete_all_items():
	var grid: GridContainer = get_node("ScrollContainer/GridContainer")
	for c in grid.get_children():
		grid.remove_child(c)
		c.queue_free()
	if is_instance_valid(active_download_panel):
		active_download_panel.queue_free()
		active_download_panel = null

func search_submitted(new_text: String) -> void:
	print(new_text)
	request_for_key_words()

func request_for_key_words():
	delete_all_items()
	var HTTP = HTTPRequest.new()
	add_child(HTTP)
	# make initial request
	HTTP.request(search_url.replace("{keywords}", get_node("%Search").text), [], HTTPClient.METHOD_GET, "")
	var request_completion_data = await(HTTP.request_completed)
	var utf8_body = request_completion_data[3]
	remove_child(HTTP)
	HTTP.queue_free()

	var parsed_data : Dictionary = return_parsed_xml(utf8_body)
	create_widgets_from(parsed_data)

func create_widgets_from(parsed_data):
	for acg_material in parsed_data:
		if not visible: return
		create_widget(acg_material, parsed_data.get(acg_material), "https://ambientcg.com/view?id=%s" % acg_material)


func create_widget(widget_name, widget_icon_path, widget_page):
	if not visible: return
	var new_widget = ACG_MATERIAL_WIDGET.instantiate()
	var grid_container = get_node("ScrollContainer/GridContainer")
	grid_container.add_child(new_widget)

	var download = HTTPRequest.new()
	add_child(download)

	download.request_raw(widget_icon_path)
	var data = await download.request_completed
	var image = Image.new()
	var error = image.load_jpg_from_buffer(data[3])

	if error == OK:
		remove_child(download)
		download.queue_free()
		new_widget.get_node("TextureRect").texture = ImageTexture.create_from_image(image)
		new_widget.get_node("Label").text = widget_name
		new_widget.get_node("Button").pressed.connect(pop_up.bind(widget_page, new_widget))
	else:
		print("failed to load thumbnail, removing.")
		grid_container.remove_child(new_widget)
		new_widget.queue_free()

func pop_up(widget_page, widget):
	if is_instance_valid(active_download_panel) and not active_download_panel.downloading:
		remove_child(active_download_panel)
		active_download_panel.queue_free()
		active_download_panel = null

	if not is_instance_valid(active_download_panel):
		active_download_panel = DOWNLOAD_PANEL.instantiate()
		add_child(active_download_panel)
		active_download_panel.url = widget_page

		active_download_panel.position = get_rect().size / 2 - Vector2(active_download_panel.size / 2)
		active_download_panel.get_node("Icon").texture = widget.get_node("TextureRect").texture
		active_download_panel.get_node("Title").text = widget.get_node("Label").text
		active_download_panel.download_finished.connect(download_finished)

func download_finished():
	if plugin and Engine.is_editor_hint():
		plugin.get_editor_interface().get_resource_filesystem().scan_sources()

func return_parsed_xml(xml : PackedByteArray) -> Dictionary:
	var parser = XMLParser.new()
	parser.open_buffer(xml)
	var final_dict = {}
	while parser.read() != ERR_FILE_EOF:
		var id = 0
		if parser.get_node_type() == XMLParser.NODE_ELEMENT:
			var node_name = parser.get_node_name()
			var attributes_dict = {}
			for idx in range(parser.get_attribute_count()):
				attributes_dict[parser.get_attribute_name(idx)] = parser.get_attribute_value(idx)
				if attributes_dict.has("src") and attributes_dict.has("alt"):
					final_dict[str(attributes_dict.alt).replace("Asset: ", "")] = attributes_dict.src
	return final_dict
