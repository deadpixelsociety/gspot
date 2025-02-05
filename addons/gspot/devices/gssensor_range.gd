class_name GSSensorRange
extends RefCounted

var sensor_range_min: int = -1
var sensor_range_max: int = -1


func _init(range_min: int = 0, range_max: int = 0) -> void:
	sensor_range_min = range_min
	sensor_range_max = range_max
