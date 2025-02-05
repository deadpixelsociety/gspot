class_name GSRotation
extends RefCounted

var index: int = -1
var speed: float:
	set(value):
		speed = clampf(value, 0.0, 1.0)

var clockwise: bool = true


func serialize() -> Dictionary:
	return {
		GSMessage.MESSAGE_FIELD_INDEX: index,
		GSMessage.MESSAGE_FIELD_SPEED: speed,
		GSMessage.MESSAGE_FIELD_CLOCKWISE: clockwise,
	}
