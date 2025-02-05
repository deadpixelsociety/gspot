extends Node

const MESSAGE_VERSION: int = 3
const DEFAULT_HOST: String = "127.0.0.1"
const DEFAULT_PORT: int = 12345
const DEFAULT_PING_TIME: int = 1000 * 30 # 30 seconds
const RAW_DISCLAIMER: String = "Raw commands are potentially dangerous and must be manually enabled."
const EXTENSIONS_DIR: String = "extensions"


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

enum LogLevel {
	VERBOSE,
	DEBUG,
	WARN,
	ERROR
}


class FeatureDuration extends Node:
	var client: GSClient
	var feature: GSFeature
	var duration: float = 0.0
	
	
	func _ready() -> void:
		name = "FeatureDuration-%s-%s" % [ feature.device.get_display_name(), feature.get_display_name() ]
	
	
	func _process(delta: float) -> void:
		if not client or not feature:
			return
		if duration > 0.0:
			duration -= delta
			if duration <= 0.0:
				client.stop_feature(feature)
				kill()
	
	
	func kill() -> void:
		duration = 0.0
		var key = client._get_feature_key(feature)
		client._durations.erase(key)
		queue_free()



signal client_connection_changed(connected)
signal client_device_added(device)
signal client_device_list_received(devices)
signal client_device_removed(device)
signal client_error(error, message)
signal client_frame_received(frame)
signal client_message(message)
signal client_raw_reading(id, device_index, endpoint, data)
signal client_scan_finished()
signal client_sensor_reading(id, device_index, sensor_index, sensor_type, data)
signal server_error(id, error, message)


var extensions_dir: String = EXTENSIONS_DIR

var _hostname: String = DEFAULT_HOST
var _port: int = 12345
var _server_name: String
var _message_version: int
var _max_ping_time: int
var _ack_map: Dictionary = {}
var _device_map: Dictionary = {}
var _id: int = 1
var _message_handlers: Dictionary = {}
var _peer: WebSocketPeer = WebSocketPeer.new()
var _ping: float = 0.0
var _scanning: bool = false
var _state: ClientState = ClientState.DISCONNECTED
var _timeout: float = 0.0
var _durations: Dictionary = {}
var _log_level: LogLevel = LogLevel.VERBOSE
var _extension_map: Dictionary = {}


func _init() -> void:
	add_message_handler(GSMessage.MESSAGE_TYPE_OK, _on_message_ok)
	add_message_handler(GSMessage.MESSAGE_TYPE_ERROR, _on_message_error)
	add_message_handler(GSMessage.MESSAGE_TYPE_SERVER_INFO, _on_message_server_info)
	add_message_handler(GSMessage.MESSAGE_TYPE_DEVICE_LIST, _on_message_device_list)
	add_message_handler(GSMessage.MESSAGE_TYPE_DEVICE_ADDED, _on_message_device_added)
	add_message_handler(GSMessage.MESSAGE_TYPE_DEVICE_REMOVED, _on_message_device_removed)
	add_message_handler(GSMessage.MESSAGE_TYPE_SCANNING_FINISHED, _on_message_scanning_finished)
	add_message_handler(GSMessage.MESSAGE_TYPE_SENSOR_READING, _on_message_sensor_reading)
	add_message_handler(GSMessage.MESSAGE_TYPE_RAW_READING, _on_message_raw_reading)


func _process(delta: float) -> void:
	_check_ping(delta)
	_process_peer(delta)


func _enter_tree() -> void:
	init_extensions()
	load_extensions()


func _exit_tree() -> void:
	unload_extensions()


func get_client_name() -> String:
	return GSUtil.get_project_value(GSConstants.PROJECT_SETTING_CLIENT_NAME, GSConstants.CLIENT_NAME)


func get_client_version() -> String:
	return GSUtil.get_project_value(GSConstants.PROJECT_SETTING_CLIENT_VERSION, GSConstants.CLIENT_VERSION)


func get_client_string() -> String:
	return "%s v%s" % [ get_client_name(), get_client_version() ]


func is_raw_command_enabled() -> bool:
	return GSUtil.get_project_value(GSConstants.PROJECT_SETTING_ENABLE_RAW_COMMANDS, false)


func get_hostname() -> String:
	return _hostname


func get_port() -> int:
	return _port


func get_server_name() -> String:
	return _server_name


func get_message_version() -> int:
	return _message_version


func get_max_ping_time() -> int:
	return _max_ping_time


func get_client_state() -> ClientState:
	return _state


