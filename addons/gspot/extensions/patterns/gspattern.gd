extends RefCounted
class_name GSPattern


var pattern_name: String = ""
var duration: float = 0.0

var _generator: GSValueGenerator = null


func get_generator() -> GSValueGenerator:
	return _generator
