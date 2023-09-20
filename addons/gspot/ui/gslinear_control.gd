extends GridContainer
class_name GSLinearControl

var client: GSClient
var device: GSDevice
var feature: GSFeature

@onready var _index: Label = %Index
@onready var _duration: SpinBox = %Duration
@onready var _position: HSlider = $Position


func _ready() -> void:
	_index.text = str(feature.feature_index)


func _on_position_value_changed(value: float) -> void:
	value = clampf(value / 100.0, 0.0, 1.0)
	await client.send_feature(feature, value, int(_duration.value))
