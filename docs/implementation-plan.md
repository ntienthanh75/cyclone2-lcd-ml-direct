# LCD Touch → FPGA ML Implementation Plan

This document consolidates the former `lcd_touch_ml` integration checklist
into the direct LCD-to-ML project. The project has one authoritative plan and
one reusable classifier boundary.

## Current progress

- [x] Create a small coordinate-to-14×14 adapter.
- [x] Verify four corner points and the 196-pixel stream in a standalone testbench.
- [x] Synthesize the adapter as an EP2C5T144C8 Quartus project.
- [x] Replace coordinate division with threshold mapping to reduce logic.
- [x] Implement a standalone Nios-free XPT2046 raw SPI reader.
- [x] Add a self-checking XPT2046 protocol testbench with known X/Y response words.
- [x] Implement and verify a standalone raw-to-LCD calibration block.
- [x] Connect the raw reader and calibrator to the frame adapter.
- [ ] Connect the stream to the reusable ML core.

## Verification rule for each implementation step

Each step must have all three items below before it is considered complete:

1. A small RTL boundary with explicit input/output signals.
2. A self-checking simulation or a documented synthesis check with expected
   resource/timing limits.
3. A recorded result and a clear list of what remains outside the step.

The current evidence is:

| Step | Implementation | Verification | Status |
|---|---|---|---|
| 1 | Coordinate to 14×14 adapter | `verification/touch_frame_adapter_tb.sv` plus Quartus fit/timing | Complete |
| 2 | Threshold mapping replaces division | Quartus resource/timing comparison | Complete |
| 3 | Raw XPT2046 SPI reader | `verification/xpt2046_reader_tb.sv` plus standalone Quartus fit/timing | Complete: simulation and synthesis pass |
| 4 | Calibration and frame connection | Test raw-to-screen mapping and streamed pixels | Complete in simulation/synthesis; board pins pending |
| 5 | ML-core connection | End-to-end known-frame prediction test | Not started |

## A. Confirm the touch source

- [ ] Confirm the LCD touch controller and calibrated coordinate range.
- [ ] Confirm whether the current touch design returns raw points, a PC viewer
      stream, or both.
- [ ] Record screen orientation and map raw coordinates to the 240×320 panel.
- [ ] Keep the buzzer muted in every hardware image.

## B. Capture one drawing

- [ ] Start a new drawing buffer when the user begins touching the LCD.
- [ ] Append touch points while the finger or stylus is down.
- [ ] Join consecutive points into anti-aliased or one-pixel strokes.
- [ ] Use joystick UP as the end-of-writing command.
- [ ] Save the captured drawing to a PNG or PGM file on the PC for inspection.
- [ ] Clear the LCD and prepare the next drawing.
- [ ] Use joystick DOWN as the documented shutdown/stop command.

## C. Normalize for the classifier

- [ ] Convert the drawing to a 240×320 grayscale bitmap.
- [ ] Detect the foreground and reject an empty drawing.
- [ ] Compute the digit bounding box with a margin.
- [ ] Reject unusably small, huge, or multiply disconnected drawings.
- [ ] Preserve aspect ratio and center the digit on a square canvas.
- [ ] Resize to 28×28, then area-average to 14×14.
- [ ] Quantize pixels to unsigned 4-bit values (`0..15`).
- [ ] Export the 28×28 and 14×14 intermediates for debugging.

## D. Reuse the ML model

- [ ] Use the exact 196-pixel contract from the reusable handwriting-ML
      project.
- [ ] Reuse its trained `196 → 32 → 10` model and quantized weights.
- [ ] Return digit `0..9`, confidence, margin, and inference latency.
- [ ] Return `NON_RECOGNIZABLE` for preprocessing failure, low confidence, or
      an ambiguous top-two score margin.
- [ ] Do not create a second classifier in this project.

## E. Hardware integration order

1. Validate touch capture to a PC image file.
2. Validate PC normalization against the ML reference model.
3. Test PC-fed FPGA inference with the normalized tensor.
4. Integrate touch capture and inference on the FPGA.
5. Validate the direct LCD display path and PC result reporting.

