extends Node
## The gspot client implementation for interacting with a buttplug.io server.
##
## This client implementation handles all message communication with the buttplug.io server it 
## connects to and relays messages back to the developer via signals. This is the main interface for
## requesting devices ([method request_device_list]) and sending commands to activate features 
## [method send_feature].
##
## @tutorial(Spec Reference): https://buttplug.io/docs/spec/

## Legacy v3 protocol version constant retained for source compatibility.
const MESSAGE_VERSION: int = GSConstants.MESSAGE_VERSION
const PROTOCOL_VERSION_MAJOR: int = 4
const PROTOCOL_VERSION_MINOR: int = 0
## The default server host to connect to.
const DEFAULT_HOST: String = "127.0.0.1"
## The default server port to connect to.
const DEFAULT_PORT: int = 12345
## The default ping time.
const DEFAULT_PING_TIME: int = 1000 * 30 # 30 seconds
## A disclaimer that is displayed if any of the raw commands are used without first doing an opt-in 
## through the project settings.
const RAW_DISCLAIMER: String = "Raw commands are potentially dangerous and must be manually enabled."
## The subdirectory where extensions are loaded from.
const EXTENSIONS_DIR: String = "extensions"

## Enumerates possible client states.
enum ClientState {
	## THe client is attempting to connect to the server.
	CONNECTING,
	## The client has connected to the server and passing initial information.
	HANDSHAKING,
	## The client has completed handshaking and is connected.
	CONNECTED,
	## The client is disconnected from the server.
	DISCONNECTED,
}

## Selects the protocol offered during the next connection.
enum ProtocolMode {
	AUTO,
	SPEC_V4,
	SPEC_V3,
}

## Enumerates possible server error codes.
enum ErrorCode {
	UNKNOWN = 0,
	INIT = 1,
	PING = 2,
	MSG = 3,
	DEVICE = 4,
}

## Enumerates available logging levels.
enum LogLevel {
	VERBOSE,
	DEBUG,
	WARN,
	ERROR,
}

## Emitted when the client connection state has changed.
signal client_connection_changed(connected: bool)
## Emitted when a device has been added to the device list.
signal client_device_added(device: GSDevice)
## Emitted when a device list has been received from the server.
signal client_device_list_received(devices: Array[GSDevice])
## Emitted when a device has been removed from the device list.
signal client_device_removed(device: GSDevice)
## Emitted when a client error has occurred.
signal client_error(error: int, message: String)
## Emitted when frame data has been received from the server.
signal client_frame_received(frame: String)
## Emitted when the client sends a message.
signal client_message(message: String)
## Emitted when a value has returned from [method raw_read].
signal client_raw_reading(id: int, device_index: int, endpoint: String, data: PackedByteArray)
## Emitted when a device scan has finished and [method get_devices] can be called.
signal client_scan_finished()
## Emitted when a value has returned from [method read_sensor].
signal client_sensor_reading(
	id: int, 
	device_index: int, 
	sensor_index: int, 
	sensor_type: String, 
	data: PackedInt32Array
)
## Emitted when a server error has occurred.
signal server_error(id: int, error: int, message: String)

## Defines the subdirectory where extensions are loaded from.
var extensions_dir: String = EXTENSIONS_DIR
var _hostname: String = DEFAULT_HOST
var _port: int = 12345
var _server_name: String
var _message_version: int
var _protocol_version_minor: int
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
var _protocol_handler: GSProtocolHandler
var _protocol_mode_override: int = -1
var _fallback_attempted: bool = false
var _connect_options: TLSOptions


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
	add_message_handler(GSMessage.MESSAGE_TYPE_INPUT_READING, _on_message_input_reading)


func _enter_tree() -> void:
	init_extensions()
	load_extensions()


func _exit_tree() -> void:
	unload_extensions()


func _process(delta: float) -> void:
	_check_ping(delta)
	_process_peer(delta)


## Returns the client name as specified in the project settings. Defaults to 
## [constant GSConstants.CLIENT_NAME].
func get_client_name() -> String:
	return GSUtil.get_project_value(GSConstants.PROJECT_SETTING_CLIENT_NAME, GSConstants.CLIENT_NAME)


## Returns the client version as specified in the project settings. Defaults to 
## [constant GSConstants.CLIENT_VERSION].
func get_client_version() -> String:
	return GSUtil.get_project_value(GSConstants.PROJECT_SETTING_CLIENT_VERSION, GSConstants.CLIENT_VERSION)


## Returns a formatted client value in the format of: GSClient v3.0.0.
func get_client_string() -> String:
	return "%s v%s" % [ get_client_name(), get_client_version() ]


