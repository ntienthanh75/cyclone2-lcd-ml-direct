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

## LCD displacement diagnosis (2026-10-06)

The previous side-displaced touch mark was investigated before changing the
LCD orientation again. The original Nios driver was used as the reference:
it maps raw touch X to logical LCD X, raw touch Y to logical LCD Y, and for
`DISP_ORIENTATION=90` writes GRAM coordinates `(x_hw,y_hw)=(logical_y,
319-logical_x)`.

Two independent issues were found:

1. The HDL 14-cell calibration table had incorrect X centers from cell 4
   onward. It skipped the 103-pixel center and shifted subsequent cells by
   11 pixels. The table now uses the equal-cell centers
   `11,34,57,80,103,126,149,171,194,217,240,263,286,309`.
2. The LCD writer test only checked that command/data traffic existed. It now
   checks a known point: logical `(100,80)` must produce GRAM X `80` and GRAM
   Y `219`.

The corrected writer passes ModelSim and Quartus compilation. The bitstream
must still be downloaded and checked on hardware; a passing simulation does
not prove the panel wiring or physical touch calibration.

The first hardware download still showed vertical stripes and horizontal
bands. This indicates incomplete LCD bus writes rather than only a touch
coordinate offset. The writer now holds `WR` low for four processing-clock
cycles, matching the proven VHDL driver. ModelSim still passes, and the new
Quartus build has positive setup slack (`18.502 ns` on `clk50`).

The complete reset investigation found the more specific error: the HDL was
reprogramming GRAM address registers for every clear pixel. The reference
driver writes the cursor once, writes `0x0022` once, and then streams all
76,800 pixels. The clear path now follows that exact sequence. This directly
addresses the repeated bands; touch calibration was not changed in this
correction.

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

### Frequency sweep

The same RTL was compiled at three clock constraints. Only the clock period
changed; each report is stored under
[`synthesis/frequency-sweep`](synthesis/frequency-sweep).

| Constraint | Logic elements | Memory bits | Multipliers | Slow setup slack | Slow hold slack | Calculated Fmax | Status |
|---:|---:|---:|---:|---:|---:|---:|---|
| 25 MHz | 3,661 (79%) | 55,888 (47%) | 5 (19%) | -50.736 ns | +0.499 ns | 11.02 MHz | FAIL |
| 10 MHz | 3,661 (79%) | 55,888 (47%) | 5 (19%) | +5.292 ns | +0.499 ns | 10.56 MHz | PASS* |
| 5 MHz | 3,590 (78%) | 55,888 (47%) | 5 (19%) | +70.138 ns | +0.499 ns | 7.70 MHz | PASS* |

`PASS*` means timing passed the selected constraint only. It does not mean
the board is ready: physical pins are still unassigned, and the design has
not been downloaded or tested on hardware. The conservative choice from this
sweep is 5 MHz; 10 MHz also passes but has only 5.292 ns of slow-corner
margin. A later pipeline experiment is still needed if higher performance is
required.

### Timing-repair experiment: serialized score scan

The baseline timing failure was traced to the `FINISH` state in the shared ML
core. It compared all ten output scores, selected the best digit and second
best score, and calculated the margin in one combinational path. Adding a
register only at the hidden/output boundary would not remove that path.

The isolated experiment
[`rtl/experiments/ml_inference_scanpipe.sv`](rtl/experiments/ml_inference_scanpipe.sv)
keeps the MAC operations and weights unchanged. It compares one score per
clock, then registers the result. Its wrapper is
[`rtl/experiments/touch_ml_scanpipe_top.sv`](rtl/experiments/touch_ml_scanpipe_top.sv).
The production core is unchanged.

| Build | Logic elements | Memory bits | Multipliers | Setup slack | Functional result |
|---|---:|---:|---:|---:|---|
| Baseline 5 MHz | 3,590 (78%) | 55,888 (47%) | 5 (19%) | +70.138 ns | digit 7, 13,411 cycles |
| Scan-pipeline 5 MHz | 2,267 (49%) | 55,888 (47%) | 5 (19%) | +172.323 ns | digit 7, 13,420 cycles |
| Baseline 10 MHz | 3,661 (79%) | 55,888 (47%) | 5 (19%) | +5.292 ns | timing PASS* |
| Scan-pipeline 10 MHz | 2,267 (49%) | 55,888 (47%) | 5 (19%) | +70.647 ns | timing PASS* |

The scan pipeline adds nine cycles, about 1.8 microseconds at 5 MHz, but
removes the long score-ranking path. The real-weight regression output is:

```text
PASS: touch-to-ML integration; digit=7 confidence=71 margin=25 cycles=13420 accepted=1
```

