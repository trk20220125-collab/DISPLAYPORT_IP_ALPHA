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
