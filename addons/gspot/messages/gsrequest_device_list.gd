extends GSMessage
class_name GSRequestDeviceList


func _init(message_id: int) -> void:
	super._init(message_id)
	message_type = MESSAGE_TYPE_REQUEST_DEVICE_LIST