Reports are stored in
[`synthesis/pipeline-experiments`](synthesis/pipeline-experiments), and the
dedicated test is
[`verification/touch_ml_scanpipe_top_tb.sv`](verification/touch_ml_scanpipe_top_tb.sv)
using [`verification/scanpipe_run.do`](verification/scanpipe_run.do).
This is still simulation/synthesis evidence only; do not download it until
the actual EP2C5T144C8 pin table is assigned and reviewed.

The measured control experiment is also retained under
[`synthesis/pipeline-experiments`](synthesis/pipeline-experiments): an
explicit register bank before the original score-ranking scan. It passes the
same functional test with `digit=7` and adds one cycle, but uses 3,894 LEs at
5 MHz and 3,841 LEs at 10 MHz. Its 10 MHz setup slack is only `+1.119 ns`,
showing that a register boundary alone does not break the long ranking path.
It is therefore rejected in favor of the serialized score scan.

## Preferred implementation and next checklist

The board-level wrapper milestone is documented in
[`docs/hardware-wrapper-milestone.md`](docs/hardware-wrapper-milestone.md).
The complete joystick direction map is in
[`docs/joystick-pin-map.md`](docs/joystick-pin-map.md).
For a visual map, run `python tools/joystick_map_ui.py`.
For a live LED direction test, use the separate diagnostic project
`rtl/cyclone2_joystick_diag.qpf`; its SOF temporarily replaces the ML image.
It records the exact CoreEP2C5 pin assignments, the real 50 MHz input clock,
the derived 5 MHz processing clock, and the Quartus timing/resource results.

The preferred RTL for the direct path is
[`rtl/experiments/touch_ml_scanpipe_top.sv`](rtl/experiments/touch_ml_scanpipe_top.sv)
with [`rtl/experiments/ml_inference_scanpipe.sv`](rtl/experiments/ml_inference_scanpipe.sv).
The original core and the registered-boundary variant are retained as
references. The board-level wrapper is
[`rtl/cyclone2_lcd_ml_hw.sv`](rtl/cyclone2_lcd_ml_hw.sv), with exact
CoreEP2C5 assignments in `rtl/cyclone2_lcd_ml_hw.qsf`. Its fitted SOF is a
hardware candidate; physical touch and LED verification remain outstanding.

Before downloading, complete these items in order:

1. Confirm the real board clock pin and frequency.
2. Confirm XPT2046 touch IRQ, MISO, CS, SCLK, MOSI, and reset wiring.
3. Decide which result/debug outputs are physically connected.
4. Review the exact `set_location_assignment` entries in the board wrapper.
5. Recompile and inspect timing, pin, and fitter reports. **Done for the
   current wrapper.**
6. Download the resulting `.sof`. The previous image was accepted by the
   board; the updated LCD-writer image must be tested separately.
7. Perform and record the first touch/joystick/LED board test.
8. Perform and record the LCD test: after startup the panel must clear white,
   then each touch must leave a visible black 5x5 mark immediately. A blank
   LCD is a failed LCD-writer test, even if Quartus programming succeeds.

## Current LCD and busy diagnosis

The earlier wrapper had the touch reader and ML stream but no LCD data or
ILI9325 command writer. Touches could therefore be captured internally while
nothing was sent to the panel. `rtl/lcd_live_writer.sv` now reuses the
known-good initialization sequence from `D:\fpga\lcd_photo_hdl`, clears the
panel, and writes each calibrated point as a 5x5 black square without Nios.
Its self-checking test is `verification/lcd_live_writer_tb.sv`.

The first hardware attempt did not produce the expected white panel. Before
the second download, the clear-address path was corrected from a truncated
9-bit X coordinate to a full 10-bit 0..319 coordinate, and LCD CS was kept
asserted during reset/initialization to match `lcd_photo_hdl`. The corrected
SOF was compiled and downloaded successfully; hardware display behavior is
still awaiting visual confirmation.

The latest image changes the clear operation to match the old driver exactly:
after initialization and its final delay, it streams 76,800 white GRAM writes
from the existing GRAM start address instead of rewriting X/Y for every pixel.
This addresses the striped-screen result observed in the first corrected image.

The following hardware capture showed a remaining top band and touch marks
appearing at the side. The original Nios source confirms
`DISP_ORIENTATION=90`: logical `(x,y)` maps to GRAM `(y,319-x)`, and logical
`(0,0)` starts at GRAM `(0,319)`. The current RTL applies this mapping for
both the white clear start address and the 5x5 touch marks.

LED1+LED3 means that the serialized ML core is processing the submitted
196-pixel frame; it is not an LCD acknowledgement. The expected sequence is
submit indication, brief ML-busy indication, result indication, then the
recognized-digit display. If LED1+LED3 persists after a complete frame should
have finished, record whether any touch mark appeared and reload the new SOF
before repeating; this distinguishes LCD initialization from ML behavior.

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