func is_client_connected() -> bool:
	return get_client_state() == ClientState.CONNECTED


func add_message_handler(message_type: String, handler: Callable):
	_message_handlers[message_type] = handler


func remove_message_handler(message_type: String) -> bool:
	return _message_handlers.erase(message_type)


func set_log_level(level: LogLevel) -> void:
	_log_level = level


func get_log_level() -> LogLevel:
	return _log_level


func _log(level: LogLevel, message: String) -> void:
	if level >= _log_level:
		client_message.emit(message)


func _error(error: Error, message: String) -> void:
	_log(LogLevel.ERROR, message)
	client_error.emit(error, message)


func start(hostname: String = DEFAULT_HOST, port: int = DEFAULT_PORT, timeout: int = 60, options: TLSOptions = null) -> Error:
	_log(LogLevel.VERBOSE, "%s starting..." % get_client_string())
	_log(LogLevel.DEBUG, "Attempting to connect to %s on port %d..." % [ hostname, port ])
	var protocol = "ws" if not options else "wss"
	_hostname = hostname
	_port = port
	_timeout = float(timeout)
	var resp = _peer.connect_to_url("%s://%s:%d" % [ protocol, hostname, port ], options)
	if resp != OK:
		_error(resp, "Unable to connect to server.")
		set_process(false)
		_state = ClientState.DISCONNECTED
	else:
		set_process(true)
		_state = ClientState.CONNECTING
	return resp


func stop():
	_peer.close(1000, "Client requested shutdown.")
	_log(LogLevel.VERBOSE, "%s stopping..." % get_client_string())


func scan_start():
	_log(LogLevel.DEBUG, "Starting device scan...")
	send(GSStartScanning.new(_get_message_id()))
	_scanning = true


func scan_stop():
	if not _scanning:
		return
	_log(LogLevel.DEBUG, "Ending device scan...")
	send(GSStopScanning.new(_get_message_id()))


func request_device_list():
	send(GSRequestDeviceList.new(_get_message_id()))
	_log(LogLevel.DEBUG, "Requesting device list...")


func get_device(device_index: int) -> GSDevice:
	if _device_map.has(device_index):
		return _device_map[device_index]
	return null


func get_devices() -> Array[GSDevice]:
	var list: Array[GSDevice] = []
	for device in _device_map.values():
		list.append(device)
	return list


func send_feature(feature: GSFeature, value: float, duration: float = 0.0, clockwise: bool = true):
	if not feature or not feature.device:
		return
	match feature.feature_command:
		GSMessage.MESSAGE_TYPE_SCALAR_CMD:
			send_scalar(feature.device.device_index, feature.feature_index, feature.actuator_type, value)
			if duration > 0.0:
				_create_feature_duration(feature, duration)
		GSMessage.MESSAGE_TYPE_ROTATE_CMD:
			send_rotate(feature.device.device_index, feature.feature_index, clockwise, value)
			if duration > 0.0:
				_create_feature_duration(feature, duration)
		GSMessage.MESSAGE_TYPE_LINEAR_CMD:
			await send_linear(feature.device.device_index, feature.feature_index, duration, value)


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


func stop_feature(feature: GSFeature):
	if not feature or not feature.device:
		return
	match feature.feature_command:
		GSMessage.MESSAGE_TYPE_SCALAR_CMD:
			send_scalar(feature.device.device_index, feature.feature_index, feature.actuator_type, 0.0)
		GSMessage.MESSAGE_TYPE_ROTATE_CMD:
			send_rotate(feature.device.device_index, feature.feature_index, true, 0.0)
		GSMessage.MESSAGE_TYPE_LINEAR_CMD:
			# Linear features move into a position over a duration and stop. Sending a stop for 
			# these is not needed.
			pass


func stop_device(device_index: int):
	send(GSStopDevice.new(_get_message_id(), device_index))


func stop_all_devices():
	send(GSStopAllDevices.new(_get_message_id()))


func raw_write(device_index: int, endpoint: String, data: PackedByteArray, write_with_response: bool):
	assert(is_raw_command_enabled(), RAW_DISCLAIMER)
	send(GSRawWriteCmd.new(_get_message_id(), device_index, endpoint, data, write_with_response))


func raw_read(device_index: int, endpoint: String, expected_length: int, wait_for_data: bool):
	assert(is_raw_command_enabled(), RAW_DISCLAIMER)
	send(GSRawReadCmd.new(_get_message_id(), device_index, endpoint, expected_length, wait_for_data))


