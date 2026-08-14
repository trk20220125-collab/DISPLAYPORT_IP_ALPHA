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