## Determines if raw commands have been opted into.
func is_raw_command_enabled() -> bool:
	return GSUtil.get_project_value(GSConstants.PROJECT_SETTING_ENABLE_RAW_COMMANDS, false)


## Returns the connected hostname.
func get_hostname() -> String:
	return _hostname


## Returns the connected port.
func get_port() -> int:
	return _port


## Returns the connected server's name.
func get_server_name() -> String:
	return _server_name


## Returns the connected server's major protocol version.
## Deprecated: use [method get_protocol_version_major].
func get_message_version() -> int:
	return _message_version


## Returns the negotiated protocol major version.
func get_protocol_version_major() -> int:
	return _message_version


## Returns the negotiated protocol minor version.
func get_protocol_version_minor() -> int:
	return _protocol_version_minor


## Sets the protocol mode used by subsequent connections.
func set_protocol_mode(mode: ProtocolMode) -> void:
	_protocol_mode_override = clampi(int(mode), ProtocolMode.AUTO, ProtocolMode.SPEC_V3)


## Gets the configured protocol mode.
func get_protocol_mode() -> ProtocolMode:
	if _protocol_mode_override >= 0:
		return _protocol_mode_override
	var configured := int(ProjectSettings.get_setting(GSConstants.PROJECT_SETTING_PROTOCOL_MODE, ProtocolMode.AUTO))
	return clampi(configured, ProtocolMode.AUTO, ProtocolMode.SPEC_V3)


## Returns the connected server's max ping time.
func get_max_ping_time() -> int:
	return _max_ping_time


## Returns the current [enum ClientState].
func get_client_state() -> ClientState:
	return _state


## Determines if the client is currently connected to a server.
func is_client_connected() -> bool:
	return get_client_state() == ClientState.CONNECTED


## Adds a message handler to handle the specified message type. This allows the developer override 
## specific message functionality without needing to modify the GSClient itself.
func add_message_handler(message_type: String, handler: Callable):
	_message_handlers[message_type] = handler


## Removes the message handler for the specified message type. Returns [code]true[/code] if it was 
## removed successfully.
func remove_message_handler(message_type: String) -> bool:
	return _message_handlers.erase(message_type)


## Sets the current [enum LogLevel]. Any logged messages below this level will not be sent via 
## [signal client_message].
func set_log_level(level: LogLevel) -> void:
	_log_level = level


## Gets the current [enum LogLevel].
func get_log_level() -> LogLevel:
	return _log_level


## Logs a [enum LogLevel.VERBOSE] message.
func logv(message: String) -> void:
	_log(LogLevel.VERBOSE, message)


## Logs a [enum LogLevel.DEBUG] message.
func logd(message: String) -> void:
	_log(LogLevel.DEBUG, message)


## Logs a [enum LogLevel.WARN] message.
func logw(message: String) -> void:
	_log(LogLevel.WARN, message)


## Logs a [enum LogLevel.ERROR] message with an optional [enum Error] code.
func loge(message: String, error: Error = FAILED) -> void:
	_error(error, message)


## Starts the client and connects to the specified server hostname and port. If the connection does 
## not happen within the specified [param timeout] value an error will be raised. If any 
## [param options] are defined then a secure connection will be attempted.
func start(
	hostname: String = DEFAULT_HOST, 
	port: int = DEFAULT_PORT, 
	timeout: int = 60, 
	options: TLSOptions = null
) -> Error:
	logv("%s starting..." % get_client_string())
	logd("Attempting to connect to %s on port %d..." % [ hostname, port ])
	_hostname = hostname
	_port = port
	_connect_options = options
	_fallback_attempted = false
	_protocol_handler = _create_protocol_handler()
	_timeout = float(timeout)
	var resp: Error = _connect_transport()
	if resp != OK:
		loge("Unable to connect to server.", resp)
		set_process(false)
		_state = ClientState.DISCONNECTED
	else:
		set_process(true)
		_state = ClientState.CONNECTING
	return resp


## Stops the client and disconnects from a connected server.
func stop() -> void:
	if _peer.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		_peer.close(1000, "Client requested shutdown.")
	logv("%s stopping..." % get_client_string())


## Begins a device scan. Any devices found will be emitted via [signal client_device_added].
func scan_start() -> void:
	logd("Starting device scan...")
	if _protocol_handler:
		send(_protocol_handler.create_start_scanning(_get_message_id()))
	_scanning = true


