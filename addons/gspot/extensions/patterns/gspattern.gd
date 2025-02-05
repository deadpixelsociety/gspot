class_name GSPattern
extends RefCounted

var pattern_name: String = "New Pattern"
var duration: float = 0.0
var _generator: GSValueGenerator = null


func get_generator() -> GSValueGenerator:
	return _generator
