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
