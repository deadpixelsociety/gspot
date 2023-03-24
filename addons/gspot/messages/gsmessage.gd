extends RefCounted
class_name GSMessage

const MESSAGE_TYPE_OK = "Ok"
const MESSAGE_TYPE_ERROR = "Error"
const MESSAGE_TYPE_PING = "Ping"
const MESSAGE_TYPE_REQUEST_SERVER_INFO = "RequestServerInfo"
const MESSAGE_TYPE_SERVER_INFO = "ServerInfo"
const MESSAGE_TYPE_START_SCANNING = "StartScanning"
const MESSAGE_TYPE_STOP_SCANNING = "StopScanning"
const MESSAGE_TYPE_SCANNING_FINISHED = "ScanningFinished"
const MESSAGE_TYPE_REQUEST_DEVICE_LIST = "RequestDeviceList"
const MESSAGE_TYPE_DEVICE_LIST = "DeviceList"
const MESSAGE_TYPE_DEVICE_ADDED = "DeviceAdded"
const MESSAGE_TYPE_DEVICE_REMOVED = "DeviceRemoved"
const MESSAGE_TYPE_STOP_DEVICE_CMD = "StopDeviceCmd"
const MESSAGE_TYPE_STOP_ALL_DEVICES = "StopAllDevices"
const MESSAGE_TYPE_SCALAR_CMD = "ScalarCmd"
const MESSAGE_TYPE_LINEAR_CMD = "LinearCmd"
const MESSAGE_TYPE_ROTATE_CMD = "RotateCmd"
const MESSAGE_TYPE_SENSOR_READ_CMD = "SensorReadCmd"
const MESSAGE_TYPE_SENSOR_READING = "SensorReading"
const MESSAGE_TYPE_SENSOR_SUBSCRIBE_CMD = "SensorSubscribeCmd"
const MESSAGE_TYPE_SENSOR_UNSUBSCRIBE_CMD = "SensorUnsubscribeCmd"
const MESSAGE_TYPE_RAW_WRITE_CMD = "RawWriteCmd"
const MESSAGE_TYPE_RAW_READ_CMD = "RawReadCmd"
const MESSAGE_TYPE_RAW_READING = "RawReading"
const MESSAGE_TYPE_RAW_SUBSCRIBE_CMD = "RawSubscribeCmd"
const MESSAGE_TYPE_RAW_UNSUBSCRIBE_CMD = "RawUnsubscribeCmd"

const MESSAGE_FIELD_ID = "Id"
const MESSAGE_FIELD_ERROR_MESSAGE = "ErrorMessage"
const MESSAGE_FIELD_ERROR_CODE = "ErrorCode"
const MESSAGE_FIELD_CLIENT_NAME = "ClientName"
const MESSAGE_FIELD_MESSAGE_VERSION = "MessageVersion"
const MESSAGE_FIELD_SERVER_NAME = "ServerName"
const MESSAGE_FIELD_MAX_PING_TIME = "MaxPingTime"
const MESSAGE_FIELD_DEVICES = "Devices"
const MESSAGE_FIELD_DEVICE_NAME = "DeviceName"
const MESSAGE_FIELD_DEVICE_INDEX = "DeviceIndex"
const MESSAGE_FIELD_DEVICE_MESSAGE_TIMING_GAP = "DeviceMessageTimingGap"
const MESSAGE_FIELD_DEVICE_DISPLAY_NAME = "DeviceDisplayName"
const MESSAGE_FIELD_DEVICE_MESSAGES = "DeviceMessages"
const MESSAGE_FIELD_FEATURE_DESCRIPTOR = "FeatureDescriptor"
const MESSAGE_FIELD_STEP_COUNT = "StepCount"
const MESSAGE_FIELD_ACTUATOR_TYPE = "ActuatorType"
const MESSAGE_FIELD_SENSOR_TYPE = "SensorType"
const MESSAGE_FIELD_SENSOR_RANGE = "SensorRange"
const MESSAGE_FIELD_ENDPOINTS = "Endpoints"
const MESSAGE_FIELD_SCALARS = "Scalars"
const MESSAGE_FIELD_INDEX = "Index"
const MESSAGE_FIELD_SCALAR = "Scalar"
const MESSAGE_FIELD_VECTORS = "Vectors"
const MESSAGE_FIELD_DURATION = "Duration"
const MESSAGE_FIELD_POSITION = "Position"
const MESSAGE_FIELD_ROTATIONS = "Rotations"
const MESSAGE_FIELD_SPEED = "Speed"
const MESSAGE_FIELD_CLOCKWISE = "Clockwise"
const MESSAGE_FIELD_SENSOR_INDEX = "SensorIndex"
const MESSAGE_FIELD_DATA = "Data"
const MESSAGE_FIELD_ENDPOINT = "Endpoint"
const MESSAGE_FIELD_WRITE_WITH_RESPONSE = "WriteWithResponse"
const MESSAGE_FIELD_EXPECTED_LENGTH = "ExpectedLength"
const MESSAGE_FIELD_WAIT_FOR_DATA = "WaitForData"

const SENSOR_TYPE_BATTERY = "Battery"

var message_type: String
var fields: Dictionary = {}


func _init(message_id: int = 0) -> void:
	fields[MESSAGE_FIELD_ID] = message_id


static func deserialize(data: Dictionary) -> GSMessage:
	var message = GSMessage.new()
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
