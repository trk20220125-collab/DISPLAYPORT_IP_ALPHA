#!/usr/bin/env python3
"""
RV32I firmware emulation test for DP AUX controller firmware.
Loads firmware.hex and emulates the RISC-V core + AUX peripheral.
Tests AUX read/write transaction handling.
"""

import struct

class RV32Emu:
    def __init__(self, firmware_hex, stack_addr=0x2000):
        self.regs = [0] * 32
        self.regs[2] = stack_addr  # SP
        self.pc = 0
        self.mem = {}
        self.firmware = self._load_hex(firmware_hex)
        self.cycles = 0
        self.instret = 0
        # AUX peripheral state
        self.aux_req_pending = False
        self.aux_req_opcode = 0
        self.aux_req_addr_hi = 0
        self.aux_req_addr_lo = 0
        self.aux_req_len = 0
        self.aux_req_wdata = 0
        self.aux_resp_ready = False
        self.aux_resp_ack = False
        self.aux_resp_code = 0
        self.aux_resp_data = 0
        self.dpcd = [0] * 256
        self.dpcd[0] = 0x01
        self.dpcd[1] = 0x02
        self.dpcd[2] = 0x03
        self.dpcd[3] = 0x04

    def _load_hex(self, path):
        with open(path) as f:
            lines = f.read().strip().split()
        mem = {}
        for i, line in enumerate(lines):
            addr = i * 4
            val = int(line, 16)
            mem[addr] = val
        return mem

    def _read_word(self, addr):
        if addr in self.firmware:
            return self.firmware[addr]
        if addr == 0x10000000:
            return 1 if self.aux_req_pending else 0
        if addr == 0x10000004:
            return (self.aux_req_opcode << 24) | (self.aux_req_addr_hi << 16) | \
                   (self.aux_req_addr_lo << 8) | self.aux_req_len
        if addr == 0x10000008:
            return self.aux_req_wdata
        if 0x10000100 <= addr < 0x10000200:
            idx = addr - 0x10000100
            return self.dpcd[idx]
        return 0

    def _read_byte(self, addr):
        if 0x10000100 <= addr < 0x10000200:
            idx = addr - 0x10000100
            return self.dpcd[idx] & 0xFF
        if addr in self.firmware:
            v = self.firmware[addr & ~3]
            shift = (addr & 3) * 8
            return (v >> shift) & 0xFF
        # AUX register byte read - delegate to word read
        word_val = self._read_word(addr & ~3)
        shift = (addr & 3) * 8
        return (word_val >> shift) & 0xFF

    def _write_word(self, addr, val):
        if addr == 0x10000000:
            if val & 2:  # resp_ready
                self.aux_resp_ready = True
                self.aux_resp_ack = bool(val & 4)
                self.aux_req_pending = False
        elif addr == 0x1000000C:
            self.aux_resp_code = val & 0xFF
            self.aux_resp_ack = bool(val & 0x100)
        elif addr == 0x10000010:
            self.aux_resp_data = val & 0xFF
        elif 0x10000100 <= addr < 0x10000200:
            idx = addr - 0x10000100
            self.dpcd[idx] = val & 0xFF

    def _write_byte(self, addr, val):
        if 0x10000100 <= addr < 0x10000200:
            idx = addr - 0x10000100
            self.dpcd[idx] = val & 0xFF

    def _sign_ext(self, val, bits):
        if val & (1 << (bits - 1)):
            val -= (1 << bits)
        return val

    def _decode_r(self, instr):
        return ((instr >> 25) & 0x7F, (instr >> 20) & 0x1F, (instr >> 15) & 0x1F,
                (instr >> 12) & 0x7, (instr >> 7) & 0x1F, instr & 0x7F)

    def _decode_i(self, instr):
        imm = self._sign_ext((instr >> 20) & 0xFFF, 12)
        rs1 = (instr >> 15) & 0x1F
        f3 = (instr >> 12) & 0x7
        rd = (instr >> 7) & 0x1F
        op = instr & 0x7F
        return imm, rs1, f3, rd, op

    def _decode_s(self, instr):
        imm = ((instr >> 25) << 5) | ((instr >> 7) & 0x1F)
        imm = self._sign_ext(imm, 12)
        rs2 = (instr >> 20) & 0x1F
        rs1 = (instr >> 15) & 0x1F
        f3 = (instr >> 12) & 0x7
        op = instr & 0x7F
        return imm, rs2, rs1, f3

    def _decode_b(self, instr):
        b12 = (instr >> 31) & 1
        b10_5 = (instr >> 25) & 0x3F
        b4_1 = (instr >> 8) & 0xF
        b11 = (instr >> 7) & 1
        imm = (b12 << 12) | (b11 << 11) | (b10_5 << 5) | (b4_1 << 1)
        imm = self._sign_ext(imm, 13)
        rs2 = (instr >> 20) & 0x1F
        rs1 = (instr >> 15) & 0x1F
        f3 = (instr >> 12) & 0x7
        return imm, rs2, rs1, f3

    def _decode_u(self, instr):
        imm = (instr >> 12) << 12
        rd = (instr >> 7) & 0x1F
        return imm, rd

    def _decode_j(self, instr):
        b20 = (instr >> 31) & 1
        b10_1 = (instr >> 21) & 0x3FF
        b11 = (instr >> 20) & 1
        b19_12 = (instr >> 12) & 0xFF
        imm = (b20 << 20) | (b19_12 << 12) | (b11 << 11) | (b10_1 << 1)
        imm = self._sign_ext(imm, 21)
        rd = (instr >> 7) & 0x1F
        return imm, rd

    def step(self):
        if self.pc not in self.firmware:
            return False
        instr = self.firmware[self.pc]
        opcode = instr & 0x7F
        rd = (instr >> 7) & 0x1F
        f3 = (instr >> 12) & 0x7
        rs1 = (instr >> 15) & 0x1F
        rs2 = (instr >> 20) & 0x1F
        f7 = (instr >> 25) & 0x7F

        self.cycles += 1
        self.instret += 1

        next_pc = self.pc + 4
        val = 0

        if opcode == 0b0110111:  # LUI
            imm, rd = self._decode_u(instr)
            self.regs[rd] = imm & 0xFFFFFFFF

        elif opcode == 0b0010111:  # AUIPC
            imm, rd = self._decode_u(instr)
            self.regs[rd] = (self.pc + imm) & 0xFFFFFFFF

        elif opcode == 0b1101111:  # JAL
            imm, rd = self._decode_j(instr)
            self.regs[rd] = self.pc + 4
            next_pc = self.pc + imm

        elif opcode == 0b1100111:  # JALR
            imm, rs1, f3, rd, _ = self._decode_i(instr)
            self.regs[rd] = self.pc + 4
            next_pc = (self.regs[rs1] + imm) & 0xFFFFFFFE

        elif opcode == 0b1100011:  # BRANCH
            imm, rs2, rs1, f3 = self._decode_b(instr)
            a = self.regs[rs1]
            b = self.regs[rs2]
            taken = False
            if f3 == 0: taken = a == b
            elif f3 == 1: taken = a != b
            elif f3 == 4: taken = self._sign_ext(a, 32) < self._sign_ext(b, 32)
            elif f3 == 5: taken = self._sign_ext(a, 32) >= self._sign_ext(b, 32)
            elif f3 == 6: taken = (a & 0xFFFFFFFF) < (b & 0xFFFFFFFF)
            elif f3 == 7: taken = (a & 0xFFFFFFFF) >= (b & 0xFFFFFFFF)
            if taken:
                next_pc = self.pc + imm

        elif opcode == 0b0000011:  # LOAD
            imm, rs1, f3, rd, _ = self._decode_i(instr)
            addr = (self.regs[rs1] + imm) & 0xFFFFFFFF
            if f3 == 0:  # LB
                val = self._read_byte(addr)
                val = self._sign_ext(val, 8) & 0xFFFFFFFF
            elif f3 == 1:  # LH
                val = (self._read_byte(addr)) | (self._read_byte(addr + 1) << 8)
                val = self._sign_ext(val, 16) & 0xFFFFFFFF
            elif f3 == 2:  # LW
                val = self._read_word(addr)
            elif f3 == 5:  # LBU
                val = self._read_byte(addr) & 0xFF
            elif f3 == 6:  # LHU
                val = (self._read_byte(addr)) | (self._read_byte(addr + 1) << 8)
            self.regs[rd] = val

        elif opcode == 0b0100011:  # STORE
            imm, rs2, rs1, f3 = self._decode_s(instr)
            addr = (self.regs[rs1] + imm) & 0xFFFFFFFF
            data = self.regs[rs2]
            if f3 == 0:  # SB
                self._write_byte(addr, data & 0xFF)
            elif f3 == 1:  # SH
                self._write_byte(addr, data & 0xFF)
                self._write_byte(addr + 1, (data >> 8) & 0xFF)
            elif f3 == 2:  # SW
                self._write_word(addr, data)

        elif opcode == 0b0010011:  # OP-IMM
            imm, rs1, f3, rd, _ = self._decode_i(instr)
            a = self.regs[rs1]
            if f3 == 0: val = a + imm           # ADDI
            elif f3 == 2: val = 1 if self._sign_ext(a, 32) < self._sign_ext(imm, 32) else 0
            elif f3 == 3: val = 1 if (a & 0xFFFFFFFF) < (imm & 0xFFFFFFFF) else 0
            elif f3 == 4: val = a ^ imm          # XORI
            elif f3 == 6: val = a | imm          # ORI
            elif f3 == 7: val = a & imm          # ANDI
            elif f3 == 1: val = a << (rs2 & 0x1F)  # SLLI (shamt in rs2 field)
            elif f3 == 5:
                if f7 & 0x20:  # SRAI
                    val = self._sign_ext(a, 32) >> (rs2 & 0x1F)
                else:  # SRLI
                    val = (a & 0xFFFFFFFF) >> (rs2 & 0x1F)
            self.regs[rd] = val & 0xFFFFFFFF

        elif opcode == 0b0110011:  # OP
            funct7, rs2, rs1, f3, rd, _ = self._decode_r(instr)
            a = self.regs[rs1]
            b = self.regs[rs2]
            sub = (funct7 & 0x20) != 0
            if f3 == 0:
                val = (a - b) if sub else (a + b)
            elif f3 == 1: val = a << (b & 0x1F)
            elif f3 == 2: val = 1 if self._sign_ext(a, 32) < self._sign_ext(b, 32) else 0
            elif f3 == 3: val = 1 if (a & 0xFFFFFFFF) < (b & 0xFFFFFFFF) else 0
            elif f3 == 4: val = a ^ b
            elif f3 == 5:
                if sub:
                    val = self._sign_ext(a, 32) >> (b & 0x1F)
                else:
                    val = (a & 0xFFFFFFFF) >> (b & 0x1F)
            elif f3 == 6: val = a | b
            elif f3 == 7: val = a & b
            self.regs[rd] = val & 0xFFFFFFFF

        elif opcode == 0b1110011:  # SYSTEM (CSRRx, ECALL, EBREAK)
            imm, rs1, f3, rd, _ = self._decode_i(instr)
            if f3 == 2 and rd != 0:  # CSRRS read-only
                csr = imm & 0xFFF
                if csr == 0xC00: val = self.cycles
                elif csr == 0xC01: val = self.instret
                else: val = 0
                self.regs[rd] = val

        elif opcode == 0b0001111:  # FENCE
            pass

        # Write back rd (except stores, branches)
        if rd and opcode not in (0b0100011, 0b1100011, 0b0001111):
            if opcode not in (0b0000011, 0b0110111, 0b0010111, 0b1101111, 0b1100111,
                              0b0010011, 0b0110011, 0b1110011):
                pass  # already handled or no writeback

        self.regs[0] = 0
        self.pc = next_pc
        return True

    def run(self, max_cycles=10000):
        for _ in range(max_cycles):
            if not self.step():
                break
        return self.cycles < max_cycles

    def send_aux_request(self, opcode, addr_hi, addr_lo, length, wdata=0):
        self.aux_req_pending = True
        self.aux_req_opcode = opcode
        self.aux_req_addr_hi = addr_hi
        self.aux_req_addr_lo = addr_lo
        self.aux_req_len = length
        self.aux_req_wdata = wdata
        self.aux_resp_ready = False
        self.aux_resp_ack = False
        self.aux_resp_code = 0
        self.aux_resp_data = 0

    def poll_for_response(self, max_cycles=5000):
        for _ in range(max_cycles):
            self.step()
            if self.aux_resp_ready:
                return True
        return False


