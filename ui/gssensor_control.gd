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
	_subscribe.visible = feature.can_subscribe()
	_unsubscribe.visible = feature.can_subscribe()
	_read_sensor.visible = feature.can_read()
	_label4.visible = feature.can_read()


func _on_read_sensor_pressed() -> void:
	feature.read_sensor()


func _on_feature_sensor_value_read(feature: GSFeature, data: PackedInt32Array):
	if data.size() > 0:
		_value.text = "%d" % data[0]


func _on_subscribe_pressed() -> void:
	GSClient.send_sensor_subscribe(device.device_index, feature.feature_index, feature.sensor_type)


func _on_unsubscribe_pressed() -> void:
	GSClient.send_sensor_unsubscribe(device.device_index, feature.feature_index, feature.sensor_type)
