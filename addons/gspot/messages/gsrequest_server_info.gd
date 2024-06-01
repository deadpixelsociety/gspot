extends GSMessage
class_name GSRequestServerInfo


func _init(message_id: int) -> void:
	super._init(message_id)
	message_type = MESSAGE_TYPE_REQUEST_SERVER_INFO
	fields[MESSAGE_FIELD_CLIENT_NAME] = GSClient.get_client_string()
	fields[MESSAGE_FIELD_MESSAGE_VERSION] = GSClient.MESSAGE_VERSION
