class_name GSScalar
extends RefCounted

var index: int = -1
var scalar: float:
	set(value):
		scalar = clampf(value, 0.0, 1.0)

var actuator_type: String


func serialize() -> Dictionary:
	return {
		GSMessage.MESSAGE_FIELD_INDEX: index,
		GSMessage.MESSAGE_FIELD_SCALAR: scalar,
		GSMessage.MESSAGE_FIELD_ACTUATOR_TYPE: actuator_type,
	}
