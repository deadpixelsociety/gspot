class_name  GSCurveValueGenerator
extends GSValueGenerator

var curve: Curve = null
var _tween: Tween = null


func generate_values() -> void:
	if _tween:
		_tween.kill()
	if duration <= 0.0 or not curve:
		return
	_tween = GSClient.create_tween()
	_tween.tween_method(_generate_value, 0.0, 1.0, duration)
	await _tween.finished
	generator_finished.emit(self)
	if _tween:
		_tween.kill()
		_tween = null


func _generate_value(t: float) -> void:
	if not curve:
		return
	var value: float = get_value(t)
	generator_value.emit(self, value)


func get_value(t: float) -> float:
	if not curve:
		return 0.0
	return clampf(curve.sample(t), 0.0, 1.0)


func play() -> void:
	if _tween:
		_tween.play()


func pause() -> void:
	if _tween:
		_tween.pause()


func stop() -> void:
	if _tween:
		_tween.stop()
