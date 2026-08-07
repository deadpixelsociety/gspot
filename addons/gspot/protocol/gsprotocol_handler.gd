class_name GSProtocolHandler
extends RefCounted
## Common wire-protocol interface used by [GSClient].

func get_major_version() -> int:
	return 0

func get_minor_version() -> int:
	return 0

func supports_raw() -> bool:
	return false

func create_request_server_info(message_id: int, client_name: String) -> GSMessage:
	return null

func parse_server_info(fields: Dictionary) -> Dictionary:
	return {}

func create_ping(message_id: int) -> GSMessage:
	return null

func create_request_device_list(message_id: int) -> GSMessage:
	return null

func create_start_scanning(message_id: int) -> GSMessage:
	return null

func create_stop_scanning(message_id: int) -> GSMessage:
	return null

func create_output(message_id: int, feature: GSFeature, value: float, duration_ms: int, clockwise: bool) -> GSMessage:
	return null

func create_output_value(message_id: int, feature: GSFeature, value: int, duration_ms: int) -> GSMessage:
	return null

func create_input(message_id: int, feature: GSFeature, command: String) -> GSMessage:
	return null

func create_stop(message_id: int, device_index: Variant = null, feature_index: Variant = null, inputs: bool = true, outputs: bool = true) -> GSMessage:
	return null

func create_disconnect(message_id: int) -> GSMessage:
	return null

func parse_devices(fields: Dictionary) -> Array:
	return []

func parse_input_reading(fields: Dictionary) -> Dictionary:
	return {}

func _message(message_type: String, message_id: int, message_fields: Dictionary = {}) -> GSMessage:
	var message := GSMessage.new(message_id)
	message.message_type = message_type
	message.fields.merge(message_fields, true)
	return message
