@tool extends Node

signal file_downloaded (file : String)

func download_file_from_data(file_information : Dictionary, source_window : Window) -> void:
	# using a hard coded path here because i didn't like having multiple pop-ups in the chain - cslr
	# uncomment out the await if you want the file dialog
	var path: String = "user://" + file_information.get("local_file_name", "") #await open_file_dialog_for_path(file_information.get("local_file_name", ""), file_information.get("extension", ""))
	
	var text = "File will be Downloaded to %s and is Approx. %sMiB.\nDownload?" % [path, snappedf(float(file_information.get("file_size", 0)) / 1049000.0, 0.01)]
	
	await confirm_file_path(path, text)
	
	source_window.grab_focus()
	
	await AmbientAPI.http_request_download(file_information.get("uri", ""), path, file_information.get("file_size", 0))
	file_downloaded.emit(path)


func extract_and_save(window : Window, source_file : String, files_selected : Dictionary[String, CheckBox], options : Dictionary = {}) -> void:
	var file_sys := EditorInterface.get_resource_filesystem()
	var reader := ZIPReader.new()
	reader.open(source_file)
	var files = reader.get_files()
	
	var extraction_path : String = await open_directory_dialog_for_path("Select path to Extract to")
	
	var saved_files : PackedStringArray
	
	for file in files:
		if files_selected.has(file) and (files_selected.get(file, CheckBox.new()) as CheckBox).button_pressed:
			var file_data : PackedByteArray = reader.read_file(file)
			
			var new_file_path = extraction_path.trim_suffix("/") + "/%s" % file.get_file()
			var fs := FileAccess.open(new_file_path, FileAccess.WRITE)
			
			if fs.is_open():
				fs.store_buffer(file_data)
				fs.close()
				file_sys.update_file(new_file_path)
				saved_files.append(new_file_path)
				if ["jpg", "jpeg", "png"].has(new_file_path.get_extension()):
					if options.get("use_custom_size", false):
						var scaled_image = Image.load_from_file(new_file_path)
						
						if scaled_image and not scaled_image.is_empty():
							var new_size = options.get("img_size", scaled_image.get_size())
							if not new_size == Vector2(scaled_image.get_size()):
								
								scaled_image.resize(new_size.x, new_size.y,Image.INTERPOLATE_BILINEAR)
								
								match new_file_path.get_extension():
									"jpg", "jpeg":
										scaled_image.save_jpg(new_file_path)
									"png":
										scaled_image.save_png(new_file_path)
					
					file_sys.update_file(new_file_path)
	
	file_sys.scan()
	file_sys.scan_sources()
	reader.close()
	window.queue_free()
	
	await file_sys.resources_reimported
	
	# delete file after use to avoid clutter
	DirAccess.remove_absolute(source_file)
	
	if options.get("enable_packing", false):
		var mat = AmbientMaterialMaker.make_orm_material(saved_files, options)
		ResourceSaver.save(mat, extraction_path.trim_suffix("/") + "/%s_orm.material" % source_file.get_file().get_basename() )
	else:
		var mat = AmbientMaterialMaker.make_standard_material(saved_files, options)
		ResourceSaver.save(mat, extraction_path.trim_suffix("/") + "/%s_standard.material" % source_file.get_file().get_basename() )


func confirm_file_path(path : String, dialog_text : String) -> void:
	var confirmation_dialog = ConfirmationDialog.new()
	add_child(confirmation_dialog)
	confirmation_dialog.hide()
	confirmation_dialog.exclusive = false
	confirmation_dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_SCREEN_WITH_MOUSE_FOCUS
	confirmation_dialog.title = "Confirm File Path"
	confirmation_dialog.dialog_text = dialog_text
	
	confirmation_dialog.show()
	
	await confirmation_dialog.confirmed


func open_file_dialog_for_path(file_name : String, filtered_extension : String) -> String:
	var dialog := FileDialog.new()
	add_child(dialog)
	dialog.current_file = file_name
	dialog.filters = ["*%s" % filtered_extension]
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_SCREEN_WITH_MOUSE_FOCUS
	dialog.show()
	return await dialog.file_selected


func open_directory_dialog_for_path(title : String) -> String:
	var dialog := FileDialog.new()
	add_child(dialog)
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	dialog.title = title
	dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_SCREEN_WITH_MOUSE_FOCUS
	dialog.show()
	dialog.current_dir = ProjectSettings.get_setting("ambientcg/extract_path")
	return await dialog.dir_selected


func save_buffer(path: String, buffer: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	
	if file.is_open():
		file.store_buffer(buffer)
		file.close()


func check_dirs() -> void:
	var extract_path: String = ProjectSettings.get_setting("ambientcg/extract_path", "res://AmbientCG/Extracted")
	var material_file_directory: String = ProjectSettings.get_setting("ambientcg/material_file_directory", "res://AmbientCG/Materials")
	var environment_file_directory: String = ProjectSettings.get_setting("ambientcg/environment_file_directory", "res://AmbientCG/Environments")
	
	for i in [extract_path, material_file_directory, environment_file_directory]:
		if not DirAccess.dir_exists_absolute(i):
			DirAccess.make_dir_recursive_absolute(i)