## First synthesis result

The standalone adapter compiles successfully with Quartus II 13.0 SP1 for
EP2C5T144C8 at the temporary 50 MHz constraint.

| Version | Logic cells | Worst setup slack | Note |
|---|---:|---:|---|
| Divider mapping | 1,139 | +8.378 ns | Two inferred divider megafunctions |
| Threshold mapping | 577 | +8.811 ns | Current implementation |

Threshold mapping saves 562 logic cells (about 49%) and slightly improves
timing. The compile still reports unassigned pins because this is an adapter
milestone, not a board top level; no `.sof` should be downloaded to hardware
from this project yet.

## Second synthesis result: raw XPT2046 reader

The raw reader is compiled separately so its SPI timing and protocol can be
checked before it is connected to the frame adapter. It uses a divider of 25
on the temporary 50 MHz clock, producing a 1 MHz SCLK. It performs two
transactions per touch sample: X (`0xD0`) followed by Y (`0x90`).

| Module | Logic cells | Worst setup slack | Scope |
|---|---:|---:|---|
| `xpt2046_reader.sv` | 124 | +12.342 ns | Raw X/Y SPI conversion only |

This result is not a complete board result: no physical clock, IRQ, MISO,
MOSI, SCLK, or CS locations are assigned yet. The next step is calibration
and adapter integration, followed by a new top-level pin assignment review.

The protocol testbench is
[`verification/xpt2046_reader_tb.sv`](../verification/xpt2046_reader_tb.sv).
It supplies known X/Y response words and checks that the reader performs two
transactions and emits the expected 12-bit values. ModelSim now passes this
test. The original mismatch was caused by the RTL appending `touch_miso`
again on the falling edge even though the final bit had already been sampled
on the preceding rising edge. Removing that second shift fixed the alignment.

## Third synthesis result: calibration block

`rtl/xpt2046_calibrator.sv` converts the raw range used by the working Nios
application (`200..3900`) into fourteen fixed raw bins. Each bin emits the
centre coordinate of one 14×14 LCD cell. This avoids division and keeps the
frame adapter contract unchanged.

| Module | Logic cells | Timing result | Verification |
|---|---:|---|---|
| `xpt2046_calibrator.sv` | 129 | Quartus compile successful; isolated wrapper has no registered setup paths | ModelSim PASS |

The test is
[`verification/xpt2046_calibrator_tb.sv`](../verification/xpt2046_calibrator_tb.sv).
It checks low, middle, and high raw coordinates and verifies the emitted point
valid pulse. This is still an isolated module; it has no physical pin
assignments and must not be downloaded as a board design.

LCD drawing/viewer UI remains separate from classifier RTL. Reading arbitrary
pixels already displayed by the LCD is not assumed: touchscreen strokes are
coordinate input, while LCD GRAM readback requires a separate controller.

## Fourth implementation step: integrated touch capture boundary

`rtl/touch_capture_top.sv` now connects the existing raw reader, calibrator,
and 14×14 frame adapter. It exposes the reader pins plus the ML pixel stream,
and includes raw X/Y and sample-valid debug outputs. The standalone Quartus
project is `rtl/touch_capture_top.qsf`; physical pin assignments remain
intentionally absent.

The end-to-end self-checking test is
`verification/touch_capture_top_tb.sv`. It injects known X/Y response words,
checks the converted raw values, and counts exactly 196 streamed pixels.
ModelSim passes the integration test. Quartus synthesis for EP2C5T144C8 uses
824 logic cells and reports +3.349 ns worst-case setup slack at 50 MHz.
The design still has unassigned top-level pins, so this remains a
simulation/synthesis milestone and is not a hardware-download image.

## F. Validation set

- [ ] Collect at least 20 drawings for each digit `0..9`.
- [ ] Test multiple users, stroke widths, positions, and rotations.
- [ ] Measure accuracy separately from MNIST accuracy.
- [ ] Calibrate rejection thresholds on real LCD drawings.
- [ ] Report a confusion matrix and rejection rate.
