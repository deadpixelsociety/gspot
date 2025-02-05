extends VBoxContainer
class_name GSScalarControl

var device: GSDevice
var feature: GSFeature

@onready var _actuator_type: Label = %ActuatorType
@onready var _index: Label = %Index
@onready var _scalar: HSlider = %Scalar


func _ready() -> void:
	_actuator_type.text = feature.actuator_type
	_index.text = str(feature.feature_index)
	if feature.step_count != 0:
		_scalar.max_value = feature.step_count


func _on_scalar_value_changed(value: float) -> void:
	value = clampf(0.0 if _scalar.max_value == 0.0 else value / _scalar.max_value, 0.0, 1.0)
	GSClient.send_feature(feature, value)
