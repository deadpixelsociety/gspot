extends SceneTree

var failures: Array[String] = []
var _client

const PROTOCOL_MODE_AUTO: int = 0
const PROTOCOL_MODE_SPEC_V4: int = 1
const PROTOCOL_MODE_SPEC_V3: int = 2


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	# Script entrypoints can be parsed before autoload identifiers are registered.
	# Resolve the singleton by its scene-tree name and provide a local fallback.
	_client = get_root().get_node_or_null("GSClient")
	if not _client:
		var client_script := load("res://addons/gspot/gsclient.gd") as Script
		if client_script:
			_client = client_script.new()
			_client.name = "GSClient"
			get_root().add_child(_client)
	if not _client:
		push_error("Unable to load GSClient for headless tests.")
		quit(1)
		return
	_test_v4_fixture()
	_test_v3_fixture()
	_test_unknown_v4_capabilities()
	_test_device_snapshots()
	_test_handshakes()
	_test_duration_conversion()
	_test_protocol_modes()
	_test_v4_messages()
	_test_v4_capability_wire_types()
	if failures.is_empty():
		print("gspot protocol tests passed")
	else:
		for failure in failures:
			push_error(failure)
	quit(1 if not failures.is_empty() else 0)


func _test_v4_fixture() -> void:
	var frame = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v4_device_list.json"))
	var message := GSMessage.deserialize(frame[0])
	var devices := GSProtocolV4.new().parse_devices(message.fields)
	_check(devices.size() == 2, "v4 fixture should contain two devices")
	var vibrator: GSDevice = devices[0]
	_check(vibrator.features.size() == 2, "v4 contexts should flatten into capabilities")
	var output: GSFeature = vibrator.features[0]
	_check(output.output_type == GSOutputType.VIBRATE, "v4 output type should be preserved")
	_check(output.value_range == Vector2i(0, 20), "v4 output range should be preserved")
	_check(output.feature_descriptor == "Vibrator", "v4 FeatureDescription should map to the public descriptor")
	var battery: GSFeature = vibrator.features[1]
	_check(battery.can_read() and battery.can_subscribe(), "v4 input commands should be preserved")
	var stroker: GSDevice = devices[1]
	var positions := stroker.get_features_by_actuator_type(GSActuatorType.POSITION)
	_check(positions.size() == 2, "position contexts should retain the same legacy actuator type")
	_check(positions[0].get_capability_key() != positions[1].get_capability_key(), "v4 contexts should have distinct composite identities")
	_check(positions.any(func(feature: GSFeature): return feature.duration_range == Vector2i(0, 100000)), "hardware position duration range should be preserved")


func _test_v3_fixture() -> void:
	var frame = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v3_device_list.json"))
	var message := GSMessage.deserialize(frame[0])
	var devices := GSProtocolV3.new().parse_devices(message.fields)
	_check(devices.size() == 1, "v3 fixture should contain one device")
	_check(devices[0].has_feature(GSMessage.MESSAGE_TYPE_SCALAR_CMD), "v3 scalar feature should remain addressable")
	_check(devices[0].has_actuator_type(GSActuatorType.VIBRATE), "v3 actuator type should remain addressable")
	_check(devices[0].features[1].can_read(), "v3 read capability should remain addressable")


func _test_unknown_v4_capabilities() -> void:
	var device := GSDevice.deserialize({
		"DeviceIndex": 9,
		"DeviceFeatures": {
			"0": {
				"FeatureIndex": 0,
				"FeatureDescription": "Future feature",
				"Output": {"FutureOutput": {"Value": [0, 1]}},
				"Input": {"FutureInput": {"Command": ["Read"]}}
			}
		}
	}, 4)
	_check(device.features.is_empty(), "unknown future v4 capabilities should be skipped")


func _test_device_snapshots() -> void:
	var frame = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v4_device_list.json"))
	var message := GSMessage.deserialize(frame[0])
	var initial: GSDevice = GSProtocolV4.new().parse_devices(message.fields)[0]
	_client._apply_device_snapshot([initial])
	var retained: GSDevice = _client.get_device(initial.device_index)
	var replacement: GSDevice = GSProtocolV4.new().parse_devices(message.fields)[0]
	_client._apply_device_snapshot([replacement])
	_check(_client.get_device(initial.device_index) == retained, "retained indexes should preserve GSDevice identity")
	_client._apply_device_snapshot([])
	var reused: GSDevice = GSProtocolV4.new().parse_devices(message.fields)[1]
	reused.device_index = initial.device_index
	_client._apply_device_snapshot([reused])
	_check(_client.get_device(initial.device_index) != retained, "a removed then reused index should create a new GSDevice")
	_client._apply_device_snapshot([])


