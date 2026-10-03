# Milestone Verification Plan

This file is the verification checklist for the direct LCD-to-ML project.
Each milestone must satisfy its requirements and produce evidence before the
next milestone starts. A successful Quartus compilation alone is not a
hardware verification result.

## Common rules

Every milestone must record:

1. The implementation boundary and its signals.
2. The expected behavior and measurable acceptance criteria.
3. The testbench or hardware procedure used.
4. The tool output, log, waveform, or photograph proving the result.
5. Known limitations and the exact next step.

Do not download an isolated milestone `.sof` to the board when its physical
pin assignments are incomplete. Hardware testing begins only after the
top-level pin table has been reviewed against the actual CoreEP2C5 wiring.

## Milestone 0 — Requirements and board contract

### Requirements

- Target device is `EP2C5T144C8` on the Waveshare/CoreEP2C5 board.
- Clock frequency and reset polarity are documented.
- LCD dimensions and controller are documented: 320×240, XPT2046 touch.
- Touch signals are named and mapped: `TOUCH_IRQ`, `TOUCH_MISO`,
  `TOUCH_MOSI`, `TOUCH_SCLK`, and `TOUCH_CS`.
- ML input contract is fixed at 196 pixels, 14×14, 4-bit grayscale.
- No Nios dependency is permitted in the direct path.

### Verification

- Review `SPEC.md`, `docs/architecture.md`, and the board pin table.
- Confirm every signal has one source, one destination, and one voltage level.

### Pass evidence

- Reviewed specification and pin table committed with the project.
- No unresolved wiring assumptions remain.

## Milestone 1 — Coordinate-to-frame adapter

### Requirements

- Accept decoded screen coordinates in the range X=0..319 and Y=0..239.
- Map each point to exactly one 14×14 cell.
- Support frame clear and stream control.
- Stream exactly 196 pixels using the ML input contract.
- Keep the adapter independent of LCD SPI and Nios.

### Verification

- Run `verification/touch_frame_adapter_tb.sv`.
- Test all four screen corners, center points, clear, stream start, and
  `input_frame_last`.
- Synthesize with Quartus for `EP2C5T144C8`.

### Pass criteria

- Testbench reports no errors.
- Exactly 196 ordered pixels are emitted per frame.
- Quartus analysis, fitting, and timing complete successfully.
- Resource and timing values are recorded in the implementation plan.

### Evidence

- Testbench source and simulator transcript.
- Quartus reports and resource/timing table.

## Milestone 2 — Resource-optimized coordinate mapping

### Requirements

- Replace runtime division with fixed threshold mapping.
- Preserve the coordinate-to-cell behavior from Milestone 1.
- Do not introduce inferred divider megafunctions.

### Verification

- Re-run the Milestone 1 testbench unchanged.
- Compare logic cells and timing against the divider implementation.
- Inspect synthesis messages for inferred dividers.

### Pass criteria

- Functional test remains identical to Milestone 1.
- Resource use is lower or the tradeoff is documented and accepted.
- Timing remains positive at the selected constraint frequency.

## Milestone 3 — Raw XPT2046 reader

### Requirements

- Operate without Nios.
- Detect active-low touch IRQ.
- Send X command `0xD0` and Y command `0x90`.
- Use SPI mode 0 and the documented serial clock rate.
- Produce one `raw_x`, `raw_y`, and `sample_valid` result per press.
- Insert the required CS-high gap between X and Y transactions.
- Prevent repeated samples until touch release.

### Verification

- Run `verification/xpt2046_reader_tb.sv` in ModelSim.
- Supply known 16-bit X/Y response words.
- Check transaction count, CS gap, raw 12-bit values, and `sample_valid`.
- Synthesize the standalone reader and record resources/timing.

### Pass criteria

- ModelSim reports `PASS` with no protocol or alignment errors.
- Quartus compilation and timing pass.
- The result is explicitly labelled simulation-only until board pins are
  assigned and a physical test is completed.

## Milestone 4 — Board top-level and physical touch capture

### Requirements

- Instantiate the reader and frame adapter in one SystemVerilog top level.
- Assign the real CoreEP2C5 clock, reset, and LCD touch pins.
- Preserve safe idle levels: CS inactive, SCLK idle, buzzer muted.
- Expose a debug path for raw X/Y and sample-valid events.

### Verification

- Run Quartus full compile with zero missing required pin assignments.
- Download the `.sof` using Quartus Programmer.
- Confirm JTAG identifies the single intended EP2C5 device.
- Touch at known positions and collect raw X/Y samples.
- Compare measured corner samples with the expected orientation.

### Pass criteria

- Programming succeeds on the physical board.
- Raw samples change only while the panel is touched.
- At least five samples each are collected near all four corners.
- No swapped axes, inversion, stuck IRQ, or repeated-sample fault remains.

### Evidence

- Pin-assignment report, programmer log, raw sample capture, and wiring photo.

## Milestone 5 — Calibration and 14×14 frame capture

### Requirements

- Convert raw X/Y ADC values to screen coordinates.
- Apply the documented orientation and clamping.
- Mark touched cells in the frame adapter.
- Clear the frame on command.
- Stream exactly 196 normalized pixels.

### Verification

- Unit-test calibration with recorded raw corner samples.
- Hardware-test a grid of known touch locations.
- Compare the streamed frame against a PC reference implementation.
- Test empty, single-point, line, and multi-stroke drawings.

### Pass criteria

- Coordinate error and cell error limits are documented and met.
- The PC reference and FPGA frame agree for the same touch trace.
- No frame data is emitted before a complete frame is requested.

