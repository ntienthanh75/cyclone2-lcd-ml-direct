`timescale 1ns/1ps
module lcd_live_writer_tb;
    logic clk = 0, reset_n = 0, point_valid = 0;
    logic [8:0] point_x = 9'd100, point_y = 9'd80;
    wire [15:0] lcd_data;
    wire lcd_cs_n, lcd_rs, lcd_wr_n, lcd_rd_n, lcd_rst_n, ready;
    lcd_live_writer #(.RESET_HOLD_CYCLES(2), .INIT_GAP_CYCLES(2), .CLEAR_PIXEL_COUNT(3)) dut (
        .clk(clk), .reset_n(reset_n), .point_valid(point_valid),
        .point_x(point_x), .point_y(point_y), .lcd_data(lcd_data),
        .lcd_cs_n(lcd_cs_n), .lcd_rs(lcd_rs), .lcd_wr_n(lcd_wr_n),
        .lcd_rd_n(lcd_rd_n), .lcd_rst_n(lcd_rst_n), .ready(ready));
    always #5 clk = ~clk;
    integer writes = 0, command_writes = 0, data_writes = 0;
    always @(negedge clk) begin
        if (!lcd_cs_n && !lcd_wr_n) begin
            writes = writes + 1;
            if (lcd_rs) data_writes = data_writes + 1;
            else command_writes = command_writes + 1;
        end
    end
    initial begin
        repeat (2) @(posedge clk); reset_n = 1;
        wait (ready);
        if (lcd_rst_n !== 1'b1) $fatal(1, "LCD reset still asserted at ready");
        point_valid = 1; @(posedge clk); point_valid = 0;
        repeat (180) @(posedge clk);
        if (writes < 20 || command_writes == 0 || data_writes == 0)
            $fatal(1, "writer did not produce command/data traffic");
        $display("PASS: LCD writer init, clear, and point traffic; writes=%0d commands=%0d data=%0d", writes, command_writes, data_writes);
        $finish;
    end
endmodule
