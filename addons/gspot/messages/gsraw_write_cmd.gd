extends GSMessage
class_name GSRawWriteCmd


func _init(
	message_id: int, 
	device_index: int, 
	endpoint: String, 
	data: PackedByteArray, 
	write_with_response: bool
) -> void:
	super._init(message_id)
	message_type = MESSAGE_TYPE_RAW_WRITE_CMD
	fields[MESSAGE_FIELD_DEVICE_INDEX] = device_index
	fields[MESSAGE_FIELD_ENDPOINT] = endpoint
	fields[MESSAGE_FIELD_DATA] = data
	fields[MESSAGE_FIELD_WRITE_WITH_RESPONSE] = write_with_response
	
