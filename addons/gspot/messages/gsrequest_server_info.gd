class_name GSRequestServerInfo
extends GSMessage


func _init(message_id: int, client_name: String = "", protocol_version: int = -1) -> void:
	super._init(message_id)
	message_type = MESSAGE_TYPE_REQUEST_SERVER_INFO
	var client: Variant = GSUtil.get_client()
	var effective_name := client_name
	if effective_name.is_empty() and client:
		effective_name = client.get_client_string()
	fields[MESSAGE_FIELD_CLIENT_NAME] = effective_name
	fields[MESSAGE_FIELD_MESSAGE_VERSION] = GSConstants.MESSAGE_VERSION if protocol_version < 0 else protocol_version
