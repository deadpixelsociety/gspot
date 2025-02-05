class_name GSMessage
extends RefCounted

const MESSAGE_TYPE_OK: String = "Ok"
const MESSAGE_TYPE_ERROR: String = "Error"
const MESSAGE_TYPE_PING: String = "Ping"
const MESSAGE_TYPE_REQUEST_SERVER_INFO: String = "RequestServerInfo"
const MESSAGE_TYPE_SERVER_INFO: String = "ServerInfo"
const MESSAGE_TYPE_START_SCANNING: String = "StartScanning"
const MESSAGE_TYPE_STOP_SCANNING: String = "StopScanning"
const MESSAGE_TYPE_SCANNING_FINISHED: String = "ScanningFinished"
const MESSAGE_TYPE_REQUEST_DEVICE_LIST: String = "RequestDeviceList"
const MESSAGE_TYPE_DEVICE_LIST: String = "DeviceList"
const MESSAGE_TYPE_DEVICE_ADDED: String = "DeviceAdded"
const MESSAGE_TYPE_DEVICE_REMOVED: String = "DeviceRemoved"
const MESSAGE_TYPE_STOP_DEVICE_CMD: String = "StopDeviceCmd"
const MESSAGE_TYPE_STOP_ALL_DEVICES: String = "StopAllDevices"
const MESSAGE_TYPE_SCALAR_CMD: String = "ScalarCmd"
const MESSAGE_TYPE_LINEAR_CMD: String = "LinearCmd"
const MESSAGE_TYPE_ROTATE_CMD: String = "RotateCmd"
const MESSAGE_TYPE_SENSOR_READ_CMD: String = "SensorReadCmd"
const MESSAGE_TYPE_SENSOR_READING: String = "SensorReading"
const MESSAGE_TYPE_SENSOR_SUBSCRIBE_CMD: String = "SensorSubscribeCmd"
const MESSAGE_TYPE_SENSOR_UNSUBSCRIBE_CMD: String = "SensorUnsubscribeCmd"
const MESSAGE_TYPE_RAW_WRITE_CMD: String = "RawWriteCmd"
const MESSAGE_TYPE_RAW_READ_CMD: String = "RawReadCmd"
const MESSAGE_TYPE_RAW_READING: String = "RawReading"
const MESSAGE_TYPE_RAW_SUBSCRIBE_CMD: String = "RawSubscribeCmd"
const MESSAGE_TYPE_RAW_UNSUBSCRIBE_CMD: String = "RawUnsubscribeCmd"
const MESSAGE_FIELD_ID: String = "Id"
const MESSAGE_FIELD_ERROR_MESSAGE: String = "ErrorMessage"
const MESSAGE_FIELD_ERROR_CODE: String = "ErrorCode"
const MESSAGE_FIELD_CLIENT_NAME: String = "ClientName"
const MESSAGE_FIELD_MESSAGE_VERSION: String = "MessageVersion"
const MESSAGE_FIELD_SERVER_NAME: String = "ServerName"
const MESSAGE_FIELD_MAX_PING_TIME: String = "MaxPingTime"
const MESSAGE_FIELD_DEVICES: String = "Devices"
const MESSAGE_FIELD_DEVICE_NAME: String = "DeviceName"
const MESSAGE_FIELD_DEVICE_INDEX: String = "DeviceIndex"
const MESSAGE_FIELD_DEVICE_MESSAGE_TIMING_GAP: String = "DeviceMessageTimingGap"
const MESSAGE_FIELD_DEVICE_DISPLAY_NAME: String = "DeviceDisplayName"
const MESSAGE_FIELD_DEVICE_MESSAGES: String = "DeviceMessages"
const MESSAGE_FIELD_FEATURE_DESCRIPTOR: String = "FeatureDescriptor"
const MESSAGE_FIELD_STEP_COUNT: String = "StepCount"
const MESSAGE_FIELD_ACTUATOR_TYPE: String = "ActuatorType"
const MESSAGE_FIELD_SENSOR_TYPE: String = "SensorType"
const MESSAGE_FIELD_SENSOR_RANGE: String = "SensorRange"
const MESSAGE_FIELD_ENDPOINTS: String = "Endpoints"
const MESSAGE_FIELD_SCALARS: String = "Scalars"
const MESSAGE_FIELD_INDEX: String = "Index"
const MESSAGE_FIELD_SCALAR: String = "Scalar"
const MESSAGE_FIELD_VECTORS: String = "Vectors"
const MESSAGE_FIELD_DURATION: String = "Duration"
const MESSAGE_FIELD_POSITION: String = "Position"
const MESSAGE_FIELD_ROTATIONS: String = "Rotations"
const MESSAGE_FIELD_SPEED: String = "Speed"
const MESSAGE_FIELD_CLOCKWISE: String = "Clockwise"
const MESSAGE_FIELD_SENSOR_INDEX: String = "SensorIndex"
const MESSAGE_FIELD_DATA: String = "Data"
const MESSAGE_FIELD_ENDPOINT: String = "Endpoint"
const MESSAGE_FIELD_WRITE_WITH_RESPONSE: String = "WriteWithResponse"
const MESSAGE_FIELD_EXPECTED_LENGTH: String = "ExpectedLength"
const MESSAGE_FIELD_WAIT_FOR_DATA: String = "WaitForData"
const SENSOR_TYPE_BATTERY: String = "Battery"

var message_type: String
var fields: Dictionary = {}


func _init(message_id: int = 0) -> void:
	fields[MESSAGE_FIELD_ID] = message_id


static func deserialize(data: Dictionary) -> GSMessage:
	var message := GSMessage.new()
	message.message_type = data.keys().front()
	message.fields = data[message.message_type]
	return message


func get_id() -> int:
	return fields[MESSAGE_FIELD_ID]


func serialize() -> Dictionary:
	return {
		message_type: fields
	}


func _to_string() -> String:
	return JSON.stringify(serialize())
