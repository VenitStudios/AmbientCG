@tool
extends Control

var url : String
var id : String
var tags : PackedStringArray
var download_options : Dictionary[String, Dictionary]

var downloading : bool = false

const ALLOWED_FILE_TYPES = ["zip", "exr"]

signal download_finished
@onready var override_material_save_path = ProjectSettings.get_setting("ambientcg/material_file_directory", "res://AmbientCG/Materials")

func _ready() -> void:
	if not ProjectSettings.has_setting("ambientcg/material_file_directory"):
		ProjectSettings.set_setting("ambientcg/material_file_directory","")

func get_information():
	id = url.replace("https://ambientcg.com/view?id=", "")
	var info_url = "https://ambientCG.com/api/v2/full_json?id=%s&include=tagData,downloadData" % id
	
	var HTTP = HTTPRequest.new()
	add_child(HTTP)
	# make initial request
	HTTP.request(info_url, [], HTTPClient.METHOD_GET, "")
	var request_completion_data = await(HTTP.request_completed)
	var utf8_body = request_completion_data[3].get_string_from_utf8()
	remove_child(HTTP)
	HTTP.queue_free()
	var json : Dictionary = JSON.parse_string(utf8_body)
	if !json.is_empty():
		parse_download_options(json)

func parse_download_options(download_json : Dictionary) -> void:
	get_node_or_null("%GettingDownloads").text = "Fetching Downloads...\nThis May Take a Moment"
	get_node_or_null("%GettingDownloads").show()
	if download_json.is_empty(): 
		get_node_or_null("%GettingDownloads").text = "No Downloads Available\nCheck Website For Options."
		return
	download_options = {}
	if (download_json.has("foundAssets")):
		var foundAssets : Array = download_json.foundAssets
		for asset : Dictionary in foundAssets:
			if asset.get("assetId", "") == id:
				if asset.has("tags"): tags = PackedStringArray(asset.get("tags", []))
				if asset.has("downloadFolders"):
					var downloadFolders : Dictionary = asset.get("downloadFolders", {}).get("default", {})
					if downloadFolders.has("downloadFiletypeCategories"):
						var categories = downloadFolders.get("downloadFiletypeCategories")
						
						for file_type in ALLOWED_FILE_TYPES:
							if categories.has(file_type):
								var download_categories : Dictionary = categories.get(file_type, {})
								if download_categories.has("downloads"):
									var downloads : Array = download_categories.get("downloads", [])
									for download : Dictionary in downloads:
										if download.has("downloadLink"):
											var downloadLink = download.get("downloadLink", "")
											var attribute = download.get("attribute", "")
											var filetype = download.get("filetype", "")
											
											download_options[attribute] = {"url": downloadLink, "filetype": filetype}
											
											create_download_buttons()
							# this is a glorious stack of else statements
								else: get_node_or_null("%GettingDownloads").text = "No Downloads Found\nCheck Website For Options."
							else: get_node_or_null("%GettingDownloads").text = "No Downloads Found\nCheck Website For Options."
					else: get_node_or_null("%GettingDownloads").text = "No Downloads Found\nCheck Website For Options."
				else: get_node_or_null("%GettingDownloads").text = "No Downloads Found\nCheck Website For Options."
			else: get_node_or_null("%GettingDownloads").text = "No Downloads Found\nCheck Website For Options."
	else: get_node_or_null("%GettingDownloads").text = "No Downloads Found\nCheck Website For Options."

func create_download_buttons():
	%GettingDownloads.hide()
	for option : String in download_options.keys():
		if not %DownloadOptions.has_node(option):
			var url = download_options.get(option, {}).get("url", "")
			var extension = download_options.get(option, {}).get("filetype", "")
			var button = Button.new()
			%DownloadOptions.add_child(button)
			
			button.name = option
			button.text = option + " (.%s)" % str(extension).to_upper()
			
			var is_sky = tags.has("sky") or tags.has("environment")
			if not is_sky:
				button.pressed.connect(download_material.bind(url, option, extension))
			if is_sky:
				button.pressed.connect(download_environment.bind(url, option, extension))
			

