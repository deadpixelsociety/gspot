@tool
extends EditorPlugin


func _enter_tree() -> void:
	add_custom_type("GSClient", "Node", preload("gsclient.gd"), preload("editor_icon.png"))


func _exit_tree() -> void:
	remove_custom_type("GSClient")
