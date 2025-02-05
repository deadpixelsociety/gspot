class_name GSActivePattern
extends Node
## An actively playing pattern for a specific [GSFeature].
##
## A GSActivePattern is automatically added to the scene tree and begins playing when created via 
## [method GSPatterns.play]. Once the pattern finishes or [method stop] is called this node is 
## removed automatically.

## Emitted when the pattern is played.
signal played(active: GSActivePattern)
## Emitted when the pattern is paused.
signal paused(active: GSActivePattern)
## Emitted when the pattern is resumed from a previous pause.
signal resumed(active: GSActivePattern)
## Emitted when the pattern is stopped.
signal stopped(active: GSActivePattern)

## Enumerates the active pattern states.
enum {
	## The pattern is currently playing.
	PLAYING,
	## The pattern has been paused.
	PAUSED,
	## The pattern has been stopped.
	STOPPED,
}

## The previously playing pattern before this one. If set it will be resumed after this finishes.
var parent: GSActivePattern = null
## The pattern to play.
var pattern: GSPattern = null
## The feature to use.
var feature: GSFeature = null
## The intensity modifier.
var intensity: float = 1.0
## The pattern sample rate, in seconds.
var sample_rate: float = GSUtil.get_project_value(
	GSConstants.PROJECT_SETTINGS_MESSAGE_RATE, 
	GSConstants.MESSAGE_RATE
)
## Determines if the pattern will restart after it finishes.
var loop: bool = false
## The amount of time, in seconds, it takes for a linear command to reach its final position.
var linear_duration: float = 0.0
## The direction of rotation for rotate features.
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


## Gets the current pattern state.
func get_state() -> int:
	return _state


## Returns [code]true[/code] if the pattern is currently playing.
func is_playing() -> bool:
	return get_state() == PLAYING


## Gets the intensity modifier value.
func get_intensity() -> float:
	return clampf(intensity, 0.0, 1.0)


## Plays the pattern from a stopped state.
func play() -> void:
	if get_state() != STOPPED or is_queued_for_deletion():
		return
	_state = PLAYING
	played.emit(self)
	await GSClient.send_feature(
		feature, 
		_get_value(0.0),
		linear_duration * 1000.0, 
		rotate_clockwise
	)


## Pauses the pattern if it is currently playing.
func pause() -> void:
	if get_state() == PLAYING:
		_state = PAUSED
		GSClient.stop_feature(feature)
		paused.emit(self)


## Resumes the pattern if it is currently paused.
func resume() -> void:
	if get_state() == PAUSED:
		_state = PLAYING
		resumed.emit(self)


## Stops the pattern and queues it to be cleaned up.
func stop() -> void:
	if get_state() != STOPPED:
		_state = STOPPED
		GSClient.stop_feature(feature)
		stopped.emit(self)
		queue_free()


func _get_value(t: float) -> float:
	return pattern.get_generator().get_value(t) * get_intensity()
