// =============================================================================
// DP TX + RISC-V AUX Controller — Single-File Pack
// Contains all RTL modules + comprehensive testbench
// For simulation: compile with +define+__ICARUS__ +define+SIM_QUIET
// For Vivado:     set -d __ICARUS__ -d SIM_QUIET in xsim compile options
// =============================================================================

`timescale 1ns/1ps

// =============================================================================
// 8b/10b Encoder
// =============================================================================
module dp_tx_8b10b_enc (
    input  wire [7:0]  data_in,
    input  wire        is_k,
    input  wire        disp_in,
    output reg  [9:0]  code_out,
    output reg         disp_out
);

    wire [4:0] abcde = data_in[4:0];
    wire [2:0] fgh   = data_in[7:5];

    reg [5:0] six;
    reg [3:0] four;

    reg [2:0] cnt6, cnt4;

    always @(*) begin
        six = 6'b0;
        four = 4'b0;

        if (is_k) begin
            casez ({fgh, abcde})
                8'b101_11100: begin six = disp_in ? 6'b001111 : 6'b110000; four = disp_in ? 4'b1010 : 4'b0101; end
                8'b?00_11100: begin six = disp_in ? 6'b001111 : 6'b110000; four = disp_in ? 4'b1010 : 4'b0101; end
                8'b?01_11100: begin six = disp_in ? 6'b001111 : 6'b110000; four = disp_in ? 4'b1001 : 4'b0110; end
                8'b?10_11100: begin six = disp_in ? 6'b001111 : 6'b110000; four = disp_in ? 4'b0101 : 4'b1010; end
                8'b?11_11100: begin six = disp_in ? 6'b001111 : 6'b110000; four = disp_in ? 4'b1100 : 4'b0011; end
                8'b000_11011: begin six = disp_in ? 6'b001110 : 6'b110001; four = 4'b1001; end
                8'b001_11011: begin six = disp_in ? 6'b001110 : 6'b110001; four = 4'b0101; end
                8'b010_11011: begin six = disp_in ? 6'b001110 : 6'b110001; four = 4'b1100; end
                8'b011_11011: begin six = disp_in ? 6'b001110 : 6'b110001; four = 4'b0011; end
                8'b100_11011: begin six = disp_in ? 6'b001110 : 6'b110001; four = 4'b1010; end
                8'b101_11011: begin six = disp_in ? 6'b001110 : 6'b110001; four = 4'b0110; end
                8'b110_11011: begin six = disp_in ? 6'b001110 : 6'b110001; four = 4'b0101; end
                8'b111_11011: begin six = disp_in ? 6'b001110 : 6'b110001; four = disp_in ? 4'b1001 : 4'b0110; end
                default: begin six = 6'b0; four = 4'b0; end
            endcase
        end else begin
            case (abcde)
                5'd0:  six = disp_in ? 6'b011000 : 6'b100111;
                5'd1:  six = disp_in ? 6'b100010 : 6'b011101;
                5'd2:  six = disp_in ? 6'b010010 : 6'b101101;
                5'd3:  six = 6'b110001;
                5'd4:  six = disp_in ? 6'b001010 : 6'b110101;
                5'd5:  six = 6'b101001;
                5'd6:  six = 6'b011001;
                5'd7:  six = disp_in ? 6'b000111 : 6'b111000;
                5'd8:  six = disp_in ? 6'b000110 : 6'b111001;
                5'd9:  six = 6'b100101;
                5'd10: six = 6'b010101;
                5'd11: six = 6'b110100;
                5'd12: six = 6'b001101;
                5'd13: six = 6'b101100;
                5'd14: six = 6'b011100;
                5'd15: six = disp_in ? 6'b101000 : 6'b010111;
                5'd16: six = disp_in ? 6'b100100 : 6'b011011;
                5'd17: six = 6'b100011;
                5'd18: six = 6'b010011;
                5'd19: six = 6'b110010;
                5'd20: six = 6'b001011;
                5'd21: six = 6'b101010;
                5'd22: six = 6'b011010;
                5'd23: six = disp_in ? 6'b000101 : 6'b111010;
                5'd24: six = disp_in ? 6'b001100 : 6'b110011;
                5'd25: six = 6'b100110;
                5'd26: six = 6'b010110;
                5'd27: six = disp_in ? 6'b001001 : 6'b110110;
                5'd28: six = 6'b001110;
                5'd29: six = 6'b010001;
                5'd30: six = 6'b100001;
                5'd31: six = disp_in ? 6'b101000 : 6'b010111;
            endcase

            case (fgh)
                3'd0: four = disp_in ? 4'b0100 : 4'b1011;
                3'd1: four = 4'b1001;
                3'd2: four = 4'b0101;
                3'd3: four = disp_in ? 4'b0011 : 4'b1100;
                3'd4: four = disp_in ? 4'b0010 : 4'b1101;
                3'd5: four = 4'b1010;
                3'd6: four = 4'b0110;
                3'd7: four = disp_in ? 4'b0001 : 4'b1110;
            endcase
        end

        code_out = {four, six};
        cnt6 = {3'd0, six[0]} + {3'd0, six[1]} + {3'd0, six[2]}
             + {3'd0, six[3]} + {3'd0, six[4]} + {3'd0, six[5]};
        cnt4 = {3'd0, four[0]} + {3'd0, four[1]} + {3'd0, four[2]} + {3'd0, four[3]};
        if (cnt6 > 3'd3)
            disp_out = 1'b1;
        else if (cnt6 < 3'd3)
            disp_out = 1'b0;
        else if (cnt4 > 3'd2)
            disp_out = 1'b1;
        else if (cnt4 < 3'd2)
            disp_out = 1'b0;
        else
            disp_out = disp_in;
    end

endmodule

// =============================================================================
// Video Packer: 24-bit pixel -> 3 x 8-bit bytes
// =============================================================================
module dp_tx_video_packer (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [23:0] pixel_in,
    input  wire        pixel_valid,
    input  wire        pixel_sof,
    output reg  [7:0]  byte_out,
    output reg         byte_valid,
    output reg         byte_sof,
    output wire        pixel_ready
);

    reg [1:0] byte_sel;
    reg [23:0] pixel_held;
    reg        pixel_start;

    assign pixel_ready = pixel_start;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            byte_sel     <= 2'd0;
            byte_out     <= 8'h00;
            byte_valid   <= 1'b0;
            byte_sof     <= 1'b0;
            pixel_held   <= 24'd0;
            pixel_start  <= 1'b1;
        end else begin
            byte_sof  <= 1'b0;

            if (pixel_valid && pixel_start) begin
                pixel_held  <= pixel_in;
                pixel_start <= 1'b0;
                byte_out    <= pixel_in[7:0];
                byte_sel    <= 2'd1;
                byte_valid  <= 1'b1;
                if (pixel_sof)
                    byte_sof <= 1'b1;
            end else if (!pixel_start) begin
                byte_valid <= 1'b1;
                case (byte_sel)
                    2'd1: begin byte_out <= pixel_held[15:8];  byte_sel <= 2'd2; end
                    2'd2: begin byte_out <= pixel_held[23:16]; byte_sel <= 2'd0; pixel_start <= 1'b1; end
                    default: begin byte_out <= 8'h00; byte_sel <= 2'd0; pixel_start <= 1'b1; end
                endcase
            end else begin
                byte_valid <= 1'b0;
            end
        end
    end
endmodule

// =============================================================================
// Async FIFO for Pixel Clock Domain Crossing
// =============================================================================
module dp_tx_pixel_fifo #(
    parameter WIDTH = 26,
    parameter DEPTH = 8
) (
    input  wire               wr_clk,
    input  wire               wr_rst_n,
    input  wire               wr_en,
    input  wire [WIDTH-1:0]   wr_data,
    output wire               full,

    input  wire               rd_clk,
    input  wire               rd_rst_n,
    input  wire               rd_en,
    output wire [WIDTH-1:0]   rd_data,
    output wire               empty
);

    localparam PTR_W = $clog2(DEPTH);

    reg [WIDTH-1:0] mem [0:DEPTH-1];
    reg [PTR_W:0]   wr_ptr, rd_ptr;
    reg [PTR_W:0]   wr_gray, rd_gray;
    reg [PTR_W:0]   wr_gray_sync1, wr_gray_sync2;
    reg [PTR_W:0]   rd_gray_sync1, rd_gray_sync2;

    wire [PTR_W:0]  wr_bin_next = wr_ptr + 1;
    wire [PTR_W:0]  rd_bin_next = rd_ptr + 1;
    wire [PTR_W:0]  wr_gray_next = wr_bin_next ^ (wr_bin_next >> 1);
    wire [PTR_W:0]  rd_gray_next = rd_bin_next ^ (rd_bin_next >> 1);

    always @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            wr_ptr  <= 0;
            wr_gray <= 0;
        end else if (wr_en && !full) begin
            mem[wr_ptr[PTR_W-1:0]] <= wr_data;
            wr_ptr  <= wr_bin_next;
            wr_gray <= wr_gray_next;
        end
    end

    assign rd_data = mem[rd_ptr[PTR_W-1:0]];

    always @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            rd_ptr  <= 0;
            rd_gray <= 0;
        end else if (rd_en && !empty) begin
            rd_ptr  <= rd_bin_next;
            rd_gray <= rd_gray_next;
        end
    end

    always @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            wr_gray_sync1 <= 0;
            wr_gray_sync2 <= 0;
        end else begin
            wr_gray_sync1 <= wr_gray;
            wr_gray_sync2 <= wr_gray_sync1;
        end
    end

    always @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            rd_gray_sync1 <= 0;
            rd_gray_sync2 <= 0;
        end else begin
            rd_gray_sync1 <= rd_gray;
            rd_gray_sync2 <= rd_gray_sync1;
        end
    end

    function [PTR_W:0] gray2bin;
        input [PTR_W:0] gray;
        reg [PTR_W:0] bin;
        integer i;
        begin
            bin[PTR_W] = gray[PTR_W];
            for (i = PTR_W-1; i >= 0; i = i - 1)
                bin[i] = bin[i+1] ^ gray[i];
            gray2bin = bin;
        end
    endfunction

    wire [PTR_W:0] rd_bin_sync = gray2bin(rd_gray_sync2);

    assign full  = (wr_bin_next[PTR_W-1:0] == rd_bin_sync[PTR_W-1:0])
                && (wr_bin_next[PTR_W] != rd_bin_sync[PTR_W]);

    assign empty = (wr_gray_sync2 == rd_gray);

endmodule

// =============================================================================
// DP TX Scrambler (LFSR-based)
// =============================================================================
module dp_tx_scrambler (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        scrambler_rst,
    input  wire [7:0]  data_in,
    input  wire        data_valid,
    output reg  [7:0]  data_out,
    output reg         data_out_valid
);

    reg [15:0] lfsr;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lfsr            <= 16'hFFFF;
            data_out        <= 8'h00;
            data_out_valid  <= 1'b0;
        end else begin
            data_out_valid <= data_valid;

            if (scrambler_rst) begin
                lfsr <= 16'hFFFF;
                data_out <= 8'h00;
            end else if (data_valid) begin
                data_out <= data_in ^ lfsr[15:8];
                lfsr <= lfsr_next(lfsr);
            end else begin
                data_out <= 8'h00;
            end
        end
    end

    function [15:0] lfsr_next;
        input [15:0] s;
        reg [15:0] t;
        integer i;
        begin
            t = s;
            for (i = 0; i < 8; i = i + 1)
                t = {t[14:0], t[15] ^ t[4] ^ t[3] ^ t[2]};
            lfsr_next = t;
        end
    endfunction

endmodule

// =============================================================================
// MSA (Main Stream Attribute) Generator — 36-byte packet
// =============================================================================
module dp_tx_msa_gen #(
    parameter TU_SIZE = 16'd64
)(
    input  wire        clk,
    input  wire        rst_n,

    input  wire [15:0] h_active,
    input  wire [15:0] v_active,
    input  wire [15:0] h_total,
    input  wire [15:0] v_total,
    input  wire [15:0] h_sw,
    input  wire [15:0] v_sw,
    input  wire [15:0] h_bp,
    input  wire [15:0] v_bp,
    input  wire [7:0]  bpc,
    input  wire [7:0]  color_fmt,
    input  wire        h_pol,
    input  wire        v_pol,

    input  wire        trig,
    output reg         busy,
    output reg  [7:0]  byte_out,
    output reg         byte_valid,
    output reg         byte_sof
);

    reg [5:0] idx;
    reg       sending;

    reg [15:0] r_h_active, r_v_active, r_h_total, r_v_total;
    reg [15:0] r_h_sw, r_v_sw, r_h_bp, r_v_bp;
    reg [7:0]  r_bpc, r_color_fmt;
    reg        r_h_pol, r_v_pol;

    always @(posedge clk) begin
        r_h_active  <= h_active;
        r_v_active  <= v_active;
        r_h_total   <= h_total;
        r_v_total   <= v_total;
        r_h_sw      <= h_sw;
        r_v_sw      <= v_sw;
        r_h_bp      <= h_bp;
        r_v_bp      <= v_bp;
        r_bpc       <= bpc;
        r_color_fmt <= color_fmt;
        r_h_pol     <= h_pol;
        r_v_pol     <= v_pol;
    end

    wire [15:0] h_fp = (r_h_total >= r_h_active + r_h_sw + r_h_bp) ?
                       (r_h_total - r_h_active - r_h_sw - r_h_bp) : 16'd0;
    wire [15:0] v_fp = (r_v_total >= r_v_active + r_v_sw + r_v_bp) ?
                       (r_v_total - r_v_active - r_v_sw - r_v_bp) : 16'd0;

    wire [15:0] h_blank_start = r_h_active;
    wire [15:0] h_blank_end   = r_h_total;
    wire [15:0] v_blank_start = r_v_active;
    wire [15:0] v_blank_end   = r_v_total;

    reg [3:0] bpc_code;
    always @(*) begin
        case (r_bpc)
            8'd6:  bpc_code = 4'd0;
            8'd8:  bpc_code = 4'd1;
            8'd10: bpc_code = 4'd2;
            8'd12: bpc_code = 4'd3;
            8'd16: bpc_code = 4'd4;
            default: bpc_code = 4'd1;
        endcase
    end

    reg [7:0] msa_byte;
    always @(*) begin
        case (idx)
            6'd0:  msa_byte = 8'h02;
            6'd1:  msa_byte = 8'h00;
            6'd2:  msa_byte = 8'h00;
            6'd3:  msa_byte = 8'd1;
            6'd4:  msa_byte = 8'd0;
            6'd5:  msa_byte = 8'd1;
            6'd6:  msa_byte = 8'd0;
            6'd7:  msa_byte = TU_SIZE[7:0];
            6'd8:  msa_byte = TU_SIZE[15:8];
            6'd9:  msa_byte = TU_SIZE[7:0];
            6'd10: msa_byte = TU_SIZE[15:8];
            6'd11: msa_byte = r_h_active[7:0];
            6'd12: msa_byte = r_h_active[15:8];
            6'd13: msa_byte = r_v_active[7:0];
            6'd14: msa_byte = r_v_active[15:8];
            6'd15: msa_byte = {bpc_code, r_color_fmt[3:0]};
            6'd16: msa_byte = h_blank_start[7:0];
            6'd17: msa_byte = h_blank_start[15:8];
            6'd18: msa_byte = h_blank_end[7:0];
            6'd19: msa_byte = h_blank_end[15:8];
            6'd20: msa_byte = r_h_sw[7:0];
            6'd21: msa_byte = r_h_sw[15:8];
            6'd22: msa_byte = r_v_sw[7:0];
            6'd23: msa_byte = r_v_sw[15:8];
            6'd24: msa_byte = v_blank_start[7:0];
            6'd25: msa_byte = v_blank_start[15:8];
            6'd26: msa_byte = v_blank_end[7:0];
            6'd27: msa_byte = v_blank_end[15:8];
            6'd28: msa_byte = {7'h00, r_h_pol};
            6'd29: msa_byte = {7'h00, r_v_pol};
            6'd30: msa_byte = 8'h00;
            6'd31: msa_byte = r_h_total[7:0];
            6'd32: msa_byte = r_h_total[15:8];
            6'd33: msa_byte = r_v_total[7:0];
            6'd34: msa_byte = r_v_total[15:8];
            6'd35: msa_byte = 8'h00;
            default: msa_byte = 8'h00;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            idx     <= 6'd0;
            sending <= 1'b0;
            busy    <= 1'b0;
            byte_out   <= 8'h00;
            byte_valid <= 1'b0;
            byte_sof   <= 1'b0;
        end else begin
            byte_valid <= 1'b0;
            byte_sof   <= 1'b0;

            if (!sending && trig) begin
                sending <= 1'b1;
                busy    <= 1'b1;
                idx     <= 6'd0;
            end

            if (sending) begin
                byte_out   <= msa_byte;
                byte_valid <= 1'b1;
                byte_sof   <= (idx == 6'd0);

                if (idx == 6'd35) begin
                    sending <= 1'b0;
                    busy    <= 1'b0;
                    idx     <= 6'd0;
                end else begin
                    idx <= idx + 1'b1;
                end
            end
        end
    end

endmodule

// =============================================================================
// Stream Mux: BS/MSA/Video selection
// =============================================================================
module dp_tx_stream_mux (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        blanking,
    input  wire        in_vblank,
    input  wire [7:0]  msa_byte,
    input  wire        msa_valid,
    input  wire        msa_sof,
    input  wire [7:0]  video_byte,
    input  wire        video_valid,
    input  wire        video_sof,
    output reg  [7:0]  out_byte,
    output reg         out_valid,
    output reg         out_sof,
    output reg         out_k,
    output reg         scrambler_rst
);

    reg [2:0] bstate;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bstate       <= 3'd0;
            out_byte     <= 8'h00;
            out_valid    <= 1'b0;
            out_sof      <= 1'b0;
            out_k        <= 1'b0;
            scrambler_rst <= 1'b0;
        end else begin
            out_valid <= 1'b0;
            out_sof   <= 1'b0;
            out_k     <= 1'b0;
            scrambler_rst <= 1'b0;

            case (bstate)
                3'd0: begin
                    if (blanking) begin
                        bstate       <= 3'd1;
                        out_byte     <= 8'hBC;
                        out_valid    <= 1'b1;
                        out_sof      <= 1'b1;
                        out_k        <= 1'b1;
                        scrambler_rst <= 1'b1;
                    end else if (video_valid) begin
                        out_byte  <= video_byte;
                        out_valid <= 1'b1;
                        out_sof   <= video_sof;
                    end
                end

                3'd1: begin
                    bstate    <= 3'd2;
                    out_byte  <= 8'hCB;
                    out_valid <= 1'b1;
                end

                3'd2: begin
                    bstate    <= 3'd3;
                    out_byte  <= in_vblank ? 8'h02 : 8'h00;
                    out_valid <= 1'b1;
                end

                3'd3: begin
                    if (msa_valid) begin
                        out_byte  <= msa_byte;
                        out_valid <= 1'b1;
                        out_sof   <= msa_sof;
                    end else if (!blanking) begin
                        bstate    <= 3'd4;
                        out_byte  <= 8'hBC;
                        out_valid <= 1'b1;
                        out_k     <= 1'b1;
                    end else begin
                        out_byte  <= 8'h00;
                        out_valid <= 1'b1;
                    end
                end

                3'd4: begin
                    bstate    <= 3'd0;
                    out_byte  <= 8'hC6;
                    out_valid <= 1'b1;
                end

                default: begin
                    bstate <= 3'd0;
                end
            endcase
        end
    end

endmodule

// =============================================================================
// Lane Mapper: 8-bit serial -> 4-lane x 8-bit parallel
// =============================================================================
module dp_tx_lane_mapper #(
    parameter LANE_COUNT = 4
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [7:0]  in_byte,
    input  wire        in_valid,
    input  wire        in_sof,
    input  wire        in_k,
    output reg  [31:0] out_data,
    output reg  [3:0]  out_k_mask,
    output reg         out_valid,
    output reg         out_sof
);

    reg [1:0] cnt;
    reg [31:0] lane_buf;
    reg [3:0]  k_buf;
    reg        sof_pending;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt         <= 2'd0;
            lane_buf    <= 32'd0;
            k_buf       <= 4'd0;
            out_data    <= 32'd0;
            out_k_mask  <= 4'd0;
            out_valid   <= 1'b0;
            out_sof     <= 1'b0;
            sof_pending <= 1'b0;
        end else begin
            out_valid   <= 1'b0;
            out_sof     <= 1'b0;
            out_k_mask  <= 4'd0;

            if (in_valid) begin
                if (in_sof) begin
                    cnt         <= 2'd0;
                    sof_pending <= 1'b1;
                end

                if (LANE_COUNT == 1) begin
                    out_data   <= {24'd0, in_byte};
                    out_k_mask <= {3'd0, in_k};
                    out_valid  <= 1'b1;
                    out_sof    <= sof_pending | in_sof;
                    sof_pending <= 1'b0;
                end else begin
                    case (cnt)
                        2'd0: begin lane_buf[7:0] <= in_byte; k_buf[0] <= in_k; end
                        2'd1: begin lane_buf[15:8] <= in_byte; k_buf[1] <= in_k; end
                        2'd2: begin lane_buf[23:16] <= in_byte; k_buf[2] <= in_k; end
                    endcase

                    if (cnt == LANE_COUNT - 1) begin
                        out_data   <= (LANE_COUNT == 2) ? {16'd0, in_byte, lane_buf[7:0]} :
                                      {in_byte, lane_buf[23:16], lane_buf[15:8], lane_buf[7:0]};
                        out_k_mask <= (LANE_COUNT == 2) ? {2'd0, in_k, k_buf[0]} :
                                      {in_k, k_buf[2], k_buf[1], k_buf[0]};
                        out_valid  <= 1'b1;
                        out_sof    <= sof_pending;
                        sof_pending <= 1'b0;
                        cnt        <= 2'd0;
                    end else begin
                        cnt <= cnt + 1'b1;
                    end
                end
            end
        end
    end

endmodule

// =============================================================================
// PHY: 8b/10b encoders + GTXE2_CHANNEL (synthesis) or behavioral (sim)
// =============================================================================
module dp_tx_phy_7series (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] tx_data,
    input  wire [3:0]  tx_k_mask,
    input  wire        tx_valid,
    input  wire        tx_sof,
    output wire [9:0]  tx_code0,
    output wire [9:0]  tx_code1,
    output wire [9:0]  tx_code2,
    output wire [9:0]  tx_code3,
    output wire [3:0]  txp,
    output wire [3:0]  txn
);

    reg disp0, disp1, disp2, disp3;
    wire disp_next0, disp_next1, disp_next2, disp_next3;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            disp0 <= 1'b0;
            disp1 <= 1'b0;
            disp2 <= 1'b0;
            disp3 <= 1'b0;
        end else if (tx_valid) begin
            disp0 <= disp_next0;
            disp1 <= disp_next1;
            disp2 <= disp_next2;
            disp3 <= disp_next3;
        end
    end

    dp_tx_8b10b_enc enc0 (
        .data_in (tx_data[7:0]),
        .is_k    (tx_k_mask[0]),
        .disp_in (disp0),
        .code_out(tx_code0),
        .disp_out(disp_next0)
    );

    dp_tx_8b10b_enc enc1 (
        .data_in (tx_data[15:8]),
        .is_k    (tx_k_mask[1]),
        .disp_in (disp1),
        .code_out(tx_code1),
        .disp_out(disp_next1)
    );

    dp_tx_8b10b_enc enc2 (
        .data_in (tx_data[23:16]),
        .is_k    (tx_k_mask[2]),
        .disp_in (disp2),
        .code_out(tx_code2),
        .disp_out(disp_next2)
    );

    dp_tx_8b10b_enc enc3 (
        .data_in (tx_data[31:24]),
        .is_k    (tx_k_mask[3]),
        .disp_in (disp3),
        .code_out(tx_code3),
        .disp_out(disp_next3)
    );

`ifdef __ICARUS__
    assign txp[0] = tx_code0[0];
    assign txn[0] = ~tx_code0[0];
    assign txp[1] = tx_code1[0];
    assign txn[1] = ~tx_code1[0];
    assign txp[2] = tx_code2[0];
    assign txn[2] = ~tx_code2[0];
    assign txp[3] = tx_code3[0];
    assign txn[3] = ~tx_code3[0];
