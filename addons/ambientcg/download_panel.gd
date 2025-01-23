@tool
extends Control

var url : String

var downloading : bool = false

signal download_finished

func _ready() -> void:
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
	extract(path)
	
	downloading = false
	
	_on_cancel_pressed()


func extract(zip_file : String):
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
	
	create_material(extract_path)
	
	DirAccess.remove_absolute(zip_file)

func create_material(directory):
	print("Creating Material")
	var new_material = StandardMaterial3D.new()
	var files = DirAccess.get_files_at(directory)
	for file in files:
		file = directory + "/" + file
		if file.contains("Color"): 
			new_material.albedo_texture = ImageTexture.create_from_image(Image.load_from_file(file))
		
		if file.contains("Displacement"): 
			new_material.heightmap_enabled = true
			new_material.heightmap_texture = ImageTexture.create_from_image(Image.load_from_file(file))
		
		if file.contains("NormalGL"):
			new_material.normal_enabled = true
			new_material.normal_texture = ImageTexture.create_from_image(Image.load_from_file(file))
		
		if file.contains("Roughness"):
			new_material.roughness_texture = ImageTexture.create_from_image(Image.load_from_file(file))
	
	if new_material.albedo_texture:
		ResourceSaver.save(new_material, directory + "/material.tres")
		print("Saved Material", directory + "/material.tres")
	

func _on_cancel_pressed() -> void: if not downloading: self.queue_free()
func _on_acg_link_pressed() -> void: OS.shell_open(url)
