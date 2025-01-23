@tool
extends EditorPlugin

const UI = preload("res://addons/ambientcg/acg_ui.tscn")

var ui_instance

func _enter_tree():
	if not ProjectSettings.has_setting("ambientcg/download_path"):
		ProjectSettings.set_setting("ambientcg/download_path", "res://AmbientCG/Downloads")
	
	ui_instance = UI.instantiate()
	EditorInterface.get_editor_main_screen().add_child(ui_instance)
	ui_instance.plugin = self
	_make_visible(false)


func _exit_tree():
	if ui_instance:
		ui_instance.queue_free()


func _has_main_screen():
	return true


func _make_visible(visible):
	if ui_instance: 
		ui_instance.visible = visible


func _get_plugin_name():
	return "AmbientCG"


func _get_plugin_icon():
	return EditorInterface.get_editor_theme().get_icon("Node", "EditorIcons")
