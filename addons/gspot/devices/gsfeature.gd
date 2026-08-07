class_name GSFeature
extends RefCounted
## Represents a normalized v3 or v4 device capability.

signal sensor_value_read(feature: GSFeature, data: PackedInt32Array)

## The [GSDevice] that owns this capability.
var device: GSDevice
## Legacy protocol command name, retained for compatibility.
var feature_command: String
## Protocol feature index. In v4 this is shared by all contexts on a feature.
var feature_index: int = -1
## Exact v4 output type, when this is an output capability.
var output_type: String = ""
## Exact v4 input type, when this is an input capability.
var input_type: String = ""
## Human-readable feature description from the server.
var feature_descriptor: String
## Legacy normalized step count view.
var step_count: int
## Legacy actuator type view.
var actuator_type: String
## Legacy sensor type view.
var sensor_type: String
## Legacy sensor range view.
var sensor_range: Array[GSSensorRange] = []
## Legacy raw endpoint view.
var endpoints: PackedStringArray = []
## Inclusive v4 output value range.
var value_range: Vector2i = Vector2i(0, 1)
## Inclusive v4 hardware duration range in milliseconds.
var duration_range: Vector2i = Vector2i(0, 0)
## Whether the server advertised a duration range for this output.
var duration_range_advertised: bool = false
## v4 input operations advertised by the server.
var input_commands: PackedStringArray = []
var _read_sensor_id: int = -1


func _init() -> void:
	var client: Variant = GSUtil.get_client()
	if not client:
		return
	client.client_sensor_reading.connect(
		func(
			id: int,
			device_index: int,
			sensor_index: int,
			_sensor_type: String,
			data: PackedInt32Array
		):
			if (
				_read_sensor_id == id
				and device != null
				and device_index == device.device_index
				and sensor_index == feature_index
				and _sensor_type == sensor_type
			):
				sensor_value_read.emit(self, data)
				_read_sensor_id = -1
	)


## Deserializes a v3 message attribute into a normalized feature.
static func deserialize(command: String, index: int, data: Dictionary) -> GSFeature:
	var feature := GSFeature.new()
	feature.feature_command = command
	feature.feature_index = index
	if data.has(GSMessage.MESSAGE_FIELD_FEATURE_DESCRIPTOR):
		feature.feature_descriptor = str(data[GSMessage.MESSAGE_FIELD_FEATURE_DESCRIPTOR])
	if data.has(GSMessage.MESSAGE_FIELD_STEP_COUNT):
		feature.step_count = int(data[GSMessage.MESSAGE_FIELD_STEP_COUNT])
	if data.has(GSMessage.MESSAGE_FIELD_ACTUATOR_TYPE):
		feature.actuator_type = str(data[GSMessage.MESSAGE_FIELD_ACTUATOR_TYPE])
		feature.output_type = feature.actuator_type
	if data.has(GSMessage.MESSAGE_FIELD_SENSOR_TYPE):
		feature.sensor_type = str(data[GSMessage.MESSAGE_FIELD_SENSOR_TYPE])
		feature.input_type = feature.sensor_type
	if feature.is_output():
		feature.value_range = Vector2i(0, maxi(feature.step_count, 1))
	if data.has(GSMessage.MESSAGE_FIELD_SENSOR_RANGE):
		for sensor_range in data[GSMessage.MESSAGE_FIELD_SENSOR_RANGE]:
			if sensor_range is Array and sensor_range.size() >= 2:
				feature.sensor_range.append(GSSensorRange.new(int(sensor_range[0]), int(sensor_range[1])))
	if data.has(GSMessage.MESSAGE_FIELD_ENDPOINTS):
		feature.endpoints = PackedStringArray(data[GSMessage.MESSAGE_FIELD_ENDPOINTS])
	if command == GSMessage.MESSAGE_TYPE_SENSOR_READ_CMD:
		feature.input_commands = PackedStringArray(["Read"])
	elif command == GSMessage.MESSAGE_TYPE_SENSOR_SUBSCRIBE_CMD:
		feature.input_commands = PackedStringArray(["Subscribe", "Unsubscribe"])
	return feature


## Deserializes one v4 output context.
static func deserialize_v4_output(output: String, index: int, data: Dictionary, descriptor: String) -> GSFeature:
	var feature := GSFeature.new()
	feature.feature_command = GSOutputType.legacy_command(output)
	feature.output_type = output
	feature.feature_index = index
	feature.feature_descriptor = descriptor
	feature.actuator_type = GSActuatorType.POSITION if output == GSOutputType.HW_POSITION_WITH_DURATION else output
	var range = data.get(GSMessage.MESSAGE_FIELD_VALUE, [0, 1])
	if range is Array and range.size() >= 2:
		feature.value_range = Vector2i(int(range[0]), int(range[1]))
	feature.step_count = absi(feature.value_range.y - feature.value_range.x)
	var duration = data.get(GSMessage.MESSAGE_FIELD_DURATION_RANGE, [0, 0])
	if duration is Array and duration.size() >= 2:
		feature.duration_range = Vector2i(int(duration[0]), int(duration[1]))
		feature.duration_range_advertised = data.has(GSMessage.MESSAGE_FIELD_DURATION_RANGE)
	return feature


