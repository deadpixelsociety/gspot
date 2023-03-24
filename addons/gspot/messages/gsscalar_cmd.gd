extends GSMessage
class_name GSScalarCmd


func _init(message_id: int, device_index: int, scalars: Array[GSScalar] = []) -> void:
	super._init(message_id)
	message_type = MESSAGE_TYPE_SCALAR_CMD
	fields[MESSAGE_FIELD_DEVICE_INDEX] = device_index
	var _scalars = []
	for scalar in scalars:
		_scalars.append(scalar.serialize())
	fields[MESSAGE_FIELD_SCALARS] = _scalars
