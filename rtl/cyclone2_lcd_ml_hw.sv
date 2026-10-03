// CoreEP2C5 hardware wrapper for the direct LCD-touch ML path.
//
// The board oscillator is 50 MHz.  The verified serialized ML core is
// intentionally clocked at 5 MHz because the 50 MHz timing experiment did
// not meet timing.  The touch reader, frame adapter, and ML core all run in
// the same derived clock domain so that the one-cycle frame stream is not
// lost at a clock-domain boundary.
module cyclone2_lcd_ml_hw (
    input  logic       clk50,
    input  logic       reset_n,
    input  logic       joystick_up_n,
    input  logic       joystick_down_n,
    input  logic       touch_irq_n,
    input  logic       touch_miso,
    output logic       touch_cs_n,
    output logic       touch_sclk,
    output logic       touch_mosi,
    output logic [3:0] led,
    output logic       buzzer_n
);
    // Toggle every five 50 MHz edges: 50 MHz / 10 = 5 MHz.
    logic [2:0] div_count;
    logic       proc_clk;
    always_ff @(posedge clk50 or negedge reset_n) begin
        if (!reset_n) begin
            div_count <= 3'd0;
            proc_clk  <= 1'b0;
        end else if (div_count == 3'd4) begin
            div_count <= 3'd0;
            proc_clk  <= ~proc_clk;
        end else begin
            div_count <= div_count + 1'b1;
        end
    end

    // Synchronize external touch signals into the 5 MHz processing domain.
    logic irq_meta, irq_sync, miso_meta, miso_sync;
    always_ff @(posedge proc_clk or negedge reset_n) begin
        if (!reset_n) begin
            irq_meta  <= 1'b1;
            irq_sync  <= 1'b1;
            miso_meta <= 1'b0;
            miso_sync <= 1'b0;
        end else begin
            irq_meta  <= touch_irq_n;
            irq_sync  <= irq_meta;
            miso_meta <= touch_miso;
            miso_sync <= miso_meta;
        end
    end

    logic up_meta, up_sync, up_prev;
    logic down_meta, down_sync, down_prev;
    logic start_stream, clear_frame;
    always_ff @(posedge proc_clk or negedge reset_n) begin
        if (!reset_n) begin
            up_meta    <= 1'b1;
            up_sync    <= 1'b1;
            up_prev    <= 1'b1;
            down_meta  <= 1'b1;
            down_sync  <= 1'b1;
            down_prev  <= 1'b1;
        end else begin
            up_meta    <= joystick_up_n;
            up_sync    <= up_meta;
            up_prev    <= up_sync;
            down_meta  <= joystick_down_n;
            down_sync  <= down_meta;
            down_prev  <= down_sync;
        end
    end
    assign start_stream = up_prev && !up_sync;
    assign clear_frame  = down_prev && !down_sync;

    logic       ml_busy, result_valid, result_accepted;
    logic [3:0] result_digit;
    logic [7:0] result_confidence;
    logic [15:0] result_margin;
    logic [31:0] result_cycles;
    logic [3:0] displayed_digit;

    // CLOCK_DIV=3 gives approximately 833 kHz touch SCLK in the 5 MHz
    // processing domain, within the XPT2046 reader's intended range.
    touch_ml_scanpipe_top #(
        .TOUCH_CLOCK_DIV(3),
        .CONFIDENCE_THRESHOLD(0),
        .MARGIN_THRESHOLD(0)
    ) pipeline (
        .clk(proc_clk),
        .reset_n(reset_n),
        .clear_frame(clear_frame),
        .start_stream(start_stream),
        .touch_irq_n(irq_sync),
        .touch_miso(miso_sync),
        .touch_cs_n(touch_cs_n),
        .touch_sclk(touch_sclk),
        .touch_mosi(touch_mosi),
        .ml_busy(ml_busy),
        .result_valid(result_valid),
        .result_accepted(result_accepted),
        .result_digit(result_digit),
        .result_confidence(result_confidence),
        .result_margin(result_margin),
        .result_cycles(result_cycles)
    );

    always_ff @(posedge proc_clk or negedge reset_n) begin
        if (!reset_n)
            displayed_digit <= 4'd0;
        else if (result_valid)
            displayed_digit <= result_digit;
    end

    // The board LEDs are active-low.  A recognized digit is displayed as a
    // four-bit active-high value, then inverted at the physical pins.
    assign led      = ~displayed_digit;
    assign buzzer_n = 1'b1; // active-low buzzer: permanently muted
endmodule
