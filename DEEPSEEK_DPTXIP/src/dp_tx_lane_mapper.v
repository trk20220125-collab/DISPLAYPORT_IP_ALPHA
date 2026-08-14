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