## Stops an active device scan.
func scan_stop() -> void:
	if not _scanning:
		return
	logd("Ending device scan...")
	if _protocol_handler:
		send(_protocol_handler.create_stop_scanning(_get_message_id()))


## Requests the server's known device list. The list is returned via 
## [signal client_device_list_received].
func request_device_list() -> void:
	if _protocol_handler:
		send(_protocol_handler.create_request_device_list(_get_message_id()))
	logd("Requesting device list...")


## Gets a list of all known devices.
func get_devices() -> Array[GSDevice]:
	var list: Array[GSDevice] = []
	list.assign(_device_map.values())
	return list


## Gets a device at the specified index.
func get_device(device_index: int) -> GSDevice:
	if _device_map.has(device_index):
		return _device_map[device_index]
	return null


## Attempts to find a device by its display name. See [method GSDevice.get_display_name].
func get_device_by_name(device_name: String) -> GSDevice:
	var devices = get_devices().filter(func(device: GSDevice): return device.get_display_name() == device_name)
	if devices.size() > 0:
		return devices.front()
	return null


## Sends a feature activation to the server. 
## [br][br]
## [param feature] is the feature to activate.
## [br]
## [param value] is a value between [code]0.0[/code] and [code]1.0[/code] where [code]0.0[/code] 
## is no activation and [code]1.0[/code] is max activation.
## [br]
## [param duration] is expressed in seconds. Linear durations are converted to milliseconds
## before the protocol message is created. A value of [code]0.0[/code] is always on.
## [br]
## [param clockwise] sets the direction of rotation. Only applicable for rotation actuators.
## [br][br]
## If the feature is a LinearCmd this method can be awaited on.
func send_feature(
	feature: GSFeature, 
	value: float, 
	duration: float = 0.0, 
	clockwise: bool = true
) -> void:
	if not feature or not feature.device:
		return
	if not _protocol_handler:
		return
	var duration_seconds := maxf(duration, 0.0)
	var duration_ms := _duration_to_milliseconds(duration_seconds)
	var message := _protocol_handler.create_output(
		_get_message_id(), feature, value, duration_ms, clockwise
	)
	if message:
		send(message)
		if (
			feature.output_type in [GSOutputType.POSITION, GSOutputType.HW_POSITION_WITH_DURATION]
			or feature.feature_command == GSMessage.MESSAGE_TYPE_LINEAR_CMD
		):
			await create_tween().tween_interval(duration_seconds).finished
		elif duration_seconds > 0.0:
			_create_feature_duration(feature, duration_seconds)


## Sends an exact protocol output value. This is primarily useful for signed v4 outputs.
## [param duration] is expressed in seconds and converted to protocol milliseconds internally.
func send_output_value(feature: GSFeature, value: int, duration: float = 0.0) -> void:
	if not feature or not feature.device or not _protocol_handler:
		return
	var duration_ms := _duration_to_milliseconds(duration)
	var message := _protocol_handler.create_output_value(_get_message_id(), feature, value, duration_ms)
	if message:
		send(message)


## Sends a scalar command to the server.
## [br][br]
## [param device_index] is the device's index.
## [br]
## [param feature_index] is the feature index on the device.
## [br]
## [param actuator_type] is the actuator type of the feature.
## [br]
## [param value] is a value between [code]0.0[/code] and [code]1.0[/code] where [code]0.0[/code] 
## is no activation and [code]1.0[/code] is max activation.
func send_scalar(
	device_index: int, 
	feature_index: int, 
	actuator_type: String, 
	value: float
) -> void:
	var feature := _find_feature(device_index, feature_index, actuator_type, true)
	if feature and _protocol_handler:
		var message := _protocol_handler.create_output(_get_message_id(), feature, value, 0, true)
		if message:
			send(message)
		return
	if _protocol_handler and _protocol_handler.get_major_version() == 3:
		var scalar := GSScalar.new()
		scalar.index = feature_index
		scalar.actuator_type = actuator_type
		scalar.scalar = value
		send(GSScalarCmd.new(_get_message_id(), device_index, [ scalar ]))


