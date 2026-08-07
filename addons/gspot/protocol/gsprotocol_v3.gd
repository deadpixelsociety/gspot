class_name GSProtocolV3
extends GSProtocolHandler
## Buttplug protocol v3 wire adapter.

func get_major_version() -> int:
	return 3

func supports_raw() -> bool:
	return true

func create_request_server_info(message_id: int, client_name: String) -> GSMessage:
	return GSRequestServerInfo.new(message_id, client_name, get_major_version())

func parse_server_info(fields: Dictionary) -> Dictionary:
	return {
		"server_name": str(fields.get(GSMessage.MESSAGE_FIELD_SERVER_NAME, "")),
		"max_ping_time": int(fields.get(GSMessage.MESSAGE_FIELD_MAX_PING_TIME, 0)),
		"major": int(fields.get(GSMessage.MESSAGE_FIELD_MESSAGE_VERSION, 0)),
		"minor": 0,
	}

func create_ping(message_id: int) -> GSMessage:
	return GSPing.new(message_id)

func create_request_device_list(message_id: int) -> GSMessage:
	return GSRequestDeviceList.new(message_id)

func create_start_scanning(message_id: int) -> GSMessage:
	return GSStartScanning.new(message_id)

func create_stop_scanning(message_id: int) -> GSMessage:
	return GSStopScanning.new(message_id)

func create_output(message_id: int, feature: GSFeature, value: float, duration_ms: int, clockwise: bool) -> GSMessage:
	match feature.feature_command:
		GSMessage.MESSAGE_TYPE_SCALAR_CMD:
			var scalar := GSScalar.new()
			scalar.index = feature.feature_index
			scalar.scalar = value
			scalar.actuator_type = feature.actuator_type
			return GSScalarCmd.new(message_id, feature.device.device_index, [scalar])
		GSMessage.MESSAGE_TYPE_ROTATE_CMD:
			var rotation := GSRotation.new()
			rotation.index = feature.feature_index
			rotation.speed = value
			rotation.clockwise = clockwise
			return GSRotateCmd.new(message_id, feature.device.device_index, [rotation])
		GSMessage.MESSAGE_TYPE_LINEAR_CMD:
			var vector := GSVector.new()
			vector.index = feature.feature_index
			vector.duration = duration_ms
			vector.position = value
			return GSLinearCmd.new(message_id, feature.device.device_index, [vector])
	return null

func create_output_value(message_id: int, feature: GSFeature, value: int, duration_ms: int) -> GSMessage:
	var normalized := feature.value_to_normalized(value)
	return create_output(message_id, feature, normalized, duration_ms, true)

func create_input(message_id: int, feature: GSFeature, command: String) -> GSMessage:
	match command:
		"Read":
			return GSSensorReadCmd.new(message_id, feature.device.device_index, feature.feature_index, feature.sensor_type)
		"Subscribe":
			return GSSensorSubscribeCmd.new(message_id, feature.device.device_index, feature.feature_index, feature.sensor_type)
		"Unsubscribe":
			return GSSensorUnsubscribeCmd.new(message_id, feature.device.device_index, feature.feature_index, feature.sensor_type)
	return null

func create_stop(message_id: int, device_index: Variant = null, feature_index: Variant = null, inputs: bool = true, outputs: bool = true) -> GSMessage:
	if feature_index != null and device_index != null:
		var feature := GSMessage.new(message_id)
		feature.message_type = GSMessage.MESSAGE_TYPE_STOP_DEVICE_CMD
		feature.fields[GSMessage.MESSAGE_FIELD_DEVICE_INDEX] = int(device_index)
		return feature
	if device_index != null:
		return GSStopDevice.new(message_id, int(device_index))
	return GSStopAllDevices.new(message_id)

func parse_devices(fields: Dictionary) -> Array:
	var devices: Array = []
	var raw_devices = fields.get(GSMessage.MESSAGE_FIELD_DEVICES, [])
	if raw_devices is Array:
		for data in raw_devices:
			if data is Dictionary:
				devices.append(GSDevice.deserialize(data, 3))
	return devices

func parse_input_reading(fields: Dictionary) -> Dictionary:
	return {
		"id": int(fields.get(GSMessage.MESSAGE_FIELD_ID, 0)),
		"device_index": int(fields.get(GSMessage.MESSAGE_FIELD_DEVICE_INDEX, -1)),
		"feature_index": int(fields.get(GSMessage.MESSAGE_FIELD_SENSOR_INDEX, -1)),
		"input_type": str(fields.get(GSMessage.MESSAGE_FIELD_SENSOR_TYPE, "")),
		"data": PackedInt32Array(fields.get(GSMessage.MESSAGE_FIELD_DATA, [])),
	}
