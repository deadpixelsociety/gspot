class_name GSSensorRange
extends RefCounted
## Represents the valid range of a sensor value.

## The minimum sensor value.
var sensor_range_min: int = -1
## The maximum sensor value.
var sensor_range_max: int = -1


func _init(range_min: int = 0, range_max: int = 0) -> void:
	sensor_range_min = range_min
	sensor_range_max = range_max
