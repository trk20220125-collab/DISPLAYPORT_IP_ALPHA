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
