@tool
extends Control

const search_url = "https://ambientcg.com/hx/asset-list?q={keywords}&colorMode=&thumbnails=200&sort=popular"
const ACG_MATERIAL_WIDGET = preload("res://addons/ambientcg/acg_material_widget.tscn")
const DOWNLOAD_WINDOW = preload("res://addons/ambientcg/download_panel.tscn")

@onready var scroll_container: ScrollContainer = $ScrollContainer
@onready var load_progress: ProgressBar = $LoadProgress

var v_scroll_bar : VScrollBar

var active_download_window : Window
var active_download_panel : Control

var plugin : AmbientCGPlugin

var search_offset = 0

var active = false
var awaiting_response = false
var est_count = 0
var cur_count = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	visibility_changed.connect(self_visibility_changed)
# ew gross process function in an editor plugin
func _process(delta: float) -> void:
	if (not visible) or (not active): return
	if v_scroll_bar == null: v_scroll_bar = scroll_container.get_v_scroll_bar()
	else:
		
		var current_y = v_scroll_bar.size.y + v_scroll_bar.value
		var should_load_more = current_y > v_scroll_bar.max_value * 0.8
		if should_load_more and not awaiting_response:
			search_offset += 200
			request_for_key_words(false)

func self_visibility_changed():
	if visible and active:
		search_offset = 0
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
	## reset former counters for fresh search results
	search_offset = 0
	est_count = 0
	cur_count = 0

	request_for_key_words()

func request_for_key_words(delete_before : bool = true):
	get_node("%CenterContainer").hide()
	load_progress.show()
	load_progress.value = 0
	if delete_before: delete_all_items()
	var HTTP = HTTPRequest.new()
	add_child(HTTP)
	var keywords = get_node("%Search").text.replacen(" ", ",")
	var final_url = search_url.replace("{keywords}", keywords)
	if search_offset > 0:
		final_url += "&offset=%s" % search_offset
	# make initial request
	HTTP.request(final_url, [], HTTPClient.METHOD_GET, "")
	awaiting_response = true
	var request_completion_data = await(HTTP.request_completed)
	var utf8_body = request_completion_data[3]
	remove_child(HTTP)
	HTTP.queue_free()
	awaiting_response = false
	var parsed_data : Dictionary = return_parsed_xml(utf8_body)
	if !parsed_data.is_empty():
		create_widgets_from(parsed_data)
		load_progress.hide()
	else:
		get_node("%CenterContainer").show()
		get_node("%CenterContainer/NoResults").text = 'NO RESULTS FOR %s FOUND' % str(get_node("%Search").text).to_upper()
		load_progress.hide()

func create_widgets_from(parsed_data):
	for acg_material in parsed_data:
		if (not visible): return
		if (str(acg_material).containsn("substance")):
			push_warning("(ambientcg) possible substance painter file detected, ignoring.")
			return
		create_widget(acg_material, parsed_data.get(acg_material), "https://ambientcg.com/view?id=%s" % acg_material)
		est_count += 1


func create_widget(widget_name, widget_icon_path, widget_page):
	if not visible: return
	var new_widget = ACG_MATERIAL_WIDGET.instantiate()
	var grid_container : GridContainer = get_node("ScrollContainer/GridContainer")
	grid_container.columns = int((size.x - 40 + 8) / 200.0)
	var download = HTTPRequest.new()
	add_child(download)
	
	download.request_raw(widget_icon_path)
	var data = await download.request_completed
	var image = Image.new()
	var error = image.load_jpg_from_buffer(data[3])
	
	if error == OK and is_instance_valid(grid_container):
		remove_child(download)
		download.queue_free()
		grid_container.add_child(new_widget)
		new_widget.get_node("%TextureIcon").texture = ImageTexture.create_from_image(image)
		new_widget.get_node("%Label").text = widget_name
		new_widget.get_node("%Button").pressed.connect(pop_up.bind(widget_page, new_widget))
		
		await grid_container.tree_entered
		cur_count += 1
	else:
		print("failed to load thumbnail, removing.")
		est_count -= 1
		grid_container.remove_child(new_widget)
		new_widget.queue_free()
	
	load_progress.max_value = est_count
	load_progress.value = cur_count
	if cur_count == est_count:
		load_progress.hide()

func pop_up(widget_page, widget):
	if is_instance_valid(active_download_panel) and not active_download_panel.downloading:
		remove_child(active_download_panel)
		active_download_panel.queue_free()
		active_download_window.queue_free()
		active_download_panel = null
		active_download_window = null

	if not is_instance_valid(active_download_panel):
		active_download_window = DOWNLOAD_WINDOW.instantiate()
		add_child(active_download_window)
		active_download_panel = active_download_window.get_node("DownloadWidget")
		
		active_download_panel.url = widget_page
		active_download_panel.get_information()
		active_download_panel.position = get_rect().size / 2 - Vector2(active_download_panel.size / 2)
		active_download_panel.get_node("%Icon").texture = widget.get_node("%TextureIcon").texture
		active_download_window.title = "Download " + widget.get_node("%Label").text
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


func _on_self_resized() -> void:
	var grid_container : GridContainer = get_node("ScrollContainer/GridContainer")
	grid_container.columns = int((size.x - 40 + 8) / 200.0)