def test_aux_read_write():
    emu = RV32Emu("../riscv/firmware.hex")

    # Give firmware time to reach main loop
    for _ in range(50):
        emu.step()

    # Test 1: Read DPCD[1] (initial value 0x02)
    print("=== Test 1: Read DPCD[1] ===")
    emu.send_aux_request(opcode=2, addr_hi=0, addr_lo=1, length=0)
    assert emu.poll_for_response(), "Timeout waiting for read response"
    assert emu.aux_resp_ack, f"Expected ACK, got NACK (code=0x{emu.aux_resp_code:02X})"
    assert emu.aux_resp_data == 0x02, f"Expected 0x02, got 0x{emu.aux_resp_data:02X}"
    print(f"  PASS: ack={emu.aux_resp_ack} data=0x{emu.aux_resp_data:02X} code=0x{emu.aux_resp_code:02X}")

    # Test 2: Write DPCD[5] = 0xAA
    print("=== Test 2: Write DPCD[5] = 0xAA ===")
    emu.send_aux_request(opcode=1, addr_hi=0, addr_lo=5, length=0, wdata=0xAA)
    assert emu.poll_for_response(), "Timeout waiting for write response"
    assert emu.aux_resp_ack, f"Expected ACK, got NACK (code=0x{emu.aux_resp_code:02X})"
    print(f"  PASS: ack={emu.aux_resp_ack} code=0x{emu.aux_resp_code:02X}")

    # Test 3: Read back DPCD[5] (should be 0xAA)
    print("=== Test 3: Read back DPCD[5] ===")
    emu.send_aux_request(opcode=2, addr_hi=0, addr_lo=5, length=0)
    assert emu.poll_for_response(), "Timeout waiting for read response"
    assert emu.aux_resp_ack, f"Expected ACK, got NACK (code=0x{emu.aux_resp_code:02X})"
    assert emu.aux_resp_data == 0xAA, f"Expected 0xAA, got 0x{emu.aux_resp_data:02X}"
    print(f"  PASS: ack={emu.aux_resp_ack} data=0x{emu.aux_resp_data:02X} code=0x{emu.aux_resp_code:02X}")

    # Test 4: Unknown opcode (0xFF) should NACK
    print("=== Test 4: Unknown opcode 0xFF ===")
    emu.send_aux_request(opcode=0xFF, addr_hi=0, addr_lo=0, length=0)
    assert emu.poll_for_response(), "Timeout waiting for NACK response"
    assert not emu.aux_resp_ack, f"Expected NACK, got ACK"
    assert emu.aux_resp_code == 0x5A, f"Expected RESP_NACK, got 0x{emu.aux_resp_code:02X}"
    print(f"  PASS: ack={emu.aux_resp_ack} code=0x{emu.aux_resp_code:02X}")

    # Test 5: Initial values preserved
    print("=== Test 5: Verify DPCD[0] ===")
    emu.send_aux_request(opcode=2, addr_hi=0, addr_lo=0, length=0)
    assert emu.poll_for_response(), "Timeout waiting for read response"
    assert emu.aux_resp_data == 0x01, f"Expected 0x01, got 0x{emu.aux_resp_data:02X}"
    print(f"  PASS: ack={emu.aux_resp_ack} data=0x{emu.aux_resp_data:02X}")

    # Test 6: Multi-byte transaction (read 4 bytes from DPCD[0..3])
    print("=== Test 6: Multi-byte read DPCD[0..3] ===")
    for i in range(4):
        emu.send_aux_request(opcode=2, addr_hi=0, addr_lo=i, length=0)
        assert emu.poll_for_response(), f"Timeout reading DPCD[{i}]"
        expected = [0x01, 0x02, 0x03, 0x04][i]
        assert emu.aux_resp_data == expected, f"DPCD[{i}]: expected 0x{expected:02X}, got 0x{emu.aux_resp_data:02X}"
    print(f"  PASS: all 4 initial values correct")

    print("\n=== ALL TESTS PASSED ===")


if __name__ == '__main__':
    test_aux_read_write()
