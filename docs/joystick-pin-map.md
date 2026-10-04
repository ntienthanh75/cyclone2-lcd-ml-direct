# CoreEP2C5 joystick pin map

Source: `D:\fpga\EP2C5-pin-conf.txt`.

The joystick switches are documented as active-low: an unpressed switch reads
`1`; pressing it connects the input to ground and reads `0`.

| Direction / control | FPGA pin | Current direct-LCD ML use |
|---|---:|---|
| UP | `PIN_139` | Starts one 14x14 frame stream and recognition |
| DOWN | `PIN_143` | Clears the captured frame |
| LEFT | `PIN_142` | Reserved; not used by the current wrapper |
| RIGHT | `PIN_141` | Reserved; not used by the current wrapper |
| PRESS / center | `PIN_137` | Reserved; not used by the current wrapper |

The current hardware wrapper intentionally exposes only UP and DOWN. LEFT,
RIGHT, and PRESS remain available for a later UI/control milestone and must be
added to the top-level port list, QSF assignments, synchronizers, and
verification test before use.

## Physical test

With the board powered and the wrapper SOF loaded, use a multimeter or a
temporary LED/debug input to confirm each switch reads high at rest and low
while pressed. Do not infer direction from the LCD orientation; use the labels
on the joystick and this pin table.
