// Integrated raw-touch capture boundary for milestone 4 preparation.
// Board pin assignments remain deliberately outside this module.
module touch_capture_top #(
    parameter integer CLOCK_DIV = 25
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
    output logic       stream_busy,
    output logic       input_frame_valid,
    output logic [7:0] input_pixel_index,
    output logic [3:0] input_pixel,
    output logic       input_frame_last,
    output logic       stream_done,
    output logic       sample_valid_debug,
    output logic [11:0] raw_x_debug,
    output logic [11:0] raw_y_debug
);
    logic reader_busy;
    logic sample_valid;
    logic [11:0] raw_x, raw_y;
    logic point_valid;
    logic [8:0] point_x, point_y;

    xpt2046_reader #(.CLOCK_DIV(CLOCK_DIV)) reader (
        .clk(clk), .reset_n(reset_n), .touch_irq_n(touch_irq_n),
        .touch_miso(touch_miso), .touch_cs_n(touch_cs_n),
        .touch_sclk(touch_sclk), .touch_mosi(touch_mosi),
        .busy(reader_busy), .sample_valid(sample_valid),
        .raw_x(raw_x), .raw_y(raw_y)
    );

    xpt2046_calibrator calibrator (
        .clk(clk), .reset_n(reset_n), .sample_valid(sample_valid),
        .raw_x(raw_x), .raw_y(raw_y), .point_valid(point_valid),
        .point_x(point_x), .point_y(point_y)
    );

    touch_frame_adapter frame (
        .clk(clk), .reset_n(reset_n), .clear_frame(clear_frame),
        .point_valid(point_valid), .point_x(point_x), .point_y(point_y),
        .start_stream(start_stream), .stream_busy(stream_busy),
        .input_frame_valid(input_frame_valid),
        .input_pixel_index(input_pixel_index), .input_pixel(input_pixel),
        .input_frame_last(input_frame_last), .stream_done(stream_done)
    );

    assign sample_valid_debug = sample_valid;
    assign raw_x_debug = raw_x;
    assign raw_y_debug = raw_y;
endmodule
