extends Node
class_name GSClient

const CLIENT_NAME = "GSClient"
const CLIENT_VERSION = "1.0"
const MESSAGE_VERSION = 3

const ENABLE_RAW_CMD = false
const RAW_DISCLAIMER = "Raw commands are potentially dangerous and must be manually enabled."

enum ClientState {
	CONNECTING,
	HANDSHAKING,
	CONNECTED,
	DISCONNECTED
}

enum ErrorCode {
	UNKNOWN = 0,
	INIT = 1,
	PING = 2,
	MSG = 3,
	DEVICE = 4
}

signal client_connection_changed(connected)
signal client_error(error, message)
signal client_message(message)
signal client_frame_received(frame)
signal client_scan_finished()
signal client_device_list_received(devices)
signal client_device_added(device)
signal client_device_removed(device)
signal client_sensor_reading(id, device_index, sensor_index, sensor_type, data)
signal client_raw_reading(id, device_index, endpoint, data)
signal server_error(id, error, message)

var _ack_map: Dictionary = {}
var _device_map: Dictionary = {}
var _id: int = 1
var _peer: WebSocketPeer = WebSocketPeer.new()
var _scanning: bool = false
var _state: ClientState = ClientState.DISCONNECTED
var _timeout: float = 0.0


func _process(delta: float) -> void:
	_peer.poll()
	match _peer.get_ready_state():
		WebSocketPeer.STATE_CONNECTING:
			_on_peer_connecting(delta)
		WebSocketPeer.STATE_OPEN:
			if _state == ClientState.CONNECTING:
				_handshake()
			_consume_peer_packets()
		WebSocketPeer.STATE_CLOSING:
			if _state == ClientState.CONNECTED:
				_on_peer_closing()
		WebSocketPeer.STATE_CLOSED:
			if _state == ClientState.CONNECTED:
				_on_peer_closed()


func get_client_state() -> ClientState:
	return _state


func is_client_connected() -> bool:
	return get_client_state() == ClientState.CONNECTED


func start(server: String = "localhost", port: int = 12345, timeout: int = 60, options: TLSOptions = null) -> Error:
	client_message.emit("GSClient starting...")
	client_message.emit("Attempting to connect to %s on port %d..." % [ server, port ])
	var protocol = "ws" if not options else "wss"
	_timeout = float(timeout)
	var resp = _peer.connect_to_url("%s://%s:%d" % [ protocol, server, port ], options)
	if resp != OK:
		client_error.emit(resp, "Unable to connect to server.")
		set_process(false)
		_state = ClientState.DISCONNECTED
	else:
		set_process(true)
		_state = ClientState.CONNECTING
	return resp


func stop():
	_peer.close(1000, "Client requested shutdown.")
	client_message.emit("GSClient stopping...")


func scan_start():
	client_message.emit("Starting device scan...")
	send(GSStartScanning.new(_get_message_id()))
	_scanning = true


func scan_stop():
	if not _scanning:
		return
	client_message.emit("Ending device scan...")
	send(GSStopScanning.new(_get_message_id()))


func request_device_list():
	send(GSRequestDeviceList.new(_get_message_id()))
	client_message.emit("Requesting device list...")


func get_device(device_index: int) -> GSDevice:
	if _device_map.has(device_index):
		return _device_map[device_index]
	return null


func get_devices() -> Array[GSDevice]:
	return _device_map.values()


func send_scalar(device_index: int, feature_index: int, actuator_type: String, value: float):
	var scalar = GSScalar.new()
	scalar.index = feature_index
	scalar.actuator_type = actuator_type
	scalar.scalar = value
	send(GSScalarCmd.new(_get_message_id(), device_index, [ scalar ]))


func send_linear(device_index: int, feature_index: int, duration: int, value: float):
	var vector = GSVector.new()
	vector.index = feature_index
	vector.duration = duration
	vector.position = value
	send(GSLinearCmd.new(_get_message_id(), device_index, [ vector ]))
	await create_tween().tween_interval(float(duration) / 1000.0).finished


func send_rotate(device_index: int, feature_index: int, clockwise: bool, value: float):
	var rotation = GSRotation.new()
	rotation.index = feature_index
	rotation.clockwise = clockwise
	rotation.speed = value
	send(GSRotateCmd.new(_get_message_id(), device_index, [ rotation ]))


func read_sensor(device_index: int, sensor_index: int, sensor_type: String) -> int:
	var id = _get_message_id()
	send(GSSensorReadCmd.new(id, device_index, sensor_index, sensor_type))
	return id


func send_sensor_subscribe(device_index: int, sensor_index: int, sensor_type: String):
	send(GSSensorSubscribeCmd.new(_get_message_id(), device_index, sensor_index, sensor_type))


func send_sensor_unsubscribe(device_index: int, sensor_index: int, sensor_type: String):
	send(GSSensorUnsubscribeCmd.new(_get_message_id(), device_index, sensor_index, sensor_type))


func stop_device(device_index: int):
	send(GSStopDevice.new(_get_message_id(), device_index))


func stop_all_devices():
	send(GSStopAllDevices.new(_get_message_id()))


func raw_write(device_index: int, endpoint: String, data: PackedByteArray, write_with_response: bool):
	assert(ENABLE_RAW_CMD, RAW_DISCLAIMER)
	send(GSRawWriteCmd.new(_get_message_id(), device_index, endpoint, data, write_with_response))


