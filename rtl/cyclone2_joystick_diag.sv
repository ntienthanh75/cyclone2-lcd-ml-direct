// CoreEP2C5 joystick direction diagnostic.
// Active-low inputs: released=1, pressed=0.
// Physical LEDs are also active-low.
module cyclone2_joystick_diag (
    input  logic       joystick_up_n,
    input  logic       joystick_down_n,
    input  logic       joystick_left_n,
    input  logic       joystick_right_n,
    input  logic       joystick_press_n,
    output logic [3:0] led,
    output logic       buzzer_n
);
    // Verified board wiring: UP=139, DOWN=137, LEFT=142, RIGHT=141,
    // PRESS=143. Keep one LED per direction; PRESS lights all LEDs.
    always_comb begin
        if (!joystick_press_n)
            led = 4'b0000;
        else
            led = {joystick_right_n, joystick_left_n,
                   joystick_down_n, joystick_up_n};
    end

    assign buzzer_n = 1'b1;
endmodule
