extends GSMessage
class_name GSStopDevice


func _init(message_id: int, device_index: int) -> void:
	super._init(message_id)
	message_type = MESSAGE_TYPE_STOP_DEVICE_CMD
	fields[MESSAGE_FIELD_DEVICE_INDEX] = device_index