func download_environment(download_url : String, version : String, extension : String):
	var file_name = id
	var download_size = 0
	
	%DownloadVisualizer.show()
	%DownloadLabel.text = "Fetching File Header"
	var header_getter = HTTPRequest.new()
	add_child(header_getter)
	header_getter.request(download_url, [], HTTPClient.METHOD_HEAD)
	var header = (await header_getter.request_completed)
	if header[1] != 200:
		%DownloadLabel.text = "Failed To Find File"
		await get_tree().create_timer(2).timeout
		downloading = false
		_on_cancel_pressed()
		return
	
	for header_val : String in header[2]: 
		if header_val.containsn("content-length:"): 
			download_size = header_val.replacen("content-length: ", "").to_int()
	
	header_getter.queue_free()
	var directory = ProjectSettings.get_setting("ambientcg/environment_file_directory", "res://AmbientCG/Environments")
	if not DirAccess.dir_exists_absolute(directory): DirAccess.make_dir_recursive_absolute(directory)
	var path = directory.trim_suffix("/") + "/ambient_cg_%s%s_download.%s" % [file_name, version.to_upper(), extension]
	
	downloading = true
	%DownloadLabel.text = "Downloading"
	
	%FileDownloadLink.text = "url: " + download_url
	%FileDownloadPath.text = "to: " + path
	var download = HTTPRequest.new()
	add_child(download)
	
	download.download_file = path
	download.request_raw(download_url)
	
	var bytes_left = download_size - download.get_downloaded_bytes()
	%DownloadProgress.max_value = download_size
	
	var last_byte_count = 0
	var attempt_count = 0
	
	while bytes_left > 0:
		%DownloadLabel.text = "Downloading %s/%sMB" % [float(download.get_downloaded_bytes() / 1000000), float(download_size / 1000000)]
		
		bytes_left = download_size - download.get_downloaded_bytes()
		%DownloadProgress.value = download.get_downloaded_bytes()
		await get_tree().create_timer(0.1).timeout
		if last_byte_count == bytes_left:
			attempt_count += 1
			if attempt_count > 20:
				await download_failed("Download Hung at %sMB" % (last_byte_count / 1000000))
				download.queue_free()
				downloading = false
				break
		else:
			attempt_count = 0
			last_byte_count = bytes_left
		
		
	
	download.queue_free()
	downloading = false
	
	await get_tree().create_timer(1).timeout
	if %PopulateResourceCheck.button_pressed:
		await make_sky_environment(path)
	downloading = false
	_on_cancel_pressed()

func download_material(download_url : String, version : String, extension : String):
	var file_name = id
	var download_size = 0
	
	%DownloadVisualizer.show()
	%DownloadLabel.text = "Fetching File Header"
	var header_getter = HTTPRequest.new()
	add_child(header_getter)
	header_getter.request(download_url, [], HTTPClient.METHOD_HEAD)
	var header = (await header_getter.request_completed)
	if header[1] != 200:
		%DownloadLabel.text = "Failed To Find File"
		await get_tree().create_timer(2).timeout
		downloading = false
		_on_cancel_pressed()
		return
	
	for header_val : String in header[2]: 
		if header_val.containsn("content-length:"): 
			download_size = header_val.replacen("content-length: ", "").to_int()
	
	header_getter.queue_free()
	var path = "user://ambient_cg_%s%s_download.%s" % [file_name, version.to_upper(), extension]
	
	downloading = true
	%DownloadLabel.text = "Downloading"
	
	%FileDownloadLink.text = "url: " + download_url
	%FileDownloadPath.text = "to: " + path
	var download = HTTPRequest.new()
	add_child(download)
	
	download.download_file = path
	download.request_raw(download_url)
	
	var bytes_left = download_size - download.get_downloaded_bytes()
	%DownloadProgress.max_value = download_size
	
	var last_byte_count = 0
	var attempt_count = 0
	
	while bytes_left > 0: 
		bytes_left = download_size - download.get_downloaded_bytes()
		%DownloadProgress.value = download.get_downloaded_bytes()
		await get_tree().create_timer(0.1).timeout
		if last_byte_count == bytes_left:
			attempt_count += 1
			if attempt_count > 20:
				await download_failed("Download Hung at %sMB" % (last_byte_count / 1000000))
				download.queue_free()
				downloading = false
				break
		else:
			attempt_count = 0
			last_byte_count = bytes_left
		
		%DownloadLabel.text = "Downloading %s/%sMB" % [float(download.get_downloaded_bytes() / 1000000), float(download_size / 1000000)]
		
	
	download.queue_free()
	
	await extract(path, file_name)
	downloading = false
	
	_on_cancel_pressed()