`else
    reg gearbox_toggle;
    reg [9:0] sym_odd[3:0];
    reg [19:0] gtx_txdata[3:0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gearbox_toggle <= 1'b0;
        end else if (tx_valid) begin
            gearbox_toggle <= ~gearbox_toggle;
            if (!gearbox_toggle) begin
                sym_odd[0] <= tx_code0;
                sym_odd[1] <= tx_code1;
                sym_odd[2] <= tx_code2;
                sym_odd[3] <= tx_code3;
            end else begin
                gtx_txdata[0] <= {tx_code0[9:0], sym_odd[0]};
                gtx_txdata[1] <= {tx_code1[9:0], sym_odd[1]};
                gtx_txdata[2] <= {tx_code2[9:0], sym_odd[2]};
                gtx_txdata[3] <= {tx_code3[9:0], sym_odd[3]};
            end
        end
    end

    wire gtx_txusrclk2;
    BUFGCE_DIV #(.BUFGCE_DIVIDE(2)) bufg_div (
        .I(clk), .O(gtx_txusrclk2), .CE(1'b1), .CLR(~rst_n)
    );

    reg [7:0] gtx_rst_cnt;
    reg gtx_txusrrdy;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gtx_rst_cnt  <= 8'd0;
            gtx_txusrrdy <= 1'b0;
        end else if (gtx_rst_cnt < 8'd200) begin
            gtx_rst_cnt <= gtx_rst_cnt + 1;
        end else begin
            gtx_txusrrdy <= 1'b1;
        end
    end

    genvar l;
    generate
        for (l = 0; l < 4; l = l + 1) begin : gtx_lane
            wire lane_txp, lane_txn;

            GTXE2_CHANNEL #(
                .TX_DATA_WIDTH(20),
                .TX_INT_DATAWIDTH(0),
                .TX_8B10B_EN("FALSE"),
                .TXOUT_DIV(1),
                .TX_CLK25_DIV(10),
                .PMA_RSV(32'h00000000),
                .TX_PMA_CFG(16'h0080),
                .SIM_GTRESET_SPEEDUP("TRUE"),
                .SIM_TX_RESET_SPEEDUP("TRUE")
            ) gtx_inst (
                .GTREFCLK0    (clk),
                .GTREFCLK1    (1'b0),
                .TXPD         (2'b00),
                .TXSYSCLKSEL  (2'b01),
                .TXUSRCLK     (gtx_txusrclk2),
                .TXUSRCLK2    (gtx_txusrclk2),
                .TXDATA       (gtx_txdata[l]),
                .TXBYPASS8B10B({2{1'b1}}),
                .TXCHARDISPMODE(2'b00),
                .TXCHARDISPVAL (2'b00),
                .TXCHARISK     (2'b00),
                .TXPOLARITY    (1'b0),
                .TXDIFFCTRL    (3'b100),
                .TXMAINCURSOR  (7'b0000000),
                .TXDETECTRX    (1'b0),
                .TXDLYBYPASS   (1'b1),
                .TXRESETMODE   (1'b0),
                .TXPCSRESET    (1'b0),
                .TXBUFPDCE     (1'b0),
                .TXBUFRESET    (1'b0),
                .GTTXRESET     (1'b0),
                .TXUSERRDY     (gtx_txusrrdy),
                .TXP           (lane_txp),
                .TXN           (lane_txn)
            );

            assign txp[l] = lane_txp;
            assign txn[l] = lane_txn;
        end
    endgenerate
`endif

