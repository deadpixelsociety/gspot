class_name GSOutputType
## Output types defined by Buttplug protocol v4.

const VIBRATE: String = "Vibrate"
const ROTATE: String = "Rotate"
const OSCILLATE: String = "Oscillate"
const CONSTRICT: String = "Constrict"
const SPRAY: String = "Spray"
const TEMPERATURE: String = "Temperature"
const LED: String = "Led"
const POSITION: String = "Position"
const HW_POSITION_WITH_DURATION: String = "HwPositionWithDuration"

static func is_known(output_type: String) -> bool:
	return output_type in [
		VIBRATE,
		ROTATE,
		OSCILLATE,
		CONSTRICT,
		SPRAY,
		TEMPERATURE,
		LED,
		POSITION,
		HW_POSITION_WITH_DURATION,
	]

static func is_scalar(output_type: String) -> bool:
	return output_type in [VIBRATE, OSCILLATE, CONSTRICT, SPRAY, TEMPERATURE, LED]

static func legacy_command(output_type: String) -> String:
	if is_scalar(output_type):
		return GSMessage.MESSAGE_TYPE_SCALAR_CMD
	if output_type == ROTATE:
		return GSMessage.MESSAGE_TYPE_ROTATE_CMD
	if output_type in [POSITION, HW_POSITION_WITH_DURATION]:
		return GSMessage.MESSAGE_TYPE_LINEAR_CMD
	return ""
