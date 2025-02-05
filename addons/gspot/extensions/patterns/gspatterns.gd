class_name GSPatterns
extends GSExtension
## Implements sequence and curve patterns in gspot.
##
## The patterns extension adds pattern functionality to gspot using either sequence data as an 
## array of floats ranging from [code]0.0[/code] to [code]1.0[/code], or by utilizing the 
## [Curve] class to define the pattern.
##
## Patterns can then be played, looped, paused, resumed or stopped for any given feature.


const NAME: String = "patterns"
const FIELD_PATTERN_NAME: String = "pattern_name"
const FIELD_DURATION: String = "duration"
const FIELD_SEQUENCE: String = "sequence"
const FIELD_CURVE: String = "curve"

var _pattern_map: Dictionary = {}
var _active_patterns: Array[GSActivePattern] = []


## Serializes the given pattern into a JSON string.
static func serialize_pattern(pattern: GSPattern) -> String:
	var data = {
		FIELD_PATTERN_NAME: pattern.pattern_name,
		FIELD_DURATION: pattern.duration,
	}
	
	if pattern is GSCurvePattern:
		data[FIELD_CURVE] = pattern.curve.resource_path if pattern.curve else ""
	if pattern is GSSequencePattern:
		data[FIELD_SEQUENCE] = pattern.sequence
	
	return JSON.stringify(data, "\t", false, true)


## Deserializes the given JSON string into a new [GSPattern] instance.
static func deserialize_pattern(json: String) -> GSPattern:
	var data := JSON.parse_string(json) as Dictionary
	if not data:
		return null
	
	var pattern: GSPattern = null
	if data.has(FIELD_SEQUENCE):
		pattern = GSSequencePattern.new()
		pattern.sequence = data[FIELD_SEQUENCE]
	if data.has(FIELD_CURVE):
		pattern = GSCurvePattern.new()
		var curve_path: String = data[FIELD_CURVE]
		if curve_path and not curve_path.is_empty() and FileAccess.file_exists(curve_path):
			pattern.curve = ResourceLoader.load(curve_path)
	
	if not pattern:
		return null
	
	if data.has(FIELD_PATTERN_NAME):
		pattern.pattern_name = data[FIELD_PATTERN_NAME]
	if data.has(FIELD_DURATION):
		pattern.duration = data[FIELD_DURATION]
	
	return pattern


func get_extension_name() -> String:
	return NAME


## Gets a list of all added patterns.
func get_patterns() -> Array[GSPattern]:
	var list: Array[GSPattern] = []
	list.assign(_pattern_map.values())
	return list


## Gets a pattern by name.
func get_pattern(pattern_name: String) -> GSPattern:
	if _pattern_map.has(pattern_name):
		return _pattern_map[pattern_name] as GSPattern
	return null


## Adds a pattern to the extension.
func add_pattern(pattern: GSPattern) -> void:
	_pattern_map[pattern.pattern_name] = pattern


## Removes the specified pattern.
func remove_pattern(pattern: GSPattern) -> void:
	_pattern_map.erase(pattern.pattern_name)


## Creates and adds a new pattern based on a [Curve].
## [br][br]
## [param pattern_name] is the name of the pattern to create.
## [br]
## [param duration] is the duration, in seconds, that the pattern should take to sample the curve.
## [br]
## [param curve] is the [Curve] data to sample. The curve should have a minimum value of 
## [code]0.0[/code] and a maximum value of [code]1.0[/code].
func create_curve_pattern(pattern_name: String, duration: float, curve: Curve) -> GSCurvePattern:
	var pattern := GSCurvePattern.new()
	pattern.pattern_name = pattern_name
	pattern.duration = duration
	pattern.curve = curve
	add_pattern(pattern)
	return pattern


## Creates and adds a new pattern based on a float sequence. 
## [br][br]
## [param pattern_name] is the name of the pattern to create.
## [br]
## [param duration] is the duration, in seconds, that the pattern should take to sample the 
## sequence.
## [br]
## [param sequence] is the sequence data to sample. All values in the sequence should be between 
## [code]0.0[/code] and [code]1.0[/code].
func create_sequence_pattern(pattern_name: String, duration: float, sequence: PackedFloat32Array) -> GSSequencePattern:
	var pattern := GSSequencePattern.new()
	pattern.pattern_name = pattern_name
	pattern.duration = duration
	pattern.sequence = sequence
	add_pattern(pattern)
	return pattern


