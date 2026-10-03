// Nios-free XPT2046 raw touch reader.
//
// The reader follows the protocol used by the previously working Nios
// application: command 0xD0 for X, command 0x90 for Y, SPI mode 0, and
// sixteen response clocks.  The 16-bit response is reduced exactly as the
// Nios code did: response >> 3, producing a 12-bit ADC sample.
//
// This block intentionally does not calibrate coordinates, draw to the LCD,
// or run the ML core.  It emits one raw X/Y pair per press so those functions
// can be verified independently.
module xpt2046_reader #(
    parameter integer CLOCK_DIV = 25  // 50 MHz / (2*25) = 1 MHz SCLK
) (
    input  wire        clk,
    input  wire        reset_n,
    input  wire        touch_irq_n,
    input  wire        touch_miso,
    output reg         touch_cs_n,
    output reg         touch_sclk,
    output reg         touch_mosi,
    output reg         busy,
    output reg         sample_valid,
    output reg [11:0]  raw_x,
    output reg [11:0]  raw_y
);

    localparam [1:0] S_IDLE = 2'd0;
    localparam [1:0] S_SPI  = 2'd1;
    localparam [1:0] S_WAIT = 2'd2;
    localparam [1:0] S_GAP  = 2'd3;
    localparam [2:0] S_START_Y = 3'd4;

    reg [2:0] state;
    reg       axis_y;
    reg [4:0] bit_index;
    reg [15:0] rx_shift;
    reg [7:0] command;
    reg [15:0] divider;

    wire divider_tick = (divider == CLOCK_DIV-1);

    function [11:0] response_to_adc;
        input [15:0] response;
        begin
            response_to_adc = response[14:3];
        end
    endfunction

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state       <= S_IDLE;
            axis_y      <= 1'b0;
            bit_index   <= 5'd0;
            rx_shift    <= 16'd0;
            command     <= 8'd0;
            divider     <= 16'd0;
            touch_cs_n  <= 1'b1;
            touch_sclk  <= 1'b0;
            touch_mosi  <= 1'b0;
            busy        <= 1'b0;
            sample_valid<= 1'b0;
            raw_x       <= 12'd0;
            raw_y       <= 12'd0;
        end else begin
            sample_valid <= 1'b0;

            case (state)
                S_IDLE: begin
                    divider <= 16'd0;
                    touch_cs_n <= 1'b1;
                    touch_sclk <= 1'b0;
                    touch_mosi <= 1'b0;
                    busy <= 1'b0;
                    if (!touch_irq_n) begin
                        axis_y     <= 1'b0;
                        command    <= 8'hD0;
                        bit_index  <= 5'd0;
                        rx_shift   <= 16'd0;
                        touch_cs_n <= 1'b0;
                        touch_mosi <= 1'b1; // command bit 7 of 0xD0
                        busy       <= 1'b1;
                        state      <= S_SPI;
                    end
                end

                S_SPI: begin
                    if (divider_tick) begin
                        divider <= 16'd0;
                        if (!touch_sclk) begin
                            // Rising edge: sample MISO in SPI mode 0.
                            touch_sclk <= 1'b1;
                            if (bit_index >= 5'd8)
                                rx_shift <= {rx_shift[14:0], touch_miso};
                        end else begin
                            // Falling edge: prepare the next MOSI bit.
                            touch_sclk <= 1'b0;
                            if (bit_index == 5'd23) begin
                                touch_cs_n <= 1'b1;
                                touch_mosi <= 1'b0;
                                if (!axis_y) begin
                                    // The final response bit was already
                                    // sampled on the preceding rising edge;
                                    // do not shift it a second time here.
                                    raw_x  <= response_to_adc(rx_shift);
                                    axis_y <= 1'b1;
                                    command <= 8'h90;
                                    bit_index <= 5'd0;
                                    rx_shift <= 16'd0;
                                    // Release CS for at least one system-clock
                                    // cycle before starting the Y conversion.
                                    // XPT2046 uses this edge to latch the X
                                    // conversion and reset its serial frame.
                                    state <= S_GAP;
                                end else begin
                                    raw_y <= response_to_adc(rx_shift);
                                    sample_valid <= 1'b1;
                                    state <= S_WAIT;
                                end
                            end else begin
                                bit_index <= bit_index + 1'b1;
                                if (bit_index + 1'b1 < 5'd8)
                                    touch_mosi <= command[7-(bit_index + 1'b1)];
                                else
                                    touch_mosi <= 1'b0;
                            end
                        end
                    end else begin
                        divider <= divider + 1'b1;
                    end
                end

                S_WAIT: begin
                    // Require release before another sample, preventing
                    // repeated conversions while one touch remains held.
                    busy <= 1'b0;
                    if (touch_irq_n)
                        state <= S_IDLE;
                end

                S_GAP: begin
                    // One full clk cycle with CS high separates X and Y.
                    divider <= 16'd0;
                    touch_cs_n <= 1'b1;
                    touch_sclk <= 1'b0;
                    touch_mosi <= 1'b0;
                    state <= S_START_Y;
                end

                S_START_Y: begin
                    // Begin Y only after the visible CS-high gap.
                    touch_cs_n <= 1'b0;
                    touch_mosi <= 1'b1; // command bit 7 of 0x90
                    state <= S_SPI;
                end

                default: state <= S_IDLE;
            endcase
        end
    end
endmodule
