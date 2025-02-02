extends Node
class_name GSActivePattern


signal played(active: GSActivePattern)
signal paused(active: GSActivePattern)
signal resumed(active: GSActivePattern)
signal stopped(active: GSActivePattern)


enum {PLAYING,PAUSED,STOPPED}


var idx: int = -1
var pattern: GSPattern = null
var feature: GSFeature = null
var sample_rate: float = 0.1
var loop: bool = false
var linear_duration: float = 1.0
var rotate_clockwise: bool = true

var _tt: float = 0.0
var _sr: float = 0.0
var _state = STOPPED


func _ready() -> void:
	play()


func _process(delta: float) -> void:
	if !is_playing():
		return
	_tt += delta
	_sr += delta
	if _sr >= sample_rate and not is_queued_for_deletion():
		_sr -= sample_rate
		var t = clampf(0.0 if pattern.duration <= 0 else _tt / pattern.duration, 0.0, 1.0)
		var value = pattern.get_generator().get_value(t)
		await GSClient.send_feature(feature, value, linear_duration * 1000.0, rotate_clockwise)
	if _tt >= pattern.duration:
		if loop:
			_tt = 0.0
		else:
			stop()


func get_state() -> int:
	return _state


func is_playing() -> bool:
	return get_state() == PLAYING


func play() -> void:
	if is_queued_for_deletion():
		return
	_state = PLAYING
	played.emit(self)
	await GSClient.send_feature(
		feature, 
		pattern.get_generator().get_value(0.0), 
		linear_duration * 1000.0, 
		rotate_clockwise
	)


func pause() -> void:
	if _state == PLAYING:
		_state = PAUSED
		GSClient.stop_feature(feature)
		paused.emit(self)


func resume() -> void:
	if _state == PAUSED:
		_state = PLAYING
		resumed.emit(self)


func stop() -> void:
	if _state != STOPPED:
		_state = STOPPED
		GSClient.stop_feature(feature)
		stopped.emit(self)
		queue_free()
