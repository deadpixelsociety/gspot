extends RefCounted
class_name GSDevice

var device_name: String
var device_display_name: String
var device_index: int
var device_message_timing_gap: int
var features: Array[GSFeature] = []


static func deserialize(data: Dictionary) -> GSDevice:
	var device = GSDevice.new()
	if data.has(GSMessage.MESSAGE_FIELD_DEVICE_NAME):
		device.device_name = data[GSMessage.MESSAGE_FIELD_DEVICE_NAME]
	if data.has(GSMessage.MESSAGE_FIELD_DEVICE_DISPLAY_NAME):
		device.device_display_name = data[GSMessage.MESSAGE_FIELD_DEVICE_DISPLAY_NAME]
	if data.has(GSMessage.MESSAGE_FIELD_DEVICE_INDEX):
		device.device_index = data[GSMessage.MESSAGE_FIELD_DEVICE_INDEX]
	if data.has(GSMessage.MESSAGE_FIELD_DEVICE_MESSAGE_TIMING_GAP):
		device.device_message_timing_gap = data[GSMessage.MESSAGE_FIELD_DEVICE_MESSAGE_TIMING_GAP]
	if data.has(GSMessage.MESSAGE_FIELD_DEVICE_MESSAGES):
		var messages = data[GSMessage.MESSAGE_FIELD_DEVICE_MESSAGES]
		for feature_command in messages.keys():
			var features = messages[feature_command]
			if features is Array:
				for i in features.size():
					var feature_data = features[i]
					device.features.append(GSFeature.deserialize(feature_command, i, feature_data))
			elif features is Dictionary:
				device.features.append(GSFeature.deserialize(feature_command, 0, features))
	return device


func get_display_name() -> String:
	if device_display_name != null and device_display_name.length() > 0:
		return device_display_name
	return device_name


func has_feature(feature: String) -> bool:
	return features.any(func(f): return f.feature_command == feature)


func get_feature(feature: String) -> GSFeature:
	var results = features.filter(func(f): return f.feature_command == feature)
	if results.size() > 0:
		return results.front()
	return null
