extends RefCounted
class_name GSSensorRange

var sensor_range_min: int
var sensor_range_max: int


func _init(range_min: int = 0, range_max: int = 0) -> void:
	sensor_range_min = range_min
	sensor_range_max = range_max