## Sends a linear command to the server.
## [br][br]
## [param device_index] is the device's index.
## [br]
## [param feature_index] is the feature index on the device.
## [br]
## [param duration] sets the duration, in seconds, that it should take for the device to reach the
## specified [param position].
## [br]
## [param position] is a value between [code]0.0[/code] and [code]1.0[/code] where [code]0.0[/code] 
## is the lowest position the device can reach and [code]1.0[/code] is the highest position.
func send_linear(device_index: int, feature_index: int, duration: float, position: float) -> void:
	var duration_seconds := maxf(duration, 0.0)
	var duration_ms := _duration_to_milliseconds(duration_seconds)
	var feature := _find_feature(device_index, feature_index, GSActuatorType.POSITION, true)
	if feature and _protocol_handler:
		var message := _protocol_handler.create_output(_get_message_id(), feature, position, duration_ms, true)
		if message:
			send(message)
	elif _protocol_handler and _protocol_handler.get_major_version() == 3:
		var vector := GSVector.new()
		vector.index = feature_index
		vector.duration = duration_ms
		vector.position = position
		send(GSLinearCmd.new(_get_message_id(), device_index, [vector]))
	else:
		return
	await create_tween().tween_interval(duration_seconds).finished


## Sends a rotate command to the server.
## [br][br]
## [param device_index] is the device's index.
## [br]
## [param feature_index] is the feature index on the device.
## [br]
## [param clockwise] sets the direction of rotation.
## [br]
## [param speed] is a value between [code]0.0[/code] and [code]1.0[/code] where [code]0.0[/code] 
## is no movement and [code]1.0[/code] is max speed.
func send_rotate(device_index: int, feature_index: int, clockwise: bool, speed: float) -> void:
	var feature := _find_feature(device_index, feature_index, GSActuatorType.ROTATE, true)
	if feature and _protocol_handler:
		var message := _protocol_handler.create_output(_get_message_id(), feature, speed, 0, clockwise)
		if message:
			send(message)
	elif _protocol_handler and _protocol_handler.get_major_version() == 3:
		var rotation := GSRotation.new()
		rotation.index = feature_index
		rotation.clockwise = clockwise
		rotation.speed = speed
		send(GSRotateCmd.new(_get_message_id(), device_index, [rotation]))


## Begins a sensor read of the specified device sensor. The read value will be returned via 
## [signal client_sensor_reading]. 
## [br][br]
## This function returns the message ID that was sent to the server requesting the sensor value. 
## This can be matched up with the ID value returned in [signal client_sensor_reading].
## [br][br]
## [param device_index] is the device's index.
## [br]
## [param sensor_index] is the sensor index on the device.
## [br]
## [param sensor_type] is the sensor type to read.
func read_sensor(device_index: int, sensor_index: int, sensor_type: String) -> int:
	var id = _get_message_id()
	var feature := _find_feature(device_index, sensor_index, sensor_type, false)
	if feature and _protocol_handler:
		var message := _protocol_handler.create_input(id, feature, "Read")
		if message:
			send(message)
	elif _protocol_handler and _protocol_handler.get_major_version() == 3:
		send(GSSensorReadCmd.new(id, device_index, sensor_index, sensor_type))
	return id


## Subscribes to a stream of data from the specified device sensor. The read values will be 
## returned via [signal client_sensor_reading]. 
## [br][br]
## [param device_index] is the device's index.
## [br]
## [param sensor_index] is the sensor index on the device.
## [br]
## [param sensor_type] is the sensor type to read.
func send_sensor_subscribe(device_index: int, sensor_index: int, sensor_type: String) -> void:
	var feature := _find_feature(device_index, sensor_index, sensor_type, false)
	if feature and _protocol_handler:
		var message := _protocol_handler.create_input(_get_message_id(), feature, "Subscribe")
		if message:
			send(message)
	elif _protocol_handler and _protocol_handler.get_major_version() == 3:
		send(GSSensorSubscribeCmd.new(_get_message_id(), device_index, sensor_index, sensor_type))


## Unsubscribes from a stream of data from the specified device sensor.
## [br][br]
## [param device_index] is the device's index.
## [br]
## [param sensor_index] is the sensor index on the device.
## [br]
## [param sensor_type] is the sensor type to read.
func send_sensor_unsubscribe(device_index: int, sensor_index: int, sensor_type: String) -> void:
	var feature := _find_feature(device_index, sensor_index, sensor_type, false)
	if feature and _protocol_handler:
		var message := _protocol_handler.create_input(_get_message_id(), feature, "Unsubscribe")
		if message:
			send(message)
	elif _protocol_handler and _protocol_handler.get_major_version() == 3:
		send(GSSensorUnsubscribeCmd.new(_get_message_id(), device_index, sensor_index, sensor_type))


