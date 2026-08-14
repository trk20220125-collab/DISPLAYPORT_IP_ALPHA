module aux_periph (
    input  wire        clk,
    input  wire        rst_n,

    // Host AUX interface (same as original aux_ctrl)
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

    // RISC-V memory slave interface
    input  wire        cpu_valid,
    input  wire [31:0] cpu_addr,
    input  wire [31:0] cpu_wdata,
    input  wire [3:0]  cpu_wstrb,
    output reg  [31:0] cpu_rdata,

    // AUX PHY interface
    output reg         phy_tx_start,
    output reg  [7:0]  phy_tx_data,
    output reg         phy_tx_last,
    input  wire        phy_tx_ready,
    input  wire        phy_tx_done,
    input  wire        phy_rx_valid,
    input  wire [7:0]  phy_rx_data,
    input  wire        phy_rx_last,
    input  wire        phy_rx_err
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

    // DPCD memory initialization
    initial begin
        for (i = 0; i < 256; i = i + 1)
            dpcd_mem[i] = 8'h00;
        dpcd_mem[0] = 8'h01;
        dpcd_mem[1] = 8'h02;
        dpcd_mem[2] = 8'h03;
        dpcd_mem[3] = 8'h04;
    end

    // Host request capture
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

    // synthesis translate_off
    `ifndef SIM_QUIET
    always @(posedge clk) begin
        if (cpu_valid && cpu_wstrb == 4'b0000 && cpu_addr >= 32'h10000100 && cpu_addr < 32'h10000200)
            $display("DPCD READ  addr=0x%08X data=0x%02X", cpu_addr, dpcd_mem[cpu_addr[7:0]]);
        if (cpu_valid && cpu_wstrb != 4'b0000 && cpu_addr >= 32'h10000100 && cpu_addr < 32'h10000200)
            $display("DPCD WRITE addr=0x%08X data=0x%02X wstrb=%b", cpu_addr, cpu_wdata[7:0], cpu_wstrb);
        if (cpu_valid && cpu_wstrb == 4'b0000 && cpu_addr[11:0] == 12'h000)
            $display("AUX_CTRL  read req_pending=%b", req_pending);
        if (cpu_valid && cpu_wstrb != 4'b0000 && cpu_addr[11:0] == 12'h000)
            $display("AUX_CTRL  write val=0x%08X (resp_ready=%b ack=%b)", cpu_wdata, cpu_wdata[1], cpu_wdata[2]);
        if (cpu_valid && cpu_wstrb == 4'b0000 && cpu_addr[11:0] == 12'h004)
            $display("AUX_REQ   read opcode=0x%02X addr_hi=0x%02X addr_lo=0x%02X len=0x%02X",
                     cpu_rdata[31:24], cpu_rdata[23:16], cpu_rdata[15:8], cpu_rdata[7:0]);
        if (cpu_valid && cpu_wstrb == 4'b0000 && cpu_addr[11:0] == 12'h008)
            $display("AUX_WDATA read data=0x%02X", host_wdata);
        if (cpu_valid && cpu_wstrb != 4'b0000 && cpu_addr[11:0] == 12'h010)
            $display("AUX_RESP  write data=0x%02X", cpu_wdata[7:0]);
    end
    `endif
    // synthesis translate_on

    // RISC-V CPU register interface
    // Address map (word-aligned):
    // 0x00: AUX_CTRL      (RW) [0]=req_pending(RO), [1]=resp_ready(WO), [2]=ack(WO)
    // 0x04: AUX_REQ_OPADDR (RO) {opcode, addr_hi, addr_lo, len}
    // 0x08: AUX_REQ_WDATA  (RO) write data from host
    // 0x0C: AUX_RESP_CTRL  (WO) {code[7:0], ack, reserved}
    // 0x10: AUX_RESP_DATA  (WO) response data byte
    // 0x100-0x1FF: DPCD memory (256 bytes, word-aligned access)

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

                // DPCD memory access (0x100-0x1FF)
                if (cpu_addr[11:8] == 4'h1) begin
                    if (cpu_wstrb != 4'b0000) begin
                        if (cpu_wstrb[0]) dpcd_mem[cpu_addr[7:0]] <= cpu_wdata[7:0];
                        if (cpu_wstrb[1]) dpcd_mem[cpu_addr[7:0] + 8'h01] <= cpu_wdata[15:8];
                        if (cpu_wstrb[2]) dpcd_mem[cpu_addr[7:0] + 8'h02] <= cpu_wdata[23:16];
                        if (cpu_wstrb[3]) dpcd_mem[cpu_addr[7:0] + 8'h03] <= cpu_wdata[31:24];
                    end
                    cpu_rdata <= dpcd_mem[cpu_addr[7:0]];
                end
            end
        end
    end

endmodule
