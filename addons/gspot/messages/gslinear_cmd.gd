extends GSMessage
class_name GSLinearCmd


func _init(message_id: int, device_index: int, vectors: Array[GSVector] = []) -> void:
	super._init(message_id)
	message_type = MESSAGE_TYPE_LINEAR_CMD
	fields[MESSAGE_FIELD_DEVICE_INDEX] = device_index
	var _vectors = []
	for vector in vectors:
		_vectors.append(vector.serialize())
	fields[MESSAGE_FIELD_VECTORS] = _vectors
