class_name GSInputType
## Input types defined by Buttplug protocol v4.

const BATTERY: String = "Battery"
const RSSI: String = "Rssi"
const PRESSURE: String = "Pressure"
const BUTTON: String = "Button"

static func is_known(input_type: String) -> bool:
	return input_type in [BATTERY, RSSI, PRESSURE, BUTTON]
