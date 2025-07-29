@tool
extends EditorPlugin
class_name AmbientCGPlugin
const UI = preload("res://addons/ambientcg/acg_ui.tscn")

var ui_instance
var editor_theme : Theme

func _enter_tree():
	if not Engine.is_editor_hint():
		return
	if not ProjectSettings.has_setting("ambientcg/extract_path"):
		ProjectSettings.set_setting("ambientcg/extract_path", "res://AmbientCG/Downloads")
	if not ProjectSettings.has_setting("ambientcg/material_file_directory"):
		ProjectSettings.set_setting("ambientcg/material_file_directory", "res://AmbientCG/Materials")
	if not ProjectSettings.has_setting("ambientcg/environment_file_directory"):
		ProjectSettings.set_setting("ambientcg/environment_file_directory", "res://AmbientCG/Environments")
	editor_theme = EditorInterface.get_editor_theme()
	ui_instance = UI.instantiate()
	EditorInterface.get_editor_main_screen().add_child(ui_instance)
	ui_instance.plugin = self
	ui_instance.active = true
	_make_visible(false)


func _exit_tree():
	if ui_instance:
		EditorInterface.get_editor_main_screen().remove_child(ui_instance)
		ui_instance.queue_free()


func _has_main_screen():
	return true


func _make_visible(visible):
	if ui_instance:
		ui_instance.visible = visible


func _get_plugin_name():
	return "AmbientCG"


func _get_plugin_icon():
	return EditorInterface.get_editor_theme().get_icon("MaterialPreviewSphere", "EditorIcons")
