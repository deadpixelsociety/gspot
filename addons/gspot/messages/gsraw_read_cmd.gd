extends GSMessage
class_name GSRawReadCmd


func _init(
	message_id: int, 
	device_index: int, 
	endpoint: String, 
	expected_length: int,
	wait_for_data: bool
) -> void:
	super._init(message_id)
	message_type = MESSAGE_TYPE_RAW_READ_CMD
	fields[MESSAGE_FIELD_DEVICE_INDEX] = device_index
	fields[MESSAGE_FIELD_ENDPOINT] = endpoint
	fields[MESSAGE_FIELD_EXPECTED_LENGTH] = expected_length
	fields[MESSAGE_FIELD_WAIT_FOR_DATA] = wait_for_data
	
