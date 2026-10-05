// CoreEP2C5 joystick direction diagnostic.
// Active-low inputs: released=1, pressed=0.
// Physical LEDs are also active-low.
module cyclone2_joystick_diag (
    input  logic       joystick_1_n,
    input  logic       joystick_2_n,
    input  logic       joystick_3_n,
    input  logic       joystick_4_n,
    input  logic       joystick_press_n,
    output logic [3:0] led,
    output logic       buzzer_n
);
    // Neutral channel diagnostic: one LED per joystick input; center press
    // lights all four LEDs. Channel names intentionally avoid direction
    // assumptions because the physical joystick orientation is unknown.
    always_comb begin
        if (!joystick_press_n)
            led = 4'b0000;
        else
            led = {joystick_4_n, joystick_3_n,
                   joystick_2_n, joystick_1_n};
    end

    assign buzzer_n = 1'b1;
endmodule
