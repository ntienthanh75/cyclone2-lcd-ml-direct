`timescale 1ns/1ps

module xpt2046_calibrator_tb;
    reg clk = 1'b0;
    reg reset_n = 1'b0;
    reg sample_valid = 1'b0;
    reg [11:0] raw_x = 12'd0;
    reg [11:0] raw_y = 12'd0;
    wire point_valid;
    wire [8:0] point_x;
    wire [8:0] point_y;
    integer failures = 0;

    always #10 clk = ~clk;

    xpt2046_calibrator dut (
        .clk(clk), .reset_n(reset_n), .sample_valid(sample_valid),
        .raw_x(raw_x), .raw_y(raw_y), .point_valid(point_valid),
        .point_x(point_x), .point_y(point_y)
    );

    task automatic check_point(input [11:0] x, input [11:0] y,
                               input [8:0] expected_x, input [8:0] expected_y);
        begin
            @(negedge clk);
            raw_x = x; raw_y = y; sample_valid = 1'b1;
            @(posedge clk);
            #1;
            if (!point_valid || point_x !== expected_x || point_y !== expected_y) begin
                $display("FAIL raw=(%0d,%0d) point=(%0d,%0d) expected=(%0d,%0d)",
                         x, y, point_x, point_y, expected_x, expected_y);
                failures = failures + 1;
            end
            @(negedge clk);
            sample_valid = 1'b0;
        end
    endtask

    initial begin
        #50;
        reset_n = 1'b1;
        check_point(12'd200, 12'd200, 9'd11, 9'd9);
        check_point(12'd2050, 12'd2050, 9'd160, 9'd111);
        check_point(12'd3900, 12'd3900, 9'd308, 9'd231);
        if (failures == 0)
            $display("PASS: XPT2046 raw-to-LCD calibration bins");
        else
            $display("FAIL: %0d calibration errors", failures);
        #20;
        $finish;
    end
endmodule
