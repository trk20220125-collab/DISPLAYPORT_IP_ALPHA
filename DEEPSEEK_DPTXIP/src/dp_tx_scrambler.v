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
                t = {t[14:0], t[15] ^ t[13] ^ t[12] ^ t[10]};
            lfsr_next = t;
        end
    endfunction

endmodule
