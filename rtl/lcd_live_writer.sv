// Live ILI9325 writer for the CoreEP2C5 LCD module.
// Reuses the proven initialization sequence from D:\fpga\lcd_photo_hdl.
// After initialization and a white clear, each calibrated touch point is
// rendered as a visible 5x5 black square without Nios.
module lcd_live_writer #(
    parameter integer RESET_HOLD_CYCLES = 100000,
    parameter integer INIT_GAP_CYCLES = 125000,
    parameter integer CLEAR_PIXEL_COUNT = 76800,
    parameter integer INIT_DONE_DELAY_CYCLES = 600000,
    parameter integer WRITE_HOLD_CYCLES = 4
) (
    input  logic        clk,
    input  logic        reset_n,
    input  logic        point_valid,
    input  logic [8:0]  point_x,
    input  logic [8:0]  point_y,
    inout  wire [15:0] lcd_data,
    output logic        lcd_cs_n,
    output logic        lcd_rs,
    output logic        lcd_wr_n,
    output logic        lcd_rd_n,
    output logic        lcd_rst_n,
    output logic        ready
);
    localparam integer SETUP_WORDS = 114;
    localparam logic [15:0] SETUP [0:113] = '{
        16'h00E7,16'h0010,16'h0000,16'h0001,16'h0001,16'h0100,16'h0002,16'h0700,
        16'h0003,16'h1030,16'h0004,16'h0000,16'h0008,16'h0207,16'h0009,16'h0000,
        16'h000A,16'h0000,16'h000C,16'h0001,16'h000D,16'h0000,16'h000F,16'h0000,
        16'h0010,16'h0000,16'h0011,16'h0007,16'h0012,16'h0000,16'h0013,16'h0000,
        16'h0010,16'h1590,16'h0011,16'h0227,16'h0012,16'h009C,16'h0013,16'h1900,
        16'h0029,16'h0023,16'h002B,16'h000E,16'h0020,16'h0000,16'h0021,16'h0000,
        16'h0030,16'h0007,16'h0031,16'h0707,16'h0032,16'h0006,16'h0035,16'h0704,
        16'h0036,16'h1F04,16'h0037,16'h0004,16'h0038,16'h0000,16'h0039,16'h0706,
        16'h003C,16'h0701,16'h003D,16'h000F,16'h0050,16'h0000,16'h0051,16'h00EF,
        16'h0052,16'h0000,16'h0053,16'h013F,16'h0060,16'hA700,16'h0061,16'h0001,
        16'h006A,16'h0000,16'h0080,16'h0000,16'h0081,16'h0000,16'h0082,16'h0000,
        16'h0083,16'h0000,16'h0084,16'h0000,16'h0085,16'h0000,16'h0090,16'h0010,
        16'h0092,16'h0000,16'h0093,16'h0003,16'h0095,16'h0110,16'h0097,16'h0000,
        16'h0098,16'h0000,16'h0007,16'h0133,16'h0020,16'h0000,16'h0021,16'h0000,
        16'h0022,16'h0000
    };
    typedef enum logic [4:0] {
        S_RESET, S_INIT_LOAD, S_INIT_PULSE, S_INIT_NEXT, S_INIT_GAP,
        S_CLEAR_X, S_CLEAR_XP, S_CLEAR_Y, S_CLEAR_YP, S_CLEAR_RAM,
        S_CLEAR_RAMP, S_CLEAR_NEXT, S_FILL_SETUP, S_FILL_PULSE,
        S_FILL_NEXT, S_INIT_DONE_WAIT, S_IDLE,
        S_DRAW_X, S_DRAW_XP, S_DRAW_Y, S_DRAW_YP, S_DRAW_RAM,
        S_DRAW_RAMP, S_DRAW_NEXT
    } state_t;
    state_t state;
    logic [31:0] delay_count;
    logic [7:0] init_index;
    logic [16:0] clear_index;
    logic [9:0] clear_x;
    logic [8:0] clear_y;
    logic [8:0] draw_x, draw_y;
    logic [2:0] draw_dx, draw_dy;
    logic [15:0] bus_data;
    logic bus_oe;

    assign lcd_data = bus_oe ? bus_data : 16'hzzzz;
    // Match the proven VHDL driver: keep CS asserted during reset and all
    // initialization/clear traffic, and release it only in the idle state.
    assign lcd_cs_n = (state == S_IDLE) ? 1'b1 : 1'b0;
    assign lcd_rs = (state == S_INIT_PULSE) ? init_index[0] :
                    (state == S_CLEAR_XP ||
                     state == S_CLEAR_YP || state == S_CLEAR_RAMP ||
                     state == S_FILL_PULSE ||
                     state == S_DRAW_XP || state == S_DRAW_YP ||
                     state == S_DRAW_RAMP) ? 1'b1 : 1'b0;
    assign lcd_wr_n = (state == S_INIT_PULSE || state == S_CLEAR_XP ||
                       state == S_CLEAR_YP || state == S_CLEAR_RAMP ||
                       state == S_FILL_PULSE ||
                       state == S_DRAW_XP || state == S_DRAW_YP ||
                       state == S_DRAW_RAMP) ? 1'b0 : 1'b1;
    assign lcd_rd_n = 1'b1;
    assign lcd_rst_n = (state == S_RESET) ? 1'b0 : 1'b1;
    assign ready = (state == S_IDLE);

    always_comb begin
        bus_oe = 1'b0;
        bus_data = 16'h0000;
        case (state)
            S_INIT_LOAD, S_INIT_PULSE, S_INIT_NEXT, S_INIT_GAP: begin
                bus_oe = 1'b1; bus_data = SETUP[init_index];
            end
            S_CLEAR_X, S_CLEAR_XP: begin bus_oe = 1'b1; bus_data = 16'h0020; end
            S_CLEAR_Y, S_CLEAR_YP: begin bus_oe = 1'b1; bus_data = 16'h0021; end
            S_CLEAR_RAM, S_CLEAR_RAMP: begin bus_oe = 1'b1; bus_data = 16'h0022; end
            S_CLEAR_NEXT: begin bus_oe = 1'b1; bus_data = 16'hFFFF; end
            S_FILL_SETUP, S_FILL_PULSE, S_FILL_NEXT: begin bus_oe = 1'b1; bus_data = 16'hFFFF; end
            S_DRAW_X, S_DRAW_XP: begin bus_oe = 1'b1; bus_data = 16'h0020; end
            S_DRAW_Y, S_DRAW_YP: begin bus_oe = 1'b1; bus_data = 16'h0021; end
            S_DRAW_RAM, S_DRAW_RAMP: begin bus_oe = 1'b1; bus_data = 16'h0022; end
            S_DRAW_NEXT: begin bus_oe = 1'b1; bus_data = 16'h0000; end
            default: begin end
        endcase
        if (state == S_INIT_PULSE || state == S_INIT_NEXT || state == S_INIT_GAP)
            bus_data = SETUP[init_index];
        if (state == S_CLEAR_XP) bus_data = {6'd0, clear_x};
        if (state == S_CLEAR_YP) bus_data = {7'd0, clear_y};
        if (state == S_CLEAR_RAMP) bus_data = 16'hFFFF;
        // draw_dx follows logical X (therefore hardware Y); draw_dy follows
        // logical Y (therefore hardware X) after the 90-degree rotation.
        if (state == S_DRAW_XP) bus_data = {7'd0, draw_x + draw_dy};
        if (state == S_DRAW_YP) bus_data = {7'd0, draw_y + draw_dx};
        if (state == S_DRAW_RAMP) bus_data = 16'h0000;
    end

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= S_RESET; delay_count <= 0; init_index <= 0; clear_index <= 0;
            clear_x <= 0; clear_y <= 0;
            draw_x <= 0; draw_y <= 0; draw_dx <= 0; draw_dy <= 0;
        end else begin
            case (state)
                S_RESET: if (delay_count == RESET_HOLD_CYCLES-1) begin delay_count <= 0; state <= S_INIT_LOAD; end else delay_count <= delay_count + 1'b1;
                S_INIT_LOAD: begin delay_count <= 0; state <= S_INIT_PULSE; end
                // Match the proven VHDL driver: WR remains low for four
                // processing-clock cycles while data is stable.
                S_INIT_PULSE: if (delay_count == WRITE_HOLD_CYCLES-1) begin
                    delay_count <= 0; state <= S_INIT_NEXT;
                end else delay_count <= delay_count + 1'b1;
                S_INIT_NEXT: begin
                    if (init_index == SETUP_WORDS-1) begin delay_count <= 0; clear_index <= 0; state <= S_INIT_DONE_WAIT; end
                    else if (init_index[0]) begin delay_count <= 0; state <= S_INIT_GAP; end
                    else begin init_index <= init_index + 1'b1; state <= S_INIT_LOAD; end
                end
                S_INIT_GAP: if (delay_count == INIT_GAP_CYCLES-1) begin delay_count <= 0; init_index <= init_index + 1'b1; state <= S_INIT_LOAD; end else delay_count <= delay_count + 1'b1;
                S_INIT_DONE_WAIT: if (delay_count == INIT_DONE_DELAY_CYCLES-1) begin
                    delay_count <= 0; clear_index <= 0; clear_x <= 0; clear_y <= 319; state <= S_CLEAR_X;
                end else delay_count <= delay_count + 1'b1;
                S_CLEAR_X: begin delay_count <= 0; state <= S_CLEAR_XP; end
                S_CLEAR_XP: if (delay_count == WRITE_HOLD_CYCLES-1) begin
                    delay_count <= 0; state <= S_CLEAR_Y;
                end else delay_count <= delay_count + 1'b1;
                S_CLEAR_Y: begin delay_count <= 0; state <= S_CLEAR_YP; end
                S_CLEAR_YP: if (delay_count == WRITE_HOLD_CYCLES-1) begin
                    delay_count <= 0; state <= S_CLEAR_RAM;
                end else delay_count <= delay_count + 1'b1;
                S_CLEAR_RAM: begin delay_count <= 0; state <= S_CLEAR_RAMP; end
                S_CLEAR_RAMP: if (delay_count == WRITE_HOLD_CYCLES-1) begin
                    delay_count <= 0; state <= S_CLEAR_NEXT;
                end else delay_count <= delay_count + 1'b1;
                S_CLEAR_NEXT: if (clear_index == CLEAR_PIXEL_COUNT-1) state <= S_IDLE; else begin
                    clear_index <= clear_index + 1'b1;
                    if (clear_x == 319) begin clear_x <= 0; clear_y <= clear_y + 1'b1; end
                    else clear_x <= clear_x + 1'b1;
                    state <= S_CLEAR_X;
                end
                S_FILL_SETUP: begin delay_count <= 0; state <= S_FILL_PULSE; end
                S_FILL_PULSE: if (delay_count == WRITE_HOLD_CYCLES-1) begin
                    delay_count <= 0; state <= S_FILL_NEXT;
                end else delay_count <= delay_count + 1'b1;
                S_FILL_NEXT: if (clear_index == CLEAR_PIXEL_COUNT-1) state <= S_IDLE; else begin clear_index <= clear_index + 1'b1; state <= S_FILL_SETUP; end
                // DISP_ORIENTATION=90 from the original LCD32 driver:
                // logical (x,y) -> LCD GRAM (x_hw,y_hw) = (y,319-x).
                // Store the upper-left hardware corner of a 5x5 mark.
                S_IDLE: if (point_valid) begin
                    draw_x <= (point_y > 235) ? 235 : point_y;
                    draw_y <= (point_x > 315) ? 0 : (315 - point_x);
                    draw_dx <= 0; draw_dy <= 0; state <= S_DRAW_X;
                end
                S_DRAW_X: begin delay_count <= 0; state <= S_DRAW_XP; end
                S_DRAW_XP: if (delay_count == WRITE_HOLD_CYCLES-1) begin
                    delay_count <= 0; state <= S_DRAW_Y;
                end else delay_count <= delay_count + 1'b1;
                S_DRAW_Y: begin delay_count <= 0; state <= S_DRAW_YP; end
                S_DRAW_YP: if (delay_count == WRITE_HOLD_CYCLES-1) begin
                    delay_count <= 0; state <= S_DRAW_RAM;
                end else delay_count <= delay_count + 1'b1;
                S_DRAW_RAM: begin delay_count <= 0; state <= S_DRAW_RAMP; end
                S_DRAW_RAMP: if (delay_count == WRITE_HOLD_CYCLES-1) begin
                    delay_count <= 0; state <= S_DRAW_NEXT;
                end else delay_count <= delay_count + 1'b1;
                S_DRAW_NEXT: begin
                    if (draw_dx == 4 && draw_dy == 4) begin
                        if (point_valid) begin
                            draw_x <= (point_y > 235) ? 235 : point_y;
                            draw_y <= (point_x > 315) ? 0 : (315 - point_x);
                            draw_dx <= 0; draw_dy <= 0; state <= S_DRAW_X;
                        end
                        else state <= S_IDLE;
                    end else if (draw_dx == 4) begin draw_dx <= 0; draw_dy <= draw_dy + 1'b1; state <= S_DRAW_X; end
                    else begin draw_dx <= draw_dx + 1'b1; state <= S_DRAW_X; end
                end
                default: state <= S_RESET;
            endcase
        end
    end
endmodule
