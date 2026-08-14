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
        if (mem_valid)
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
