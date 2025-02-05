extends GSValueGenerator
class_name  GSSequenceValueGenerator


var sequence: PackedFloat32Array = []:
	set(value):
		sequence = value
		_find_low_high()

var _tween: Tween = null
var _low: float = 0.0
var _high: float = 0.0


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


func _generate_value(t: float) -> void:
	var value = get_value(t)
	generator_value.emit(self, value)


func get_value(t: float) -> float:
	if sequence.is_empty():
		return 0.0
	var size = sequence.size()
	if size == 0:
		return 0.0
	var idxf = (size - 1) * t
	var idx_low = min(max(0, floor(idxf)), size - 1)
	var idx_high = min(max(0, ceil(idxf)), size - 1)
	var low_value = sequence[idx_low]
	var high_value = sequence[idx_high]
	var alpha = fmod(idxf, 1.0)
	return clampf(lerpf(low_value, high_value, alpha), _low, _high)


func play() -> void:
	if _tween:
		_tween.play()


func pause() -> void:
	if _tween:
		_tween.pause()


func stop() -> void:
	if _tween:
		_tween.stop()


func _find_low_high() -> void:
	if sequence.is_empty():
		_low = 0.0
		_high = 0.0
		return
	_low = 1.79769e308
	_high = -1.79769e308
	for value in sequence:
		if value < _low:
			_low = value
		if value > _high:
			_high = value
