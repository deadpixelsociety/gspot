class_name GSExtension
extends RefCounted


func get_extension_name() -> String:
	return "new-extension"


func get_extension_priority() -> int:
	return 1


func load_extension(gsclient: GSClient) -> bool:
	return true


func unload_extension(gsclient: GSClient) -> void:
	pass
