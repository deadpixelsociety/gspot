class_name GSPatterns
extends GSExtension

const NAME := "patterns"
const FIELD_PATTERN_NAME := "pattern_name"
const FIELD_DURATION := "duration"
const FIELD_SEQUENCE := "sequence"
const FIELD_CURVE := "curve"

var _pattern_map: Dictionary = {}
var _active_patterns: Array[GSActivePattern] = []


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


func get_patterns() -> Array[GSPattern]:
	var list: Array[GSPattern] = []
	list.assign(_pattern_map.values())
	return list


func get_pattern(pattern_name: String) -> GSPattern:
	if _pattern_map.has(pattern_name):
		return _pattern_map[pattern_name] as GSPattern
	return null


func add_pattern(pattern: GSPattern) -> void:
	_pattern_map[pattern.pattern_name] = pattern


func remove_pattern(pattern: GSPattern) -> void:
	_pattern_map.erase(pattern.pattern_name)


func create_curve_pattern(pattern_name: String, duration: float, curve: Curve) -> GSCurvePattern:
	var pattern := GSCurvePattern.new()
	pattern.pattern_name = pattern_name
	pattern.duration = duration
	pattern.curve = curve
	add_pattern(pattern)
	return pattern


func create_sequence_pattern(pattern_name: String, duration: float, sequence: PackedFloat32Array) -> GSSequencePattern:
	var pattern := GSSequencePattern.new()
	pattern.pattern_name = pattern_name
	pattern.duration = duration
	pattern.sequence = sequence
	add_pattern(pattern)
	return pattern


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


func get_active_patterns() -> Array[GSActivePattern]:
	var list: Array[GSActivePattern] = []
	list.assign(_active_patterns)
	return list


func get_active_pattern(active_idx) -> GSActivePattern:
	if active_idx < 0 or active_idx >= _active_patterns.size():
		return
	var active = _active_patterns[active_idx]
	if not GSUtil.is_valid(active):
		return null
	return active


func get_active_patterns_by_feature(feature: GSFeature) -> Array[GSActivePattern]:
	var list: Array[GSActivePattern] = []
	for active in _active_patterns:
		if active.feature == feature:
			list.append(active)
	return list


func get_active_pattern_by_feature(feature: GSFeature) -> GSActivePattern:
	var active_patterns = get_active_patterns_by_feature(feature)
	for i in range(active_patterns.size() - 1, -1, -1):
		var active: GSActivePattern = active_patterns[i]
		if active.feature == feature:
			return active
	return null
