// Milestone 6 boundary: verified touch-frame stream to reusable ML core.
// Board pin assignments remain outside this module until the CoreEP2C5 pin
// table is reviewed against the actual wiring.
module touch_ml_boundary_top #(
    parameter integer TOUCH_CLOCK_DIV = 25,
    parameter integer CONFIDENCE_THRESHOLD = 0,
    parameter integer MARGIN_THRESHOLD = 0
) (
    input  logic       clk,
    input  logic       reset_n,
    input  logic       clear_frame,
    input  logic       start_stream,
    input  logic       touch_irq_n,
    input  logic       touch_miso,
    output logic       touch_cs_n,
    output logic       touch_sclk,
    output logic       touch_mosi,
    output logic       ml_busy,
    output logic       result_valid,
    output logic       result_accepted,
    output logic [3:0] result_digit,
    output logic [7:0] result_confidence,
    output logic [15:0] result_margin,
    output logic [31:0] result_cycles
);
    logic stream_busy;
    logic input_frame_valid;
    logic [7:0] input_pixel_index;
    logic [3:0] input_pixel;
    logic input_frame_last;
    logic stream_done;
    logic sample_valid_debug;
    logic [11:0] raw_x_debug, raw_y_debug;

    touch_capture_top #(.CLOCK_DIV(TOUCH_CLOCK_DIV)) touch_path (
        .clk(clk), .reset_n(reset_n), .clear_frame(clear_frame),
        .start_stream(start_stream), .touch_irq_n(touch_irq_n),
        .touch_miso(touch_miso), .touch_cs_n(touch_cs_n),
        .touch_sclk(touch_sclk), .touch_mosi(touch_mosi),
        .stream_busy(stream_busy), .input_frame_valid(input_frame_valid),
        .input_pixel_index(input_pixel_index), .input_pixel(input_pixel),
        .input_frame_last(input_frame_last), .stream_done(stream_done),
        .sample_valid_debug(sample_valid_debug), .raw_x_debug(raw_x_debug),
        .raw_y_debug(raw_y_debug)
    );

    ml_inference_boundary #(
        .CONFIDENCE_THRESHOLD(CONFIDENCE_THRESHOLD),
        .MARGIN_THRESHOLD(MARGIN_THRESHOLD)
    ) ml_path (
        .clk(clk), .reset_n(reset_n), .clock_enable(1'b1),
        .input_frame_valid(input_frame_valid),
        .input_pixel_index(input_pixel_index), .input_pixel(input_pixel),
        .input_frame_last(input_frame_last), .input_frame_error(1'b0),
        .busy(ml_busy), .result_valid(result_valid),
        .result_accepted(result_accepted), .result_digit(result_digit),
        .result_confidence(result_confidence), .result_margin(result_margin),
        .result_cycles(result_cycles)
    );
endmodule
