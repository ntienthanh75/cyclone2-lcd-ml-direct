# Cyclone II Direct LCD-to-ML

Option 2 architecture for the CoreEP2C5 board:

```text
LCD touch -> FPGA frame capture -> ML core -> digit/result to PC
                         \------> frame mirror to PC
```

This is a new SystemVerilog project. It is intentionally separate from
`cyclone2-handwriting-ml` and `Lcd_touch` until the architecture fits and
passes synthesis.

## Current status

The project is being implemented in small, independently synthesized stages.
The coordinate adapter and the Nios-free raw XPT2046 SPI reader now compile.
There are still no final board pin assignments and no hardware-download image.

Read [SPEC.md](SPEC.md) first, then
[docs/architecture.md](docs/architecture.md) and the staged
[implementation plan](docs/implementation-plan.md).
The required entry/exit criteria and verification evidence for every stage
are in [docs/milestone-verification-plan.md](docs/milestone-verification-plan.md).

## Before every commit

Open [docs/milestone-verification-plan.md](docs/milestone-verification-plan.md)
and check whether any requirement or verification item is now complete. Update
the milestone table, record the evidence and tool result, and state the next
step before committing. Do not mark a hardware milestone complete from
simulation or synthesis alone.

The former `lcd_touch_ml` planning folder has been consolidated here. This is
now the single project for direct LCD-touch-to-ML integration; the reusable
classifier remains in `cyclone2-handwriting-ml`.

## First implementation milestone

The first RTL step is now present in
[`rtl/touch_frame_adapter.sv`](rtl/touch_frame_adapter.sv). It accepts
already-decoded LCD coordinates, marks the corresponding 14×14 cell, and
streams 196 four-bit pixels using the same signals as `ml_inference.sv`.
The XPT2046 SPI decoder, LCD writer, full drawing buffer, and PC result link
are intentionally not implemented in this step. The standalone test is in
[`verification/touch_frame_adapter_tb.sv`](verification/touch_frame_adapter_tb.sv).

The adapter also has a minimal Quartus project under `rtl/`. The first
divider version used 1,139 logic cells with +8.378 ns setup slack. The current
threshold version uses 577 logic cells with +8.811 ns setup slack at 50 MHz.
This is still an adapter-only build with unassigned pins; it is not yet a
board-download image.

## Second implementation milestone: raw touch reader

[`rtl/xpt2046_reader.sv`](rtl/xpt2046_reader.sv) is a standalone Nios-free
reader for the XPT2046 controller. It follows the same protocol as the
working Nios application: command `0xD0` for X, command `0x90` for Y, SPI mode
0, and sixteen response clocks. The response is converted with `response >> 3`
to the same 12-bit raw ADC value used by the Nios code.

The reader waits for active-low `TOUCH_IRQ`, performs one X and one Y
conversion, pulses `sample_valid`, and then waits for release. It exposes
`raw_x` and `raw_y`; it does not yet calibrate coordinates, draw to the LCD,
capture a frame, or invoke the ML core.

The standalone reader project is `rtl/xpt2046_reader.qpf`. Quartus II 13.0
SP1 compiled it for EP2C5T144C8 with 124 logic cells and +12.342 ns worst-case
setup slack at a temporary 50 MHz constraint. The fitter warning about
unassigned pins is intentional for this isolated RTL milestone.

The reader test is
[`verification/xpt2046_reader_tb.sv`](verification/xpt2046_reader_tb.sv). It
models the XPT2046 SPI slave with known X/Y response words and checks the
12-bit conversion and `sample_valid` pulse. Synthesis has passed; the
ModelSim passes the two-transaction sequence and expected X/Y values. The
original one-bit mismatch was fixed by using the already-sampled final bit
instead of appending `touch_miso` a second time on the falling edge.

## Third implementation milestone: calibration

[`rtl/xpt2046_calibrator.sv`](rtl/xpt2046_calibrator.sv) converts raw
XPT2046 values from the working Nios range `200..3900` into the centre of one
of fourteen LCD coordinate bins. Its testbench is
[`verification/xpt2046_calibrator_tb.sv`](verification/xpt2046_calibrator_tb.sv),
which passes low, middle, and high coordinate checks. Quartus synthesis uses
129 logic cells. The block is verified in isolation and is not yet connected
to the board-level touch reader or frame adapter.

## Fourth implementation milestone: integrated capture boundary

[`rtl/touch_capture_top.sv`](rtl/touch_capture_top.sv) connects the raw
XPT2046 reader, calibrator, and 14×14 frame adapter. Its self-checking test
[`verification/touch_capture_top_tb.sv`](verification/touch_capture_top_tb.sv)
passes known X/Y response words and verifies the ordered 196-pixel stream.
Quartus synthesis uses 824 logic cells with +3.349 ns worst-case setup slack
at 50 MHz. The top level still has no physical pin assignments, so it has not
been downloaded to the board.

## Fifth implementation milestone: touch stream to ML core

[`rtl/touch_ml_top.sv`](rtl/touch_ml_top.sv) is a thin SystemVerilog
boundary. It reuses `ml_inference.sv` from the separate
`cyclone2-handwriting-ml` repository; it does not create a second classifier.
The integrated path is:

```text
XPT2046 touch SPI -> raw reader -> calibration -> 14x14/196-pixel stream
                  -> reusable 196-to-32-to-10 ML core -> result fields
```

The four MIF files under `artifacts/` are the synthesis inputs for this
project. The integration smoke test is
[`verification/touch_ml_top_tb.sv`](verification/touch_ml_top_tb.sv). It
injects the known X/Y SPI response, starts one 196-pixel frame, and waits for
the ML result. With the real trained weights it passes with `digit=7`,
`confidence=71`, `margin=20`, and `13,411` clock cycles. This is functional
simulation evidence, not a hardware result.

Quartus II 13.0 SP1 fits the reduced external boundary on EP2C5T144C8:
3,661 logic elements (79%), 55,888 memory bits (47%), and 5 embedded
multipliers. At the temporary 50 MHz constraint, setup timing fails with
`-71.005 ns` worst-case slack. The fit also reports unassigned physical pins,
so this image is not yet a valid 50 MHz hardware download.

## Target

- Board: Waveshare/CoreEP2C5
- FPGA: Altera/Intel Cyclone II EP2C5T144C8
- Principal HDL: SystemVerilog
- LCD/touch: attached 320×240 module with XPT2046 resistive touch controller
- ML input: 14×14 pixels, 4-bit grayscale, 196 pixels
- Runtime PC path: CY7C68013A FX2 WinUSB, subject to final pin/interface fit

## Important limitation

The existing LCD/Nios image and the existing ML bridge image cannot be merged
by simply loading both SOFs. Their measured logic usage is approximately 93%
and 68% separately, or 161% when added. This project therefore removes Nios
from the direct path and investigates a small RTL touch/frame-capture design.

No fit or hardware-feasibility claim is valid until the new top level is
synthesized against the actual EP2C5T144 device.
