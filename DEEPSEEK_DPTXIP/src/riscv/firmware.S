# DP AUX Controller Firmware for PicoRV32
# Memory map:
#   0x10000000: AUX_CTRL      (RW) [0]=req_pending, [1]=resp_ready, [2]=ack
#   0x10000004: AUX_REQ_OPADDR (RO) {opcode, addr_hi, addr_lo, len}
#   0x10000008: AUX_REQ_WDATA  (RO) write data byte from host
#   0x1000000C: AUX_RESP_CTRL  (WO) {code[7:0], ack}
#   0x10000010: AUX_RESP_DATA  (WO) response data byte
#   0x10000100: DPCD memory window (256 bytes)

# Constants
.equ AUX_CTRL,      0x10000000
.equ AUX_REQ_OPADDR,0x10000004
.equ AUX_REQ_WDATA, 0x10000008
.equ AUX_RESP_CTRL, 0x1000000C
.equ AUX_RESP_DATA, 0x10000010
.equ DPCD_BASE,     0x10000100

.equ OP_WRITE, 0x01
.equ OP_READ,  0x02
.equ RESP_ACK, 0xA5
.equ RESP_NACK,0x5A

_start:
    lui sp, 0x00002

main_loop:
    lui t0, 0x10000
    lw t1, 0(t0)
    andi t2, t1, 1
    beqz t2, main_loop

    lw t2, 4(t0)
    srli t3, t2, 24
    srli t4, t2, 16
    andi t4, t4, 0xFF
    srli t5, t2, 8
    andi t5, t5, 0xFF
    andi t6, t2, 0xFF

    addi a0, zero, 1
    beq t3, a0, do_write
    addi a0, zero, 2
    beq t3, a0, do_read
    j send_nack

do_write:
    lbu a1, 8(t0)
    addi a2, t0, 0x100
    add a2, a2, t5
    sb a1, 0(a2)
    addi a3, zero, 0xA5
    sw a3, 12(t0)
    addi a4, zero, 6
    sw a4, 0(t0)
    j main_loop

do_read:
    addi a2, t0, 0x100
    add a2, a2, t5
    lbu a1, 0(a2)
    sw a1, 16(t0)
    addi a3, zero, 0xA5
    sw a3, 12(t0)
    addi a4, zero, 6
    sw a4, 0(t0)
    j main_loop

send_nack:
    addi a3, zero, 0x5A
    sw a3, 12(t0)
    addi a4, zero, 2
    sw a4, 0(t0)
    j main_loop
