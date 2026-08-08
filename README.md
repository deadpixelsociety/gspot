# gspot

gspot is a Godot 4 plugin for controlling intimate haptic devices through the [Buttplug protocol](https://buttplug.io/docs/spec/). A compatible server is required. [Intiface Central](https://intiface.com/central/) is the recommended local server and normally listens on `127.0.0.1:12345`.

The 3.0 plugin uses Buttplug protocol v4 by default and retains protocol v3 compatibility.

## Installation

1. Copy or clone this repository into your project as `addons/gspot`.
2. Enable **gspot** in **Project Settings > Plugins**.
3. Start Intiface Central or another compatible WebSocket server.

The plugin registers `GSClient` as an autoload singleton. The demo control panel is available at [`ui/gscontrol_panel.tscn`](ui/gscontrol_panel.tscn).

## Connection workflow

~~~gdscript
var result := GSClient.start("127.0.0.1", 12345)
if result != OK:
	return

var connected: bool = await GSClient.client_connection_changed
if not connected:
	return

print("Protocol %d.%d" % [
	GSClient.get_protocol_version_major(),
	GSClient.get_protocol_version_minor(),
])

GSClient.request_device_list()
await GSClient.client_device_list_received

var device: GSDevice = GSClient.get_device(0)
if device:
	device.vibrate(0.5)

GSClient.stop()
~~~

`GSClient.get_devices()` returns the current device objects. Use `get_device_by_name()` when an index is not stable for the application.

Use `GSClient.scan_start()` and `GSClient.scan_stop()` for server-side scanning. `client_scan_finished` indicates that a scan has ended.

## Protocol modes

`gspot/client/protocol_mode` accepts `Auto`, `Spec v4`, and `Spec v3`. The equivalent runtime enum is `GSClient.ProtocolMode.AUTO`, `SPEC_V4`, or `SPEC_V3`.

Auto mode requests v4.0 first. It retries one v3 handshake only when the v4 handshake returns `ERROR_INIT`. Forced modes never fall back. `get_protocol_version_major()` and `get_protocol_version_minor()` report the negotiated version. `get_message_version()` remains as a deprecated major-version alias.

## Device and feature controls

`GSDevice` keeps normalized controls in the `0.0` to `1.0` range. v4 integer ranges are applied internally from each feature's advertised capability.

~~~gdscript
device.vibrate(0.8)
device.rotate(0.5, true)
device.oscillate(0.4)
device.constrict(0.6)
device.spray(1.0)
device.set_led(0.25)
device.temperature(-0.5) # cooling; positive values heat
await device.position(0.5, 0.75) # duration in seconds
device.stop()
~~~

High-level device and feature duration arguments use seconds. Position durations are converted to protocol milliseconds internally. `Inflate` is retained for v3 devices only.

For capability-specific code, inspect `GSFeature.output_type`, `input_type`, `value_range`, `duration_range`, and `input_commands`. `can_read()` and `can_subscribe()` report the input operations advertised by the server.

Supported v4 output types are Vibrate, Rotate, Oscillate, Constrict, Spray, Temperature, Led, Position, and HwPositionWithDuration. Supported input types are Battery, Rssi, Pressure, and Button.

## Sensors

~~~gdscript
for feature in device.features:
    if not feature.is_input():
        continue
    if feature.can_read():
        feature.read_sensor()
    if feature.can_subscribe():
        GSClient.send_sensor_subscribe(
            device.device_index,
            feature.feature_index,
            feature.input_type,
        )
~~~

Readings are available through `feature.sensor_value_read(feature, data)` or the existing `GSClient.client_sensor_reading` signal. `data` is a `PackedInt32Array`. Stop subscriptions with `send_sensor_unsubscribe()` or `feature.stop()`.

## Stop and error handling

Use `GSClient.stop_feature(feature)`, `GSClient.stop_device(device_index)`, or `GSClient.stop_all_devices()` for explicit stops. `GSClient.stop()` closes the WebSocket transport directly so it works with current Intiface schemas. The server cleans up the session and devices when the transport closes. The v4 `Disconnect` serializer remains available for non-WebSocket transports.

Use `client_message` for log output, `client_error` for local errors, and `server_error` for protocol errors. Set verbosity with `GSClient.set_log_level(GSClient.LogLevel.DEBUG)`.

Important signals are `client_connection_changed`, `client_device_list_received`, `client_device_added`, `client_device_removed`, `client_scan_finished`, `client_sensor_reading`, and `client_raw_reading`.

## Project settings

| Setting | Default | Purpose |
| --- | --- | --- |
| `gspot/client/client_name` | `GSClient` | Name sent during the handshake. |
| `gspot/client/client_version` | `3.0.0` | Client version sent during the handshake. |
| `gspot/client/message_rate` | `0.2` seconds | Default interval returned by `GSDevice.get_message_rate()`. |
| `gspot/client/enable_raw_commands` | `false` | Opts into deprecated v3 raw commands. |
| `gspot/client/protocol_mode` | `Auto` | Selects protocol negotiation mode. |

Raw methods require `gspot/client/enable_raw_commands=true` and are available only after a v3 handshake. Under v4 they report `ERR_UNAVAILABLE`. Direct construction of v3 wire-message classes is not adapted to v4.

## Patterns extension

The bundled `patterns` extension supports sequence and Curve patterns. Pattern durations and `linear_duration` values are expressed in seconds; linear durations are converted to milliseconds when commands are sent.

~~~gdscript
var feature := device.get_feature_by_actuator_type(GSActuatorType.VIBRATE)
var patterns := GSClient.ext(GSPatterns.NAME) as GSPatterns
patterns.create_sequence_pattern("Pulse", 10.0, PackedFloat32Array([0.0, 1.0, 0.0]))
var active := patterns.play("Pulse", feature, true, 0.5)

active.stop()
~~~

## Development and testing

~~~text
godot --headless --path . --script res://tests/run_tests.gd
~~~

The fixture runner covers v3 and v4 serialization without physical hardware. Test live discovery, commands, subscriptions, and disconnect behavior against a local server when changing protocol code. The `spec-3.0` branch remains the 2.1.1 maintenance baseline.

The headless runner resolves the `GSClient` autoload from the scene tree and creates a local fallback when an editor plugin session has not registered it.
For a host project, enable the plugin once or add `GSClient` under Project Settings > Globals > Autoload, pointing to `res://addons/gspot/gsclient.gd`.

## Attribution

The gspot icon was created by [Kokota](https://thenounproject.com/kokota.icon/) and distributed under the [Creative Commons Attribution License (CC BY 3.0)](https://creativecommons.org/licenses/by/3.0/).

Games made using gspot include [Mousegun](https://shinlalala.itch.io/mousegun) by [Shinlalala](https://shinlalala.itch.io/).
