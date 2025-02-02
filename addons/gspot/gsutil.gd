class_name GSUtil


static func is_valid(obj) -> bool:
	var valid = obj != null and is_instance_valid(obj)
	if obj is Node:
		valid = valid and not obj.is_queued_for_deletion()
	return valid