## Milestone 6 — ML-core integration

### Requirements

- Reuse the existing `ml_inference.sv` interface and quantized weights.
- Connect the 196-pixel stream without changing pixel order or scale.
- Return digit, confidence, margin, and inference cycle count.
- Keep the ML result path separate from LCD drawing signals.

### Verification

- Run a known-frame SystemVerilog testbench against the integrated core.
- Compare FPGA results with the PC reference model.
- Test all ten digits, empty input, low-confidence input, and repeated frames.
- Synthesize the integrated design and record resource/timing use.

### Pass criteria

- Known test vectors match the reference model.
- Result-valid and busy handshakes have no dropped or duplicated frames.
- Resource and timing fit the EP2C5T144C8 budget.

## Milestone 7 — PC result and benchmark path

### Requirements

- Define one result transport path to the PC.
- Record sample identifier, source frame, predicted digit, confidence, margin,
  latency, and error status.
- Preserve the original label for benchmark samples.

### Verification

- Run a small smoke test first, then the planned benchmark set.
- Store every transaction result, timeout, and reset/recovery event.
- Produce accuracy, rejection rate, throughput, and latency statistics.

### Pass criteria

- Every submitted sample has exactly one recorded result or explicit error.
- Results can be compared automatically with labels.
- Benchmark logs and summary tables are reproducible.

## Milestone 8 — LCD display and complete interactive flow

### Requirements

- Keep the LCD drawing path independent from touch capture and ML timing.
- Show the current drawing or debug frame without corrupting the input data.
- Define joystick UP as finish/save and joystick DOWN as stop/shutdown.
- Keep the buzzer muted by default.

### Verification

- Test write, finish, save, clear, new drawing, and shutdown sequences.
- Confirm the PC receives the same frame used by the FPGA classifier.
- Run repeated sessions across reset and power-cycle conditions.

### Pass criteria

- Complete flow works for multiple drawings without stale-frame mixing.
- Saved PC image, displayed LCD frame, and FPGA input frame are traceable to
  the same sample identifier.
- README contains the final wiring, programming, operation, and recovery
  instructions.

## Current position

Milestones 1–4 have simulation and synthesis evidence. Milestone 4 uses
`touch_capture_top.sv`; its ModelSim integration test passes the X/Y response
path and all 196 streamed pixels, and Quartus reports 824 logic cells with
+3.349 ns setup slack at 50 MHz. It remains simulation/synthesis-only because
the real CoreEP2C5 pin table has not yet been assigned and no hardware test
has been run.

Milestone 4 status: **NO-GO for hardware**, **GO for RTL integration**.

Milestone 6 status: the touch-to-ML functional boundary is simulation-verified
with the real trained MIF weights. The bounded test reports one result after
13,411 cycles (`digit=7`, confidence `71`, margin `20`). Quartus fit succeeds
at EP2C5T144C8 with 3,661 logic elements, 55,888 memory bits, and 5 embedded
multipliers, but 50 MHz timing is **NO-GO** because setup slack is
`-71.005 ns` (hold slack `+0.499 ns`). Physical pin assignments are still
missing, so no hardware download or board result has been claimed.

Before the next milestone, check this file and record the timing-repair
choice. The required unchanged-design sweep at 25 MHz, 10 MHz, and 5 MHz is
recorded below; only after that comparison should a frequency or pipeline
change be selected.

The frequency sweep is now complete. At 25 MHz the design fails with
`-50.736 ns` setup slack. At 10 MHz it passes with `+5.292 ns`, and at 5 MHz
it passes with `+70.138 ns`. Resource use is approximately constant, so the
frequency does not materially reduce the design size. The provisional choice
is 5 MHz for margin; 10 MHz is the fastest tested passing constraint. Before
the next milestone, check this result and decide whether to keep 5 MHz or
start a pipelined ML experiment. Hardware remains NO-GO until pins are
assigned and the board is tested.

The next milestone is the pipeline trade-off experiment. Preserve the
5 MHz baseline and compare: (1) the current sequential MAC, (2) registers at
the hidden/output layer boundary, and (3) a deeper registered MAC path. Each
variant requires functional regression evidence before synthesis comparison.

### Pipeline experiment checkpoint

The first measured variant is the serialized score-ranking scan. It targets
the actual critical path found in the baseline timing report: the combinational
comparison of all ten output scores in one FINISH clock. The experiment adds
`SCAN_INIT`, `SCAN_STEP`, and `SCAN_FINISH` states and compares one score per
clock. It does not change the production core.

Verification result: PASS with real trained MIF files, digit 7, confidence 71,
margin 25, 13,420 cycles. Synthesis result: 2,267 logic elements, 55,888
memory bits, and 5 multipliers at both 5 MHz and 10 MHz; setup slack is
`+172.323 ns` at 5 MHz and `+70.647 ns` at 10 MHz. The baseline remains stored
under `synthesis/frequency-sweep/` for comparison. The scan-pipeline variant
is not hardware-approved because pin assignments remain unresolved.

The second control variant adds an explicit ten-word registered score boundary
before the original FINISH scan. It also passes functional verification
(`digit=7`, confidence 71, margin 20, 13,412 cycles), but uses 3,894 LEs at
5 MHz and 3,841 LEs at 10 MHz. Setup slack is only `+1.119 ns` at 10 MHz,
because the ten-way scan remains. This variant is rejected; it is retained as
measured evidence that a boundary register alone is not the right fix.
