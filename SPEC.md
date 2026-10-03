# Specification — Cyclone II Direct LCD-to-ML

## 1. Purpose

Create a single FPGA design in which a user writes on the LCD touch panel,
the FPGA captures the drawing directly, the ML classifier recognizes the
digit, and the PC receives both a frame mirror and the recognition result.

This is Option 2 from the LCD/ML integration analysis. The design must not
depend on the Nios CPU for the main capture, normalization, or classification
transaction.

## 2. Target hardware

| Item | Requirement |
|---|---|
| Board | Waveshare/CoreEP2C5 |
| FPGA | EP2C5T144C8, Cyclone II |
| LCD | 320×240 attached LCD module |
| Touch controller | XPT2046 resistive touch, SPI and active-low IRQ |
| FPGA configuration | USB-Blaster/JTAG `.sof` |
| PC runtime link | CY7C68013A FX2 WinUSB, if pin budget permits |
| HDL | SystemVerilog as the principal language |
| CPU | No Nios dependency in the direct path |

## 3. User-visible behavior

1. The FPGA initializes the LCD and clears the drawing area.
2. A touch-down event starts or continues a stroke.
3. Touch coordinates are mapped to LCD coordinates and displayed immediately.
4. The same stroke is reduced into a 14×14 classifier frame.
5. A finish action freezes the frame and starts one recognition transaction.
6. The FPGA sends the captured frame or its mirror to the PC.
7. The ML core returns digit 0–9 or `NON_RECOGNIZABLE`.
8. The PC receives the digit, confidence, margin, cycle count, and session ID.
9. A clear action erases the active drawing and starts a new session.
10. A shutdown action sends a host-visible stop event; it does not remove FPGA
    configuration.

## 4. Functional architecture

```text
                +-----------------------------+
XPT2046 SPI -->| touch_capture                |
TP_IRQ ------->| coordinate_mapper             |
                +-------------+---------------+
                              |
                              v
                +-----------------------------+
                | drawing_buffer / frame RAM   |
                | 320x240 display path          |
                | 14x14 ML frame path           |
                +------+----------------------+
                       |                 |
                       v                 v
                +-------------+   +-------------+
                | lcd_writer  |   | frame_mirror|
                +-------------+   +------+------+ 
                                        |
                                        v
                                  FX2/PC stream

                       14x14 frame
                              |
                              v
                       +-------------+
                       | ml_adapter  |
                       +------+------+ 
                              |
                              v
                       +-------------+
                       | ml_inference|
                       +------+------+ 
                              |
                              v
                       result/status -> FX2 -> PC
```

The exact display storage method is an implementation decision. A full
320×240 framebuffer is probably too expensive in logic and must use available
external memory or a streaming LCD writer. The ML frame is small enough for
on-chip RAM: 196 pixels × 4 bits = 784 bits, before metadata and buffering.

## 5. Frame and session model

The design has three states:

```text
IDLE/DRAWING -> COMPLETE -> RECOGNIZING -> RESULT -> IDLE/DRAWING
```

- `DRAWING`: touch samples update the LCD and the ML frame.
- `COMPLETE`: finish freezes the frame and assigns a session ID.
- `RECOGNIZING`: the ML adapter owns the frozen frame; touch updates are
  ignored or queued until the transaction completes.
- `RESULT`: result is mirrored to the PC and displayed locally if supported.
- `CLEAR`: returns to `DRAWING` with a blank frame.

The first prototype must use a single-frame buffer and explicitly reject a
new finish event while `RECOGNIZING`.

## 6. Touch-to-ML preprocessing contract

The direct path must produce the same tensor contract as the validated PC ML
benchmark:

- logical frame: 14×14 pixels
- pixel format: unsigned 4-bit grayscale, range 0–15
- row-major order: pixel `row*14 + column`
- background: 0 after normalization
- stroke: higher values toward 15
- frame length: 196 pixels

The coordinate mapper must define calibration constants, axis direction,
rotation, clipping, and stroke thickness. These values must be recorded in a
calibration document and verified against the physical LCD before ML accuracy
testing.

## 7. FPGA-to-PC protocol

The preferred protocol reuses the validated FX2 framing where possible:

### PC/FX2 input

- frame marker `0xA5A5`
- 196 packed 4-bit pixels in 98 16-bit words
- session/transaction ID in reserved bits
- explicit finish/frame length metadata

### FPGA/FX2 output

- result marker `0xC33C`
- predicted digit 0–9
- accepted flag
- confidence
- margin
- FPGA cycle count
- session/transaction ID

Option 2 additionally needs a frame-mirror message. The mirror must be
associated with the same session ID as the result. The PC must reject a result
whose ID does not match the frame being collected.

## 8. Clock and reset plan

- Use the board clock as the primary synchronous clock.
- Use clock enables for the ML schedule rather than creating uncontrolled
  derived clocks.
- Synchronize XPT2046 `TP_IRQ` before using it in synchronous logic.
- Synchronize FX2 asynchronous flags before they enter control logic.
- Define one active-low board reset and local reset release sequencing.
- Hold the capture buffer in reset/clear state until LCD and FX2 interfaces are
  idle.

## 9. Resource budget and feasibility gate

Measured reference values:

| Resource | Device total | ML bridge used | Maximum left for direct LCD/touch side |
|---|---:|---:|---:|
| Logic elements | 4,608 | 3,135 | 1,473 |
| Memory bits | 119,808 | 56,912 | 62,896 |
| 9-bit multipliers | 26 | 5 | 21 |
| PLLs | 2 | 0 | 2 |
| Pins | 89 | 31 | 58 |

The existing LCD/Nios design uses 4,282 logic elements and 78 pins, so it is
not a candidate for direct combination. The first synthesis gate for this
project is:

- total logic elements ≤ 4,608
- total pins ≤ 89 with real pin assignments
- memory bits ≤ 119,808
- no negative setup/hold timing slack at the chosen clock
- ML result cycle count remains compatible with the PC decoder

If the direct LCD/touch side exceeds 1,473 logic elements, the design must be
reduced or the FPGA device must be changed before adding more features.

## 10. Verification plan

1. SystemVerilog unit test for XPT2046 SPI receive timing.
2. Unit test for coordinate calibration and clipping.
3. Unit test for 14×14 frame generation against golden PC frames.
4. Unit test for finish/clear/session state transitions.
5. ML adapter test using the existing golden vectors.
6. FX2 protocol test with known frames and matching session IDs.
7. Quartus synthesis and timing report stored under `synthesis/`.
8. Hardware test: draw a known digit, capture PC mirror, and compare the
   FPGA result against the PC reference model.
9. Ten-session end-to-end test before any benchmark expansion.

## 11. Explicit non-goals for the first prototype

- No Nios CPU.
- No full handwritten-digit training inside the FPGA.
- No full 320×240 framebuffer unless resource analysis proves it fits.
- No LCD/ML/FX2 pin assignment copied without checking the combined top-level.
- No claim that Option 2 fits before Quartus synthesis succeeds.
