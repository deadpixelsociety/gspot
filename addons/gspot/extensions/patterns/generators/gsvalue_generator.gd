class_name GSValueGenerator
extends RefCounted

signal generator_finished(generator: GSValueGenerator)
signal generator_value(generator: GSValueGenerator, value: float)

var duration: float = 0.0


func generate_values() -> void:
	pass


func get_value(t: float) -> float:
	return 0.0


func pause() -> void:
	pass


func resume() -> void:
	pass


func stop() -> void:
	pass
