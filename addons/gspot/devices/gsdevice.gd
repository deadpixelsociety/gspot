class_name GSDevice
extends RefCounted

var device_name: String
var device_display_name: String
var device_index: int = -1
var device_message_timing_gap: int
var features: Array[GSFeature] = []


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


func get_display_name() -> String:
	if not GSUtil.ne(device_display_name):
		return device_display_name
	return device_name


func has_feature(feature_command: String) -> bool:
	return features.any(func(f): return f.feature_command == feature_command)


func get_features_by_command(feature_command: String) -> Array[GSFeature]:
	var list: Array[GSFeature] = []
	list.assign(features.filter(func(f: GSFeature): return f.feature_command == feature_command))
	return list


func get_feature(feature_command: String) -> GSFeature:
	var features: Array[GSFeature] = get_features_by_command(feature_command)
	if features.size() > 0:
		return features.front()
	return null


func get_features_by_actuator_type(actuator_type: String) -> Array[GSFeature]:
	var list: Array[GSFeature] = []
	list.assign(features.filter(func(f: GSFeature): return f.actuator_type == actuator_type))
	return list


func get_feature_by_actuator_type(actuator_type: String) -> GSFeature:
	var features: Array[GSFeature] = get_features_by_actuator_type(actuator_type)
	if features.size() > 0:
		return features.front()
	return null


func get_message_rate() -> float:
	var rate: float = float(device_message_timing_gap) / 1000.0
	if rate <= 0.0:
		return GSUtil.get_project_value(GSConstants.PROJECT_SETTINGS_MESSAGE_RATE, GSConstants.MESSAGE_RATE)
	return rate


func vibrate(intensity: float, duration: float = 0.0) -> GSFeature:
	var feature: GSFeature = get_feature_by_actuator_type(GSActuatorType.VIBRATE)
	if not feature:
		return null
	GSClient.send_feature(feature, clampf(intensity, 0.0, 1.0), duration)
	return feature


func rotate(speed: float, clockwise: bool = true, duration: float = 0.0) -> GSFeature:
	var feature: GSFeature = get_feature_by_actuator_type(GSActuatorType.ROTATE)
	if not feature:
		return null
	GSClient.send_feature(feature, clampf(speed, 0.0, 1.0), duration, clockwise)
	return feature


func oscillate(intensity: float, duration: float = 0.0) -> GSFeature:
	var feature: GSFeature = get_feature_by_actuator_type(GSActuatorType.OSCILLATE)
	if not feature:
		return null
	GSClient.send_feature(feature, clampf(intensity, 0.0, 1.0), duration)
	return feature


func constrict(strength: float, duration: float = 0.0) -> GSFeature:
	var feature: GSFeature = get_feature_by_actuator_type(GSActuatorType.CONSTRICT)
	if not feature:
		return null
	GSClient.send_feature(feature, clampf(strength, 0.0, 1.0), duration)
	return feature


func inflate(strength: float, duration: float = 0.0) -> GSFeature:
	var feature: GSFeature = get_feature_by_actuator_type(GSActuatorType.INFLATE)
	if not feature:
		return null
	GSClient.send_feature(feature, clampf(strength, 0.0, 1.0), duration)
	return feature


func position(position: float, duration: float) -> GSFeature:
	var feature: GSFeature = get_feature_by_actuator_type(GSActuatorType.POSITION)
	if not feature:
		return null
	await GSClient.send_feature(feature, clampf(position, 0.0, 1.0), duration)
	return feature


func stop() -> void:
	GSClient.stop_device(device_index)