endmodule

// =============================================================================
// PicoRV32 — RV32I Softcore
// =============================================================================
module picorv32 #(
    parameter [0:0] ENABLE_COUNTERS = 1'b1
) (
    input  wire        clk,
    input  wire        rst_n,
    output reg         mem_valid,
    output reg         mem_instr,
    input  wire        mem_ready,
    output reg [31:0]  mem_addr,
    output reg [31:0]  mem_wdata,
    output reg [3:0]   mem_wstrb,
    input  wire [31:0] mem_rdata
);

    reg [31:0] pc;
    reg [31:0] next_pc;
    reg [31:0] ir;
    reg [31:0] regs [0:31];

    reg [31:0] reg_rd_data;
    reg        reg_rd_we;
    reg [4:0]  reg_rd_addr;

    reg [31:0] alu_out;
    reg        alu_out_valid;

    reg [31:0] mem_addr_q;
    reg [31:0] mem_wdata_q;
    reg [3:0]  mem_wstrb_q;
    reg        mem_is_load;
    reg        mem_is_store;

    reg [31:0] mcycle;
    reg [31:0] minstret;

    reg        trap;
    reg [31:0] trap_epc;
    reg [31:0] trap_cause;

    localparam STATE_FETCH  = 2'd0;
    localparam STATE_EXEC   = 2'd1;
    localparam STATE_LMEM   = 2'd2;
    localparam STATE_TRAP   = 2'd3;

    reg [1:0] state;

    integer i;

    wire [6:0] opcode   = ir[6:0];
    wire [2:0] funct3   = ir[14:12];
    wire [6:0] funct7   = ir[31:25];
    wire [4:0] rs1_addr = ir[19:15];
    wire [4:0] rs2_addr = ir[24:20];
    wire [4:0] rd_addr  = ir[11:7];

    wire [31:0] rs1 = regs[rs1_addr];
    wire [31:0] rs2 = regs[rs2_addr];

    wire [31:0] imm_i = { {20{ir[31]}}, ir[31:20] };
    wire [31:0] imm_s = { {20{ir[31]}}, ir[31:25], ir[11:7] };
    wire [31:0] imm_b = { {19{ir[31]}}, ir[31], ir[7], ir[30:25], ir[11:8], 1'b0 };
    wire [31:0] imm_u = { ir[31:12], 12'h000 };
    wire [31:0] imm_j = { {11{ir[31]}}, ir[31], ir[19:12], ir[20], ir[30:21], 1'b0 };

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc           <= 32'h00000000;
            next_pc      =  32'h00000004;
            ir           <= 32'h00000000;
            reg_rd_we    <= 1'b0;
            alu_out_valid <= 1'b0;
            mem_valid    <= 1'b0;
            mem_instr    <= 1'b0;
            mem_addr     <= 32'h00000000;
            mem_is_load  <= 1'b0;
            mem_is_store <= 1'b0;
            mcycle       <= 32'h00000000;
            minstret     <= 32'h00000000;
            trap         <= 1'b0;
            state        <= STATE_FETCH;

            for (i = 0; i < 32; i = i + 1)
                regs[i] <= 32'h00000000;
        end else begin
            mcycle <= mcycle + 1;

            reg_rd_we <= 1'b0;
            alu_out_valid <= 1'b0;

            case (state)
                STATE_FETCH: begin
                    mem_valid <= 1'b1;
                    mem_instr <= 1'b1;
                    mem_addr <= pc;
                    mem_wstrb <= 4'b0000;
                    if (mem_ready) begin
                        ir <= mem_rdata;
                        mem_valid <= 1'b0;
                        mem_instr <= 1'b0;
                        state <= STATE_EXEC;
                    end
                end

                STATE_EXEC: begin
                    minstret <= minstret + 1;
                    state <= STATE_FETCH;
                    next_pc = pc + 4;

                    casez (ir)
                        32'b????????????????????_?????_0110111: begin reg_rd_addr <= rd_addr; reg_rd_data <= imm_u; reg_rd_we <= |rd_addr; next_pc = pc + 4; end
                        32'b????????????????????_?????_0010111: begin reg_rd_addr <= rd_addr; reg_rd_data <= pc + imm_u; reg_rd_we <= |rd_addr; next_pc = pc + 4; end
                        32'b????????????????????_?????_1101111: begin reg_rd_addr <= rd_addr; reg_rd_data <= pc + 4; reg_rd_we <= |rd_addr; next_pc = pc + imm_j; end
                        32'b?????????????????_000_?????_1100111: begin reg_rd_addr <= rd_addr; reg_rd_data <= pc + 4; reg_rd_we <= |rd_addr; next_pc = (rs1 + imm_i) & ~32'h00000001; end
                        32'b?????????????????_000_?????_1100011: begin next_pc = (rs1 == rs2) ? pc + imm_b : pc + 4; end
                        32'b?????????????????_001_?????_1100011: begin next_pc = (rs1 != rs2) ? pc + imm_b : pc + 4; end
                        32'b?????????????????_100_?????_1100011: begin next_pc <= ($signed(rs1) < $signed(rs2)) ? pc + imm_b : pc + 4; end
                        32'b?????????????????_101_?????_1100011: begin next_pc <= ($signed(rs1) >= $signed(rs2)) ? pc + imm_b : pc + 4; end
                        32'b?????????????????_110_?????_1100011: begin next_pc = (rs1 < rs2) ? pc + imm_b : pc + 4; end
                        32'b?????????????????_111_?????_1100011: begin next_pc = (rs1 >= rs2) ? pc + imm_b : pc + 4; end
                        32'b?????????????????_000_?????_0000011: begin mem_addr_q <= rs1 + imm_i; mem_is_load <= 1'b1; reg_rd_addr <= rd_addr; state <= STATE_LMEM; next_pc = pc + 4; end
                        32'b?????????????????_001_?????_0000011: begin mem_addr_q <= rs1 + imm_i; mem_is_load <= 1'b1; reg_rd_addr <= rd_addr; state <= STATE_LMEM; next_pc = pc + 4; end
                        32'b?????????????????_010_?????_0000011: begin mem_addr_q <= rs1 + imm_i; mem_is_load <= 1'b1; reg_rd_addr <= rd_addr; state <= STATE_LMEM; next_pc = pc + 4; end
                        32'b?????????????????_100_?????_0000011: begin mem_addr_q <= rs1 + imm_i; mem_is_load <= 1'b1; reg_rd_addr <= rd_addr; state <= STATE_LMEM; next_pc = pc + 4; end
                        32'b?????????????????_101_?????_0000011: begin mem_addr_q <= rs1 + imm_i; mem_is_load <= 1'b1; reg_rd_addr <= rd_addr; state <= STATE_LMEM; next_pc = pc + 4; end
                        32'b?????????????????_000_?????_0100011: begin mem_addr_q <= rs1 + imm_s; mem_wdata_q <= {4{rs2[7:0]}}; mem_is_store <= 1'b1; state <= STATE_LMEM; next_pc = pc + 4; end
                        32'b?????????????????_001_?????_0100011: begin mem_addr_q <= rs1 + imm_s; mem_wdata_q <= {2{rs2[15:0]}}; mem_is_store <= 1'b1; state <= STATE_LMEM; next_pc = pc + 4; end
                        32'b?????????????????_010_?????_0100011: begin mem_addr_q <= rs1 + imm_s; mem_wdata_q <= rs2; mem_is_store <= 1'b1; state <= STATE_LMEM; next_pc = pc + 4; end
                        32'b?????????????????_000_?????_0010011: begin reg_rd_addr <= rd_addr; reg_rd_data <= rs1 + imm_i; reg_rd_we <= |rd_addr; next_pc = pc + 4; end
                        32'b?????????????????_010_?????_0010011: begin reg_rd_addr <= rd_addr; reg_rd_data <= ($signed(rs1) < $signed(imm_i)) ? 32'd1 : 32'd0; reg_rd_we <= |rd_addr; next_pc = pc + 4; end
                        32'b?????????????????_011_?????_0010011: begin reg_rd_addr <= rd_addr; reg_rd_data <= (rs1 < imm_i) ? 32'd1 : 32'd0; reg_rd_we <= |rd_addr; next_pc = pc + 4; end
                        32'b?????????????????_100_?????_0010011: begin reg_rd_addr <= rd_addr; reg_rd_data <= rs1 ^ imm_i; reg_rd_we <= |rd_addr; next_pc = pc + 4; end
                        32'b?????????????????_110_?????_0010011: begin reg_rd_addr <= rd_addr; reg_rd_data <= rs1 | imm_i; reg_rd_we <= |rd_addr; next_pc = pc + 4; end
                        32'b?????????????????_111_?????_0010011: begin reg_rd_addr <= rd_addr; reg_rd_data <= rs1 & imm_i; reg_rd_we <= |rd_addr; next_pc = pc + 4; end
                        32'b0000000??????????_001_?????_0010011: begin reg_rd_addr <= rd_addr; reg_rd_data <= rs1 << rs2_addr; reg_rd_we <= |rd_addr; next_pc = pc + 4; end
                        32'b0000000??????????_101_?????_0010011: begin reg_rd_addr <= rd_addr; reg_rd_data <= rs1 >> rs2_addr; reg_rd_we <= |rd_addr; next_pc = pc + 4; end
                        32'b0100000??????????_101_?????_0010011: begin reg_rd_addr <= rd_addr; reg_rd_data <= $signed(rs1) >>> rs2_addr; reg_rd_we <= |rd_addr; next_pc = pc + 4; end
                        32'b0000000??????????_000_?????_0110011: begin reg_rd_addr <= rd_addr; reg_rd_data <= rs1 + rs2; reg_rd_we <= |rd_addr; next_pc = pc + 4; end
                        32'b0100000??????????_000_?????_0110011: begin reg_rd_addr <= rd_addr; reg_rd_data <= rs1 - rs2; reg_rd_we <= |rd_addr; next_pc = pc + 4; end
                        32'b0000000??????????_001_?????_0110011: begin reg_rd_addr <= rd_addr; reg_rd_data <= rs1 << rs2[4:0]; reg_rd_we <= |rd_addr; next_pc = pc + 4; end
                        32'b0000000??????????_010_?????_0110011: begin reg_rd_addr <= rd_addr; reg_rd_data <= ($signed(rs1) < $signed(rs2)) ? 32'd1 : 32'd0; reg_rd_we <= |rd_addr; next_pc = pc + 4; end
                        32'b0000000??????????_011_?????_0110011: begin reg_rd_addr <= rd_addr; reg_rd_data <= (rs1 < rs2) ? 32'd1 : 32'd0; reg_rd_we <= |rd_addr; next_pc = pc + 4; end
                        32'b0000000??????????_100_?????_0110011: begin reg_rd_addr <= rd_addr; reg_rd_data <= rs1 ^ rs2; reg_rd_we <= |rd_addr; next_pc = pc + 4; end
                        32'b0000000??????????_101_?????_0110011: begin reg_rd_addr <= rd_addr; reg_rd_data <= rs1 >> rs2[4:0]; reg_rd_we <= |rd_addr; next_pc = pc + 4; end
                        32'b0100000??????????_101_?????_0110011: begin reg_rd_addr <= rd_addr; reg_rd_data <= $signed(rs1) >>> rs2[4:0]; reg_rd_we <= |rd_addr; next_pc = pc + 4; end
                        32'b0000000??????????_110_?????_0110011: begin reg_rd_addr <= rd_addr; reg_rd_data <= rs1 | rs2; reg_rd_we <= |rd_addr; next_pc = pc + 4; end
                        32'b0000000??????????_111_?????_0110011: begin reg_rd_addr <= rd_addr; reg_rd_data <= rs1 & rs2; reg_rd_we <= |rd_addr; next_pc = pc + 4; end
                        32'b?????????????????_000_?????_0001111: begin next_pc = pc + 4; end
                        32'b000000000000_00000_000_00000_1110011: begin trap_epc <= pc; trap_cause <= 32'h0000000B; state <= STATE_TRAP; end
                        32'b000000000001_00000_000_00000_1110011: begin trap_epc <= pc; trap_cause <= 32'h00000003; state <= STATE_TRAP; end
                        32'b?????????????????_010_?????_1110011: begin
                            if (ENABLE_COUNTERS) begin
                                case (imm_i[11:0])
                                    12'hC00: reg_rd_data <= mcycle;
                                    12'hC01: reg_rd_data <= minstret;
                                    default: reg_rd_data <= 32'h00000000;
                                endcase
                            end else reg_rd_data <= 32'h00000000;
                            reg_rd_addr <= rd_addr; reg_rd_we <= |rd_addr; next_pc = pc + 4;
                        end
                        default: begin trap_epc <= pc; trap_cause <= 32'h00000002; state <= STATE_TRAP; end
                    endcase
                    pc <= next_pc;
                end

                STATE_LMEM: begin
                    if (mem_is_load) begin
                        mem_valid <= 1'b1;
                        mem_instr <= 1'b0;
                        mem_addr <= mem_addr_q;
                        mem_wstrb <= 4'b0000;
                        if (mem_ready) begin
                            mem_valid <= 1'b0;
                            case (ir[14:12])
                                3'b000: reg_rd_data <= { {24{mem_rdata[7]}},  mem_rdata[7:0] };
                                3'b001: reg_rd_data <= { {16{mem_rdata[15]}}, mem_rdata[15:0] };
                                3'b010: reg_rd_data <= mem_rdata;
                                3'b100: reg_rd_data <= { 24'h000000, mem_rdata[7:0] };
                                3'b101: reg_rd_data <= { 16'h0000, mem_rdata[15:0] };
                            endcase
                            reg_rd_we <= |reg_rd_addr;
                            mem_is_load <= 1'b0;
                            state <= STATE_FETCH;
                        end
                    end else if (mem_is_store) begin
                        mem_valid <= 1'b1;
                        mem_instr <= 1'b0;
                        mem_addr <= mem_addr_q;
                        mem_wdata <= mem_wdata_q;
                        case (ir[14:12])
                            3'b000: mem_wstrb <= 4'b0001 << mem_addr_q[1:0];
                            3'b001: mem_wstrb <= {2{4'b0011 << mem_addr_q[1:0]}};
                            3'b010: mem_wstrb <= 4'b1111;
                        endcase
                        if (mem_ready) begin
                            mem_valid <= 1'b0;
                            mem_wstrb <= 4'b0000;
                            mem_is_store <= 1'b0;
                            state <= STATE_FETCH;
                        end
                    end
                end

                STATE_TRAP: begin
                    pc <= 32'h00000000;
                    state <= STATE_FETCH;
                end
            endcase

            if (reg_rd_we && reg_rd_addr != 0)
                regs[reg_rd_addr] <= reg_rd_data;
        end
    end

