`timescale 1ns/1ps

module cyclone2_joystick_diag_tb;
    reg up_n = 1'b1, down_n = 1'b1, left_n = 1'b1;
    reg right_n = 1'b1, press_n = 1'b1;
    wire [3:0] led;
    wire buzzer_n;
    integer failures = 0;
    cyclone2_joystick_diag dut (
        .joystick_up_n(up_n), .joystick_down_n(down_n),
        .joystick_left_n(left_n), .joystick_right_n(right_n),
        .joystick_press_n(press_n), .led(led), .buzzer_n(buzzer_n)
    );

    task check;
        input [3:0] expected;
        input [127:0] name;
        begin
            #1;
            if (led !== expected) begin
                failures = failures + 1;
                $display("FAIL %s: led=%b expected=%b", name, led, expected);
            end
        end
    endtask

    initial begin
        check(4'b1111, "released");
        up_n = 1'b0; check(4'b1110, "UP"); up_n = 1'b1;
        down_n = 1'b0; check(4'b1101, "DOWN"); down_n = 1'b1;
        left_n = 1'b0; check(4'b1011, "LEFT"); left_n = 1'b1;
        right_n = 1'b0; check(4'b0111, "RIGHT"); right_n = 1'b1;
        press_n = 1'b0; check(4'b0000, "PRESS"); press_n = 1'b1;
        if (buzzer_n !== 1'b1) failures = failures + 1;
        if (failures == 0) $display("PASS: joystick diagnostic direction mapping");
        else $display("FAIL: joystick diagnostic errors=%0d", failures);
        $finish;
    end
endmodule
