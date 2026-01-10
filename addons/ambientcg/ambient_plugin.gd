@tool
extends EditorPlugin
class_name AmbientCGPlugin

const UI = preload("res://addons/ambientcg/gui/ambient_ui/ambient_ui.tscn")
const PLUGIN_TAB_ICON = preload("res://addons/ambientcg/plugin_assets/icon/icon_white.png")

var ui_instance : AmbientUI


func _enter_tree():
	if not Engine.is_editor_hint():
		return
	
	_make_visible(false)
	add_default_settings()
	
	
	add_autoload_singleton("AmbientAPI", "res://addons/ambientcg/global/ambient_api.gd")
	add_autoload_singleton("AmbientParser", "res://addons/ambientcg/global/ambient_parser.gd")
	add_autoload_singleton("AmbientFileHandler", "res://addons/ambientcg/global/ambient_file_handler.gd")
	add_autoload_singleton("AmbientMaterialMaker", "res://addons/ambientcg/global/ambient_material_maker.gd")


func _exit_tree():
	if is_instance_valid(ui_instance):
		EditorInterface.get_editor_main_screen().remove_child(ui_instance)
		ui_instance.queue_free()
	
	remove_autoload_singleton("AmbientAPI")
	remove_autoload_singleton("AmbientParser")
	remove_autoload_singleton("AmbientFileHandler")
	remove_autoload_singleton("AmbientMaterialMaker")

func _has_main_screen():
	return true


func _make_visible(visible):
	if visible:
		ui_instance = UI.instantiate()
		EditorInterface.get_editor_main_screen().add_child(ui_instance)
		ui_instance.open()
	else:
		if is_instance_valid(ui_instance):
			EditorInterface.get_editor_main_screen().remove_child(ui_instance)
			ui_instance.queue_free()


func _get_plugin_name():
	return "AmbientCG"


func _get_plugin_icon():
	return PLUGIN_TAB_ICON


func add_default_settings():
	if not ProjectSettings.has_setting("ambientcg/extract_path"):
		ProjectSettings.set_setting("ambientcg/extract_path", "res://AmbientCG/Extracted")
	
	if not ProjectSettings.has_setting("ambientcg/material_file_directory"):
		ProjectSettings.set_setting("ambientcg/material_file_directory", "res://AmbientCG/Materials")
	
	if not ProjectSettings.has_setting("ambientcg/environment_file_directory"):
		ProjectSettings.set_setting("ambientcg/environment_file_directory", "res://AmbientCG/Environments")
	
