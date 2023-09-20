extends GridContainer
class_name GSRotateControl

var client: GSClient
var device: GSDevice
var feature: GSFeature

@onready var _index: Label = %Index
@onready var _speed: HSlider = %Speed
@onready var _clockwise: CheckBox = %Clockwise


func _ready() -> void:
	_index.text = str(feature.feature_index)


func _on_speed_value_changed(value: float) -> void:
	value = clampf(value / 100.0, 0.0, 1.0)
	client.send_feature(feature, value, 0.0, _clockwise.button_pressed)
