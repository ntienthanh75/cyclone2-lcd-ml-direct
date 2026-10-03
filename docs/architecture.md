# Architecture summary

## Decision

Option 2 is a direct FPGA path, but the existing LCD/Nios and ML bridge SOFs
cannot be combined. This project therefore starts with a small SystemVerilog
touch/frame-capture design and keeps Nios out of the data path.

## Data ownership

- `touch_capture` owns XPT2046 SPI sampling.
- `coordinate_mapper` owns calibration and LCD coordinates.
- `drawing_buffer` owns the frozen session frame.
- `lcd_writer` owns display updates.
- `ml_adapter` owns the 196-pixel inference stream.
- `frame_mirror` owns the PC copy.
- `result_packet` owns digit/result serialization.
- `session_controller` prevents frame changes during recognition.

## Required design rule

Only one module may write the frozen ML frame. LCD display output, ML input,
and PC mirroring are read consumers. This prevents the LCD, ML core, and PC
streamer from observing different drawings.

## First implementation boundary

The first RTL milestone is not the complete 320×240 display. It is a small
simulation-verified path:

```text
synthetic touch points -> 14x14 frame -> ML adapter -> result packet
```

The LCD electrical interface and resource fit are added only after this
transaction is verified and the real pin budget is known.
