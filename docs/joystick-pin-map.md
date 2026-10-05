# CoreEP2C5 joystick pin map

Source: `D:\fpga\EP2C5-pin-conf.txt`.

For a visual orientation guide, run:

```powershell
python D:\fpga\cyclone2-lcd-ml-direct\tools\joystick_map_ui.py
```

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

The separate diagnostic design
`rtl/output_files_joystick_diag/cyclone2_joystick_diag.sof` maps each control
to the verified board mapping below. Internally the RTL vector is zero-based
(`led[0]` through `led[3]`), but the board labels are LED1 through LED4.
It is a temporary direction-test image, not the ML image.

## Verified joystick direction mapping

This mapping is loaded in the current diagnostic SOF (checksum `0x00070D15`):

| Physical action | FPGA input pin | Board indicator |
|---|---:|---|
| Push UP | `PIN_139` | LED1 |
| Push DOWN | `PIN_137` | LED2 |
| Push LEFT | `PIN_142` | LED3 |
| Push RIGHT | `PIN_141` | LED4 |
| Press joystick center | `PIN_143` | LED1, LED2, LED3, LED4 |

The mapping was corrected using the observed opposite LED pairs: UP/DOWN are
LED1/LED2 and LEFT/RIGHT are LED3/LED4. The center press is on `PIN_143`.

### Permanent diagnostic rule

Keep LED1–LED4 connected to the four directional outputs whenever testing the
joystick. The LEDs are the hardware direction indicators and must accompany
the joystick so the physical direction can be identified without relying on
the PC UI. Do not repurpose these LEDs until the joystick mapping is fully
verified.

The diagnostic SOF was downloaded successfully to the EP2C5 on 2026-10-05.
Quartus Programmer reported one configured device and checksum `0x00070D15`.
After testing, reload
`rtl/output_files_hw/cyclone2_lcd_ml_hw.sof` to return to the ML design.

## Physical test

With the board powered and the wrapper SOF loaded, use a multimeter or a
temporary LED/debug input to confirm each switch reads high at rest and low
while pressed. Do not infer direction from the LCD orientation; use the labels
on the joystick and this pin table.
