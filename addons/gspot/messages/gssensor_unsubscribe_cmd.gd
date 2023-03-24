extends GSMessage
class_name GSSensorUnsubscribeCmd


func _init(message_id: int, device_index: int, sensor_index: int, sensor_type: String) -> void:
	super._init(message_id)
	message_type = MESSAGE_TYPE_SENSOR_UNSUBSCRIBE_CMD
	fields[MESSAGE_FIELD_DEVICE_INDEX] = device_index
	fields[MESSAGE_FIELD_SENSOR_INDEX] = sensor_index
	fields[MESSAGE_FIELD_SENSOR_TYPE] = sensor_type
