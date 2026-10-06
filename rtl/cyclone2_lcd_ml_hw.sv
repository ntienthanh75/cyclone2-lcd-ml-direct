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
    input  logic       joystick_1_n,
    input  logic       joystick_2_n,
    input  logic       joystick_3_n,
    input  logic       joystick_4_n,
    input  logic       joystick_press_n,
    input  logic       touch_irq_n,
    input  logic       touch_miso,
    output logic       touch_cs_n,
    output logic       touch_sclk,
    output logic       touch_mosi,
    inout  wire [15:0] lcd_data,
    output logic       lcd_cs_n,
    output logic       lcd_rs,
    output logic       lcd_wr_n,
    output logic       lcd_rd_n,
    output logic       lcd_rst_n,
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

    logic [3:0] joy_meta, joy_sync, joy_prev;
    logic press_meta, press_sync;
    logic start_stream, clear_frame;
    logic shutdown_latched;
    logic pipeline_reset_n;
    always_ff @(posedge proc_clk or negedge reset_n) begin
        if (!reset_n) begin
            joy_meta         <= 4'b1111;
            joy_sync         <= 4'b1111;
            joy_prev         <= 4'b1111;
            press_meta       <= 1'b1;
            press_sync       <= 1'b1;
            shutdown_latched <= 1'b0;
        end else begin
            joy_meta   <= {joystick_4_n, joystick_3_n, joystick_2_n, joystick_1_n};
            joy_sync   <= joy_meta;
            joy_prev   <= joy_sync;
            press_meta <= joystick_press_n;
            press_sync <= press_meta;
            if (joy_prev[3] && !joy_sync[3])
                shutdown_latched <= 1'b1;
        end
    end
    assign start_stream  = joy_prev[0] && !joy_sync[0];
    assign clear_frame   = (joy_prev[1] && !joy_sync[1]) ||
                           (joy_prev[2] && !joy_sync[2]);
    assign pipeline_reset_n = reset_n && !shutdown_latched;

    logic       ml_busy, result_valid, result_accepted;
    logic [3:0] result_digit;
    logic [7:0] result_confidence;
    logic [15:0] result_margin;
    logic [31:0] result_cycles;
    logic point_valid;
    logic [8:0] point_x, point_y;
    logic lcd_ready;
    logic [3:0] displayed_digit;
    logic [20:0] submit_ack_count;
    logic [21:0] result_ack_count;

    // CLOCK_DIV=3 gives approximately 833 kHz touch SCLK in the 5 MHz
    // processing domain, within the XPT2046 reader's intended range.
    touch_ml_scanpipe_top #(
        .TOUCH_CLOCK_DIV(3),
        .CONFIDENCE_THRESHOLD(0),
        .MARGIN_THRESHOLD(0)
    ) pipeline (
        .clk(proc_clk),
        .reset_n(pipeline_reset_n),
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
        .result_cycles(result_cycles),
        .point_valid(point_valid), .point_x(point_x), .point_y(point_y)
    );

    lcd_live_writer lcd_writer (
        .clk(proc_clk), .reset_n(pipeline_reset_n),
        .point_valid(point_valid), .point_x(point_x), .point_y(point_y),
        .lcd_data(lcd_data), .lcd_cs_n(lcd_cs_n), .lcd_rs(lcd_rs),
        .lcd_wr_n(lcd_wr_n), .lcd_rd_n(lcd_rd_n), .lcd_rst_n(lcd_rst_n),
        .ready(lcd_ready)
    );

    always_ff @(posedge proc_clk or negedge reset_n) begin
        if (!reset_n) begin
            displayed_digit <= 4'd0;
            submit_ack_count <= 21'd0;
            result_ack_count <= 22'd0;
        end else begin
            if (start_stream)
                submit_ack_count <= 21'd1_000_000; // 200 ms at 5 MHz
            else if (submit_ack_count != 0)
                submit_ack_count <= submit_ack_count - 1'b1;

            if (result_valid) begin
                displayed_digit <= result_digit;
                result_ack_count <= 22'd2_500_000; // 500 ms at 5 MHz
            end else if (result_ack_count != 0) begin
                result_ack_count <= result_ack_count - 1'b1;
            end
        end
    end

    // LED status protocol, all active-low:
    //   pressed channel: matching LED
    //   submit accepted: LED1 + LED4 for 200 ms
    //   ML busy:         LED1 + LED3
    //   result accepted: LED2 + LED4 for 500 ms
    //   otherwise:       recognized digit
    always_comb begin
        if (!press_sync)
            led = 4'b0000;
        else if (joy_sync != 4'b1111)
            led = joy_sync;
        else if (ml_busy)
            led = 4'b1010;
        else if (result_ack_count != 0)
            led = 4'b0101;
        else if (submit_ack_count != 0)
            led = 4'b0110;
        else
            led = ~displayed_digit;
    end
    assign buzzer_n = 1'b1; // active-low buzzer: permanently muted
endmodule
