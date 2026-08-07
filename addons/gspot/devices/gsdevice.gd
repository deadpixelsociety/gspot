class_name GSDevice
extends RefCounted
## Represents a buttplug.io device interface. 
##
## GSDevice contains information about the device such as device name, display name and its index, 
## as well as the features it contains. Also present are helper methods to quickly access device 
## features such as [method vibrate], [method rotate], and [method position].
##
## @tutorial(Spec Reference): https://buttplug.io/docs/spec/device_information/

## The device name as given by the device itself.
var device_name: String
## The device display name as set by the user.
var device_display_name: String
## The device index in the device list.
var device_index: int = -1
## THe message timing gap, in milliseconds. This determines the minimum interval to wait between 
## messages. You should prefer using [method get_message_rate] to default to the project settings 
## value if this is not set (and it often is not).
var device_message_timing_gap: int
## A list of available features on this device.
var features: Array[GSFeature] = []


## Deserializes the given dictionary into a new [GSDevice] instance.
static func deserialize(data: Dictionary, protocol_major: int = 3) -> GSDevice:
	if protocol_major >= 4:
		return deserialize_v4(data)
	var device := GSDevice.new()
	if data.has(GSMessage.MESSAGE_FIELD_DEVICE_NAME):
		device.device_name = data[GSMessage.MESSAGE_FIELD_DEVICE_NAME]
	if data.has(GSMessage.MESSAGE_FIELD_DEVICE_DISPLAY_NAME):
		device.device_display_name = data[GSMessage.MESSAGE_FIELD_DEVICE_DISPLAY_NAME]
	if data.has(GSMessage.MESSAGE_FIELD_DEVICE_INDEX):
		device.device_index = data[GSMessage.MESSAGE_FIELD_DEVICE_INDEX]
	if data.has(GSMessage.MESSAGE_FIELD_DEVICE_MESSAGE_TIMING_GAP):
		device.device_message_timing_gap = data[GSMessage.MESSAGE_FIELD_DEVICE_MESSAGE_TIMING_GAP]
	if data.has(GSMessage.MESSAGE_FIELD_DEVICE_MESSAGES):
		var messages: Dictionary = data[GSMessage.MESSAGE_FIELD_DEVICE_MESSAGES]
		for feature_command: String in messages.keys():
			var features = messages[feature_command]
			if features is Array:
				for i in features.size():
					var feature_data: Dictionary = features[i]
					var feature: GSFeature = GSFeature.deserialize(feature_command, i, feature_data)
					feature.device = device
					device.features.append(feature)
			elif features is Dictionary:
				var feature: GSFeature = GSFeature.deserialize(feature_command, 0, features)
				feature.device = device
				device.features.append(feature)
	return device


## Deserializes a v4 DeviceList device, flattening each known context into a GSFeature.
static func deserialize_v4(data: Dictionary) -> GSDevice:
	var device := GSDevice.new()
	device.device_name = str(data.get(GSMessage.MESSAGE_FIELD_DEVICE_NAME, ""))
	device.device_display_name = str(data.get(GSMessage.MESSAGE_FIELD_DEVICE_DISPLAY_NAME, ""))
	device.device_index = int(data.get(GSMessage.MESSAGE_FIELD_DEVICE_INDEX, -1))
	device.device_message_timing_gap = int(data.get(GSMessage.MESSAGE_FIELD_DEVICE_MESSAGE_TIMING_GAP, 0))
	var raw_features = data.get(GSMessage.MESSAGE_FIELD_DEVICE_FEATURES, {})
	if not raw_features is Dictionary:
		return device
	for feature_key in raw_features.keys():
		var feature_data = raw_features[feature_key]
		if not feature_data is Dictionary:
			continue
		var feature_index := int(feature_data.get(GSMessage.MESSAGE_FIELD_FEATURE_INDEX, int(feature_key)))
		var descriptor := str(feature_data.get(
			GSMessage.MESSAGE_FIELD_FEATURE_DESCRIPTION,
			feature_data.get(GSMessage.MESSAGE_FIELD_FEATURE_DESCRIPTOR, "")
		))
		var outputs = feature_data.get(GSMessage.MESSAGE_FIELD_OUTPUT, {})
		if outputs is Dictionary:
			for output_type in outputs.keys():
				if not GSOutputType.is_known(str(output_type)):
					push_warning("Skipping unknown v4 output type '%s'." % output_type)
					continue
				if not outputs[output_type] is Dictionary:
					push_warning("Skipping malformed v4 output context '%s'." % output_type)
					continue
				var feature := GSFeature.deserialize_v4_output(str(output_type), feature_index, outputs[output_type], descriptor)
				feature.device = device
				device.features.append(feature)
		var inputs = feature_data.get(GSMessage.MESSAGE_FIELD_INPUT, {})
		if inputs is Dictionary:
			for input_type in inputs.keys():
				if not GSInputType.is_known(str(input_type)):
					push_warning("Skipping unknown v4 input type '%s'." % input_type)
					continue
				if not inputs[input_type] is Dictionary:
					push_warning("Skipping malformed v4 input context '%s'." % input_type)
					continue
				var input_feature := GSFeature.deserialize_v4_input(str(input_type), feature_index, inputs[input_type], descriptor)
				input_feature.device = device
				device.features.append(input_feature)
	return device


