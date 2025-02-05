extends GridContainer
class_name GSLinearControl

var device: GSDevice
var feature: GSFeature

@onready var _index: Label = %Index
@onready var _duration: SpinBox = %Duration
@onready var _position: HSlider = %Position


func _ready() -> void:
	_index.text = str(feature.feature_index)
	if feature.step_count != 0:
		_position.max_value = feature.step_count

func _on_position_value_changed(value: float) -> void:
	value = clampf(0.0 if _position.max_value == 0.0 else value / _position.max_value, 0.0, 1.0)
	await GSClient.send_feature(feature, value, int(_duration.value))


