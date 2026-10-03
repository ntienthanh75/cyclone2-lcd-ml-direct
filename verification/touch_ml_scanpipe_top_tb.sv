`timescale 1ns/1ps

// Bounded integration smoke test. It proves that the verified XPT2046
// response becomes exactly one 196-pixel ML transaction and that the reused
// classifier returns a structured result. The digit itself is not treated as
// a golden value for this synthetic touch point.
module touch_ml_scanpipe_top_tb;
    reg clk = 1'b0;
    reg reset_n = 1'b0;
    reg clear_frame = 1'b0;
    reg start_stream = 1'b0;
    reg touch_irq_n = 1'b1;
    reg touch_miso = 1'b0;
    wire touch_cs_n, touch_sclk, touch_mosi;
    wire ml_busy, result_valid, result_accepted;
    wire [3:0] result_digit;
    wire [7:0] result_confidence;
    wire [15:0] result_margin;
    wire [31:0] result_cycles;
    localparam [15:0] X_RESPONSE = 16'h9230;
    localparam [15:0] Y_RESPONSE = 16'h2A68;
    integer transaction = 0, rising_edges = 0, failures = 0;
    reg [15:0] response_word = 16'd0;
    always #10 clk = ~clk;

    touch_ml_scanpipe_top #(.TOUCH_CLOCK_DIV(2)) dut (
        .clk(clk), .reset_n(reset_n), .clear_frame(clear_frame),
        .start_stream(start_stream), .touch_irq_n(touch_irq_n),
        .touch_miso(touch_miso), .touch_cs_n(touch_cs_n),
        .touch_sclk(touch_sclk), .touch_mosi(touch_mosi),
        .ml_busy(ml_busy), .result_valid(result_valid),
        .result_accepted(result_accepted), .result_digit(result_digit),
        .result_confidence(result_confidence), .result_margin(result_margin),
        .result_cycles(result_cycles));

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

    initial begin
        #50; reset_n = 1'b1; #50; touch_irq_n = 1'b0;
        wait (dut.touch_path.sample_valid_debug);
        touch_irq_n = 1'b1; #50;
        start_stream = 1'b1; #20; start_stream = 1'b0;
        wait (result_valid);
        if (result_digit > 9) failures = failures + 1;
        if (result_cycles == 0) failures = failures + 1;
        if (result_cycles < 13400 || result_cycles > 13500) failures = failures + 1;
        if (failures == 0)
            $display("PASS: touch-to-ML integration; digit=%0d confidence=%0d margin=%0d cycles=%0d accepted=%0d", result_digit, result_confidence, result_margin, result_cycles, result_accepted);
        else $display("FAIL: %0d integration errors", failures);
        #20; $finish;
    end
    initial begin #1200000; $display("FAIL: touch-to-ML timeout"); $finish; end
endmodule
