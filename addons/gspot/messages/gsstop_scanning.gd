extends GSMessage
class_name GSStopScanning


func _init(message_id: int) -> void:
	super._init(message_id)
	message_type = MESSAGE_TYPE_STOP_SCANNING