## Updates a retained device without invalidating references held by applications.
func update_from(other: GSDevice) -> void:
	device_name = other.device_name
	device_display_name = other.device_display_name
	device_index = other.device_index
	device_message_timing_gap = other.device_message_timing_gap
	var existing: Dictionary = {}
	for feature in features:
		existing[feature.get_capability_key()] = feature
	var updated: Array[GSFeature] = []
	for feature in other.features:
		var key := feature.get_capability_key()
		if existing.has(key):
			var retained: GSFeature = existing[key]
			retained.update_from(feature)
			retained.device = self
			updated.append(retained)
		else:
			feature.device = self
			updated.append(feature)
	features = updated


## Returns the device display name, if set. Otherwise, returns the device name.
func get_display_name() -> String:
	if not GSUtil.ne(device_display_name):
		return device_display_name
	return device_name


## Returns [code]true[/code] if the given feature command (ScalarCmd, RotateCmd, LinearCmd, etc.) 
## is present.
func has_feature(feature_command: String) -> bool:
	return features.any(func(f: GSFeature): return f.feature_command == feature_command)


## Returns a list of all features for the given feature command (ScalarCmd, RotateCmd, LinearCmd, etc.).
func get_features_by_command(feature_command: String) -> Array[GSFeature]:
	var list: Array[GSFeature] = []
	list.assign(features.filter(func(f: GSFeature): return f.feature_command == feature_command))
	return list


## Gets the first feature for the given feature command (ScalarCmd, RotateCmd, LinearCmd, etc.). 
## Returns [code]null[/code] if no feature of that type is available.
func get_feature(feature_command: String) -> GSFeature:
	var features: Array[GSFeature] = get_features_by_command(feature_command)
	if features.size() > 0:
		return features.front()
	return null


## Returns [code]true[/code] if the given actuator type (Vibrate, Rotate, Position, etc.) is 
## present. 
## [br][br]
## See [GSActuatorType] for a list of available types.
func has_actuator_type(actuator_type: String) -> bool:
	return features.any(func(f: GSFeature): return f.actuator_type == actuator_type)


## Returns a list of all features for the given actuator type. 
## [br][br]
## See [GSActuatorType] for a list of available types.
func get_features_by_actuator_type(actuator_type: String) -> Array[GSFeature]:
	var list: Array[GSFeature] = []
	list.assign(features.filter(func(f: GSFeature): return f.actuator_type == actuator_type))
	return list


## Gets the first feature for the given actuator type. Returns [code]null[/code] if no feature of 
## that type is available. 
## [br][br]
## See [GSActuatorType] for a list of available types.
func get_feature_by_actuator_type(actuator_type: String) -> GSFeature:
	var features: Array[GSFeature] = get_features_by_actuator_type(actuator_type)
	if features.size() > 0:
		return features.front()
	return null


## Gets the preferred message rate for the device, in seconds. 
## [br][br]
## Attempts to use [member device_message_timing_gap] if it's set, otherwise it defaults to the 
## Message Rate project setting.
func get_message_rate() -> float:
	var rate: float = float(device_message_timing_gap) / 1000.0
	if rate <= 0.0:
		return GSUtil.get_project_value(GSConstants.PROJECT_SETTINGS_MESSAGE_RATE, GSConstants.MESSAGE_RATE)
	return rate


func _find_output(output: String) -> GSFeature:
	for feature in features:
		if feature.is_output() and feature.output_type == output:
			return feature
	return null


func _set_output(output: String, value: float, duration: float = 0.0) -> GSFeature:
	var feature := _find_output(output)
	if not feature:
		return null
	_send_feature(feature, clampf(value, 0.0, 1.0), duration)
	return feature


func _send_feature(feature: GSFeature, value: float, duration: float = 0.0, clockwise: bool = true) -> void:
	var client: Variant = GSUtil.get_client()
	if client:
		client.send_feature(feature, value, duration, clockwise)


## Attempts to vibrate the device. If no vibrate feature is available this does nothing.
## [br][br]
## [param intensity] is a value between [code]0.0[/code] and [code]1.0[/code] where [code]0.0[/code] 
## is no vibration and [code]1.0[/code] is max vibration.
## [br]
## [param duration] sets the duration, in seconds. A value of [code]0.0[/code] is always on.
func vibrate(intensity: float = 1.0, duration: float = 0.0) -> GSFeature:
	var feature: GSFeature = get_feature_by_actuator_type(GSActuatorType.VIBRATE)
	if not feature:
		return null
	_send_feature(feature, clampf(intensity, 0.0, 1.0), duration)
	return feature