func raw_subscribe(device_index: int, endpoint: String):
	assert(is_raw_command_enabled(), RAW_DISCLAIMER)
	send(GSRawSubscribeCmd.new(_get_message_id(), device_index, endpoint))


func raw_unsubscribe(device_index: int, endpoint: String):
	assert(is_raw_command_enabled(), RAW_DISCLAIMER)
	send(GSRawUnsubscribeCmd.new(_get_message_id(), device_index, endpoint))


func send(message: GSMessage):
	_ack_map[message.get_id()] = message
	_log(LogLevel.DEBUG, "Sending message: %s" % message)
	_peer.send_text(JSON.stringify([ message.serialize() ]))


func has_ext(extension_name: String) -> bool:
	return _extension_map.has(extension_name)


func ext(extension_name: String) -> Variant:
	if has_ext(extension_name):
		return _extension_map[extension_name]
	return null


func ext_call(extension_name: String, method_name: String, args: Array = []) -> Variant:
	var extension = ext(extension_name)
	if not extension or not extension.has_method(method_name):
		return null
	return extension.callv(method_name, args)


func init_extensions() -> void:
	_extension_map.clear()
	var script: Script = get_script()
	var script_path := script.resource_path.get_base_dir()
	_populate_extension_map(script_path, extensions_dir)


func load_extensions() -> void:
	var extensions := _prioritize_extensions()
	for ext: GSExtension in extensions:
		_log(LogLevel.DEBUG, "Loading '%s'..." % ext.get_extension_name())
		if not ext.load_extension(self):
			_log(LogLevel.DEBUG, "!! Extension load failed and removed from extension list.")
			_extension_map.erase(ext.get_extension_name())
		else:
			_log(LogLevel.DEBUG, "** Extension loaded!")


func unload_extensions() -> void:
	var extensions := _prioritize_extensions()
	for i in range(extensions.size() - 1, -1, -1):
		_log(LogLevel.DEBUG, "Unloading extension %s..." % extensions[i].get_extension_name())
		extensions[i].unload_extension(self)


func _populate_extension_map(current_dir: String, ext_dir: String) -> void:
	var extension_path := "%s/%s" % [ current_dir, ext_dir ]
	
	var dir := DirAccess.open(extension_path)
	if not dir:
		return
	
	_log(LogLevel.DEBUG, "Loading extensions from %s..." % extension_path)
	
	dir.list_dir_begin()
	var filename := dir.get_next()
	while filename != "":
		if dir.current_is_dir():
			_populate_extension_map(extension_path, filename)
		else:
			if filename.contains(".gd"):
				var res := ResourceLoader.load("%s/%s" % [ extension_path, filename ])
				if res is Script:
					var ext_script = res.new()
					if ext_script is GSExtension and not ext_script.get_script() == GSExtension:
						_log(LogLevel.DEBUG, "Found extension %s." % filename)
						_extension_map[ext_script.get_extension_name()] = ext_script
		filename = dir.get_next()


func _prioritize_extensions() -> Array:
	var extensions := _extension_map.values()
	extensions.sort_custom(func(a: GSExtension, b: GSExtension):
		return a.get_extension_priority() > b.get_extension_priority()
	)
	return extensions


func _check_ping(delta: float):
	if _max_ping_time <= 0.0:
		return
	if get_client_state() != ClientState.CONNECTED:
		return
	_ping -= delta
	if _ping <= 0.0:
		_ping = float(_max_ping_time) / 1000.0
		send(GSPing.new(_get_message_id()))


func _process_peer(delta: float):
	_peer.poll()
	match _peer.get_ready_state():
		WebSocketPeer.STATE_CONNECTING:
			_on_peer_connecting(delta)
		WebSocketPeer.STATE_OPEN:
			if _state == ClientState.CONNECTING:
				_handshake()
			_consume_peer_packets()
		WebSocketPeer.STATE_CLOSING:
			if _state in [ ClientState.CONNECTING, ClientState.CONNECTED ]:
				_on_peer_closing()
		WebSocketPeer.STATE_CLOSED:
			if _state in [ ClientState.CONNECTING, ClientState.CONNECTED ]:
				_on_peer_closed()


func _on_connect_timeout():
	if _state == ClientState.CONNECTING:
		set_process(false)
		_state = ClientState.DISCONNECTED
		_peer.close(1001, "Client connection timeout.")
		_error(ERR_TIMEOUT, "Connection timed out!")
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
			_log(LogLevel.WARN, "Invalid data frame received from server: %s" % frame)
			continue
		for msg in data:
			var message = GSMessage.deserialize(msg)
			_on_handle_message(message)


