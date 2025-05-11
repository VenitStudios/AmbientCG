@tool class_name TMakerBG extends ColorRect

## Background Color Node from TMaker Scenes
## https://github.com/VenitStudios/GDTMaker/blob/main/addons/gdtmaker/TmakerBG.gd

@export var multiplier : float = 1.0 : set = set_color_with_mult

func _enter_tree() -> void:
	set_color_with_mult(multiplier)

func set_color_with_mult(mult_val):
	multiplier = mult_val
	var settings = EditorInterface.get_editor_settings()
	self.color = settings.get_setting("interface/theme/base_color") * multiplier
