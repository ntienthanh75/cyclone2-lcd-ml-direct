# Hardware wrapper milestone: CoreEP2C5 direct LCD-touch ML

## Purpose

This milestone converts the preferred serialized-score simulation wrapper into
a board-level Quartus design. It does not claim that the LCD touch panel has
already been tested on the physical board.

## Implementation

1. `rtl/cyclone2_lcd_ml_hw.sv` is the new board wrapper.
2. The physical oscillator on `PIN_17` is 50 MHz.
3. A divide-by-10 generated clock provides a 5 MHz processing clock. The
   touch reader, 14x14 frame adapter, and serialized ML core all use that same
   domain, so the one-cycle frame stream is not lost between clock domains.
4. Touch inputs use the board map: IRQ `PIN_129`, MISO `PIN_135`, CS `PIN_134`,
   SCLK `PIN_133`, and MOSI `PIN_136`.
5. Joystick UP `PIN_139` starts one frame stream; joystick DOWN `PIN_143`
   clears the captured frame. Both are active-low and edge-detected.
6. The recognized digit is latched on `led[3:0]` and driven with the board's
   active-low LED polarity. The buzzer on `PIN_4` is forced to logic 1, so it
   remains muted.
7. Reset uses `PIN_88`. Its weak pull-up was deliberately not assigned because
   Quartus reports that pin 88 does not support that option.

## Verification performed

- Full Quartus 13.0 SP1 compile: **PASS**, 0 errors.
- Device fit: **PASS**, EP2C5T144C8.
- 50 MHz input setup slack: **+18.487 ns** (slow corner).
- 5 MHz processing-clock setup slack: **+171.126 ns** (slow corner).
- Hold slack: **+0.499 ns** for both clock domains.
- Resource result: 2,226 logic cells, 124 RAM segments, 5 DSP elements.
- The generated-clock constraint is recognized as `proc_clk` at 200 ns;
  there are no SDC warnings in the final TimeQuest run.
- RTL smoke-test source: `verification/cyclone2_lcd_ml_hw_tb.sv`.
- RTL smoke-test command file: `verification/hardware_wrapper_run.do`.

## Important boundary

The `.sof` generated at
`rtl/output_files_hw/cyclone2_lcd_ml_hw.sof` is a fitted hardware candidate,
not yet a hardware result. The next physical step is to download it only after
the board is connected, then verify reset, touch SPI activity, joystick UP,
joystick DOWN, and the LED digit output one at a time.

## Checklist

- [x] Find and record the CoreEP2C5 clock, reset, touch, joystick, LED, and
  buzzer pins.
- [x] Add the board wrapper and exact QSF pin assignments.
- [x] Implement the 50 MHz to 5 MHz processing-clock path.
- [x] Add generated-clock timing constraints.
- [x] Compile, fit, assemble, and run TimeQuest.
- [x] Add the wrapper smoke-test source and run command file.
- [x] Run the wrapper smoke test in ModelSim: `PASS: hardware wrapper; proc
  clock divider, controls, LEDs, buzzer mute`.
- [x] Download the candidate SOF to the physical FPGA over USB-Blaster JTAG.
  Quartus Programmer reported one EP2C5T144@1 device configured successfully
  with SOF checksum `0x002933CB`.
- [ ] Verify touch capture and digit display on the board.

## First hardware test after programming

1. The buzzer must remain silent.
2. Press joystick DOWN once; the captured 14x14 frame is cleared and LEDs
   should show the inactive value.
3. Touch several points on the LCD. This design reads the XPT2046 touch
   controller; it does not redraw pixels on the LCD.
4. Release the touch panel and press joystick UP once. The ML transaction
   takes roughly 2.7 ms at 5 MHz; the result digit is then latched on the four
   LEDs using the board's active-low LED polarity.
5. Repeat with a simple digit-shaped drawing. Record whether touch SPI pins
   toggle and whether the LED pattern changes.