func _test_handshakes() -> void:
	var v4_request := GSProtocolV4.new().create_request_server_info(1, "Test Client")
	_check(v4_request.serialize()[GSMessage.MESSAGE_TYPE_REQUEST_SERVER_INFO][GSMessage.MESSAGE_FIELD_PROTOCOL_VERSION_MAJOR] == 4, "v4 handshake should declare major version 4")
	_check(v4_request.serialize()[GSMessage.MESSAGE_TYPE_REQUEST_SERVER_INFO][GSMessage.MESSAGE_FIELD_PROTOCOL_VERSION_MINOR] == 0, "v4 handshake should declare minor version 0")
	var negotiated := GSProtocolV4.new().parse_server_info({"ProtocolVersionMajor": 4, "ProtocolVersionMinor": 3, "MaxPingTime": 0})
	_check(negotiated["major"] == 4 and negotiated["minor"] == 3 and negotiated["max_ping_time"] == 0, "v4 negotiated minor and no-ping values should be preserved")
	var v3_request := GSProtocolV3.new().create_request_server_info(1, "Test Client")
	_check(v3_request.serialize()[GSMessage.MESSAGE_TYPE_REQUEST_SERVER_INFO][GSMessage.MESSAGE_FIELD_MESSAGE_VERSION] == 3, "v3 handshake should declare message version 3")
	_check(GSProtocolV3.new().supports_raw() and not GSProtocolV4.new().supports_raw(), "raw commands should remain v3-only")


func _test_protocol_modes() -> void:
	_client.set_protocol_mode(PROTOCOL_MODE_SPEC_V4)
	_check(_client._create_protocol_handler().get_major_version() == 4, "forced v4 mode should select the v4 handler")
	_client.set_protocol_mode(PROTOCOL_MODE_SPEC_V3)
	_check(_client._create_protocol_handler().get_major_version() == 3, "forced v3 mode should select the v3 handler")
	_client.set_protocol_mode(PROTOCOL_MODE_AUTO)
	_check(_client._create_protocol_handler().get_major_version() == 4, "auto mode should prefer the v4 handler")


func _test_duration_conversion() -> void:
	_check(_client._duration_to_milliseconds(0.5) == 500, "public linear seconds should convert to protocol milliseconds")
	_check(_client._duration_to_milliseconds(1.234) == 1234, "linear duration conversion should round to integer milliseconds")
	_check(_client._duration_to_milliseconds(-1.0) == 0, "negative durations should clamp to zero")


func _test_v4_messages() -> void:
	var frame = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v4_device_list.json"))
	var message := GSMessage.deserialize(frame[0])
	var device: GSDevice = GSProtocolV4.new().parse_devices(message.fields)[0]
	var feature: GSFeature = device.features[0]
	var output := GSProtocolV4.new().create_output(2, feature, 0.5, 0, true)
	var fields: Dictionary = output.serialize()[GSMessage.MESSAGE_TYPE_OUTPUT_CMD]
	_check(fields[GSMessage.MESSAGE_FIELD_COMMAND][GSOutputType.VIBRATE][GSMessage.MESSAGE_FIELD_VALUE] == 10, "normalized v4 output should map to advertised integer range")
	_check(GSProtocolV4.new().create_output(2, feature, 0.0, 0, true).fields[GSMessage.MESSAGE_FIELD_COMMAND][GSOutputType.VIBRATE][GSMessage.MESSAGE_FIELD_VALUE] == 0, "normalized v4 minimum should map to the advertised minimum")
	_check(GSProtocolV4.new().create_output(2, feature, 1.0, 0, true).fields[GSMessage.MESSAGE_FIELD_COMMAND][GSOutputType.VIBRATE][GSMessage.MESSAGE_FIELD_VALUE] == 20, "normalized v4 maximum should map to the advertised maximum")
	var rotate := GSFeature.deserialize_v4_output(GSOutputType.ROTATE, 2, {"Value": [-20, 20]}, "Rotator")
	rotate.device = device
	var clockwise := GSProtocolV4.new().create_output(2, rotate, 0.5, 0, true)
	var counterclockwise := GSProtocolV4.new().create_output(2, rotate, 0.5, 0, false)
	_check(clockwise.fields[GSMessage.MESSAGE_FIELD_COMMAND][GSOutputType.ROTATE][GSMessage.MESSAGE_FIELD_VALUE] == 10, "signed v4 clockwise rotation should be positive")
	_check(counterclockwise.fields[GSMessage.MESSAGE_FIELD_COMMAND][GSOutputType.ROTATE][GSMessage.MESSAGE_FIELD_VALUE] == -10, "signed v4 counterclockwise rotation should be negative")
	var hardware_position = GSProtocolV4.new().parse_devices(message.fields)[1].features[0]
	if hardware_position:
		var duration_message := GSProtocolV4.new().create_output(4, hardware_position, 0.5, 500, true)
		_check(duration_message.fields[GSMessage.MESSAGE_FIELD_COMMAND][GSOutputType.HW_POSITION_WITH_DURATION][GSMessage.MESSAGE_FIELD_DURATION] == 500, "v4 hardware position duration should remain milliseconds")
	var input: GSFeature = device.features[1]
	var input_message := GSProtocolV4.new().create_input(3, input, "Read")
	_check(input_message.serialize()[GSMessage.MESSAGE_TYPE_INPUT_CMD][GSMessage.MESSAGE_FIELD_COMMAND] == "Read", "v4 input command should serialize")
	var reading := GSProtocolV4.new().parse_input_reading({
		"Id": 3,
		"DeviceIndex": 0,
		"FeatureIndex": 1,
		"Reading": {"Battery": {"Value": 75}},
	})
	_check(reading["data"][0] == 75, "v4 input reading should normalize to the legacy packed signal")
	var stop := GSProtocolV4.new().create_stop(5, 0, 1, false, true)
	_check(stop.message_type == GSMessage.MESSAGE_TYPE_STOP_CMD and stop.fields[GSMessage.MESSAGE_FIELD_FEATURE_INDEX] == 1, "v4 feature stop should include its feature scope")
	var device_stop := GSProtocolV4.new().create_stop(6, 0)
	_check(device_stop.fields[GSMessage.MESSAGE_FIELD_DEVICE_INDEX] == 0 and not device_stop.fields.has(GSMessage.MESSAGE_FIELD_FEATURE_INDEX), "v4 device stop should omit feature scope")
	var all_stop := GSProtocolV4.new().create_stop(7)
	_check(not all_stop.fields.has(GSMessage.MESSAGE_FIELD_DEVICE_INDEX), "v4 all-device stop should omit device scope")
	_check(GSProtocolV4.new().create_disconnect(8).message_type == GSMessage.MESSAGE_TYPE_DISCONNECT, "v4 disconnect should use the graceful Disconnect message")


