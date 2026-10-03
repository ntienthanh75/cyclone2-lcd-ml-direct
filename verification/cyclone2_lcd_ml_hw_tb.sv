`timescale 1ns/1ps

// Hardware-wrapper smoke test. This does not claim touch-panel correctness;
// that remains covered by touch_ml_scanpipe_top_tb. It checks the board-level
// clock divider, button edge pulses, LED reset value, and buzzer mute default.
module cyclone2_lcd_ml_hw_tb;
    reg clk50 = 1'b0;
    reg reset_n = 1'b0;
    reg joystick_up_n = 1'b1;
    reg joystick_down_n = 1'b1;
    reg touch_irq_n = 1'b1;
    reg touch_miso = 1'b0;
    wire touch_cs_n, touch_sclk, touch_mosi;
    wire [3:0] led;
    wire buzzer_n;
    integer failures = 0;
    integer source_edges = 0;
    integer proc_edges = 0;
    integer last_source_edge = 0;

    always #10 clk50 = ~clk50;
    always @(posedge clk50) source_edges = source_edges + 1;
    always @(posedge dut.proc_clk) begin
        proc_edges = proc_edges + 1;
        if (last_source_edge != 0 && (source_edges - last_source_edge) != 10)
            failures = failures + 1;
        last_source_edge = source_edges;
    end

    cyclone2_lcd_ml_hw dut (
        .clk50(clk50), .reset_n(reset_n),
        .joystick_up_n(joystick_up_n), .joystick_down_n(joystick_down_n),
        .touch_irq_n(touch_irq_n), .touch_miso(touch_miso),
        .touch_cs_n(touch_cs_n), .touch_sclk(touch_sclk),
        .touch_mosi(touch_mosi), .led(led), .buzzer_n(buzzer_n)
    );

    initial begin
        #50;
        if (buzzer_n !== 1'b1) failures = failures + 1;
        if (led !== 4'b1111) failures = failures + 1;
        reset_n = 1'b1;
        repeat (30) @(posedge clk50);

        // A short active-low UP press must become one processing-domain pulse.
        joystick_up_n = 1'b0;
        repeat (4) @(posedge dut.proc_clk);
        joystick_up_n = 1'b1;
        repeat (4) @(posedge dut.proc_clk);
        if (dut.start_stream !== 1'b0) failures = failures + 1;

        // DOWN is also edge-triggered and must not affect the mute default.
        joystick_down_n = 1'b0;
        repeat (4) @(posedge dut.proc_clk);
        joystick_down_n = 1'b1;
        repeat (4) @(posedge dut.proc_clk);
        if (buzzer_n !== 1'b1) failures = failures + 1;

        if (proc_edges < 10) failures = failures + 1;
        if (failures == 0)
            $display("PASS: hardware wrapper; proc clock divider, controls, LEDs, buzzer mute");
        else
            $display("FAIL: hardware wrapper smoke test errors=%0d", failures);
        #40;
        $finish;
    end
endmodule
