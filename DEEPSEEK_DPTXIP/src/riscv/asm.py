#!/usr/bin/env python3
"""
Minimal RV32I assembler for DP AUX firmware.
Usage: python asm.py firmware.S firmware.hex
"""

import sys
import re

def reg_num(r):
    names = {f'x{i}': i for i in range(32)}
    names.update({
        'zero': 0, 'ra': 1, 'sp': 2, 'gp': 3, 'tp': 4,
        't0': 5, 't1': 6, 't2': 7, 's0': 8, 'fp': 8,
        's1': 9, 'a0': 10, 'a1': 11, 'a2': 12, 'a3': 13,
        'a4': 14, 'a5': 15, 'a6': 16, 'a7': 17,
        's2': 18, 's3': 19, 's4': 20, 's5': 21, 's6': 22,
        's7': 23, 's8': 24, 's9': 25, 's10': 26, 's11': 27,
        't3': 28, 't4': 29, 't5': 30, 't6': 31,
    })
    n = names.get(r)
    if n is not None:
        return n
    raise ValueError(f"Unknown register: {r}")

def parse_imm(s, bits, unsigned=False):
    s = s.strip()
    if s.startswith('-'):
        neg = True
        s = s[1:]
    else:
        neg = False
    val = 0
    if s.startswith('0x'):
        val = int(s[2:], 16)
    else:
        val = int(s)
    if neg:
        val = -val
    if unsigned:
        if val < 0 or val >= (1 << bits):
            raise ValueError(f"Immediate {val} out of range for unsigned {bits} bits")
    else:
        if val < -(1 << (bits-1)) or val >= (1 << (bits-1)):
            raise ValueError(f"Immediate {val} out of range for signed {bits} bits")
    return val & ((1 << bits) - 1)

def parse_imm_signed(s, bits):
    return parse_imm(s, bits, unsigned=False)

