// Convert calibrated XPT2046 ADC samples into LCD coordinates.
//
// This first calibration stage uses fixed raw limits from the proven Nios
// application (200..3900).  Division is avoided: the raw range is split into
// fourteen threshold bins and each bin emits its LCD-cell centre coordinate.
// The cell-centre output is sufficient for the 14x14 frame adapter and keeps
// this stage small.  Per-panel calibration constants can be refined later.
module xpt2046_calibrator (
    input  logic       clk,
    input  logic       reset_n,
    input  logic       sample_valid,
    input  logic [11:0] raw_x,
    input  logic [11:0] raw_y,
    output logic       point_valid,
    output logic [8:0] point_x,
    output logic [8:0] point_y
);
    function automatic [3:0] raw_to_cell(input logic [11:0] raw);
        begin
            if      (raw < 12'd465)  raw_to_cell = 4'd0;
            else if (raw < 12'd729)  raw_to_cell = 4'd1;
            else if (raw < 12'd994)  raw_to_cell = 4'd2;
            else if (raw < 12'd1258) raw_to_cell = 4'd3;
            else if (raw < 12'd1522) raw_to_cell = 4'd4;
            else if (raw < 12'd1786) raw_to_cell = 4'd5;
            else if (raw < 12'd2051) raw_to_cell = 4'd6;
            else if (raw < 12'd2315) raw_to_cell = 4'd7;
            else if (raw < 12'd2579) raw_to_cell = 4'd8;
            else if (raw < 12'd2843) raw_to_cell = 4'd9;
            else if (raw < 12'd3108) raw_to_cell = 4'd10;
            else if (raw < 12'd3372) raw_to_cell = 4'd11;
            else if (raw < 12'd3636) raw_to_cell = 4'd12;
            else                       raw_to_cell = 4'd13;
        end
    endfunction

    function automatic [8:0] cell_to_x(input logic [3:0] idx);
        begin
            case (idx)
                // Centers of 14 equal cells over logical X=0..319.
                // The previous table skipped the 103-pixel center and
                // shifted every later cell by 11 pixels.
                4'd0: cell_to_x = 9'd11;  4'd1: cell_to_x = 9'd34;
                4'd2: cell_to_x = 9'd57;  4'd3: cell_to_x = 9'd80;
                4'd4: cell_to_x = 9'd103; 4'd5: cell_to_x = 9'd126;
                4'd6: cell_to_x = 9'd149; 4'd7: cell_to_x = 9'd171;
                4'd8: cell_to_x = 9'd194; 4'd9: cell_to_x = 9'd217;
                4'd10: cell_to_x = 9'd240; 4'd11: cell_to_x = 9'd263;
                4'd12: cell_to_x = 9'd286; default: cell_to_x = 9'd309;
            endcase
        end
    endfunction

    function automatic [8:0] cell_to_y(input logic [3:0] idx);
        begin
            case (idx)
                4'd0: cell_to_y = 9'd9;   4'd1: cell_to_y = 9'd26;
                4'd2: cell_to_y = 9'd43;  4'd3: cell_to_y = 9'd60;
                4'd4: cell_to_y = 9'd77;  4'd5: cell_to_y = 9'd94;
                4'd6: cell_to_y = 9'd111; 4'd7: cell_to_y = 9'd129;
                4'd8: cell_to_y = 9'd146; 4'd9: cell_to_y = 9'd163;
                4'd10: cell_to_y = 9'd180; 4'd11: cell_to_y = 9'd197;
                4'd12: cell_to_y = 9'd214; default: cell_to_y = 9'd231;
            endcase
        end
    endfunction

    always_ff @(posedge clk) begin
        if (!reset_n) begin
            point_valid <= 1'b0;
            point_x <= 9'd0;
            point_y <= 9'd0;
        end else begin
            point_valid <= sample_valid;
            if (sample_valid) begin
                point_x <= cell_to_x(raw_to_cell(raw_x));
                point_y <= cell_to_y(raw_to_cell(raw_y));
            end
        end
    end
endmodule
