extends GridContainer
class_name GSScalarControl

var client: GSClient
var device: GSDevice
var feature: GSFeature

@onready var _actuator_type: Label = %ActuatorType
@onready var _index: Label = %Index
@onready var _scalar: HSlider = $Scalar


func _ready() -> void:
	_actuator_type.text = feature.actuator_type
	_index.text = str(feature.feature_index)


func _on_scalar_value_changed(value: float) -> void:
	value = clampf(value / 100.0, 0.0, 1.0)
	client.send_feature(feature, value)
