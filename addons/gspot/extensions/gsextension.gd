class_name GSExtension
extends RefCounted
## Defines an extension that adds new functionality to gspot.
##
## GSExtension defines an extension that allows a developer to add new functionality to gspot 
## without needing to modify GSClient directly. These extensions are automatically loaded at 
## runtime and can be access via [method GSClient.ext] or [method GSClient.ext_call].


## Gets the extension's name. This name is how it will be accessed via [method GSClient.ext] or 
## [method GSClient.ext_call].
func get_extension_name() -> String:
	return "new-extension"


## Gets the extension's load priority. Higher values load first.
func get_extension_priority() -> int:
	return 1


## Loads the extension, allowing the developer to do any necessary setup. Returns 
## [code]false[/code] if loading failed for any reason and the extension will not be available.
func load_extension(gsclient: GSClient) -> bool:
	return true


## Unloads the extension, allowing the developer to do any necessary cleanup.
func unload_extension(gsclient: GSClient) -> void:
	pass
