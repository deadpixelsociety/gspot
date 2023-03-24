extends GSMessage
class_name GSRawUnsubscribeCmd


func _init(
	message_id: int, 
	device_index: int, 
	endpoint: String
) -> void:
	super._init(message_id)
	message_type = MESSAGE_TYPE_RAW_SUBSCRIBE_CMD
	fields[MESSAGE_FIELD_DEVICE_INDEX] = device_index
	fields[MESSAGE_FIELD_ENDPOINT] = endpoint
