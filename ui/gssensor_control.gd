extends GridContainer
class_name GSSensorControl

var device: GSDevice
var feature: GSFeature

@onready var _sensor_type: Label = %SensorType
@onready var _index: Label = %Index
@onready var _value: Label = %Value
@onready var _label4: Label = $Label4
@onready var _read_sensor: Button = %ReadSensor
@onready var _subscribe: Button = %Subscribe
@onready var _unsubscribe: Button = %Unsubscribe


func _ready() -> void:
	feature.sensor_value_read.connect(_on_feature_sensor_value_read)
	_sensor_type.text = feature.sensor_type
	_index.text = str(feature.feature_index)
	_setup_buttons()


func _setup_buttons():
	if feature.feature_command.begins_with("SensorSubscribe"):
		_subscribe.visible = true
		_unsubscribe.visible = true
		_label4.visible = false
		_read_sensor.visible = false
	else:
		_subscribe.visible = false
		_unsubscribe.visible = false
		_label4.visible = true
		_read_sensor.visible = true


func _on_read_sensor_pressed() -> void:
	feature.read_sensor()


func _on_feature_sensor_value_read(feature: GSFeature, data: PackedInt32Array):
	if data.size() > 0:
		_value.text = "%d" % data[0]


func _on_subscribe_pressed() -> void:
	GSClient.send_sensor_subscribe(device.device_index, feature.feature_index, feature.sensor_type)


func _on_unsubscribe_pressed() -> void:
	GSClient.send_sensor_unsubscribe(device.device_index, feature.feature_index, feature.sensor_type)
