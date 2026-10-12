module riscv_soc (
    input  wire        clk,
    input  wire        rst_n,

    // Host AUX interface (DP 1.2 native AUX)
    input  wire        aux_req_valid,
    input  wire [1:0]  aux_req_type,
    input  wire [19:0] aux_req_addr,
    input  wire [7:0]  aux_req_len,
    input  wire [7:0]  aux_req_data,
    input  wire        aux_req_data_valid,
    input  wire        aux_req_last,
    output wire        aux_busy,
    output wire        aux_resp_valid,
    output wire [1:0]  aux_resp_reply,
    output wire [7:0]  aux_resp_data,
    output wire        aux_resp_last,

    // AUX PHY interface
    output wire        phy_tx_start,
    output wire [1:0]  phy_tx_type,
    output wire [19:0] phy_tx_addr,
    output wire [7:0]  phy_tx_len,
    output wire [7:0]  phy_tx_data,
    output wire        phy_tx_data_valid,
    output wire        phy_tx_last,
    input  wire        phy_tx_ready,
    input  wire        phy_tx_done,
    input  wire        phy_rx_valid,
    input  wire [1:0]  phy_rx_reply,
    input  wire [7:0]  phy_rx_data,
    input  wire        phy_rx_last,
    input  wire        phy_rx_err
);

    // PicoRV32 memory interface
    wire        mem_valid;
    wire        mem_instr;
    wire        mem_ready;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0]  mem_wstrb;
    wire [31:0] mem_rdata;

    // Peripheral interface
    wire        periph_valid;
    wire [31:0] periph_rdata;
    wire [31:0] ram_rdata;

    // Address decoding
    wire ram_sel    = (mem_addr[31:13] == 19'h0);     // 8KB @ 0x0000_0000
    wire periph_sel = (mem_addr[31:12] == 20'h10000); // 4KB @ 0x1000_0000

    // Memory ready: one cycle for RAM, one cycle for peripherals
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

    // Read data mux
    assign mem_rdata = ram_sel ? ram_rdata : periph_rdata;

    // Peripheral valid
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

    ram #(
        .AW(13)
    ) firmware_ram (
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
        .clk                  (clk),
        .rst_n                (rst_n),
        .aux_req_valid        (aux_req_valid),
        .aux_req_type         (aux_req_type),
        .aux_req_addr         (aux_req_addr),
        .aux_req_len          (aux_req_len),
        .aux_req_data         (aux_req_data),
        .aux_req_data_valid   (aux_req_data_valid),
        .aux_req_last         (aux_req_last),
        .aux_busy             (aux_busy),
        .aux_resp_valid       (aux_resp_valid),
        .aux_resp_reply       (aux_resp_reply),
        .aux_resp_data        (aux_resp_data),
        .aux_resp_last        (aux_resp_last),
        .cpu_valid            (periph_valid),
        .cpu_addr             (mem_addr),
        .cpu_wdata            (mem_wdata),
        .cpu_wstrb            (mem_wstrb),
        .cpu_rdata            (periph_rdata),
        // PHY interface
        .phy_tx_start         (phy_tx_start),
        .phy_tx_type          (phy_tx_type),
        .phy_tx_addr          (phy_tx_addr),
        .phy_tx_len           (phy_tx_len),
        .phy_tx_data          (phy_tx_data),
        .phy_tx_data_valid    (phy_tx_data_valid),
        .phy_tx_last          (phy_tx_last),
        .phy_tx_ready         (phy_tx_ready),
        .phy_tx_done          (phy_tx_done),
        .phy_rx_valid         (phy_rx_valid),
        .phy_rx_reply         (phy_rx_reply),
        .phy_rx_data          (phy_rx_data),
        .phy_rx_last          (phy_rx_last),
        .phy_rx_err           (phy_rx_err)
    );

endmodule