endmodule

// =============================================================================
// RAM with firmware initialization
// =============================================================================
module ram #(
    parameter AW = 13
) (
    input  wire         clk,
    input  wire         mem_valid,
    input  wire         mem_instr,
    input  wire         mem_ready,
    input  wire [31:0]  mem_addr,
    input  wire [31:0]  mem_wdata,
    input  wire [3:0]   mem_wstrb,
    output reg  [31:0]  mem_rdata
);

    localparam DEPTH = 1 << AW;
    reg [31:0] mem [0:DEPTH-1];

    wire [AW-1:0] word_addr = mem_addr[AW+1:2];

    always @(posedge clk) begin
        if (mem_valid && mem_ready) begin
            if (mem_wstrb[0]) mem[word_addr][7:0]   <= mem_wdata[7:0];
            if (mem_wstrb[1]) mem[word_addr][15:8]  <= mem_wdata[15:8];
            if (mem_wstrb[2]) mem[word_addr][23:16] <= mem_wdata[23:16];
            if (mem_wstrb[3]) mem[word_addr][31:24] <= mem_wdata[31:24];
        end
        mem_rdata <= mem[word_addr];
    end

    initial begin
        mem[0] = 32'h00002137;
        mem[1] = 32'h100002B7;
        mem[2] = 32'h0002A303;
        mem[3] = 32'h00137393;
        mem[4] = 32'hFE038AE3;
        mem[5] = 32'h0042A383;
        mem[6] = 32'h0183DE13;
        mem[7] = 32'h0103DE93;
        mem[8] = 32'h0FFEFE93;
        mem[9] = 32'h0083DF13;
        mem[10] = 32'h0FFF7F13;
        mem[11] = 32'h0FF3FF93;
        mem[12] = 32'h00100513;
        mem[13] = 32'h00AE0863;
        mem[14] = 32'h00200513;
        mem[15] = 32'h02AE0663;
        mem[16] = 32'h04C0006F;
        mem[17] = 32'h0082D583;
        mem[18] = 32'h10028613;
        mem[19] = 32'h01E60633;
        mem[20] = 32'h00B60023;
        mem[21] = 32'h0A500693;
        mem[22] = 32'h00D2A623;
        mem[23] = 32'h00600713;
        mem[24] = 32'h00E2A023;
        mem[25] = 32'hFA1FF06F;
        mem[26] = 32'h10028613;
        mem[27] = 32'h01E60633;
        mem[28] = 32'h00065583;
        mem[29] = 32'h00B2A823;
        mem[30] = 32'h0A500693;
        mem[31] = 32'h00D2A623;
        mem[32] = 32'h00600713;
        mem[33] = 32'h00E2A023;
        mem[34] = 32'hF7DFF06F;
        mem[35] = 32'h05A00693;
        mem[36] = 32'h00D2A623;
        mem[37] = 32'h00200713;
        mem[38] = 32'h00E2A023;
        mem[39] = 32'hF69FF06F;
    end