func download_failed(why : String = ""):
	%DownloadLabel.text = "Download Failed " + why
	%FileDownloadLink.text = ""
	%FileDownloadPath.text = ""
	await get_tree().create_timer(2.0).timeout
	_on_cancel_pressed()


func extract(zip_file: String, file_name: String):
	var ZR = ZIPReader.new()
	ZR.open(zip_file)
	# this is bad code, i dont know how to regex - cslr
	var extract_path = ProjectSettings.get_setting("ambientcg/extract_path", "res://AmbientCG/Downloads") + "/" + zip_file.get_file().trim_suffix("." + zip_file.get_extension()).replace("ambient_cg_", "").replace("_download", "")
	if not DirAccess.dir_exists_absolute(extract_path): DirAccess.make_dir_recursive_absolute(extract_path)
	
	%DownloadLabel.text = "Extracting"
	%FileDownloadLink.text = "from: " + zip_file
	%FileDownloadPath.text = "to: " + extract_path
	await get_tree().create_timer(0.25).timeout
	
	for file in ZR.get_files():
		var data = ZR.read_file(file)
		var path = extract_path + "/" + file

		var filesys = FileAccess.open(path, FileAccess.WRITE)
		filesys.store_buffer(data)
		filesys.close()

	prints("Extracted", zip_file)
	download_finished.emit()
	if %PopulateResourceCheck.button_pressed:
		await create_material(extract_path, file_name)
	downloading = false
	_on_cancel_pressed()
	DirAccess.remove_absolute(zip_file)

func await_for_reimport():
	var editor_fs: EditorFileSystem = EditorInterface.get_resource_filesystem()
	while not is_equal_approx(1.0, editor_fs.get_scanning_progress()) and editor_fs.is_scanning():
		var progress = editor_fs.get_scanning_progress()
		print("Waiting for initial file import progress: ", progress)
		await get_tree().create_timer(1.0).timeout

func create_material(directory, file_name: String):
	print("Creating Material")
	
	var material_path = ProjectSettings.get_setting("ambientcg/material_file_directory", "res://AmbientCG/Materials")
	if not DirAccess.dir_exists_absolute(material_path): DirAccess.make_dir_recursive_absolute(material_path)
	
	%DownloadLabel.text = "Creating Material"
	%FileDownloadLink.text = "from: " + directory
	%FileDownloadPath.text = "to: " + material_path + file_name
	await get_tree().create_timer(0.25).timeout
	
	var editor_fs: EditorFileSystem = EditorInterface.get_resource_filesystem()
	var new_material = StandardMaterial3D.new()
	# note: dir files is relative!
	var dir_files = DirAccess.get_files_at(directory)
	
	# a valid file is a png or jpg, other files are ignored!
	var valid_files: Array[String] = []
	# ensure files are only png
	for file in dir_files:
		var ext = file.get_extension()
		if ext == "jpg" or ext == "png":
			valid_files.push_back(directory.path_join(file))

	# Algorithm to force file to be loaded synchronously
	# Forces editor to finish scanning the new imported png files, then we can just load() them!
	for file in valid_files:
		editor_fs.update_file(file)
	await get_tree().process_frame
	await await_for_reimport()

	new_material.uv1_triplanar = %TriplanarCheck.button_pressed

	var albedo_filename = ""
	for file in valid_files:
		if file.containsn("Color"):
			new_material.albedo_texture = load(file)
			if not override_material_save_path.is_empty():
				var new_path: String = override_material_save_path.path_join(file_name) +"."+ file.get_extension()
				DirAccess.copy_absolute(file, new_path)
				editor_fs.update_file(new_path)
				await await_for_reimport()
			albedo_filename = file.get_basename()
		if file.containsn("Displacement"):
			# disable heightmap with triplanar texture to avoid godot warning
			new_material.heightmap_enabled = not new_material.uv1_triplanar
			new_material.heightmap_texture = load(file)

		if file.containsn("NormalDX"):
			DirAccess.remove_absolute(file)

		if file.containsn("NormalGL"):
			new_material.normal_enabled = true
			new_material.normal_texture = load(file)

		if file.containsn("Roughness"):
			new_material.roughness_texture = load(file)
		if file.containsn("AmbientOcclusion"):
			new_material.ao_texture = load(file)
	
	
	if new_material.albedo_texture:
		var save_path = ""
		if albedo_filename.is_empty():
			save_path = directory + "/fallback-name.tres"
		elif not override_material_save_path.is_empty():
			save_path = override_material_save_path.path_join(file_name) + ".material"
		else:
			save_path = directory.path_join(file_name) + ".material"
		var uid: int = ResourceUID.create_id()
		ResourceSaver.save(new_material, save_path)
		ResourceUID.set_id(uid, save_path)

		ResourceSaver.get_resource_id_for_path(save_path, true)
		print("Saved Material ", save_path)

		editor_fs.update_file(save_path)
		editor_fs.scan_sources()
		editor_fs.scan()

