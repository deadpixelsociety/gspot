class_name GSFeature
extends RefCounted
## Represents a buttplug.io device feature.
##
## GSFeature contains information about a device feature such as a vibration actuator or a battery
## sensor. 
##
## @tutorial(Spec Reference): https://buttplug-spec.docs.buttplug.io/docs/spec/enumeration#devicelist

## Emitted when a sensor value has been read after calling [method read_sensor].
## [br][br]
## [param feature] is the sensor feature.
## [br]
## [param data] is the sensor data.
signal sensor_value_read(feature: GSFeature, data: PackedInt32Array)

## The [GSDevice] that owns this feature.
var device: GSDevice
## The feature command (ScalarCmd, RotateCmd, LinearCmd, etc.)
var feature_command: String
## The feature index in the device's feature list.
var feature_index: int = -1
## The feature descriptor is a text description of the feature, if available.
var feature_descriptor: String
## The step count is the number of discrete steps the feature can use. Useful for normalizing UI 
## interactions back into the required [code]0.0[/code] to [code]1.0[/code] range.
var step_count: int
## The actuator type of the feature, if applicable.
## [br][br]
## See [GSActuatorType] for a list of available types.
var actuator_type: String
## The sensor type of the feature, if applicable.
var sensor_type: String
## An array of possible sensor ranges. A sensor can have multiple axes of values it can return, and 
## these ranges will align with the data returned from [method read_sensor].
var sensor_range: Array[GSSensorRange] = []
## A list of endpoints useable by raw commands, if enabled.
var endpoints: PackedStringArray = []
var _read_sensor_id: int = -1

func _init() -> void:
	GSClient.client_sensor_reading.connect(
		func(
			id: int, 
			device_index: int, 
			sensor_index: int, 
			_sensor_type: String, 
			data: PackedInt32Array
		):
			if(
				_read_sensor_id == id
				and device_index == device.device_index
				and sensor_index == feature_index
				and _sensor_type == sensor_type
			):
				sensor_value_read.emit(self, data)
				_read_sensor_id = -1
	)


## Deserializes the given dictionary into a new [GSFeature] instance.
static func deserialize(command: String, index: int, data: Dictionary) -> GSFeature:
	var feature := GSFeature.new()
	feature.feature_command = command
	feature.feature_index = index
	if data.has(GSMessage.MESSAGE_FIELD_FEATURE_DESCRIPTOR):
		feature.feature_descriptor = data[GSMessage.MESSAGE_FIELD_FEATURE_DESCRIPTOR]
	if data.has(GSMessage.MESSAGE_FIELD_STEP_COUNT):
		feature.step_count = data[GSMessage.MESSAGE_FIELD_STEP_COUNT]
	if data.has(GSMessage.MESSAGE_FIELD_ACTUATOR_TYPE):
		feature.actuator_type = data[GSMessage.MESSAGE_FIELD_ACTUATOR_TYPE]
	if data.has(GSMessage.MESSAGE_FIELD_SENSOR_TYPE):
		feature.sensor_type = data[GSMessage.MESSAGE_FIELD_SENSOR_TYPE]
	if data.has(GSMessage.MESSAGE_FIELD_SENSOR_RANGE):
		for range: Array in data[GSMessage.MESSAGE_FIELD_SENSOR_RANGE]:
			feature.sensor_range.append(GSSensorRange.new(range[0], range[1]))
	if data.has(GSMessage.MESSAGE_FIELD_ENDPOINTS):
		for endpoint: String in data[GSMessage.MESSAGE_FIELD_ENDPOINTS]:
			feature.endpoints.append(endpoint)
	return feature


## Returns the [member feature_descriptor], if set. If not it attempts to return the 
## [member acuator_type], if set. Otherwise, it returns the [member feature_command].
func get_display_name() -> String:
	if not GSUtil.ne(feature_descriptor) and feature_descriptor != "NA":
		return feature_descriptor
	if not GSUtil.ne(actuator_type):
		return actuator_type
	return feature_command


## Starts the feature if it has an actuator type. This does nothing for sensor features.
## [br][br]
## [param value] is a value between [code]0.0[/code] and [code]1.0[/code] where [code]0.0[/code] 
## is no activation and [code]1.0[/code] is max activation.
## [br]
## [param duration] sets the duration, in seconds. A value of [code]0.0[/code] is always on.
## [br]
## [param clockwise] sets the direction of rotation. Only applicable for rotation actuators.
## [br][br]
## If the feature is a LinearCmd this method can be awaited on.
func start(value: float, duration: float = 0.0, clockwise: bool = true) -> void:
	if GSUtil.ne(actuator_type):
		return
	await GSClient.send_feature(self, clampf(value, 0.0, 1.0), duration, clockwise)


## Stops the feature.
func stop() -> void:
	GSClient.stop_feature(self)


## Requests the feature value if it has a sensor type. This does nothing for actuator features. The 
## value will be returned via [signal sensor_value_read].
func read_sensor() -> void:
	if GSUtil.ne(sensor_type):
		return
	_read_sensor_id = GSClient.read_sensor(device.device_index, feature_index, sensor_type)
