@tool class_name AmbientDownloadWindow extends Window

@onready var download_container: HBoxContainer = %DownloadContainer
@onready var material_icon: TextureRect = %MaterialIcon
@onready var download_progress: ProgressBar = %DownloadProgress
@onready var download_panel: Panel = %DownloadPanel
@onready var extract_panel: Panel = %ExtractPanel
@onready var extract_scroll: ScrollContainer = %ExtractScroll
@onready var extract_file_options: VBoxContainer = %ExtractFileOptions
@onready var extract_button: Button = %extract_button

@onready var img_size_width: SpinBox = %img_size_width
@onready var img_size_height: SpinBox = %img_size_height
@onready var enable_triplanar: CheckButton = %enable_triplanar
@onready var enable_resize: CheckButton = %enable_resize

var material_json : Dictionary
var implementations : Dictionary
var parsed_implementations : Array[Dictionary]

var last_used_file : String
var last_used_file_info : Dictionary

func pop_up(_material_json : Dictionary, icon : Texture2D = null) -> void:
	hide()
	force_native = true
	show()
	
	material_json = _material_json
	material_icon.texture = icon
	
	title = material_json.get("title", "") + " - AmbientCG.com"
	
	process_implementations()
	connect_signals()
	
	download_panel.show()
	extract_panel.hide()
	
	print(material_json)

func connect_signals() -> void:
	AmbientFileHander.file_downloaded.connect(check_downloaded_extension)
	
	extract_button.pressed.connect(extract_button_pressed)
	

func _process(delta: float) -> void:
	if AmbientAPI.download_progress.has(last_used_file):
		%DownloadProgress.value = AmbientAPI.download_progress.get(last_used_file, 0)
		%DownloadProgress.max_value = last_used_file_info.get("file_size", 0.0)
		

func _on_close_requested() -> void:
	if not AmbientAPI.download_progress.has(last_used_file):
		queue_free()


func process_implementations() -> void:
	implementations = material_json.get("implementation_uris", {})
	
	for implementation : String in implementations:
		var implementation_uri = implementations.get(implementation)
		fetch_implementation(implementation_uri)


func fetch_implementation(implementation_uri : String) -> void:
	var request = await AmbientAPI.http_request(implementation_uri)
	var result := AmbientAPI.parse_pba_json(request[3])
	
	parsed_implementations = AmbientParser.parse_asset_implementation(result)
	
	create_download_buttons(parsed_implementations)


func create_download_buttons(options : Array[Dictionary]) -> void:
	options.sort()
	for option : Dictionary in options:
		var extension : String = str(option.get("extension", "")).get_extension()
		if not download_container.has_node(extension):
			var carrier_scroll := ScrollContainer.new()
			var carrier_vbox := VBoxContainer.new()
			
			carrier_scroll.add_child(carrier_vbox)
			download_container.add_child(carrier_scroll)
			
			carrier_scroll.owner = download_container
			carrier_vbox.owner = carrier_scroll
			
			carrier_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			carrier_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
			
			carrier_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			carrier_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
			
			carrier_scroll.name = extension
			carrier_vbox.name = "vbox"
			
			var label = Label.new()
			label.text = extension.to_upper()
			
			carrier_vbox.add_child(label)
			
		
		if download_container.has_node(extension):
			var carrier : ScrollContainer = download_container.get_node(extension)
			var vbox : VBoxContainer = carrier.get_node("vbox")
			
			var button := Button.new()
			button.text = str(option.get("local_file_name", ""))
			button.name = button.text
			
			button.pressed.connect(download_button_pressed.bind(option))
			
			vbox.add_child(button)
			
			button.add_theme_font_size_override("font_size", 14)
			vbox.queue_sort()

var extraction_file_links : Dictionary[String, CheckBox]
var extraction_source_file : String

func prompt_user_for_extraction(source_file : String) -> void:
	download_panel.hide()
	extract_panel.show()
	
	extraction_file_links = {}
	
	# temporary zip reader
	var reader := ZIPReader.new()
	reader.open(source_file)
	extraction_source_file = source_file
	var files = reader.get_files()
	reader.close()
	
	for file in files:
		var button = CheckBox.new()
		button.text = file
		button.name = file
		extract_file_options.add_child(button)
		extraction_file_links[file] = button


func extract_button_pressed() -> void:
	var options_dict = {
	"img_size": Vector2(img_size_width.value, img_size_height.value), 
	"use_triplanar_uv": enable_triplanar.button_pressed,
	"use_custom_size": enable_resize.button_pressed
	}
	AmbientFileHander.extract_and_save(self, extraction_source_file, extraction_file_links, options_dict)


func download_button_pressed(data : Dictionary) -> void:
	AmbientFileHander.download_file_from_data(data, self)
	last_used_file = data.get("uri", "")
	last_used_file_info = data


func check_downloaded_extension(file : String) -> void:
	match file.get_extension():
		"zip", "usdz":
			prompt_user_for_extraction(file)
		_:
			_on_close_requested()