def encode_r(funct7, rs2, rs1, funct3, rd, opcode):
    return (funct7 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode

def encode_i(imm, rs1, funct3, rd, opcode):
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode

def encode_s(imm, rs2, rs1, funct3, opcode):
    imm = imm & 0xFFF
    return ((imm >> 5) << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | ((imm & 0x1F) << 7) | opcode

def encode_b(imm, rs2, rs1, funct3, opcode):
    imm = imm & 0x1FFF
    b = 0
    b |= ((imm >> 12) & 1) << 31
    b |= ((imm >> 5) & 0x3F) << 25
    b |= (rs2 & 0x1F) << 20
    b |= (rs1 & 0x1F) << 15
    b |= (funct3 & 0x7) << 12
    b |= ((imm >> 1) & 0xF) << 8
    b |= ((imm >> 11) & 1) << 7
    b |= opcode & 0x7F
    return b

def encode_u(imm, rd, opcode):
    return ((imm & 0xFFFFF) << 12) | ((rd & 0x1F) << 7) | opcode

def encode_j(imm, rd, opcode):
    imm = imm & 0x1FFFFFF
    b = 0
    b |= ((imm >> 20) & 1) << 31
    b |= ((imm >> 1) & 0x3FF) << 21
    b |= ((imm >> 11) & 1) << 20
    b |= ((imm >> 12) & 0xFF) << 12
    b |= ((rd & 0x1F) << 7)
    b |= opcode & 0x7F
    return b

OP_LUI     = 0b0110111
OP_AUIPC   = 0b0010111
OP_JAL     = 0b1101111
OP_JALR    = 0b1100111
OP_BRANCH  = 0b1100011
OP_LOAD    = 0b0000011
OP_STORE   = 0b0100011
OP_OP_IMM  = 0b0010011
OP_OP      = 0b0110011
OP_SYSTEM  = 0b1110011
OP_FENCE   = 0b0001111

# funct3 values
F3_JALR    = 0
F3_BEQ     = 0; F3_BNE = 1; F3_BLT = 4; F3_BGE = 5; F3_BLTU = 6; F3_BGEU = 7
F3_LB=0; F3_LH=1; F3_LW=2; F3_LBU=5; F3_LHU=6
F3_SB=0; F3_SH=1; F3_SW=2
F3_ADDI=0; F3_SLTI=2; F3_SLTIU=3; F3_XORI=4; F3_ORI=6; F3_ANDI=7
F3_SLLI=1; F3_SRLI=5; F3_SRAI=5
F3_ADD=0; F3_SUB=0; F3_SLL=1; F3_SLT=2; F3_SLTU=3; F3_XOR=4; F3_SRL=5; F3_SRA=5; F3_OR=6; F3_AND=7
F3_CSRRW=1; F3_CSRRS=2; F3_CSRRC=3

F7_STD = 0
F7_SUB_SRA = 0b0100000

def expand_pseudo(line, labels, pc):
    """Expand pseudo-instructions into real instructions."""
    line_clean = line
    m = re.match(r'^\s*li\s+(\w+)\s*,\s*(.+)$', line_clean)
    if m:
        rd = m.group(1)
        imm_str = m.group(2).strip()

        # Check if it's a label reference
        if imm_str in labels:
            imm_val = labels[imm_str]
        else:
            imm_val = parse_imm_signed(imm_str, 32)

        if imm_val == 0:
            return [f"addi {rd}, zero, 0"]
        elif -2048 <= imm_val <= 2047:
            return [f"addi {rd}, zero, {imm_val}"]
        else:
            upper = (imm_val + 0x800) >> 12
            lower = imm_val - (upper << 12)
            if lower > 2047:
                lower -= 4096
            elif lower < -2048:
                lower += 4096
            if lower >= 0:
                return [f"lui {rd}, {upper & 0xFFFFF}", f"addi {rd}, {rd}, {lower}"]
            else:
                return [f"lui {rd}, {upper & 0xFFFFF}", f"addi {rd}, {rd}, {lower}"]

    m = re.match(r'^\s*beqz\s+(\w+)\s*,\s*(.+)$', line_clean)
    if m:
        return [f"beq {m.group(1)}, zero, {m.group(2)}"]

    m = re.match(r'^\s*bnez\s+(\w+)\s*,\s*(.+)$', line_clean)
    if m:
        return [f"bne {m.group(1)}, zero, {m.group(2)}"]

    return [line]

def assemble(source, start_addr=0):
    lines = source.split('\n')
    # First pass: collect labels and addresses, skip directives
    labels = {}
    addr = start_addr
    cleaned = []

    for line in lines:
        line = line.split('#')[0].strip()
        if not line:
            cleaned.append((addr, ''))
            continue
        if line.startswith('.'):
            continue
        if line.endswith(':'):
            labels[line[:-1]] = addr
            cleaned.append((addr, ''))
            continue
        # Handle label: instruction on same line
        if ':' in line:
            parts = line.split(':')
            labels[parts[0].strip()] = addr
            line = ':'.join(parts[1:]).strip()
            if not line:
                cleaned.append((addr, ''))
                continue
        cleaned.append((addr, line))
        addr += 4

    # Second pass: assemble
    output = []
    for addr, line in cleaned:
        if not line:
            continue

        # Expand pseudo-ops
        expanded = expand_pseudo(line, labels, addr)
        for asm_line in expanded:
            if not asm_line.strip():
                continue

            parts = asm_line.replace(',', ' ').split()
            instr = parts[0].lower()
            args = parts[1:]

            try:
                if instr == 'nop':
                    val = encode_i(0, 0, 0, 0, OP_OP_IMM)

                elif instr == 'lui':
                    val = encode_u(parse_imm(args[1], 32, unsigned=True), reg_num(args[0]), OP_LUI)

                elif instr == 'auipc':
                    val = encode_u(parse_imm(args[1], 32, unsigned=True), reg_num(args[0]), OP_AUIPC)

                elif instr == 'jal':
                    if len(args) == 2:
                        rd = reg_num(args[0])
                        target = args[1]
                    else:
                        rd = 1
                        target = args[0]
                    imm_val = labels[target] - addr if target in labels else parse_imm(target, 21, unsigned=False)
                    val = encode_j(imm_val, rd, OP_JAL)

                elif instr == 'jalr':
                    rd = reg_num(args[0])
                    m = re.search(r'(\w+),\s*(-?\d+)\((\w+)\)', asm_line)
                    if m:
                        rd = reg_num(m.group(1))
                        imm = parse_imm(m.group(2), 12, unsigned=False)
                        rs1 = reg_num(m.group(3))
                    else:
                        imm = parse_imm(args[2], 12, unsigned=False) if len(args) > 2 else 0
                        rs1 = reg_num(args[1])
                    val = encode_i(imm, rs1, F3_JALR, rd, OP_JALR)

                elif instr in ('beq', 'bne', 'blt', 'bge', 'bltu', 'bgeu'):
                    f3 = {'beq':0,'bne':1,'blt':4,'bge':5,'bltu':6,'bgeu':7}[instr]
                    rs1 = reg_num(args[0])
                    rs2 = reg_num(args[1])
                    target = args[2]
                    imm_val = labels[target] - addr if target in labels else parse_imm(target, 13, unsigned=False)
                    val = encode_b(imm_val, rs2, rs1, f3, OP_BRANCH)

                elif instr in ('lb', 'lh', 'lw', 'lbu', 'lhu'):
                    f3 = {'lb':0,'lh':1,'lw':2,'lbu':5,'lhu':6}[instr]
                    rd = reg_num(args[0])
                    m = re.search(r'(-?\d+)\((\w+)\)', asm_line)
                    if m:
                        imm = parse_imm(m.group(1), 12, unsigned=False)
                        rs1 = reg_num(m.group(2))
                    else:
                        rs1 = reg_num(args[1])
                        imm = parse_imm(args[2], 12, unsigned=False) if len(args) > 2 else 0
                    val = encode_i(imm, rs1, f3, rd, OP_LOAD)

                elif instr in ('sb', 'sh', 'sw'):
                    f3 = {'sb':0,'sh':1,'sw':2}[instr]
                    rs2 = reg_num(args[0])
                    m = re.search(r'(-?\d+)\((\w+)\)', asm_line)
                    if m:
                        imm = parse_imm(m.group(1), 12, unsigned=False)
                        rs1 = reg_num(m.group(2))
                    else:
                        rs1 = reg_num(args[1])
                        imm = parse_imm(args[2], 12, unsigned=False)
                    val = encode_s(imm, rs2, rs1, f3, OP_STORE)

                elif instr in ('addi', 'slti', 'sltiu', 'xori', 'ori', 'andi'):
                    f3 = {'addi':0,'slti':2,'sltiu':3,'xori':4,'ori':6,'andi':7}[instr]
                    rd = reg_num(args[0])
                    rs1 = reg_num(args[1])
                    imm = parse_imm(args[2], 12, unsigned=False)
                    val = encode_i(imm, rs1, f3, rd, OP_OP_IMM)

                elif instr == 'slli':
                    rd = reg_num(args[0])
                    rs1 = reg_num(args[1])
                    shamt = parse_imm(args[2], 5, unsigned=True)
                    val = encode_r(F7_STD, shamt, rs1, 1, rd, OP_OP_IMM)

                elif instr == 'srli':
                    rd = reg_num(args[0])
                    rs1 = reg_num(args[1])
                    shamt = parse_imm(args[2], 5, unsigned=True)
                    val = encode_r(F7_STD, shamt, rs1, 5, rd, OP_OP_IMM)

                elif instr == 'srai':
                    rd = reg_num(args[0])
                    rs1 = reg_num(args[1])
                    shamt = parse_imm(args[2], 5, unsigned=True)
                    val = encode_r(F7_SUB_SRA, shamt, rs1, 5, rd, OP_OP_IMM)

                elif instr in ('add', 'sub', 'sll', 'slt', 'sltu', 'xor', 'srl', 'sra', 'or', 'and'):
                    f3_map = {'add':0,'sub':0,'sll':1,'slt':2,'sltu':3,'xor':4,'srl':5,'sra':5,'or':6,'and':7}
                    f7_map = {'add':0,'sub':F7_SUB_SRA,'sll':0,'slt':0,'sltu':0,'xor':0,'srl':0,'sra':F7_SUB_SRA,'or':0,'and':0}
                    rd = reg_num(args[0])
                    rs1 = reg_num(args[1])
                    rs2 = reg_num(args[2])
                    val = encode_r(f7_map[instr], rs2, rs1, f3_map[instr], rd, OP_OP)

                elif instr in ('csrrw', 'csrrs', 'csrrc'):
                    f3 = {'csrrw':1,'csrrs':2,'csrrc':3}[instr]
                    rd = reg_num(args[0])
                    csr = parse_imm(args[1], 12, unsigned=True)
                    rs1 = reg_num(args[2])
                    val = encode_i(csr, rs1, f3, rd, OP_SYSTEM)

                elif instr in ('csrrwi', 'csrrsi', 'csrrci'):
                    f3 = {'csrrwi':5,'csrrsi':6,'csrrci':7}[instr]
                    rd = reg_num(args[0])
                    csr = parse_imm(args[1], 12, unsigned=True)
                    uimm = parse_imm(args[2], 5, unsigned=True)
                    val = encode_i(csr, uimm, f3, rd, OP_SYSTEM)

                elif instr == 'ecall':
                    val = encode_i(0, 0, 0, 0, OP_SYSTEM)

                elif instr == 'ebreak':
                    val = encode_i(1, 0, 0, 0, OP_SYSTEM)

                elif instr in ('fence', 'fence_i'):
                    val = encode_i(0, 0, 0, 0, OP_FENCE)

                elif instr == 'rdcycle':
                    rd = reg_num(args[0])
                    val = encode_i(0xC00, 0, 2, rd, OP_SYSTEM)

                elif instr == 'rdinstret':
                    rd = reg_num(args[0])
                    val = encode_i(0xC01, 0, 2, rd, OP_SYSTEM)

                elif instr == 'mv':
                    rd = reg_num(args[0])
                    rs1 = reg_num(args[1])
                    val = encode_i(0, rs1, 0, rd, OP_OP_IMM)

                elif instr == 'neg':
                    rd = reg_num(args[0])
                    rs1 = reg_num(args[1])
                    val = encode_r(F7_SUB_SRA, 0, rs1, 0, rd, OP_OP)

                elif instr == 'not':
                    rd = reg_num(args[0])
                    rs1 = reg_num(args[1])
                    val = encode_i(-1, rs1, F3_XORI, rd, OP_OP_IMM)

                elif instr == 'j':
                    target = args[0]
                    imm_val = labels[target] - addr if target in labels else parse_imm(target, 21, unsigned=False)
                    val = encode_j(imm_val, 0, OP_JAL)

                elif instr == 'jr':
                    rs1 = reg_num(args[0])
                    val = encode_i(0, rs1, F3_JALR, 0, OP_JALR)

                elif instr == 'ret':
                    val = encode_i(0, 1, F3_JALR, 0, OP_JALR)

                elif instr == 'call':
                    target = args[0]
                    imm_val = labels[target] - addr if target in labels else parse_imm(target, 21, unsigned=False)
                    val = encode_j(imm_val, 1, OP_JAL)

                else:
                    raise ValueError(f"Unknown instruction: {instr}")

            except (ValueError, KeyError, IndexError) as e:
                print(f"Error assembling '{asm_line}' at 0x{addr:08X}: {e}", file=sys.stderr)
                val = 0x00000013

            output.append((addr, val))

    return output


def main():
    if len(sys.argv) < 3:
        print("Usage: python asm.py <input.S> <output.hex> [start_addr]", file=sys.stderr)
        sys.exit(1)

    with open(sys.argv[1], 'r') as f:
        source = f.read()

    start_addr = int(sys.argv[3], 0) if len(sys.argv) > 3 else 0x00000000

    result = assemble(source, start_addr)

    max_addr = max(a for a, v in result) if result else 0
    nwords = (max_addr // 4) + 1

    mem = [0] * nwords
    for addr, val in result:
        idx = addr // 4
        mem[idx] = val

    hex_lines = [f"{v:08X}" for v in mem]

    with open(sys.argv[2], 'w') as f:
        f.write('\n'.join(hex_lines) + '\n')

    print(f"Assembled {len(result)} instructions into {sys.argv[2]} ({nwords} words)", file=sys.stderr)

if __name__ == '__main__':
    main()