## Stops the specified device feature.
func stop_feature(feature: GSFeature) -> void:
	if not feature or not feature.device:
		return
	if not _protocol_handler:
		return
	if feature.is_input():
		if feature.can_subscribe():
			var unsubscribe := _protocol_handler.create_input(_get_message_id(), feature, "Unsubscribe")
			if unsubscribe:
				send(unsubscribe)
		return
	if (
		_protocol_handler.get_major_version() >= 4
		and feature.output_type in [GSOutputType.POSITION, GSOutputType.HW_POSITION_WITH_DURATION]
	):
		# v4 position commands are expected to finish their movement and have no
		# feature-scoped stop operation. Device-wide StopCmd remains available.
		return
	if _protocol_handler.get_major_version() < 4:
		if feature.feature_command in [GSMessage.MESSAGE_TYPE_SCALAR_CMD, GSMessage.MESSAGE_TYPE_ROTATE_CMD]:
			var legacy_stop := _protocol_handler.create_output(_get_message_id(), feature, 0.0, 0, true)
			if legacy_stop:
				send(legacy_stop)
		return
	var message := _protocol_handler.create_stop(
		_get_message_id(), feature.device.device_index, feature.feature_index, false, true
	)
	if message:
		send(message)


## Stops all features of the specified device index.
func stop_device(device_index: int) -> void:
	if _protocol_handler:
		send(_protocol_handler.create_stop(_get_message_id(), device_index, null, true, true))


## Stops all active devices.
func stop_all_devices() -> void:
	if _protocol_handler:
		send(_protocol_handler.create_stop(_get_message_id(), null, null, true, true))


## Sends the specified message to the server.
func send(message: GSMessage) -> void:
	if not message or _peer.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	_ack_map[message.get_id()] = message
	logv("Sending message: %s" % message)
	_peer.send_text(JSON.stringify([ message.serialize() ]))


## Determines if the specified extension has been loaded.
func has_ext(extension_name: String) -> bool:
	return _extension_map.has(extension_name)


## Returns the specified extension object.
func ext(extension_name: String) -> Variant:
	if has_ext(extension_name):
		return _extension_map[extension_name]
	return null


## Calls a method on the specified extension. Returns [code]null[/code] if the extension or 
## specified method does not exist.
func ext_call(extension_name: String, method_name: String, args: Array = []) -> Variant:
	var extension = ext(extension_name)
	if not extension or not extension.has_method(method_name):
		return null
	return extension.callv(method_name, args)


## Locates and maps available extensions. Called automatically during [method Node._enter_tree].
func init_extensions() -> void:
	_extension_map.clear()
	var script: Script = get_script()
	var script_path := script.resource_path.get_base_dir()
	_populate_extension_map(script_path, extensions_dir)


## Attempts to load available extensions. Called automatically during [method Node._enter_tree].
func load_extensions() -> void:
	var extensions: Array[GSExtension] = _prioritize_extensions()
	for ext: GSExtension in extensions:
		logv("Loading '%s'..." % ext.get_extension_name())
		if not ext.load_extension(self):
			logw("!! Extension load failed and removed from extension list.")
			_extension_map.erase(ext.get_extension_name())
		else:
			logv("** Extension loaded!")


## Unloads previously loaded extensions. Called automatically during [method Node._exit_tree].
func unload_extensions() -> void:
	var extensions: Array[GSExtension] = _prioritize_extensions()
	for i in range(extensions.size() - 1, -1, -1):
		logv("Unloading extension %s..." % extensions[i].get_extension_name())
		extensions[i].unload_extension(self)


## Deprecated v3 raw command write. Must be opted into via the project settings.
func raw_write(
	device_index: int, 
	endpoint: String, 
	data: PackedByteArray, 
	write_with_response: bool
) -> void:
	assert(is_raw_command_enabled(), RAW_DISCLAIMER)
	if not _protocol_handler or not _protocol_handler.supports_raw():
		_error(ERR_UNAVAILABLE, "Raw commands are unavailable under protocol v4.")
		return
	send(GSRawWriteCmd.new(_get_message_id(), device_index, endpoint, data, write_with_response))


## Deprecated v3 raw command read. Must be opted into via the project settings.
func raw_read(
	device_index: int, 
	endpoint: String, 
	expected_length: int, 
	wait_for_data: bool
) -> void:
	assert(is_raw_command_enabled(), RAW_DISCLAIMER)
	if not _protocol_handler or not _protocol_handler.supports_raw():
		_error(ERR_UNAVAILABLE, "Raw commands are unavailable under protocol v4.")
		return
	send(GSRawReadCmd.new(_get_message_id(), device_index, endpoint, expected_length, wait_for_data))


