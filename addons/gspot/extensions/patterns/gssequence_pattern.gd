extends GSPattern
class_name  GSSequencePattern


var sequence: PackedFloat32Array = []


func get_generator() -> GSValueGenerator:
	if not _generator:
		_generator = GSSequenceValueGenerator.new()
		_generator.sequence = sequence
		_generator.duration = duration
	return _generator
