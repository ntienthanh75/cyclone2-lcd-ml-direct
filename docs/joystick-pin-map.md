# CoreEP2C5 joystick pin map

Source: `D:\fpga\EP2C5-pin-conf.txt`.

For a visual orientation guide, run:

```powershell
python D:\fpga\cyclone2-lcd-ml-direct\tools\joystick_map_ui.py
```

The joystick switches are documented as active-low: an unpressed switch reads
`1`; pressing it connects the input to ground and reads `0`.

| Neutral joystick channel | FPGA pin | Diagnostic indicator |
|---|---:|---|
| Joystick 1 | `PIN_139` | LED1 |
| Joystick 2 | `PIN_137` | LED2 |
| Joystick 3 | `PIN_142` | LED3 |
| Joystick 4 | `PIN_141` | LED4 |
| Center press | `PIN_143` | LED1–LED4 |

This diagnostic intentionally does not claim which physical channel is UP,
DOWN, LEFT, or RIGHT. The channel-to-LED relationship is the only verified
requirement at this stage.

## LCD/ML integration channel actions

The hardware wrapper uses the same neutral channel numbers:

| Channel | Action |
|---|---|
| Joystick 1 | Submit the captured LCD frame to the ML pipeline |
| Joystick 2 | Clear the captured frame |
| Joystick 3 | Cancel/reset the current capture by clearing the frame |
| Joystick 4 | Latch a shutdown request for the processing pipeline |
| Center press | Light LED1–LED4 for physical confirmation |

LED1–LED4 continue to show the active channel while a channel is pressed.

The separate diagnostic design
`rtl/output_files_joystick_diag/cyclone2_joystick_diag.sof` maps each control
to the verified board mapping below. Internally the RTL vector is zero-based
(`led[0]` through `led[3]`), but the board labels are LED1 through LED4.
It is a temporary direction-test image, not the ML image.

## Verified joystick channel mapping

This mapping is loaded in the current diagnostic SOF (checksum `0x00070D15`):

| Input channel | FPGA input pin | Board indicator |
|---|---:|---|
| Joystick 1 | `PIN_139` | LED1 |
| Joystick 2 | `PIN_137` | LED2 |
| Joystick 3 | `PIN_142` | LED3 |
| Joystick 4 | `PIN_141` | LED4 |
| Center press | `PIN_143` | LED1, LED2, LED3, LED4 |

The observed opposite-pair arrangement is intentionally not converted into
direction names. This avoids guessing the physical orientation of the
joystick module.

### Permanent diagnostic rule

Keep LED1–LED4 connected to the four joystick-channel outputs whenever testing
the joystick. The LEDs are the hardware channel indicators and must accompany
the joystick test. Do not repurpose these LEDs until a later application
defines a stable physical orientation.

The diagnostic SOF was downloaded successfully to the EP2C5 on 2026-10-05.
Quartus Programmer reported one configured device and checksum `0x00070D15`.
After testing, reload
`rtl/output_files_hw/cyclone2_lcd_ml_hw.sof` to return to the ML design.

## Physical test

With the board powered and the wrapper SOF loaded, use a multimeter or a
temporary LED/debug input to confirm each switch reads high at rest and low
while pressed. Do not infer direction from the LCD orientation; use the labels
on the joystick and this pin table.
