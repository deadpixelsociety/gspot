extends GSExtension
class_name GSPatterns


func get_extension_name() -> String:
	return "patterns"


func load_extension(gsclient: GSClient) -> bool:
	print("extension loaded")
	return true


func unload_extension(gsclient: GSClient) -> void:
	print("extension unloaded")


func test(msg: String) -> bool:
	print(msg)
	return true
