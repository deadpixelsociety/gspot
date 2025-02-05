class_name GSUtil
## Utility class used by gspot.
##
## Various utility functions used by gspot.


## Gets the specified project property value. Returns [param default] if no value is set.
static func get_project_value(property: String, default = null):
	var value = ProjectSettings.get(property)
	if value == null or (value is String and value == ""):
		value = default
	return value


## Determines if the given object is valid. Checks for nullability, instance validity, and if it has 
## been queued for deletion.
static func is_valid(obj) -> bool:
	var valid = obj != null and is_instance_valid(obj)
	if obj is Node:
		valid = valid and not obj.is_queued_for_deletion()
	return valid


## Determines if the given string is [code]null[/code] or empty.
static func ne(str: String) -> bool:
	return str == null or str == ""
