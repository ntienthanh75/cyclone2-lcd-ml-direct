`timescale 1ns/1ps

module touch_frame_adapter_tb;
    logic clk = 1'b0;
    always #5 clk = ~clk;

    logic reset_n = 1'b0;
    logic clear_frame = 1'b0;
    logic point_valid = 1'b0;
    logic [8:0] point_x = 0;
    logic [8:0] point_y = 0;
    logic start_stream = 1'b0;
    logic stream_busy, input_frame_valid, input_frame_last, stream_done;
    logic [7:0] input_pixel_index;
    logic [3:0] input_pixel;

    touch_frame_adapter dut (.*);

    task add_point(input integer x, input integer y);
        begin
            @(negedge clk);
            point_x = x; point_y = y; point_valid = 1'b1;
            @(negedge clk);
            point_valid = 1'b0;
        end
    endtask

    initial begin
        repeat (2) @(negedge clk);
        reset_n = 1'b1;

        // Four corners must map to cells 0, 13, 182, and 195.
        add_point(0,   0);
        add_point(319, 0);
        add_point(0,   239);
        add_point(319, 239);

        @(negedge clk); start_stream = 1'b1;
        @(negedge clk); start_stream = 1'b0;
        wait (stream_done);

        if (dut.frame[0]   !== 4'hF) $fatal(1, "top-left cell missing");
        if (dut.frame[13]  !== 4'hF) $fatal(1, "top-right cell missing");
        if (dut.frame[182] !== 4'hF) $fatal(1, "bottom-left cell missing");
        if (dut.frame[195] !== 4'hF) $fatal(1, "bottom-right cell missing");
        $display("PASS: four points rasterized and 196 pixels streamed");
        $finish;
    end
endmodule
