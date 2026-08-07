class_name GSProtocolV4
extends GSProtocolHandler
## Buttplug protocol v4 wire adapter.

func get_major_version() -> int:
	return 4

func get_minor_version() -> int:
	return 0

func create_request_server_info(message_id: int, client_name: String) -> GSMessage:
	return _message(GSMessage.MESSAGE_TYPE_REQUEST_SERVER_INFO, message_id, {
		GSMessage.MESSAGE_FIELD_CLIENT_NAME: client_name,
		GSMessage.MESSAGE_FIELD_PROTOCOL_VERSION_MAJOR: get_major_version(),
		GSMessage.MESSAGE_FIELD_PROTOCOL_VERSION_MINOR: get_minor_version(),
	})

func parse_server_info(fields: Dictionary) -> Dictionary:
	return {
		"server_name": str(fields.get(GSMessage.MESSAGE_FIELD_SERVER_NAME, "")),
		"max_ping_time": int(fields.get(GSMessage.MESSAGE_FIELD_MAX_PING_TIME, 0)),
		"major": int(fields.get(GSMessage.MESSAGE_FIELD_PROTOCOL_VERSION_MAJOR, 0)),
		"minor": int(fields.get(GSMessage.MESSAGE_FIELD_PROTOCOL_VERSION_MINOR, 0)),
	}

func create_ping(message_id: int) -> GSMessage:
	return _message(GSMessage.MESSAGE_TYPE_PING, message_id)

func create_request_device_list(message_id: int) -> GSMessage:
	return _message(GSMessage.MESSAGE_TYPE_REQUEST_DEVICE_LIST, message_id)

func create_start_scanning(message_id: int) -> GSMessage:
	return _message(GSMessage.MESSAGE_TYPE_START_SCANNING, message_id)

func create_stop_scanning(message_id: int) -> GSMessage:
	return _message(GSMessage.MESSAGE_TYPE_STOP_SCANNING, message_id)

func create_output(message_id: int, feature: GSFeature, value: float, duration_ms: int, clockwise: bool) -> GSMessage:
	var wire_value := _normalized_value(feature, value, clockwise)
	return create_output_value(message_id, feature, wire_value, duration_ms)

func create_output_value(message_id: int, feature: GSFeature, value: int, duration_ms: int) -> GSMessage:
	if not feature or not feature.is_output() or not GSOutputType.is_known(feature.output_type):
		return null
	var command_fields := { GSMessage.MESSAGE_FIELD_VALUE: feature.clamp_value(value) }
	if feature.output_type == GSOutputType.HW_POSITION_WITH_DURATION:
		command_fields[GSMessage.MESSAGE_FIELD_DURATION] = feature.clamp_duration(duration_ms)
	return _message(GSMessage.MESSAGE_TYPE_OUTPUT_CMD, message_id, {
		GSMessage.MESSAGE_FIELD_DEVICE_INDEX: feature.device.device_index,
		GSMessage.MESSAGE_FIELD_FEATURE_INDEX: feature.feature_index,
		GSMessage.MESSAGE_FIELD_COMMAND: { feature.output_type: command_fields },
	})

func create_input(message_id: int, feature: GSFeature, command: String) -> GSMessage:
	if not feature or not feature.is_input() or not command in feature.input_commands:
		return null
	return _message(GSMessage.MESSAGE_TYPE_INPUT_CMD, message_id, {
		GSMessage.MESSAGE_FIELD_DEVICE_INDEX: feature.device.device_index,
		GSMessage.MESSAGE_FIELD_FEATURE_INDEX: feature.feature_index,
		GSMessage.MESSAGE_FIELD_TYPE: feature.input_type,
		GSMessage.MESSAGE_FIELD_COMMAND: command,
	})

func create_stop(message_id: int, device_index: Variant = null, feature_index: Variant = null, inputs: bool = true, outputs: bool = true) -> GSMessage:
	var fields := {
		GSMessage.MESSAGE_FIELD_INPUTS: inputs,
		GSMessage.MESSAGE_FIELD_OUTPUTS: outputs,
	}
	if device_index != null:
		fields[GSMessage.MESSAGE_FIELD_DEVICE_INDEX] = int(device_index)
	if feature_index != null and device_index != null:
		fields[GSMessage.MESSAGE_FIELD_FEATURE_INDEX] = int(feature_index)
	return _message(GSMessage.MESSAGE_TYPE_STOP_CMD, message_id, fields)

func create_disconnect(message_id: int) -> GSMessage:
	return _message(GSMessage.MESSAGE_TYPE_DISCONNECT, message_id)

func parse_devices(fields: Dictionary) -> Array:
	var devices: Array = []
	var raw_devices = fields.get(GSMessage.MESSAGE_FIELD_DEVICES, {})
	if not raw_devices is Dictionary:
		return devices
	for key in raw_devices.keys():
		var data = raw_devices[key]
		if data is Dictionary:
			devices.append(GSDevice.deserialize(data, 4))
	return devices

func parse_input_reading(fields: Dictionary) -> Dictionary:
	var raw_reading = fields.get(GSMessage.MESSAGE_FIELD_READING, {})
	if not raw_reading is Dictionary:
		return {}
	var reading: Dictionary = raw_reading
	if reading.is_empty():
		return {}
	var input_type := ""
	for candidate in reading.keys():
		if GSInputType.is_known(str(candidate)):
			input_type = str(candidate)
			break
		push_warning("Skipping unknown v4 input reading type '%s'." % candidate)
	if input_type.is_empty():
		return {}
	var input_data = reading[input_type]
	var value = input_data.get(GSMessage.MESSAGE_FIELD_VALUE, 0) if input_data is Dictionary else 0
	return {
		"id": int(fields.get(GSMessage.MESSAGE_FIELD_ID, 0)),
		"device_index": int(fields.get(GSMessage.MESSAGE_FIELD_DEVICE_INDEX, -1)),
		"feature_index": int(fields.get(GSMessage.MESSAGE_FIELD_FEATURE_INDEX, -1)),
		"input_type": input_type,
		"data": PackedInt32Array([int(value)]),
	}

func _normalized_value(feature: GSFeature, value: float, clockwise: bool) -> int:
	value = clampf(value, 0.0, 1.0)
	if feature.output_type == GSOutputType.ROTATE and not clockwise and feature.value_range.x < 0:
		return roundi(lerpf(0.0, float(feature.value_range.x), value))
	if feature.output_type == GSOutputType.ROTATE:
		return roundi(lerpf(0.0, float(feature.value_range.y), value))
	return roundi(lerpf(float(feature.value_range.x), float(feature.value_range.y), value))
