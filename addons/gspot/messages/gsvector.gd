extends RefCounted
class_name GSVector

var index: int
var duration: int
var position: float:
	set(value):
		position = clampf(value, 0.0, 1.0)


func serialize() -> Dictionary:
	return {
		GSMessage.MESSAGE_FIELD_INDEX: index,
		GSMessage.MESSAGE_FIELD_DURATION: duration,
		GSMessage.MESSAGE_FIELD_POSITION: position,
	}
