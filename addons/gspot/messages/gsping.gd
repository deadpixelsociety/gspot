class_name GSPing
extends GSMessage


func _init(message_id: int) -> void:
	super._init(message_id)
	message_type = MESSAGE_TYPE_PING
