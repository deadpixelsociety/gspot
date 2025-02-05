class_name GSCurvePattern
extends GSPattern

var curve: Curve = null


func get_generator() -> GSValueGenerator:
	if not _generator:
		_generator = GSCurveValueGenerator.new()
		_generator.curve = curve
		_generator.duration = duration
	return _generator
