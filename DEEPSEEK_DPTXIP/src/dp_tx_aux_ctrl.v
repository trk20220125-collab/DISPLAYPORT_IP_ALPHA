module dp_tx_aux_ctrl (
    input  wire        clk,
    input  wire        rst_n,
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
    output reg [7:0]   aux_resp_code
);

    localparam OP_WRITE = 8'h01;
    localparam OP_READ  = 8'h02;
    localparam RESP_ACK = 8'hA5;
    localparam RESP_NACK = 8'h5A;
    localparam RESP_DEFER = 8'h7E;

    localparam ST_IDLE = 2'd0;
    localparam ST_WAIT = 2'd1;
    localparam ST_REPLY = 2'd2;

    reg [1:0] state;
    reg [7:0] dpcd_mem [0:15];
    reg [3:0] addr_index;
    reg [7:0] req_len;
    reg [7:0] reply_data;

    integer i;

    initial begin
        for (i = 0; i < 16; i = i + 1) begin
            dpcd_mem[i] = 8'h00;
        end
        dpcd_mem[0] = 8'h01;
        dpcd_mem[1] = 8'h02;
        dpcd_mem[2] = 8'h03;
        dpcd_mem[3] = 8'h04;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= ST_IDLE;
            aux_busy      <= 1'b0;
            aux_resp_valid<= 1'b0;
            aux_resp_ack  <= 1'b0;
            aux_resp_data <= 8'h00;
            aux_resp_code <= RESP_NACK;
            addr_index    <= 4'h0;
            req_len       <= 8'h00;
            reply_data    <= 8'h00;
        end else begin
            aux_resp_valid <= 1'b0;
            aux_resp_ack   <= 1'b0;

            case (state)
                ST_IDLE: begin
                    if (aux_req_valid) begin
                        aux_busy <= 1'b1;
                        addr_index <= aux_req_addr_lo[3:0];
                        req_len <= aux_req_len;

                        if (aux_req_opcode == OP_WRITE) begin
                            dpcd_mem[aux_req_addr_lo[3:0]] <= aux_req_data;
                            aux_resp_code <= RESP_ACK;
                            state <= ST_REPLY;
                        end else if (aux_req_opcode == OP_READ) begin
                            reply_data <= dpcd_mem[aux_req_addr_lo[3:0]];
                            aux_resp_code <= RESP_ACK;
                            state <= ST_REPLY;
                        end else begin
                            aux_resp_code <= RESP_NACK;
                            state <= ST_REPLY;
                        end
                    end
                end

                ST_WAIT: begin
                    state <= ST_REPLY;
                end

                ST_REPLY: begin
                    aux_busy <= 1'b0;
                    aux_resp_valid <= 1'b1;
                    aux_resp_ack <= (aux_resp_code == RESP_ACK);
                    aux_resp_data <= (aux_req_opcode == OP_READ) ? reply_data : aux_req_data;
                    state <= ST_IDLE;
                end

                default: begin
                    state <= ST_IDLE;
                end
            endcase
        end
    end
endmodule
