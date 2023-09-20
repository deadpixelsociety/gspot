extends RefCounted
class_name GSFeature


var device: GSDevice
var feature_command: String
var feature_index: int
var feature_descriptor: String
var step_count: int
var actuator_type: String
var sensor_type: String
var sensor_range: Array[GSSensorRange] = []
var endpoints: PackedStringArray = PackedStringArray()


static func deserialize(command: String, index: int, data: Dictionary) -> GSFeature:
	var feature = GSFeature.new()
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
		for range in data[GSMessage.MESSAGE_FIELD_SENSOR_RANGE]:
			feature.sensor_range.append(GSSensorRange.new(range[0], range[1]))
	if data.has(GSMessage.MESSAGE_FIELD_ENDPOINTS):
		for endpoint in data[GSMessage.MESSAGE_FIELD_ENDPOINTS]:
			feature.endpoints.append(endpoint)
	return feature


func get_display_name() -> String:
	if feature_descriptor != null and feature_descriptor != "" and feature_descriptor != "N/A":
		return feature_descriptor
	if actuator_type != null and actuator_type != "":
		return actuator_type
	return feature_command
