// Small first-step adapter for the direct LCD-to-ML path.
//
// The XPT2046 controller is deliberately outside this module.  An existing
// touch decoder supplies calibrated LCD coordinates and point_valid.  This
// adapter owns only the 14x14 frame contract shared with ml_inference.sv.
module touch_frame_adapter (
    input  logic       clk,
    input  logic       reset_n,
    input  logic       clear_frame,
    input  logic       point_valid,
    input  logic [8:0] point_x,       // 0..319, LCD coordinates
    input  logic [8:0] point_y,       // 0..239, LCD coordinates
    input  logic       start_stream,  // freeze current drawing and stream it
    output logic       stream_busy,
    output logic       input_frame_valid,
    output logic [7:0] input_pixel_index,
    output logic [3:0] input_pixel,
    output logic       input_frame_last,
    output logic       stream_done
);
    logic [3:0] frame [0:195];
    integer i;
    logic [3:0] mapped_x;
    logic [3:0] mapped_y;
    integer cell_index;
    logic [7:0] stream_index;

    // ceil(320*k/14) for k=1..13.  Thresholds avoid a run-time divider.
    function automatic [3:0] map_x(input logic [8:0] x);
        begin
            if      (x < 9'd23)  map_x = 4'd0;
            else if (x < 9'd46)  map_x = 4'd1;
            else if (x < 9'd69)  map_x = 4'd2;
            else if (x < 9'd92)  map_x = 4'd3;
            else if (x < 9'd115) map_x = 4'd4;
            else if (x < 9'd137) map_x = 4'd5;
            else if (x < 9'd160) map_x = 4'd6;
            else if (x < 9'd183) map_x = 4'd7;
            else if (x < 9'd206) map_x = 4'd8;
            else if (x < 9'd229) map_x = 4'd9;
            else if (x < 9'd252) map_x = 4'd10;
            else if (x < 9'd275) map_x = 4'd11;
            else if (x < 9'd297) map_x = 4'd12;
            else                 map_x = 4'd13;
        end
    endfunction

    // ceil(240*k/14) for k=1..13.  Thresholds preserve the original mapping.
    function automatic [3:0] map_y(input logic [8:0] y);
        begin
            if      (y < 9'd18)  map_y = 4'd0;
            else if (y < 9'd35)  map_y = 4'd1;
            else if (y < 9'd52)  map_y = 4'd2;
            else if (y < 9'd69)  map_y = 4'd3;
            else if (y < 9'd86)  map_y = 4'd4;
            else if (y < 9'd103) map_y = 4'd5;
            else if (y < 9'd120) map_y = 4'd6;
            else if (y < 9'd138) map_y = 4'd7;
            else if (y < 9'd155) map_y = 4'd8;
            else if (y < 9'd172) map_y = 4'd9;
            else if (y < 9'd189) map_y = 4'd10;
            else if (y < 9'd206) map_y = 4'd11;
            else if (y < 9'd223) map_y = 4'd12;
            else                 map_y = 4'd13;
        end
    endfunction

    always_comb begin
        mapped_x = map_x(point_x);
        mapped_y = map_y(point_y);
        cell_index = mapped_y * 14 + mapped_x;
    end

    always_ff @(posedge clk) begin
        input_frame_valid <= 1'b0;
        input_frame_last  <= 1'b0;
        stream_done       <= 1'b0;

        if (!reset_n) begin
            stream_busy        <= 1'b0;
            stream_index       <= 8'd0;
            input_pixel_index  <= 8'd0;
            input_pixel        <= 4'd0;
            for (i = 0; i < 196; i = i + 1)
                frame[i] <= 4'd0;
        end else if (clear_frame && !stream_busy) begin
            for (i = 0; i < 196; i = i + 1)
                frame[i] <= 4'd0;
        end else begin
            if (point_valid && !stream_busy)
                frame[cell_index] <= 4'hF;

            if (start_stream && !stream_busy) begin
                stream_busy  <= 1'b1;
                stream_index <= 8'd0;
            end else if (stream_busy) begin
                input_frame_valid <= 1'b1;
                input_pixel_index <= stream_index;
                input_pixel        <= frame[stream_index];
                input_frame_last   <= (stream_index == 8'd195);
                if (stream_index == 8'd195) begin
                    stream_busy <= 1'b0;
                    stream_done <= 1'b1;
                end else begin
                    stream_index <= stream_index + 1'b1;
                end
            end
        end
    end
endmodule