## Deserializes one v4 input context.
static func deserialize_v4_input(input: String, index: int, data: Dictionary, descriptor: String) -> GSFeature:
	var feature := GSFeature.new()
	feature.feature_command = GSMessage.MESSAGE_TYPE_SENSOR_READ_CMD if "Read" in data.get(GSMessage.MESSAGE_FIELD_COMMAND, []) else GSMessage.MESSAGE_TYPE_SENSOR_SUBSCRIBE_CMD
	feature.input_type = input
	feature.sensor_type = input
	feature.feature_index = index
	feature.feature_descriptor = descriptor
	var commands = data.get(GSMessage.MESSAGE_FIELD_COMMAND, [])
	if commands is Array:
		feature.input_commands = PackedStringArray(commands)
	var ranges = data.get(GSMessage.MESSAGE_FIELD_VALUE, [])
	if ranges is Array:
		if not ranges.is_empty() and ranges[0] is Array:
			for sensor_range in ranges:
				if sensor_range is Array and sensor_range.size() >= 2:
					feature.sensor_range.append(GSSensorRange.new(int(sensor_range[0]), int(sensor_range[1])))
		elif ranges.size() >= 2:
			feature.sensor_range.append(GSSensorRange.new(int(ranges[0]), int(ranges[1])))
	return feature


## Returns whether this capability exposes an output context.
func is_output() -> bool:
	return not output_type.is_empty()


## Returns whether this capability exposes an input context.
func is_input() -> bool:
	return not input_type.is_empty()


## Returns whether the server advertises Read for this input.
func can_read() -> bool:
	return is_input() and "Read" in input_commands


## Returns whether the server advertises Subscribe for this input.
func can_subscribe() -> bool:
	return is_input() and "Subscribe" in input_commands


## Returns the stable internal identity used when reconciling DeviceList snapshots.
func get_capability_key() -> String:
	return "%s:%d:%s:%s" % ["output" if is_output() else "input", feature_index, output_type, input_type]


func clamp_value(value: int) -> int:
	return clampi(value, value_range.x, value_range.y)


func clamp_duration(duration_ms: int) -> int:
	if not duration_range_advertised:
		return duration_ms
	return clampi(duration_ms, duration_range.x, duration_range.y)


func value_to_normalized(value: int) -> float:
	var span := float(value_range.y - value_range.x)
	if is_zero_approx(span):
		return 0.0
	return clampf((float(value) - float(value_range.x)) / span, 0.0, 1.0)


func update_from(other: GSFeature) -> void:
	var pending_read_id := _read_sensor_id
	device = other.device
	feature_command = other.feature_command
	feature_index = other.feature_index
	output_type = other.output_type
	input_type = other.input_type
	feature_descriptor = other.feature_descriptor
	step_count = other.step_count
	actuator_type = other.actuator_type
	sensor_type = other.sensor_type
	sensor_range = other.sensor_range
	endpoints = other.endpoints
	value_range = other.value_range
	duration_range = other.duration_range
	duration_range_advertised = other.duration_range_advertised
	input_commands = other.input_commands
	_read_sensor_id = pending_read_id


func get_display_name() -> String:
	if not GSUtil.ne(feature_descriptor) and feature_descriptor != "NA":
		return feature_descriptor
	if not GSUtil.ne(output_type):
		return output_type
	if not GSUtil.ne(actuator_type):
		return actuator_type
	if not GSUtil.ne(input_type):
		return input_type
	return feature_command


## Starts this output using a normalized value. Durations are expressed in seconds;
## linear values are converted to milliseconds before they are sent.
func start(value: float, duration: float = 0.0, clockwise: bool = true) -> void:
	if not is_output():
		return
	var client: Variant = GSUtil.get_client()
	if client:
		await client.send_feature(self, clampf(value, 0.0, 1.0), duration, clockwise)


## Stops this capability.
func stop() -> void:
	var client: Variant = GSUtil.get_client()
	if client:
		client.stop_feature(self)


## Requests an input reading when Read is advertised. The result is emitted via
## [signal sensor_value_read].
func read_sensor() -> void:
	if not is_input() or not can_read():
		return
	var client: Variant = GSUtil.get_client()
	if client:
		_read_sensor_id = client.read_sensor(device.device_index, feature_index, sensor_type)
