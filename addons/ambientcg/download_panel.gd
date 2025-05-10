@tool
extends Control

var url : String

var downloading : bool = false

signal download_finished
@onready var override_material_save_path = ProjectSettings.get_setting("ambientcg/material_file_directory","")

func _ready() -> void:
	if not ProjectSettings.has_setting("ambientcg/material_file_directory"):
		ProjectSettings.set_setting("ambientcg/material_file_directory","")
	for c in $DownloadOptions.get_children():
		if c is Button:
			c.pressed.connect(download.bind(c))

func download(version):
	downloading = true
	var file_name = url.replace("https://ambientcg.com/view?id=", "")
	prints("Downloading", file_name, "This may take awhile for file formats >1k")
	var download_url = "https://ambientcg.com/get?file=%s_%s.zip" % [file_name,version.name.to_upper()]
	var download = HTTPRequest.new()
	add_child(download)
	var path = "user://ambient_cg_%s%sdownload.zip" % [file_name, version.name.to_upper()]
	download.download_file = path
	download.request_raw(download_url)
	var data : PackedByteArray = await download.request_completed
	download.queue_free()
	await extract(path, file_name)

	downloading = false

	_on_cancel_pressed()


func extract(zip_file: String, file_name: String):
	prints("Extracting", zip_file)
	var ZR = ZIPReader.new()
	ZR.open(zip_file)

	# this is bad code, i dont know how to regex
	var extract_path = ProjectSettings.get_setting("ambientcg/download_path") + "/" + zip_file.get_file().trim_suffix("." + zip_file.get_extension()).replace("ambient_cg_", "").replace("_download", "")
	if not DirAccess.dir_exists_absolute(extract_path): DirAccess.make_dir_recursive_absolute(extract_path)

	for file in ZR.get_files():
		var data = ZR.read_file(file)
		var path = extract_path + "/" + file

		var filesys = FileAccess.open(path, FileAccess.WRITE)
		filesys.store_buffer(data)
		filesys.close()

	prints("Extracted", zip_file)
	download_finished.emit()

	await create_material(extract_path, file_name)

	DirAccess.remove_absolute(zip_file)

func await_for_reimport():
	var editor_fs: EditorFileSystem = EditorInterface.get_resource_filesystem()
	while not is_equal_approx(1.0, editor_fs.get_scanning_progress()) and editor_fs.is_scanning():
		var progress = editor_fs.get_scanning_progress()
		print("Waiting for initial file import progress: ", progress)
		await get_tree().create_timer(1.0).timeout

func create_material(directory, file_name: String):
	print("Creating Material")
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

	var albedo_filename = ""
	for file in valid_files:
		if file.contains("Color"):
			new_material.albedo_texture = load(file)
			if not override_material_save_path.is_empty():
				var new_path: String = override_material_save_path.path_join(file_name) +"."+ file.get_extension()
				DirAccess.copy_absolute(file, new_path)
				editor_fs.update_file(new_path)
				await await_for_reimport()
			albedo_filename = file.get_basename()
		if file.contains("Displacement"):
			new_material.heightmap_enabled = true
			new_material.heightmap_texture = load(file)

		if file.contains("NormalGL"):
			new_material.normal_enabled = true
			new_material.normal_texture = load(file)

		if file.contains("Roughness"):
			new_material.roughness_texture = load(file)
		if file.contains("AmbientOcclusion"):
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

		EditorInterface.get_resource_filesystem().update_file(save_path)
		EditorInterface.get_resource_filesystem().scan_sources()
		EditorInterface.get_resource_filesystem().scan()


func _on_cancel_pressed() -> void: if not downloading: self.queue_free()
func _on_acg_link_pressed() -> void: OS.shell_open(url)
