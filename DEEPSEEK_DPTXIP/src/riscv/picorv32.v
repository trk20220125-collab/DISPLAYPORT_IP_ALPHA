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
                        // synthesis translate_off
                        // FETCH_OK
                        // synthesis translate_on
                        ir <= mem_rdata;
                        mem_valid <= 1'b0;
                        mem_instr <= 1'b0;
                        state <= STATE_EXEC;
                    end
                end

                STATE_EXEC: begin
                    minstret <= minstret + 1;
                    state <= STATE_FETCH;
                    next_pc = pc + 4;   // default (blocking, overridden by branches/jumps)

                    // synthesis translate_off
                    `ifndef SIM_QUIET
                    $write("EXEC[%d] pc=0x%08X ir=0x%08X opcode=0x%02X ", $time, pc, ir, ir[6:0]);
                    $write("rs1_addr=%d rs2_addr=%d rd_addr=%d ", ir[19:15], ir[24:20], ir[11:7]);
                    $write("rs1=0x%08X rs2=0x%08X ", rs1, rs2);
                    casez (ir[6:0])
                        7'b0110111: $display("LUI rd=x%02X imm=0x%05X", ir[11:7], ir[31:12]);
                        7'b0010111: $display("AUIPC rd=x%02X imm=0x%05X", ir[11:7], ir[31:12]);
                        7'b1101111: $display("JAL rd=x%02X target=0x%08X", ir[11:7], pc+{{11{ir[31]}},ir[31],ir[19:12],ir[20],ir[30:21],1'b0});
                        7'b1100111: $display("JALR rd=x%02X rs1=x%02X imm=0x%03X", ir[11:7], ir[19:15], ir[31:20]);
                        7'b1100011: $display("BRANCH f3=%d target=0x%08X", ir[14:12], pc+{{19{ir[31]}},ir[31],ir[7],ir[30:25],ir[11:8],1'b0});
                        7'b0000011: $display("LOAD f3=%d addr=0x%08X rd=x%02X", ir[14:12], rs1+{{20{ir[31]}},ir[31:20]}, ir[11:7]);
                        7'b0100011: $display("STORE f3=%d addr=0x%08X", ir[14:12], rs1+{{20{ir[31]}},ir[31:25],ir[11:7]});
                        7'b0010011: $display("OP-IMM f3=%d rd=x%02X rs1=0x%08X imm=0x%03X", ir[14:12], ir[11:7], rs1, ir[31:20]);
                        7'b0110011: $display("OP f3=%d f7=%d rd=x%02X rs1=0x%08X rs2=0x%08X", ir[14:12], ir[31:25], ir[11:7], rs1, rs2);
                        7'b0001111: $display("FENCE");
                        7'b1110011: $display("SYSTEM imm=0x%03X", ir[31:20]);
                        default: $display("UNKNOWN");
                    endcase
                    `endif
                    // synthesis translate_on

                    casez (ir)
                        // LUI
                        32'b????????????????????_?????_0110111: begin
                            reg_rd_addr <= rd_addr;
                            reg_rd_data <= imm_u;
                            reg_rd_we <= |rd_addr;
                            next_pc = pc + 4;
                        end

                        // AUIPC
                        32'b????????????????????_?????_0010111: begin
                            reg_rd_addr <= rd_addr;
                            reg_rd_data <= pc + imm_u;
                            reg_rd_we <= |rd_addr;
                            next_pc = pc + 4;
                        end

                        // JAL
                        32'b????????????????????_?????_1101111: begin
                            reg_rd_addr <= rd_addr;
                            reg_rd_data <= pc + 4;
                            reg_rd_we <= |rd_addr;
                            next_pc = pc + imm_j;
                        end

                        // JALR
                        32'b?????????????????_000_?????_1100111: begin
                            reg_rd_addr <= rd_addr;
                            reg_rd_data <= pc + 4;
                            reg_rd_we <= |rd_addr;
                            next_pc = (rs1 + imm_i) & ~32'h00000001;
                        end

                        // BEQ
                        32'b?????????????????_000_?????_1100011: begin
                            next_pc = (rs1 == rs2) ? pc + imm_b : pc + 4;
                        end

                        // BNE
                        32'b?????????????????_001_?????_1100011: begin
                            next_pc = (rs1 != rs2) ? pc + imm_b : pc + 4;
                        end

                        // BLT
                        32'b?????????????????_100_?????_1100011: begin
                            next_pc <= ($signed(rs1) < $signed(rs2)) ? pc + imm_b : pc + 4;
                        end

                        // BGE
                        32'b?????????????????_101_?????_1100011: begin
                            next_pc <= ($signed(rs1) >= $signed(rs2)) ? pc + imm_b : pc + 4;
                        end

                        // BLTU
                        32'b?????????????????_110_?????_1100011: begin
                            next_pc = (rs1 < rs2) ? pc + imm_b : pc + 4;
                        end

                        // BGEU
                        32'b?????????????????_111_?????_1100011: begin
                            next_pc = (rs1 >= rs2) ? pc + imm_b : pc + 4;
                        end

                        // LB
                        32'b?????????????????_000_?????_0000011: begin
                            mem_addr_q <= rs1 + imm_i;
                            mem_is_load <= 1'b1;
                            reg_rd_addr <= rd_addr;
                            state <= STATE_LMEM;
                            next_pc = pc + 4;
                        end

                        // LH
                        32'b?????????????????_001_?????_0000011: begin
                            mem_addr_q <= rs1 + imm_i;
                            mem_is_load <= 1'b1;
                            reg_rd_addr <= rd_addr;
                            state <= STATE_LMEM;
                            next_pc = pc + 4;
                        end

                        // LW
                        32'b?????????????????_010_?????_0000011: begin
                            mem_addr_q <= rs1 + imm_i;
                            mem_is_load <= 1'b1;
                            reg_rd_addr <= rd_addr;
                            state <= STATE_LMEM;
                            next_pc = pc + 4;
                        end

                        // LBU
                        32'b?????????????????_100_?????_0000011: begin
                            mem_addr_q <= rs1 + imm_i;
                            mem_is_load <= 1'b1;
                            reg_rd_addr <= rd_addr;
                            state <= STATE_LMEM;
                            next_pc = pc + 4;
                        end

                        // LHU
                        32'b?????????????????_101_?????_0000011: begin
                            mem_addr_q <= rs1 + imm_i;
                            mem_is_load <= 1'b1;
                            reg_rd_addr <= rd_addr;
                            state <= STATE_LMEM;
                            next_pc = pc + 4;
                        end

                        // SB
                        32'b?????????????????_000_?????_0100011: begin
                            mem_addr_q <= rs1 + imm_s;
                            mem_wdata_q <= {4{rs2[7:0]}};
                            mem_is_store <= 1'b1;
                            state <= STATE_LMEM;
                            next_pc = pc + 4;
                        end

                        // SH
                        32'b?????????????????_001_?????_0100011: begin
                            mem_addr_q <= rs1 + imm_s;
                            mem_wdata_q <= {2{rs2[15:0]}};
                            mem_is_store <= 1'b1;
                            state <= STATE_LMEM;
                            next_pc = pc + 4;
                        end

                        // SW
                        32'b?????????????????_010_?????_0100011: begin
                            mem_addr_q <= rs1 + imm_s;
                            mem_wdata_q <= rs2;
                            mem_is_store <= 1'b1;
                            state <= STATE_LMEM;
                            next_pc = pc + 4;
                        end

                        // ADDI
                        32'b?????????????????_000_?????_0010011: begin
                            reg_rd_addr <= rd_addr;
                            reg_rd_data <= rs1 + imm_i;
                            reg_rd_we <= |rd_addr;
                            next_pc = pc + 4;
                        end

                        // SLTI
                        32'b?????????????????_010_?????_0010011: begin
                            reg_rd_addr <= rd_addr;
                            reg_rd_data <= ($signed(rs1) < $signed(imm_i)) ? 32'h00000001 : 32'h00000000;
                            reg_rd_we <= |rd_addr;
                            next_pc = pc + 4;
                        end

                        // SLTIU
                        32'b?????????????????_011_?????_0010011: begin
                            reg_rd_addr <= rd_addr;
                            reg_rd_data <= (rs1 < imm_i) ? 32'h00000001 : 32'h00000000;
                            reg_rd_we <= |rd_addr;
                            next_pc = pc + 4;
                        end

                        // XORI
                        32'b?????????????????_100_?????_0010011: begin
                            reg_rd_addr <= rd_addr;
                            reg_rd_data <= rs1 ^ imm_i;
                            reg_rd_we <= |rd_addr;
                            next_pc = pc + 4;
                        end

                        // ORI
                        32'b?????????????????_110_?????_0010011: begin
                            reg_rd_addr <= rd_addr;
                            reg_rd_data <= rs1 | imm_i;
                            reg_rd_we <= |rd_addr;
                            next_pc = pc + 4;
                        end

                        // ANDI
                        32'b?????????????????_111_?????_0010011: begin
                            reg_rd_addr <= rd_addr;
                            reg_rd_data <= rs1 & imm_i;
                            reg_rd_we <= |rd_addr;
                            next_pc = pc + 4;
                        end

                        // SLLI
                        32'b0000000??????????_001_?????_0010011: begin
                            reg_rd_addr <= rd_addr;
                            reg_rd_data <= rs1 << rs2_addr;
                            reg_rd_we <= |rd_addr;
                            next_pc = pc + 4;
                        end

                        // SRLI
                        32'b0000000??????????_101_?????_0010011: begin
                            reg_rd_addr <= rd_addr;
                            reg_rd_data <= rs1 >> rs2_addr;
                            reg_rd_we <= |rd_addr;
                            next_pc = pc + 4;
                        end

                        // SRAI
                        32'b0100000??????????_101_?????_0010011: begin
                            reg_rd_addr <= rd_addr;
                            reg_rd_data <= $signed(rs1) >>> rs2_addr;
                            reg_rd_we <= |rd_addr;
                            next_pc = pc + 4;
                        end

                        // ADD
                        32'b0000000??????????_000_?????_0110011: begin
                            reg_rd_addr <= rd_addr;
                            reg_rd_data <= rs1 + rs2;
                            reg_rd_we <= |rd_addr;
                            next_pc = pc + 4;
                        end

                        // SUB
                        32'b0100000??????????_000_?????_0110011: begin
                            reg_rd_addr <= rd_addr;
                            reg_rd_data <= rs1 - rs2;
                            reg_rd_we <= |rd_addr;
                            next_pc = pc + 4;
                        end

                        // SLL
                        32'b0000000??????????_001_?????_0110011: begin
                            reg_rd_addr <= rd_addr;
                            reg_rd_data <= rs1 << rs2[4:0];
                            reg_rd_we <= |rd_addr;
                            next_pc = pc + 4;
                        end

                        // SLT
                        32'b0000000??????????_010_?????_0110011: begin
                            reg_rd_addr <= rd_addr;
                            reg_rd_data <= ($signed(rs1) < $signed(rs2)) ? 32'h00000001 : 32'h00000000;
                            reg_rd_we <= |rd_addr;
                            next_pc = pc + 4;
                        end

                        // SLTU
                        32'b0000000??????????_011_?????_0110011: begin
                            reg_rd_addr <= rd_addr;
                            reg_rd_data <= (rs1 < rs2) ? 32'h00000001 : 32'h00000000;
                            reg_rd_we <= |rd_addr;
                            next_pc = pc + 4;
                        end

                        // XOR
                        32'b0000000??????????_100_?????_0110011: begin
                            reg_rd_addr <= rd_addr;
                            reg_rd_data <= rs1 ^ rs2;
                            reg_rd_we <= |rd_addr;
                            next_pc = pc + 4;
                        end

                        // SRL
                        32'b0000000??????????_101_?????_0110011: begin
                            reg_rd_addr <= rd_addr;
                            reg_rd_data <= rs1 >> rs2[4:0];
                            reg_rd_we <= |rd_addr;
                            next_pc = pc + 4;
                        end

                        // SRA
                        32'b0100000??????????_101_?????_0110011: begin
                            reg_rd_addr <= rd_addr;
                            reg_rd_data <= $signed(rs1) >>> rs2[4:0];
                            reg_rd_we <= |rd_addr;
                            next_pc = pc + 4;
                        end

                        // OR
                        32'b0000000??????????_110_?????_0110011: begin
                            reg_rd_addr <= rd_addr;
                            reg_rd_data <= rs1 | rs2;
                            reg_rd_we <= |rd_addr;
                            next_pc = pc + 4;
                        end

                        // AND
                        32'b0000000??????????_111_?????_0110011: begin
                            reg_rd_addr <= rd_addr;
                            reg_rd_data <= rs1 & rs2;
                            reg_rd_we <= |rd_addr;
                            next_pc = pc + 4;
                        end

                        // FENCE / FENCE.I
                        32'b?????????????????_000_?????_0001111: begin
                            next_pc = pc + 4;
                        end

                        // ECALL
                        32'b000000000000_00000_000_00000_1110011: begin
                            trap_epc <= pc;
                            trap_cause <= 32'h0000000B;
                            state <= STATE_TRAP;
                        end

                        // EBREAK
                        32'b000000000001_00000_000_00000_1110011: begin
                            trap_epc <= pc;
                            trap_cause <= 32'h00000003;
                            state <= STATE_TRAP;
                        end

                        // CSR read (rdcycle, rdinstret)
                        32'b?????????????????_010_?????_1110011: begin
                            if (ENABLE_COUNTERS) begin
                                case (imm_i[11:0])
                                    12'hC00: reg_rd_data <= mcycle;       // rdcycle
                                    12'hC01: reg_rd_data <= minstret;      // rdinstret
                                    12'hC02: reg_rd_data <= 32'h00000000;   // rdcycleh
                                    12'hC03: reg_rd_data <= 32'h00000000;   // rdinstreth
                                    default: reg_rd_data <= 32'h00000000;
                                endcase
                            end else begin
                                reg_rd_data <= 32'h00000000;
                            end
                            reg_rd_addr <= rd_addr;
                            reg_rd_we <= |rd_addr;
                            next_pc = pc + 4;
                        end

                        // Default: illegal instruction
                        default: begin
                            trap_epc <= pc;
                            trap_cause <= 32'h00000002;
                            state <= STATE_TRAP;
                        end
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
                                3'b000: reg_rd_data <= { {24{mem_rdata[7]}},  mem_rdata[7:0] };      // LB
                                3'b001: reg_rd_data <= { {16{mem_rdata[15]}}, mem_rdata[15:0] };     // LH
                                3'b010: reg_rd_data <= mem_rdata;                                     // LW
                                3'b100: reg_rd_data <= { 24'h000000, mem_rdata[7:0] };               // LBU
                                3'b101: reg_rd_data <= { 16'h0000, mem_rdata[15:0] };                // LHU
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
                            3'b000: mem_wstrb <= 4'b0001 << mem_addr_q[1:0];  // SB
                            3'b001: mem_wstrb <= {2{4'b0011 << mem_addr_q[1:0]}}; // SH
                            3'b010: mem_wstrb <= 4'b1111;                     // SW
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