## Deprecated v3 raw command subscribe. Must be opted into via the project settings.
func raw_subscribe(device_index: int, endpoint: String) -> void:
	assert(is_raw_command_enabled(), RAW_DISCLAIMER)
	if not _protocol_handler or not _protocol_handler.supports_raw():
		_error(ERR_UNAVAILABLE, "Raw commands are unavailable under protocol v4.")
		return
	send(GSRawSubscribeCmd.new(_get_message_id(), device_index, endpoint))


## Deprecated v3 raw command unsubscribe. Must be opted into via the project settings.
func raw_unsubscribe(device_index: int, endpoint: String) -> void:
	assert(is_raw_command_enabled(), RAW_DISCLAIMER)
	if not _protocol_handler or not _protocol_handler.supports_raw():
		_error(ERR_UNAVAILABLE, "Raw commands are unavailable under protocol v4.")
		return
	send(GSRawUnsubscribeCmd.new(_get_message_id(), device_index, endpoint))


func _log(level: LogLevel, message: String) -> void:
	if level >= _log_level:
		client_message.emit(message)


func _error(error: Error, message: String) -> void:
	_log(LogLevel.ERROR, message)
	client_error.emit(error, message)


func _check_ping(delta: float) -> void:
	if _max_ping_time <= 0.0:
		return
	if get_client_state() != ClientState.CONNECTED:
		return
	_ping -= delta
	if _ping <= 0.0:
		_ping = float(_max_ping_time) / 1000.0
		if _protocol_handler:
			send(_protocol_handler.create_ping(_get_message_id()))


func _process_peer(delta: float) -> void:
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


func _on_connect_timeout() -> void:
	if _state in [ClientState.CONNECTING, ClientState.HANDSHAKING]:
		set_process(false)
		_state = ClientState.DISCONNECTED
		_peer.close(1001, "Client connection timeout.")
		loge("Connection timed out!", ERR_TIMEOUT)
		client_connection_changed.emit(false)


func _get_message_id() -> int:
	var id: int = _id
	_id += 1
	return id


func _duration_to_milliseconds(duration_seconds: float) -> int:
	return maxi(roundi(maxf(duration_seconds, 0.0) * 1000.0), 0)


func _handshake() -> void:
	if not _protocol_handler:
		_protocol_handler = _create_protocol_handler()
	send(_protocol_handler.create_request_server_info(_get_message_id(), get_client_string()))
	_state = ClientState.HANDSHAKING


func _consume_peer_packets() -> void:
	while _peer.get_available_packet_count():
		var frame: String = _peer.get_packet().get_string_from_utf8()
		client_frame_received.emit(frame)
		var data := JSON.parse_string(frame) as Array
		if data == null:
			logw("Invalid data frame received from server: %s" % frame)
			continue
		for msg in data:
			if not msg is Dictionary:
				logw("Invalid message received from server: %s" % msg)
				continue
			var message = GSMessage.deserialize(msg)
			if not message:
				logw("Invalid message received from server: %s" % msg)
				continue
			_on_handle_message(message)
			if _state == ClientState.DISCONNECTED:
				break


func _on_message_ok(message: GSMessage) -> void:
	_ack(message.get_id())


func _on_message_error(message: GSMessage) -> void:
	_ack(message.get_id())
	var error_code: int = int(message.fields.get(GSMessage.MESSAGE_FIELD_ERROR_CODE, ErrorCode.UNKNOWN))
	var error_message: String = str(message.fields.get(GSMessage.MESSAGE_FIELD_ERROR_MESSAGE, "Unknown server error"))
	if (
		_state == ClientState.HANDSHAKING
		and get_protocol_mode() == ProtocolMode.AUTO
		and _protocol_handler
		and _protocol_handler.get_major_version() == PROTOCOL_VERSION_MAJOR
		and not _fallback_attempted
		and error_code == ErrorCode.INIT
	):
		_fallback_attempted = true
		logw("Protocol v4 handshake rejected; retrying with protocol v3.")
		_retry_with_v3()
		return
	server_error.emit(message.get_id(), error_code, error_message)


func _on_message_server_info(message: GSMessage) -> void:
	if _state == ClientState.HANDSHAKING:
		_ack(message.get_id())
		var info := _protocol_handler.parse_server_info(message.fields)
		var negotiated_major := int(info.get("major", 0))
		if negotiated_major != _protocol_handler.get_major_version():
			_error(ERR_UNAVAILABLE, "Server negotiated unsupported protocol major %d." % negotiated_major)
			_peer.close(1002, "Unsupported protocol version.")
			return
		_state = ClientState.CONNECTED
		_server_name = str(info.get("server_name", ""))
		_message_version = negotiated_major
		_protocol_version_minor = int(info.get("minor", 0))
		_max_ping_time = int(info.get("max_ping_time", 0))
		_ping = float(_max_ping_time) / 1000.0 if _max_ping_time > 0 else 0.0
		logv("%s connected to %s!" % [ get_client_string(), _server_name ])
		client_connection_changed.emit(true)