func raw_read(device_index: int, endpoint: String, expected_length: int, wait_for_data: bool):
	assert(ENABLE_RAW_CMD, RAW_DISCLAIMER)
	send(GSRawReadCmd.new(_get_message_id(), device_index, endpoint, expected_length, wait_for_data))


func raw_subscribe(device_index: int, endpoint: String):
	assert(ENABLE_RAW_CMD, RAW_DISCLAIMER)
	send(GSRawSubscribeCmd.new(_get_message_id(), device_index, endpoint))


func raw_unsubscribe(device_index: int, endpoint: String):
	assert(ENABLE_RAW_CMD, RAW_DISCLAIMER)
	send(GSRawUnsubscribeCmd.new(_get_message_id(), device_index, endpoint))


func send(message: GSMessage):
	_ack_map[message.get_id()] = message
	client_message.emit("Sending message: %s" % message)
	_peer.send_text(JSON.stringify([ message.serialize() ]))


func _on_connect_timeout():
	if _state == ClientState.CONNECTING:
		set_process(false)
		_state = ClientState.DISCONNECTED
		_peer.close(1001, "Client connection timeout.")
		client_error.emit(ERR_TIMEOUT, "Connection timed out!")
		client_connection_changed.emit(false)


func _get_message_id() -> int:
	var id = _id
	_id += 1
	return id


func _handshake():
	send(GSRequestServerInfo.new(_get_message_id()))
	_state = ClientState.HANDSHAKING


func _consume_peer_packets():
	while _peer.get_available_packet_count():
		var frame = _peer.get_packet().get_string_from_utf8()
		client_frame_received.emit(frame)
		var data = JSON.parse_string(frame)
		if data == null:
			client_error.emit(ERR_INVALID_DATA, "Invalid data frame received from server: %s" % frame)
			continue
		for msg in data:
			var message = GSMessage.deserialize(msg)
			match message.message_type:
				GSMessage.MESSAGE_TYPE_OK:
					_ack(message.get_id())
				GSMessage.MESSAGE_TYPE_ERROR:
					_ack(message.get_id())
					var error_code = message.fields[GSMessage.MESSAGE_FIELD_ERROR_CODE]
					var error_message = message.fields[GSMessage.MESSAGE_FIELD_ERROR_MESSAGE]
					server_error.emit(message.get_id(), error_code, error_message)
				GSMessage.MESSAGE_TYPE_SERVER_INFO:
					if _state == ClientState.HANDSHAKING:
						_ack(1)
						_state = ClientState.CONNECTED
						var server_name = message.fields[GSMessage.MESSAGE_FIELD_SERVER_NAME]
						client_message.emit("GSClient connected to %s!" % server_name)
						client_connection_changed.emit(true)
				GSMessage.MESSAGE_TYPE_DEVICE_LIST:
					for device_data in message.fields[GSMessage.MESSAGE_FIELD_DEVICES]:
						var device = GSDevice.deserialize(device_data)
						_device_map[device.device_index] = device
					client_device_list_received.emit(_device_map.values())
				GSMessage.MESSAGE_TYPE_DEVICE_ADDED:
					var device = GSDevice.deserialize(message.fields)
					_device_map[device.device_index] = device
					client_device_added.emit(device)
				GSMessage.MESSAGE_TYPE_DEVICE_REMOVED:
					var device_index = int(message.fields[GSMessage.MESSAGE_FIELD_DEVICE_INDEX])
					if _device_map.has(device_index):
						var device = _device_map[device_index]
						_device_map.erase(device_index)
						client_device_removed.emit(device)
				GSMessage.MESSAGE_TYPE_SCANNING_FINISHED:
					_scanning = false
					client_scan_finished.emit()
				GSMessage.MESSAGE_TYPE_SENSOR_READING:
					_ack(message.get_id())
					var id = message.get_id()
					var device_index: int = message.fields[GSMessage.MESSAGE_FIELD_DEVICE_INDEX]
					var sensor_index: int = message.fields[GSMessage.MESSAGE_FIELD_SENSOR_INDEX]
					var sensor_type = message.fields[GSMessage.MESSAGE_FIELD_SENSOR_TYPE]
					var sensor_data = message.fields[GSMessage.MESSAGE_FIELD_DATA]
					client_sensor_reading.emit(id, device_index, sensor_index, sensor_type, sensor_data)
				GSMessage.MESSAGE_TYPE_RAW_READING:
					_ack(message.get_id())
					var id = message.get_id()
					var device_index: int = message.fields[GSMessage.MESSAGE_FIELD_DEVICE_INDEX]
					var endpoint = message.fields[GSMessage.MESSAGE_FIELD_ENDPOINT]
					var raw_data: PackedByteArray = message.fields[GSMessage.MESSAGE_FIELD_DATA]
					client_raw_reading.emit(id, device_index, endpoint, raw_data)
				_:
					client_message.emit("Unrecognized message type: %s" % message.message_type)


func _ack(ack_id: int):
	if _ack_map.has(ack_id):
		_ack_map.erase(ack_id)


func _on_peer_connecting(delta: float):
	if _timeout > 0.0:
		_timeout -= delta
		if _timeout <= 0.0:
			_timeout = 0.0
			_on_connect_timeout()


func _on_peer_closing():
	# NOP
	pass


func _on_peer_closed():
	var code = _peer.get_close_code()
	var reason = _peer.get_close_reason()
	client_message.emit("GSClient closed with code %d, reason: %s" % [ code, reason ])
	set_process(false)
	_state = ClientState.DISCONNECTED
	client_connection_changed.emit(false)
