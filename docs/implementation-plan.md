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
- [x] Connect the stream to the reusable ML core boundary.
- [x] Sweep the integrated design at 25 MHz, 10 MHz, and 5 MHz and record
      resource/timing results before choosing an operating point.
- [ ] Compare three timing-repair variants against the 5 MHz baseline:
      baseline, layer-boundary registers, and deeper MAC pipelining.

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
| 5 | ML-core connection | End-to-end known-frame prediction test plus Quartus fit/timing | Functional simulation and fit pass; 50 MHz timing fails |

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

## Fifth implementation step: reusable ML integration

`rtl/touch_ml_top.sv` instantiates the authoritative
`rtl/touch_capture_top.sv` boundary and the reusable
`../../cyclone2-handwriting-ml/rtl/ml_inference.sv` source. The 196 pixels,
pixel index, frame-last, and reset/clock-enable contract are connected
directly; no Nios processor or LCD display path is added. The result boundary
exports `result_valid`, `result_accepted`, digit, confidence, margin, and
cycle count.

The local `artifacts/` directory contains copies of the four required MIF
files so Quartus can package the same trained weights. The testbench
`verification/touch_ml_top_tb.sv` injects the known XPT2046 response, waits
for the 196-pixel stream, and waits for the classifier result. ModelSim passes
with the real weights:

```text
PASS: touch-to-ML integration; digit=7 confidence=71 margin=20 cycles=13411 accepted=1
```

The first simulation attempt used an incorrect working directory and loaded
no MIF files; it was rejected as evidence. Running ModelSim from the original
ML project's verification directory resolves the shared core's existing
`../../artifacts` path and loads the real weights.

Quartus full compile for `rtl/touch_ml_top.qsf` succeeds through synthesis,
fit, assembly, and timing analysis. The fitted design uses 3,661 logic
elements (79%), 55,888 memory bits (47%), and 5 embedded multipliers (19%).
The temporary 50 MHz constraint reports worst-case setup slack `-71.005 ns`
and hold slack `+0.499 ns`. This means the integration is not timing-closed
at 50 MHz and must not be downloaded as a claimed working hardware image.
The next design milestone is to reduce or pipeline the ML critical path and
repeat timing at the selected clock, while keeping the passing functional
integration test unchanged.

## Sixth implementation step: frequency sweep

Before changing RTL, run the same integrated design at 25 MHz, 10 MHz, and
5 MHz. The sweep must preserve the source, device, and synthesis options so
that only the clock period changes. Store each report under
`synthesis/frequency-sweep/<frequency>/` and compare logic elements, memory,
multipliers, setup slack, hold slack, and Fmax. A lower frequency may make the
design usable, but it does not repair the long combinational ML path; that
remains a separate pipeline/resource tradeoff.

## Seventh implementation step: pipeline trade-off experiment

Keep the current `ml_inference.sv` unchanged as the baseline. Evaluate three
separate variants using the same trained weights and 14×14 input contract:

1. Baseline sequential MAC, constrained at 5 MHz and 10 MHz.
2. Add registers at the hidden-layer/output-layer boundary.
3. Add a deeper registered MAC path, accepting extra latency if timing and
   logic/RAM/DSP use improve.

For every variant, run the existing functional ML verification first, then
compile at 5 MHz and 10 MHz. Record logic elements, registers, memory bits,
multipliers, latency cycles, setup slack, and Fmax. Do not replace the
baseline or claim hardware readiness until the comparison is complete.

### Sweep result

| Constraint | Logic elements | Memory bits | Multipliers | Slow setup | Slow hold | Fmax | Result |
|---:|---:|---:|---:|---:|---:|---:|---|
| 25 MHz | 3,661 | 55,888 | 5 | -50.736 ns | +0.499 ns | 11.02 MHz | Fail |
| 10 MHz | 3,661 | 55,888 | 5 | +5.292 ns | +0.499 ns | 10.56 MHz | Pass |
| 5 MHz | 3,590 | 55,888 | 5 | +70.138 ns | +0.499 ns | 7.70 MHz | Pass |

The 5 MHz fit used fewer logic elements because Quartus made a different
placement/optimization choice; the memory and multiplier use are unchanged.
The sweep selects 5 MHz as the safer provisional clock, while 10 MHz is the
fastest tested passing constraint. Neither is a hardware sign-off because the
pin table remains unresolved.

### Pipeline experiment result 1: serialized score ranking

The timing report identified the original FINISH state's ten-score winner and
runner-up scan as the dominant combinational path. The isolated experiment in
`rtl/experiments/ml_inference_scanpipe.sv` keeps the MAC schedule and trained
weights unchanged, but compares one score per clock in `SCAN_STEP` and
publishes the result in `SCAN_FINISH`. The production `ml_inference.sv` is not
replaced.

Functional verification passed with the real MIF weights:

```text
PASS: touch-to-ML integration; digit=7 confidence=71 margin=25 cycles=13420 accepted=1
```

The extra nine cycles are the cost of replacing the one-cycle ten-score scan
with nine registered comparisons. At 5 MHz this adds about 1.8 microseconds;
the dominant ML latency remains about 2.68 milliseconds.

| Variant / constraint | Logic elements | Memory bits | Multipliers | Setup slack | Hold slack | Approx. Fmax | Result |
|---|---:|---:|---:|---:|---:|---:|---|
| Baseline, 5 MHz | 3,590 (78%) | 55,888 (47%) | 5 (19%) | +70.138 ns | +0.499 ns | 7.70 MHz reported | PASS |
| Serialized scan, 5 MHz | 2,267 (49%) | 55,888 (47%) | 5 (19%) | +172.323 ns | +0.499 ns | ~36.1 MHz path limit | PASS |
| Baseline, 10 MHz | 3,661 (79%) | 55,888 (47%) | 5 (19%) | +5.292 ns | +0.499 ns | 10.56 MHz reported | PASS* |
| Serialized scan, 10 MHz | 2,267 (49%) | 55,888 (47%) | 5 (19%) | +70.647 ns | +0.499 ns | ~34.1 MHz path limit | PASS* |

`PASS*` still means timing-only: exact board pin assignments and a hardware
test are missing. The serialized scan is currently the preferred repair
candidate because it removes the measured critical path without adding DSP or
RAM blocks. A deeper MAC pipeline remains a separate experiment if more
throughput is required.

The complete synthesis projects and reports are stored under
`synthesis/pipeline-experiments/scanpipe-5MHz/` and
`synthesis/pipeline-experiments/scanpipe-10MHz/`. The dedicated regression is
`verification/touch_ml_scanpipe_top_tb.sv`, run by
`verification/scanpipe_run.do`.

## F. Validation set

- [ ] Collect at least 20 drawings for each digit `0..9`.
- [ ] Test multiple users, stroke widths, positions, and rotations.
- [ ] Measure accuracy separately from MNIST accuracy.
- [ ] Calibrate rejection thresholds on real LCD drawings.
- [ ] Report a confusion matrix and rejection rate.