## Attempts to rotate the device. If no rotate feature is available this does nothing.
## [br][br]
## [param speed] is a value between [code]0.0[/code] and [code]1.0[/code] where [code]0.0[/code] 
## is no movement and [code]1.0[/code] is max speed.
## [br]
## [param clockwise] sets the direction of rotation.
## [br]
## [param duration] sets the duration, in seconds. A value of [code]0.0[/code] is always on.
func rotate(speed: float = 1.0, clockwise: bool = true, duration: float = 0.0) -> GSFeature:
	var feature: GSFeature = get_feature_by_actuator_type(GSActuatorType.ROTATE)
	if not feature:
		return null
	_send_feature(feature, clampf(speed, 0.0, 1.0), duration, clockwise)
	return feature


## Attempts to oscillate the device. If no oscillate feature is available this does nothing.
## [br][br]
## [param intensity] is a value between [code]0.0[/code] and [code]1.0[/code] where [code]0.0[/code] 
## is no oscillation and [code]1.0[/code] is max oscillation.
## [br]
## [param duration] sets the duration, in seconds. A value of [code]0.0[/code] is always on.
func oscillate(intensity: float = 1.0, duration: float = 0.0) -> GSFeature:
	var feature: GSFeature = get_feature_by_actuator_type(GSActuatorType.OSCILLATE)
	if not feature:
		return null
	_send_feature(feature, clampf(intensity, 0.0, 1.0), duration)
	return feature


## Attempts to constrict the device. If no constrict feature is available this does nothing.
## [br][br]
## [param strength] is a value between [code]0.0[/code] and [code]1.0[/code] where [code]0.0[/code] 
## is no constriction and [code]1.0[/code] is max constriction.
## [br]
## [param duration] sets the duration, in seconds. A value of [code]0.0[/code] is always on.
func constrict(strength: float = 1.0, duration: float = 0.0) -> GSFeature:
	var feature: GSFeature = get_feature_by_actuator_type(GSActuatorType.CONSTRICT)
	if not feature:
		return null
	_send_feature(feature, clampf(strength, 0.0, 1.0), duration)
	return feature


## Attempts to inflate the device. If no inflate feature is available this does nothing.
## [br][br]
## [param strength] is a value between [code]0.0[/code] and [code]1.0[/code] where [code]0.0[/code] 
## is no inflation and [code]1.0[/code] is max inflation.
## [br]
## [param duration] sets the duration, in seconds. A value of [code]0.0[/code] is always on.
func inflate(strength: float = 1.0, duration: float = 0.0) -> GSFeature:
	var feature: GSFeature = get_feature_by_actuator_type(GSActuatorType.INFLATE)
	if not feature:
		return null
	_send_feature(feature, clampf(strength, 0.0, 1.0), duration)
	return feature


## Attempts to control a spray output using normalized intensity.
func spray(intensity: float = 1.0) -> GSFeature:
	return _set_output(GSOutputType.SPRAY, intensity)


## Attempts to set an LED brightness using normalized intensity.
func set_led(brightness: float = 1.0) -> GSFeature:
	return _set_output(GSOutputType.LED, brightness)


## Attempts to set temperature. Negative values cool, positive values heat.
func temperature(level: float = 0.0) -> GSFeature:
	var feature := _find_output(GSOutputType.TEMPERATURE)
	if not feature:
		return null
	level = clampf(level, -1.0, 1.0)
	var value: float = feature.value_range.y * level if level >= 0.0 else abs(feature.value_range.x) * level
	var client: Variant = GSUtil.get_client()
	if client:
		client.send_output_value(feature, roundi(value))
	return feature


## Attempts to move the device to the specified position. If no position feature is available this 
## does nothing.
## [br][br]
## [param duration] sets the duration, in seconds, that it should take for the device to reach the
## specified [param position].
## [br]
## [param position] is a value between [code]0.0[/code] and [code]1.0[/code] where [code]0.0[/code] 
## is the lowest position the device can reach and [code]1.0[/code] is the highest position.
## [br][br]
## Due to the duration required to move the device this method is async and can be awaited on.
func position(duration: float, position: float) -> GSFeature:
	var feature: GSFeature = _find_output(GSOutputType.HW_POSITION_WITH_DURATION)
	if not feature:
		feature = _find_output(GSOutputType.POSITION)
	if not feature:
		feature = get_feature_by_actuator_type(GSActuatorType.POSITION)
	if not feature:
		return null
	var client: Variant = GSUtil.get_client()
	if client:
		await client.send_feature(feature, clampf(position, 0.0, 1.0), duration)
	return feature


## Stops all active features on this device.
func stop() -> void:
	var client: Variant = GSUtil.get_client()
	if client:
		client.stop_device(device_index)
