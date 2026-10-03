`timescale 1ns/1ps

// Protocol-level test for xpt2046_reader.
// The model supplies two known 16-bit ADC response words, one for X and one
// for Y, and checks the reader's response >> 3 conversion and sample pulse.
module xpt2046_reader_tb;
    reg clk = 1'b0;
    reg reset_n = 1'b0;
    reg touch_irq_n = 1'b1;
    reg touch_miso = 1'b0;
    wire touch_cs_n;
    wire touch_sclk;
    wire touch_mosi;
    wire busy;
    wire sample_valid;
    wire [11:0] raw_x;
    wire [11:0] raw_y;

    localparam [15:0] X_RESPONSE = 16'h9230; // expected ADC = 12'h246
    localparam [15:0] Y_RESPONSE = 16'h2A68; // expected ADC = 12'h54D

    integer transaction;
    integer rising_edges;
    integer failures;
    reg [15:0] response_word;

    always #10 clk = ~clk; // 50 MHz

    xpt2046_reader #(.CLOCK_DIV(2)) dut (
        .clk(clk), .reset_n(reset_n),
        .touch_irq_n(touch_irq_n), .touch_miso(touch_miso),
        .touch_cs_n(touch_cs_n), .touch_sclk(touch_sclk),
        .touch_mosi(touch_mosi), .busy(busy),
        .sample_valid(sample_valid), .raw_x(raw_x), .raw_y(raw_y)
    );

    always @(negedge touch_cs_n) begin
        transaction = transaction + 1;
        rising_edges = 0;
        if (transaction == 1)
            response_word = X_RESPONSE;
        else if (transaction == 2)
            response_word = Y_RESPONSE;
    end

    // Count the just-completed rising edge and place the next response bit
    // before the next rising edge, as an SPI mode-0 slave does.
    always @(posedge touch_sclk) begin
        rising_edges = rising_edges + 1;
    end

    always @(negedge touch_sclk) begin
        if ((rising_edges >= 8) && (rising_edges < 24))
            touch_miso = response_word[15-(rising_edges-8)];
        else
            touch_miso = 1'b0;
    end

    always @(posedge sample_valid) begin
        #1;
        if (transaction != 2) begin
            $display("FAIL: expected two SPI transactions, got %0d", transaction);
            failures = failures + 1;
        end
        if (raw_x !== 12'h246) begin
            $display("FAIL: raw_x=%h expected 246", raw_x);
            failures = failures + 1;
        end
        if (raw_y !== 12'h54D) begin
            $display("FAIL: raw_y=%h expected 54D", raw_y);
            failures = failures + 1;
        end
        if (failures == 0)
            $display("PASS: XPT2046 X/Y response conversion and sample_valid");
        else
            $display("FAIL: %0d verification errors", failures);
        touch_irq_n = 1'b1;
        #100;
        $finish;
    end

    initial begin
        transaction = 0;
        rising_edges = 0;
        failures = 0;
        response_word = 16'd0;
        #100;
        reset_n = 1'b1;
        #100;
        touch_irq_n = 1'b0;
        #200000;
        $display("FAIL: timeout waiting for sample_valid");
        $finish;
    end
endmodule
