extends PanelContainer
class_name GSControlPanel

const SCALAR_CONTROl = preload("res://addons/gspot/ui/gsscalar_control.tscn")
const LINEAR_CONTROL = preload("res://addons/gspot/ui/gsslinear_control.tscn")
const ROTATE_CONTROL = preload("res://addons/gspot/ui/gsrotate_control.tscn")
const SENSOR_CONTROL = preload("res://addons/gspot/ui/gssensor_control.tscn")

@onready var _title: Label = %Title
@onready var _client: GSClient = $GSClient
@onready var _hostname: LineEdit = %Hostname
@onready var _port: SpinBox = %Port
@onready var _connect: Button = %Connect
@onready var _disconnect: Button = %Disconnect
@onready var _request_device_list: Button = %RequestDeviceList
@onready var _start_scan: Button = %StartScan
@onready var _stop_scan: Button = %StopScan
@onready var _device_list: ItemList = %DeviceList
@onready var _scalar_scroll: ScrollContainer = %ScalarScroll
@onready var _linear_scroll: ScrollContainer = %LinearScroll
@onready var _rotation_scroll: ScrollContainer = %RotationScroll
@onready var _sensor_scroll: ScrollContainer = %SensorScroll
@onready var _scalar_container: VBoxContainer = %ScalarContainer
@onready var _rotation_container: VBoxContainer = %RotationContainer
@onready var _linear_container: VBoxContainer = %LinearContainer
@onready var _sensor_container: VBoxContainer = %SensorContainer
@onready var _log: RichTextLabel = %Log


func _ready() -> void:
	_client.client_frame_received.connect(_on_client_frame_received)
	_client.client_message.connect(_on_client_message)
	_client.client_error.connect(_on_client_error)
	_client.client_scan_finished.connect(_on_client_scan_finished)
	_client.client_device_list_received.connect(_on_client_device_list_received)
	_client.client_device_added.connect(_on_client_device_added)
	_client.client_device_removed.connect(_on_client_device_removed)
	_client.client_connection_changed.connect(_on_client_connection_changed)
	_title.text = "%s v%s" % [ GSClient.CLIENT_NAME, GSClient.CLIENT_VERSION]


func get_hostname() -> String:
	return _hostname.text


func get_port() -> int:
	return int(_port.value)


func get_selected_device() -> GSDevice:
	if _device_list.get_selected_items().size() > 0:
		var idx = _device_list.get_selected_items()[0]
		return _device_list.get_item_metadata(idx) as GSDevice
	return null


func _populate_device_list(devices: Array):
	_device_list.clear()
	devices.sort_custom(func(a, b): return a.device_index < b.device_index)
	for device in devices:
		_add_device(device)


func _add_device(device: GSDevice):
	var idx = _device_list.add_item(device.get_display_name())
	_device_list.set_item_metadata(idx, device)
	device.set_meta("device_list_idx", idx)


func _remove_device(device: GSDevice):
	if device.has_meta("device_list_idx"):
		var idx = device.get_meta("device_list_idx")
		if _device_list.get_selected_items().has(idx):
			_clear_container(_scalar_container)
			_clear_container(_linear_container)
			_clear_container(_rotation_container)
			_clear_container(_sensor_container)
		_device_list.remove_item(idx)


func _on_client_frame_received(frame: String):
	_log.add_text("Frame received: %s" % frame)
	_log.newline()


func _on_client_message(message: String):
	_log.add_text(message)
	_log.newline()


func _on_client_error(error: int, message: String):
	_log.append_text("[color=red][b]Error %d: %s[/b][/color]" % [ error, message ])
	_log.newline()


func _on_client_scan_finished():
	_populate_device_list(_client.get_devices())


func _on_client_device_list_received(devices: Array):
	_populate_device_list(devices)


func _on_client_device_added(device: GSDevice):
	_add_device(device)


func _on_client_device_removed(device: GSDevice):
	_remove_device(device)


func _on_client_connection_changed(connected: bool):
	if _client.is_client_connected():
		_connect.visible = false
		_connect.disabled = true
		_disconnect.visible = true
		_disconnect.disabled = false
	else:
		_connect.visible = true
		_connect.disabled = false
		_disconnect.visible = false
		_disconnect.disabled = true
	_reset_devices()


func _reset_devices():
	_device_list.clear()
	_clear_container(_scalar_container)
	_clear_container(_linear_container)
	_clear_container(_rotation_container)
	_clear_container(_sensor_container)


func _on_connect_pressed() -> void:
	var hostname = get_hostname()
	var port = get_port()
	
	if hostname == null or hostname.length() == 0:
		OS.alert("Hostname is required.")
	
	_connect.disabled = true
	_client.start(hostname, port)


func _on_disconnect_pressed() -> void:
	_disconnect.disabled = true
	_client.stop()


func _on_request_device_list_pressed() -> void:
	_client.request_device_list()


func _on_start_scan_pressed() -> void:
	_client.scan_start()


func _on_stop_scan_pressed() -> void:
	_client.scan_stop()


func _on_stop_device_pressed() -> void:
	var device = get_selected_device()
	if not device:
		return
	_client.stop_device(device.device_index)


func _on_stop_all_devices_pressed() -> void:
	_client.stop_all_devices()


func _on_device_list_item_clicked(index: int, at_position: Vector2, mouse_button_index: int) -> void:
	var device = _device_list.get_item_metadata(index) as GSDevice
	if not device:
		return
	_add_scalars(device)
	_add_linears(device)
	_add_rotations(device)
	_add_sensors(device)


func _add_scalars(device: GSDevice):
	_clear_container(_scalar_container)
	for feature in device.features:
		if feature.feature_command == GSMessage.MESSAGE_TYPE_SCALAR_CMD:
			var scalar = SCALAR_CONTROl.instantiate() as GSScalarControl
			scalar.client = _client
			scalar.device = device
			scalar.feature = feature
			_scalar_container.add_child(scalar)
	_scalar_scroll.visible = _scalar_container.get_child_count() > 0


func _add_linears(device: GSDevice):
	_clear_container(_linear_container)
	for feature in device.features:
		if feature.feature_command == GSMessage.MESSAGE_TYPE_LINEAR_CMD:
			var linear = LINEAR_CONTROL.instantiate() as GSLinearControl
			linear.client = _client
			linear.device = device
			linear.feature = feature
			_linear_container.add_child(linear)
	_linear_scroll.visible = _linear_container.get_child_count() > 0


func _add_rotations(device: GSDevice):
	_clear_container(_rotation_container)
	for feature in device.features:
		if feature.feature_command == GSMessage.MESSAGE_TYPE_ROTATE_CMD:
			var rotate = ROTATE_CONTROL.instantiate() as GSRotateControl
			rotate.client = _client
			rotate.device = device
			rotate.feature = feature
			_rotation_container.add_child(rotate)
	_rotation_scroll.visible = _rotation_container.get_child_count() > 0


func _add_sensors(device: GSDevice):
	_clear_container(_sensor_container)
	for feature in device.features:
		if feature.feature_command == GSMessage.MESSAGE_TYPE_SENSOR_READ_CMD:
			var sensor = SENSOR_CONTROL.instantiate() as GSSensorControl
			sensor.client = _client
			sensor.device = device
			sensor.feature = feature
			_sensor_container.add_child(sensor)
	_sensor_scroll.visible = _sensor_container.get_child_count() > 0


func _clear_container(control: Control):
	for child in control.get_children():
		child.queue_free()


