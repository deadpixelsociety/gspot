class_name GSActivePattern
extends Node

signal played(active: GSActivePattern)
signal paused(active: GSActivePattern)
signal resumed(active: GSActivePattern)
signal stopped(active: GSActivePattern)

enum {
	PLAYING,
	PAUSED,
	STOPPED,
}

var parent: GSActivePattern = null
var pattern: GSPattern = null
var feature: GSFeature = null
var intensity: float = 1.0
var sample_rate: float = GSUtil.get_project_value(GSConstants.PROJECT_SETTINGS_MESSAGE_RATE, GSConstants.MESSAGE_RATE)
var loop: bool = false
var linear_duration: float = 0.0
var rotate_clockwise: bool = true
var _tt: float = 0.0
var _sr: float = 0.0
var _state = STOPPED


func _ready() -> void:
	name = "GSActivePattern-%s-%s-%s" % [ feature.device.get_display_name(), feature.get_display_name(), pattern.pattern_name ]
	play()


func _process(delta: float) -> void:
	if !is_playing():
		return
	_tt += delta
	_sr += delta
	if _sr >= sample_rate and not is_queued_for_deletion():
		_sr -= sample_rate
		var t: float = clampf(0.0 if pattern.duration <= 0 else _tt / pattern.duration, 0.0, 1.0)
		match feature.feature_command:
			GSMessage.MESSAGE_TYPE_SCALAR_CMD:
				GSClient.send_feature(feature, _get_value(t))
			GSMessage.MESSAGE_TYPE_ROTATE_CMD:
				GSClient.send_feature(feature, _get_value(t), 0.0, rotate_clockwise)
			GSMessage.MESSAGE_TYPE_LINEAR_CMD:
				await GSClient.send_feature(feature, _get_value(t), linear_duration * 1000.0)
	if _tt >= pattern.duration:
		if loop:
			_tt = 0.0
		else:
			stop()


func get_state() -> int:
	return _state


func is_playing() -> bool:
	return get_state() == PLAYING


func get_intensity() -> float:
	return clampf(intensity, 0.0, 1.0)


func play() -> void:
	if is_queued_for_deletion():
		return
	_state = PLAYING
	played.emit(self)
	await GSClient.send_feature(
		feature, 
		_get_value(0.0),
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


func _get_value(t: float) -> float:
	return pattern.get_generator().get_value(t) * get_intensity()
