extends GSMessage
class_name GSRequestServerInfo


func _init(message_id: int) -> void:
	super._init(message_id)
	message_type = MESSAGE_TYPE_REQUEST_SERVER_INFO
	fields[MESSAGE_FIELD_CLIENT_NAME] = GSClient.CLIENT_NAME
	fields[MESSAGE_FIELD_MESSAGE_VERSION] = GSClient.MESSAGE_VERSION
