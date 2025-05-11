@tool class_name DownloadWindow extends Window

func _on_close_requested() -> void: 
	if has_node("DownloadWidget"):
		if get_node("DownloadWidget").downloading:
			return
	queue_free()

func _process(delta: float) -> void:
	for c in get_children():
		c.position = Vector2.ZERO
