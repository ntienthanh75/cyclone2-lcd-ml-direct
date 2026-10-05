`timescale 1ns/1ps

module cyclone2_joystick_diag_tb;
    reg j1_n = 1'b1, j2_n = 1'b1, j3_n = 1'b1;
    reg j4_n = 1'b1, press_n = 1'b1;
    wire [3:0] led;
    wire buzzer_n;
    integer failures = 0;
    cyclone2_joystick_diag dut (
        .joystick_1_n(j1_n), .joystick_2_n(j2_n),
        .joystick_3_n(j3_n), .joystick_4_n(j4_n),
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
        j1_n = 1'b0; check(4'b1110, "JOYSTICK 1"); j1_n = 1'b1;
        j2_n = 1'b0; check(4'b1101, "JOYSTICK 2"); j2_n = 1'b1;
        j3_n = 1'b0; check(4'b1011, "JOYSTICK 3"); j3_n = 1'b1;
        j4_n = 1'b0; check(4'b0111, "JOYSTICK 4"); j4_n = 1'b1;
        press_n = 1'b0; check(4'b0000, "PRESS"); press_n = 1'b1;
        if (buzzer_n !== 1'b1) failures = failures + 1;
        if (failures == 0) $display("PASS: joystick channel-to-LED mapping");
        else $display("FAIL: joystick diagnostic errors=%0d", failures);
        $finish;
    end
endmodule
