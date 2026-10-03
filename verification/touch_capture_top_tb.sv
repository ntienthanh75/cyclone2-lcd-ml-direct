`timescale 1ns/1ps

module touch_capture_top_tb;
    reg clk = 1'b0;
    reg reset_n = 1'b0;
    reg clear_frame = 1'b0;
    reg start_stream = 1'b0;
    reg touch_irq_n = 1'b1;
    reg touch_miso = 1'b0;
    wire touch_cs_n, touch_sclk, touch_mosi;
    wire stream_busy, input_frame_valid, input_frame_last, stream_done;
    wire sample_valid_debug;
    wire [7:0] input_pixel_index;
    wire [3:0] input_pixel;
    wire [11:0] raw_x_debug, raw_y_debug;
    localparam [15:0] X_RESPONSE = 16'h9230;
    localparam [15:0] Y_RESPONSE = 16'h2A68;
    integer transaction = 0, rising_edges = 0, pixel_count = 0, failures = 0;
    reg [15:0] response_word = 16'd0;
    always #10 clk = ~clk;

    touch_capture_top #(.CLOCK_DIV(2)) dut (
        .clk(clk), .reset_n(reset_n), .clear_frame(clear_frame),
        .start_stream(start_stream), .touch_irq_n(touch_irq_n),
        .touch_miso(touch_miso), .touch_cs_n(touch_cs_n),
        .touch_sclk(touch_sclk), .touch_mosi(touch_mosi),
        .stream_busy(stream_busy), .input_frame_valid(input_frame_valid),
        .input_pixel_index(input_pixel_index), .input_pixel(input_pixel),
        .input_frame_last(input_frame_last), .stream_done(stream_done),
        .sample_valid_debug(sample_valid_debug), .raw_x_debug(raw_x_debug),
        .raw_y_debug(raw_y_debug));

    always @(negedge touch_cs_n) begin
        transaction = transaction + 1;
        rising_edges = 0;
        if (transaction == 1) response_word = X_RESPONSE;
        else if (transaction == 2) response_word = Y_RESPONSE;
    end
    always @(posedge touch_sclk) rising_edges = rising_edges + 1;
    always @(negedge touch_sclk) begin
        if ((rising_edges >= 8) && (rising_edges < 24))
            touch_miso = response_word[15-(rising_edges-8)];
        else touch_miso = 1'b0;
    end
    always @(posedge clk) if (input_frame_valid) begin
        pixel_count = pixel_count + 1;
        if (input_pixel_index !== pixel_count-1) failures = failures + 1;
        if (input_frame_last && (pixel_count != 196)) failures = failures + 1;
    end

    initial begin
        #50; reset_n = 1'b1; #50; touch_irq_n = 1'b0;
        wait (sample_valid_debug); #1;
        if (raw_x_debug !== 12'h246 || raw_y_debug !== 12'h54D) failures = failures + 1;
        touch_irq_n = 1'b1; #50; start_stream = 1'b1; #20; start_stream = 1'b0;
        wait (stream_done); @(posedge clk); #1;
        if (pixel_count != 196) failures = failures + 1;
        if (failures == 0) $display("PASS: reader/calibrator/frame adapter integration; 196 pixels");
        else $display("FAIL: %0d integration errors", failures);
        #20; $finish;
    end
    initial begin #500000; $display("FAIL: integration timeout"); $finish; end
endmodule