## Plays the specified pattern name using the specified feature.
## [br][br]
## [param pattern_name] is the name of the pattern to play.
## [br]
## [param feature] is the [GSFeature] to use.
## [br]
## [param loop] determines if the pattern will start over once completed, or stop.
## [br]
## [param intensity] is a modifier to the sampled pattern value. This should be a value between 
## [code]0.0[/code] and [code]1.0[/code] where [code]0.0[/code] effectively disables the pattern, 
## and [code]1.0[/code] is no change from the sampled value.
## [br]
## [param replace_active] determines if an active pattern for the same feature is replaced, or 
## paused and later resumed when this new pattern is finished.
## [br]
## [param sample_rate] determines how often, in seconds, a new value is sampled from the pattern 
## and sent to the device. If a value less than or equal to [code]0.0[/code] is passed then the 
## value from [method GSDevice.get_message_rate] will be used.
## [br]
## [param linear_duration] is the duration, in seconds, that it takes for a linear feature to reach
## its position. Ignored for non-linear features. This duration effectively pauses the pattern 
## which will artifically inflate your pattern duration by that amount for each sample.
## [br]
## [param rotate_clockwise] determines the direction of rotation for the feature. Ignored for 
## non-rotation features.
func play(
	pattern_name: String, 
	feature: GSFeature, 
	loop: bool = false, 
	intensity: float = 1.0,
	replace_active: bool = false,
	sample_rate: float = -1.0, 
	linear_duration: float = 0.0,
	rotate_clockwise: bool = true
) -> GSActivePattern:
	var pattern: GSPattern = get_pattern(pattern_name)
	if not pattern:
		GSClient.logw("Pattern %s not found." % pattern_name)
		return null
	var parent: GSActivePattern = null
	var active: GSActivePattern = get_active_pattern_by_feature(feature)
	if GSUtil.is_valid(active):
		if replace_active:
			active.stop()
		else:
			parent = active
			active.pause()
	active = GSActivePattern.new()
	active.parent = parent
	active.pattern = pattern
	active.feature = feature
	active.intensity = clampf(intensity, 0.0, 1.0)
	# If no sample rate is provided use the device value.
	if sample_rate <= 0:
		sample_rate = feature.device.get_message_rate()
	active.sample_rate = sample_rate
	active.loop = loop
	active.linear_duration = linear_duration
	active.rotate_clockwise = rotate_clockwise
	active.stopped.connect(
		func(_active: GSActivePattern): 
			_active_patterns.erase(_active)
			if GSUtil.is_valid(_active) and GSUtil.is_valid(_active.parent):
				_active.parent.resume()
	)
	
	_active_patterns.append(active)
	GSClient.add_child(active)
	
	return active


## Gets a list of all actively playing patterns.
func get_active_patterns() -> Array[GSActivePattern]:
	var list: Array[GSActivePattern] = []
	list.assign(_active_patterns)
	return list


## Gets an active pattern by its index.
func get_active_pattern(active_idx) -> GSActivePattern:
	if active_idx < 0 or active_idx >= _active_patterns.size():
		return
	var active = _active_patterns[active_idx]
	if not GSUtil.is_valid(active):
		return null
	return active


## Gets all active patterns for the specified feature.
func get_active_patterns_by_feature(feature: GSFeature) -> Array[GSActivePattern]:
	var list: Array[GSActivePattern] = []
	for active in _active_patterns:
		if active.feature == feature:
			list.append(active)
	return list


## Gets the latest active pattern for the specified feature.
func get_active_pattern_by_feature(feature: GSFeature) -> GSActivePattern:
	var active_patterns = get_active_patterns_by_feature(feature)
	for i in range(active_patterns.size() - 1, -1, -1):
		var active: GSActivePattern = active_patterns[i]
		if active.feature == feature:
			return active
	return null