func _on_message_device_list(message: GSMessage) -> void:
	_ack(message.get_id())
	if _protocol_handler:
		_apply_device_snapshot(_protocol_handler.parse_devices(message.fields))


func _on_message_device_added(message: GSMessage) -> void:
	if _protocol_handler and _protocol_handler.get_major_version() >= 4:
		logw("Ignoring deprecated DeviceAdded message under protocol v4; waiting for DeviceList snapshot.")
		return
	var device: GSDevice = GSDevice.deserialize(message.fields, 3)
	_device_map[device.device_index] = device
	client_device_added.emit(device)


func _on_message_device_removed(message: GSMessage) -> void:
	if _protocol_handler and _protocol_handler.get_major_version() >= 4:
		logw("Ignoring deprecated DeviceRemoved message under protocol v4; waiting for DeviceList snapshot.")
		return
	var device_index := int(message.fields[GSMessage.MESSAGE_FIELD_DEVICE_INDEX])
	if _device_map.has(device_index):
		var device: GSDevice = get_device(device_index)
		_device_map.erase(device_index)
		client_device_removed.emit(device)


func _on_message_scanning_finished(message: GSMessage) -> void:
	_scanning = false
	client_scan_finished.emit()


func _on_message_sensor_reading(message: GSMessage) -> void:
	_ack(message.get_id())
	if not _protocol_handler:
		return
	var reading := _protocol_handler.parse_input_reading(message.fields)
	if reading.is_empty():
		return
	client_sensor_reading.emit(
		int(reading.get("id", 0)),
		int(reading.get("device_index", -1)),
		int(reading.get("feature_index", -1)),
		str(reading.get("input_type", "")),
		reading.get("data", PackedInt32Array())
	)


func _on_message_input_reading(message: GSMessage) -> void:
	_on_message_sensor_reading(message)


func _on_message_raw_reading(message: GSMessage) -> void:
	_ack(message.get_id())
	var id: int = message.get_id()
	var device_index: int = message.fields[GSMessage.MESSAGE_FIELD_DEVICE_INDEX]
	var endpoint: String = message.fields[GSMessage.MESSAGE_FIELD_ENDPOINT]
	var raw_data: PackedByteArray = message.fields[GSMessage.MESSAGE_FIELD_DATA]
	client_raw_reading.emit(id, device_index, endpoint, raw_data)


func _on_handle_message(message: GSMessage) -> void:
	if not _message_handlers.has(message.message_type):
		_on_unhandled_message(message)
		return
	var handler: Callable = _message_handlers[message.message_type]
	handler.call(message)


func _on_unhandled_message(message: GSMessage) -> void:
	logw("Unrecognized message type: %s" % message.message_type)


func _ack(ack_id: int) -> void:
	if _ack_map.has(ack_id):
		_ack_map.erase(ack_id)


func _on_peer_connecting(delta: float) -> void:
	if _timeout <= 0.0:
		return
	_timeout -= delta
	if _timeout <= 0.0:
		_timeout = 0.0
		_on_connect_timeout()


func _on_peer_closing() -> void:
	# NOP
	pass


func _on_peer_closed() -> void:
	var code: int = _peer.get_close_code()
	var reason: String = _peer.get_close_reason()
	logd("%s closed with code %d, reason: %s" % [ get_client_string(), code, reason ])
	set_process(false)
	_reset()
	client_connection_changed.emit(false)


func _reset() -> void:
	_ack_map.clear()
	_device_map.clear()
	for duration in _durations.values():
		if is_instance_valid(duration):
			duration.queue_free()
	_durations.clear()
	_id = 1
	_ping = 0.0
	_scanning = false
	_timeout = 0.0
	_message_version = 0
	_protocol_version_minor = 0
	_max_ping_time = 0
	_protocol_handler = null
	_state = ClientState.DISCONNECTED


func _create_protocol_handler() -> GSProtocolHandler:
	match get_protocol_mode():
		ProtocolMode.SPEC_V3:
			return GSProtocolV3.new()
		_:
			return GSProtocolV4.new()


func _connect_transport() -> Error:
	var protocol: String = "ws" if not _connect_options else "wss"
	_peer = WebSocketPeer.new()
	return _peer.connect_to_url("%s://%s:%d" % [ protocol, _hostname, _port ], _connect_options)