func make_sky_environment(source_file: String):
	var directory = ProjectSettings.get_setting("ambientcg/environment_file_directory", "res://AmbientCG/Environments")
	if not DirAccess.dir_exists_absolute(directory): DirAccess.make_dir_recursive_absolute(directory)
	var editor_fs: EditorFileSystem = EditorInterface.get_resource_filesystem()
	var new_material = StandardMaterial3D.new()
	# note: dir files is relative!
	var dir_files = DirAccess.get_files_at(directory)
	
	%DownloadLabel.text = "Creating Environment"
	%FileDownloadLink.text = "from: " + directory + "/" + source_file
	%FileDownloadPath.text = ""
	
	var valid_files: Array[String] = []
	# ensure files are only exr
	for file in dir_files:
		var ext = file.get_extension()
		if ext == "exr":
			valid_files.push_back(directory.path_join(file))
	
	# Algorithm to force file to be loaded synchronously
	# Forces editor to finish scanning the new imported files, then we can just load() them!
	for file in valid_files:
		editor_fs.update_file(file)
	await get_tree().process_frame
	await await_for_reimport()
	
	for file in valid_files:
		editor_fs.reimport_files([file])
		var env = Environment.new()
		var sky = Sky.new()
		var sky_mat = PanoramaSkyMaterial.new()
		
		sky.sky_material = sky_mat
		sky_mat.panorama = ResourceLoader.load(file, "Texture2D")
		
		env.background_mode = Environment.BG_SKY
		
		var env_save_path : String = file.trim_suffix(file.get_extension()) + "_env.res"
		var sky_save_path : String = file.trim_suffix(file.get_extension()) + "_sky.res"
		
		var sky_uid: int = ResourceUID.create_id()
		ResourceSaver.save(sky, sky_save_path)
		ResourceUID.set_id(sky_uid, sky_save_path)
		
		ResourceSaver.get_resource_id_for_path(sky_save_path, true)
		
		editor_fs.update_file(sky_save_path)
		
		env.set_sky(load(sky_save_path))
		
		var env_uid: int = ResourceUID.create_id()
		ResourceSaver.save(env, env_save_path)
		ResourceUID.set_id(env_uid, env_save_path)
		
		ResourceSaver.get_resource_id_for_path(env_save_path, true)
		
		editor_fs.update_file(env_save_path)
	
	editor_fs.scan_sources()
	editor_fs.scan()
	
	downloading = false
	_on_cancel_pressed()

func _on_cancel_pressed() -> void: 
	if not downloading: 
		get_parent().queue_free()
func _on_acg_link_pressed() -> void: OS.shell_open(url)
