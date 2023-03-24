extends RefCounted
class_name GSRotation

var index: int
var speed: float:
	set(value):
		speed = clampf(value, 0.0, 1.0)
var clockwise: bool


func serialize() -> Dictionary:
	return {
		GSMessage.MESSAGE_FIELD_INDEX: index,
		GSMessage.MESSAGE_FIELD_SPEED: speed,
		GSMessage.MESSAGE_FIELD_CLOCKWISE: clockwise,
	}
