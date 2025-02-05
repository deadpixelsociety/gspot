class_name GSRequestDeviceList
extends GSMessage


func _init(message_id: int) -> void:
	super._init(message_id)
	message_type = MESSAGE_TYPE_REQUEST_DEVICE_LIST
