class_name GSDevice
extends RefCounted
## Represents a buttplug.io device interface. 
##
## GSDevice contains information about the device such as device name, display name and its index, 
## as well as the features it contains. Also present are helper methods to quickly access device 
## features such as [method vibrate], [method rotate], and [method position].
##
## @tutorial(Spec Reference): https://buttplug-spec.docs.buttplug.io/docs/spec/enumeration#devicelist

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
static func deserialize(data: Dictionary) -> GSDevice:
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
	GSClient.send_feature(feature, clampf(intensity, 0.0, 1.0), duration)
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
	GSClient.send_feature(feature, clampf(speed, 0.0, 1.0), duration, clockwise)
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
	GSClient.send_feature(feature, clampf(intensity, 0.0, 1.0), duration)
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
	GSClient.send_feature(feature, clampf(strength, 0.0, 1.0), duration)
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
	GSClient.send_feature(feature, clampf(strength, 0.0, 1.0), duration)
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
## Due to the duration required to move the device this method is asyc and can be awaited on.
func position(duration: float, position: float) -> GSFeature:
	var feature: GSFeature = get_feature_by_actuator_type(GSActuatorType.POSITION)
	if not feature:
		return null
	await GSClient.send_feature(feature, clampf(position, 0.0, 1.0), duration)
	return feature


## Stops all active features on this device.
func stop() -> void:
	GSClient.stop_device(device_index)
