class_name GSSequenceValueGenerator
extends GSValueGenerator

var sequence: PackedFloat32Array = []
var _tween: Tween = null


func generate_values() -> void:
	if _tween:
		_tween.kill()
	if duration <= 0.0 or sequence.is_empty():
		return
	_tween = GSClient.create_tween()
	_tween.tween_method(_generate_value, 0.0, 1.0, duration)
	await _tween.finished
	generator_finished.emit(self)
	if _tween:
		_tween.kill()
		_tween = null


func get_value(t: float) -> float:
	if sequence.is_empty():
		return 0.0
	var size: int = sequence.size()
	if size == 0:
		return 0.0
	var idxf: float = (size - 1) * t
	var idx_low: int = min(max(0, floor(idxf)), size - 1)
	var idx_high: int = min(max(0, ceil(idxf)), size - 1)
	var low_value: float = sequence[idx_low]
	var high_value: float = sequence[idx_high]
	var alpha: float = fmod(idxf, 1.0)
	return clampf(lerpf(low_value, high_value, alpha), 0.0, 1.0)


func play() -> void:
	if _tween:
		_tween.play()


func pause() -> void:
	if _tween:
		_tween.pause()


func stop() -> void:
	if _tween:
		_tween.stop()


func _generate_value(t: float) -> void:
	var value: float = get_value(t)
	generator_value.emit(self, value)
