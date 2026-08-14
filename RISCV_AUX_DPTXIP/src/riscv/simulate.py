#!/usr/bin/env python3
"""
Simulation runner for DP TX with RISC-V AUX controller.
Assembles firmware, then runs iverilog simulation.

Usage:
    python simulate.py          # assemble + simulate
    python simulate.py --waves  # assemble + simulate with VCD dump
"""

import os
import sys
import subprocess

PROJ_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_DIR = os.path.join(PROJ_ROOT, "src")
RISCV_DIR = os.path.join(SRC_DIR, "riscv")
TB_DIR = os.path.join(PROJ_ROOT, "tb")


def assemble_firmware():
    print("=== Assembling firmware ===")
    subprocess.run(
        [sys.executable, "asm.py", "firmware.S", "firmware.hex"],
        cwd=RISCV_DIR, check=True
    )
    # Copy firmware.hex to tb/ for simulation
    import shutil
    shutil.copy2(
        os.path.join(RISCV_DIR, "firmware.hex"),
        os.path.join(TB_DIR, "firmware.hex")
    )
    print("  Firmware hex copied to tb/")
    return True


def run_simulation(waves=False):
    print("=== Running Verilog simulation ===")
    src_files = [
        os.path.join(SRC_DIR, "dp_tx_top.v"),
        os.path.join(SRC_DIR, "dp_tx_video_packer.v"),
        os.path.join(SRC_DIR, "dp_tx_pixel_fifo.v"),
        os.path.join(SRC_DIR, "dp_tx_scrambler.v"),
        os.path.join(SRC_DIR, "dp_tx_8b10b_enc.v"),
        os.path.join(SRC_DIR, "dp_tx_msa_gen.v"),
        os.path.join(SRC_DIR, "dp_tx_stream_mux.v"),
        os.path.join(SRC_DIR, "dp_tx_lane_mapper.v"),
        os.path.join(SRC_DIR, "dp_tx_phy_7series.v"),
        os.path.join(RISCV_DIR, "picorv32.v"),
        os.path.join(RISCV_DIR, "ram.v"),
        os.path.join(RISCV_DIR, "aux_periph.v"),
        os.path.join(RISCV_DIR, "riscv_soc.v"),
        os.path.join(TB_DIR, "dp_tx_top_tb.v"),
    ]

    tb_path = os.path.join(TB_DIR, "dp_tx_top_tb.v")

    cmd = ["iverilog", "-g2012", "-o", "sim_vvp"]
    cmd.extend(["-I", RISCV_DIR])
    cmd.extend(src_files)

    print(f"  {' '.join(cmd[:4])} ...")
    result = subprocess.run(cmd, cwd=TB_DIR, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"  iverilog failed:\n{result.stderr}")
        return False

    print("  Running simulation...")
    vvp_cmd = ["vvp", "sim_vvp"]
    result = subprocess.run(vvp_cmd, cwd=TB_DIR, capture_output=True, text=True)
    print(result.stdout)
    if result.stderr:
        print(f"  stderr: {result.stderr}")

    if waves:
        vcd_path = os.path.join(TB_DIR, "dp_tx_top_tb.vcd")
        if os.path.exists(vcd_path):
            print(f"  Waves saved to {vcd_path}")
            print(f"  View with: gtkwave {vcd_path}")

    return result.returncode == 0


def test_firmware():
    print("=== Testing firmware in emulator ===")
    result = subprocess.run(
        [sys.executable, "test_fw.py"],
        cwd=RISCV_DIR, capture_output=True, text=True
    )
    print(result.stdout)
    if result.stderr:
        print(f"  stderr: {result.stderr}")
    return "ALL TESTS PASSED" in result.stdout


def main():
    if not assemble_firmware():
        sys.exit(1)
    if not test_firmware():
        print("  Firmware tests FAILED!", file=sys.stderr)
        sys.exit(1)
    if not run_simulation(waves="--waves" in sys.argv):
        print("  Simulation FAILED!", file=sys.stderr)
        sys.exit(1)
    print("=== ALL CHECKS PASSED ===")


if __name__ == '__main__':
    main()