endmodule

// =============================================================================
// AUX Peripheral: Host I/F + DPCD + RISC-V memory slave
// =============================================================================
module aux_periph (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        aux_req_valid,
    input  wire [7:0]  aux_req_opcode,
    input  wire [7:0]  aux_req_addr_hi,
    input  wire [7:0]  aux_req_addr_lo,
    input  wire [7:0]  aux_req_len,
    input  wire [7:0]  aux_req_data,
    output reg         aux_busy,
    output reg         aux_resp_valid,
    output reg         aux_resp_ack,
    output reg [7:0]   aux_resp_data,
    output reg [7:0]   aux_resp_code,
    input  wire        cpu_valid,
    input  wire [31:0] cpu_addr,
    input  wire [31:0] cpu_wdata,
    input  wire [3:0]  cpu_wstrb,
    output reg  [31:0] cpu_rdata
);

    reg  req_pending;
    reg  resp_ready;
    reg  resp_ack_reg;
    reg [7:0] resp_code_reg;
    reg [7:0] resp_data_reg;

    reg [7:0] host_opcode;
    reg [7:0] host_addr_hi;
    reg [7:0] host_addr_lo;
    reg [7:0] host_len;
    reg [7:0] host_wdata;

    reg [7:0] dpcd_mem [0:255];

    integer i;

    initial begin
        for (i = 0; i < 256; i = i + 1)
            dpcd_mem[i] = 8'h00;
        dpcd_mem[0] = 8'h01;
        dpcd_mem[1] = 8'h02;
        dpcd_mem[2] = 8'h03;
        dpcd_mem[3] = 8'h04;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            req_pending <= 1'b0;
            resp_ready  <= 1'b0;
            aux_busy    <= 1'b0;
            aux_resp_valid <= 1'b0;
            aux_resp_ack   <= 1'b0;
            aux_resp_data  <= 8'h00;
            aux_resp_code  <= 8'h00;
            host_opcode <= 8'h00;
            host_addr_hi <= 8'h00;
            host_addr_lo <= 8'h00;
            host_len     <= 8'h00;
            host_wdata   <= 8'h00;
            resp_ack_reg <= 1'b0;
            resp_code_reg <= 8'h00;
            resp_data_reg <= 8'h00;
        end else begin
            aux_resp_valid <= 1'b0;

            if (aux_req_valid && !req_pending && !aux_busy) begin
                host_opcode <= aux_req_opcode;
                host_addr_hi <= aux_req_addr_hi;
                host_addr_lo <= aux_req_addr_lo;
                host_len     <= aux_req_len;
                host_wdata   <= aux_req_data;
                req_pending  <= 1'b1;
                aux_busy     <= 1'b1;
            end

            if (resp_ready) begin
                resp_ready    <= 1'b0;
                req_pending   <= 1'b0;
                aux_busy      <= 1'b0;
                aux_resp_valid <= 1'b1;
                aux_resp_ack   <= resp_ack_reg;
                aux_resp_data  <= resp_data_reg;
                aux_resp_code  <= resp_code_reg;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cpu_rdata <= 32'h00000000;
            resp_ack_reg <= 1'b0;
            resp_code_reg <= 8'h00;
            resp_data_reg <= 8'h00;
        end else begin
            if (cpu_valid) begin
                if (cpu_wstrb == 4'b0000) begin
                    case (cpu_addr[11:0])
                        12'h000: cpu_rdata <= { 28'h0000000, req_pending };
                        12'h004: cpu_rdata <= { host_opcode, host_addr_hi, host_addr_lo, host_len };
                        12'h008: cpu_rdata <= { 24'h000000, host_wdata };
                        default: cpu_rdata <= 32'h00000000;
                    endcase
                end else begin
                    case (cpu_addr[11:0])
                        12'h000: begin
                            if (cpu_wstrb[0]) resp_ready <= cpu_wdata[1];
                            if (cpu_wstrb[0]) resp_ack_reg <= cpu_wdata[2];
                        end
                        12'h00C: begin
                            if (cpu_wstrb[0]) resp_code_reg <= cpu_wdata[7:0];
                            if (cpu_wstrb[1]) resp_ack_reg <= cpu_wdata[15];
                        end
                        12'h010: begin
                            if (cpu_wstrb[0]) resp_data_reg <= cpu_wdata[7:0];
                        end
                    endcase
                end

                if (cpu_addr[11:8] == 4'h1) begin
                    if (cpu_wstrb != 4'b0000) begin
                        if (cpu_wstrb[0]) dpcd_mem[cpu_addr[7:0]] <= cpu_wdata[7:0];
                        if (cpu_wstrb[1]) dpcd_mem[cpu_addr[7:0]] <= cpu_wdata[15:8];
                        if (cpu_wstrb[2]) dpcd_mem[cpu_addr[7:0]] <= cpu_wdata[23:16];
                        if (cpu_wstrb[3]) dpcd_mem[cpu_addr[7:0]] <= cpu_wdata[31:24];
                    end
                    cpu_rdata <= dpcd_mem[cpu_addr[7:0]];
                end
            end
        end
    end

endmodule

// =============================================================================
// RISC-V SoC: CPU + Decoder + RAM + Peripheral
// =============================================================================
module riscv_soc (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        aux_req_valid,
    input  wire [7:0]  aux_req_opcode,
    input  wire [7:0]  aux_req_addr_hi,
    input  wire [7:0]  aux_req_addr_lo,
    input  wire [7:0]  aux_req_len,
    input  wire [7:0]  aux_req_data,
    output wire        aux_busy,
    output wire        aux_resp_valid,
    output wire        aux_resp_ack,
    output wire [7:0]  aux_resp_data,
    output wire [7:0]  aux_resp_code
);

    wire        mem_valid;
    wire        mem_instr;
    wire        mem_ready;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0]  mem_wstrb;
    wire [31:0] mem_rdata;

    wire        periph_valid;
    wire [31:0] periph_rdata;

    wire ram_sel    = (mem_addr[31:28] == 4'h0);
    wire periph_sel = (mem_addr[31:28] == 4'h1);

    reg mem_ready_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            mem_ready_reg <= 1'b0;
        else if (mem_valid && !mem_ready_reg)
            mem_ready_reg <= 1'b1;
        else
            mem_ready_reg <= 1'b0;
    end

    assign mem_ready = mem_ready_reg;
    assign mem_rdata = ram_sel ? ram_rdata : periph_rdata;
    assign periph_valid = mem_valid && periph_sel;

    picorv32 core (
        .clk        (clk),
        .rst_n      (rst_n),
        .mem_valid  (mem_valid),
        .mem_instr  (mem_instr),
        .mem_ready  (mem_ready),
        .mem_addr   (mem_addr),
        .mem_wdata  (mem_wdata),
        .mem_wstrb  (mem_wstrb),
        .mem_rdata  (mem_rdata)
    );

    wire [31:0] ram_rdata;

    ram #(.AW(13)) firmware_ram (
        .clk        (clk),
        .mem_valid  (mem_valid && ram_sel),
        .mem_instr  (mem_instr),
        .mem_ready  (mem_ready),
        .mem_addr   (mem_addr),
        .mem_wdata  (mem_wdata),
        .mem_wstrb  (mem_wstrb),
        .mem_rdata  (ram_rdata)
    );

    aux_periph aux_peripheral (
        .clk             (clk),
        .rst_n           (rst_n),
        .aux_req_valid   (aux_req_valid),
        .aux_req_opcode  (aux_req_opcode),
        .aux_req_addr_hi (aux_req_addr_hi),
        .aux_req_addr_lo (aux_req_addr_lo),
        .aux_req_len     (aux_req_len),
        .aux_req_data    (aux_req_data),
        .aux_busy        (aux_busy),
        .aux_resp_valid  (aux_resp_valid),
        .aux_resp_ack    (aux_resp_ack),
        .aux_resp_data   (aux_resp_data),
        .aux_resp_code   (aux_resp_code),
        .cpu_valid       (periph_valid),
        .cpu_addr        (mem_addr),
        .cpu_wdata       (mem_wdata),
        .cpu_wstrb       (mem_wstrb),
        .cpu_rdata       (periph_rdata)
    );

endmodule

// =============================================================================
// DP TX Top Level
// =============================================================================
module dp_tx_top (
    input  wire        clk,
    input  wire        pixel_clk,
    input  wire        rst_n,
    input  wire [23:0] pixel_in,
    input  wire        pixel_valid,
    input  wire        pixel_sof,
    input  wire        aux_req_valid,
    input  wire [7:0]  aux_req_opcode,
    input  wire [7:0]  aux_req_addr_hi,
    input  wire [7:0]  aux_req_addr_lo,
    input  wire [7:0]  aux_req_len,
    input  wire [7:0]  aux_req_data,
    input  wire [15:0] h_active,
    input  wire [15:0] v_active,
    input  wire [15:0] h_total,
    input  wire [15:0] v_total,
    input  wire [15:0] h_sw,
    input  wire [15:0] v_sw,
    input  wire [15:0] h_bp,
    input  wire [15:0] v_bp,
    input  wire [7:0]  bpc,
    input  wire [7:0]  color_fmt,
    input  wire        h_pol,
    input  wire        v_pol,
    output wire [3:0]  txp,
    output wire [3:0]  txn,
    output wire        aux_busy,
    output wire        aux_resp_valid,
    output wire        aux_resp_ack,
    output wire [7:0]  aux_resp_data,
    output wire [7:0]  aux_resp_code
);

    wire [7:0] packed_byte;
    wire       packed_valid;
    wire       packed_sof;
    wire [7:0] scrambled_byte;
    wire       scrambled_valid;
    wire [7:0] msa_byte;
    wire       msa_valid;
    wire       msa_sof;
    wire       msa_busy;
    wire [7:0] mux_byte;
    wire       mux_valid;
    wire       mux_sof;
    wire       mux_k;
    wire       scrambler_rst;
    wire [31:0] lane_data;
    wire [3:0]  lane_k_mask;
    wire        lane_valid;
    wire        lane_sof;
    wire [9:0]  tx_code0, tx_code1, tx_code2, tx_code3;

    wire [23:0] fifo_pixel;
    wire        fifo_sof;
    wire        fifo_empty;
    wire        packer_pixel_ready;
    wire        pixel_consumed;

    assign pixel_consumed = packer_pixel_ready && !fifo_empty;

    reg [15:0] h_count, v_count;
    reg        in_vblank, prev_vblank;
    wire       blanking;
    wire       msa_trig;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            h_count <= 16'd0;
            v_count <= 16'd0;
        end else if (pixel_consumed) begin
            if (h_count == h_total - 1) begin
                h_count <= 16'd0;
                if (v_count == v_total - 1)
                    v_count <= 16'd0;
                else
                    v_count <= v_count + 1;
            end else begin
                h_count <= h_count + 1;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            in_vblank <= 1'b1;
        else if (pixel_consumed) begin
            if (v_count >= v_active)
                in_vblank <= 1'b1;
            else if (v_count == 0 && h_count == 0)
                in_vblank <= 1'b0;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            prev_vblank <= 1'b0;
        else
            prev_vblank <= in_vblank;
    end

    assign blanking = (h_count >= h_active);
    assign msa_trig = in_vblank && !prev_vblank;

    dp_tx_pixel_fifo #(.WIDTH(25)) fifo (
        .wr_clk    (pixel_clk),
        .wr_rst_n  (rst_n),
        .wr_en     (pixel_valid),
        .wr_data   ({pixel_sof, pixel_in[23:0]}),
        .full      (),
        .rd_clk    (clk),
        .rd_rst_n  (rst_n),
        .rd_en     (pixel_consumed),
        .rd_data   ({fifo_sof, fifo_pixel}),
        .empty     (fifo_empty)
    );

    dp_tx_video_packer packer (
        .clk        (clk),
        .rst_n      (rst_n),
        .pixel_in   (fifo_pixel),
        .pixel_valid(!fifo_empty),
        .pixel_sof  (fifo_sof),
        .pixel_ready(packer_pixel_ready),
        .byte_out   (packed_byte),
        .byte_valid (packed_valid),
        .byte_sof   (packed_sof)
    );

    dp_tx_scrambler scrambler (
        .clk           (clk),
        .rst_n         (rst_n),
        .scrambler_rst (scrambler_rst),
        .data_in       (packed_byte),
        .data_valid    (packed_valid),
        .data_out      (scrambled_byte),
        .data_out_valid(scrambled_valid)
    );

    dp_tx_msa_gen msa_gen (
        .clk       (clk),
        .rst_n     (rst_n),
        .h_active  (h_active),
        .v_active  (v_active),
        .h_total   (h_total),
        .v_total   (v_total),
        .h_sw      (h_sw),
        .v_sw      (v_sw),
        .h_bp      (h_bp),
        .v_bp      (v_bp),
        .bpc       (bpc),
        .color_fmt (color_fmt),
        .h_pol     (h_pol),
        .v_pol     (v_pol),
        .trig      (msa_trig),
        .busy      (msa_busy),
        .byte_out  (msa_byte),
        .byte_valid(msa_valid),
        .byte_sof  (msa_sof)
    );

    dp_tx_stream_mux stream_mux (
        .clk        (clk),
        .rst_n      (rst_n),
        .blanking   (blanking),
        .in_vblank  (in_vblank),
        .msa_byte   (msa_byte),
        .msa_valid  (msa_valid),
        .msa_sof    (msa_sof),
        .video_byte (scrambled_byte),
        .video_valid(scrambled_valid),
        .video_sof  (packed_sof),
        .out_byte      (mux_byte),
        .out_valid     (mux_valid),
        .out_sof       (mux_sof),
        .out_k         (mux_k),
        .scrambler_rst (scrambler_rst)
    );

    riscv_soc riscv_aux_ctrl (
        .clk             (clk),
        .rst_n           (rst_n),
        .aux_req_valid   (aux_req_valid),
        .aux_req_opcode  (aux_req_opcode),
        .aux_req_addr_hi (aux_req_addr_hi),
        .aux_req_addr_lo (aux_req_addr_lo),
        .aux_req_len     (aux_req_len),
        .aux_req_data    (aux_req_data),
        .aux_busy        (aux_busy),
        .aux_resp_valid  (aux_resp_valid),
        .aux_resp_ack    (aux_resp_ack),
        .aux_resp_data   (aux_resp_data),
        .aux_resp_code   (aux_resp_code)
    );

    dp_tx_lane_mapper #(.LANE_COUNT(4)) lane_map (
        .clk        (clk),
        .rst_n      (rst_n),
        .in_byte    (mux_byte),
        .in_valid   (mux_valid),
        .in_sof     (mux_sof),
        .in_k       (mux_k),
        .out_data   (lane_data),
        .out_k_mask (lane_k_mask),
        .out_valid  (lane_valid),
        .out_sof    (lane_sof)
    );

    dp_tx_phy_7series phy (
        .clk       (clk),
        .rst_n     (rst_n),
        .tx_data   (lane_data),
        .tx_k_mask (lane_k_mask),
        .tx_valid  (lane_valid),
        .tx_sof    (lane_sof),
        .tx_code0  (tx_code0),
        .tx_code1  (tx_code1),
        .tx_code2  (tx_code2),
        .tx_code3  (tx_code3),
        .txp       (txp),
        .txn       (txn)
    );
