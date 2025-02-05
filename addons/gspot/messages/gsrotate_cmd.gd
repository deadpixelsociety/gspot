class_name GSRotateCmd
extends GSMessage


func _init(message_id: int, device_index: int, rotations: Array[GSRotation] = []) -> void:
	super._init(message_id)
	message_type = MESSAGE_TYPE_ROTATE_CMD
	fields[MESSAGE_FIELD_DEVICE_INDEX] = device_index
	var _rotations: Array[Dictionary] = []
	for rotation in rotations:
		_rotations.append(rotation.serialize())
	fields[MESSAGE_FIELD_ROTATIONS] = _rotations