func _on_message_ok(message: GSMessage):
	_ack(message.get_id())


func _on_message_error(message: GSMessage):
	_ack(message.get_id())
	var error_code = message.fields[GSMessage.MESSAGE_FIELD_ERROR_CODE]
	var error_message = message.fields[GSMessage.MESSAGE_FIELD_ERROR_MESSAGE]
	server_error.emit(message.get_id(), error_code, error_message)


func _on_message_server_info(message: GSMessage):
	if _state == ClientState.HANDSHAKING:
		_ack(1)
		_state = ClientState.CONNECTED
		_server_name = message.fields[GSMessage.MESSAGE_FIELD_SERVER_NAME]
		_message_version = int(message.fields[GSMessage.MESSAGE_FIELD_MESSAGE_VERSION])
		_max_ping_time = int(message.fields[GSMessage.MESSAGE_FIELD_MAX_PING_TIME])
		if _max_ping_time <= 0:
			_max_ping_time = DEFAULT_PING_TIME
		_log(LogLevel.VERBOSE, "%s connected to %s!" % [ get_client_string(), _server_name ])
		client_connection_changed.emit(true)


func _on_message_device_list(message: GSMessage):
	_ack(message.get_id())
	for device_data in message.fields[GSMessage.MESSAGE_FIELD_DEVICES]:
		var device = GSDevice.deserialize(device_data)
		_device_map[device.device_index] = device
	client_device_list_received.emit(_device_map.values())


func _on_message_device_added(message: GSMessage):
	var device = GSDevice.deserialize(message.fields)
	_device_map[device.device_index] = device
	client_device_added.emit(device)


func _on_message_device_removed(message: GSMessage):
	var device_index = int(message.fields[GSMessage.MESSAGE_FIELD_DEVICE_INDEX])
	if _device_map.has(device_index):
		var device = _device_map[device_index]
		_device_map.erase(device_index)
		client_device_removed.emit(device)


func _on_message_scanning_finished(message: GSMessage):
	_scanning = false
	client_scan_finished.emit()


func _on_message_sensor_reading(message: GSMessage):
	_ack(message.get_id())
	var id = message.get_id()
	var device_index: int = message.fields[GSMessage.MESSAGE_FIELD_DEVICE_INDEX]
	var sensor_index: int = message.fields[GSMessage.MESSAGE_FIELD_SENSOR_INDEX]
	var sensor_type = message.fields[GSMessage.MESSAGE_FIELD_SENSOR_TYPE]
	var sensor_data = message.fields[GSMessage.MESSAGE_FIELD_DATA]
	client_sensor_reading.emit(id, device_index, sensor_index, sensor_type, sensor_data)


func _on_message_raw_reading(message: GSMessage):
	_ack(message.get_id())
	var id = message.get_id()
	var device_index: int = message.fields[GSMessage.MESSAGE_FIELD_DEVICE_INDEX]
	var endpoint = message.fields[GSMessage.MESSAGE_FIELD_ENDPOINT]
	var raw_data: PackedByteArray = message.fields[GSMessage.MESSAGE_FIELD_DATA]
	client_raw_reading.emit(id, device_index, endpoint, raw_data)


func _on_handle_message(message: GSMessage):
	if not _message_handlers.has(message.message_type):
		_on_unhandled_message(message)
		return
	var handler = _message_handlers[message.message_type] as Callable
	handler.call(message)


func _on_unhandled_message(message: GSMessage):
	_log(LogLevel.WARN, "Unrecognized message type: %s" % message.message_type)


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
	_log(LogLevel.DEBUG, "%s closed with code %d, reason: %s" % [ get_client_string(), code, reason ])
	set_process(false)
	_reset()
	client_connection_changed.emit(false)


func _reset():
	_ack_map.clear()
	_device_map.clear()
	_id = 1
	_ping = 0.0
	_scanning = false
	_timeout = 0.0
	_state = ClientState.DISCONNECTED


func _get_feature_key(feature: GSFeature) -> int:
	return feature.device.device_index * 1000 + feature.feature_index


func _get_feature_duration(feature: GSFeature) -> FeatureDuration:
	var key = _get_feature_key(feature)
	var duration = _durations.get(key, null)
	if not duration:
		duration = FeatureDuration.new()
		duration.client = self
		duration.feature = feature
		_durations[key] = duration
		add_child(duration)
	return duration


func _create_feature_duration(feature: GSFeature, duration: float) -> void:
	var feature_duration = _get_feature_duration(feature)
	feature_duration.duration = duration


