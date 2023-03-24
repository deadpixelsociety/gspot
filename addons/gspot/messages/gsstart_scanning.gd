extends GSMessage
class_name GSStartScanning


func _init(message_id: int) -> void:
	super._init(message_id)
	message_type = MESSAGE_TYPE_START_SCANNING