func _retry_with_v3() -> void:
	set_process(false)
	_peer.close(1000, "Retrying with protocol v3.")
	_ack_map.clear()
	_device_map.clear()
	_protocol_handler = GSProtocolV3.new()
	_state = ClientState.DISCONNECTED
	call_deferred("_begin_v3_retry")


func _begin_v3_retry() -> void:
	if get_client_state() != ClientState.DISCONNECTED:
		return
	var response := _connect_transport()
	if response != OK:
		_error(response, "Unable to reconnect using protocol v3.")
		return
	_state = ClientState.CONNECTING
	set_process(true)


func _find_feature(device_index: int, feature_index: int, type_name: String, output: bool) -> GSFeature:
	var device := get_device(device_index)
	if not device:
		return null
	for feature in device.features:
		if feature.feature_index != feature_index:
			continue
		if output and feature.is_output() and (feature.output_type == type_name or feature.actuator_type == type_name):
			return feature
		if not output and feature.is_input() and (feature.input_type == type_name or feature.sensor_type == type_name):
			return feature
	return null


func _apply_device_snapshot(devices: Array) -> void:
	var incoming: Dictionary = {}
	for device in devices:
		if device is GSDevice:
			incoming[device.device_index] = device
	for old_index in _device_map.keys().duplicate():
		if not incoming.has(old_index):
			var removed: GSDevice = _device_map[old_index]
			_device_map.erase(old_index)
			client_device_removed.emit(removed)
	for device_index in incoming.keys():
		var incoming_device: GSDevice = incoming[device_index]
		if _device_map.has(device_index):
			var retained: GSDevice = _device_map[device_index]
			retained.update_from(incoming_device)
		else:
			_device_map[device_index] = incoming_device
			client_device_added.emit(incoming_device)
	var list: Array[GSDevice] = []
	list.assign(_device_map.values())
	list.sort_custom(func(a: GSDevice, b: GSDevice): return a.device_index < b.device_index)
	client_device_list_received.emit(list)


func _get_feature_key(feature: GSFeature) -> String:
	return "%d:%s" % [feature.device.device_index, feature.get_capability_key()]


func _get_feature_duration(feature: GSFeature) -> GSFeatureDuration:
	var key: String = _get_feature_key(feature)
	var duration: GSFeatureDuration = _durations.get(key, null)
	if not duration:
		duration = GSFeatureDuration.new()
		duration.feature = feature
		duration.client = self
		_durations[key] = duration
		add_child(duration)
	return duration


func _create_feature_duration(feature: GSFeature, duration: float) -> void:
	var feature_duration: GSFeatureDuration = _get_feature_duration(feature)
	feature_duration.duration = duration


func _populate_extension_map(current_dir: String, ext_dir: String) -> void:
	var extension_path := "%s/%s" % [ current_dir, ext_dir ]
	
	var dir := DirAccess.open(extension_path)
	if not dir:
		return
	
	logv("Loading extensions from %s..." % extension_path)
	
	dir.list_dir_begin()
	var filename: String = dir.get_next()
	while filename != "":
		if dir.current_is_dir():
			_populate_extension_map(extension_path, filename)
		else:
			if filename.contains(".gd") and not filename.contains(".uid"):
				var res = ResourceLoader.load("%s/%s" % [ extension_path, filename ])
				if res is Script:
					var ext_script = res.new()
					if ext_script is GSExtension and not ext_script.get_script() == GSExtension:
						logv("Found extension %s." % filename)
						_extension_map[ext_script.get_extension_name()] = ext_script
		filename = dir.get_next()


func _prioritize_extensions() -> Array[GSExtension]:
	var extensions: Array[GSExtension] = []
	extensions.assign(_extension_map.values())
	extensions.sort_custom(
		func(a: GSExtension, b: GSExtension):
			return a.get_extension_priority() > b.get_extension_priority()
	)
	
	return extensions


class GSFeatureDuration extends Node:
	var feature: GSFeature
	var client
	var duration: float = 0.0
	
	
	func _ready() -> void:
		name = "FeatureDuration-%s-%s" % [ feature.device.get_display_name(), feature.get_display_name() ]
	
	
	func _process(delta: float) -> void:
		if  not feature:
			return
		if duration > 0.0:
			duration -= delta
			if duration <= 0.0:
				if client:
					client.stop_feature(feature)
				kill()
	
	
	func kill() -> void:
		duration = 0.0
		if client:
			var key = client._get_feature_key(feature)
			client._durations.erase(key)
		queue_free()