func _test_v4_capability_wire_types() -> void:
	var protocol := GSProtocolV4.new()
	var device := GSDevice.new()
	device.device_index = 4
	var output_ranges := {
		GSOutputType.VIBRATE: Vector2i(0, 20),
		GSOutputType.ROTATE: Vector2i(-20, 20),
		GSOutputType.OSCILLATE: Vector2i(0, 10),
		GSOutputType.CONSTRICT: Vector2i(0, 10),
		GSOutputType.SPRAY: Vector2i(0, 5),
		GSOutputType.TEMPERATURE: Vector2i(-4, 6),
		GSOutputType.LED: Vector2i(0, 100),
		GSOutputType.POSITION: Vector2i(0, 100),
		GSOutputType.HW_POSITION_WITH_DURATION: Vector2i(0, 100),
	}
	var feature_index := 0
	for output_type in output_ranges.keys():
		var output_range: Vector2i = output_ranges[output_type]
		var feature := GSFeature.deserialize_v4_output(
			str(output_type), feature_index, {"Value": [output_range.x, output_range.y]}, str(output_type)
		)
		feature.device = device
		var message := protocol.create_output(20 + feature_index, feature, 0.5, 1234, true)
		_check(message != null and message.message_type == GSMessage.MESSAGE_TYPE_OUTPUT_CMD, "%s should serialize as OutputCmd" % output_type)
		var command: Dictionary = message.fields[GSMessage.MESSAGE_FIELD_COMMAND][output_type]
		var expected := roundi(lerpf(float(output_range.x), float(output_range.y), 0.5))
		if output_type == GSOutputType.ROTATE:
			expected = 10
		_check(command[GSMessage.MESSAGE_FIELD_VALUE] == expected, "%s should map normalized values through its advertised range" % output_type)
		if output_type == GSOutputType.HW_POSITION_WITH_DURATION:
			_check(command[GSMessage.MESSAGE_FIELD_DURATION] == 1234, "hardware position should include duration in milliseconds")
		else:
			_check(not command.has(GSMessage.MESSAGE_FIELD_DURATION), "%s should not include a duration field" % output_type)
		feature_index += 1

	var signed_temperature := GSFeature.deserialize_v4_output(
		GSOutputType.TEMPERATURE, 20, {"Value": [-20, 20]}, "Temperature"
	)
	signed_temperature.device = device
	var cooling := protocol.create_output_value(40, signed_temperature, -10, 0)
	_check(
		cooling.fields[GSMessage.MESSAGE_FIELD_COMMAND][GSOutputType.TEMPERATURE][GSMessage.MESSAGE_FIELD_VALUE] == -10,
		"signed temperature values should be sent unchanged"
	)

	var input_values := {
		GSInputType.BATTERY: 75,
		GSInputType.RSSI: -53,
		GSInputType.PRESSURE: 1252,
		GSInputType.BUTTON: 1,
	}
	var input_index := 30
	for input_type in input_values.keys():
		var input_feature := GSFeature.deserialize_v4_input(
			str(input_type), input_index, {"Command": ["Read", "Subscribe", "Unsubscribe"]}, str(input_type)
		)
		input_feature.device = device
		for command_name in ["Read", "Subscribe", "Unsubscribe"]:
			var input_message := protocol.create_input(60 + input_index, input_feature, command_name)
			_check(input_message != null and input_message.fields[GSMessage.MESSAGE_FIELD_TYPE] == input_type, "%s %s should serialize as InputCmd" % [input_type, command_name])
		var reading := protocol.parse_input_reading({
			"Id": input_index,
			"DeviceIndex": device.device_index,
			"FeatureIndex": input_index,
			"Reading": {input_type: {"Value": input_values[input_type]}},
		})
		_check(reading["input_type"] == input_type and reading["data"][0] == input_values[input_type], "%s readings should retain their signed integer value" % input_type)
		input_index += 1


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