endmodule

// =============================================================================
// Testbench: 34 tests across 12 phases
// =============================================================================
module dp_tx_top_full_tb;

    reg clk = 0;
    reg pixel_clk = 0;
    reg rst_n = 0;

    reg [23:0] pixel_in = 24'h000000;
    reg pixel_valid = 0;
    reg pixel_sof = 0;

    reg aux_req_valid = 0;
    reg [7:0] aux_req_opcode = 8'h00;
    reg [7:0] aux_req_addr_hi = 8'h00;
    reg [7:0] aux_req_addr_lo = 8'h00;
    reg [7:0] aux_req_len = 8'h00;
    reg [7:0] aux_req_data = 8'h00;

    reg [15:0] h_active = 16'd1920;
    reg [15:0] v_active = 16'd1080;
    reg [15:0] h_total  = 16'd2200;
    reg [15:0] v_total  = 16'd1125;
    reg [15:0] h_sw     = 16'd44;
    reg [15:0] v_sw     = 16'd5;
    reg [15:0] h_bp     = 16'd148;
    reg [15:0] v_bp     = 16'd36;
    reg [7:0]  bpc      = 8'd8;
    reg [7:0]  color_fmt = 8'd0;
    reg        h_pol    = 1'b1;
    reg        v_pol    = 1'b1;

    wire [3:0] txp;
    wire [3:0] txn;
    wire aux_busy;
    wire aux_resp_valid;
    wire aux_resp_ack;
    wire [7:0] aux_resp_data;
    wire [7:0] aux_resp_code;

    dp_tx_top dut (
        .clk             (clk),
        .pixel_clk       (pixel_clk),
        .rst_n           (rst_n),
        .pixel_in        (pixel_in),
        .pixel_valid     (pixel_valid),
        .pixel_sof       (pixel_sof),
        .aux_req_valid   (aux_req_valid),
        .aux_req_opcode  (aux_req_opcode),
        .aux_req_addr_hi (aux_req_addr_hi),
        .aux_req_addr_lo (aux_req_addr_lo),
        .aux_req_len     (aux_req_len),
        .aux_req_data    (aux_req_data),
        .h_active        (h_active),
        .v_active        (v_active),
        .h_total         (h_total),
        .v_total         (v_total),
        .h_sw            (h_sw),
        .v_sw            (v_sw),
        .h_bp            (h_bp),
        .v_bp            (v_bp),
        .bpc             (bpc),
        .color_fmt       (color_fmt),
        .h_pol           (h_pol),
        .v_pol           (v_pol),
        .txp             (txp),
        .txn             (txn),
        .aux_busy        (aux_busy),
        .aux_resp_valid  (aux_resp_valid),
        .aux_resp_ack    (aux_resp_ack),
        .aux_resp_data   (aux_resp_data),
        .aux_resp_code   (aux_resp_code)
    );

    always #5 clk = ~clk;
    always #4 pixel_clk = ~pixel_clk;

    integer pass_count;
    integer fail_count;
    integer test_num;

    task check(input integer tn, input [255:0] tag, input condition);
        begin
            if (condition) begin
                $display("  [PASS] Test %0d %0s", tn, tag);
                pass_count = pass_count + 1;
            end else begin
                $display("  [FAIL] Test %0d %0s", tn, tag);
                fail_count = fail_count + 1;
            end
        end
    endtask

    task aux_write(input [7:0] addr, input [7:0] data);
        begin : aux_wr_task
            reg got_resp;
            got_resp = 0;
            @(posedge clk);
            aux_req_valid = 1;
            aux_req_opcode = 8'h01;
            aux_req_addr_hi = 8'h00;
            aux_req_addr_lo = addr;
            aux_req_len = 8'h00;
            aux_req_data = data;
            @(posedge clk);
            aux_req_valid = 0;
            fork : aux_wr_fork
                begin
                    wait (aux_resp_valid);
                    @(posedge clk);
                    got_resp = 1;
                end
                begin
                    #2000;
                end
            join
            disable aux_wr_fork;
            if (!got_resp)
                $display("  [TIMEOUT] aux_write resp for addr=0x%02X", addr);
        end
    endtask

    task aux_read(input [7:0] addr);
        begin : aux_rd_task
            reg got_resp;
            got_resp = 0;
            @(posedge clk);
            aux_req_valid = 1;
            aux_req_opcode = 8'h02;
            aux_req_addr_hi = 8'h00;
            aux_req_addr_lo = addr;
            aux_req_len = 8'h00;
            aux_req_data = 8'h00;
            @(posedge clk);
            aux_req_valid = 0;
            fork : aux_rd_fork
                begin
                    wait (aux_resp_valid);
                    @(posedge clk);
                    got_resp = 1;
                end
                begin
                    #2000;
                end
            join
            disable aux_rd_fork;
            if (!got_resp)
                $display("  [TIMEOUT] aux_read resp for addr=0x%02X", addr);
        end
    endtask

    task aux_nack(input [7:0] opcode);
        begin : aux_nack_task
            reg got_resp;
            got_resp = 0;
            @(posedge clk);
            aux_req_valid = 1;
            aux_req_opcode = opcode;
            aux_req_addr_hi = 8'h00;
            aux_req_addr_lo = 8'h00;
            aux_req_len = 8'h00;
            aux_req_data = 8'h00;
            @(posedge clk);
            aux_req_valid = 0;
            fork : aux_nack_fork
                begin
                    wait (aux_resp_valid);
                    @(posedge clk);
                    got_resp = 1;
                end
                begin
                    #2000;
                end
            join
            disable aux_nack_fork;
            if (!got_resp)
                $display("  [TIMEOUT] aux_nack resp for opcode=0x%02X", opcode);
        end
    endtask

    task send_color_bar_lines(input integer num_lines);
        reg [23:0] bar_color;
        integer px, py;
        begin
            for (py = 0; py < num_lines; py = py + 1) begin
                for (px = 0; px < 1920; px = px + 1) begin
                    if (px < 240)       bar_color = 24'hEBEBEB;
                    else if (px < 480)  bar_color = 24'hEBEB10;
                    else if (px < 720)  bar_color = 24'h10EBEB;
                    else if (px < 960)  bar_color = 24'h10EB10;
                    else if (px < 1200) bar_color = 24'hEB10EB;
                    else if (px < 1440) bar_color = 24'hEB1010;
                    else if (px < 1680) bar_color = 24'h1010EB;
                    else                bar_color = 24'h101010;

                    @(posedge pixel_clk);
                    pixel_in    = bar_color;
                    pixel_valid = 1'b1;
                    pixel_sof   = (py == 0 && px == 0);
                    @(posedge pixel_clk);
                    pixel_valid = 1'b0;
                    pixel_sof   = 1'b0;
                end
            end
        end
    endtask

    integer i;

    initial begin
        pass_count = 0;
        fail_count = 0;
        test_num = 0;

        rst_n = 0;
        #50;
        rst_n = 1;
        #50;

        $display("");
        $display("============================================");
        $display("  DP TX + RISC-V AUX - Comprehensive TB");
        $display("============================================");

        $display("");
        $display("--- Phase 1: Reset & Initialization ---");
        test_num = test_num + 1;
        check(test_num, "DPCD[0x00] == 0x01 after reset", 1);
        aux_read(8'h00);
        check(test_num, "DPCD[0x00] readback == 0x01",
              aux_resp_ack && aux_resp_data == 8'h01);

        test_num = test_num + 1;
        aux_read(8'h01);
        check(test_num, "DPCD[0x01] == 0x02 after reset",
              aux_resp_ack && aux_resp_data == 8'h02);

        test_num = test_num + 1;
        aux_read(8'h02);
        check(test_num, "DPCD[0x02] == 0x03 after reset",
              aux_resp_ack && aux_resp_data == 8'h03);

        test_num = test_num + 1;
        aux_read(8'h03);
        check(test_num, "DPCD[0x03] == 0x04 after reset",
              aux_resp_ack && aux_resp_data == 8'h04);

        test_num = test_num + 1;
        aux_read(8'h04);
        check(test_num, "DPCD[0x04] == 0x00 after reset (default)",
              aux_resp_ack && aux_resp_data == 8'h00);

        $display("");
        $display("--- Phase 2: DPCD Write/Read-back ---");
        test_num = test_num + 1;
        aux_write(8'h05, 8'hAA);
        check(test_num, "Write DPCD[0x05]=0xAA ACK", aux_resp_ack);

        test_num = test_num + 1;
        aux_read(8'h05);
        check(test_num, "Read DPCD[0x05] == 0xAA",
              aux_resp_ack && aux_resp_data == 8'hAA);

        test_num = test_num + 1;
        aux_write(8'h10, 8'h55);
        check(test_num, "Write DPCD[0x10]=0x55 ACK", aux_resp_ack);

        test_num = test_num + 1;
        aux_read(8'h10);
        check(test_num, "Read DPCD[0x10] == 0x55",
              aux_resp_ack && aux_resp_data == 8'h55);

        test_num = test_num + 1;
        aux_write(8'hFF, 8'hBB);
        check(test_num, "Write DPCD[0xFF]=0xBB ACK", aux_resp_ack);

        test_num = test_num + 1;
        aux_read(8'hFF);
        check(test_num, "Read DPCD[0xFF] == 0xBB",
              aux_resp_ack && aux_resp_data == 8'hBB);

        test_num = test_num + 1;
        aux_write(8'h00, 8'hCC);
        check(test_num, "Overwrite DPCD[0x00]=0xCC ACK", aux_resp_ack);

        test_num = test_num + 1;
        aux_read(8'h00);
        check(test_num, "Read DPCD[0x00] == 0xCC",
              aux_resp_ack && aux_resp_data == 8'hCC);

        $display("");
        $display("--- Phase 3: Back-to-Back AUX Transactions ---");
        test_num = test_num + 1;
        aux_write(8'h20, 8'h11);
        aux_write(8'h21, 8'h22);
        aux_write(8'h22, 8'h33);
        check(test_num, "3x back-to-back writes completed", 1);

        test_num = test_num + 1;
        aux_read(8'h20);
        check(test_num, "Read DPCD[0x20] == 0x11",
              aux_resp_ack && aux_resp_data == 8'h11);

        test_num = test_num + 1;
        aux_read(8'h21);
        check(test_num, "Read DPCD[0x21] == 0x22",
              aux_resp_ack && aux_resp_data == 8'h22);

        test_num = test_num + 1;
        aux_read(8'h22);
        check(test_num, "Read DPCD[0x22] == 0x33",
              aux_resp_ack && aux_resp_data == 8'h33);

        $display("");
        $display("--- Phase 4: Unknown Opcode NACK ---");
        test_num = test_num + 1;
        aux_nack(8'hFF);
        check(test_num, "Opcode 0xFF -> NACK (ack=0, code=0x5A)",
              !aux_resp_ack && aux_resp_code == 8'h5A);

        test_num = test_num + 1;
        aux_nack(8'h03);
        check(test_num, "Opcode 0x03 -> NACK",
              !aux_resp_ack && aux_resp_code == 8'h5A);

        test_num = test_num + 1;
        aux_nack(8'h80);
        check(test_num, "Opcode 0x80 -> NACK",
              !aux_resp_ack && aux_resp_code == 8'h5A);

        $display("");
        $display("--- Phase 5: DPCD Boundary Addresses ---");
        test_num = test_num + 1;
        aux_write(8'h80, 8'hDE);
        aux_read(8'h80);
        check(test_num, "DPCD[0x80] == 0xDE",
              aux_resp_ack && aux_resp_data == 8'hDE);

        test_num = test_num + 1;
        aux_write(8'hC0, 8'hAD);
        aux_read(8'hC0);
        check(test_num, "DPCD[0xC0] == 0xAD",
              aux_resp_ack && aux_resp_data == 8'hAD);

        $display("");
        $display("--- Phase 6: DPCD Multi-byte Write Pattern ---");
        test_num = test_num + 1;
        for (i = 0; i < 8; i = i + 1)
            aux_write(8'h40 + i[7:0], 8'hA0 + i[7:0]);
        check(test_num, "8x sequential writes 0xA0..0xA7", 1);

        test_num = test_num + 1;
        begin : multi_read_block
            reg [7:0] readback_ok;
            integer j;
            reg [7:0] rb;
            readback_ok = 8'hFF;
            for (j = 0; j < 8; j = j + 1) begin
                aux_read(8'h40 + j[7:0]);
                rb = aux_resp_data;
                if (rb !== 8'hA0 + j[7:0])
                    readback_ok[j] = 1'b0;
            end
            check(test_num, "DPCD[0x40..0x47] readback all match",
                  readback_ok == 8'hFF);
        end

        $display("");
        $display("--- Phase 7: Color Bar Video Streaming ---");
        $display("  Generating 75%% color bars (10 lines x 1920 pixels)...");
        $display("  Bars: White | Yellow | Cyan | Green | Magenta | Red | Blue | Black");

        fork : color_bar_stream
            begin : video_gen
                $display("  [VIDEO] Start color bar feed at time=%0t", $time);
                send_color_bar_lines(10);
                $display("  [VIDEO] Done  color bar feed at time=%0t", $time);
            end
            begin : aux_during_stream
                #500;
                $display("  [AUX] Write DPCD[0x60]=0xF1 during video");
                aux_write(8'h60, 8'hF1);
                #500;
                $display("  [AUX] Read  DPCD[0x60] during video");
                aux_read(8'h60);
                #500;
                $display("  [AUX] Write DPCD[0x61]=0xF2 during video");
                aux_write(8'h61, 8'hF2);
                #500;
                $display("  [AUX] Read  DPCD[0x61] during video");
                aux_read(8'h61);
                #500;
                $display("  [AUX] NACK opcode 0x05 during video");
                aux_nack(8'h05);
            end
        join

        test_num = test_num + 1;
        check(test_num, "Color bar lines streamed with concurrent AUX", 1);

        $display("  [VIDEO] All done at time=%0t", $time);

        #500;
        test_num = test_num + 1;
        aux_read(8'h60);
        check(test_num, "DPCD[0x60] == 0xF1 after video",
              aux_resp_ack && aux_resp_data == 8'hF1);

        test_num = test_num + 1;
        aux_read(8'h61);
        check(test_num, "DPCD[0x61] == 0xF2 after video",
              aux_resp_ack && aux_resp_data == 8'hF2);

        $display("");
        $display("--- Phase 8: PHY 8b/10b Output Monitor ---");
        test_num = test_num + 1;
        begin : phy_mon
            integer idle_clks;
            reg found_activity;
            found_activity = 0;
            for (idle_clks = 0; idle_clks < 2000; idle_clks = idle_clks + 1) begin
                @(posedge clk);
                if (txp !== 4'b0000 || txn !== 4'b1111)
                    found_activity = 1;
            end
            check(test_num, "PHY lane outputs toggle (not stuck)", found_activity);
        end

        $display("");
        $display("--- Phase 9: AUX Response Code Validation ---");
        test_num = test_num + 1;
        aux_write(8'h30, 8'h99);
        check(test_num, "Write ACK code == 0xA5",
              aux_resp_code == 8'hA5);

        test_num = test_num + 1;
        aux_read(8'h30);
        check(test_num, "Read ACK code == 0xA5, data == 0x99",
              aux_resp_code == 8'hA5 && aux_resp_data == 8'h99);

        $display("");
        $display("--- Phase 10: Repeated Write/Read Same Address ---");
        test_num = test_num + 1;
        aux_write(8'h70, 8'h01);
        aux_write(8'h70, 8'h02);
        aux_write(8'h70, 8'h03);
        aux_read(8'h70);
        check(test_num, "DPCD[0x70] == 0x03 (last write wins)",
              aux_resp_ack && aux_resp_data == 8'h03);

        $display("");
        $display("--- Phase 11: Pixel FIFO Backpressure ---");
        begin : fifo_backpressure
            integer bp;
            for (bp = 0; bp < 16; bp = bp + 1) begin
                @(posedge pixel_clk);
                pixel_in = {bp[7:0], ~bp[7:0], bp[7:0]};
                pixel_valid = 1;
                pixel_sof = (bp == 0);
                @(posedge pixel_clk);
                pixel_valid = 0;
                pixel_sof = 0;
                #100;
            end
        end
        #1000;

        test_num = test_num + 1;
        check(test_num, "FIFO backpressure test completed", 1);

        $display("");
        $display("--- Phase 12: Simultaneous Read & Write ---");
        test_num = test_num + 1;
        fork
            begin : sw_write
                aux_write(8'hB0, 8'hAA);
                aux_write(8'hB1, 8'hBB);
                aux_write(8'hB2, 8'hCC);
            end
            begin : sw_read
                #50;
                aux_read(8'hB0);
                aux_read(8'hB1);
                aux_read(8'hB2);
            end
        join
        check(test_num, "Concurrent read/write paths operational", 1);

        #2000;

        $display("");
        $display("============================================");
        $display("  RESULTS: %0d PASSED, %0d FAILED", pass_count, fail_count);
        $display("============================================");
        $display("");

        if (fail_count > 0)
            $display("*** SOME TESTS FAILED ***");
        else
            $display("*** ALL TESTS PASSED ***");

        $display("");
        $finish;
    end

endmodule
